use crate::models::{HexCoordinate, TileSwap, GameState};
use starknet::ContractAddress;
use hexcore_logic::types::{CellData, TurnSideEffects, TileSwap as CoreTileSwap};
use crate::type_conversions::{dojo_to_core_coords, dojo_to_core_coord, core_to_dojo_coord};

// Interface for the game system
#[starknet::interface]
pub trait IGameActions<T> {
    fn create_game(
        ref self: T, grid_size: u8, score_limit: u32, word_list_root: felt252
    ) -> u32;
    fn join_game(ref self: T, game_id: u32, player_name: ByteArray, color: felt252);
    fn submit_turn(
        ref self: T,
        game_id: u32,
        word: ByteArray,
        tile_positions: Array<HexCoordinate>,
        tile_swap: Option<TileSwap>,
        merkle_proof: Array<felt252>
    ) -> bool;
    fn get_current_player(self: @T, game_id: u32) -> ContractAddress;
    fn get_game_state(self: @T, game_id: u32) -> GameState;

}

// Dojo contract implementation
#[dojo::contract]
pub mod game_actions {
    use super::{IGameActions, HexCoordinate, TileSwap, CellData, TurnSideEffects, CoreTileSwap, dojo_to_core_coords, dojo_to_core_coord, core_to_dojo_coord};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use crate::models::{
        GameState, Player, Cell, GamePlayer,
        GameCreated, PlayerJoined, GameStarted, GameOver
    };
    use crate::constants::{
        NAMESPACE, DEFAULT_GRID_SIZE, DEFAULT_SCORE_LIMIT, DEFAULT_MIN_WORD_LENGTH
    };
    use hexcore_logic::{PlayerTurn, GameLogicTrait, GameConfig};
    use dojo::model::{ModelStorage};
    use dojo::event::EventStorage;
    use core::poseidon::poseidon_hash_span;
    
    #[abi(embed_v0)]
    impl GameActionsImpl of IGameActions<ContractState> {
        fn create_game(
            ref self: ContractState, 
            grid_size: u8, 
            score_limit: u32, 
            word_list_root: felt252
        ) -> u32 {
            let mut world = self.world(NAMESPACE());
            
            // Generate game ID using timestamp and caller
            let _caller = get_caller_address();
            let timestamp = get_block_timestamp();
            let game_id: u32 = (timestamp % 1000000).try_into().unwrap();
            
            // Create game state
            let game_state = GameState {
                id: game_id,
                grid_size: if grid_size == 0 { DEFAULT_GRID_SIZE } else { grid_size },
                score_limit: if score_limit == 0 { DEFAULT_SCORE_LIMIT } else { score_limit },
                min_word_length: DEFAULT_MIN_WORD_LENGTH,
                word_list_root,
                current_player_index: 0,
                player_count: 0,
                is_active: false,
                winner: Option::None,
                created_at: get_block_timestamp(),
            };
            
            world.write_model(@game_state);
            
            // Initialize grid
            self.initialize_grid(game_id, game_state.grid_size);
            
            // Emit event
            world.emit_event(
                @GameCreated {
                    game_id,
                    creator: get_caller_address(),
                    grid_size: game_state.grid_size,
                    score_limit: game_state.score_limit,
                }
            );
            
            game_id
        }
        
        fn join_game(ref self: ContractState, game_id: u32, player_name: ByteArray, color: felt252) {
            let mut world = self.world(NAMESPACE());
            let player_address = get_caller_address();
            
            // Read and validate game state
            let mut game_state: GameState = world.read_model(game_id);
            assert(game_state.player_count < 2, 'Game is full');
            assert(!game_state.is_active, 'Game already started');
            
            // Check if player already joined
            let existing_player: Player = world.read_model((game_id, player_address));
            assert(existing_player.name.len() == 0, 'Already joined');
            
            // Add player
            let game_player = GamePlayer {
                game_id,
                index: game_state.player_count,
                address: player_address,
            };
            world.write_model(@game_player);
            
            // Create player model
            let player = Player {
                game_id,
                address: player_address,
                name: player_name,
                color,
                score: 0,
            };
            world.write_model(@player);
            
            // Update game state
            game_state.player_count += 1;
            
            // Emit player joined event
            world.emit_event(
                @PlayerJoined {
                    game_id,
                    player: player_address,
                    player_index: game_state.player_count - 1,
                }
            );
            
            // Start game if we have 2 players
            if game_state.player_count == 2 {
                game_state.is_active = true;
                // Random starting player (simplified - use block timestamp)
                game_state.current_player_index = (get_block_timestamp() % 2).try_into().unwrap();
                
                world.emit_event(
                    @GameStarted {
                        game_id,
                        starting_player_index: game_state.current_player_index,
                    }
                );
            }
            
            world.write_model(@game_state);
        }
        
        fn submit_turn(
            ref self: ContractState,
            game_id: u32,
            word: ByteArray,
            tile_positions: Array<HexCoordinate>,
            tile_swap: Option<TileSwap>,
            merkle_proof: Array<felt252>
        ) -> bool {
            let mut world = self.world(NAMESPACE());
            let player_address = get_caller_address();
            
            // Validate game and player turn
            let mut game_state: GameState = world.read_model(game_id);
            assert(game_state.is_active, 'Game not active');
            
            let current_player = self.get_player_by_index(game_id, game_state.current_player_index);
            assert(player_address == current_player, 'Not your turn');
              
            // Build grid scenario from current cells
            let grid_scenario = self.build_grid_scenario(game_id);
            
            // Create PlayerTurn for hexcore_logic
            let player_turn = PlayerTurn {
                player_index: game_state.current_player_index,
                word: self.word_to_bytes(@word),
                tile_positions: dojo_to_core_coords(@tile_positions),
                tile_swap: self.convert_tile_swap(tile_swap),
                merkle_proof,
            };
            
            // Calculate turn using hexcore_logic
            let game_logic = GameLogicTrait::new(GameConfig {
                grid_size: game_state.grid_size,
                min_word_length: game_state.min_word_length,
                score_limit: game_state.score_limit,
            });
            
            let side_effects = match game_logic.calculate_turn(@grid_scenario, @player_turn) {
                Result::Ok(effects) => effects,
                Result::Err(_error) => {
                    // Handle validation error
                    return false;
                }
            };
            
            // Apply side effects
            self.apply_turn_side_effects(game_id, player_address, @side_effects);  
            
            // Check if game is over
            match InternalFunctionsTrait::is_game_over(@self, game_id) {
                Option::Some(winner_address) => {
                    // Game is over, update state and emit event
                    game_state.is_active = false;
                    game_state.winner = Option::Some(winner_address);
                    world.write_model(@game_state);
                    
                    // Get winner's score for the event
                    let winner: Player = world.read_model((game_id, winner_address));
                    
                    // Emit game over event
                    world.emit_event(@GameOver {
                        game_id,
                        winner: winner_address,
                        final_score: winner.score,
                    });
                },
                Option::None => {
                    // Game continues, move to next player
                    game_state.current_player_index = (game_state.current_player_index + 1) % game_state.player_count;
                    world.write_model(@game_state);
                }
            }
            
            true
        }
        
        fn get_current_player(self: @ContractState, game_id: u32) -> ContractAddress {
            let world = self.world(NAMESPACE());
            let game_state: GameState = world.read_model(game_id);
            self.get_player_by_index(game_id, game_state.current_player_index)
        }
        
        fn get_game_state(self: @ContractState, game_id: u32) -> GameState {
            let world = self.world(NAMESPACE());
            world.read_model(game_id)
        }
    }
    
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn initialize_grid(self: @ContractState, game_id: u32, grid_size: u8) {
            let mut world = self.world(NAMESPACE());
            
            // Simple grid initialization - just create cells in a radius
            let radius: i32 = grid_size.into();
            let mut letter_index: u32 = 0;
            
            // Create cells in hexagonal pattern
            let mut q: i32 = -radius;
            loop {
                if q > radius {
                    break;
                }
                
                let r_start = if q < 0 { -radius - q } else { -radius };
                let r_end = if q < 0 { radius } else { radius - q };
                
                let mut r: i32 = r_start;
                loop {
                    if r > r_end {
                        break;
                    }
                    
                    // Simple letter generation (cycle through A-Z)
                    let letter = 65 + (letter_index % 26); // ASCII A=65
                    
                    let cell = Cell {
                        game_id,
                        q,
                        r,
                        letter: letter.try_into().unwrap(),
                        captured_by: Option::None,
                        locked_by: Option::None,
                    };
                    
                    world.write_model(@cell);
                    letter_index += 1;
                    r += 1;
                };
                
                q += 1;
            };
        }
        
        fn get_player_by_index(self: @ContractState, game_id: u32, index: u8) -> ContractAddress {
            let world = self.world(NAMESPACE());
            let game_player: GamePlayer = world.read_model((game_id, index));
            game_player.address
        }
        
        fn build_grid_scenario(self: @ContractState, game_id: u32) -> Array<CellData> {
            let world = self.world(NAMESPACE());
            let game_state: GameState = world.read_model(game_id);
            let grid_size_i32: i32 = game_state.grid_size.into();
            
            let mut grid_scenario = array![];
            
            // Iterate through all coordinates in the grid
            let mut q = -grid_size_i32;
            while q <= grid_size_i32 {
                let r_min = if q < 0 { -grid_size_i32 - q } else { -grid_size_i32 };
                let r_max = if q > 0 { grid_size_i32 } else { grid_size_i32 - q };
                
                let mut r = r_min;
                while r <= r_max {
                    // Read the cell from storage
                    let cell: Cell = world.read_model((game_id, q, r));
                    
                    // Convert to CellData for hexcore_logic
                    let cell_data = CellData {
                        coordinate: hexcore_logic::types::HexCoordinate { q, r },
                        letter: cell.letter,
                        captured_by: cell.captured_by,
                        locked_by: cell.locked_by,
                    };
                    
                    grid_scenario.append(cell_data);
                    r += 1;
                };
                q += 1;
            };
            
            grid_scenario
        }
        
        fn word_to_bytes(self: @ContractState, word: @ByteArray) -> Array<u8> {
            let mut bytes = array![];
            let mut i = 0;
            while i < word.len() {
                if let Option::Some(byte) = word.at(i) {
                    bytes.append(byte);
                }
                i += 1;
            };
            bytes
        }
        
        fn convert_tile_swap(self: @ContractState, tile_swap: Option<TileSwap>) -> Option<CoreTileSwap> {
            match tile_swap {
                Option::Some(swap) => {
                    Option::Some(CoreTileSwap {
                        from: dojo_to_core_coord(@swap.from),
                        to: dojo_to_core_coord(@swap.to),
                    })
                },
                Option::None => Option::None,
            }
        }
        
        fn apply_turn_side_effects(self: @ContractState, game_id: u32, player_address: ContractAddress, side_effects: @TurnSideEffects) {
            let mut world = self.world(NAMESPACE());
            
            // Apply cell captures
            let mut i = 0;
            while i < side_effects.cells_captured.len() {
                let coord = side_effects.cells_captured[i];
                let dojo_coord = core_to_dojo_coord(coord);
                let mut cell: Cell = world.read_model((game_id, dojo_coord.q, dojo_coord.r));
                cell.captured_by = Option::Some(player_address);
                world.write_model(@cell);
                i += 1;
            };
            
            // Apply hexagon formations (lock centers)
            let mut i = 0;
            while i < side_effects.hexagons_formed.len() {
                let center_coord = side_effects.hexagons_formed[i];
                let dojo_coord = core_to_dojo_coord(center_coord);
                let mut cell: Cell = world.read_model((game_id, dojo_coord.q, dojo_coord.r));
                cell.locked_by = Option::Some(player_address);
                world.write_model(@cell);
                i += 1;
            };
            
            // Apply tile replacements
            let mut i = 0;
            while i < side_effects.tiles_replaced.len() {
                let coord = side_effects.tiles_replaced[i];
                let dojo_coord = core_to_dojo_coord(coord);
                let mut cell: Cell = world.read_model((game_id, dojo_coord.q, dojo_coord.r));
                
                // Generate new letter using poseidon hash
                let hash = poseidon_hash_span([
                    game_id.into(), 
                    dojo_coord.q.into(), 
                    dojo_coord.r.into(),
                    starknet::get_block_timestamp().into()
                ].span());
                let hash_u256: u256 = hash.into();
                let letter_index = (hash_u256 % 26).try_into().unwrap();
                cell.letter = self.get_letter_at(letter_index);
                
                // Clear capture and lock status
                cell.captured_by = Option::None;
                cell.locked_by = Option::None;
                
                world.write_model(@cell);
                i += 1;
            };
            
            // Update player scores
            let mut i = 0;
            while i < side_effects.points_awarded.len() {
                let (player, points) = *side_effects.points_awarded[i];
                let mut player_model: Player = world.read_model((game_id, player));
                player_model.score += points;
                world.write_model(@player_model);
                i += 1;
            };
            
            // These variables are for counting but not currently used in the event
            let _cells_captured_count: u8 = side_effects.cells_captured.len().try_into().unwrap();
            let _hexagons_count: u8 = side_effects.hexagons_formed.len().try_into().unwrap();
            
            // TODO: Emit TurnSubmitted event with proper word and turn_number
            // world.emit_event(@TurnSubmitted {
            //     game_id,
            //     turn_number: 0, // TODO: Get actual turn number
            //     player: player_address,
            //     word: "", // TODO: Get actual word from turn
            //     points_scored: side_effects.score_gain,
            // });
        }
        
        fn get_letter_at(self: @ContractState, index: u32) -> felt252 {
            match index {
                0 => 'A',
                1 => 'B',
                2 => 'C',
                3 => 'D',
                4 => 'E',
                5 => 'F',
                6 => 'G',
                7 => 'H',
                8 => 'I',
                9 => 'J',
                10 => 'K',
                11 => 'L',
                12 => 'M',
                13 => 'N',
                14 => 'O',
                15 => 'P',
                16 => 'Q',
                17 => 'R',
                18 => 'S',
                19 => 'T',
                20 => 'U',
                21 => 'V',
                22 => 'W',
                23 => 'X',
                24 => 'Y',
                25 => 'Z',
                _ => 'A',
            }
        }
        
        fn is_game_over(self: @ContractState, game_id: u32) -> Option<ContractAddress> {
            let world = self.world(NAMESPACE());
            let game_state: GameState = world.read_model(game_id);
            
            // Check if any player has reached the score limit and return their address
            let mut i = 0;
            let mut winner = Option::None;
            while i < game_state.player_count {
                let player_address = self.get_player_by_index(game_id, i);
                let player: Player = world.read_model((game_id, player_address));
                
                if player.score >= game_state.score_limit {
                    winner = Option::Some(player_address);
                    break;
                }
                
                i += 1;
            };
            
            winner
        }
    }
}
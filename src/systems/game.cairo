use crate::models::{HexCoordinate, TileSwap};
use starknet::ContractAddress;

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
}

// Dojo contract implementation
#[dojo::contract]
pub mod game_actions {
    use super::{IGameActions, HexCoordinate, TileSwap};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use crate::models::{
        GameState, Player, Cell, GamePlayer,
        GameCreated, PlayerJoined, GameStarted
    };
    use crate::constants::{
        NAMESPACE, DEFAULT_GRID_SIZE, DEFAULT_SCORE_LIMIT, DEFAULT_MIN_WORD_LENGTH
    };
    use dojo::model::{ModelStorage};
    use dojo::event::EventStorage;
    
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
            
            // TODO: Implement full turn logic with hexcore_logic integration
            // For now, just rotate turns
            
            // Move to next player
            game_state.current_player_index = (game_state.current_player_index + 1) % game_state.player_count;
            world.write_model(@game_state);
            
            true
        }
        
        fn get_current_player(self: @ContractState, game_id: u32) -> ContractAddress {
            let world = self.world(NAMESPACE());
            let game_state: GameState = world.read_model(game_id);
            self.get_player_by_index(game_id, game_state.current_player_index)
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
    }
}
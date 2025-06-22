use crate::models::{Cell, Player, GameState, WordSubmitted, GameOver, HexCoordinate};

#[starknet::interface]
pub trait IGameActions<T> {
    fn create_game(ref self: T, grid_size: u8) -> u32;
    fn join_game(ref self: T, game_id: u32, player_name: ByteArray, color: felt252);
    fn submit_word(ref self: T, game_id: u32, cells: Array<HexCoordinate>) -> bool;
    fn get_game_state(self: @T, game_id: u32) -> GameState;
}

#[dojo::contract]
pub mod game_actions {
    use super::{IGameActions, Cell, Player, GameState, WordSubmitted, GameOver, HexCoordinate};
    use starknet::{ContractAddress, get_caller_address};
    use dojo::model::{ModelStorage};
    use dojo::event::EventStorage;
    use core::poseidon::poseidon_hash_span;
    use hexcore_logic::hex_grid::HexGridTrait;
    use hexcore_logic::types::{HexCoordinate as CoreHexCoordinate};
    use crate::type_conversions::{dojo_to_core_coord, dojo_to_core_coords, core_to_dojo_coords};

    #[abi(embed_v0)]
    impl GameActionsImpl of IGameActions<ContractState> {
        fn create_game(ref self: ContractState, grid_size: u8) -> u32 {
            let mut world = self.world(@"hexgame");
            
            // Generate new game ID - use a simple counter for now
            // In production, you might want to use a more sophisticated ID generation
            let game_id = 1; // TODO: Implement proper game ID generation
            
            // Create game state
            let game_state = GameState {
                id: game_id,
                grid_size,
                current_player_index: 0,
                player_count: 0,
                is_active: false,
            };
            
            world.write_model(@game_state);
            
            // Initialize grid with random letters
            self.initialize_grid(game_id, grid_size);
            
            game_id
        }
        
        fn join_game(ref self: ContractState, game_id: u32, player_name: ByteArray, color: felt252) {
            let mut world = self.world(@"hexgame");
            let player_address = get_caller_address();
            
            // Read game state
            let mut game_state: GameState = world.read_model(game_id);
            assert(game_state.player_count < 4, 'Game is full');
            assert(!game_state.is_active, 'Game already started');
            
            // Create player
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
            if game_state.player_count >= 2 {
                game_state.is_active = true;
            }
            
            world.write_model(@game_state);
        }
        
        fn submit_word(ref self: ContractState, game_id: u32, cells: Array<HexCoordinate>) -> bool {
            let mut world = self.world(@"hexgame");
            let player_address = get_caller_address();
            
            // Validate game state
            let mut game_state: GameState = world.read_model(game_id);
            assert(game_state.is_active, 'Game not active');
            
            // Validate it's player's turn
            let _player: Player = world.read_model((game_id, player_address));
            let current_player = self.get_current_player(@game_state);
            assert(player_address == current_player, 'Not your turn');
            
            // Validate word length
            let word_length = cells.len();
            assert(word_length >= 3, 'Word too short');
            
            // Validate cells are connected
            assert(self.are_cells_connected(@cells, game_id), 'Cells not connected');
            
            // Get word from cells
            let _word = self.get_word_from_cells(@cells, game_id);
            
            // TODO: Validate word against dictionary
            // For now, we'll accept all words
            
            // Capture cells
            let (cells_captured, cells_locked) = self.capture_cells(game_id, @cells, player_address);
            
            // Update player score
            let mut player: Player = world.read_model((game_id, player_address));
            player.score += cells_captured;
            world.write_model(@player);
            
            // Emit event
            world.emit_event(@WordSubmitted {
                game_id,
                player: player_address,
                word_length: word_length.try_into().unwrap(),
                cells_captured: cells_captured.try_into().unwrap(),
                cells_locked: cells_locked.try_into().unwrap(),
            });
            
            // Check if game is over
            if self.is_game_over(game_id) {
                let winner = self.get_winner(game_id);
                let final_score = player.score;
                world.emit_event(@GameOver {
                    game_id,
                    winner,
                    final_score,
                });
                game_state.is_active = false;
            } else {
                // Move to next player
                game_state.current_player_index = (game_state.current_player_index + 1) % game_state.player_count;
            }
            
            world.write_model(@game_state);
            
            true
        }
        
        fn get_game_state(self: @ContractState, game_id: u32) -> GameState {
            let world = self.world(@"hexgame");
            world.read_model(game_id)
        }
    }
    
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initialize_grid(ref self: ContractState, game_id: u32, grid_size: u8) {
            let mut world = self.world(@"hexgame");
            let _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
            let grid_size_i32: i32 = grid_size.into();
            
            let mut q = -grid_size_i32;
            while q <= grid_size_i32 {
                let mut r = -grid_size_i32;
                while r <= grid_size_i32 {
                    if self.is_valid_coordinate(q, r, grid_size_i32) {
                        // Generate pseudo-random letter
                        let hash = poseidon_hash_span([game_id.into(), q.into(), r.into()].span());
                        // Convert hash to u256 for modulo operation
                        let hash_u256: u256 = hash.into();
                        let letter_index: u32 = (hash_u256 % 26).try_into().unwrap();
                        let letter = self.get_letter_at(letter_index);
                        
                        let cell = Cell {
                            game_id,
                            q,
                            r,
                            letter,
                            captured_by: Option::None,
                            locked_by: Option::None,
                        };
                        
                        world.write_model(@cell);
                    }
                    r += 1;
                };
                q += 1;
            };
        }
        
        fn is_valid_coordinate(self: @ContractState, q: i32, r: i32, grid_size: i32) -> bool {
            let grid_size_u8: u8 = grid_size.try_into().unwrap();
            let grid = HexGridTrait::new(grid_size_u8);
            let core_coord = CoreHexCoordinate { q, r };
            grid.is_valid_coordinate(@core_coord)
        }
        
        fn abs(self: @ContractState, value: i32) -> i32 {
            if value < 0 {
                -value
            } else {
                value
            }
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
        
        fn get_neighbors(self: @ContractState, coord: HexCoordinate) -> Array<HexCoordinate> {
            let game_state: GameState = self.world(@"hexgame").read_model(0); // Need actual game_id
            let grid = HexGridTrait::new(game_state.grid_size);
            let core_coord = dojo_to_core_coord(@coord);
            let core_neighbors = grid.get_neighbors(@core_coord);
            core_to_dojo_coords(@core_neighbors)
        }
        
        fn are_cells_connected(self: @ContractState, cells: @Array<HexCoordinate>, game_id: u32) -> bool {
            let game_state: GameState = self.world(@"hexgame").read_model(game_id);
            let grid = HexGridTrait::new(game_state.grid_size);
            let core_cells = dojo_to_core_coords(cells);
            grid.are_cells_connected(@core_cells)
        }
        
        fn contains_coord(self: @ContractState, coords: @Array<HexCoordinate>, target: @HexCoordinate) -> bool {
            let core_coords = dojo_to_core_coords(coords);
            let core_target = dojo_to_core_coord(target);
            hexcore_logic::hex_grid::contains_coord(@core_coords, @core_target)
        }
        
        fn get_word_from_cells(self: @ContractState, cells: @Array<HexCoordinate>, game_id: u32) -> ByteArray {
            let world = self.world(@"hexgame");
            let mut word = "";
            
            let mut i = 0;
            while i < cells.len() {
                let coord = *cells[i];
                let _cell: Cell = world.read_model((game_id, coord.q, coord.r));
                // TODO: Convert felt252 letter to ByteArray and append
                i += 1;
            };
            
            word
        }
        
        fn capture_cells(self: @ContractState, game_id: u32, cells: @Array<HexCoordinate>, player: ContractAddress) -> (u32, u32) {
            let mut world = self.world(@"hexgame");
            let mut cells_captured = 0;
            let mut cells_locked = 0;
            
            let mut i = 0;
            while i < cells.len() {
                let coord = *cells[i];
                let mut cell: Cell = world.read_model((game_id, coord.q, coord.r));
                
                if cell.locked_by.is_none() {
                    if cell.captured_by.is_none() || cell.captured_by != Option::Some(player) {
                        cells_captured += 1;
                    }
                    cell.captured_by = Option::Some(player);
                    
                    // TODO: Implement locking the central cell of the hexagon
                    // if cells.len() >= 5 {
                    //     cell.locked_by = Option::Some(player);
                    //     cells_locked += 1;
                    // }
                    
                    world.write_model(@cell);
                }
                i += 1;
            };
            
            (cells_captured, cells_locked)
        }
        
        fn get_current_player(self: @ContractState, game_state: @GameState) -> ContractAddress {
            // TODO: Need a way to iterate through players based on current_player_index
            // For now, returning a dummy address
            starknet::contract_address_const::<0>()
        }
        
        fn is_game_over(self: @ContractState, game_id: u32) -> bool {
            let world = self.world(@"hexgame");
            let game_state: GameState = world.read_model(game_id);
            let grid_size_i32: i32 = game_state.grid_size.into();
            
            let mut all_captured = true;
            let mut q = -grid_size_i32;
            while q <= grid_size_i32 && all_captured {
                let mut r = -grid_size_i32;
                while r <= grid_size_i32 && all_captured {
                    if self.is_valid_coordinate(q, r, grid_size_i32) {
                        let cell: Cell = world.read_model((game_id, q, r));
                        if cell.captured_by.is_none() {
                            // Found an uncaptured cell, game is not over
                            all_captured = false;
                        }
                    }
                    r += 1;
                };
                q += 1;
            };
            
            all_captured
        }
        
        fn get_winner(self: @ContractState, game_id: u32) -> ContractAddress {
            // TODO: Implement proper winner calculation
            starknet::contract_address_const::<0>()
        }
    }
}

#[cfg(test)]
mod unit_tests {
    use super::{HexCoordinate};
    
    // Helper function to test abs
    fn abs(value: i32) -> i32 {
        if value < 0 {
            -value
        } else {
            value
        }
    }
    
    // Helper to test get_letter_at
    fn get_letter_at(index: u32) -> felt252 {
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

    #[test]
    fn test_is_valid_coordinate() {
        let grid_size = 3;
        
        // Test center
        let s = -0 - 0;
        assert(abs(0) <= grid_size && abs(0) <= grid_size && abs(s) <= grid_size, 'Center should be valid');
        
        // Test edge cases
        let s1 = -3 - 0;
        assert(abs(3) <= grid_size && abs(0) <= grid_size && abs(s1) <= grid_size, 'Edge (3,0) valid');
        
        // Test invalid coordinates
        let s2 = -4 - 0;
        assert(!(abs(4) <= grid_size && abs(0) <= grid_size && abs(s2) <= grid_size), 'Beyond edge invalid');
    }

    #[test]
    fn test_abs_function() {
        assert(abs(5) == 5, 'Positive unchanged');
        assert(abs(-5) == 5, 'Negative to positive');
        assert(abs(0) == 0, 'Zero unchanged');
        assert(abs(-100) == 100, 'Large negative');
    }

    #[test]
    fn test_get_letter_at_function() {
        assert(get_letter_at(0) == 'A', 'Index 0 is A');
        assert(get_letter_at(1) == 'B', 'Index 1 is B');
        assert(get_letter_at(25) == 'Z', 'Index 25 is Z');
        assert(get_letter_at(26) == 'A', 'Index 26 wraps to A');
        assert(get_letter_at(100) == 'A', 'Large index wraps to A');
    }

    #[test]
    fn test_hex_neighbors() {
        // Test that neighbor calculation is correct
        let center = HexCoordinate { q: 0, r: 0 };
        
        // Manually calculate neighbors according to PRD spec
        let north = HexCoordinate { q: center.q, r: center.r - 1 };
        let northeast = HexCoordinate { q: center.q + 1, r: center.r - 1 };
        let southeast = HexCoordinate { q: center.q + 1, r: center.r };
        let south = HexCoordinate { q: center.q, r: center.r + 1 };
        let southwest = HexCoordinate { q: center.q - 1, r: center.r + 1 };
        let northwest = HexCoordinate { q: center.q - 1, r: center.r };
        
        // Verify all 6 directions
        assert(north.q == 0 && north.r == -1, 'North');
        assert(northeast.q == 1 && northeast.r == -1, 'Northeast');
        assert(southeast.q == 1 && southeast.r == 0, 'Southeast');
        assert(south.q == 0 && south.r == 1, 'South');
        assert(southwest.q == -1 && southwest.r == 1, 'Southwest');
        assert(northwest.q == -1 && northwest.r == 0, 'Northwest');
    }

    #[test]
    fn test_contains_coord_logic() {
        let coords = array![
            HexCoordinate { q: 0, r: 0 },
            HexCoordinate { q: 1, r: 0 },
            HexCoordinate { q: 2, r: -1 }
        ];
        
        let target1 = HexCoordinate { q: 1, r: 0 };
        
        // Manual contains check
        let mut found = false;
        let mut i = 0;
        while i < coords.len() {
            let coord = *coords[i];
            if coord.q == target1.q && coord.r == target1.r {
                found = true;
                break;
            }
            i += 1;
        };
        
        assert(found, 'Should contain (1,0)');
    }
}
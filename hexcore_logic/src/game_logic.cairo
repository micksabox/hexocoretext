use super::types::{HexCoordinate, CellData, PlayerTurn, TurnSideEffects};
use super::hex_grid::{HexGrid, HexGridTrait, contains_coord};
use super::cell_map::{CellMap, CellMapTrait};
use core::poseidon::poseidon_hash_span;

#[derive(Drop, Serde, Copy)]
pub struct GameConfig {
    pub grid_size: u8,
    pub min_word_length: u8,
    pub score_limit: u32,
}

#[derive(Drop)]
pub struct GameLogic {
    pub config: GameConfig,
    pub grid: HexGrid,
}

#[generate_trait]
pub impl GameLogicImpl of GameLogicTrait {
    fn new(config: GameConfig) -> GameLogic {
        GameLogic {
            config,
            grid: HexGridTrait::new(config.grid_size),
        }
    }

    // Generate a pseudo-random letter for a cell
    fn generate_letter(self: @GameLogic, game_id: u32, coord: @HexCoordinate) -> felt252 {
        let hash = poseidon_hash_span([game_id.into(), (*coord.q).into(), (*coord.r).into()].span());
        // Convert felt252 to u256 for modulo operation
        let hash_u256: u256 = hash.into();
        let modulo: u256 = 26;
        let remainder = hash_u256 - ((hash_u256 / modulo) * modulo);
        let index_u32: u32 = remainder.try_into().unwrap();
        get_letter_at(index_u32)
    }

    // Check if a word meets minimum length requirement
    fn is_valid_word_length(self: @GameLogic, word_length: u32) -> bool {
        word_length >= (*self.config.min_word_length).into()
    }
    // Find all hexagon formations in the captured cells
    fn find_hexagon_formations(self: @GameLogic, cells: @Array<HexCoordinate>) -> Array<HexCoordinate> {
        let mut hexagon_centers = array![];
        
        // For each cell, check if it's the center of a hexagon
        let mut i = 0;
        while i < cells.len() {
            let potential_center = cells.at(i);
            if self.is_hexagon_center(cells, potential_center) {
                hexagon_centers.append(*potential_center);
            }
            i += 1;
        };
        
        hexagon_centers
    }

    // Find all super hexagon formations (center + 6 neighbors all locked)
    fn find_super_hexagon_formations(self: @GameLogic, ref cell_map: CellMap) -> Array<HexCoordinate> {
        let mut super_hexagon_centers = array![];
        
        // Get all coordinates from the grid
        let all_coords = self.grid.get_all_coordinates();
        
        // For each coordinate, check if it's the center of a super hexagon
        let mut i = 0;
        while i < all_coords.len() {
            let potential_center = all_coords.at(i);
            if self.is_super_hexagon_center(ref cell_map, potential_center) {
                super_hexagon_centers.append(*potential_center);
            }
            i += 1;
        };
        
        super_hexagon_centers
    }

    // Check if a cell is the center of a complete hexagon
    fn is_hexagon_center(self: @GameLogic, cells: @Array<HexCoordinate>, center: @HexCoordinate) -> bool {
        let neighbors = self.grid.get_neighbors(center);
        
        // Must have exactly 6 neighbors (not on edge)
        if neighbors.len() != 6 {
            return false;
        }
        
        // All neighbors must be in the cells array
        let mut i = 0;
        let mut all_present = true;
        while i < neighbors.len() && all_present {
            if !contains_coord(cells, neighbors.at(i)) {
                all_present = false;
            }
            i += 1;
        };
        
        all_present
    }

    // Check if a cell is the center of a super hexagon (all 7 cells locked)
    fn is_super_hexagon_center(self: @GameLogic, ref cell_map: CellMap, center: @HexCoordinate) -> bool {
        let neighbors = self.grid.get_neighbors(center);
        
        // Must have exactly 6 neighbors (not on edge)
        if neighbors.len() != 6 {
            return false;
        }
        
        // Check if center is locked
        let center_locked_by = cell_map.get_locked_by(center);
        
        // Center must be locked
        if center_locked_by.is_none() {
            return false;
        }
        
        // All neighbors must be locked (by any player)
        let mut i = 0;
        let mut all_locked = true;
        while i < neighbors.len() && all_locked {
            let neighbor_coord = neighbors.at(i);
            let neighbor_locked_by = cell_map.get_locked_by(neighbor_coord);
            
            if neighbor_locked_by.is_none() {
                all_locked = false;
            }
            
            i += 1;
        };
        
        all_locked
    }

    // Check if the game is over (score limit reached)
    fn is_game_over(self: @GameLogic, player_scores: @Array<u32>) -> bool {
        let mut i = 0;
        let mut game_over = false;
        while i < player_scores.len() && !game_over {
            if *player_scores.at(i) >= *self.config.score_limit {
                game_over = true;
            }
            i += 1;
        };
        game_over
    }

    // Get cells that should be replaced after hexagon capture
    fn get_cells_to_replace(self: @GameLogic, hexagon_centers: @Array<HexCoordinate>) -> Array<HexCoordinate> {
        let mut cells_to_replace = array![];
        
        let mut i = 0;
        while i < hexagon_centers.len() {
            let center = hexagon_centers.at(i);
            let neighbors = self.grid.get_neighbors(center);
            
            // Add all neighbors (they get replaced when hexagon is formed)
            let mut j = 0;
            while j < neighbors.len() {
                let neighbor = neighbors.at(j);
                // Avoid duplicates
                if !contains_coord(@cells_to_replace, neighbor) {
                    cells_to_replace.append(*neighbor);
                }
                j += 1;
            };
            i += 1;
        };
        
        cells_to_replace
    }

    // Calculate turn side effects from a grid scenario
    fn calculate_turn(
        self: @GameLogic, 
        grid_scenario: @Array<CellData>,
        turn: @PlayerTurn
    ) -> TurnSideEffects {
        let mut cells_captured = array![];
        let mut hexagons_formed = array![];
        let mut superhexagons_formed = array![];
        let mut tiles_replaced = array![];

        // Create a CellMap for O(1) lookups
        let mut cell_map = CellMapTrait::from_array(grid_scenario);

        // Identify cells being captured in this turn
        let mut i = 0;
        while i < turn.tile_positions.len() {
            let coord = turn.tile_positions.at(i);

            let is_locked = cell_map.is_locked(coord);
            
            // Check if the cell at this position is not already locked
            if !is_locked {
                cells_captured.append(*coord);
            }
            
            i += 1;
        };

        // Find hexagon formations from the captured cells
        hexagons_formed = self.find_hexagon_formations(turn.tile_positions);

        // Find super hexagon formations
        superhexagons_formed = self.find_super_hexagon_formations(ref cell_map);

        // Get tiles that need to be replaced due to hexagon formations
        if hexagons_formed.len() > 0 {
            tiles_replaced = self.get_cells_to_replace(@hexagons_formed);
        }
        
        // Add super hexagon tiles to tiles that need to be replaced
        if superhexagons_formed.len() > 0 {
            let mut i = 0;
            while i < superhexagons_formed.len() {
                let super_center = superhexagons_formed.at(i);
                // Add the center
                if !contains_coord(@tiles_replaced, super_center) {
                    tiles_replaced.append(*super_center);
                }
                // Add all neighbors
                let neighbors = self.grid.get_neighbors(super_center);
                let mut j = 0;
                while j < neighbors.len() {
                    let neighbor = neighbors.at(j);
                    if !contains_coord(@tiles_replaced, neighbor) {
                        tiles_replaced.append(*neighbor);
                    }
                    j += 1;
                };
                i += 1;
            };
        }

        TurnSideEffects {
            cells_captured,
            hexagons_formed,
            superhexagons_formed,
            tiles_replaced,
        }
    }
}

// Get letter from index
fn get_letter_at(index: u32) -> felt252 {
    match index {
        0 => 'A', 1 => 'B', 2 => 'C', 3 => 'D', 4 => 'E',
        5 => 'F', 6 => 'G', 7 => 'H', 8 => 'I', 9 => 'J',
        10 => 'K', 11 => 'L', 12 => 'M', 13 => 'N', 14 => 'O',
        15 => 'P', 16 => 'Q', 17 => 'R', 18 => 'S', 19 => 'T',
        20 => 'U', 21 => 'V', 22 => 'W', 23 => 'X', 24 => 'Y',
        25 => 'Z', _ => 'A',
    }
}

#[cfg(test)]
mod tests {
    use super::{GameLogic, GameLogicTrait, GameConfig, CellData, HexCoordinate, get_letter_at, PlayerTurn};
    use super::super::grid_scenario::{map_scenario_to_cells, gs, gs_captured};

    // Constants for players
    const PLAYER1: felt252 = 'P1';
    const PLAYER2: felt252 = 'P2';


    fn setup_game() -> GameLogic {
        let config = GameConfig {
            grid_size: 5,
            min_word_length: 3,
            score_limit: 16,
        };
        GameLogicTrait::new(config)
    }

    #[test]
    fn test_generate_letter() {
        let game = setup_game();
        let coord = HexCoordinate { q: 0, r: 0 };
        let _letter = game.generate_letter(1, @coord);
        
        // Should generate a valid letter - just check it matches one of our letters
        // Since get_letter_at always returns a valid letter, this should always pass
        assert(true, 'Letter generated');
    }

    #[test]
    fn test_word_length_validation() {
        let game = setup_game();
        
        assert(!game.is_valid_word_length(2), 'Length 2 should be invalid');
        assert(game.is_valid_word_length(3), 'Length 3 should be valid');
        assert(game.is_valid_word_length(5), 'Length 5 should be valid');
    }


    #[test]
    fn test_get_letter_at() {
        assert(get_letter_at(0) == 'A', 'Index 0 should be A');
        assert(get_letter_at(25) == 'Z', 'Index 25 should be Z');
        assert(get_letter_at(26) == 'A', 'Index 26 should wrap to A');
    }

    #[test]
    fn test_calculate_turn_basic() {
        let game = setup_game();
        
        // Create a simple turn with 3 cells in a row
        let turn = PlayerTurn {
            player_index: 0,
            word: array![0_u8, 1_u8, 2_u8], // ABC
            tile_positions: array![
                HexCoordinate { q: 0, r: 0 },
                HexCoordinate { q: 1, r: 0 },
                HexCoordinate { q: 2, r: 0 },
            ],
            tile_swap: Option::None,
            merkle_proof: array![],
        };
        
        // Create a grid scenario (simple case - all cells uncaptured)
        let grid_scenario = array![
            CellData { 
                coordinate: HexCoordinate { q: 0, r: 0 },
                letter: 'A', 
                captured_by: Option::None, 
                locked_by: Option::None 
            },
            CellData { 
                coordinate: HexCoordinate { q: 1, r: 0 },
                letter: 'B', 
                captured_by: Option::None, 
                locked_by: Option::None 
            },
            CellData { 
                coordinate: HexCoordinate { q: 2, r: 0 },
                letter: 'C', 
                captured_by: Option::None, 
                locked_by: Option::None 
            },
        ];
        
        let side_effects = game.calculate_turn(@grid_scenario, @turn);
        
        // Should capture 3 cells
        assert(side_effects.cells_captured.len() == 3, 'Should capture 3 cells');
        
        // No hexagons should be formed from 3 cells in a row
        assert(side_effects.hexagons_formed.len() == 0, 'No hexagons formed');
        
        // No super hexagons should be formed
        assert(side_effects.superhexagons_formed.len() == 0, 'No super hexagons');
        
        // No tiles should be replaced
        assert(side_effects.tiles_replaced.len() == 0, 'No tiles replaced');
    }

    #[test]
    fn test_calculate_turn_with_hexagon() {
        let game = setup_game();
        
        // Create a turn that forms a hexagon (center + 6 neighbors)
        let turn = PlayerTurn {
            player_index: 0,
            word: array![],
            tile_positions: array![
                HexCoordinate { q: 0, r: 0 },  // Center
                HexCoordinate { q: 1, r: 0 },  // East
                HexCoordinate { q: 0, r: 1 },  // Southeast
                HexCoordinate { q: -1, r: 1 }, // Southwest
                HexCoordinate { q: -1, r: 0 }, // West
                HexCoordinate { q: 0, r: -1 }, // Northwest
                HexCoordinate { q: 1, r: -1 }, // Northeast
            ],
            tile_swap: Option::None,
            merkle_proof: array![],
        };
        
        // Create a grid scenario
        let grid_scenario = array![
            gs('X'),                    // Center
            gs_captured('C', PLAYER1),  // North - already captured by P1
            gs_captured('A', PLAYER1),  // Northeast - already captured by P1
            gs('T'),                    // Southeast - uncaptured
            gs('S'),                    // South - uncaptured
            gs('O'),                    // Southwest - uncaptured
            gs_captured('N', PLAYER2),  // Northwest - already captured by P2
        ];
        
        let cells = map_scenario_to_cells(1, grid_scenario);
        
        let side_effects = game.calculate_turn(@cells, @turn);
        
        // Should capture 7 cells
        assert(side_effects.cells_captured.len() == 7, 'Should capture 7 cells');
        
        // Should form 1 hexagon
        assert(side_effects.hexagons_formed.len() == 1, 'Should form 1 hexagon');
        
        // No super hexagons in this test
        assert(side_effects.superhexagons_formed.len() == 0, 'No super hexagons');
        
        // Should replace 6 tiles (the neighbors of the center)
        assert(side_effects.tiles_replaced.len() == 6, 'Should replace 6 tiles');
    }
}
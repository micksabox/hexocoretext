use super::types::{PlayerTurn, HexCoordinate, TileSwap, HexCoordinateTrait};
use super::hex_grid::HexGrid;
use super::cell_map::{CellMap, CellMapTrait};
use core::array::ArrayTrait;

#[derive(Drop, Copy, Debug, PartialEq, Serde)]
pub enum TurnValidationError {
    DuplicatePositions,
    NonAdjacentSwap,
    SwapWithLockedTile,
    SwapSameTile,
}

pub trait TurnValidatorTrait {
    fn validate_turn(
        turn: @PlayerTurn,
        ref cell_map: CellMap,
        grid: @HexGrid
    ) -> Result<(), TurnValidationError>;
    
    fn validate_tile_positions(positions: @Array<HexCoordinate>) -> Result<(), TurnValidationError>;
    
    fn validate_tile_swap(
        swap: @TileSwap,
        ref cell_map: CellMap
    ) -> Result<(), TurnValidationError>;
}

pub impl TurnValidator of TurnValidatorTrait {
    fn validate_turn(
        turn: @PlayerTurn,
        ref cell_map: CellMap,
        grid: @HexGrid
    ) -> Result<(), TurnValidationError> {
        // Validate tile positions
        Self::validate_tile_positions(turn.tile_positions)?;
        
        // Validate tile swap if present
        if let Option::Some(swap) = turn.tile_swap {
            Self::validate_tile_swap(swap, ref cell_map)?;
        }
        
        Result::Ok(())
    }
    
    fn validate_tile_positions(positions: @Array<HexCoordinate>) -> Result<(), TurnValidationError> {
        // Check for duplicate positions
        let mut has_duplicates = false;
        let mut i = 0;
        
        while i < positions.len() && !has_duplicates {
            let mut j = i + 1;
            while j < positions.len() && !has_duplicates {
                let pos1 = positions.at(i);
                let pos2 = positions.at(j);
                
                // Check if positions are the same
                if pos1.q == pos2.q && pos1.r == pos2.r {
                    has_duplicates = true;
                }
                
                j += 1;
            };
            i += 1;
        };
        
        if has_duplicates {
            Result::Err(TurnValidationError::DuplicatePositions)
        } else {
            Result::Ok(())
        }
    }
    
    fn validate_tile_swap(
        swap: @TileSwap,
        ref cell_map: CellMap
    ) -> Result<(), TurnValidationError> {
        // Check if swapping the same position
        if swap.from.q == swap.to.q && swap.from.r == swap.to.r {
            return Result::Err(TurnValidationError::SwapSameTile);
        }
        
        // Check if tiles are neighbors (distance of 1)
        let distance = swap.from.distance(swap.to);
        if distance != 1 {
            return Result::Err(TurnValidationError::NonAdjacentSwap);
        }
        
        // Check if either tile is locked
        if cell_map.is_locked(swap.from) || cell_map.is_locked(swap.to) {
            return Result::Err(TurnValidationError::SwapWithLockedTile);
        }
        
        Result::Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::{TurnValidator, TurnValidationError};
    use super::super::types::{HexCoordinate, PlayerTurn, TileSwap};
    use super::super::hex_grid::HexGridTrait;
    use super::super::cell_map::CellMapTrait;
    use super::super::grid_scenario::{map_scenario_to_cells, gs, gs_locked};
    
    fn create_test_turn(positions: Array<HexCoordinate>, swap: Option<TileSwap>) -> PlayerTurn {
        PlayerTurn {
            player_index: 0,
            word: array![],
            tile_positions: positions,
            tile_swap: swap,
            merkle_proof: array![],
        }
    }
    
    #[test]
    fn test_validate_unique_positions() {
        // Valid case - all positions are unique
        let positions = array![
            HexCoordinate { q: 0, r: 0 },
            HexCoordinate { q: 1, r: 0 },
            HexCoordinate { q: 2, r: 0 },
        ];
        
        let result = TurnValidator::validate_tile_positions(@positions);
        assert(result.is_ok(), 'Should accept unique positions');
    }
    
    #[test]
    fn test_validate_duplicate_positions() {
        // Invalid case - duplicate positions
        let positions = array![
            HexCoordinate { q: 0, r: 0 },
            HexCoordinate { q: 1, r: 0 },
            HexCoordinate { q: 0, r: 0 }, // Duplicate!
        ];
        
        let result = TurnValidator::validate_tile_positions(@positions);
        assert(result.is_err(), 'Should reject duplicates');
        
        if let Result::Err(error) = result {
            assert(error == TurnValidationError::DuplicatePositions, 'Wrong error type');
        }
    }
    
    #[test]
    fn test_validate_adjacent_swap() {
        // Create a simple grid scenario
        let scenario = array![
            gs('A'),  // Center (0,0)
            gs('B'),  // North (0,-1)
        ];
        
        let cells = map_scenario_to_cells(1, scenario);
        let mut cell_map = CellMapTrait::from_array(@cells);
        
        // Valid swap - adjacent tiles
        let swap = TileSwap {
            from: HexCoordinate { q: 0, r: 0 },
            to: HexCoordinate { q: 0, r: -1 },
        };
        
        let result = TurnValidator::validate_tile_swap(@swap, ref cell_map);
        assert(result.is_ok(), 'Should accept adjacent swap');
    }
    
    #[test]
    fn test_validate_non_adjacent_swap() {
        // Create a simple grid scenario
        let scenario = array![
            gs('A'),  // Center (0,0)
            gs('B'),  // North (0,-1)
            gs('C'),  // Far away (2,0)
        ];
        
        let cells = map_scenario_to_cells(1, scenario);
        let mut cell_map = CellMapTrait::from_array(@cells);
        
        // Invalid swap - non-adjacent tiles
        let swap = TileSwap {
            from: HexCoordinate { q: 0, r: 0 },
            to: HexCoordinate { q: 2, r: 0 },
        };
        
        let result = TurnValidator::validate_tile_swap(@swap, ref cell_map);
        assert(result.is_err(), 'Should reject non-adjacent');
        
        if let Result::Err(error) = result {
            assert(error == TurnValidationError::NonAdjacentSwap, 'Wrong error type');
        }
    }
    
    #[test]
    fn test_validate_swap_with_locked_tile() {
        // Create a grid with locked tiles
        let scenario = array![
            gs_locked('A', 'P1'),  // Locked tile
            gs('B'),               // Normal tile
        ];
        
        let cells = map_scenario_to_cells(1, scenario);
        let mut cell_map = CellMapTrait::from_array(@cells);
        
        // Invalid swap - trying to swap locked tile
        let swap = TileSwap {
            from: HexCoordinate { q: 0, r: 0 },  // Locked tile
            to: HexCoordinate { q: 0, r: -1 },
        };
        
        let result = TurnValidator::validate_tile_swap(@swap, ref cell_map);
        assert(result.is_err(), 'Should reject locked swap');
        
        if let Result::Err(error) = result {
            assert(error == TurnValidationError::SwapWithLockedTile, 'Wrong error type');
        }
    }
    
    #[test]
    fn test_validate_swap_same_tile() {
        // Create a simple grid scenario
        let scenario = array![gs('A')];
        let cells = map_scenario_to_cells(1, scenario);
        let mut cell_map = CellMapTrait::from_array(@cells);
        
        // Invalid swap - same position
        let swap = TileSwap {
            from: HexCoordinate { q: 0, r: 0 },
            to: HexCoordinate { q: 0, r: 0 },
        };
        
        let result = TurnValidator::validate_tile_swap(@swap, ref cell_map);
        assert(result.is_err(), 'Should reject same tile swap');
        
        if let Result::Err(error) = result {
            assert(error == TurnValidationError::SwapSameTile, 'Wrong error type');
        }
    }
    
    #[test]
    fn test_validate_complete_turn() {
        // Create a grid scenario
        let scenario = array![
            gs('C'),  // Center
            gs('A'),  // North
            gs('T'),  // Northeast
        ];
        
        let cells = map_scenario_to_cells(1, scenario);
        let mut cell_map = CellMapTrait::from_array(@cells);
        let grid = HexGridTrait::new(5);
        
        // Valid turn
        let turn = PlayerTurn {
            player_index: 0,
            word: array!['C', 'A', 'T'],
            tile_positions: array![
                HexCoordinate { q: 0, r: 0 },
                HexCoordinate { q: 0, r: -1 },
                HexCoordinate { q: 1, r: -1 },
            ],
            tile_swap: Option::None,
            merkle_proof: array![],
        };
        
        let result = TurnValidator::validate_turn(@turn, ref cell_map, @grid);
        assert(result.is_ok(), 'Should accept valid turn');
    }
}
// Tests for turn validation errors
use hexcore_logic::types::{HexCoordinate, PlayerTurn, TileSwap};
use hexcore_logic::game_logic::{GameLogic, GameLogicTrait, GameConfig};
use hexcore_logic::grid_scenario::{map_scenario_to_cells, gs, gs_locked};
use hexcore_logic::turn_validator::TurnValidationError;

// Constants for players
const PLAYER1: felt252 = 'P1';
const PLAYER2: felt252 = 'P2';

// Test helper functions
fn create_test_game() -> GameLogic {
    let config = GameConfig {
        grid_size: 5,
        min_word_length: 3,
        score_limit: 16,
    };
    GameLogicTrait::new(config)
}

#[test]
fn test_duplicate_positions_error() {
    let game = create_test_game();
    
    // Create a scenario with some tiles
    let scenario = array![
        gs('C'),  // Center (0,0)
        gs('A'),  // North (0,-1)
        gs('T'),  // Northeast (1,-1)
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Create a turn with duplicate positions
    let turn = PlayerTurn {
        player_index: 0,
        word: array!['C', 'A', 'T'],
        tile_positions: array![
            HexCoordinate { q: 0, r: 0 },   // C
            HexCoordinate { q: 0, r: -1 },  // A
            HexCoordinate { q: 0, r: 0 },   // C again - duplicate!
        ],
        tile_swap: Option::None,
        merkle_proof: array![],
    };
    
    let result = game.calculate_turn(@cells, @turn);
    assert(result.is_err(), 'Should reject duplicates');
    
    if let Result::Err(error) = result {
        assert(error == TurnValidationError::DuplicatePositions, 'Wrong error type');
    }
}

#[test]
fn test_non_adjacent_swap_error() {
    let game = create_test_game();
    
    // Create a scenario with tiles far apart
    let scenario = array![
        gs('A'),  // Center (0,0)
        gs('B'),  // North (0,-1)
        gs('C'),  // Far position (2,0)
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Create a turn with non-adjacent swap
    let turn = PlayerTurn {
        player_index: 0,
        word: array![],
        tile_positions: array![],
        tile_swap: Option::Some(TileSwap {
            from: HexCoordinate { q: 0, r: 0 },   // Center
            to: HexCoordinate { q: 2, r: 0 },     // Far away - not adjacent!
        }),
        merkle_proof: array![],
    };
    
    let result = game.calculate_turn(@cells, @turn);
    assert(result.is_err(), 'Should reject non-adjacent');
    
    if let Result::Err(error) = result {
        assert(error == TurnValidationError::NonAdjacentSwap, 'Wrong error type');
    }
}

#[test]
fn test_swap_with_locked_tile_error() {
    let game = create_test_game();
    
    // Create a scenario with a locked tile
    let scenario = array![
        gs_locked('A', PLAYER1),  // Center - locked
        gs('B'),                  // North - not locked
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Create a turn trying to swap a locked tile
    let turn = PlayerTurn {
        player_index: 0,
        word: array![],
        tile_positions: array![],
        tile_swap: Option::Some(TileSwap {
            from: HexCoordinate { q: 0, r: 0 },   // Locked tile
            to: HexCoordinate { q: 0, r: -1 },    // Normal tile
        }),
        merkle_proof: array![],
    };
    
    let result = game.calculate_turn(@cells, @turn);
    assert(result.is_err(), 'Should reject locked swap');
    
    if let Result::Err(error) = result {
        assert(error == TurnValidationError::SwapWithLockedTile, 'Wrong error type');
    }
}

#[test]
fn test_swap_same_tile_error() {
    let game = create_test_game();
    
    // Create a simple scenario
    let scenario = array![gs('A')];
    let cells = map_scenario_to_cells(1, scenario);
    
    // Create a turn trying to swap a tile with itself
    let turn = PlayerTurn {
        player_index: 0,
        word: array![],
        tile_positions: array![],
        tile_swap: Option::Some(TileSwap {
            from: HexCoordinate { q: 0, r: 0 },
            to: HexCoordinate { q: 0, r: 0 },  // Same position!
        }),
        merkle_proof: array![],
    };
    
    let result = game.calculate_turn(@cells, @turn);
    assert(result.is_err(), 'Should reject same tile');
    
    if let Result::Err(error) = result {
        assert(error == TurnValidationError::SwapSameTile, 'Wrong error type');
    }
}

#[test]
fn test_valid_turn_with_swap() {
    let game = create_test_game();
    
    // Create a scenario with adjacent tiles
    let scenario = array![
        gs('C'),  // Center (0,0)
        gs('A'),  // North (0,-1) - adjacent to center
        gs('T'),  // Northeast (1,-1)
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Create a valid turn with adjacent swap
    let turn = PlayerTurn {
        player_index: 0,
        word: array!['A', 'C', 'T'],  // After swap: A at center, C at north
        tile_positions: array![
            HexCoordinate { q: 0, r: 0 },   // A (after swap)
            HexCoordinate { q: 0, r: -1 },  // C (after swap)
            HexCoordinate { q: 1, r: -1 },  // T
        ],
        tile_swap: Option::Some(TileSwap {
            from: HexCoordinate { q: 0, r: 0 },   // Center
            to: HexCoordinate { q: 0, r: -1 },    // North - adjacent!
        }),
        merkle_proof: array![],
    };
    
    let result = game.calculate_turn(@cells, @turn);
    assert(result.is_ok(), 'Valid turn should succeed');
}
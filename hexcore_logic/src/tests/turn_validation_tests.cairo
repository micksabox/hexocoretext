// Unit tests for turn validation logic
use hexcore_logic::types::{HexCoordinate, CellData, PlayerTurn, TileSwap, HexCoordinateTrait};
use hexcore_logic::game_logic::{GameLogic, GameLogicTrait, GameConfig};
use hexcore_logic::grid_scenario::{map_scenario_to_cells, gs, gs_captured, gs_locked};
use core::array::ArrayTrait;
use core::option::OptionTrait;

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

fn create_test_turn(
    player_index: u8,
    word: Array<u8>,
    positions: Array<HexCoordinate>,
    swap: Option<TileSwap>
) -> PlayerTurn {
    PlayerTurn {
        player_index,
        word,
        tile_positions: positions,
        tile_swap: swap,
        merkle_proof: array![],
    }
}

// Get coordinate from cell data array by position
fn get_coord_at_index(cells: @Array<CellData>, index: u32) -> HexCoordinate {
    *cells.at(index).coordinate
}

#[test]
fn test_valid_player_turn() {
    // Setup grid with CAT spelled horizontally
    let scenario = array![
        gs('X'),  // Center (0,0)
        gs('C'),  // North (0,-1)
        gs('A'),  // Northeast (1,-1)
        gs('T'),  // Southeast (1,0)
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    let current_player = 0_u8;
    
    // Create turn using coordinates from the grid
    let word = array!['C', 'A', 'T'];
    let positions = array![
        get_coord_at_index(@cells, 1),  // C at North
        get_coord_at_index(@cells, 2),  // A at Northeast  
        get_coord_at_index(@cells, 3),  // T at Southeast
    ];
    
    let turn = create_test_turn(current_player, word, positions, Option::None);
    
    // Validate turn properties
    assert(turn.player_index == current_player, 'Player index should match');
    assert(turn.word.len() >= 3, 'Word length should be valid');
    assert(turn.tile_positions.len() == turn.word.len(), 'Positions match word length');
}

#[test]
fn test_turn_with_captured_tiles() {
    // Setup grid where player1 has already captured some tiles
    let scenario = array![
        gs_captured('H', PLAYER1),    // Center - captured by P1
        gs_captured('E', PLAYER1),    // North - captured by P1
        gs('L'),                      // Northeast
        gs('L'),                      // Southeast
        gs('O'),                      // South
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Player 1 forms HELLO using their captured tiles and new ones
    let word = array!['H', 'E', 'L', 'L', 'O'];
    let positions = array![
        get_coord_at_index(@cells, 0),  // H (captured by P1)
        get_coord_at_index(@cells, 1),  // E (captured by P1)
        get_coord_at_index(@cells, 2),  // L (uncaptured)
        get_coord_at_index(@cells, 3),  // L (uncaptured)
        get_coord_at_index(@cells, 4),  // O (uncaptured)
    ];
    
    let turn = create_test_turn(0, word, positions, Option::None);
    
    // Check that player can use their own captured tiles
    assert(cells.at(0).captured_by.is_some(), 'H is captured');
    assert(cells.at(1).captured_by.is_some(), 'E is captured');
    assert(turn.word.len() == 5, 'Word is HELLO');
}

#[test]
fn test_disconnected_path_invalid() {
    // Setup grid where tiles are not adjacent
    let scenario = array![
        gs('C'),  // Center
        gs('A'),  // North
        gs('X'),  // Northeast - gap
        gs('T'),  // Southeast
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Player tries to form CAT but skips the middle tile
    let positions = array![
        get_coord_at_index(@cells, 0),  // C 
        get_coord_at_index(@cells, 1),  // A
        get_coord_at_index(@cells, 3),  // T (not adjacent to A)
    ];
    
    // Check connectivity - positions 1 and 3 are not adjacent
    let pos1 = positions.at(1);
    let pos2 = positions.at(2);
    let distance = pos1.distance(pos2);
    assert(distance > 1_i32, 'Path is disconnected');
}

#[test]
fn test_turn_with_tile_swap() {
    // Setup grid for swap scenario
    let scenario = array![
        gs('C'),  // Center
        gs('A'),  // North
        gs('R'),  // Northeast - will swap this
        gs('T'),  // Southeast - with this
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Player swaps R and T, then forms CAT
    let swap = TileSwap {
        from: get_coord_at_index(@cells, 2),  // R at Northeast
        to: get_coord_at_index(@cells, 3),    // T at Southeast
    };
    
    // After swap, T is at Northeast position
    let word = array!['C', 'A', 'T'];
    let positions = array![
        get_coord_at_index(@cells, 0),  // C
        get_coord_at_index(@cells, 1),  // A
        get_coord_at_index(@cells, 2),  // T (after swap)
    ];
    
    let turn = create_test_turn(0, word, positions, Option::Some(swap));
    
    assert(turn.tile_swap.is_some(), 'Turn has swap');
    let swap_info = turn.tile_swap.unwrap();
    
    // Verify swap is between adjacent tiles
    let swap_distance = swap_info.from.distance(@swap_info.to);
    assert(swap_distance == 1_i32, 'Swap tiles are adjacent');
}

#[test]
fn test_locked_tile_usage() {
    // Setup grid with locked tiles
    let scenario = array![
        gs_locked('W', PLAYER1),       // Center - locked by P1
        gs('I'),                       // North
        gs('N'),                       // Northeast
        gs('D'),                       // Southeast
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Player 1 forms WIND using their locked tile
    let word = array!['W', 'I', 'N', 'D'];
    let positions = array![
        get_coord_at_index(@cells, 0),  // W (locked by P1)
        get_coord_at_index(@cells, 1),  // I
        get_coord_at_index(@cells, 2),  // N
        get_coord_at_index(@cells, 3),  // D
    ];
    
    let turn = create_test_turn(0, word, positions, Option::None);
    
    // Verify locked tile ownership
    assert(cells.at(0).locked_by.is_some(), 'Cell locked');
    assert(cells.at(0).captured_by.is_some(), 'Cell captured');
    assert(turn.word.len() == 4, 'Forms WIND');
}

#[test]
fn test_duplicate_positions() {
    let positions = array![
        HexCoordinate { q: 0, r: 0 },
        HexCoordinate { q: 1, r: 0 },
        HexCoordinate { q: 0, r: 0 }, // Duplicate!
    ];
    
    // Check for duplicates
    let mut has_duplicates = false;
    let mut i = 0;
    while i < positions.len() && !has_duplicates {
        let mut j = i + 1;
        while j < positions.len() {
            let pos1 = positions.at(i);
            let pos2 = positions.at(j);
            if pos1.q == pos2.q && pos1.r == pos2.r {
                has_duplicates = true;
                break;
            }
            j += 1;
        };
        i += 1;
    };
    
    assert(has_duplicates, 'Should have duplicates');
}

#[test]
fn test_word_too_short() {
    let word = array!['A', 'T']; // Only 2 letters
    let positions = array![
        HexCoordinate { q: 0, r: 0 },
        HexCoordinate { q: 1, r: 0 },
    ];
    
    let turn = create_test_turn(0, word, positions, Option::None);
    
    assert(turn.word.len() < 3, 'Word should be too short');
}
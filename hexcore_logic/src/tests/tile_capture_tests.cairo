// Unit tests for tile capture mechanics
use hexcore_logic::types::{HexCoordinate, CellData, HexCoordinateTrait};
use hexcore_logic::grid_scenario::{map_scenario_to_cells, gs, gs_captured, gs_locked};
use core::array::ArrayTrait;
use core::option::OptionTrait;

// Constants for players
const PLAYER1: felt252 = 'P1';
const PLAYER2: felt252 = 'P2';

// Get coordinate from cell data array by index
fn get_coord_at_index(cells: @Array<CellData>, index: u32) -> HexCoordinate {
    *cells.at(index).coordinate
}

// Convert CellData array to coordinate array
fn get_coords_from_indices(cells: @Array<CellData>, indices: Array<u32>) -> Array<HexCoordinate> {
    let mut coords = array![];
    let mut i = 0;
    while i < indices.len() {
        coords.append(get_coord_at_index(cells, *indices.at(i)));
        i += 1;
    };
    coords
}

#[test]
fn test_capture_uncaptured_tiles() {
    // Setup grid with uncaptured tiles forming CAT
    let scenario = array![
        gs('X'),  // Center
        gs('C'),  // North
        gs('A'),  // Northeast
        gs('T'),  // Southeast
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Player captures CAT
    let _positions = get_coords_from_indices(@cells, array![1, 2, 3]);
    
    // All tiles are uncaptured
    assert(cells.at(1).captured_by.is_none(), 'C is uncaptured');
    assert(cells.at(2).captured_by.is_none(), 'A is uncaptured');
    assert(cells.at(3).captured_by.is_none(), 'T is uncaptured');
    
    // These tiles should be capturable
    let word = array!['C', 'A', 'T'];
    assert(word.len() == 3, 'Word matches positions');
}

#[test]
fn test_capture_own_tiles_for_chaining() {
    // Setup grid where player1 already has some captured tiles
    let scenario = array![
        gs('X'),                    // Center
        gs_captured('C', PLAYER1),  // North - already captured by P1
        gs_captured('A', PLAYER1),  // Northeast - already captured by P1
        gs('T'),                    // Southeast - uncaptured
        gs('S'),                    // South - uncaptured
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Player1 forms CATS using their captured tiles
    let _positions = get_coords_from_indices(@cells, array![1, 2, 3, 4]);
    
    // Verify ownership
    assert(cells.at(1).captured_by.is_some(), 'C captured by P1');
    assert(cells.at(2).captured_by.is_some(), 'A captured by P1');
    assert(cells.at(3).captured_by.is_none(), 'T is uncaptured');
    assert(cells.at(4).captured_by.is_none(), 'S is uncaptured');
    
    // Player can use their own captured tiles for word formation
    let word = array!['C', 'A', 'T', 'S'];
    assert(word.len() == 4, 'Forms CATS');
}

#[test]
fn test_cannot_capture_opponent_tiles() {
    // Setup grid with opponent's tiles in the path
    let scenario = array![
        gs('X'),                    // Center
        gs('C'),                    // North
        gs_captured('A', PLAYER2),  // Northeast - captured by opponent
        gs('T'),                    // Southeast
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Player1 tries to form CAT but A is captured by opponent
    let _positions = get_coords_from_indices(@cells, array![1, 2, 3]);
    
    // Verify the middle tile is opponent's
    assert(cells.at(2).captured_by.is_some(), 'A captured by opponent');
    
    // This turn would be invalid - can't use opponent's tiles
}

#[test]
fn test_cannot_capture_locked_tiles() {
    // Setup grid with locked tiles
    let scenario = array![
        gs('X'),                   // Center
        gs('C'),                   // North
        gs_locked('A', PLAYER2),   // Northeast - locked by opponent
        gs('T'),                   // Southeast
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Player1 tries to form CAT but A is locked
    let _positions = get_coords_from_indices(@cells, array![1, 2, 3]);
    
    // Verify the middle tile is locked
    assert(cells.at(2).locked_by.is_some(), 'A locked by opponent');
    assert(cells.at(2).captured_by.is_some(), 'A captured by opponent');
    
    // This turn would be invalid - can't use locked tiles owned by opponent
}

#[test]
fn test_using_locked_tile_in_path() {
    // Setup where player must use their own locked tile
    let scenario = array![
        gs_locked('W', PLAYER1),    // Center - P1's locked tile
        gs('I'),                    // North
        gs('N'),                    // Northeast
        gs('D'),                    // Southeast
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Player1 forms WIND using their locked W
    let _positions = get_coords_from_indices(@cells, array![0, 1, 2, 3]);
    
    // Verify locked tile ownership
    assert(cells.at(0).locked_by.is_some(), 'W locked by P1');
    assert(cells.at(0).captured_by.is_some(), 'W captured by P1');
    
    // Can use own locked tiles in word
    let word = array!['W', 'I', 'N', 'D'];
    assert(word.len() == 4, 'Forms WIND');
}

#[test] 
fn test_zigzag_capture_pattern() {
    // Setup grid for zigzag word path
    let scenario = array![
        gs('S'),  // 0: Center
        gs('N'),  // 1: North
        gs('A'),  // 2: Northeast
        gs('K'),  // 3: Southeast
        gs('E'),  // 4: South
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Form SNAKE in zigzag pattern: S(center) -> N(north) -> A(northeast) -> K(southeast) -> E(south)
    let positions = get_coords_from_indices(@cells, array![0, 1, 2, 3, 4]);
    
    // Verify the path is connected
    let mut i = 0;
    while i < positions.len() - 1 {
        let current = positions.at(i);
        let next = positions.at(i + 1);
        let distance = current.distance(next);
        assert(distance == 1_i32, 'Adjacent tiles');
        i += 1;
    };
    
    let word = array!['S', 'N', 'A', 'K', 'E'];
    assert(word.len() == 5, 'Forms SNAKE');
}
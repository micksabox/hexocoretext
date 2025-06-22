mod test_utils;
mod game_tests;

use crate::models::{Direction, HexCoordinate};
use crate::hex_logic::{
    get_neighbors, get_neighbor_in_direction, is_valid_coordinate, abs, are_neighbors, 
    are_cells_connected, hex_distance
};

#[test]
fn test_hex_coordinate_neighbors() {
    let center = HexCoordinate { q: 0, r: 0 };
    let neighbors = get_neighbors(center);
    
    assert(neighbors.len() == 6, 'Should have 6 neighbors');
    
    // Test all 6 neighbors in the order: North, Northeast, Southeast, South, Southwest, Northwest
    let north = *neighbors[0];
    assert(north.q == 0 && north.r == -1, 'North neighbor');
    
    let northeast = *neighbors[1];
    assert(northeast.q == 1 && northeast.r == -1, 'Northeast neighbor');
    
    let southeast = *neighbors[2];
    assert(southeast.q == 1 && southeast.r == 0, 'Southeast neighbor');
    
    let south = *neighbors[3];
    assert(south.q == 0 && south.r == 1, 'South neighbor');
    
    let southwest = *neighbors[4];
    assert(southwest.q == -1 && southwest.r == 1, 'Southwest neighbor');
    
    let northwest = *neighbors[5];
    assert(northwest.q == -1 && northwest.r == 0, 'Northwest neighbor');
    
    // Verify s coordinate constraint (q + r + s = 0)
    assert(center.q + center.r + (-center.q - center.r) == 0, 'Invalid center coordinate');
    assert(north.q + north.r + (-north.q - north.r) == 0, 'Invalid north coordinate');
}

#[test]
fn test_valid_coordinates() {
    let grid_size = 2;
    
    // Valid coordinates for grid_size = 2
    let valid_coords = array![
        HexCoordinate { q: 0, r: 0 },     // Center
        HexCoordinate { q: 1, r: 0 },     // Valid
        HexCoordinate { q: 0, r: 1 },     // Valid
        HexCoordinate { q: -1, r: 0 },    // Valid
        HexCoordinate { q: 0, r: -1 },    // Valid
        HexCoordinate { q: 1, r: -1 },    // Valid
        HexCoordinate { q: -1, r: 1 },    // Valid
        HexCoordinate { q: 2, r: -2 },    // Edge
        HexCoordinate { q: -2, r: 2 },    // Edge
    ];
    
    let mut i = 0;
    while i < valid_coords.len() {
        let coord = *valid_coords[i];
        assert(is_valid_coordinate(coord, grid_size), 'Coordinate should be valid');
        i += 1;
    };
}

#[test]
fn test_invalid_coordinates() {
    let grid_size = 2;
    
    // Invalid coordinates for grid_size = 2
    let invalid_coords = array![
        HexCoordinate { q: 3, r: 0 },     // Too far east
        HexCoordinate { q: 0, r: 3 },     // Too far southeast
        HexCoordinate { q: -3, r: 0 },    // Too far west
        HexCoordinate { q: 2, r: 1 },     // Invalid combination
    ];
    
    let mut i = 0;
    while i < invalid_coords.len() {
        let coord = *invalid_coords[i];
        assert(!is_valid_coordinate(coord, grid_size), 'Coordinate should be invalid');
        i += 1;
    };
}

#[test]
fn test_are_neighbors() {
    let center = HexCoordinate { q: 0, r: 0 };
    let southeast = HexCoordinate { q: 1, r: 0 };  // Southeast in new system
    let northeast = HexCoordinate { q: 1, r: -1 };
    let far_away = HexCoordinate { q: 3, r: 3 };
    
    assert(are_neighbors(center, southeast), 'Center and SE are neighbors');
    assert(are_neighbors(center, northeast), 'Center and NE are neighbors');
    assert(are_neighbors(southeast, northeast), 'SE and NE are neighbors');
    assert(!are_neighbors(center, far_away), 'Center and far not neighbors');
}

#[test]
fn test_connected_cells() {
    // Test a simple connected path
    let connected_cells = array![
        HexCoordinate { q: 0, r: 0 },
        HexCoordinate { q: 1, r: 0 },
        HexCoordinate { q: 1, r: -1 },
    ];
    
    assert(are_cells_connected(@connected_cells), 'Cells should be connected');
    
    // Test disconnected cells
    let disconnected_cells = array![
        HexCoordinate { q: 0, r: 0 },
        HexCoordinate { q: 2, r: 0 },  // Not neighbor to center
        HexCoordinate { q: 3, r: 0 },
    ];
    
    assert(!are_cells_connected(@disconnected_cells), 'Cells should not be connected');
}

#[test]
fn test_hex_distance() {
    let a = HexCoordinate { q: 0, r: 0 };
    let b = HexCoordinate { q: 2, r: -1 };
    
    assert(hex_distance(a, b) == 2, 'Distance should be 2');
    
    let c = HexCoordinate { q: -1, r: 2 };
    assert(hex_distance(a, c) == 2, 'Distance should be 2');
    
    // Same position
    assert(hex_distance(a, a) == 0, 'Distance to self should be 0');
}

#[test]
fn test_abs_function() {
    assert(abs(5) == 5, 'Positive number');
    assert(abs(-5) == 5, 'Negative number');
    assert(abs(0) == 0, 'Zero');
}

#[test]
fn test_cube_constraint() {
    // Test that q + r + s = 0 for all valid coordinates
    let coords = array![
        HexCoordinate { q: 0, r: 0 },     // s = 0
        HexCoordinate { q: 1, r: -1 },    // s = 0
        HexCoordinate { q: -1, r: 2 },    // s = -1
        HexCoordinate { q: 2, r: -2 },    // s = 0
    ];
    
    let mut i = 0;
    while i < coords.len() {
        let coord = *coords[i];
        let s = -coord.q - coord.r;
        assert(coord.q + coord.r + s == 0, 'Cube constraint violated');
        i += 1;
    };
}

#[test]
fn test_get_neighbor_in_direction() {
    let center = HexCoordinate { q: 0, r: 0 };
    
    // Test each direction according to PRD spec
    let north = get_neighbor_in_direction(center, Direction::North);
    assert(north.q == 0 && north.r == -1, 'North direction');
    
    let northeast = get_neighbor_in_direction(center, Direction::Northeast);
    assert(northeast.q == 1 && northeast.r == -1, 'Northeast direction');
    
    let southeast = get_neighbor_in_direction(center, Direction::Southeast);
    assert(southeast.q == 1 && southeast.r == 0, 'Southeast direction');
    
    let south = get_neighbor_in_direction(center, Direction::South);
    assert(south.q == 0 && south.r == 1, 'South direction');
    
    let southwest = get_neighbor_in_direction(center, Direction::Southwest);
    assert(southwest.q == -1 && southwest.r == 1, 'Southwest direction');
    
    let northwest = get_neighbor_in_direction(center, Direction::Northwest);
    assert(northwest.q == -1 && northwest.r == 0, 'Northwest direction');
    
    // Test from a different position
    let pos = HexCoordinate { q: 2, r: -1 };
    let pos_north = get_neighbor_in_direction(pos, Direction::North);
    assert(pos_north.q == 2 && pos_north.r == -2, 'North from (2,-1)');
}
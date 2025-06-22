use super::models::{HexCoordinate, Direction};

// Get all 6 neighbors of a hex cell
pub fn get_neighbors(coord: HexCoordinate) -> Array<HexCoordinate> {
    let mut neighbors = array![];
    
    // North
    neighbors.append(HexCoordinate { q: coord.q, r: coord.r - 1 });
    // Northeast
    neighbors.append(HexCoordinate { q: coord.q + 1, r: coord.r - 1 });
    // Southeast
    neighbors.append(HexCoordinate { q: coord.q + 1, r: coord.r });
    // South
    neighbors.append(HexCoordinate { q: coord.q, r: coord.r + 1 });
    // Southwest
    neighbors.append(HexCoordinate { q: coord.q - 1, r: coord.r + 1 });
    // Northwest
    neighbors.append(HexCoordinate { q: coord.q - 1, r: coord.r });
    
    neighbors
}

// Get neighbor in a specific direction
pub fn get_neighbor_in_direction(coord: HexCoordinate, direction: Direction) -> HexCoordinate {
    match direction {
        Direction::North => HexCoordinate { q: coord.q, r: coord.r - 1 },
        Direction::Northeast => HexCoordinate { q: coord.q + 1, r: coord.r - 1 },
        Direction::Southeast => HexCoordinate { q: coord.q + 1, r: coord.r },
        Direction::South => HexCoordinate { q: coord.q, r: coord.r + 1 },
        Direction::Southwest => HexCoordinate { q: coord.q - 1, r: coord.r + 1 },
        Direction::Northwest => HexCoordinate { q: coord.q - 1, r: coord.r },
    }
}

// Check if a coordinate is within the hex grid bounds
pub fn is_valid_coordinate(coord: HexCoordinate, grid_size: i32) -> bool {
    let s = -coord.q - coord.r;
    abs(coord.q) <= grid_size && abs(coord.r) <= grid_size && abs(s) <= grid_size
}

// Helper function for absolute value
pub fn abs(value: i32) -> i32 {
    if value < 0 {
        -value
    } else {
        value
    }
}

// Check if two coordinates are neighbors
pub fn are_neighbors(a: HexCoordinate, b: HexCoordinate) -> bool {
    let neighbors = get_neighbors(a);
    let mut i = 0;
    let mut found = false;
    while i < neighbors.len() && !found {
        let neighbor = *neighbors[i];
        if neighbor.q == b.q && neighbor.r == b.r {
            found = true;
        }
        i += 1;
    };
    found
}

// Check if an array of cells forms a connected path
pub fn are_cells_connected(cells: @Array<HexCoordinate>) -> bool {
    if cells.len() == 0 {
        return false;
    }
    
    if cells.len() == 1 {
        return true;
    }
    
    // Check each cell is neighbor to at least one other cell
    let mut i = 0;
    let mut all_connected = true;
    while i < cells.len() && all_connected {
        let current = *cells[i];
        let mut has_neighbor = false;
        
        let mut j = 0;
        while j < cells.len() && !has_neighbor {
            if i != j {
                let other = *cells[j];
                if are_neighbors(current, other) {
                    has_neighbor = true;
                }
            }
            j += 1;
        };
        
        if !has_neighbor {
            all_connected = false;
        }
        i += 1;
    };
    
    all_connected
}

// Calculate distance between two hex coordinates
pub fn hex_distance(a: HexCoordinate, b: HexCoordinate) -> i32 {
    let dq = abs(a.q - b.q);
    let dr = abs(a.r - b.r);
    let ds = abs((-a.q - a.r) - (-b.q - b.r));
    (dq + dr + ds) / 2
}
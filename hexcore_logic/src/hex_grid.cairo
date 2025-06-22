use super::types::{HexCoordinate, Direction, HexCoordinateTrait};

// Helper function for absolute value
fn abs(value: i32) -> i32 {
    if value < 0 {
        -value
    } else {
        value
    }
}

// Direction vectors for hexagonal neighbors
pub fn get_direction_vector(direction: Direction) -> HexCoordinate {
    match direction {
        Direction::North => HexCoordinate { q: 0, r: -1 },
        Direction::Northeast => HexCoordinate { q: 1, r: -1 },
        Direction::Southeast => HexCoordinate { q: 1, r: 0 },
        Direction::South => HexCoordinate { q: 0, r: 1 },
        Direction::Southwest => HexCoordinate { q: -1, r: 1 },
        Direction::Northwest => HexCoordinate { q: -1, r: 0 },
    }
}

#[derive(Drop)]
pub struct HexGrid {
    pub size: u8,
}

#[generate_trait]
pub impl HexGridImpl of HexGridTrait {
    fn new(size: u8) -> HexGrid {
        HexGrid { size }
    }

    fn is_valid_coordinate(self: @HexGrid, coord: @HexCoordinate) -> bool {
        let size_i32: i32 = (*self.size).into();
        let s = coord.s();
        abs(*coord.q) <= size_i32 && abs(*coord.r) <= size_i32 && abs(s) <= size_i32
    }

    fn get_neighbors(self: @HexGrid, coord: @HexCoordinate) -> Array<HexCoordinate> {
        let mut neighbors = array![];
        
        // All six directions
        neighbors.append(coord.add(@get_direction_vector(Direction::North)));
        neighbors.append(coord.add(@get_direction_vector(Direction::Northeast)));
        neighbors.append(coord.add(@get_direction_vector(Direction::Southeast)));
        neighbors.append(coord.add(@get_direction_vector(Direction::South)));
        neighbors.append(coord.add(@get_direction_vector(Direction::Southwest)));
        neighbors.append(coord.add(@get_direction_vector(Direction::Northwest)));
        
        // Filter out invalid coordinates
        let mut valid_neighbors = array![];
        let mut i = 0;
        while i < neighbors.len() {
            let neighbor = *neighbors.at(i);
            if self.is_valid_coordinate(@neighbor) {
                valid_neighbors.append(neighbor);
            }
            i += 1;
        };
        
        valid_neighbors
    }

    fn are_neighbors(self: @HexGrid, coord1: @HexCoordinate, coord2: @HexCoordinate) -> bool {
        coord1.distance(coord2) == 1
    }

    fn are_cells_connected(self: @HexGrid, cells: @Array<HexCoordinate>) -> bool {
        if cells.len() == 0 {
            return false;
        }
        
        // Use DFS to check connectivity
        let mut visited = array![];
        let mut to_visit = array![*cells.at(0)];
        
        while to_visit.len() > 0 {
            let current = to_visit.pop_front().unwrap();
            
            if contains_coord(@visited, @current) {
                continue;
            }
            
            visited.append(current);
            
            let neighbors = self.get_neighbors(@current);
            let mut i = 0;
            while i < neighbors.len() {
                let neighbor = *neighbors.at(i);
                if contains_coord(cells, @neighbor) && !contains_coord(@visited, @neighbor) {
                    to_visit.append(neighbor);
                }
                i += 1;
            };
        };
        
        visited.len() == cells.len()
    }

    fn get_all_coordinates(self: @HexGrid) -> Array<HexCoordinate> {
        let mut coords = array![];
        let size_i32: i32 = (*self.size).into();
        
        let mut q = -size_i32;
        while q <= size_i32 {
            let mut r = -size_i32;
            while r <= size_i32 {
                let coord = HexCoordinate { q, r };
                if self.is_valid_coordinate(@coord) {
                    coords.append(coord);
                }
                r += 1;
            };
            q += 1;
        };
        
        coords
    }

    // Check if a set of cells forms a hexagon pattern
    fn check_hexagon_pattern(self: @HexGrid, cells: @Array<HexCoordinate>) -> Option<HexCoordinate> {
        if cells.len() < 7 {
            return Option::None;
        }

        // For each cell, check if it could be the center of a hexagon
        let mut result = Option::None;
        let mut i = 0;
        let mut found = false;
        
        while i < cells.len() && !found {
            let potential_center = cells.at(i);
            let neighbors = self.get_neighbors(potential_center);
            
            // Check if all 6 neighbors are in the cells array
            let mut all_neighbors_present = true;
            let mut j = 0;
            while j < neighbors.len() {
                if !contains_coord(cells, neighbors.at(j)) {
                    all_neighbors_present = false;
                    break;
                }
                j += 1;
            };
            
            if all_neighbors_present && neighbors.len() == 6 {
                result = Option::Some(*potential_center);
                found = true;
            }
            
            i += 1;
        };
        
        result
    }
}

// Helper function to check if a coordinate is in an array
pub fn contains_coord(coords: @Array<HexCoordinate>, target: @HexCoordinate) -> bool {
    let mut i = 0;
    let mut found = false;
    while i < coords.len() && !found {
        let coord = coords.at(i);
        if coord.q == target.q && coord.r == target.r {
            found = true;
        }
        i += 1;
    };
    found
}

#[cfg(test)]
mod tests {
    use super::{HexGridTrait, HexCoordinate, contains_coord};

    #[test]
    fn test_is_valid_coordinate() {
        let grid = HexGridTrait::new(3);
        
        // Test center
        assert(grid.is_valid_coordinate(@HexCoordinate { q: 0, r: 0 }), 'Center should be valid');
        
        // Test edges
        assert(grid.is_valid_coordinate(@HexCoordinate { q: 3, r: 0 }), 'Edge (3,0) valid');
        assert(grid.is_valid_coordinate(@HexCoordinate { q: 0, r: 3 }), 'Edge (0,3) valid');
        assert(grid.is_valid_coordinate(@HexCoordinate { q: -3, r: 3 }), 'Edge (-3,3) valid');
        
        // Test invalid
        assert(!grid.is_valid_coordinate(@HexCoordinate { q: 4, r: 0 }), 'Beyond edge invalid');
        assert(!grid.is_valid_coordinate(@HexCoordinate { q: 2, r: 2 }), '(2,2) invalid - s=4');
    }

    #[test]
    fn test_get_neighbors() {
        let grid = HexGridTrait::new(5);
        let center = HexCoordinate { q: 0, r: 0 };
        let neighbors = grid.get_neighbors(@center);
        
        assert(neighbors.len() == 6, 'Should have 6 neighbors');
        
        // Check specific neighbors
        assert(contains_coord(@neighbors, @HexCoordinate { q: 0, r: -1 }), 'North neighbor');
        assert(contains_coord(@neighbors, @HexCoordinate { q: 1, r: -1 }), 'Northeast neighbor');
        assert(contains_coord(@neighbors, @HexCoordinate { q: 1, r: 0 }), 'Southeast neighbor');
        assert(contains_coord(@neighbors, @HexCoordinate { q: 0, r: 1 }), 'South neighbor');
        assert(contains_coord(@neighbors, @HexCoordinate { q: -1, r: 1 }), 'Southwest neighbor');
        assert(contains_coord(@neighbors, @HexCoordinate { q: -1, r: 0 }), 'Northwest neighbor');
    }

    #[test]
    fn test_are_cells_connected() {
        let grid = HexGridTrait::new(5);
        
        // Test connected line
        let connected = array![
            HexCoordinate { q: 0, r: 0 },
            HexCoordinate { q: 1, r: 0 },
            HexCoordinate { q: 2, r: 0 }
        ];
        assert(grid.are_cells_connected(@connected), 'Line should be connected');
        
        // Test disconnected cells
        let disconnected = array![
            HexCoordinate { q: 0, r: 0 },
            HexCoordinate { q: 2, r: 0 },  // Gap at (1,0)
            HexCoordinate { q: 3, r: 0 }
        ];
        assert(!grid.are_cells_connected(@disconnected), 'Should be disconnected');
    }

    #[test]
    fn test_hexagon_pattern() {
        let grid = HexGridTrait::new(5);
        
        // Create a hexagon pattern
        let hexagon = array![
            HexCoordinate { q: 0, r: 0 },   // Center
            HexCoordinate { q: 0, r: -1 },  // North
            HexCoordinate { q: 1, r: -1 },  // Northeast
            HexCoordinate { q: 1, r: 0 },   // Southeast
            HexCoordinate { q: 0, r: 1 },   // South
            HexCoordinate { q: -1, r: 1 },  // Southwest
            HexCoordinate { q: -1, r: 0 },  // Northwest
        ];
        
        let center = grid.check_hexagon_pattern(@hexagon);
        assert(center.is_some(), 'Should detect hexagon');
        assert(center.unwrap().q == 0 && center.unwrap().r == 0, 'Center should be (0,0)');
    }
}


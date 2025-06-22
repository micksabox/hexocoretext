use super::types::HexCoordinate;

// Generate coordinates in spiral pattern from center outward
// This is used by test utilities to map flat arrays to hex grid positions
pub fn generate_spiral_coordinates(grid_size: u8) -> Array<HexCoordinate> {
    let mut coords = array![];
    
    let grid_size_i32: i32 = grid_size.into();
    
    // Add rings outward starting from center
    let mut ring = 0;
    
    while ring <= grid_size_i32 {
        if ring == 0 {
            // Just add the center
            coords.append(HexCoordinate { q: 0, r: 0 });
        } else {
            // Starting position for each ring (move North from center by 'ring' steps)
            let mut q = 0;
            let mut r = -ring;
            
            // For each of the 6 sides of the hexagon
            let directions = array![
                HexCoordinate { q: 1, r: 0 },   // Southeast
                HexCoordinate { q: 0, r: 1 },   // South
                HexCoordinate { q: -1, r: 1 },  // Southwest
                HexCoordinate { q: -1, r: 0 },  // Northwest
                HexCoordinate { q: 0, r: -1 },  // North
                HexCoordinate { q: 1, r: -1 },  // Northeast
            ];
            
            let mut dir_idx = 0;
            while dir_idx < 6 {
                let direction = *directions.at(dir_idx);
                let steps = ring;
                
                let mut step = 0;
                while step < steps {
                    // Check if coordinate is valid before adding
                    let coord = HexCoordinate { q, r };
                    if is_valid_hex_coordinate(coord, grid_size_i32) {
                        coords.append(coord);
                    }
                    
                    // Move in current direction
                    q += direction.q;
                    r += direction.r;
                    step += 1;
                };
                
                dir_idx += 1;
            };
        }
        
        ring += 1;
    };
    
    coords
}

// Check if a hex coordinate is valid for the given grid size
fn is_valid_hex_coordinate(coord: HexCoordinate, grid_size: i32) -> bool {
    let s = -coord.q - coord.r;
    abs_i32(coord.q) <= grid_size && abs_i32(coord.r) <= grid_size && abs_i32(s) <= grid_size
}

// Helper for absolute value of i32
fn abs_i32(value: i32) -> i32 {
    if value < 0 {
        -value
    } else {
        value
    }
}

#[cfg(test)]
mod tests {
    use super::{generate_spiral_coordinates, HexCoordinate};

    #[test]
    fn test_spiral_generation_size_1() {
        let coords = generate_spiral_coordinates(1);
        
        // Should have 7 cells for size 1
        assert(coords.len() == 7, 'Size 1 should have 7 cells');
        
        // Check center
        assert(*coords.at(0) == HexCoordinate { q: 0, r: 0 }, 'Center');
        
        // Check ring 1
        assert(*coords.at(1) == HexCoordinate { q: 0, r: -1 }, 'North');
        assert(*coords.at(2) == HexCoordinate { q: 1, r: -1 }, 'Northeast');
        assert(*coords.at(3) == HexCoordinate { q: 1, r: 0 }, 'Southeast');
        assert(*coords.at(4) == HexCoordinate { q: 0, r: 1 }, 'South');
        assert(*coords.at(5) == HexCoordinate { q: -1, r: 1 }, 'Southwest');
        assert(*coords.at(6) == HexCoordinate { q: -1, r: 0 }, 'Northwest');
    }

    #[test]
    fn test_spiral_generation_size_2() {
        let coords = generate_spiral_coordinates(2);
        
        // Should have 19 cells for size 2 (1 + 6 + 12)
        assert(coords.len() == 19, 'Size 2 should have 19 cells');
        
        // Check center
        assert(*coords.at(0) == HexCoordinate { q: 0, r: 0 }, 'Center at index 0');
        
        // Check that all coordinates are unique
        let mut i = 0;
        while i < coords.len() {
            let mut j = i + 1;
            while j < coords.len() {
                let coord_i = coords.at(i);
                let coord_j = coords.at(j);
                assert(
                    coord_i.q != coord_j.q || coord_i.r != coord_j.r,
                    'Coordinates should be unique'
                );
                j += 1;
            };
            i += 1;
        };
    }
}
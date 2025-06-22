use super::types::CellData;
use super::spiral_coords::generate_spiral_coordinates;

// Grid scenario structure for easy test setup
#[derive(Drop)]
pub struct GridScenario {
    pub letter: felt252,
    pub captured_by: Option<felt252>,
    pub locked_by: Option<felt252>,
}

// Map a flat array of scenarios to positioned cells
// The scenarios are mapped to coordinates in spiral order from center outward
pub fn map_scenario_to_cells(
    grid_size: u8,
    scenario: Array<GridScenario>
) -> Array<CellData> {
    let coords = generate_spiral_coordinates(grid_size);
    let mut cells = array![];
    
    let mut i = 0;
    while i < scenario.len() && i < coords.len() {
        let coord = *coords.at(i);
        let scenario_cell = scenario.at(i);
        
        // Convert felt252 options to ContractAddress options
        let captured_by = match *scenario_cell.captured_by {
            Option::Some(addr_felt) => Option::Some(addr_felt.try_into().unwrap()),
            Option::None => Option::None,
        };
        
        let locked_by = match *scenario_cell.locked_by {
            Option::Some(addr_felt) => Option::Some(addr_felt.try_into().unwrap()),
            Option::None => Option::None,
        };
        
        cells.append(CellData {
            coordinate: coord,
            letter: *scenario_cell.letter,
            captured_by,
            locked_by,
        });
        
        i += 1;
    };
    
    cells
}

// Abbreviated helper to create GridScenario entries
pub fn gs(letter: felt252) -> GridScenario {
    GridScenario {
        letter,
        captured_by: Option::None,
        locked_by: Option::None,
    }
}

// Create GridScenario with capture
pub fn gs_captured(letter: felt252, player: felt252) -> GridScenario {
    GridScenario {
        letter,
        captured_by: Option::Some(player),
        locked_by: Option::None,
    }
}

// Create GridScenario with capture and lock by same player
pub fn gs_locked(letter: felt252, player: felt252) -> GridScenario {
    GridScenario {
        letter,
        captured_by: Option::Some(player),
        locked_by: Option::Some(player),
    }
}

#[cfg(test)]
mod tests {
    use super::{map_scenario_to_cells, gs, gs_captured};

    #[test]
    fn test_scenario_mapping() {
        let scenario = array![
            gs('H'),
            gs('E'),
            gs('L'),
            gs('L'),
            gs('O'),
            gs('X'),
            gs('W'),
        ];
        
        let cells = map_scenario_to_cells(1, scenario);
        
        assert(cells.len() == 7, 'Should map all cells');
        
        // Check center cell
        let center = cells.at(0);
        assert(*center.coordinate.q == 0_i32, 'Center q coord');
        assert(*center.coordinate.r == 0_i32, 'Center r coord');
        assert(*center.letter == 'H', 'Center letter');
        
        // Check north cell
        let north = cells.at(1);
        assert(*north.coordinate.q == 0_i32, 'North q coord');
        assert(*north.coordinate.r == -1_i32, 'North r coord');
        assert(*north.letter == 'E', 'North letter');
    }

    #[test]
    fn test_scenario_with_captures() {
        let player1: felt252 = 'PLAYER1';
        let player2: felt252 = 'PLAYER2';
        
        let scenario = array![
            gs_captured('A', player1),
            gs('B'),
            gs_captured('C', player2),
        ];
        
        let cells = map_scenario_to_cells(1, scenario);
        
        let cell0 = cells.at(0);
        assert(*cell0.captured_by == Option::Some(player1.try_into().unwrap()), 'Cell 0 captured');
        
        let cell1 = cells.at(1);
        assert(*cell1.captured_by == Option::None, 'Cell 1 not captured');
        
        let cell2 = cells.at(2);
        assert(*cell2.captured_by == Option::Some(player2.try_into().unwrap()), 'Cell 2 captured');
    }
}
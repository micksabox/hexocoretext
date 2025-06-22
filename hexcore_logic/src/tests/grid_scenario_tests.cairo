// Grid scenario tests for hexcore_logic
// These tests demonstrate how to use the test grid utilities to create game scenarios

#[cfg(test)]
mod tests {
    use hexcore_logic::grid_scenario::{
        map_scenario_to_cells,
        gs, gs_captured, gs_locked
    };

    #[test]
    fn test_simple_game_state() {
        // Create a test scenario for a grid with radius 1 (7 cells)
        // The cells are specified in spiral order: center, then ring 1
        let player1 = 'player1';
        let player2 = 'player2';
        
        let scenario = array![
            gs('H'),                    // Center (0,0)
            gs_captured('E', player1),  // North (0,-1)
            gs('X'),                    // Northeast (1,-1)
            gs_locked('A', player2),    // Southeast (1,0)
            gs('G'),                    // South (0,1)
            gs('O'),                    // Southwest (-1,1)
            gs_captured('N', player1),  // Northwest (-1,0)
        ];
        
        // Map to actual cell positions
        let cells = map_scenario_to_cells(1, scenario);
        
        // Verify the mapping
        assert(cells.len() == 7, 'Should have 7 cells');
        
        // Check specific cells
        let center = cells.at(0);
        assert(*center.letter == 'H', 'Center letter');
        assert(center.captured_by.is_none(), 'Center not captured');
        
        let north = cells.at(1);
        assert(*north.letter == 'E', 'North letter');
        assert(*north.captured_by == Option::Some(player1), 'North captured');
    }

    #[test]
    fn test_partial_grid_scenario() {
        // For a grid with radius 2, we can provide partial scenarios
        // This is useful for testing specific patterns without defining the entire grid
        let player1 = 'player1';
        
        let scenario = array![
            // Center
            gs('C'),
            // Ring 1 (6 cells)
            gs('A'), gs('B'), gs('C'), gs('D'), gs('E'), gs('F'),
            // Ring 2 (partial - only first 4 cells)
            gs_captured('G', player1), gs('H'), gs('I'), gs('J'),
        ];
        
        // Map first 11 cells (partial grid)
        let cells = map_scenario_to_cells(2, scenario);
        
        // The harness will map as many cells as provided in the scenario
        assert(cells.len() == 11, 'Should map 11 cells');
        
        // Verify captured cell in ring 2
        let ring2_first = cells.at(7);
        assert(*ring2_first.letter == 'G', 'Ring 2 first letter');
        assert(*ring2_first.captured_by == Option::Some(player1), 'Ring 2 first captured');
    }

    #[test]
    fn test_hexagon_capture_pattern() {
        // Test a complete hexagon capture pattern
        // Center + 6 surrounding cells all captured by same player
        let player1 = 'player1';
        
        let scenario = array![
            gs_captured('A', player1),  // Center
            gs_captured('B', player1),  // All surrounding cells
            gs_captured('C', player1),
            gs_captured('D', player1),
            gs_captured('E', player1),
            gs_captured('F', player1),
            gs_captured('G', player1),
        ];
        
        let cells = map_scenario_to_cells(1, scenario);
        
        // All cells should be captured by player1
        let mut i = 0;
        while i < cells.len() {
            let cell = cells.at(i);
            assert(*cell.captured_by == Option::Some(player1), 'All captured');
            i += 1;
        };
    }

    #[test]
    fn test_mixed_capture_scenario() {
        // Test a scenario with mixed captures and locks
        let player1 = 'player1';
        let player2 = 'player2';
        
        let scenario = array![
            gs('C'),                    // Center - neutral
            gs_captured('A', player1),  // North - P1 captured
            gs_locked('B', player1),    // Northeast - P1 locked
            gs_captured('C', player2),  // Southeast - P2 captured
            gs_locked('D', player2),    // South - P2 locked
            gs('E'),                    // Southwest - neutral
            gs('F'),                    // Northwest - neutral
        ];
        
        let cells = map_scenario_to_cells(1, scenario);
        
        // Verify mixed states
        let center = cells.at(0);
        assert(center.captured_by.is_none(), 'Center neutral');
        
        let northeast = cells.at(2);
        assert(*northeast.captured_by == Option::Some(player1), 'NE captured by P1');
        assert(*northeast.locked_by == Option::Some(player1), 'NE locked by P1');
        
        let south = cells.at(4);
        assert(*south.captured_by == Option::Some(player2), 'S captured by P2');
        assert(*south.locked_by == Option::Some(player2), 'S locked by P2');
    }

    #[test]
    fn test_word_formation_scenario() {
        // Test setting up a scenario where a word can be formed
        let scenario = array![
            gs('C'),  // Center
            gs('A'),  // North
            gs('T'),  // Northeast
            gs('S'),  // Southeast
            gs('X'),  // South
            gs('Y'),  // Southwest
            gs('Z'),  // Northwest
        ];
        
        let cells = map_scenario_to_cells(1, scenario);
        
        // Verify we can trace the word "CAT" from Center -> North -> Northeast
        let c_cell = cells.at(0);
        let a_cell = cells.at(1);
        let t_cell = cells.at(2);
        
        assert(*c_cell.letter == 'C', 'C letter');
        assert(*a_cell.letter == 'A', 'A letter');
        assert(*t_cell.letter == 'T', 'T letter');
        
        // Verify coordinates form a connected path
        assert(*c_cell.coordinate.q == 0 && *c_cell.coordinate.r == 0, 'C at center');
        assert(*a_cell.coordinate.q == 0 && *a_cell.coordinate.r == -1, 'A at north');
        assert(*t_cell.coordinate.q == 1 && *t_cell.coordinate.r == -1, 'T at northeast');
    }
}
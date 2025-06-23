// Test edge cases for turn calculation
use hexcore_logic::types::{HexCoordinate, PlayerTurn};
use hexcore_logic::grid_scenario::{map_scenario_to_cells, gs, gs_captured};
use hexcore_logic::game_logic::{GameLogic, GameLogicTrait, GameConfig};

// Constants for players
const PLAYER1: felt252 = 'P1';
const PLAYER2: felt252 = 'P2';

fn setup_game() -> GameLogic {
    let config = GameConfig {
        grid_size: 5,
        min_word_length: 3,
        score_limit: 16,
    };
    GameLogicTrait::new(config)
}

#[test]
fn test_hexagon_completion_by_other_player() {
    let game = setup_game();
    
    // Scenario: P1 has center + 3 neighbors, P2 captures remaining 3 to complete hexagon
    let scenario = array![
        gs_captured('H', PLAYER1),  // Center - P1 owns
        gs_captured('E', PLAYER1),  // North - P1 owns
        gs_captured('X', PLAYER1),  // Northeast - P1 owns  
        gs('A'),                    // Southeast - uncaptured
        gs('G'),                    // South - uncaptured
        gs('O'),                    // Southwest - uncaptured
        gs_captured('N', PLAYER1),  // Northwest - P1 owns
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // P2 captures the 3 uncaptured tiles to complete the hexagon
    let turn = PlayerTurn {
        player_index: 1,  // Player 2
        word: array![],
        tile_positions: array![
            HexCoordinate { q: 1, r: 0 },   // Southeast (index 3 in spiral)
            HexCoordinate { q: 0, r: 1 },   // South (index 4)
            HexCoordinate { q: -1, r: 1 },  // Southwest (index 5)
        ],
        tile_swap: Option::None,
        merkle_proof: array![],
    };
    
    let result = game.calculate_turn(@cells, @turn);
    assert(result.is_ok(), 'Turn should be valid');
    
    let side_effects = result.unwrap();
    
    // Should capture 3 cells (the uncaptured ones)
    assert(side_effects.cells_captured.len() == 3, 'Should capture 3 cells');
    
    // Should form 1 hexagon (center at 0,0) - P1 has majority (4 vs 3)
    assert(side_effects.hexagons_formed.len() == 1, 'Should form 1 hexagon');
    
    // The center should be locked for P1 (majority owner)
    let center = side_effects.hexagons_formed.at(0);
    assert(*center.q == 0 && *center.r == 0, 'Center should be at origin');
}

#[test]
fn test_cannot_capture_opponent_tiles() {
    let game = setup_game();
    
    // Scenario: P1 tries to capture tiles owned by P2
    let scenario = array![
        gs('X'),                    // Center
        gs_captured('C', PLAYER2),  // North - P2 owns
        gs_captured('A', PLAYER2),  // Northeast - P2 owns
        gs('T'),                    // Southeast - uncaptured
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // P1 tries to capture all tiles including P2's
    let turn = PlayerTurn {
        player_index: 0,  // Player 1
        word: array![],
        tile_positions: array![
            HexCoordinate { q: 0, r: 0 },   // Center
            HexCoordinate { q: 0, r: -1 },  // North (owned by P2)
            HexCoordinate { q: 1, r: -1 },  // Northeast (owned by P2)
            HexCoordinate { q: 1, r: 0 },   // Southeast
        ],
        tile_swap: Option::None,
        merkle_proof: array![],
    };
    
    let result = game.calculate_turn(@cells, @turn);
    assert(result.is_ok(), 'Turn should be valid');
    
    let side_effects = result.unwrap();
    
    // Should only capture 2 cells (center and southeast)
    // Cannot capture North and Northeast owned by P2
    assert(side_effects.cells_captured.len() == 2, 'Can only capture 2 cells');
}

#[test]
fn test_hexagon_with_mixed_ownership() {
    let game = setup_game();
    
    // Create a complete hexagon with mixed ownership
    let scenario = array![
        gs_captured('H', PLAYER1),  // Center - P1
        gs_captured('E', PLAYER1),  // North - P1
        gs_captured('X', PLAYER2),  // Northeast - P2
        gs_captured('A', PLAYER2),  // Southeast - P2
        gs_captured('G', PLAYER2),  // South - P2  
        gs_captured('O', PLAYER2),  // Southwest - P2
        gs_captured('N', PLAYER1),  // Northwest - P1
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Empty turn just to trigger hexagon detection
    let turn = PlayerTurn {
        player_index: 0,
        word: array![],
        tile_positions: array![],
        tile_swap: Option::None,
        merkle_proof: array![],
    };
    
    let result = game.calculate_turn(@cells, @turn);
    assert(result.is_ok(), 'Turn should be valid');
    
    let side_effects = result.unwrap();
    
    // No new captures
    assert(side_effects.cells_captured.len() == 0, 'No new captures');
    
    // Should detect the hexagon - P2 has majority (4 vs 3)
    assert(side_effects.hexagons_formed.len() == 1, 'Should detect hexagon');
}
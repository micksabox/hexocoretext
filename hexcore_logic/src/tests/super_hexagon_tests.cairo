use hexcore_logic::game_logic::{GameLogicTrait, GameConfig};
use hexcore_logic::types::{HexCoordinate, PlayerTurn};
use hexcore_logic::grid_scenario::{map_scenario_to_cells, gs_captured, gs_locked};

// Constants for players
const PLAYER1: felt252 = 'P1';
const PLAYER2: felt252 = 'P2';

#[test]
fn test_super_hexagon_detection() {
    let config = GameConfig {
        grid_size: 2,
        min_word_length: 3,
        score_limit: 16,
    };
    let game = GameLogicTrait::new(config);
    
    // Create a scenario where all 7 cells are locked by the same player
    let scenario = array![
        gs_locked('S', PLAYER1),  // Center - locked
        gs_locked('U', PLAYER1),  // North - locked
        gs_locked('P', PLAYER1),  // Northeast - locked
        gs_locked('E', PLAYER1),  // Southeast - locked
        gs_locked('R', PLAYER1),  // South - locked
        gs_locked('H', PLAYER1),  // Southwest - locked
        gs_locked('X', PLAYER1),  // Northwest - locked
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Create a turn that doesn't matter for this test
    let turn = PlayerTurn {
        player_index: 0,
        word: array![],
        tile_positions: array![],
        tile_swap: Option::None,
        merkle_proof: array![],
    };
    
    let side_effects = game.calculate_turn(@cells, @turn);
    
    // Should detect 1 super hexagon
    assert(side_effects.superhexagons_formed.len() == 1, 'Should find 1 super hexagon');
    
    // The center should be at (0,0)
    let super_center = side_effects.superhexagons_formed.at(0);
    assert(*super_center.q == 0, 'Super hexagon center q');
    assert(*super_center.r == 0, 'Super hexagon center r');
    
    // All 7 tiles should be marked for replacement
    assert(side_effects.tiles_replaced.len() >= 7, 'Should replace all 7 tiles');
}

#[test]
fn test_super_hexagon_mixed_locks() {
    let config = GameConfig {
        grid_size: 2,
        min_word_length: 3,
        score_limit: 16,
    };
    let game = GameLogicTrait::new(config);
    
    // Create a scenario where cells are locked by different players
    let scenario = array![
        gs_locked('S', PLAYER1),  // Center - locked by P1
        gs_locked('U', PLAYER1),  // North - locked by P1
        gs_locked('P', PLAYER2),  // Northeast - locked by P2
        gs_locked('E', PLAYER1),  // Southeast - locked by P1
        gs_locked('R', PLAYER1),  // South - locked by P1
        gs_locked('H', PLAYER1),  // Southwest - locked by P1
        gs_locked('X', PLAYER2),  // Northwest - locked by P2
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Create a turn that doesn't matter for this test
    let turn = PlayerTurn {
        player_index: 0,
        word: array![],
        tile_positions: array![],
        tile_swap: Option::None,
        merkle_proof: array![],
    };
    
    let side_effects = game.calculate_turn(@cells, @turn);
    
    // Should detect a super hexagon (all locked, mixed ownership is OK)
    assert(side_effects.superhexagons_formed.len() == 1, 'Should find super hexagon');
}

#[test]
fn test_no_super_hexagon_not_all_locked() {
    let config = GameConfig {
        grid_size: 2,
        min_word_length: 3,
        score_limit: 16,
    };
    let game = GameLogicTrait::new(config);
    
    // Create a scenario where not all cells are locked
    let scenario = array![
        gs_locked('S', PLAYER1),  // Center - locked
        gs_locked('U', PLAYER1),  // North - locked
        gs_locked('P', PLAYER1),  // Northeast - locked
        gs_captured('E', PLAYER1), // Southeast - captured but not locked
        gs_locked('R', PLAYER1),  // South - locked
        gs_locked('H', PLAYER1),  // Southwest - locked
        gs_locked('X', PLAYER1),  // Northwest - locked
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Create a turn that doesn't matter for this test
    let turn = PlayerTurn {
        player_index: 0,
        word: array![],
        tile_positions: array![],
        tile_swap: Option::None,
        merkle_proof: array![],
    };
    
    let side_effects = game.calculate_turn(@cells, @turn);
    
    // Should not detect any super hexagon (one cell not locked)
    assert(side_effects.superhexagons_formed.len() == 0, 'No super hexagon unlocked');
}

#[test]
fn test_super_hexagon_replacement_includes_all() {
    let config = GameConfig {
        grid_size: 2,
        min_word_length: 3,
        score_limit: 16,
    };
    let game = GameLogicTrait::new(config);
    
    // Create a scenario with all tiles locked (super hexagon)
    let scenario = array![
        gs_locked('S', PLAYER1),  // Center - locked (super hexagon)
        gs_locked('U', PLAYER1),  // North - locked
        gs_locked('P', PLAYER1),  // Northeast - locked
        gs_locked('E', PLAYER1),  // Southeast - locked
        gs_locked('R', PLAYER1),  // South - locked
        gs_locked('H', PLAYER1),  // Southwest - locked
        gs_locked('X', PLAYER1),  // Northwest - locked
    ];
    
    let cells = map_scenario_to_cells(1, scenario);
    
    // Try to capture all tiles (will fail since they're locked)
    let turn = PlayerTurn {
        player_index: 0,
        word: array![],
        tile_positions: array![
            HexCoordinate { q: 0, r: 0 },  // Center
            HexCoordinate { q: 1, r: 0 },  // East
            HexCoordinate { q: 0, r: 1 },  // Southeast
            HexCoordinate { q: -1, r: 1 }, // Southwest
            HexCoordinate { q: -1, r: 0 }, // West
            HexCoordinate { q: 0, r: -1 }, // Northwest
            HexCoordinate { q: 1, r: -1 }, // Northeast
        ],
        tile_swap: Option::None,
        merkle_proof: array![],
    };
    
    let side_effects = game.calculate_turn(@cells, @turn);
    
    // Should not form new hexagon (center already locked), but super hexagon exists
    assert(side_effects.hexagons_formed.len() == 0, 'No new hexagon formed');
    assert(side_effects.superhexagons_formed.len() == 1, 'Should find 1 super hexagon');
    
    // All tiles should be replaced (no duplicates)
    assert(side_effects.tiles_replaced.len() >= 7, 'Should replace all tiles');
}
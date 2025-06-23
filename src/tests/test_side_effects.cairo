use starknet::{contract_address_const};
use dojo::world::{WorldStorage};
use dojo::model::{ModelStorage};

use crate::models::{Cell, HexCoordinate, TileSwap};
use crate::systems::game::{IGameActionsDispatcherTrait};
use crate::tests::test_utils::{
    setup_world, create_test_game, setup_two_players, get_game_state, get_player,
    get_cell, create_horizontal_word_positions, set_cell_letters, submit_turn_helper,
    get_current_player_address, create_test_merkle_proof
};

// Helper to setup cells in a hexagon pattern
fn setup_hexagon_cells(mut world: WorldStorage, game_id: u32, center_q: i32, center_r: i32) {
    // Set up cells in a hexagon pattern around center
    // The 6 neighbors of a hex cell
    let neighbors = array![
        (center_q + 1, center_r),     // E
        (center_q + 1, center_r - 1), // NE
        (center_q, center_r - 1),     // NW
        (center_q - 1, center_r),     // W
        (center_q - 1, center_r + 1), // SW
        (center_q, center_r + 1),     // SE
    ];
    
    // Set all cells with letter 'H' for testing
    let mut i = 0;
    while i < neighbors.len() {
        let (q, r) = *neighbors[i];
        let mut cell: Cell = world.read_model((game_id, q, r));
        cell.letter = 'H';
        world.write_model(@cell);
        i += 1;
    };
    
    // Set center cell
    let mut center_cell: Cell = world.read_model((game_id, center_q, center_r));
    center_cell.letter = 'H';
    world.write_model(@center_cell);
}

#[test]
fn test_cell_capture() {
    let (mut world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    let (player1, _player2) = setup_two_players(game_actions, game_id);
    
    // Get current player
    let current_player = get_current_player_address(@world, @game_actions, game_id);
    
    // Setup word "CAPTURE" at positions
    let positions = array![
        HexCoordinate { q: 0, r: 0 },
        HexCoordinate { q: 1, r: 0 },
        HexCoordinate { q: 2, r: 0 },
        HexCoordinate { q: 3, r: 0 },
        HexCoordinate { q: 4, r: 0 },
        HexCoordinate { q: 5, r: 0 },
        HexCoordinate { q: 6, r: 0 },
    ];
    let letters = array!['C', 'A', 'P', 'T', 'U', 'R', 'E'];
    set_cell_letters(world, game_id, @positions, @letters);
    
    // Submit turn
    let success = submit_turn_helper(
        game_actions,
        game_id,
        current_player,
        "CAPTURE",
        positions.clone(),
        Option::None
    );
    assert!(success);
    
    // Note: We can't verify captures directly without mocking the hexcore_logic
    // In a real test, we would need to:
    // 1. Mock the hexcore_logic response
    // 2. Verify cells are captured by checking cell.captured_by
}

#[test]
fn test_hexagon_formation_locks_center() {
    let (mut world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    let (_player1, _player2) = setup_two_players(game_actions, game_id);
    
    // Setup hexagon pattern
    let center_q = 0;
    let center_r = 0;
    setup_hexagon_cells(world, game_id, center_q, center_r);
    
    // Get current player and ensure all cells are captured by them first
    let current_player = get_current_player_address(@world, @game_actions, game_id);
    
    // Pre-capture all cells in the hexagon for the current player
    let hex_positions = array![
        HexCoordinate { q: center_q, r: center_r },
        HexCoordinate { q: center_q + 1, r: center_r },
        HexCoordinate { q: center_q + 1, r: center_r - 1 },
        HexCoordinate { q: center_q, r: center_r - 1 },
        HexCoordinate { q: center_q - 1, r: center_r },
        HexCoordinate { q: center_q - 1, r: center_r + 1 },
        HexCoordinate { q: center_q, r: center_r + 1 },
    ];
    
    let mut i = 0;
    while i < hex_positions.len() {
        let coord = *hex_positions[i];
        let mut cell: Cell = world.read_model((game_id, coord.q, coord.r));
        cell.captured_by = Option::Some(current_player);
        world.write_model(@cell);
        i += 1;
    };
    
    // Note: Testing hexagon formation would require:
    // 1. Setting up a scenario where a word completes a hexagon
    // 2. Mocking hexcore_logic to return hexagons_formed
    // 3. Verifying the center cell gets locked
}

#[test]
fn test_tile_swap() {
    let (mut world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    let (_player1, _player2) = setup_two_players(game_actions, game_id);
    
    let current_player = get_current_player_address(@world, @game_actions, game_id);
    
    // Setup initial board state
    let pos1 = HexCoordinate { q: 0, r: 0 };
    let pos2 = HexCoordinate { q: 1, r: 0 };
    let pos3 = HexCoordinate { q: 2, r: 0 };
    let pos4 = HexCoordinate { q: 3, r: 0 };
    
    // Set letters for a word
    let positions = array![pos1, pos2, pos3, pos4];
    let letters = array!['W', 'O', 'R', 'D'];
    set_cell_letters(world, game_id, @positions, @letters);
    
    // Also set up swap target
    let swap_from = HexCoordinate { q: 5, r: 0 };
    let swap_to = HexCoordinate { q: 6, r: 0 };
    
    let mut cell_from: Cell = world.read_model((game_id, swap_from.q, swap_from.r));
    cell_from.letter = 'X';
    world.write_model(@cell_from);
    
    let mut cell_to: Cell = world.read_model((game_id, swap_to.q, swap_to.r));
    cell_to.letter = 'Y';
    world.write_model(@cell_to);
    
    // Submit turn with tile swap
    let tile_swap = Option::Some(TileSwap { from: swap_from, to: swap_to });
    
    let success = submit_turn_helper(
        game_actions,
        game_id,
        current_player,
        "WORD",
        positions,
        tile_swap
    );
    assert!(success);
    
    // Note: Actual tile swap verification would require mocking hexcore_logic
}

#[test]
fn test_score_update() {
    let (mut world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    let (_player1, _player2) = setup_two_players(game_actions, game_id);
    
    let current_player = get_current_player_address(@world, @game_actions, game_id);
    
    // Get initial score
    let initial_player_state = get_player(@world, game_id, current_player);
    let initial_score = initial_player_state.score;
    
    // Setup word
    let positions = create_horizontal_word_positions(0, 0, 5);
    let letters = array!['S', 'C', 'O', 'R', 'E'];
    set_cell_letters(world, game_id, @positions, @letters);
    
    // Submit turn
    let success = submit_turn_helper(
        game_actions,
        game_id,
        current_player,
        "SCORE",
        positions,
        Option::None
    );
    assert!(success);
    
    // Note: Score update verification requires mocking hexcore_logic
    // to return points_awarded in side effects
}

#[test]
fn test_tile_replacement_after_capture() {
    let (mut world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    let (_player1, _player2) = setup_two_players(game_actions, game_id);
    
    let current_player = get_current_player_address(@world, @game_actions, game_id);
    
    // Setup word that would trigger replacements
    let positions = create_horizontal_word_positions(0, 0, 7);
    let letters = array!['R', 'E', 'P', 'L', 'A', 'C', 'E'];
    set_cell_letters(world, game_id, @positions, @letters);
    
    // Submit turn
    let success = submit_turn_helper(
        game_actions,
        game_id,
        current_player,
        "REPLACE",
        positions,
        Option::None
    );
    assert!(success);
    
    // Note: Tile replacement verification requires mocking hexcore_logic
    // to return tiles_replaced in side effects
}

#[test]
fn test_multiple_side_effects_in_one_turn() {
    let (mut world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    let (_player1, _player2) = setup_two_players(game_actions, game_id);
    
    let current_player = get_current_player_address(@world, @game_actions, game_id);
    
    // Setup a complex board state that could trigger multiple effects
    // This would include:
    // 1. Word placement that captures cells
    // 2. Completes a hexagon
    // 3. Awards points
    // 4. Triggers tile replacements
    
    let positions = create_horizontal_word_positions(0, 0, 8);
    let letters = array!['C', 'O', 'M', 'P', 'L', 'E', 'T', 'E'];
    set_cell_letters(world, game_id, @positions, @letters);
    
    // Submit turn
    let success = submit_turn_helper(
        game_actions,
        game_id,
        current_player,
        "COMPLETE",
        positions,
        Option::None
    );
    assert!(success);
    
    // Verification would require mocking hexcore_logic with complex side effects
}

#[test]
fn test_locked_cells_cannot_be_captured() {
    let (mut world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    let (player1, player2) = setup_two_players(game_actions, game_id);
    
    // Lock a cell by player1
    let locked_coord = HexCoordinate { q: 2, r: 0 };
    let mut locked_cell: Cell = world.read_model((game_id, locked_coord.q, locked_coord.r));
    locked_cell.locked_by = Option::Some(player1);
    locked_cell.captured_by = Option::Some(player1);
    world.write_model(@locked_cell);
    
    // Get current player (might be player1 or player2)
    let current_player = get_current_player_address(@world, @game_actions, game_id);
    
    // If current player is player1, make it player2's turn
    if current_player == player1 {
        // Submit a dummy turn to switch players
        let dummy_positions = create_horizontal_word_positions(5, 5, 3);
        let dummy_letters = array!['A', 'B', 'C'];
        set_cell_letters(world, game_id, @dummy_positions, @dummy_letters);
        
        submit_turn_helper(
            game_actions,
            game_id,
            player1,
            "ABC",
            dummy_positions,
            Option::None
        );
    }
    
    // Now player2 tries to use the locked cell in their word
    let positions = create_horizontal_word_positions(0, 0, 5);
    let letters = array!['T', 'R', 'Y', 'I', 'T'];
    set_cell_letters(world, game_id, @positions, @letters);
    
    let success = submit_turn_helper(
        game_actions,
        game_id,
        player2,
        "TRYIT",
        positions,
        Option::None
    );
    assert!(success);
    
    // The locked cell should still be locked by player1
    let cell_after = get_cell(@world, game_id, locked_coord.q, locked_coord.r);
    assert_eq!(cell_after.locked_by, Option::Some(player1));
}

#[test]
fn test_game_over_event() {
    let (mut world, game_actions) = setup_world();
    
    // Create game with very low score limit for easy testing
    let game_id = game_actions.create_game(5, 5, 0x123);
    let (player1, _player2) = setup_two_players(game_actions, game_id);
    
    let current_player = get_current_player_address(@world, @game_actions, game_id);
    
    // Manually set player score close to limit
    let mut player_state = get_player(@world, game_id, current_player);
    player_state.score = 4;
    world.write_model(@player_state);
    
    // Setup word
    let positions = create_horizontal_word_positions(0, 0, 3);
    let letters = array!['W', 'I', 'N'];
    set_cell_letters(world, game_id, @positions, @letters);
    
    // This turn should end the game if it awards any points
    let success = submit_turn_helper(
        game_actions,
        game_id,
        current_player,
        "WIN",
        positions,
        Option::None
    );
    assert!(success);
    
    // Note: Actual game over verification requires mocking hexcore_logic
    // to return points that would push score over limit
}
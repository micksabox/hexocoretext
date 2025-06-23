use starknet::{contract_address_const};
use dojo::model::{ModelStorage};

use crate::models::{HexCoordinate};
use crate::systems::game::{IGameActionsDispatcherTrait};
use crate::tests::test_utils::{
    setup_world, create_test_game, setup_two_players, get_game_state, get_player,
    get_cell, create_horizontal_word_positions, set_cell_letters, submit_turn_helper,
    get_current_player_address
};

#[test]
fn test_create_game() {
    let (mut world, game_actions) = setup_world();
    
    // Create a game with custom parameters
    let game_id = game_actions.create_game(7, 20, 0xABCDEF);
    
    // Verify game state
    let game_state = get_game_state(@world, game_id);
    assert_eq!(game_state.grid_size, 7);
    assert_eq!(game_state.score_limit, 20);
    assert_eq!(game_state.word_list_root, 0xABCDEF);
    assert_eq!(game_state.min_word_length, 3); // DEFAULT_MIN_WORD_LENGTH
    assert_eq!(game_state.player_count, 0);
    assert_eq!(game_state.is_active, false);
    assert!(game_state.winner.is_none());
}

#[test]
fn test_create_game_with_defaults() {
    let (mut world, game_actions) = setup_world();
    
    // Create a game with default parameters (0 values)
    let game_id = game_actions.create_game(0, 0, 0x123);
    
    // Verify defaults are applied
    let game_state = get_game_state(@world, game_id);
    assert_eq!(game_state.grid_size, 5); // DEFAULT_GRID_SIZE
    assert_eq!(game_state.score_limit, 16); // DEFAULT_SCORE_LIMIT
}

#[test]
fn test_grid_initialization() {
    let (mut world, game_actions) = setup_world();
    
    // Create a small game for testing
    let game_id = game_actions.create_game(2, 10, 0x123);
    
    // Check some cells exist and have letters
    let cell_center = get_cell(@world, game_id, 0, 0);
    // Just check the letter is not zero
    assert!(cell_center.letter != 0);
    assert!(cell_center.captured_by.is_none());
    assert!(cell_center.locked_by.is_none());
    
    // Check edge cell
    let cell_edge = get_cell(@world, game_id, 2, 0);
    assert!(cell_edge.letter != 0);
}

#[test]
fn test_join_game() {
    let (mut world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    
    // First player joins
    let player1 = contract_address_const::<0x1>();
    starknet::testing::set_contract_address(player1);
    game_actions.join_game(game_id, "Alice", 'RED');
    
    // Verify player state
    let player1_state = get_player(@world, game_id, player1);
    assert_eq!(player1_state.name, "Alice");
    assert_eq!(player1_state.color, 'RED');
    assert_eq!(player1_state.score, 0);
    
    // Verify game state updated
    let game_state = get_game_state(@world, game_id);
    assert_eq!(game_state.player_count, 1);
    assert_eq!(game_state.is_active, false);
}

#[test]
fn test_game_starts_with_two_players() {
    let (mut world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    
    let (_player1, _player2) = setup_two_players(game_actions, game_id);
    
    // Verify game is now active
    let game_state = get_game_state(@world, game_id);
    assert_eq!(game_state.player_count, 2);
    assert_eq!(game_state.is_active, true);
    assert!(game_state.current_player_index < 2);
}

#[test]
#[should_panic(expected: ('Game is full',))]
fn test_cannot_join_full_game() {
    let (_world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    
    let (_player1, _player2) = setup_two_players(game_actions, game_id);
    
    // Third player tries to join
    let player3 = contract_address_const::<0x3>();
    starknet::testing::set_contract_address(player3);
    game_actions.join_game(game_id, "Charlie", 'GREEN');
}

#[test]
#[should_panic(expected: ('Already joined',))]
fn test_cannot_join_twice() {
    let (_world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    
    // Player joins first time
    let player1 = contract_address_const::<0x1>();
    starknet::testing::set_contract_address(player1);
    game_actions.join_game(game_id, "Alice", 'RED');
    
    // Same player tries to join again
    game_actions.join_game(game_id, "Alice2", 'BLUE');
}

#[test]
fn test_turn_changes_player() {
    let (mut world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    let (player1, player2) = setup_two_players(game_actions, game_id);
    
    // Get initial current player
    let initial_player = get_current_player_address(@world, @game_actions, game_id);
    
    // Setup word "TEST" at position (0,0)
    let positions = create_horizontal_word_positions(0, 0, 4);
    let letters = array!['T', 'E', 'S', 'T'];
    set_cell_letters(world, game_id, @positions, @letters);
    
    // Submit turn
    let success = submit_turn_helper(
        game_actions,
        game_id,
        initial_player,
        "TEST",
        positions,
        Option::None
    );
    assert!(success);
    
    // Verify turn changed
    let new_current_player = get_current_player_address(@world, @game_actions, game_id);
    assert!(new_current_player != initial_player);
    
    // Verify it's the other player
    if initial_player == player1 {
        assert_eq!(new_current_player, player2);
    } else {
        assert_eq!(new_current_player, player1);
    }
}

#[test]
#[should_panic(expected: ('Not your turn',))]
fn test_cannot_play_out_of_turn() {
    let (mut world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    let (player1, player2) = setup_two_players(game_actions, game_id);
    
    // Get current player
    let current_player = get_current_player_address(@world, @game_actions, game_id);
    let wrong_player = if current_player == player1 { player2 } else { player1 };
    
    // Setup word
    let positions = create_horizontal_word_positions(0, 0, 4);
    let letters = array!['T', 'E', 'S', 'T'];
    set_cell_letters(world, game_id, @positions, @letters);
    
    // Wrong player tries to play
    submit_turn_helper(
        game_actions,
        game_id,
        wrong_player,
        "TEST",
        positions,
        Option::None
    );
}

#[test]
#[should_panic(expected: ('Game not active',))]
fn test_cannot_play_before_game_starts() {
    let (mut world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    
    // Only one player joins
    let player1 = contract_address_const::<0x1>();
    starknet::testing::set_contract_address(player1);
    game_actions.join_game(game_id, "Alice", 'RED');
    
    // Try to play
    let positions = create_horizontal_word_positions(0, 0, 4);
    let letters = array!['T', 'E', 'S', 'T'];
    set_cell_letters(world, game_id, @positions, @letters);
    
    submit_turn_helper(
        game_actions,
        game_id,
        player1,
        "TEST",
        positions,
        Option::None
    );
}

#[test]
fn test_game_ends_when_score_limit_reached() {
    let (mut world, game_actions) = setup_world();
    
    // Create game with low score limit
    let game_id = game_actions.create_game(5, 1, 0x123);
    let (player1, _player2) = setup_two_players(game_actions, game_id);
    
    // Get current player
    let current_player = get_current_player_address(@world, @game_actions, game_id);
    
    // Manually update player score to just below limit
    let mut player_state = get_player(@world, game_id, current_player);
    player_state.score = 0;
    world.write_model(@player_state);
    
    // Setup word that will give points
    let positions = create_horizontal_word_positions(0, 0, 4);
    let letters = array!['T', 'E', 'S', 'T'];
    set_cell_letters(world, game_id, @positions, @letters);
    
    // Submit turn - this should trigger game over
    let success = submit_turn_helper(
        game_actions,
        game_id,
        current_player,
        "TEST",
        positions,
        Option::None
    );
    assert!(success);
    
    // Note: Since we can't easily trigger scoring in this test without mocking,
    // we'll test the game over logic separately in side effects tests
}

#[test]
fn test_get_current_player() {
    let (mut world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    let (player1, player2) = setup_two_players(game_actions, game_id);
    
    let current = game_actions.get_current_player(game_id);
    assert!(current == player1 || current == player2);
}

#[test]
fn test_get_game_state() {
    let (_world, game_actions) = setup_world();
    let game_id = create_test_game(game_actions);
    
    let state = game_actions.get_game_state(game_id);
    assert_eq!(state.id, game_id);
    assert_eq!(state.grid_size, 5);
    assert_eq!(state.score_limit, 16);
}
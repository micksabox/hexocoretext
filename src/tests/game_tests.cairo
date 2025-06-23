use starknet::contract_address_const;
use dojo::model::ModelStorage;

use crate::models::{GameState, Player, Cell, GamePlayer};
use crate::systems::game::IGameActionsDispatcherTrait;
use crate::tests::test_utils::{setup_world, create_test_game, setup_two_players};

#[test]
#[available_gas(300000000)]
fn test_create_game() {
    let (mut world, game_actions) = setup_world();
    
    // Create a game
    let game_id = game_actions.create_game(5, 16, 0x123456789);
    
    // Verify game state
    let game_state: GameState = world.read_model(game_id);
    assert(game_state.grid_size == 5, 'Wrong grid size');
    assert(game_state.score_limit == 16, 'Wrong score limit');
    assert(game_state.word_list_root == 0x123456789, 'Wrong word list root');
    assert(game_state.player_count == 0, 'Wrong player count');
    assert(!game_state.is_active, 'Game should not be active');
    
    // Verify grid cells were created (check center cell)
    let center_cell: Cell = world.read_model((game_id, 0, 0));
    let letter_num: u32 = center_cell.letter.try_into().unwrap();
    assert(letter_num >= 65 && letter_num <= 90, 'Invalid letter');
    assert(center_cell.captured_by.is_none(), 'Cell should not be captured');
    assert(center_cell.locked_by.is_none(), 'Cell should not be locked');
}

#[test]
#[available_gas(300000000)]
fn test_join_game() {
    let (mut world, game_actions) = setup_world();
    
    // Create a game
    let game_id = create_test_game(game_actions);
    
    // Player 1 joins
    let player1 = contract_address_const::<0x1>();
    starknet::testing::set_contract_address(player1);
    game_actions.join_game(game_id, "Player 1", 'RED');
    
    // Verify player was added
    let player: Player = world.read_model((game_id, player1));
    assert(player.name == "Player 1", 'Wrong player name');
    assert(player.color == 'RED', 'Wrong player color');
    assert(player.score == 0, 'Wrong initial score');
    
    // Verify game player index
    let game_player: GamePlayer = world.read_model((game_id, 0_u8));
    assert(game_player.address == player1, 'Wrong player address');
    
    // Verify game state updated
    let game_state: GameState = world.read_model(game_id);
    assert(game_state.player_count == 1, 'Wrong player count');
    assert(!game_state.is_active, 'Game should not be active yet');
}

#[test]
#[available_gas(300000000)]
fn test_game_starts_with_two_players() {
    let (mut world, game_actions) = setup_world();
    
    // Create game and add two players
    let game_id = create_test_game(game_actions);
    let (player1, player2) = setup_two_players(game_actions, game_id);
    
    // Verify game is now active
    let game_state: GameState = world.read_model(game_id);
    assert(game_state.player_count == 2, 'Wrong player count');
    assert(game_state.is_active, 'Game should be active');
    assert(
        game_state.current_player_index == 0 || game_state.current_player_index == 1,
        'Invalid starting player'
    );
    
    // Verify both players exist
    let player1_data: Player = world.read_model((game_id, player1));
    let player2_data: Player = world.read_model((game_id, player2));
    assert(player1_data.name == "Player 1", 'Wrong player 1 name');
    assert(player2_data.name == "Player 2", 'Wrong player 2 name');
}

#[test]
#[available_gas(300000000)]
#[should_panic(expected: ('Game is full', 'ENTRYPOINT_FAILED'))]
fn test_cannot_join_full_game() {
    let (_world, game_actions) = setup_world();
    
    // Create game and add two players
    let game_id = create_test_game(game_actions);
    let (_player1, _player2) = setup_two_players(game_actions, game_id);
    
    // Try to add third player
    let player3 = contract_address_const::<0x3>();
    starknet::testing::set_contract_address(player3);
    game_actions.join_game(game_id, "Player 3", 'GREEN');
}

#[test]
#[available_gas(300000000)]
#[should_panic(expected: ('Already joined', 'ENTRYPOINT_FAILED'))]
fn test_cannot_join_twice() {
    let (_world, game_actions) = setup_world();
    
    // Create a game
    let game_id = create_test_game(game_actions);
    
    // Player 1 joins
    let player1 = contract_address_const::<0x1>();
    starknet::testing::set_contract_address(player1);
    game_actions.join_game(game_id, "Player 1", 'RED');
    
    // Try to join again
    game_actions.join_game(game_id, "Player 1 Again", 'BLUE');
}
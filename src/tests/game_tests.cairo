#[cfg(test)]
mod tests {
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use starknet::{ContractAddress, contract_address_const};
    
    use hexocoretext::models::{Cell, Player, GameState, HexCoordinate};
    use hexocoretext::systems::game::{IGameActionsDispatcherTrait};
    use hexocoretext::tests::test_utils::{
        setup_test_world, get_game_actions, setup_game_with_players,
        set_cell_state, create_word_path, assert_cell_state, get_player_score,
        PLAYER_ONE, PLAYER_TWO, PLAYER_THREE, PLAYER_FOUR
    };

    // Test game creation with different grid sizes
    #[test]
    #[available_gas(50000000)]
    fn test_create_game_scenarios() {
        let world = setup_test_world();
        let game_actions = get_game_actions(@world);
        
        // Test small grid
        starknet::testing::set_contract_address(PLAYER_ONE());
        let game_id_small = game_actions.create_game(3);
        let game_state_small: GameState = world.read_model(game_id_small);
        assert(game_state_small.grid_size == 3, 'Small grid size incorrect');
        assert(!game_state_small.is_active, 'Game should not be active yet');
        assert(game_state_small.player_count == 0, 'Should have 0 players');
        
        // Test medium grid
        let game_id_medium = game_actions.create_game(5);
        let game_state_medium: GameState = world.read_model(game_id_medium);
        assert(game_state_medium.grid_size == 5, 'Medium grid size incorrect');
        
        // Verify grid cells are initialized
        let center_cell: Cell = world.read_model((game_id_small, 0, 0));
        assert(center_cell.letter != 0, 'Center cell should have letter');
        assert(center_cell.captured_by.is_none(), 'Cell should not be captured');
        assert(center_cell.locked_by.is_none(), 'Cell should not be locked');
    }

    // Test player joining scenarios
    #[test]
    #[available_gas(50000000)]
    fn test_player_join_scenarios() {
        let world = setup_test_world();
        let game_actions = get_game_actions(@world);
        
        // Create game
        starknet::testing::set_contract_address(PLAYER_ONE());
        let game_id = game_actions.create_game(4);
        
        // First player joins
        game_actions.join_game(game_id, "Alice", 'RED');
        let game_state: GameState = world.read_model(game_id);
        assert(game_state.player_count == 1, 'Should have 1 player');
        assert(!game_state.is_active, 'Game needs 2 players to start');
        
        // Second player joins - game should start
        starknet::testing::set_contract_address(PLAYER_TWO());
        game_actions.join_game(game_id, "Bob", 'BLUE');
        let game_state: GameState = world.read_model(game_id);
        assert(game_state.player_count == 2, 'Should have 2 players');
        assert(game_state.is_active, 'Game should be active');
        
        // Third player joins
        starknet::testing::set_contract_address(PLAYER_THREE());
        game_actions.join_game(game_id, "Charlie", 'GREEN');
        let game_state: GameState = world.read_model(game_id);
        assert(game_state.player_count == 3, 'Should have 3 players');
        
        // Fourth player joins
        starknet::testing::set_contract_address(PLAYER_FOUR());
        game_actions.join_game(game_id, "David", 'YELLOW');
        let game_state: GameState = world.read_model(game_id);
        assert(game_state.player_count == 4, 'Should have 4 players');
    }

    // Test that game is full
    #[test]
    #[should_panic(expected: ('Game is full',))]
    #[available_gas(50000000)]
    fn test_join_full_game() {
        let world = setup_test_world();
        let (game_id, game_actions) = setup_game_with_players(@world, 4, 4);
        
        // Try to join as fifth player - should panic
        starknet::testing::set_contract_address(contract_address_const::<'PLAYER_FIVE'>());
        game_actions.join_game(game_id, "Eve", 'PURPLE');
    }

    // Test valid word submission
    #[test]
    #[available_gas(50000000)]
    fn test_word_submission_valid() {
        let world = setup_test_world();
        let (game_id, game_actions) = setup_game_with_players(@world, 4, 2);
        
        // Set up specific letters for testing
        set_cell_state(@world, game_id, 0, 0, 'C', Option::None, Option::None);
        set_cell_state(@world, game_id, 1, 0, 'A', Option::None, Option::None);
        set_cell_state(@world, game_id, 1, -1, 'T', Option::None, Option::None);
        
        // Submit 3-letter word "CAT"
        starknet::testing::set_contract_address(PLAYER_ONE());
        let word_path = create_word_path([(0, 0), (1, 0), (1, -1)]);
        let success = game_actions.submit_word(game_id, word_path);
        assert(success, 'Word submission should succeed');
        
        // Verify cells are captured
        assert_cell_state(@world, game_id, 0, 0, Option::Some(PLAYER_ONE()), Option::None);
        assert_cell_state(@world, game_id, 1, 0, Option::Some(PLAYER_ONE()), Option::None);
        assert_cell_state(@world, game_id, 1, -1, Option::Some(PLAYER_ONE()), Option::None);
        
        // Verify score
        let score = get_player_score(@world, game_id, PLAYER_ONE());
        assert(score == 3, 'Should have 3 points');
    }

    // Test 5+ letter word locks cells
    #[test]
    #[available_gas(50000000)]
    fn test_word_locking_mechanism() {
        let world = setup_test_world();
        let (game_id, game_actions) = setup_game_with_players(@world, 5, 2);
        
        // Set up letters for 5-letter word
        set_cell_state(@world, game_id, 0, 0, 'H', Option::None, Option::None);
        set_cell_state(@world, game_id, 1, 0, 'E', Option::None, Option::None);
        set_cell_state(@world, game_id, 2, 0, 'L', Option::None, Option::None);
        set_cell_state(@world, game_id, 2, -1, 'L', Option::None, Option::None);
        set_cell_state(@world, game_id, 1, -1, 'O', Option::None, Option::None);
        
        // Submit 5-letter word "HELLO"
        starknet::testing::set_contract_address(PLAYER_ONE());
        let word_path = create_word_path([(0, 0), (1, 0), (2, 0), (2, -1), (1, -1)]);
        game_actions.submit_word(game_id, word_path);
        
        // Verify cells are captured AND locked
        assert_cell_state(@world, game_id, 0, 0, Option::Some(PLAYER_ONE()), Option::Some(PLAYER_ONE()));
        assert_cell_state(@world, game_id, 1, 0, Option::Some(PLAYER_ONE()), Option::Some(PLAYER_ONE()));
        assert_cell_state(@world, game_id, 2, 0, Option::Some(PLAYER_ONE()), Option::Some(PLAYER_ONE()));
        assert_cell_state(@world, game_id, 2, -1, Option::Some(PLAYER_ONE()), Option::Some(PLAYER_ONE()));
        assert_cell_state(@world, game_id, 1, -1, Option::Some(PLAYER_ONE()), Option::Some(PLAYER_ONE()));
    }

    // Test disconnected cells
    #[test]
    #[should_panic(expected: ('Cells not connected',))]
    #[available_gas(50000000)]
    fn test_disconnected_cells() {
        let world = setup_test_world();
        let (game_id, game_actions) = setup_game_with_players(@world, 4, 2);
        
        // Try to submit word with disconnected cells
        starknet::testing::set_contract_address(PLAYER_ONE());
        let word_path = create_word_path([(0, 0), (2, 0), (3, 0)]); // Gap between first and second
        game_actions.submit_word(game_id, word_path);
    }

    // Test word too short
    #[test]
    #[should_panic(expected: ('Word too short',))]
    #[available_gas(50000000)]
    fn test_word_too_short() {
        let world = setup_test_world();
        let (game_id, game_actions) = setup_game_with_players(@world, 4, 2);
        
        // Try to submit 2-letter word
        starknet::testing::set_contract_address(PLAYER_ONE());
        let word_path = create_word_path([(0, 0), (1, 0)]);
        game_actions.submit_word(game_id, word_path);
    }

    // Test wrong turn
    #[test]
    #[should_panic(expected: ('Not your turn',))]
    #[available_gas(50000000)]
    fn test_wrong_turn() {
        let world = setup_test_world();
        let (game_id, game_actions) = setup_game_with_players(@world, 4, 2);
        
        // Player 2 tries to go first
        starknet::testing::set_contract_address(PLAYER_TWO());
        let word_path = create_word_path([(0, 0), (1, 0), (1, -1)]);
        game_actions.submit_word(game_id, word_path);
    }

    // Test capturing opponent's cells
    #[test]
    #[available_gas(50000000)]
    fn test_capture_opponent_cells() {
        let world = setup_test_world();
        let (game_id, game_actions) = setup_game_with_players(@world, 4, 2);
        
        // Player 1 captures some cells
        set_cell_state(@world, game_id, 0, 0, 'A', Option::None, Option::None);
        set_cell_state(@world, game_id, 1, 0, 'B', Option::None, Option::None);
        set_cell_state(@world, game_id, 1, -1, 'C', Option::None, Option::None);
        
        starknet::testing::set_contract_address(PLAYER_ONE());
        let word_path = create_word_path([(0, 0), (1, 0), (1, -1)]);
        game_actions.submit_word(game_id, word_path);
        
        // Player 2 captures overlapping cells
        set_cell_state(@world, game_id, 1, -1, 'C', Option::Some(PLAYER_ONE()), Option::None);
        set_cell_state(@world, game_id, 0, -1, 'D', Option::None, Option::None);
        set_cell_state(@world, game_id, -1, 0, 'E', Option::None, Option::None);
        
        starknet::testing::set_contract_address(PLAYER_TWO());
        let word_path2 = create_word_path([(1, -1), (0, -1), (-1, 0)]);
        game_actions.submit_word(game_id, word_path2);
        
        // Verify Player 2 captured the overlapping cell
        assert_cell_state(@world, game_id, 1, -1, Option::Some(PLAYER_TWO()), Option::None);
        
        // Verify scores
        let score_p1 = get_player_score(@world, game_id, PLAYER_ONE());
        let score_p2 = get_player_score(@world, game_id, PLAYER_TWO());
        assert(score_p1 == 3, 'P1 should have 3 points');
        assert(score_p2 == 3, 'P2 should have 3 points');
    }

    // Test attempting to capture locked cells
    #[test]
    #[available_gas(50000000)]
    fn test_cannot_capture_locked_cells() {
        let world = setup_test_world();
        let (game_id, game_actions) = setup_game_with_players(@world, 5, 2);
        
        // Player 1 creates a 5-letter word to lock cells
        set_cell_state(@world, game_id, 0, 0, 'A', Option::None, Option::None);
        set_cell_state(@world, game_id, 1, 0, 'B', Option::None, Option::None);
        set_cell_state(@world, game_id, 2, 0, 'C', Option::None, Option::None);
        set_cell_state(@world, game_id, 3, 0, 'D', Option::None, Option::None);
        set_cell_state(@world, game_id, 4, 0, 'E', Option::None, Option::None);
        
        starknet::testing::set_contract_address(PLAYER_ONE());
        let word_path = create_word_path([(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)]);
        game_actions.submit_word(game_id, word_path);
        
        // Player 2 tries to capture locked cells
        set_cell_state(@world, game_id, 2, -1, 'F', Option::None, Option::None);
        set_cell_state(@world, game_id, 1, -1, 'G', Option::None, Option::None);
        
        starknet::testing::set_contract_address(PLAYER_TWO());
        let word_path2 = create_word_path([(2, 0), (2, -1), (1, -1)]); // Includes locked cell at (2,0)
        game_actions.submit_word(game_id, word_path2);
        
        // Verify locked cell wasn't captured
        assert_cell_state(@world, game_id, 2, 0, Option::Some(PLAYER_ONE()), Option::Some(PLAYER_ONE()));
        
        // Only the unlocked cells should be captured
        let score_p2 = get_player_score(@world, game_id, PLAYER_TWO());
        assert(score_p2 == 2, 'P2 should only capture 2 cells');
    }

    // Test turn rotation
    #[test]
    #[available_gas(50000000)]
    fn test_turn_rotation() {
        let world = setup_test_world();
        let (game_id, game_actions) = setup_game_with_players(@world, 4, 3);
        
        // Player 1's turn
        set_cell_state(@world, game_id, 0, 0, 'A', Option::None, Option::None);
        set_cell_state(@world, game_id, 1, 0, 'B', Option::None, Option::None);
        set_cell_state(@world, game_id, 1, -1, 'C', Option::None, Option::None);
        
        starknet::testing::set_contract_address(PLAYER_ONE());
        game_actions.submit_word(game_id, create_word_path([(0, 0), (1, 0), (1, -1)]));
        
        let game_state: GameState = world.read_model(game_id);
        assert(game_state.current_player_index == 1, 'Should be player 2 turn');
        
        // Player 2's turn
        set_cell_state(@world, game_id, -1, 0, 'D', Option::None, Option::None);
        set_cell_state(@world, game_id, -1, 1, 'E', Option::None, Option::None);
        set_cell_state(@world, game_id, 0, 1, 'F', Option::None, Option::None);
        
        starknet::testing::set_contract_address(PLAYER_TWO());
        game_actions.submit_word(game_id, create_word_path([(-1, 0), (-1, 1), (0, 1)]));
        
        let game_state: GameState = world.read_model(game_id);
        assert(game_state.current_player_index == 2, 'Should be player 3 turn');
        
        // Player 3's turn
        set_cell_state(@world, game_id, 2, -1, 'G', Option::None, Option::None);
        set_cell_state(@world, game_id, 2, -2, 'H', Option::None, Option::None);
        set_cell_state(@world, game_id, 1, -2, 'I', Option::None, Option::None);
        
        starknet::testing::set_contract_address(PLAYER_THREE());
        game_actions.submit_word(game_id, create_word_path([(2, -1), (2, -2), (1, -2)]));
        
        let game_state: GameState = world.read_model(game_id);
        assert(game_state.current_player_index == 0, 'Should wrap to player 1');
    }

    // Test game over detection
    #[test]
    #[available_gas(100000000)]
    fn test_game_over_scenario() {
        let world = setup_test_world();
        let (game_id, game_actions) = setup_game_with_players(@world, 1, 2); // Very small grid
        
        // Manually set up a nearly complete board
        set_cell_state(@world, game_id, 0, 0, 'A', Option::Some(PLAYER_ONE()), Option::None);
        set_cell_state(@world, game_id, 1, 0, 'B', Option::Some(PLAYER_ONE()), Option::None);
        set_cell_state(@world, game_id, 0, 1, 'C', Option::Some(PLAYER_TWO()), Option::None);
        set_cell_state(@world, game_id, -1, 0, 'D', Option::Some(PLAYER_TWO()), Option::None);
        set_cell_state(@world, game_id, 0, -1, 'E', Option::Some(PLAYER_ONE()), Option::None);
        set_cell_state(@world, game_id, -1, 1, 'F', Option::None, Option::None); // Last uncaptured cell
        set_cell_state(@world, game_id, 1, -1, 'G', Option::None, Option::None);
        
        // Submit final word to capture remaining cells
        starknet::testing::set_contract_address(PLAYER_ONE());
        let word_path = create_word_path([(-1, 1), (0, 0), (1, -1)]);
        game_actions.submit_word(game_id, word_path);
        
        // Game should be over
        let game_state: GameState = world.read_model(game_id);
        assert(!game_state.is_active, 'Game should be over');
    }
}
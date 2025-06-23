use starknet::{ContractAddress, contract_address_const};
use dojo::world::{WorldStorage, WorldStorageTrait};
use dojo::model::{ModelStorage};
use dojo_cairo_test::{
    spawn_test_world, NamespaceDef, TestResource, ContractDefTrait,
    WorldStorageTestTrait,
};

use crate::models::{
    m_GameState, m_Player, m_Cell, m_GameCounter, m_GamePlayer, m_TurnHistory,
    e_GameCreated, e_PlayerJoined, e_GameStarted, e_TurnSubmitted, e_GameOver,
    GameState, Player, Cell, GamePlayer, HexCoordinate, TileSwap
};
use crate::systems::game::{game_actions, IGameActionsDispatcher, IGameActionsDispatcherTrait};

pub fn setup_world() -> (WorldStorage, IGameActionsDispatcher) {
    // Define namespace with all models and events
    let ndef = NamespaceDef {
        namespace: "hexocoretext",
        resources: [
            TestResource::Model(m_GameState::TEST_CLASS_HASH),
            TestResource::Model(m_Player::TEST_CLASS_HASH),
            TestResource::Model(m_Cell::TEST_CLASS_HASH),
            TestResource::Model(m_GameCounter::TEST_CLASS_HASH),
            TestResource::Model(m_GamePlayer::TEST_CLASS_HASH),
            TestResource::Model(m_TurnHistory::TEST_CLASS_HASH),
            TestResource::Event(e_GameCreated::TEST_CLASS_HASH),
            TestResource::Event(e_PlayerJoined::TEST_CLASS_HASH),
            TestResource::Event(e_GameStarted::TEST_CLASS_HASH),
            TestResource::Event(e_TurnSubmitted::TEST_CLASS_HASH),
            TestResource::Event(e_GameOver::TEST_CLASS_HASH),
            TestResource::Contract(game_actions::TEST_CLASS_HASH),
        ].span(),
    };
    
    // Define contract permissions
    let contract_defs = [
        ContractDefTrait::new(@"hexocoretext", @"game_actions")
            .with_writer_of([dojo::utils::bytearray_hash(@"hexocoretext")].span())
    ].span();
    
    // Spawn world
    let mut world = spawn_test_world([ndef].span());
    world.sync_perms_and_inits(contract_defs);
    
    // Get game actions dispatcher
    let (game_actions_addr, _) = world.dns(@"game_actions").unwrap();
    let game_actions = IGameActionsDispatcher { contract_address: game_actions_addr };
    
    (world, game_actions)
}

pub fn create_test_game(game_actions: IGameActionsDispatcher) -> u32 {
    game_actions.create_game(5, 16, 0x123456789)
}

pub fn setup_two_players(
    game_actions: IGameActionsDispatcher, game_id: u32
) -> (ContractAddress, ContractAddress) {
    let player1 = contract_address_const::<0x1>();
    let player2 = contract_address_const::<0x2>();
    
    // Player 1 joins
    starknet::testing::set_contract_address(player1);
    game_actions.join_game(game_id, "Player 1", 'RED');
    
    // Player 2 joins
    starknet::testing::set_contract_address(player2);
    game_actions.join_game(game_id, "Player 2", 'BLUE');
    
    (player1, player2)
}

// Helper to get current game state
pub fn get_game_state(world: @WorldStorage, game_id: u32) -> GameState {
    let game_state: GameState = world.read_model(game_id);
    game_state
}

// Helper to get player info
pub fn get_player(world: @WorldStorage, game_id: u32, player: ContractAddress) -> Player {
    let player_model: Player = world.read_model((game_id, player));
    player_model
}

// Helper to get cell info
pub fn get_cell(world: @WorldStorage, game_id: u32, q: i32, r: i32) -> Cell {
    let cell: Cell = world.read_model((game_id, q, r));
    cell
}

// Helper to create valid word positions (horizontal line)
pub fn create_horizontal_word_positions(start_q: i32, start_r: i32, length: u32) -> Array<HexCoordinate> {
    let mut positions = array![];
    let mut i = 0;
    while i < length {
        let i_i32: i32 = i.try_into().unwrap();
        positions.append(HexCoordinate { 
            q: start_q + i_i32, 
            r: start_r 
        });
        i += 1;
    };
    positions
}

// Helper to create a simple merkle proof (for testing)
pub fn create_test_merkle_proof() -> Array<felt252> {
    array![0x123, 0x456, 0x789]
}

// Helper to set cell letters for testing word submissions
pub fn set_cell_letters(mut world: WorldStorage, game_id: u32, positions: @Array<HexCoordinate>, letters: @Array<felt252>) {
    let mut i = 0;
    while i < positions.len() {
        let coord = *positions[i];
        let mut cell: Cell = world.read_model((game_id, coord.q, coord.r));
        cell.letter = *letters[i];
        world.write_model(@cell);
        i += 1;
    };
}

// Helper to get the current player's address
pub fn get_current_player_address(world: @WorldStorage, game_actions: @IGameActionsDispatcher, game_id: u32) -> ContractAddress {
    let game_state: GameState = world.read_model(game_id);
    let game_player: GamePlayer = world.read_model((game_id, game_state.current_player_index));
    game_player.address
}

// Helper to submit a turn and get result
pub fn submit_turn_helper(
    game_actions: IGameActionsDispatcher,
    game_id: u32,
    player: ContractAddress,
    word: ByteArray,
    positions: Array<HexCoordinate>,
    tile_swap: Option<TileSwap>
) -> bool {
    starknet::testing::set_contract_address(player);
    game_actions.submit_turn(
        game_id,
        word,
        positions,
        tile_swap,
        create_test_merkle_proof()
    )
}
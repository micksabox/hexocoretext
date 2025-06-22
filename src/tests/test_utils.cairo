use dojo::model::{ModelStorage, ModelStorageTest};
use dojo::world::WorldStorageTrait;
use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef};
use starknet::{ContractAddress, contract_address_const};

use hexocoretext::models::{Cell, Player, GameState, HexCoordinate};
use hexocoretext::models::{m_Cell, m_Player, m_GameState};
use hexocoretext::systems::game::{game_actions, IGameActionsDispatcher, IGameActionsDispatcherTrait};
use hexocoretext::systems::game::game_actions::{e_WordSubmitted, e_GameOver};

// Test addresses
pub fn PLAYER_ONE() -> ContractAddress {
    contract_address_const::<'PLAYER_ONE'>()
}

pub fn PLAYER_TWO() -> ContractAddress {
    contract_address_const::<'PLAYER_TWO'>()
}

pub fn PLAYER_THREE() -> ContractAddress {
    contract_address_const::<'PLAYER_THREE'>()
}

pub fn PLAYER_FOUR() -> ContractAddress {
    contract_address_const::<'PLAYER_FOUR'>()
}

// Namespace definition for tests
pub fn namespace_def() -> NamespaceDef {
    NamespaceDef {
        namespace: "hexgame", 
        resources: [
            TestResource::Model(m_Cell::TEST_CLASS_HASH),
            TestResource::Model(m_Player::TEST_CLASS_HASH),
            TestResource::Model(m_GameState::TEST_CLASS_HASH),
            TestResource::Event(e_WordSubmitted::TEST_CLASS_HASH),
            TestResource::Event(e_GameOver::TEST_CLASS_HASH),
            TestResource::Contract(game_actions::TEST_CLASS_HASH)
        ].span()
    }
}

// Contract definitions for permissions
pub fn contract_defs() -> Span<ContractDef> {
    [
        ContractDefTrait::new(@"hexgame", @"game_actions")
            .with_writer_of([dojo::utils::bytearray_hash(@"hexgame")].span())
    ].span()
}

// Create a test world with game contracts
pub fn setup_test_world() -> dojo::world::WorldStorage {
    let ndef = namespace_def();
    let mut world = spawn_test_world([ndef].span());
    world.sync_perms_and_inits(contract_defs());
    world
}

// Get game actions dispatcher
pub fn get_game_actions(world: @dojo::world::WorldStorage) -> IGameActionsDispatcher {
    let (contract_address, _) = (*world).dns(@"game_actions").unwrap();
    IGameActionsDispatcher { contract_address }
}

// Helper to create a game with players
pub fn setup_game_with_players(
    world: @dojo::world::WorldStorage, 
    grid_size: u8, 
    player_count: u8
) -> (u32, IGameActionsDispatcher) {
    let game_actions = get_game_actions(world);
    
    // Create game
    starknet::testing::set_contract_address(PLAYER_ONE());
    let game_id = game_actions.create_game(grid_size);
    
    // Add players
    if player_count >= 1 {
        starknet::testing::set_contract_address(PLAYER_ONE());
        game_actions.join_game(game_id, "Player One", 'RED');
    }
    
    if player_count >= 2 {
        starknet::testing::set_contract_address(PLAYER_TWO());
        game_actions.join_game(game_id, "Player Two", 'BLUE');
    }
    
    if player_count >= 3 {
        starknet::testing::set_contract_address(PLAYER_THREE());
        game_actions.join_game(game_id, "Player Three", 'GREEN');
    }
    
    if player_count >= 4 {
        starknet::testing::set_contract_address(PLAYER_FOUR());
        game_actions.join_game(game_id, "Player Four", 'YELLOW');
    }
    
    (game_id, game_actions)
}

// Helper to set specific cell state for testing
pub fn set_cell_state(
    world: @dojo::world::WorldStorage,
    game_id: u32,
    q: i32,
    r: i32,
    letter: felt252,
    captured_by: Option<ContractAddress>,
    locked_by: Option<ContractAddress>
) {
    let cell = Cell {
        game_id,
        q,
        r,
        letter,
        captured_by,
        locked_by,
    };
    (*world).write_model_test(@cell);
}

// Helper to create a word path
pub fn create_word_path(coords: Array<(i32, i32)>) -> Array<HexCoordinate> {
    let mut path = array![];
    let mut i = 0;
    while i < coords.len() {
        let (q, r) = *coords[i];
        path.append(HexCoordinate { q, r });
        i += 1;
    };
    path
}

// Helper to verify cell state
pub fn assert_cell_state(
    world: @dojo::world::WorldStorage,
    game_id: u32,
    q: i32,
    r: i32,
    expected_captured_by: Option<ContractAddress>,
    expected_locked_by: Option<ContractAddress>
) {
    let cell: Cell = (*world).read_model((game_id, q, r));
    assert(cell.captured_by == expected_captured_by, 'Incorrect captured_by');
    assert(cell.locked_by == expected_locked_by, 'Incorrect locked_by');
}

// Helper to get player score
pub fn get_player_score(
    world: @dojo::world::WorldStorage,
    game_id: u32,
    player: ContractAddress
) -> u32 {
    let player_data: Player = (*world).read_model((game_id, player));
    player_data.score
}
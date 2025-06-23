use starknet::{ContractAddress, contract_address_const};
use dojo::world::{WorldStorage, WorldStorageTrait};
use dojo_cairo_test::{
    spawn_test_world, NamespaceDef, TestResource, ContractDefTrait,
    WorldStorageTestTrait,
};

use crate::models::{
    m_GameState, m_Player, m_Cell, m_GameCounter, m_GamePlayer, m_TurnHistory,
    e_GameCreated, e_PlayerJoined, e_GameStarted, e_TurnSubmitted, e_GameOver
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
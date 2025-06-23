use starknet::ContractAddress;

// Coordinate system for hexagonal grid
#[derive(Copy, Drop, Serde, Introspect, PartialEq, Debug)]
pub struct HexCoordinate {
    pub q: i32,
    pub r: i32,
}

// Tile swap information for a turn
#[derive(Copy, Drop, Serde, Introspect, PartialEq, Debug)]
pub struct TileSwap {
    pub from: HexCoordinate,
    pub to: HexCoordinate,
}

// Game state model
#[derive(Drop, Serde)]
#[dojo::model]
pub struct GameState {
    #[key]
    pub id: u32,
    pub grid_size: u8,
    pub score_limit: u32,
    pub min_word_length: u8,
    pub word_list_root: felt252,
    pub current_player_index: u8,
    pub player_count: u8,
    pub is_active: bool,
    pub winner: Option<ContractAddress>,
    pub created_at: u64,
}

// Player model - tracks player information per game
#[derive(Drop, Serde)]
#[dojo::model]
pub struct Player {
    #[key]
    pub game_id: u32,
    #[key]
    pub address: ContractAddress,
    pub name: ByteArray,
    pub color: felt252,
    pub score: u32,
}

// Cell model - represents each hex cell in the grid
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Cell {
    #[key]
    pub game_id: u32,
    #[key]
    pub q: i32,
    #[key]
    pub r: i32,
    pub letter: felt252, // ASCII value of the letter
    pub captured_by: Option<ContractAddress>,
    pub locked_by: Option<ContractAddress>,
}

// GameCounter model - for tracking game IDs globally
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GameCounter {
    #[key]
    pub id: u32, // Always GAME_COUNTER_KEY
    pub count: u32,
}

// GamePlayer model - tracks players by index for turn order
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GamePlayer {
    #[key]
    pub game_id: u32,
    #[key]
    pub index: u8,
    pub address: ContractAddress,
}

// TurnHistory model - for tracking game history
#[derive(Drop, Serde)]
#[dojo::model]
pub struct TurnHistory {
    #[key]
    pub game_id: u32,
    #[key]
    pub turn_number: u32,
    pub player: ContractAddress,
    pub word: ByteArray,
    pub tile_positions: Array<HexCoordinate>,
    pub tile_swap: Option<TileSwap>,
    pub points_scored: u32,
    pub timestamp: u64,
}

// Events
#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct GameCreated {
    #[key]
    pub game_id: u32,
    pub creator: ContractAddress,
    pub grid_size: u8,
    pub score_limit: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct PlayerJoined {
    #[key]
    pub game_id: u32,
    #[key]
    pub player: ContractAddress,
    pub player_index: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct GameStarted {
    #[key]
    pub game_id: u32,
    pub starting_player_index: u8,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct TurnSubmitted {
    #[key]
    pub game_id: u32,
    #[key]
    pub turn_number: u32,
    pub player: ContractAddress,
    pub word: ByteArray,
    pub points_scored: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct GameOver {
    #[key]
    pub game_id: u32,
    pub winner: ContractAddress,
    pub final_score: u32,
}
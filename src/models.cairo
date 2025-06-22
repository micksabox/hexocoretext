use starknet::ContractAddress;

// Hex coordinate using axial coordinates (q, r)
#[derive(Copy, Drop, Serde, Introspect, PartialEq, Debug)]
pub struct HexCoordinate {
    pub q: i32,
    pub r: i32,
}

// Cell state in the hex grid
#[derive(Drop, Serde)]
#[dojo::model]
pub struct Cell {
    #[key]
    pub game_id: u32,
    #[key] 
    pub q: i32,
    #[key]
    pub r: i32,
    pub letter: felt252,
    pub captured_by: Option<ContractAddress>,
    pub locked_by: Option<ContractAddress>,
}

// Player state
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

// Game state
#[derive(Drop, Serde)]
#[dojo::model]
pub struct GameState {
    #[key]
    pub id: u32,
    pub grid_size: u8,
    pub current_player_index: u8,
    pub player_count: u8,
    pub is_active: bool,
}

// Word submission event
#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct WordSubmitted {
    #[key]
    pub game_id: u32,
    #[key]
    pub player: ContractAddress,
    pub word_length: u8,
    pub cells_captured: u8,
    pub cells_locked: u8,
}

// Game over event
#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct GameOver {
    #[key]
    pub game_id: u32,
    pub winner: ContractAddress,
    pub final_score: u32,
}

// Direction for hex neighbors
#[derive(Copy, Drop, Serde, Introspect, PartialEq, Debug)]
pub enum Direction {
    North,
    Northeast,
    Southeast,
    South,
    Southwest,
    Northwest,
}

impl DirectionIntoFelt252 of Into<Direction, felt252> {
    fn into(self: Direction) -> felt252 {
        match self {
            Direction::North => 0,
            Direction::Northeast => 1,
            Direction::Southeast => 2,
            Direction::South => 3,
            Direction::Southwest => 4,
            Direction::Northwest => 5,
        }
    }
}
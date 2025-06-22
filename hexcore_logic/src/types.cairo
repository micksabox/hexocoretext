// Core types that don't depend on Dojo
use starknet::ContractAddress;

#[derive(Drop, Serde, Copy, Debug, PartialEq)]
pub struct HexCoordinate {
    pub q: i32,
    pub r: i32,
}

#[derive(Drop, Serde, Copy, Debug, PartialEq)]
pub enum Direction {
    North,
    Northeast,
    Southeast,
    South,
    Southwest,
    Northwest,
}

#[derive(Drop, Serde, Copy, Debug, PartialEq)]
pub struct CellState {
    pub letter: felt252,
    pub captured_by: Option<ContractAddress>,
    pub locked_by: Option<ContractAddress>,
}

#[derive(Drop, Serde, Copy)]
pub struct GameConfig {
    pub grid_size: u8,
    pub min_word_length: u8,
    pub score_limit: u32,
}

// Game calculation results
#[derive(Drop, Serde, Copy)]
pub struct CaptureResult {
    pub cells_captured: u32,
    pub cells_locked: u32,
    pub hexagons_formed: u32,
    pub points_scored: u32,
}

#[derive(Drop, Serde)]
pub struct HexagonCheck {
    pub is_hexagon: bool,
    pub center: HexCoordinate,
    pub surrounding_cells: Array<HexCoordinate>,
}

// Trait definition for HexCoordinate
pub trait HexCoordinateTrait {
    fn new(q: i32, r: i32) -> HexCoordinate;
    fn s(self: @HexCoordinate) -> i32;
    fn add(self: @HexCoordinate, other: @HexCoordinate) -> HexCoordinate;
    fn subtract(self: @HexCoordinate, other: @HexCoordinate) -> HexCoordinate;
    fn distance(self: @HexCoordinate, other: @HexCoordinate) -> i32;
}

// Implement traits for HexCoordinate
pub impl HexCoordinateImpl of HexCoordinateTrait {
    fn new(q: i32, r: i32) -> HexCoordinate {
        HexCoordinate { q, r }
    }

    fn s(self: @HexCoordinate) -> i32 {
        -*self.q - *self.r
    }

    fn add(self: @HexCoordinate, other: @HexCoordinate) -> HexCoordinate {
        HexCoordinate { q: *self.q + *other.q, r: *self.r + *other.r }
    }

    fn subtract(self: @HexCoordinate, other: @HexCoordinate) -> HexCoordinate {
        HexCoordinate { q: *self.q - *other.q, r: *self.r - *other.r }
    }

    fn distance(self: @HexCoordinate, other: @HexCoordinate) -> i32 {
        let diff = self.subtract(other);
        (abs(diff.q) + abs(diff.q + diff.r) + abs(diff.r)) / 2
    }
}

// Helper function for absolute value
fn abs(value: i32) -> i32 {
    if value < 0 {
        -value
    } else {
        value
    }
}
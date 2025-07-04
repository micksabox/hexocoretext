pub mod hex_grid;
pub mod game_logic;
pub mod word_validator;
pub mod turn_validator;
pub mod types;
pub mod spiral_coords;
pub mod grid_scenario;
pub mod cell_map;

#[cfg(test)]
pub mod tests;

// Re-export main types and functions
pub use types::{HexCoordinate, Direction, CellData, PlayerTurn};
pub use hex_grid::{HexGrid, HexGridTrait};
pub use game_logic::{GameLogic, GameLogicTrait, GameConfig};
pub use word_validator::{WordValidator, WordValidatorTrait};
pub use turn_validator::{TurnValidator, TurnValidatorTrait, TurnValidationError};
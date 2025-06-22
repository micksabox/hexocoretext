pub mod hex_grid;
pub mod game_logic;
pub mod word_validator;
pub mod types;

// Re-export main types and functions
pub use types::{HexCoordinate, Direction, CellState, GameConfig};
pub use hex_grid::{HexGrid, HexGridTrait};
pub use game_logic::{GameLogic, GameLogicTrait};
pub use word_validator::{WordValidator, WordValidatorTrait};
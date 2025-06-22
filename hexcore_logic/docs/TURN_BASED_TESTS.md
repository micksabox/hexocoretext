# Turn-Based Test Documentation

Game logic tests consist of setting up games with predefined scenarios.
Turn actions are performed against the game scenario and the results are checked.

## Overview

This document describes the comprehensive test suite for the Hexcoretext turn-based gameplay mechanics. The tests are organized into focused modules that cover all aspects of the classic game mode.

## PlayerTurn Structure

The `PlayerTurn` struct encapsulates all information needed for a player's turn:

```cairo
pub struct PlayerTurn {
    pub player_index: u8,              // Which player (0 or 1)
    pub word: Array<u8>,              // Letters forming the word
    pub tile_positions: Array<HexCoordinate>,  // Ordered positions for letter chain
    pub tile_swap: Option<TileSwap>,  // Optional tile swap
    pub merkle_proof: Array<felt252>, // Proof for word validation
}

pub struct TileSwap {
    pub from: HexCoordinate,
    pub to: HexCoordinate,
}
```

## Test Module Structure

### 1. Turn Validation Tests (`turn_validation_tests.cairo`)

Tests the core validation logic for player turns:
- **Player turn order**: Ensures only the current player can make a move
- **Word length validation**: Minimum 3 letters required
- **Tile chain connectivity**: All tiles must be adjacent neighbors
- **Grid boundary checks**: All positions must be within the hex grid
- **Duplicate position detection**: No tile can be used twice in one word
- **Word-position alignment**: Word length must match tile positions

Edge cases covered:
- Empty turns
- Circular paths
- Disconnected tile chains
- Out-of-bounds positions

### 2. Tile Capture Tests (`tile_capture_tests.cairo`)

Tests the mechanics of capturing tiles:
- **Capturing uncaptured tiles**: Basic capture mechanics
- **Using own captured tiles**: Allowed for word chaining
- **Opponent tile restrictions**: Cannot use opponent's tiles
- **Locked tile restrictions**: Cannot capture locked tiles
- **Mixed state handling**: Complex board states with various tile ownerships

Edge cases covered:
- Single tile captures
- Boundary tile captures
- Repeated tile usage attempts

### 3. Hexagon Formation Tests (`hexagon_formation_tests.cairo`)

Tests hexagon detection and formation:
- **Single hexagon formation**: 7 tiles (center + 6 neighbors)
- **Multiple hexagon formation**: Multiple hexagons in one turn
- **Majority calculation**: Determining who locks the center tile
- **Super hexagon detection**: All 7 tiles locked by same player
- **Incomplete hexagons**: Missing one or more tiles

Edge cases covered:
- Tied majority (3-3 split)
- Hexagons at grid edges
- Overlapping hexagons
- Chain formations

### 4. Scoring Tests (`scoring_tests.cairo`)

Tests point calculation mechanics:
- **Basic word scoring**: 1 point per captured tile
- **Hexagon bonus**: 3 additional points per hexagon
- **Multiple hexagon scoring**: Cumulative bonuses
- **Opponent hexagon formation**: Points go to majority holder
- **Score limit detection**: Game ends at 16 points (configurable)

Edge cases covered:
- Zero score turns
- Exactly reaching score limit
- Exceeding score limit
- Tied scores

### 5. Tile Swap Tests (`tile_swap_tests.cairo`)

Tests the once-per-turn tile swap mechanic:
- **Valid neighbor swaps**: Only adjacent tiles can swap
- **Swap restrictions**: Cannot swap locked tiles
- **Swap and capture combo**: Using swapped tile in same turn
- **Captured tile swaps**: Allowed if tiles are unlocked

Edge cases covered:
- Non-adjacent swap attempts
- Self-swap attempts
- Swaps at grid boundaries
- Multiple swap attempts

### 6. Tile Replacement Tests (`tile_replacement_tests.cairo`)

Tests tile replacement after hexagon captures:
- **Single hexagon replacement**: 6 surrounding tiles replaced
- **Multiple hexagon replacement**: Handling overlaps
- **Super hexagon replacement**: All 7 tiles replaced
- **Locked tile exclusion**: Locked tiles not replaced
- **Letter generation**: Deterministic based on position and game ID

Edge cases covered:
- Replacements at grid edges
- Chain reactions
- Empty hexagon lists

### 7. Game State Tests (`game_state_tests.cairo`)

Tests game lifecycle and state management:
- **Game initialization**: Starting configuration
- **Turn rotation**: Player index cycling
- **Game end detection**: Score limit reached
- **Winner determination**: Highest score wins
- **Move prevention**: No moves after game ends

Edge cases covered:
- Single player games
- Simultaneous win conditions
- Zero score limits
- Very high score limits

### 8. Integration Tests (`integration_tests.cairo`)

Complete game scenario tests:
- **Full game simulation**: Multiple turns to completion
- **Complex board states**: Mixed ownership and locks
- **Multi-hexagon turns**: Testing complex captures
- **Competitive scenarios**: Both players near winning
- **Super hexagon cascades**: Chain reactions

## Key Design Decisions

1. **Turn Validation in Tests**: Validation logic is tested through assertions rather than returning validation result structs. This keeps the test code focused on behavior verification.

2. **Modular Test Structure**: Each test module focuses on a specific aspect of gameplay, making it easy to locate and update tests for specific features.

3. **Edge Case Coverage**: Extensive edge case testing ensures robustness of the game logic implementation.

4. **Helper Functions**: Common test utilities reduce code duplication and improve readability.

## Running the Tests

Tests are executed using the Scarb build tool:

```bash
cd hexcore_logic
scarb test
```

Individual test modules can be run by specifying the module name:

```bash
scarb test tile_capture_tests
```

## Future Considerations

- Additional game modes can extend the test structure
- Performance benchmarking for complex board states
- Fuzz testing for unexpected input combinations
- Integration with contract-level tests when implementing Dojo
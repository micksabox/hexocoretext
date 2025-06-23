# Hexagon Detection Algorithm

## Overview

The hexagon detection algorithm in Hexocoretext ensures that all possible hexagon formations are detected during a turn, even when the center of the hexagon wasn't part of the captured tiles in that turn.

## Problem Statement

In the previous implementation, hexagon detection only checked if tiles captured in the current turn could form hexagon centers. This missed scenarios where:
- Player A has already captured the center and some neighbors
- Player B captures the remaining neighbors, completing a hexagon
- The hexagon should be detected even though the center wasn't in Player B's turn

## Solution

The algorithm now follows these steps:

### 1. Apply Captures
First, update the game state with all valid captures from the current turn:
```cairo
// Apply captures from this turn
let mut i = 0;
while i < turn.tile_positions.len() {
    let coord = turn.tile_positions.at(i);
    // Check if the cell can be captured (not locked, not opponent's)
    if can_capture(coord) {
        cells_captured.append(*coord);
        cell_map.set_captured_by(coord, Option::Some(player_address));
    }
    i += 1;
};
```

### 2. Check All Grid Coordinates
Instead of only checking the captured tiles, iterate through ALL coordinates in the grid:
```cairo
let all_hexagons = self.find_all_hexagon_formations(ref cell_map);
```

### 3. Detect Complete Hexagons
For each coordinate, check if it's the center of a complete hexagon:
- Has exactly 6 neighbors (not on edge)
- Center is captured
- All 6 neighbors are captured (by any player)

### 4. Determine Majority Owner
Count which player owns the most tiles in the hexagon (center + 6 neighbors):
```cairo
fn get_hexagon_majority_owner(self: @GameLogic, ref cell_map: CellMap, center: @HexCoordinate) -> Option<ContractAddress> {
    // Count ownership of center + all neighbors
    // Return the player with the most tiles
    // Return None if there's a tie
}
```

### 5. Lock Center Tiles
If a player has majority, lock the center tile for them:
```cairo
if let Option::Some(majority_owner) = self.get_hexagon_majority_owner(ref cell_map, center) {
    cell_map.set_locked_by(center, Option::Some(majority_owner));
    cell_map.set_captured_by(center, Option::Some(majority_owner));
    hexagons_formed.append(*center);
}
```

### 6. Detect Super Hexagons
After locking tiles, check for super hexagons (all 7 tiles locked):
```cairo
superhexagons_formed = self.find_super_hexagon_formations(ref cell_map);
```

### 7. Build Replacement List
- For regular hexagons: replace surrounding unlocked tiles
- For super hexagons: replace all 7 tiles

## Key Changes

1. **`find_all_hexagon_formations`** - New method that checks entire grid instead of just turn tiles
2. **`is_complete_hexagon_center`** - Checks if all 7 cells are captured (by any player)
3. **`get_hexagon_majority_owner`** - Determines which player owns the hexagon
4. **Updated `calculate_turn`** - Implements the complete algorithm

## Edge Cases Handled

1. **Mixed Ownership**: Hexagons can have tiles owned by different players
2. **Opponent Tiles**: Cannot capture tiles already captured by opponents
3. **Locked Tiles**: Cannot capture locked tiles (unless they're your own)
4. **Tie Scenarios**: No center locking if ownership is tied
5. **Super Hexagons**: All locked tiles trigger complete replacement

## Testing

The implementation includes comprehensive tests for:
- Basic hexagon formation
- Hexagon completion by different player
- Mixed ownership scenarios
- Super hexagon detection
- Tile replacement logic

All tests pass, confirming the algorithm correctly handles all game scenarios according to the PRD requirements.
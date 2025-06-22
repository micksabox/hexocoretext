# Super Hexagon Feature

## Overview

A super hexagon is formed when all 7 tiles (center + 6 neighbors) of a hexagon pattern are locked, regardless of which player(s) locked them. This triggers additional tile replacements.

## Detection Logic

The super hexagon detection works as follows:

1. **After each turn**, the system checks all possible hexagon centers in the grid
2. For each potential center:
   - Check if the center tile is locked
   - Check if all 6 neighbor tiles are locked (by any player)
   - If all 7 tiles are locked, it's a super hexagon

## Implementation Details

### Key Functions

- `find_super_hexagon_formations()`: Scans the entire grid for super hexagons
- `is_super_hexagon_center()`: Checks if a specific coordinate is the center of a super hexagon
- `get_locked_by()`: Helper method to get the locking player for a cell

### TurnSideEffects Structure

The `TurnSideEffects` structure now includes:
```cairo
pub struct TurnSideEffects {
    pub cells_captured: Array<HexCoordinate>,
    pub hexagons_formed: Array<HexCoordinate>,  // Centers of hexagons
    pub superhexagons_formed: Array<HexCoordinate>,  // Centers of super hexagons
    pub tiles_replaced: Array<HexCoordinate>,
}
```

### Tile Replacement Logic

When a super hexagon is detected:
1. All 7 tiles of the super hexagon are marked for replacement
2. This is in addition to any regular hexagon replacements
3. The system ensures no duplicate replacements

## Example Scenario

```
    N
   / \
 NW   NE
 |  C  |
 SW   SE
   \ /
    S
```

If all 7 positions (C, N, NE, SE, S, SW, NW) are locked (by any player or combination of players), this forms a super hexagon centered at C.

## Testing

The feature includes comprehensive tests in `super_hexagon_tests.cairo`:
- Detection of valid super hexagons
- Support for mixed ownership patterns (all locked is what matters)
- Rejection when not all tiles are locked
- Proper tile replacement handling

## Performance Considerations

- Uses the efficient `CellMap` structure for O(1) lookups
- Only checks valid grid coordinates
- Minimal overhead added to turn processing
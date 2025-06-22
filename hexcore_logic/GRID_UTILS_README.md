# Grid Utilities for Hexcore Logic

## Overview

The grid utilities provide a convenient way to create game grid scenarios without manually specifying hex coordinates. They use a spiral traversal pattern starting from the center and moving outward ring by ring. These utilities can be used for testing, game setup, visualization, or any other purpose requiring hex grid manipulation.

## Modules

### `spiral_coords`
Provides coordinate generation utilities for hex grids using a spiral pattern. Can be used independently for any hex grid coordinate needs.

### `grid_scenario`
Builds on `spiral_coords` to provide high-level grid scenario creation utilities. Maps flat arrays of game states to hex grid positions.

## Spiral Pattern

For a hex grid with radius N:
- Ring 0 (center): 1 cell at (0,0)
- Ring 1: 6 cells surrounding the center
- Ring 2: 12 cells
- Ring k: 6*k cells

Total cells for radius N: 1 + 3*N*(N+1)

### Traversal Order

Starting from the center (0,0), the spiral moves:
1. North to start each ring
2. Then clockwise: Northeast → Southeast → South → Southwest → Northwest

## Usage

### Basic Example

```cairo
use hexcore_logic::grid_scenario::{
    map_scenario_to_cells, gs, gs_captured, gs_locked
};

// Create a scenario for radius 1 grid (7 cells)
let scenario = array![
    gs('H'),                    // Center
    gs('E'),                    // North
    gs('X'),                    // Northeast
    gs('A'),                    // Southeast
    gs('G'),                    // South
    gs('O'),                    // Southwest
    gs('N'),                    // Northwest
];

// Map to actual cells with coordinates
let cells = map_scenario_to_cells(1, scenario);
```

### Helper Functions

- `gs(letter)` - Create a simple cell with just a letter
- `gs_captured(letter, player)` - Create a captured cell
- `gs_locked(letter, player)` - Create a locked cell

### Coordinate Mapping

For a radius 1 grid, the mapping is:
```
Index | Position   | Coordinates
------|------------|------------
  0   | Center     | (0, 0)
  1   | North      | (0, -1)
  2   | Northeast  | (1, -1)
  3   | Southeast  | (1, 0)
  4   | South      | (0, 1)
  5   | Southwest  | (-1, 1)
  6   | Northwest  | (-1, 0)
```

### Visual Reference

```
      2
   1     3
      0
   6     4
      5
```

## Testing Patterns

### Hexagon Capture Pattern
```cairo
// All cells captured by same player
let scenario = array![
    gs_captured('A', player1),  // Center
    gs_captured('B', player1),  // North
    gs_captured('C', player1),  // Northeast
    // ... etc for all 6 surrounding cells
];
```

### Partial Grid
You can provide fewer cells than the full grid size. The harness will map only the cells provided:

```cairo
// Only define center and north cells
let scenario = array![
    gs('H'),  // Center
    gs('E'),  // North
];
let cells = map_scenario_to_cells(2, scenario); // Grid size 2, but only 2 cells defined
```

## Integration with Game Logic

The grid utilities produce `CellData` structures that can be easily converted to your game's cell format:

```cairo
let cells = map_scenario_to_cells(1, scenario);
for cell in cells {
    // cell.coordinate - HexCoordinate with q, r
    // cell.letter - felt252
    // cell.captured_by - Option<ContractAddress>
    // cell.locked_by - Option<ContractAddress>
}
```
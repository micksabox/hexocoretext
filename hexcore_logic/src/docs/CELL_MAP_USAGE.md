# CellMap Usage Guide

The `CellMap` module provides an efficient hash map-based structure for storing and retrieving `CellData` by `HexCoordinate`. This allows O(1) lookups instead of O(n) linear searches through arrays.

## Key Features

- **O(1) Lookups**: Uses Poseidon hash to create unique keys from hex coordinates
- **Memory Efficient**: Stores cell data components in separate dictionaries
- **Easy Integration**: Works seamlessly with existing `CellData` arrays

## Usage Example

```cairo
use hexcore_logic::cell_map::CellMapTrait;

// Create from an array of CellData
let cells = array![
    CellData { coordinate: HexCoordinate { q: 0, r: 0 }, letter: 'A', ... },
    CellData { coordinate: HexCoordinate { q: 1, r: 0 }, letter: 'B', ... },
    // ... more cells
];

let mut cell_map = CellMapTrait::from_array(@cells);

// Check if a coordinate exists
let coord = HexCoordinate { q: 0, r: 0 };
if cell_map.contains(@coord) {
    // Get the cell data
    let cell_option = cell_map.get(@coord);
    
    // Check if cell is locked
    if !cell_map.is_locked(@coord) {
        // Cell can be captured
    }
}
```

## Implementation Details

The `CellMap` uses:
- Poseidon hash function to convert (q, r) coordinates into unique felt252 keys
- Separate `Felt252Dict` for each field (letter, captured_by, locked_by)
- An exists_map to track which coordinates are present

This design is necessary because Cairo's dictionaries can only store felt252 values, not complex structures.

## Performance Benefits

Before (linear search):
```cairo
// O(n) search through array
let mut j = 0;
while j < grid_scenario.len() {
    let cell_data = grid_scenario.at(j);
    if cell_data.coordinate.q == coord.q && cell_data.coordinate.r == coord.r {
        // Found the cell
        break;
    }
    j += 1;
};
```

After (hash map lookup):
```cairo
// O(1) lookup
if !cell_map.is_locked(@coord) {
    cells_captured.append(*coord);
}
```

For a typical game with ~100 cells and multiple lookups per turn, this significantly improves performance.
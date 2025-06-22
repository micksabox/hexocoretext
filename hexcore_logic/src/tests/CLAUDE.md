# Testing strategy

- Use grid_scenario.cairo utilities when setting up tests. This way, you can load an in-memory array representation of a grid using map_scenario_to_cells.

## Unit Tests
Turns can be applied against a grid representation and expected side effects asserted.

Turn side effects:
- cells captured. Output is array of HexCoordinate representing the captured tiles.
- hexagons formed. Output is array of HexCoordinate representing the centers of the hexagons.
- tiles replaced. Output is array of HexCoordinate that need to be replaced.

Turn validity
- turn positions cannot be duplicated
- the swap consists of neighbours and are not locked
- the word is valid (TODO: leave mocked for now)

## Integration Tests

To test further logic, integration tests need game state storage to assert behaviour against the game itself.
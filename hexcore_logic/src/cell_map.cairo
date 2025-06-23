use super::types::{HexCoordinate, CellData};
use core::poseidon::poseidon_hash_span;
use core::dict::Felt252Dict;
use core::dict::Felt252DictTrait;

// Compute hash for a hex coordinate to use as dictionary key
pub fn hash_coordinate(coord: @HexCoordinate) -> felt252 {
    // Use poseidon hash to combine q and r into a single felt252
    poseidon_hash_span([(*coord.q).into(), (*coord.r).into()].span())
}

// Cell map structure that stores CellData indexed by coordinate hash
#[derive(Destruct)]
pub struct CellMap {
    // We need to store each field separately since Felt252Dict only stores felt252
    letter_map: Felt252Dict<felt252>,
    captured_by_map: Felt252Dict<felt252>,
    locked_by_map: Felt252Dict<felt252>,
    // Track which coordinates exist in the map
    exists_map: Felt252Dict<bool>,
}

#[generate_trait]
pub impl CellMapImpl of CellMapTrait {
    // Create an empty cell map
    fn new() -> CellMap {
        CellMap {
            letter_map: Default::default(),
            captured_by_map: Default::default(),
            locked_by_map: Default::default(),
            exists_map: Default::default(),
        }
    }

    // Create a cell map from an array of CellData
    fn from_array(cells: @Array<CellData>) -> CellMap {
        let mut map = Self::new();
        
        let mut i = 0;
        while i < cells.len() {
            let cell = cells.at(i);
            map.insert(cell);
            i += 1;
        };
        
        map
    }

    // Insert a cell into the map
    fn insert(ref self: CellMap, cell: @CellData) {
        let key = hash_coordinate(cell.coordinate);
        
        // Store the letter
        self.letter_map.insert(key, *cell.letter);
        
        // Store captured_by (0 if None)
        let captured_value = match *cell.captured_by {
            Option::Some(addr) => addr.into(),
            Option::None => 0,
        };
        self.captured_by_map.insert(key, captured_value);
        
        // Store locked_by (0 if None)
        let locked_value = match *cell.locked_by {
            Option::Some(addr) => addr.into(),
            Option::None => 0,
        };
        self.locked_by_map.insert(key, locked_value);
        
        // Mark this coordinate as existing
        self.exists_map.insert(key, true);
    }

    // Get a cell from the map by coordinate
    fn get(ref self: CellMap, coord: @HexCoordinate) -> Option<CellData> {
        let key = hash_coordinate(coord);
        
        // Check if this coordinate exists in the map
        if !self.exists_map.get(key) {
            return Option::None;
        }
        
        // Retrieve the letter
        let letter = self.letter_map.get(key);
        
        // Retrieve captured_by
        let captured_value = self.captured_by_map.get(key);
        let captured_by = if captured_value == 0 {
            Option::None
        } else {
            Option::Some(captured_value.try_into().unwrap())
        };
        
        // Retrieve locked_by
        let locked_value = self.locked_by_map.get(key);
        let locked_by = if locked_value == 0 {
            Option::None
        } else {
            Option::Some(locked_value.try_into().unwrap())
        };
        
        Option::Some(CellData {
            coordinate: *coord,
            letter,
            captured_by,
            locked_by,
        })
    }

    // Check if a coordinate exists in the map
    fn contains(ref self: CellMap, coord: @HexCoordinate) -> bool {
        let key = hash_coordinate(coord);
        self.exists_map.get(key)
    }

    // Check if a cell is locked
    fn is_locked(ref self: CellMap, coord: @HexCoordinate) -> bool {
        match self.get(coord) {
            Option::Some(cell) => cell.locked_by.is_some(),
            Option::None => false,
        }
    }

    // Check if a cell is captured
    fn is_captured(ref self: CellMap, coord: @HexCoordinate) -> bool {
        match self.get(coord) {
            Option::Some(cell) => cell.captured_by.is_some(),
            Option::None => false,
        }
    }

    // Get locked_by for a coordinate
    fn get_locked_by(ref self: CellMap, coord: @HexCoordinate) -> Option<felt252> {
        match self.get(coord) {
            Option::Some(cell) => match cell.locked_by {
                Option::Some(addr) => Option::Some(addr.into()),
                Option::None => Option::None,
            },
            Option::None => Option::None,
        }
    }

    // Get captured_by for a coordinate
    fn get_captured_by(ref self: CellMap, coord: @HexCoordinate) -> Option<starknet::ContractAddress> {
        match self.get(coord) {
            Option::Some(cell) => cell.captured_by,
            Option::None => Option::None,
        }
    }

    // Set captured_by for a coordinate
    fn set_captured_by(ref self: CellMap, coord: @HexCoordinate, captured_by: Option<starknet::ContractAddress>) {
        let key = hash_coordinate(coord);
        
        // Update captured_by
        let captured_value = match captured_by {
            Option::Some(addr) => addr.into(),
            Option::None => 0,
        };
        self.captured_by_map.insert(key, captured_value);
        
        // Ensure the coordinate is marked as existing if setting a value
        if captured_by.is_some() {
            self.exists_map.insert(key, true);
        }
    }

    // Set locked_by for a coordinate
    fn set_locked_by(ref self: CellMap, coord: @HexCoordinate, locked_by: Option<starknet::ContractAddress>) {
        let key = hash_coordinate(coord);
        
        // Update locked_by
        let locked_value = match locked_by {
            Option::Some(addr) => addr.into(),
            Option::None => 0,
        };
        self.locked_by_map.insert(key, locked_value);
        
        // Ensure the coordinate is marked as existing if setting a value
        if locked_by.is_some() {
            self.exists_map.insert(key, true);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{CellMapTrait, hash_coordinate};
    use super::super::types::{HexCoordinate, CellData};
    use starknet::contract_address_const;

    #[test]
    fn test_hash_coordinate() {
        let coord1 = HexCoordinate { q: 0, r: 0 };
        let coord2 = HexCoordinate { q: 0, r: 0 };
        let coord3 = HexCoordinate { q: 1, r: 0 };
        
        // Same coordinates should produce same hash
        assert(hash_coordinate(@coord1) == hash_coordinate(@coord2), 'Same coords same hash');
        
        // Different coordinates should produce different hash
        assert(hash_coordinate(@coord1) != hash_coordinate(@coord3), 'Diff coords diff hash');
    }

    #[test]
    fn test_insert_and_get() {
        let mut map = CellMapTrait::new();
        
        let coord = HexCoordinate { q: 1, r: 2 };
        let player = contract_address_const::<'PLAYER1'>();
        
        let cell = CellData {
            coordinate: coord,
            letter: 'A',
            captured_by: Option::Some(player),
            locked_by: Option::None,
        };
        
        map.insert(@cell);
        
        // Should be able to retrieve the cell
        let retrieved = map.get(@coord);
        assert(retrieved.is_some(), 'Cell should exist');
        
        let retrieved_cell = retrieved.unwrap();
        assert(retrieved_cell.letter == 'A', 'Letter should match');
        assert(retrieved_cell.captured_by == Option::Some(player), 'Captured by should match');
        assert(retrieved_cell.locked_by == Option::None, 'Locked by should match');
    }

    #[test]
    fn test_from_array() {
        let player1 = contract_address_const::<'PLAYER1'>();
        let player2 = contract_address_const::<'PLAYER2'>();
        
        let cells = array![
            CellData {
                coordinate: HexCoordinate { q: 0, r: 0 },
                letter: 'A',
                captured_by: Option::Some(player1),
                locked_by: Option::None,
            },
            CellData {
                coordinate: HexCoordinate { q: 1, r: 0 },
                letter: 'B',
                captured_by: Option::None,
                locked_by: Option::None,
            },
            CellData {
                coordinate: HexCoordinate { q: 0, r: 1 },
                letter: 'C',
                captured_by: Option::Some(player2),
                locked_by: Option::Some(player2),
            },
        ];
        
        let mut map = CellMapTrait::from_array(@cells);
        
        // Check first cell
        assert(map.contains(@HexCoordinate { q: 0, r: 0 }), 'Should contain (0,0)');
        assert(map.is_captured(@HexCoordinate { q: 0, r: 0 }), 'Should be captured');
        assert(!map.is_locked(@HexCoordinate { q: 0, r: 0 }), 'Should not be locked');
        
        // Check second cell
        assert(map.contains(@HexCoordinate { q: 1, r: 0 }), 'Should contain (1,0)');
        assert(!map.is_captured(@HexCoordinate { q: 1, r: 0 }), 'Should not be captured');
        assert(!map.is_locked(@HexCoordinate { q: 1, r: 0 }), 'Should not be locked');
        
        // Check third cell
        assert(map.contains(@HexCoordinate { q: 0, r: 1 }), 'Should contain (0,1)');
        assert(map.is_captured(@HexCoordinate { q: 0, r: 1 }), 'Should be captured');
        assert(map.is_locked(@HexCoordinate { q: 0, r: 1 }), 'Should be locked');
        
        // Check non-existent cell
        assert(!map.contains(@HexCoordinate { q: 5, r: 5 }), 'Should not contain (5,5)');
    }
}
use crate::models::HexCoordinate as DojoHexCoordinate;
use hexcore_logic::types::HexCoordinate as CoreHexCoordinate;

// Convert Dojo coordinate to Core coordinate
pub fn dojo_to_core_coord(coord: @DojoHexCoordinate) -> CoreHexCoordinate {
    CoreHexCoordinate { q: *coord.q, r: *coord.r }
}

// Convert array of Dojo coordinates to array of Core coordinates
pub fn dojo_to_core_coords(coords: @Array<DojoHexCoordinate>) -> Array<CoreHexCoordinate> {
    let mut result = array![];
    let mut i = 0;
    while i < coords.len() {
        let coord = coords[i];
        result.append(dojo_to_core_coord(coord));
        i += 1;
    };
    result
}

// Convert Core coordinate to Dojo coordinate
pub fn core_to_dojo_coord(coord: @CoreHexCoordinate) -> DojoHexCoordinate {
    DojoHexCoordinate { q: *coord.q, r: *coord.r }
}

// Convert array of Core coordinates to array of Dojo coordinates
pub fn core_to_dojo_coords(coords: @Array<CoreHexCoordinate>) -> Array<DojoHexCoordinate> {
    let mut result = array![];
    let mut i = 0;
    while i < coords.len() {
        let coord = coords[i];
        result.append(core_to_dojo_coord(coord));
        i += 1;
    };
    result
}
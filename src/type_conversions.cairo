// Type conversions between Dojo models and hexcore_logic types
use crate::models::{HexCoordinate as DojoHexCoordinate};
use hexcore_logic::types::{HexCoordinate as CoreHexCoordinate};

// Convert Dojo HexCoordinate to Core HexCoordinate
pub fn dojo_to_core_coord(dojo_coord: @DojoHexCoordinate) -> CoreHexCoordinate {
    CoreHexCoordinate { q: *dojo_coord.q, r: *dojo_coord.r }
}

// Convert Core HexCoordinate to Dojo HexCoordinate
pub fn core_to_dojo_coord(core_coord: @CoreHexCoordinate) -> DojoHexCoordinate {
    DojoHexCoordinate { q: *core_coord.q, r: *core_coord.r }
}

// Convert array of Dojo HexCoordinates to Core HexCoordinates
pub fn dojo_to_core_coords(dojo_coords: @Array<DojoHexCoordinate>) -> Array<CoreHexCoordinate> {
    let mut core_coords = array![];
    let mut i = 0;
    while i < dojo_coords.len() {
        core_coords.append(dojo_to_core_coord(dojo_coords.at(i)));
        i += 1;
    };
    core_coords
}

// Convert array of Core HexCoordinates to Dojo HexCoordinates
pub fn core_to_dojo_coords(core_coords: @Array<CoreHexCoordinate>) -> Array<DojoHexCoordinate> {
    let mut dojo_coords = array![];
    let mut i = 0;
    while i < core_coords.len() {
        dojo_coords.append(core_to_dojo_coord(core_coords.at(i)));
        i += 1;
    };
    dojo_coords
}
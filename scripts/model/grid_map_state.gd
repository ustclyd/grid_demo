class_name GridMapState
extends RefCounted

var tiles: Array[TileState] = []
var portal_pairs: Array[PortalPairState] = []

var storm_active: bool = false
var storm_center: Vector2i = Vector2i.ZERO
var storm_radius: int = 0
var storm_expand_every_turns: int = 2

var exit_portal_tile: Vector2i = Vector2i.ZERO


func get_tile_at(pos: Vector2i) -> TileState:
	for tile in tiles:
		if tile.pos == pos:
			return tile
	return null


func get_portal_pair_by_id(pair_id: int) -> PortalPairState:
	for pair in portal_pairs:
		if pair.id == pair_id:
			return pair
	return null


func duplicate_state() -> GridMapState:
	var copy := GridMapState.new()
	copy.storm_active = storm_active
	copy.storm_center = storm_center
	copy.storm_radius = storm_radius
	copy.storm_expand_every_turns = storm_expand_every_turns
	copy.exit_portal_tile = exit_portal_tile

	for tile in tiles:
		copy.tiles.append(tile.duplicate_state())
	for pair in portal_pairs:
		copy.portal_pairs.append(pair.duplicate_state())

	return copy

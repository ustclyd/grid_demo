class_name GameState
extends RefCounted

var board_size: Vector2i = Vector2i(7, 7)
var turn_index: int = 0

var units: Array[UnitState] = []
var bags: Array[BagState] = []
var tiles: Array[TileState] = []
var portal_pairs: Array[PortalPairState] = []

var storm_active: bool = false
var storm_center: Vector2i = Vector2i.ZERO
var storm_radius: int = 0
var storm_expand_every_turns: int = 2

var ultimate_bag_id: int = -1
var exit_portal_tile: Vector2i = Vector2i.ZERO


func get_unit_by_id(unit_id: int) -> UnitState:
	for unit in units:
		if unit.id == unit_id:
			return unit
	return null


func get_bag_by_id(bag_id: int) -> BagState:
	for bag in bags:
		if bag.id == bag_id:
			return bag
	return null


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


func duplicate_state() -> GameState:
	var copy := GameState.new()
	copy.board_size = board_size
	copy.turn_index = turn_index
	copy.storm_active = storm_active
	copy.storm_center = storm_center
	copy.storm_radius = storm_radius
	copy.storm_expand_every_turns = storm_expand_every_turns
	copy.ultimate_bag_id = ultimate_bag_id
	copy.exit_portal_tile = exit_portal_tile

	for unit in units:
		copy.units.append(unit.duplicate_state())
	for bag in bags:
		copy.bags.append(bag.duplicate_state())
	for tile in tiles:
		copy.tiles.append(tile.duplicate_state())
	for pair in portal_pairs:
		copy.portal_pairs.append(pair.duplicate_state())

	return copy

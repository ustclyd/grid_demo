class_name GameState
extends RefCounted

var board_size: Vector2i = Vector2i(7, 7)
var turn_index: int = 0

var units: Array[UnitState] = []
var bags: Array[BagState] = []
var ultimate_bag_id: int = -1
var map_state := GridMapState.new()
var trail: PuzzleTrail
var pressure_cells: Array[Vector2i] = []


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


func occupied_pressure_cells() -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	if pressure_cells.is_empty():
		return occupied
	for unit in units:
		if unit.alive and not unit.won and pressure_cells.has(unit.pos):
			occupied.append(unit.pos)
	return occupied


func duplicate_state() -> GameState:
	var copy := GameState.new()
	copy.board_size = board_size
	copy.turn_index = turn_index
	copy.ultimate_bag_id = ultimate_bag_id
	copy.map_state = map_state.duplicate_state()
	copy.pressure_cells = pressure_cells.duplicate()
	if trail != null:
		copy.trail = trail.duplicate_state()

	for unit in units:
		copy.units.append(unit.duplicate_state())
	for bag in bags:
		copy.bags.append(bag.duplicate_state())

	return copy

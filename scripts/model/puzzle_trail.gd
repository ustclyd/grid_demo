class_name PuzzleTrail
extends RefCounted

const PLAYER_ID := 1

var exit_cell: Vector2i
var _floor: Dictionary[Vector2i, bool] = {}
var _left: Dictionary[Vector2i, bool] = {}


func _init(cells: Array[Vector2i] = [], end: Vector2i = Vector2i.ZERO) -> void:
	exit_cell = end
	for cell in cells:
		_floor[cell] = true


func is_floor(cell: Vector2i) -> bool:
	return _floor.has(cell)


func has_left(cell: Vector2i) -> bool:
	return _left.has(cell)


func allows_step(from: Vector2i, to: Vector2i, unit_id: int) -> bool:
	var offset := (to - from).abs()
	return (
		offset.x + offset.y == 1 and is_floor(to)
		and (unit_id != PLAYER_ID or not has_left(to))
	)


func leave(cell: Vector2i) -> void:
	_left[cell] = true


func remaining_cells() -> int:
	return _floor.size() - _left.size() - 1


func is_complete(player_cell: Vector2i) -> bool:
	return player_cell == exit_cell and remaining_cells() == 0


func duplicate_state() -> PuzzleTrail:
	var copy := PuzzleTrail.new()
	copy.exit_cell = exit_cell
	copy._floor = _floor
	copy._left = _left.duplicate()
	return copy

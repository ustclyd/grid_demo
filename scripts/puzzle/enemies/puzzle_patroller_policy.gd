class_name PuzzlePatrollerPolicy
extends PuzzleEnemyPolicy

@export var route: Array[Vector2i] = []


func get_display_name() -> String:
	return "巡回兵"


func is_available() -> bool:
	return kind == Kind.PATROLLER and route.size() >= 3


func accepts_spawn(cell: Vector2i, board_size: Vector2i) -> bool:
	if not is_available() or not route.has(cell):
		return false
	var visited: Dictionary[Vector2i, bool] = {}
	for index in route.size():
		var here := route[index]
		var next := route[(index + 1) % route.size()]
		if visited.has(here) or not TurnResolver.is_valid_move_target(here, next, board_size):
			return false
		visited[here] = true
	return true


func choose_intent(board: GameState, unit_id: int, _player_id: int) -> ActionIntent:
	var unit := board.get_unit_by_id(unit_id)
	var index := route.find(unit.pos)
	if index >= 0:
		var next := route[(index + 1) % route.size()]
		var move := PuzzleActions.create_intent(board, unit_id, ActionType.MOVE, next)
		if move != null:
			return move
	return PuzzleActions.create_intent(board, unit_id, ActionType.STAY)

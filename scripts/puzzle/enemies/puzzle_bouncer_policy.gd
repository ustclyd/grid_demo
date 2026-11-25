class_name PuzzleBouncerPolicy
extends PuzzleEnemyPolicy

@export var endpoint_a := Vector2i.ZERO
@export var endpoint_b := Vector2i.RIGHT


func get_display_name() -> String:
	return "折返兵"


func is_available() -> bool:
	var offset := (endpoint_b - endpoint_a).abs()
	return kind == Kind.BOUNCER and maxi(offset.x, offset.y) == 1


func accepts_spawn(cell: Vector2i, board_size: Vector2i) -> bool:
	return (
		(cell == endpoint_a or cell == endpoint_b)
		and TurnResolver.is_valid_move_target(endpoint_a, endpoint_b, board_size)
		and TurnResolver.is_valid_move_target(endpoint_b, endpoint_a, board_size)
	)


func choose_intent(board: GameState, unit_id: int, _player_id: int) -> ActionIntent:
	var unit := board.get_unit_by_id(unit_id)
	var target := endpoint_b if unit.pos == endpoint_a else endpoint_a
	var move := PuzzleActions.create_intent(board, unit_id, ActionType.MOVE, target)
	return move if move != null else PuzzleActions.create_intent(board, unit_id, ActionType.STAY)

class_name PuzzleStraightMoverPolicy
extends PuzzleEnemyPolicy

@export var direction := Vector2i.RIGHT


func get_display_name() -> String:
	return "定向兵"


func is_available() -> bool:
	return (
		kind == Kind.STRAIGHT_MOVER and direction != Vector2i.ZERO
		and absi(direction.x) <= 1 and absi(direction.y) <= 1
	)


func choose_intent(board: GameState, unit_id: int, _player_id: int) -> ActionIntent:
	var unit := board.get_unit_by_id(unit_id)
	var move := PuzzleActions.create_intent(board, unit_id, ActionType.MOVE, unit.pos + direction)
	return move if move != null else PuzzleActions.create_intent(board, unit_id, ActionType.STAY)

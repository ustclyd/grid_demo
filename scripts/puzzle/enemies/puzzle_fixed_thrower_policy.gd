class_name PuzzleFixedThrowerPolicy
extends PuzzleEnemyPolicy

@export var target_cell := Vector2i.ZERO


func get_display_name() -> String:
	return "定点投手"


func is_available() -> bool:
	return kind == Kind.THROWER


func accepts_spawn(cell: Vector2i, board_size: Vector2i) -> bool:
	return TurnResolver.is_valid_throw_target(cell, target_cell, board_size)


func choose_intent(board: GameState, unit_id: int, _player_id: int) -> ActionIntent:
	var shot := PuzzleActions.create_intent(board, unit_id, ActionType.THROW, target_cell)
	return shot if shot != null else PuzzleActions.create_intent(board, unit_id, ActionType.STAY)

class_name PuzzleAimedThrowerPolicy
extends PuzzleEnemyPolicy


func get_display_name() -> String:
	return "投手"


func is_available() -> bool:
	return kind == Kind.THROWER


func choose_intent(board: GameState, unit_id: int, player_id: int) -> ActionIntent:
	var player := board.get_unit_by_id(player_id)
	var aimed_throw := PuzzleActions.create_intent(board, unit_id, ActionType.THROW, player.pos)
	return aimed_throw if aimed_throw != null else PuzzleActions.create_intent(board, unit_id, ActionType.STAY)

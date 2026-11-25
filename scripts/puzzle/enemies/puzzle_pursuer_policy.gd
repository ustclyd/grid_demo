class_name PuzzlePursuerPolicy
extends PuzzleEnemyPolicy


func get_display_name() -> String:
	return "追兵"


func is_available() -> bool:
	return kind == Kind.PURSUER


func choose_intent(board: GameState, unit_id: int, player_id: int) -> ActionIntent:
	var unit := board.get_unit_by_id(unit_id)
	var player := board.get_unit_by_id(player_id)
	var offset := player.pos - unit.pos
	var step := Vector2i(signi(offset.x), signi(offset.y))
	var move := PuzzleActions.create_intent(board, unit_id, ActionType.MOVE, unit.pos + step)
	return move if move != null else PuzzleActions.create_intent(board, unit_id, ActionType.STAY)

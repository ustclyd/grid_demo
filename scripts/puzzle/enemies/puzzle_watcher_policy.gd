class_name PuzzleWatcherPolicy
extends PuzzlePursuerPolicy

@export var radius: int = 1


func get_display_name() -> String:
	return "警戒兵"


func is_available() -> bool:
	return kind == Kind.WATCHER and radius > 0


func choose_intent(board: GameState, unit_id: int, player_id: int) -> ActionIntent:
	var unit := board.get_unit_by_id(unit_id)
	var player := board.get_unit_by_id(player_id)
	var offset := (player.pos - unit.pos).abs()
	if maxi(offset.x, offset.y) <= radius:
		return super.choose_intent(board, unit_id, player_id)
	return PuzzleActions.create_intent(board, unit_id, ActionType.STAY)

class_name PuzzleSentryPolicy
extends PuzzleEnemyPolicy


func is_available() -> bool:
	return kind == Kind.SENTRY


func choose_intent(board: GameState, unit_id: int, _player_id: int) -> ActionIntent:
	return PuzzleActions.create_intent(board, unit_id, ActionType.STAY)

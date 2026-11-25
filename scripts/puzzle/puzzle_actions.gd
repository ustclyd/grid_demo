class_name PuzzleActions
extends RefCounted


static func create_intent(
	board: GameState,
	unit_id: int,
	action_type: String,
	target: Vector2i = Vector2i.ZERO,
) -> ActionIntent:
	var unit := board.get_unit_by_id(unit_id)
	if unit == null or not unit.alive or unit.won:
		return null
	if unit.stun_turns > 0 and action_type != ActionType.STAY:
		return null

	var intent := ActionIntent.new()
	intent.actor_id = unit_id
	intent.type = action_type
	intent.target_pos = target
	match action_type:
		ActionType.STAY:
			intent.target_pos = unit.pos
		ActionType.MOVE:
			if not TurnResolver.is_valid_move_target(unit.pos, target, board.board_size):
				return null
		ActionType.THROW:
			intent.throw_amount = TurnResolver.standard_throw_amount(unit.coins)
			if intent.throw_amount == 0 or not TurnResolver.is_valid_throw_target(unit.pos, target, board.board_size):
				return null
		_:
			return null
	return intent


static func list_intents(board: GameState, unit_id: int) -> Array[ActionIntent]:
	var actions: Array[ActionIntent] = []
	var stay := create_intent(board, unit_id, ActionType.STAY)
	if stay == null:
		return actions
	actions.append(stay)

	var unit := board.get_unit_by_id(unit_id)
	if unit.stun_turns > 0:
		return actions
	for y in range(-1, 2):
		for x in range(-1, 2):
			var direction := Vector2i(x, y)
			if direction == Vector2i.ZERO:
				continue
			var move := create_intent(board, unit_id, ActionType.MOVE, unit.pos + direction)
			if move != null:
				actions.append(move)
			for distance in range(1, 3):
				var throw := create_intent(board, unit_id, ActionType.THROW, unit.pos + direction * distance)
				if throw != null:
					actions.append(throw)
	return actions

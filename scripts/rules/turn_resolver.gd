class_name TurnResolver
extends RefCounted


func resolve_turn(state: GameState, intents: Array[ActionIntent]) -> TurnResult:
	var result := TurnResult.new()
	result.state_before = state
	result.intents = intents
	result.state_after = state.duplicate_state()
	result.state_after.turn_index += 1

	for unit in result.state_after.units:
		if not unit.alive or unit.won:
			continue

		var intent := _find_intent_for_actor(intents, unit.id)
		unit.prev_pos = unit.pos
		unit.teleported_this_turn = false

		if unit.forced_stay_turns > 0:
			unit.forced_stay_turns -= 1
			intent = null

		if intent == null:
			continue

		match intent.type:
			ActionType.MOVE:
				if _is_inside_board(intent.target_pos, result.state_after.board_size) and intent.target_pos != unit.pos:
					unit.pos = intent.target_pos
					result.moved_unit_ids.append(unit.id)
			ActionType.STAY:
				pass

	return result


func _find_intent_for_actor(intents: Array[ActionIntent], actor_id: int) -> ActionIntent:
	for intent in intents:
		if intent.actor_id == actor_id:
			return intent
	return null


func _is_inside_board(pos: Vector2i, board_size: Vector2i) -> bool:
	return (
		pos.x >= 0
		and pos.y >= 0
		and pos.x < board_size.x
		and pos.y < board_size.y
	)

class_name TurnResolver
extends RefCounted


func resolve_turn(state: GameState, intents: Array[ActionIntent]) -> TurnResult:
	var result := TurnResult.new()
	result.state_before = state
	result.intents = intents
	result.state_after = state.duplicate_state()
	result.state_after.turn_index += 1

	var intent_by_actor_id := _build_intent_lookup(intents)
	var conflict_groups := {}

	for unit in result.state_after.units:
		if not unit.alive or unit.won:
			continue

		var intent: ActionIntent = intent_by_actor_id.get(unit.id)
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

		var pos_key := _pos_key(unit.pos)
		if not conflict_groups.has(pos_key):
			conflict_groups[pos_key] = []
		conflict_groups[pos_key].append(unit)

	_resolve_conflict_phase_one(conflict_groups, intent_by_actor_id, result)

	return result


func _build_intent_lookup(intents: Array[ActionIntent]) -> Dictionary:
	var lookup := {}
	for intent in intents:
		lookup[intent.actor_id] = intent
	return lookup


func _resolve_conflict_phase_one(conflict_groups: Dictionary, intent_by_actor_id: Dictionary, result: TurnResult) -> void:
	for units_in_cell in conflict_groups.values():
		if units_in_cell.size() <= 1:
			if units_in_cell.size() == 1:
				var survivor: UnitState = units_in_cell[0]
				if survivor.alive:
					result.conflict1_survivor_unit_ids.append(survivor.id)
			continue

		var survivor := _pick_conflict_winner(units_in_cell, intent_by_actor_id)
		if survivor == null:
			continue

		result.conflict1_survivor_unit_ids.append(survivor.id)
		for unit in units_in_cell:
			if unit.id == survivor.id:
				continue
			unit.alive = false
			result.conflict1_defeated_unit_ids.append(unit.id)
			result.dead_unit_ids.append(unit.id)


func _pick_conflict_winner(units_in_cell: Array, intent_by_actor_id: Dictionary) -> UnitState:
	var pure_stayers: Array[UnitState] = []
	for unit in units_in_cell:
		var intent: ActionIntent = intent_by_actor_id.get(unit.id)
		if intent == null or intent.type == ActionType.STAY:
			pure_stayers.append(unit)

	var candidates: Array = units_in_cell
	if pure_stayers.size() > 0:
		candidates = pure_stayers

	var winner: UnitState = candidates[0]
	for index in range(1, candidates.size()):
		var challenger: UnitState = candidates[index]
		if _compare_unit_priority(challenger, winner) < 0:
			winner = challenger

	return winner


func _compare_unit_priority(a: UnitState, b: UnitState) -> int:
	if a.coins != b.coins:
		return -1 if a.coins < b.coins else 1

	if a.entry_coins != b.entry_coins:
		return -1 if a.entry_coins < b.entry_coins else 1

	if a.id != b.id:
		return -1 if a.id < b.id else 1

	return 0


func _pos_key(pos: Vector2i) -> String:
	return "%s,%s" % [pos.x, pos.y]


func _is_inside_board(pos: Vector2i, board_size: Vector2i) -> bool:
	return (
		pos.x >= 0
		and pos.y >= 0
		and pos.x < board_size.x
		and pos.y < board_size.y
	)

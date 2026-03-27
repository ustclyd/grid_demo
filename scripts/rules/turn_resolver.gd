class_name TurnResolver
extends RefCounted

const CONFLICT1_ROLE_STAY_PRIORITY := "stay_priority"
const CONFLICT1_ROLE_FORCED_STAY := "forced_stay"
const CONFLICT1_ROLE_NORMAL := "normal"


func resolve_turn(state: GameState, intents: Array[ActionIntent]) -> TurnResult:
	var result := TurnResult.new()
	result.state_before = state
	result.intents = intents
	result.state_after = state.duplicate_state()
	result.state_after.turn_index += 1

	var intent_by_actor_id := _build_intent_lookup(intents)
	_resolve_pick_phase(result.state_after, intent_by_actor_id, result)
	_resolve_throw_phase(result.state_after, intent_by_actor_id, result)
	var conflict_groups := {}

	for unit in result.state_after.units:
		if not unit.alive or unit.won:
			continue

		var intent: ActionIntent = intent_by_actor_id.get(unit.id)
		var conflict1_role := ""
		unit.prev_pos = unit.pos
		unit.teleported_this_turn = false

		if unit.forced_stay_turns > 0:
			unit.forced_stay_turns -= 1
			intent = null
			conflict1_role = CONFLICT1_ROLE_FORCED_STAY

		if intent == null:
			if conflict1_role == "":
				conflict1_role = _get_conflict1_role(unit, intent)
			unit.set_meta("conflict1_role", conflict1_role)
			var null_intent_pos_key := _pos_key(unit.pos)
			if not conflict_groups.has(null_intent_pos_key):
				conflict_groups[null_intent_pos_key] = []
			conflict_groups[null_intent_pos_key].append(unit)
			continue

		match intent.type:
			ActionType.PICK:
				pass
			ActionType.MOVE:
				if _is_valid_move_target(unit.pos, intent.target_pos, result.state_after.board_size):
					unit.pos = intent.target_pos
					result.moved_unit_ids.append(unit.id)
			ActionType.STAY:
				pass

		if conflict1_role == "":
			conflict1_role = _get_conflict1_role(unit, intent)
		unit.set_meta("conflict1_role", conflict1_role)

		var pos_key := _pos_key(unit.pos)
		if not conflict_groups.has(pos_key):
			conflict_groups[pos_key] = []
		conflict_groups[pos_key].append(unit)

	_resolve_conflict_phase_one(conflict_groups, intent_by_actor_id, result)
	var conflict2_groups := _resolve_throw_knockback_phase(result.state_after, result)
	_resolve_conflict_phase_two(conflict2_groups, result)
	_apply_forced_stay_after_knockback(result.state_after, result)

	return result


func _build_intent_lookup(intents: Array[ActionIntent]) -> Dictionary:
	var lookup := {}
	for intent in intents:
		lookup[intent.actor_id] = intent
	return lookup


func _resolve_pick_phase(state_after: GameState, intent_by_actor_id: Dictionary, result: TurnResult) -> void:
	for unit in state_after.units:
		if not unit.alive or unit.won:
			continue

		var intent: ActionIntent = intent_by_actor_id.get(unit.id)
		if intent == null or intent.type != ActionType.PICK:
			continue

		if not _is_valid_pick_target(unit, intent, state_after):
			continue

		var bag := state_after.get_bag_by_id(intent.target_bag_id)

		unit.coins += bag.coins
		result.picked_bag_records.append({
			"unit_id": unit.id,
			"bag_id": bag.id,
			"coins": bag.coins,
		})
		state_after.bags.erase(bag)


func _resolve_throw_phase(state_after: GameState, intent_by_actor_id: Dictionary, result: TurnResult) -> void:
	for unit in state_after.units:
		if not unit.alive or unit.won:
			continue

		var intent: ActionIntent = intent_by_actor_id.get(unit.id)
		if intent == null or intent.type != ActionType.THROW:
			continue

		var throw_amount := intent.throw_amount
		if not _is_valid_throw_action(unit, intent, state_after.board_size):
			continue

		unit.coins -= throw_amount

		var bag := BagState.new()
		bag.id = _get_next_bag_id(state_after)
		bag.pos = intent.target_pos
		bag.coins = throw_amount
		bag.is_throw_bag = true
		state_after.bags.append(bag)

		result.thrown_bag_records.append({
			"unit_id": unit.id,
			"bag_id": bag.id,
			"coins": throw_amount,
			"from": unit.pos,
			"to": intent.target_pos,
		})


func _resolve_throw_knockback_phase(state_after: GameState, result: TurnResult) -> Dictionary:
	var knocked_back_targets := {}
	var targeted_pos_keys := {}

	for throw_record in result.thrown_bag_records:
		var target_pos: Vector2i = throw_record["to"]
		targeted_pos_keys[_pos_key(target_pos)] = target_pos

	for target_pos in targeted_pos_keys.values():
		var survivor := _get_alive_unit_at_pos(state_after, target_pos)
		if survivor == null:
			continue

		result.knocked_back_unit_ids.append(survivor.id)
		survivor.pos = survivor.prev_pos
		knocked_back_targets[survivor.id] = survivor.pos

	var conflict2_groups := {}
	for destination in knocked_back_targets.values():
		var destination_key := _pos_key(destination)
		var occupants: Array[UnitState] = []
		for unit in state_after.units:
			if not unit.alive or unit.won:
				continue
			if unit.pos == destination:
				occupants.append(unit)
		if occupants.size() > 1:
			conflict2_groups[destination_key] = occupants

	return conflict2_groups


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
			_mark_unit_defeated(unit, result.conflict1_defeated_unit_ids, result)


func _resolve_conflict_phase_two(conflict_groups: Dictionary, result: TurnResult) -> void:
	for units_in_cell in conflict_groups.values():
		if units_in_cell.size() <= 1:
			if units_in_cell.size() == 1:
				var survivor: UnitState = units_in_cell[0]
				if survivor.alive and not result.conflict2_survivor_unit_ids.has(survivor.id):
					result.conflict2_survivor_unit_ids.append(survivor.id)
			continue

		var survivor := _pick_standard_conflict_winner(units_in_cell)
		if survivor == null:
			continue

		if not result.conflict2_survivor_unit_ids.has(survivor.id):
			result.conflict2_survivor_unit_ids.append(survivor.id)
		for unit in units_in_cell:
			if unit.id == survivor.id:
				continue
			_mark_unit_defeated(unit, result.conflict2_defeated_unit_ids, result)


func _apply_forced_stay_after_knockback(state_after: GameState, result: TurnResult) -> void:
	for unit_id in result.knocked_back_unit_ids:
		var unit := state_after.get_unit_by_id(unit_id)
		if unit == null or not unit.alive:
			continue
		unit.forced_stay_turns = maxi(unit.forced_stay_turns, 1)
		if not result.forced_stay_unit_ids.has(unit.id):
			result.forced_stay_unit_ids.append(unit.id)


func _get_next_bag_id(state_after: GameState) -> int:
	var max_bag_id := 0
	for bag in state_after.bags:
		if bag.id > max_bag_id:
			max_bag_id = bag.id
	return max_bag_id + 1


func _get_alive_unit_at_pos(state_after: GameState, pos: Vector2i) -> UnitState:
	for unit in state_after.units:
		if unit.alive and not unit.won and unit.pos == pos:
			return unit
	return null


func _pick_conflict_winner(units_in_cell: Array, intent_by_actor_id: Dictionary) -> UnitState:
	var pure_stayers: Array[UnitState] = []
	for unit in units_in_cell:
		var role := _get_unit_conflict1_role(unit, intent_by_actor_id)
		if role == CONFLICT1_ROLE_STAY_PRIORITY or role == CONFLICT1_ROLE_FORCED_STAY:
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


func _pick_standard_conflict_winner(units_in_cell: Array) -> UnitState:
	var winner: UnitState = units_in_cell[0]
	for index in range(1, units_in_cell.size()):
		var challenger: UnitState = units_in_cell[index]
		if _compare_unit_priority(challenger, winner) < 0:
			winner = challenger
	return winner


func _mark_unit_defeated(unit: UnitState, defeated_list: Array[int], result: TurnResult) -> void:
	if not unit.alive:
		return
	unit.alive = false
	if not defeated_list.has(unit.id):
		defeated_list.append(unit.id)
	if not result.dead_unit_ids.has(unit.id):
		result.dead_unit_ids.append(unit.id)


func _get_conflict1_role(unit: UnitState, intent: ActionIntent) -> String:
	if intent == null:
		return CONFLICT1_ROLE_STAY_PRIORITY

	match intent.type:
		ActionType.STAY:
			return CONFLICT1_ROLE_STAY_PRIORITY
		ActionType.MOVE:
			return CONFLICT1_ROLE_STAY_PRIORITY if unit.pos == unit.prev_pos else CONFLICT1_ROLE_NORMAL
		ActionType.PICK:
			return CONFLICT1_ROLE_NORMAL
		ActionType.THROW:
			return CONFLICT1_ROLE_NORMAL

	return CONFLICT1_ROLE_NORMAL


func _is_valid_move_target(from_pos: Vector2i, to_pos: Vector2i, board_size: Vector2i) -> bool:
	if not _is_inside_board(to_pos, board_size):
		return false
	return to_pos != from_pos and maxi(absi(to_pos.x - from_pos.x), absi(to_pos.y - from_pos.y)) <= 1


func _is_valid_pick_target(unit: UnitState, intent: ActionIntent, state_after: GameState) -> bool:
	var bag := state_after.get_bag_by_id(intent.target_bag_id)
	return bag != null and bag.pos == unit.pos


func _is_valid_throw_action(unit: UnitState, intent: ActionIntent, board_size: Vector2i) -> bool:
	if intent.throw_amount <= 0:
		return false
	if unit.coins <= intent.throw_amount:
		return false
	return _is_valid_throw_target(unit.pos, intent.target_pos, board_size)


func _get_unit_conflict1_role(unit: UnitState, intent_by_actor_id: Dictionary) -> String:
	if unit.has_meta("conflict1_role"):
		return String(unit.get_meta("conflict1_role"))

	var intent: ActionIntent = intent_by_actor_id.get(unit.id)
	return _get_conflict1_role(unit, intent)


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


func _is_valid_throw_target(from_pos: Vector2i, to_pos: Vector2i, board_size: Vector2i) -> bool:
	if not _is_inside_board(to_pos, board_size):
		return false

	var delta := to_pos - from_pos
	var abs_x := absi(delta.x)
	var abs_y := absi(delta.y)

	if abs_x == 0 and abs_y == 0:
		return false

	var max_delta := maxi(abs_x, abs_y)
	if max_delta < 1 or max_delta > 2:
		return false

	return (
		abs_x == 0
		or abs_y == 0
		or abs_x == abs_y
	)

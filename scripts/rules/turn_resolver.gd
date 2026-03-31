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
	_tick_portal_cooldowns(result.state_after)
	_resolve_queued_exits(result.state_after, result)
	_refresh_exit_portal_if_used(result.state_after, result)
	_resolve_queued_portals(result.state_after, result)
	_resolve_pick_phase(result.state_after, intent_by_actor_id, result)
	_resolve_throw_phase(result.state_after, intent_by_actor_id, result)
	var conflict_groups := {}

	for unit in result.state_after.units:
		if not unit.alive or unit.won:
			continue

		var intent: ActionIntent = intent_by_actor_id.get(unit.id)
		var conflict1_role := ""
		if not unit.teleported_this_turn:
			unit.prev_pos = unit.pos

		if unit.forced_stay_turns > 0:
			unit.forced_stay_turns -= 1
			if not unit.teleported_this_turn:
				intent = null
				conflict1_role = CONFLICT1_ROLE_FORCED_STAY

		if unit.teleported_this_turn:
			conflict1_role = CONFLICT1_ROLE_NORMAL
			unit.set_meta("conflict1_role", conflict1_role)
			var teleported_pos_key := _pos_key(unit.pos)
			if not conflict_groups.has(teleported_pos_key):
				conflict_groups[teleported_pos_key] = []
			conflict_groups[teleported_pos_key].append(unit)
			continue

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
	_resolve_death_drop_phase(result.state_after, result)
	_apply_forced_stay_after_knockback(result.state_after, result)
	_resolve_exit_reservations(result.state_after, result)
	_resolve_portal_reservations(result.state_after, result)

	return result


func _build_intent_lookup(intents: Array[ActionIntent]) -> Dictionary:
	var lookup := {}
	for intent in intents:
		lookup[intent.actor_id] = intent
	return lookup


func _tick_portal_cooldowns(state_after: GameState) -> void:
	for pair in state_after.portal_pairs:
		pair.tick_cooldown()


func _resolve_queued_exits(state_after: GameState, result: TurnResult) -> void:
	var queued_units_by_pos := {}
	for unit in state_after.units:
		if not unit.alive or unit.won:
			continue
		if not unit.queued_exit:
			continue

		var unit_key := _pos_key(unit.pos)
		if not queued_units_by_pos.has(unit_key):
			queued_units_by_pos[unit_key] = []
		queued_units_by_pos[unit_key].append(unit)

	var queued_bags_by_pos := {}
	for bag in state_after.bags:
		if not bag.queued_exit:
			continue

		var bag_key := _pos_key(bag.pos)
		if not queued_bags_by_pos.has(bag_key):
			queued_bags_by_pos[bag_key] = []
		queued_bags_by_pos[bag_key].append(bag)

	var all_exit_keys := {}
	for key in queued_units_by_pos.keys():
		all_exit_keys[key] = true
	for key in queued_bags_by_pos.keys():
		all_exit_keys[key] = true

	var bags_to_remove: Array[BagState] = []
	for key in all_exit_keys.keys():
		var units_at_pos: Array = queued_units_by_pos.get(key, [])
		var bags_at_pos: Array = queued_bags_by_pos.get(key, [])
		var collector: UnitState = null

		if units_at_pos.size() > 0:
			collector = _pick_exit_coin_collector(units_at_pos)

		for bag in bags_at_pos:
			bag.queued_exit = false
			if collector != null:
				collector.coins += bag.coins
			result.exit_records.append({
				"bag_id": bag.id,
				"from": bag.pos,
				"coins": bag.coins,
			})
			bags_to_remove.append(bag)

		for unit in units_at_pos:
			var exit_from := unit.pos
			unit.queued_exit = false

			if not result.exited_unit_ids.has(unit.id):
				result.exited_unit_ids.append(unit.id)
			result.exit_records.append({
				"unit_id": unit.id,
				"from": exit_from,
				"coins": unit.coins,
			})
			unit.won = true
			unit.alive = false

	for bag in bags_to_remove:
		state_after.bags.erase(bag)


func _refresh_exit_portal_if_used(state_after: GameState, result: TurnResult) -> void:
	if result.exit_records.is_empty():
		return

	var old_exit_pos := state_after.exit_portal_tile
	if not _is_inside_board(old_exit_pos, state_after.board_size):
		old_exit_pos = _find_current_exit_portal_pos(state_after)

	if not _is_inside_board(old_exit_pos, state_after.board_size):
		return

	_clear_exit_portal_at(state_after, old_exit_pos)

	var new_exit_pos := _find_refreshed_exit_portal_pos(state_after, old_exit_pos)
	if not _is_inside_board(new_exit_pos, state_after.board_size):
		new_exit_pos = old_exit_pos

	_set_exit_portal_at(state_after, new_exit_pos)
	state_after.exit_portal_tile = new_exit_pos
	result.exit_refresh_records.append({
		"from": old_exit_pos,
		"to": new_exit_pos,
	})


func _resolve_queued_portals(state_after: GameState, result: TurnResult) -> void:
	var used_pair_ids: Array[int] = []

	for unit in state_after.units:
		unit.teleported_this_turn = false
		if not unit.alive or unit.won:
			continue
		if not unit.has_queued_teleport:
			continue

		var source_pos := unit.pos
		var target_pos := unit.queued_teleport_to
		var tile := state_after.get_tile_at(source_pos)
		if tile == null or tile.tile_type != TileType.PORTAL:
			unit.has_queued_teleport = false
			continue

		var pair := state_after.get_portal_pair_by_id(tile.portal_pair_id)
		if pair == null:
			unit.has_queued_teleport = false
			continue

		unit.prev_pos = source_pos
		unit.pos = target_pos
		unit.has_queued_teleport = false
		unit.queued_teleport_to = Vector2i.ZERO
		unit.teleported_this_turn = true

		if not result.teleported_unit_ids.has(unit.id):
			result.teleported_unit_ids.append(unit.id)
		result.teleport_records.append({
			"unit_id": unit.id,
			"pair_id": pair.id,
			"from": source_pos,
			"to": target_pos,
		})
		if not used_pair_ids.has(pair.id):
			used_pair_ids.append(pair.id)

	for pair_id in used_pair_ids:
		var used_pair := state_after.get_portal_pair_by_id(pair_id)
		if used_pair == null:
			continue
		used_pair.cooldown_turns = 3
		used_pair.refresh_overheat_state()
		if not result.overheated_portal_pair_ids.has(pair_id):
			result.overheated_portal_pair_ids.append(pair_id)

	for bag in state_after.bags:
		if not bag.has_queued_teleport:
			continue

		var source_pos := bag.pos
		var target_pos := bag.queued_teleport_to
		var tile := state_after.get_tile_at(source_pos)
		if tile == null or tile.tile_type != TileType.PORTAL:
			bag.has_queued_teleport = false
			bag.queued_teleport_to = Vector2i.ZERO
			continue

		var pair := state_after.get_portal_pair_by_id(tile.portal_pair_id)
		if pair == null:
			bag.has_queued_teleport = false
			bag.queued_teleport_to = Vector2i.ZERO
			continue

		bag.pos = target_pos
		bag.has_queued_teleport = false
		bag.queued_teleport_to = Vector2i.ZERO

		result.teleport_records.append({
			"bag_id": bag.id,
			"pair_id": pair.id,
			"from": source_pos,
			"to": target_pos,
			"coins": bag.coins,
		})
		if not used_pair_ids.has(pair.id):
			used_pair_ids.append(pair.id)

	for pair_id in used_pair_ids:
		var used_pair_after_bags := state_after.get_portal_pair_by_id(pair_id)
		if used_pair_after_bags == null:
			continue
		used_pair_after_bags.cooldown_turns = 3
		used_pair_after_bags.refresh_overheat_state()
		if not result.overheated_portal_pair_ids.has(pair_id):
			result.overheated_portal_pair_ids.append(pair_id)


func _resolve_pick_phase(state_after: GameState, intent_by_actor_id: Dictionary, result: TurnResult) -> void:
	for unit in state_after.units:
		if not unit.alive or unit.won:
			continue
		if unit.teleported_this_turn:
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
		if unit.teleported_this_turn:
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
		result.knocked_back_records.append({
			"unit_id": survivor.id,
			"from": survivor.pos,
			"to": survivor.prev_pos,
		})
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


func _resolve_portal_reservations(state_after: GameState, result: TurnResult) -> void:
	for unit in state_after.units:
		if not unit.alive or unit.won:
			continue
		if unit.queued_exit:
			continue

		var tile := state_after.get_tile_at(unit.pos)
		if tile == null or tile.tile_type != TileType.PORTAL:
			continue

		var pair := state_after.get_portal_pair_by_id(tile.portal_pair_id)
		if pair == null or pair.is_overheated:
			continue

		var target := pair.entry_b if pair.entry_a == unit.pos else pair.entry_a
		unit.has_queued_teleport = true
		unit.queued_teleport_to = target

		if not unit.discovered_portal_ids.has(pair.id):
			unit.discovered_portal_ids.append(pair.id)
		if not pair.discovered_by_player_ids.has(unit.id):
			pair.discovered_by_player_ids.append(unit.id)

		if not result.portal_ready_unit_ids.has(unit.id):
			result.portal_ready_unit_ids.append(unit.id)
		result.portal_ready_records.append({
			"unit_id": unit.id,
			"pair_id": pair.id,
			"from": unit.pos,
			"to": target,
		})

	for bag in state_after.bags:
		var tile := state_after.get_tile_at(bag.pos)
		if tile == null or tile.tile_type != TileType.PORTAL:
			continue

		var pair := state_after.get_portal_pair_by_id(tile.portal_pair_id)
		if pair == null or pair.is_overheated:
			continue

		var target := pair.entry_b if pair.entry_a == bag.pos else pair.entry_a
		bag.has_queued_teleport = true
		bag.queued_teleport_to = target

		result.portal_ready_records.append({
			"bag_id": bag.id,
			"pair_id": pair.id,
			"from": bag.pos,
			"to": target,
			"coins": bag.coins,
		})


func _resolve_exit_reservations(state_after: GameState, result: TurnResult) -> void:
	for unit in state_after.units:
		if not unit.alive or unit.won:
			continue
		if unit.has_queued_teleport:
			continue

		var tile := state_after.get_tile_at(unit.pos)
		if tile == null or tile.tile_type != TileType.EXIT_PORTAL:
			continue

		unit.queued_exit = true
		if not result.exit_ready_unit_ids.has(unit.id):
			result.exit_ready_unit_ids.append(unit.id)
		result.exit_ready_records.append({
			"unit_id": unit.id,
			"from": unit.pos,
		})

	for bag in state_after.bags:
		var tile := state_after.get_tile_at(bag.pos)
		if tile == null or tile.tile_type != TileType.EXIT_PORTAL:
			continue

		bag.queued_exit = true
		result.exit_ready_records.append({
			"bag_id": bag.id,
			"from": bag.pos,
			"coins": bag.coins,
		})


func _resolve_death_drop_phase(state_after: GameState, result: TurnResult) -> void:
	for unit_id in result.dead_unit_ids:
		var unit := state_after.get_unit_by_id(unit_id)
		if unit == null:
			continue
		if unit.coins <= 0:
			continue

		var bag := BagState.new()
		bag.id = _get_next_bag_id(state_after)
		bag.pos = unit.pos
		bag.coins = unit.coins
		state_after.bags.append(bag)

		result.dropped_bag_ids.append(bag.id)
		result.dropped_bag_records.append({
			"unit_id": unit.id,
			"bag_id": bag.id,
			"coins": bag.coins,
			"pos": bag.pos,
		})

		unit.coins = 0


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


func _pick_exit_coin_collector(units_at_pos: Array) -> UnitState:
	var collector: UnitState = units_at_pos[0]
	for index in range(1, units_at_pos.size()):
		var challenger: UnitState = units_at_pos[index]
		if challenger.id < collector.id:
			collector = challenger
	return collector


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


func _find_current_exit_portal_pos(state_after: GameState) -> Vector2i:
	for tile in state_after.tiles:
		if tile.tile_type == TileType.EXIT_PORTAL:
			return tile.pos
	return Vector2i(-1, -1)


func _clear_exit_portal_at(state_after: GameState, pos: Vector2i) -> void:
	var tile := state_after.get_tile_at(pos)
	if tile == null:
		return
	if tile.tile_type != TileType.EXIT_PORTAL:
		return

	tile.tile_type = TileType.NORMAL
	tile.portal_pair_id = -1
	tile.portal_color_id = -1


func _set_exit_portal_at(state_after: GameState, pos: Vector2i) -> void:
	var tile := state_after.get_tile_at(pos)
	if tile == null:
		tile = TileState.new()
		tile.pos = pos
		state_after.tiles.append(tile)

	tile.tile_type = TileType.EXIT_PORTAL
	tile.portal_pair_id = -1
	tile.portal_color_id = -1


func _find_refreshed_exit_portal_pos(state_after: GameState, old_exit_pos: Vector2i) -> Vector2i:
	for y in range(state_after.board_size.y):
		for x in range(state_after.board_size.x):
			var candidate := Vector2i(x, y)
			if candidate == old_exit_pos:
				continue
			if _is_valid_exit_refresh_pos(state_after, candidate):
				return candidate
	return Vector2i(-1, -1)


func _is_valid_exit_refresh_pos(state_after: GameState, pos: Vector2i) -> bool:
	if not _is_inside_board(pos, state_after.board_size):
		return false

	for unit in state_after.units:
		if not unit.alive or unit.won:
			continue
		if unit.pos == pos:
			return false

	var tile := state_after.get_tile_at(pos)
	if tile == null:
		return true

	if tile.has_storm:
		return false

	return tile.tile_type == TileType.NORMAL

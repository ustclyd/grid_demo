class_name MapTurnRules
extends RefCounted


func apply_turn_start(result: TurnResult) -> void:
	var state := result.state_after
	_tick_portal_cooldowns(state)
	_resolve_queued_exits(state, result)
	_refresh_exit_portal_if_used(state, result)
	_resolve_queued_portals(state, result)


func apply_turn_end(result: TurnResult) -> void:
	var state := result.state_after
	_resolve_exit_reservations(state, result)
	_resolve_portal_reservations(state, result)


func _tick_portal_cooldowns(state_after: GameState) -> void:
	for pair in state_after.map_state.portal_pairs:
		pair.tick_cooldown()


func _resolve_queued_exits(state_after: GameState, result: TurnResult) -> void:
	var queued_units_by_pos := {}
	for unit in state_after.units:
		if not unit.alive or unit.won:
			continue
		if not unit.queued_exit:
			continue

		var unit_key := unit.pos
		if not queued_units_by_pos.has(unit_key):
			queued_units_by_pos[unit_key] = []
		queued_units_by_pos[unit_key].append(unit)

	var queued_bags_by_pos := {}
	for bag in state_after.bags:
		if not bag.queued_exit:
			continue

		var bag_key := bag.pos
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

		for bag_value in bags_at_pos:
			var bag: BagState = bag_value
			bag.queued_exit = false
			if collector != null:
				collector.coins += bag.coins
			result.exit_records.append({
				"bag_id": bag.id,
				"from": bag.pos,
				"coins": bag.coins,
			})
			bags_to_remove.append(bag)

		for unit_value in units_at_pos:
			var unit: UnitState = unit_value
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

	var bounds := Rect2i(Vector2i.ZERO, state_after.board_size)
	var old_exit_pos := state_after.map_state.exit_portal_tile
	if not bounds.has_point(old_exit_pos):
		old_exit_pos = _find_current_exit_portal_pos(state_after)

	if not bounds.has_point(old_exit_pos):
		return

	_clear_exit_portal_at(state_after, old_exit_pos)

	var new_exit_pos := _find_refreshed_exit_portal_pos(state_after, old_exit_pos)
	if not bounds.has_point(new_exit_pos):
		new_exit_pos = old_exit_pos

	_set_exit_portal_at(state_after, new_exit_pos)
	state_after.map_state.exit_portal_tile = new_exit_pos
	result.exit_refresh_records.append({
		"from": old_exit_pos,
		"to": new_exit_pos,
	})


func _resolve_queued_portals(state_after: GameState, result: TurnResult) -> void:
	var used_pair_ids: Array[int] = []

	for unit in state_after.units:
		if not unit.alive or unit.won:
			continue
		if not unit.has_queued_teleport:
			continue

		var source_pos := unit.pos
		var target_pos := unit.queued_teleport_to
		var tile := state_after.map_state.get_tile_at(source_pos)
		if tile == null or tile.tile_type != TileType.PORTAL:
			unit.has_queued_teleport = false
			continue

		var pair := state_after.map_state.get_portal_pair_by_id(tile.portal_pair_id)
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
		var used_pair := state_after.map_state.get_portal_pair_by_id(pair_id)
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
		var tile := state_after.map_state.get_tile_at(source_pos)
		if tile == null or tile.tile_type != TileType.PORTAL:
			bag.has_queued_teleport = false
			bag.queued_teleport_to = Vector2i.ZERO
			continue

		var pair := state_after.map_state.get_portal_pair_by_id(tile.portal_pair_id)
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
		var used_pair_after_bags := state_after.map_state.get_portal_pair_by_id(pair_id)
		if used_pair_after_bags == null:
			continue
		used_pair_after_bags.cooldown_turns = 3
		used_pair_after_bags.refresh_overheat_state()
		if not result.overheated_portal_pair_ids.has(pair_id):
			result.overheated_portal_pair_ids.append(pair_id)


func _resolve_exit_reservations(state_after: GameState, result: TurnResult) -> void:
	for unit in state_after.units:
		if not unit.alive or unit.won:
			continue
		if unit.has_queued_teleport:
			continue

		var tile := state_after.map_state.get_tile_at(unit.pos)
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
		var tile := state_after.map_state.get_tile_at(bag.pos)
		if tile == null or tile.tile_type != TileType.EXIT_PORTAL:
			continue

		bag.queued_exit = true
		result.exit_ready_records.append({
			"bag_id": bag.id,
			"from": bag.pos,
			"coins": bag.coins,
		})


func _resolve_portal_reservations(state_after: GameState, result: TurnResult) -> void:
	for unit in state_after.units:
		if not unit.alive or unit.won:
			continue
		if unit.queued_exit:
			continue

		var tile := state_after.map_state.get_tile_at(unit.pos)
		if tile == null or tile.tile_type != TileType.PORTAL:
			continue

		var pair := state_after.map_state.get_portal_pair_by_id(tile.portal_pair_id)
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
		var tile := state_after.map_state.get_tile_at(bag.pos)
		if tile == null or tile.tile_type != TileType.PORTAL:
			continue

		var pair := state_after.map_state.get_portal_pair_by_id(tile.portal_pair_id)
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


func _pick_exit_coin_collector(units_at_pos: Array) -> UnitState:
	var collector: UnitState = units_at_pos[0]
	for index in range(1, units_at_pos.size()):
		var challenger: UnitState = units_at_pos[index]
		if challenger.id < collector.id:
			collector = challenger
	return collector


func _find_current_exit_portal_pos(state_after: GameState) -> Vector2i:
	for tile in state_after.map_state.tiles:
		if tile.tile_type == TileType.EXIT_PORTAL:
			return tile.pos
	return Vector2i(-1, -1)


func _clear_exit_portal_at(state_after: GameState, pos: Vector2i) -> void:
	var tile := state_after.map_state.get_tile_at(pos)
	if tile == null:
		return
	if tile.tile_type != TileType.EXIT_PORTAL:
		return

	tile.tile_type = TileType.NORMAL
	tile.portal_pair_id = -1
	tile.portal_color_id = -1


func _set_exit_portal_at(state_after: GameState, pos: Vector2i) -> void:
	var tile := state_after.map_state.get_tile_at(pos)
	if tile == null:
		tile = TileState.new()
		tile.pos = pos
		state_after.map_state.tiles.append(tile)

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
	for unit in state_after.units:
		if not unit.alive or unit.won:
			continue
		if unit.pos == pos:
			return false

	var tile := state_after.map_state.get_tile_at(pos)
	if tile == null:
		return true

	if tile.has_storm:
		return false

	return tile.tile_type == TileType.NORMAL

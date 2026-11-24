extends SceneTree


func _init() -> void:
	var failures: Array[String] = []

	if not _test_portal_bag_flow():
		failures.append("PortalBag")
	if not _test_exit_bag_flow():
		failures.append("ExitBag")
	if not _test_exit_unit_bag_flow():
		failures.append("ExitUnitBag")
	if not _test_map_rules_are_optional():
		failures.append("MapRulesOptional")

	if failures.is_empty():
		print("portal_bag_smoke: PASS")
		quit(0)
		return

	push_error("portal_bag_smoke: FAIL -> %s" % ", ".join(failures))
	quit(1)


func _test_portal_bag_flow() -> bool:
	var resolver := TurnResolver.new(MapTurnRules.new())
	var state := _create_base_state()
	_add_portal_pair(state, 1, Vector2i(1, 6), Vector2i(5, 2), 0)
	_add_unit(state, 1, Vector2i(0, 6), 5, 5)

	var throw_intent := _make_throw_intent(1, Vector2i(1, 6), 2)
	var turn_one := resolver.resolve_turn(state, [throw_intent])
	var queued_bag := _get_single_bag(turn_one.state_after)
	if queued_bag == null:
		push_error("PortalBag: turn1 no bag created")
		return false
	if queued_bag.pos != Vector2i(1, 6):
		push_error("PortalBag: turn1 bag not on portal entry")
		return false
	if not queued_bag.has_queued_teleport or queued_bag.queued_teleport_to != Vector2i(5, 2):
		push_error("PortalBag: turn1 bag did not queue teleport")
		return false

	var turn_two := resolver.resolve_turn(turn_one.state_after, [_make_stay_intent(1, turn_one.state_after.get_unit_by_id(1).pos)])
	var teleported_bag := _get_single_bag(turn_two.state_after)
	if teleported_bag == null:
		push_error("PortalBag: turn2 bag missing after teleport")
		return false
	if teleported_bag.pos != Vector2i(5, 2):
		push_error("PortalBag: turn2 bag did not teleport to exit")
		return false
	var pair := turn_two.state_after.map_state.get_portal_pair_by_id(1)
	if pair == null or pair.cooldown_turns != 3 or not pair.is_overheated:
		push_error("PortalBag: portal did not overheat after bag teleport")
		return false
	return true


func _test_exit_bag_flow() -> bool:
	var resolver := TurnResolver.new(MapTurnRules.new())
	var state := _create_base_state()
	_add_exit_portal(state, Vector2i(1, 6))
	_add_unit(state, 1, Vector2i(0, 6), 5, 5)

	var throw_intent := _make_throw_intent(1, Vector2i(1, 6), 2)
	var turn_one := resolver.resolve_turn(state, [throw_intent])
	var queued_bag := _get_single_bag(turn_one.state_after)
	if queued_bag == null or not queued_bag.queued_exit:
		push_error("ExitBag: turn1 bag did not queue exit")
		return false

	var turn_two := resolver.resolve_turn(turn_one.state_after, [_make_stay_intent(1, turn_one.state_after.get_unit_by_id(1).pos)])
	if turn_two.state_after.bags.size() != 0:
		push_error("ExitBag: bag did not leave through exit portal")
		return false
	if turn_two.state_after.map_state.exit_portal_tile == Vector2i(1, 6):
		push_error("ExitBag: exit portal did not refresh")
		return false
	if turn_two.exit_records.size() == 0:
		push_error("ExitBag: no exit record produced")
		return false
	return true


func _test_exit_unit_bag_flow() -> bool:
	var resolver := TurnResolver.new(MapTurnRules.new())
	var state := _create_base_state()
	_add_exit_portal(state, Vector2i(1, 6))
	_add_unit(state, 1, Vector2i(0, 6), 5, 5)
	_add_unit(state, 2, Vector2i(1, 6), 0, 0)

	var throw_intent := _make_throw_intent(1, Vector2i(1, 6), 2)
	var turn_one := resolver.resolve_turn(state, [throw_intent, _make_stay_intent(2, Vector2i(1, 6))])
	var enemy_after_turn_one := turn_one.state_after.get_unit_by_id(2)
	var queued_bag := _get_single_bag(turn_one.state_after)
	if enemy_after_turn_one == null or not enemy_after_turn_one.queued_exit:
		push_error("ExitUnitBag: unit did not queue exit on turn1")
		return false
	if queued_bag == null or not queued_bag.queued_exit:
		push_error("ExitUnitBag: bag did not queue exit on turn1")
		return false

	var turn_two := resolver.resolve_turn(turn_one.state_after, [
		_make_stay_intent(1, turn_one.state_after.get_unit_by_id(1).pos),
		_make_stay_intent(2, enemy_after_turn_one.pos),
	])
	var exited_enemy := turn_two.state_after.get_unit_by_id(2)
	if exited_enemy == null or not exited_enemy.won or exited_enemy.alive:
		push_error("ExitUnitBag: unit did not exit successfully")
		return false
	if exited_enemy.coins != 2:
		push_error("ExitUnitBag: bag coins were not settled to exiting unit")
		return false
	if turn_two.state_after.bags.size() != 0:
		push_error("ExitUnitBag: bag still exists after joint exit")
		return false
	return true


func _test_map_rules_are_optional() -> bool:
	var resolver := TurnResolver.new()
	var state := _create_base_state()
	var portal_pos := Vector2i(1, 6)
	var exit_pos := Vector2i(2, 6)
	_add_portal_pair(state, 1, portal_pos, Vector2i(5, 2), 0)
	_add_exit_portal(state, exit_pos)
	_add_unit(state, 1, Vector2i(0, 6), 0, 0)
	state.get_unit_by_id(1).teleported_this_turn = true

	for target in [portal_pos, exit_pos]:
		var intent := ActionIntent.new()
		intent.actor_id = 1
		intent.type = ActionType.MOVE
		intent.target_pos = target
		var turn := resolver.resolve_turn(state, [intent])
		var player := turn.state_after.get_unit_by_id(1)
		if player.pos != target or not player.alive:
			push_error("MapRulesOptional: ordinary movement across map tiles failed")
			return false
		if player.has_queued_teleport or player.queued_exit:
			push_error("MapRulesOptional: movement triggered a disabled map rule")
			return false
		state = turn.state_after

	if state.map_state.get_tile_at(exit_pos).tile_type != TileType.EXIT_PORTAL:
		push_error("MapRulesOptional: disabled map rules lost their tile data")
		return false
	return true


func _create_base_state() -> GameState:
	var state := GameState.new()
	state.board_size = Vector2i(7, 7)
	return state


func _add_unit(state: GameState, unit_id: int, pos: Vector2i, coins: int, entry_coins: int) -> void:
	var unit := UnitState.new()
	unit.id = unit_id
	unit.pos = pos
	unit.prev_pos = pos
	unit.coins = coins
	unit.entry_coins = entry_coins
	unit.alive = true
	state.units.append(unit)


func _add_portal_pair(state: GameState, pair_id: int, entry_a: Vector2i, entry_b: Vector2i, color_id: int) -> void:
	var pair := PortalPairState.new()
	pair.id = pair_id
	pair.entry_a = entry_a
	pair.entry_b = entry_b
	pair.color_id = color_id
	pair.refresh_overheat_state()
	state.map_state.portal_pairs.append(pair)

	var tile_a := TileState.new()
	tile_a.pos = entry_a
	tile_a.tile_type = TileType.PORTAL
	tile_a.portal_pair_id = pair_id
	tile_a.portal_color_id = color_id
	state.map_state.tiles.append(tile_a)

	var tile_b := TileState.new()
	tile_b.pos = entry_b
	tile_b.tile_type = TileType.PORTAL
	tile_b.portal_pair_id = pair_id
	tile_b.portal_color_id = color_id
	state.map_state.tiles.append(tile_b)


func _add_exit_portal(state: GameState, pos: Vector2i) -> void:
	var tile := TileState.new()
	tile.pos = pos
	tile.tile_type = TileType.EXIT_PORTAL
	state.map_state.tiles.append(tile)
	state.map_state.exit_portal_tile = pos


func _make_throw_intent(actor_id: int, target: Vector2i, throw_amount: int) -> ActionIntent:
	var intent := ActionIntent.new()
	intent.actor_id = actor_id
	intent.type = ActionType.THROW
	intent.target_pos = target
	intent.throw_amount = throw_amount
	return intent


func _make_stay_intent(actor_id: int, pos: Vector2i) -> ActionIntent:
	var intent := ActionIntent.new()
	intent.actor_id = actor_id
	intent.type = ActionType.STAY
	intent.target_pos = pos
	return intent


func _get_single_bag(state: GameState) -> BagState:
	if state.bags.is_empty():
		return null
	return state.bags[0]

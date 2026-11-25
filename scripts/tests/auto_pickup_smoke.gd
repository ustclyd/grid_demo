
extends SceneTree


func _init() -> void:
	var cases := {
		"moving and waiting collect every bag for any unit": _test_moving_and_waiting_collect_all,
		"first conflict uses pre-pickup coins and winner takes the drop": _test_first_conflict_before_pickup,
		"knocked-back mover collects neither origin nor target": _test_knocked_back_mover,
		"pushed stayer collects neither impact nor landing": _test_pushed_stayer,
		"stunned unit collects only after the recovery turn": _test_stun_recovery,
		"thrower leaves its own bag and a stayer can take the thrown coins": _test_throw_and_fresh_bag,
		"second conflict finishes before the survivor takes the loot": _test_second_conflict_before_pickup,
		"implicit wait and a rejected move can collect": _test_wait_fallbacks,
	}
	var failures := 0
	for label in cases:
		var test_case: Callable = cases[label]
		if not test_case.call():
			push_error("auto_pickup_smoke: %s" % label)
			failures += 1
	if failures == 0:
		print("auto_pickup_smoke: PASS (%d cases)" % cases.size())
		quit(0)
	else:
		print("auto_pickup_smoke: FAIL (%d of %d cases)" % [failures, cases.size()])
		quit(1)


func _test_moving_and_waiting_collect_all() -> bool:
	var stay_cell := Vector2i(1, 1)
	var move_cell := Vector2i(4, 3)
	var state := _board(
		[_unit(1, stay_cell, 2), _unit(7, Vector2i(4, 4), 3)],
		[_bag(1, stay_cell, 2), _bag(2, stay_cell, 4), _bag(3, move_cell, 5), _bag(4, Vector2i.ZERO, 1)],
	)
	var turn := TurnResolver.new().resolve_turn(state, [
		_action(1, ActionType.STAY), _action(7, ActionType.MOVE, move_cell),
	])
	return (
		turn.state_after.get_unit_by_id(1).coins == 8 and turn.state_after.get_unit_by_id(7).coins == 8
		and _picked_ids(turn, 1) == [1, 2] and _picked_ids(turn, 7) == [3]
		and turn.state_after.bags.size() == 1 and turn.state_after.bags[0].id == 4
		and state.bags.size() == 4 and state.get_unit_by_id(1).coins == 2
		and state.get_unit_by_id(7).pos == Vector2i(4, 4)
	)


func _test_first_conflict_before_pickup() -> bool:
	var target := Vector2i(2, 2)
	var state := _board(
		[_unit(1, Vector2i(1, 2), 1), _unit(2, Vector2i(3, 2), 3)],
		[_bag(1, target, 5)],
	)
	var turn := TurnResolver.new().resolve_turn(state, [
		_action(1, ActionType.MOVE, target), _action(2, ActionType.MOVE, target),
	])
	var winner := turn.state_after.get_unit_by_id(1)
	return (
		turn.conflict1_defeated_unit_ids == [2] and winner.alive and winner.coins == 9
		and _picked_ids(turn, 1) == [1, 2] and _picked_ids(turn, 2).is_empty()
		and turn.dropped_bag_records.size() == 1 and turn.state_after.bags.is_empty()
	)


func _test_knocked_back_mover() -> bool:
	var origin := Vector2i(1, 2)
	var target := Vector2i(2, 2)
	var state := _board(
		[_unit(2, origin, 3), _unit(3, Vector2i(2, 1), 5)],
		[_bag(1, origin, 2), _bag(2, target, 4)],
	)
	var turn := TurnResolver.new().resolve_turn(state, [
		_action(2, ActionType.MOVE, target), _action(3, ActionType.THROW, target, 2),
	])
	var mover := turn.state_after.get_unit_by_id(2)
	return (
		turn.knocked_back_unit_ids == [2] and mover.pos == origin and mover.stun_turns == 1
		and mover.coins == 3 and turn.picked_bag_records.is_empty()
		and turn.state_after.bags.size() == 3
	)


func _test_pushed_stayer() -> bool:
	var impact := Vector2i(1, 2)
	var landing := Vector2i(2, 2)
	var state := _board(
		[_unit(1, Vector2i(0, 2), 5), _unit(2, impact, 1)],
		[_bag(1, impact, 3), _bag(2, landing, 5)],
	)
	var turn := TurnResolver.new().resolve_turn(state, [
		_action(1, ActionType.THROW, impact, 2), _action(2, ActionType.STAY),
	])
	var guard := turn.state_after.get_unit_by_id(2)
	return (
		guard.pos == landing and guard.coins == 1 and guard.stun_turns == 1
		and turn.picked_bag_records.is_empty() and turn.state_after.bags.size() == 3
	)


func _test_stun_recovery() -> bool:
	var origin := Vector2i(2, 2)
	var state := _board([_unit(2, origin, 1)], [_bag(1, origin, 4)])
	state.get_unit_by_id(2).stun_turns = 1
	var resolver := TurnResolver.new()
	var first := resolver.resolve_turn(state, [_action(2, ActionType.STAY)])
	var recovering := first.state_after.get_unit_by_id(2)
	if recovering.stun_turns != 0 or recovering.coins != 1 or not first.picked_bag_records.is_empty():
		return false
	if first.state_after.get_bag_by_id(1) == null:
		return false
	var second := resolver.resolve_turn(first.state_after, [_action(2, ActionType.STAY)])
	return _picked_ids(second, 2) == [1] and second.state_after.get_unit_by_id(2).coins == 5


func _test_throw_and_fresh_bag() -> bool:
	var source := Vector2i(5, 2)
	var edge := Vector2i(6, 2)
	var state := _board([_unit(1, source, 5), _unit(2, edge, 1)], [_bag(1, source, 4)])
	var turn := TurnResolver.new().resolve_turn(state, [
		_action(1, ActionType.THROW, edge, 2), _action(2, ActionType.STAY),
	])
	var guard := turn.state_after.get_unit_by_id(2)
	return (
		turn.state_after.get_unit_by_id(1).coins == 3 and _picked_ids(turn, 1).is_empty()
		and guard.pos == edge and guard.coins == 3 and guard.stun_turns == 1
		and _picked_ids(turn, 2) == [2]
		and turn.state_after.bags.size() == 1 and turn.state_after.bags[0].id == 1
	)


func _test_second_conflict_before_pickup() -> bool:
	var impact := Vector2i(1, 2)
	var landing := Vector2i(2, 2)
	var state := _board(
		[_unit(1, Vector2i(0, 2), 5), _unit(2, impact, 4), _unit(3, landing, 1)],
		[_bag(1, landing, 5)],
	)
	var turn := TurnResolver.new().resolve_turn(state, [
		_action(1, ActionType.THROW, impact, 2), _action(2, ActionType.STAY), _action(3, ActionType.STAY),
	])
	var winner := turn.state_after.get_unit_by_id(3)
	return (
		turn.conflict2_defeated_unit_ids == [2] and winner.alive and winner.coins == 10
		and _picked_ids(turn, 2).is_empty() and _picked_ids(turn, 3) == [1, 3]
		and turn.state_after.bags.size() == 1 and turn.state_after.bags[0].pos == impact
	)


func _test_wait_fallbacks() -> bool:
	var origin := Vector2i.ZERO
	var state := _board([_unit(1, origin, 1), _unit(2, Vector2i(3, 3), 2)], [
		_bag(1, origin, 3), _bag(2, Vector2i(3, 3), 4),
	])
	var turn := TurnResolver.new().resolve_turn(state, [_action(1, ActionType.MOVE, Vector2i(-1, 0))])
	return (
		turn.moved_unit_ids.is_empty() and _picked_ids(turn, 1) == [1] and _picked_ids(turn, 2) == [2]
		and turn.state_after.get_unit_by_id(1).coins == 4 and turn.state_after.get_unit_by_id(2).coins == 6
	)


func _board(units: Array[UnitState], bags: Array[BagState]) -> GameState:
	var state := GameState.new()
	state.units.assign(units)
	state.bags.assign(bags)
	return state


func _unit(id: int, pos: Vector2i, coins: int) -> UnitState:
	var unit := UnitState.new()
	unit.id = id
	unit.pos = pos
	unit.coins = coins
	unit.entry_coins = coins
	return unit


func _bag(id: int, pos: Vector2i, coins: int) -> BagState:
	var bag := BagState.new()
	bag.id = id
	bag.pos = pos
	bag.coins = coins
	return bag


func _action(id: int, type: String, target := Vector2i.ZERO, amount := 0) -> ActionIntent:
	var intent := ActionIntent.new()
	intent.actor_id = id
	intent.type = type
	intent.target_pos = target
	intent.throw_amount = amount
	return intent


func _picked_ids(result: TurnResult, unit_id: int) -> Array[int]:
	var ids: Array[int] = []
	for record in result.picked_bag_records:
		if record["unit_id"] == unit_id:
			ids.append(record["bag_id"])
	return ids

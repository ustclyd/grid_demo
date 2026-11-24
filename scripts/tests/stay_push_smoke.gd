
extends SceneTree


func _init() -> void:
	var cases := {
		"push after conflict one, with bag left at impact": _test_push_after_conflict_one,
		"two-cell diagonal throw pushes one cell": _test_diagonal_push,
		"board edge keeps the stayer in place": _test_board_edge,
		"legacy landing for actions other than active stay": _test_only_active_stay_pushes,
		"two throws from the same direction push once": _test_same_direction,
		"mixed directions cancel even with a late matching throw": _test_mixed_directions,
		"occupied landing triggers conflict two and a drop": _test_occupied_landing,
		"simultaneous hits use the same board in either order": _test_simultaneous_hits,
		"simultaneous landings on one tile are resolved together": _test_shared_landing,
	}
	var failures := 0
	for label in cases:
		var test_case: Callable = cases[label]
		if not test_case.call():
			push_error("stay_push_smoke: %s" % label)
			failures += 1

	if failures == 0:
		print("stay_push_smoke: PASS (%d cases)" % cases.size())
		quit(0)
	else:
		print("stay_push_smoke: FAIL (%d of %d cases)" % [failures, cases.size()])
		quit(1)


func _test_push_after_conflict_one() -> bool:
	var impact := Vector2i(1, 2)
	var landing := Vector2i(2, 2)
	var state := _board([_unit(1, Vector2i(0, 2), 5), _unit(2, impact, 3), _unit(3, Vector2i(1, 3), 1)])
	var result := TurnResolver.new().resolve_turn(state, [
		_action(1, ActionType.THROW, impact, 2),
		_action(2, ActionType.STAY),
		_action(3, ActionType.MOVE, impact),
	])
	var final_guard := result.state_after.get_unit_by_id(2)
	var throw_record := result.thrown_bag_records[0] if result.thrown_bag_records.size() == 1 else {}
	var thrown_bag := result.state_after.get_bag_by_id(throw_record.get("bag_id", -1))
	return (
		result.conflict1_defeated_unit_ids == [3]
		and _has_knockback(result, 2, impact, landing)
		and final_guard.alive and final_guard.pos == landing and final_guard.forced_stay_turns == 1
		and thrown_bag != null and thrown_bag.pos == impact and thrown_bag.coins == 2
		and state.get_unit_by_id(2).pos == impact and state.bags.is_empty()
	)


func _test_diagonal_push() -> bool:
	var impact := Vector2i(2, 2)
	var landing := Vector2i(3, 3)
	var state := _board([_unit(1, Vector2i.ZERO, 5), _unit(2, impact, 1)])
	var result := TurnResolver.new().resolve_turn(state, [
		_action(1, ActionType.THROW, impact, 2),
		_action(2, ActionType.STAY),
	])
	return _has_knockback(result, 2, impact, landing) and result.state_after.get_unit_by_id(2).pos == landing


func _test_board_edge() -> bool:
	var impact := Vector2i(6, 2)
	var state := _board([_unit(1, Vector2i(5, 2), 5), _unit(2, impact, 1)])
	var result := TurnResolver.new().resolve_turn(state, [
		_action(1, ActionType.THROW, impact, 2),
		_action(2, ActionType.STAY),
	])
	var guard := result.state_after.get_unit_by_id(2)
	return (
		_has_knockback(result, 2, impact, impact)
		and guard.alive and guard.pos == impact and guard.forced_stay_turns == 1
		and result.state_after.bags.size() == 1 and result.state_after.bags[0].pos == impact
	)


func _test_only_active_stay_pushes() -> bool:
	var impact := Vector2i(2, 2)
	var origin := Vector2i(2, 3)
	var mover_board := _board([_unit(1, Vector2i(1, 2), 5), _unit(2, origin, 1)])
	var moved := TurnResolver.new().resolve_turn(mover_board, [
		_action(1, ActionType.THROW, impact, 2),
		_action(2, ActionType.MOVE, impact),
	])
	if not _has_knockback(moved, 2, impact, origin) or moved.state_after.get_unit_by_id(2).pos != origin:
		return false

	for action_type in [ActionType.STAY, ActionType.PICK, ActionType.THROW, ""]:
		var guard := _unit(2, impact, 5)
		var state := _board([_unit(1, Vector2i(1, 2), 5), guard])
		var intents: Array[ActionIntent] = [_action(1, ActionType.THROW, impact, 2)]
		match action_type:
			ActionType.STAY:
				guard.forced_stay_turns = 1
				intents.append(_action(2, ActionType.STAY))
			ActionType.PICK:
				var bag := BagState.new()
				bag.id = 10
				bag.pos = impact
				bag.coins = 1
				state.bags.append(bag)
				var pick := _action(2, ActionType.PICK)
				pick.target_bag_id = bag.id
				intents.append(pick)
			ActionType.THROW:
				intents.append(_action(2, ActionType.THROW, Vector2i(2, 1), 2))
		var result := TurnResolver.new().resolve_turn(state, intents)
		if not _has_knockback(result, 2, impact, impact) or result.state_after.get_unit_by_id(2).pos != impact:
			return false
		if action_type == ActionType.PICK and result.picked_bag_records.size() != 1:
			return false
		if action_type == ActionType.THROW and result.thrown_bag_records.size() != 2:
			return false
	return true


func _test_same_direction() -> bool:
	var impact := Vector2i(2, 2)
	var landing := Vector2i(3, 2)
	var state := _board([
		_unit(1, Vector2i(0, 2), 5), _unit(2, impact, 1), _unit(3, Vector2i(1, 2), 5),
	])
	var result := TurnResolver.new().resolve_turn(state, [
		_action(1, ActionType.THROW, impact, 2),
		_action(2, ActionType.STAY),
		_action(3, ActionType.THROW, impact, 2),
	])
	return (
		result.thrown_bag_records.size() == 2 and result.knocked_back_unit_ids == [2]
		and _has_knockback(result, 2, impact, landing) and result.state_after.get_unit_by_id(2).pos == landing
	)


func _test_mixed_directions() -> bool:
	var impact := Vector2i(2, 2)
	for second_thrower in [Vector2i(3, 2), Vector2i(2, 1)]:
		var state := _board([
			_unit(1, Vector2i(0, 2), 5), _unit(2, second_thrower, 5),
			_unit(3, Vector2i(1, 2), 5), _unit(4, impact, 1),
		])
		var result := TurnResolver.new().resolve_turn(state, [
			_action(1, ActionType.THROW, impact, 2),
			_action(2, ActionType.THROW, impact, 2),
			_action(3, ActionType.THROW, impact, 2),
			_action(4, ActionType.STAY),
		])
		var guard := result.state_after.get_unit_by_id(4)
		if result.thrown_bag_records.size() != 3 or result.knocked_back_unit_ids != [4]:
			return false
		if not _has_knockback(result, 4, impact, impact) or guard.pos != impact or guard.forced_stay_turns != 1:
			return false
	return true


func _test_occupied_landing() -> bool:
	var impact := Vector2i(1, 2)
	var landing := Vector2i(2, 2)
	var state := _board([_unit(1, Vector2i(0, 2), 5), _unit(2, impact, 1), _unit(3, landing, 5)])
	var result := TurnResolver.new().resolve_turn(state, [
		_action(1, ActionType.THROW, impact, 2),
		_action(2, ActionType.STAY),
		_action(3, ActionType.STAY),
	])
	return (
		result.conflict1_defeated_unit_ids.is_empty()
		and result.conflict2_defeated_unit_ids == [3]
		and _has_knockback(result, 2, impact, landing)
		and result.state_after.get_unit_by_id(2).pos == landing
		and result.dropped_bag_records.size() == 1
		and result.dropped_bag_records[0]["pos"] == landing
		and result.dropped_bag_records[0]["coins"] == 5
	)


func _test_simultaneous_hits() -> bool:
	var first := Vector2i(1, 2)
	var second := Vector2i(2, 2)
	var last := Vector2i(2, 3)
	var units: Array[UnitState] = [
		_unit(1, Vector2i(0, 2), 5), _unit(2, first, 1),
		_unit(3, Vector2i(2, 1), 5), _unit(4, second, 1),
	]
	var intents: Array[ActionIntent] = [
		_action(1, ActionType.THROW, first, 2), _action(2, ActionType.STAY),
		_action(3, ActionType.THROW, second, 2), _action(4, ActionType.STAY),
	]
	for order in range(2):
		var result := TurnResolver.new().resolve_turn(_board(units), intents)
		if result.knocked_back_unit_ids.size() != 2 or not result.conflict2_defeated_unit_ids.is_empty():
			return false
		if not _has_knockback(result, 2, first, second) or not _has_knockback(result, 4, second, last):
			return false
		if result.state_after.get_unit_by_id(2).pos != second or result.state_after.get_unit_by_id(4).pos != last:
			return false
		units.reverse()
		intents.reverse()
	return true


func _test_shared_landing() -> bool:
	var left := Vector2i(1, 2)
	var right := Vector2i(3, 2)
	var landing := Vector2i(2, 2)
	var state := _board([
		_unit(1, Vector2i(0, 2), 5), _unit(2, left, 1),
		_unit(3, Vector2i(4, 2), 5), _unit(4, right, 2),
	])
	var result := TurnResolver.new().resolve_turn(state, [
		_action(1, ActionType.THROW, left, 2), _action(2, ActionType.STAY),
		_action(3, ActionType.THROW, right, 2), _action(4, ActionType.STAY),
	])
	return (
		_has_knockback(result, 2, left, landing) and _has_knockback(result, 4, right, landing)
		and result.conflict2_survivor_unit_ids == [2] and result.conflict2_defeated_unit_ids == [4]
		and result.forced_stay_unit_ids == [2]
	)


func _board(units: Array[UnitState]) -> GameState:
	var state := GameState.new()
	state.units.assign(units)
	return state


func _unit(id: int, pos: Vector2i, coins: int) -> UnitState:
	var unit := UnitState.new()
	unit.id = id
	unit.pos = pos
	unit.coins = coins
	unit.entry_coins = coins
	return unit


func _action(id: int, type: String, target := Vector2i.ZERO, amount := 0) -> ActionIntent:
	var intent := ActionIntent.new()
	intent.actor_id = id
	intent.type = type
	intent.target_pos = target
	intent.throw_amount = amount
	return intent


func _has_knockback(result: TurnResult, id: int, from: Vector2i, to: Vector2i) -> bool:
	for record in result.knocked_back_records:
		if record["unit_id"] == id and record["from"] == from and record["to"] == to:
			return true
	return false

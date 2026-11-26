class_name TurnResolver
extends RefCounted

const CONFLICT1_ROLE_STAY_PRIORITY := "stay_priority"
const CONFLICT1_ROLE_STUNNED := "stunned"
const CONFLICT1_ROLE_NORMAL := "normal"


var _map_rules: MapTurnRules
var _push_active_stayers: bool


func _init(map_rules: MapTurnRules = null, push_active_stayers: bool = true) -> void:
	_map_rules = map_rules
	_push_active_stayers = push_active_stayers


func resolve_turn(state: GameState, intents: Array[ActionIntent]) -> TurnResult:
	var result := TurnResult.new()
	result.state_before = state
	result.intents = intents
	result.state_after = state.duplicate_state()
	result.state_after.turn_index += 1

	var intent_by_actor_id := _build_intent_lookup(intents)
	for unit in result.state_after.units:
		unit.teleported_this_turn = false
		if unit.stun_turns > 0:
			intent_by_actor_id.erase(unit.id)
	if _map_rules != null:
		_map_rules.apply_turn_start(result)

	_resolve_throw_phase(result.state_after, intent_by_actor_id, result)
	var conflict_groups := {}
	var pickup_cells_by_unit_id: Dictionary[int, Vector2i] = {}

	for unit in result.state_after.units:
		if not unit.alive or unit.won:
			continue

		var conflict1_role := CONFLICT1_ROLE_NORMAL
		if not unit.teleported_this_turn:
			unit.prev_pos = unit.pos
			var intent: ActionIntent = intent_by_actor_id.get(unit.id)
			if intent != null and intent.type == ActionType.MOVE:
				if can_step(result.state_after, unit, intent.target_pos):
					unit.pos = intent.target_pos
					result.moved_unit_ids.append(unit.id)
			conflict1_role = _get_conflict1_role(unit, intent)
			if unit.stun_turns == 0 and (
				intent == null or intent.type == ActionType.MOVE or intent.type == ActionType.STAY
			):
				pickup_cells_by_unit_id[unit.id] = unit.pos
		unit.set_meta("conflict1_role", conflict1_role)

		var pos_key := _pos_key(unit.pos)
		if not conflict_groups.has(pos_key):
			conflict_groups[pos_key] = []
		conflict_groups[pos_key].append(unit)

	_resolve_conflict_phase_one(conflict_groups, intent_by_actor_id, result)
	var conflict2_groups := _resolve_throw_knockback_phase(result.state_after, result, intent_by_actor_id)
	_resolve_conflict_phase_two(conflict2_groups, result)
	_resolve_death_drop_phase(result.state_after, result)
	_resolve_auto_pickups(result.state_after, pickup_cells_by_unit_id, result)
	_update_stun_after_turn(result.state_after, result)
	if _map_rules != null:
		_map_rules.apply_turn_end(result)

	if result.state_after.trail != null:
		var player_before := state.get_unit_by_id(PuzzleTrail.PLAYER_ID)
		var player_after := result.state_after.get_unit_by_id(PuzzleTrail.PLAYER_ID)
		if player_after.alive and player_after.pos != player_before.pos:
			result.state_after.trail.leave(player_before.pos)

	return result


func _build_intent_lookup(intents: Array[ActionIntent]) -> Dictionary:
	var lookup := {}
	for intent in intents:
		lookup[intent.actor_id] = intent
	return lookup


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
		if not _is_valid_throw_action(state_after, unit, intent):
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


func _resolve_throw_knockback_phase(
	state_after: GameState,
	result: TurnResult,
	intent_by_actor_id: Dictionary,
) -> Dictionary:
	var directions_by_target: Dictionary[Vector2i, Vector2i] = {}
	for throw_record in result.thrown_bag_records:
		var target: Vector2i = throw_record["to"]
		var delta: Vector2i = target - throw_record["from"]
		var direction := Vector2i(signi(delta.x), signi(delta.y))
		if directions_by_target.get(target, direction) != direction:
			directions_by_target[target] = Vector2i.ZERO
		else:
			directions_by_target[target] = direction

	# Read the same post-conflict board for every hit before moving any units.
	var destinations: Dictionary[int, Vector2i] = {}
	for target in directions_by_target:
		var survivor := _get_alive_unit_at_pos(state_after, target)
		if survivor == null:
			continue

		var destination := _get_knockback_destination(
			survivor, directions_by_target[target], state_after, intent_by_actor_id,
		)
		destinations[survivor.id] = destination
		result.knocked_back_unit_ids.append(survivor.id)
		result.knocked_back_records.append({
			"unit_id": survivor.id,
			"from": survivor.pos,
			"to": destination,
		})

	var occupants_by_destination := {}
	var affected_cells := {}
	for destination in destinations.values():
		affected_cells[destination] = true
	for unit in state_after.units:
		if not unit.alive or unit.won:
			continue
		unit.pos = destinations.get(unit.id, unit.pos)
		if not affected_cells.has(unit.pos):
			continue
		if not occupants_by_destination.has(unit.pos):
			occupants_by_destination[unit.pos] = []
		occupants_by_destination[unit.pos].append(unit)

	var conflict2_groups := {}
	for destination in affected_cells:
		var occupants: Array = occupants_by_destination[destination]
		if occupants.size() > 1:
			conflict2_groups[destination] = occupants

	return conflict2_groups


func _get_knockback_destination(
	unit: UnitState,
	direction: Vector2i,
	board: GameState,
	intent_by_actor_id: Dictionary,
) -> Vector2i:
	if unit.stun_turns > 0:
		return unit.pos
	var intent: ActionIntent = intent_by_actor_id.get(unit.id)
	if not _push_active_stayers or intent == null or intent.type != ActionType.STAY:
		return unit.prev_pos
	if _get_unit_conflict1_role(unit, intent_by_actor_id) != CONFLICT1_ROLE_STAY_PRIORITY:
		return unit.prev_pos

	var pushed_pos := unit.pos + direction
	return pushed_pos if can_step(board, unit, pushed_pos) else unit.pos


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


func _update_stun_after_turn(state_after: GameState, result: TurnResult) -> void:
	# Spend the current turn's stun only after both conflicts have resolved.
	for unit in state_after.units:
		if unit.stun_turns > 0:
			unit.stun_turns -= 1

	for unit_id in result.knocked_back_unit_ids:
		var unit := state_after.get_unit_by_id(unit_id)
		if unit == null or not unit.alive:
			continue
		unit.stun_turns = 1
		result.stun_next_turn_unit_ids.append(unit.id)


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


func _resolve_auto_pickups(
	state_after: GameState,
	pickup_cells_by_unit_id: Dictionary[int, Vector2i],
	result: TurnResult,
) -> void:
	if state_after.bags.is_empty() or pickup_cells_by_unit_id.is_empty():
		return

	var collectors_by_cell: Dictionary[Vector2i, UnitState] = {}
	for unit_id in pickup_cells_by_unit_id:
		var unit := state_after.get_unit_by_id(unit_id)
		if unit.alive and unit.pos == pickup_cells_by_unit_id[unit_id]:
			collectors_by_cell[unit.pos] = unit

	var remaining_bags: Array[BagState] = []
	for bag in state_after.bags:
		var collector: UnitState = collectors_by_cell.get(bag.pos)
		if collector == null:
			remaining_bags.append(bag)
			continue

		collector.coins += bag.coins
		result.picked_bag_records.append({
			"unit_id": collector.id,
			"bag_id": bag.id,
			"coins": bag.coins,
		})

	state_after.bags = remaining_bags


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
		if role == CONFLICT1_ROLE_STAY_PRIORITY:
			pure_stayers.append(unit)

	var candidates: Array = units_in_cell
	if pure_stayers.size() > 0:
		candidates = pure_stayers

	return _pick_standard_conflict_winner(candidates)


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
	if unit.stun_turns > 0:
		return CONFLICT1_ROLE_STUNNED
	if intent == null:
		return CONFLICT1_ROLE_STAY_PRIORITY

	match intent.type:
		ActionType.STAY:
			return CONFLICT1_ROLE_STAY_PRIORITY
		ActionType.MOVE:
			return CONFLICT1_ROLE_STAY_PRIORITY if unit.pos == unit.prev_pos else CONFLICT1_ROLE_NORMAL
		ActionType.THROW:
			return CONFLICT1_ROLE_NORMAL

	return CONFLICT1_ROLE_NORMAL


static func standard_throw_amount(coins: int) -> int:
	return floori(coins / 2.0) if coins > 1 else 0


static func is_valid_move_target(from_pos: Vector2i, to_pos: Vector2i, board_size: Vector2i) -> bool:
	if not _is_inside_board(to_pos, board_size):
		return false
	return to_pos != from_pos and maxi(absi(to_pos.x - from_pos.x), absi(to_pos.y - from_pos.y)) <= 1


static func can_step(board: GameState, unit: UnitState, target: Vector2i) -> bool:
	return (
		is_valid_move_target(unit.pos, target, board.board_size)
		and (board.trail == null or board.trail.allows_step(unit.pos, target, unit.id))
	)


static func can_aim_throw(board: GameState, unit: UnitState, target: Vector2i) -> bool:
	return (
		is_valid_throw_target(unit.pos, target, board.board_size)
		and (board.trail == null or board.trail.is_floor(target))
	)


func _is_valid_throw_action(board: GameState, unit: UnitState, intent: ActionIntent) -> bool:
	if intent.throw_amount <= 0:
		return false
	if unit.coins <= intent.throw_amount:
		return false
	return can_aim_throw(board, unit, intent.target_pos)


func _get_unit_conflict1_role(unit: UnitState, intent_by_actor_id: Dictionary) -> String:
	if unit.has_meta("conflict1_role"):
		return String(unit.get_meta("conflict1_role"))

	var intent: ActionIntent = intent_by_actor_id.get(unit.id)
	return _get_conflict1_role(unit, intent)


func _compare_unit_priority(a: UnitState, b: UnitState) -> int:
	var a_stunned := a.stun_turns > 0
	var b_stunned := b.stun_turns > 0
	if a_stunned != b_stunned:
		return 1 if a_stunned else -1

	if a.coins != b.coins:
		return -1 if a.coins < b.coins else 1

	if a.entry_coins != b.entry_coins:
		return -1 if a.entry_coins < b.entry_coins else 1

	if a.id != b.id:
		return -1 if a.id < b.id else 1

	return 0


func _pos_key(pos: Vector2i) -> String:
	return "%s,%s" % [pos.x, pos.y]


static func _is_inside_board(pos: Vector2i, board_size: Vector2i) -> bool:
	return (
		pos.x >= 0
		and pos.y >= 0
		and pos.x < board_size.x
		and pos.y < board_size.y
	)


static func is_valid_throw_target(from_pos: Vector2i, to_pos: Vector2i, board_size: Vector2i) -> bool:
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

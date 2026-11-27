extends RefCounted

const LOST := -1
const WON := -2

class Position:
	var session: PuzzleSession
	var successors := PackedInt32Array()
	var parents := PackedInt32Array()
	var depth: int
	var paths: int
	var can_win := false
	var winning_choices: int
	var forced_choice: int

	func _init(state: PuzzleSession, search_depth: int, path_count: int) -> void:
		session = state
		depth = search_depth
		paths = path_count


# For terrain-free levels whose enemy policies depend only on the current board.
# Terrain timers or turn-dependent policies would need additional state in the key.
static func inspect(
	level: PuzzleLevelData,
	shortest_only: bool = false,
	allow_throw: bool = true,
) -> Dictionary:
	if not level.trail_cells.is_empty():
		return {}
	var start := PuzzleSession.new()
	if not start.start_level(level):
		return {}

	var first := Position.new(start, 0, 1)
	var positions: Array[Position] = [first]
	var index_by_key := {_key(start.get_board_snapshot()): 0}
	var win_parents: Array[int] = []
	var shortest := 0
	var shortest_count := 0
	var cursor := 0
	while cursor < positions.size():
		var position := positions[cursor]
		var depth := position.depth + 1
		if shortest_only and shortest > 0 and depth > shortest:
			break
		for action in PuzzleActions.list_intents(position.session.get_board_snapshot(), PuzzleLevelData.PLAYER_ID):
			if not allow_throw and action.type == ActionType.THROW:
				continue
			var branch := position.session.fork()
			if not branch.submit_turn(action.type, action.target_pos):
				return {}

			match branch.get_phase():
				PuzzleSession.Phase.LOST:
					position.successors.append(LOST)
				PuzzleSession.Phase.WON:
					position.successors.append(WON)
					if not position.can_win:
						win_parents.append(cursor)
						position.can_win = true
					if shortest == 0:
						shortest = depth
					if depth == shortest:
						shortest_count += position.paths
				PuzzleSession.Phase.ACTIVE:
					var key := _key(branch.get_board_snapshot())
					if not index_by_key.has(key):
						index_by_key[key] = positions.size()
						positions.append(Position.new(branch, depth, 0))
					var successor: int = index_by_key[key]
					var target := positions[successor]
					if target.depth == depth:
						target.paths += position.paths
					position.successors.append(successor)
					target.parents.append(cursor)
		position.session = null
		cursor += 1

	if shortest_only:
		return {"shortest": shortest, "shortest_count": shortest_count}

	var direct_win_parents := win_parents.duplicate()
	cursor = 0
	while cursor < win_parents.size():
		for parent in positions[win_parents[cursor]].parents:
			if not positions[parent].can_win:
				positions[parent].can_win = true
				win_parents.append(parent)
		cursor += 1

	for position in positions:
		for successor in position.successors:
			if successor == WON or (successor >= 0 and positions[successor].can_win):
				position.winning_choices += 1
		# Ignore automatic turns or states with fewer than three legal choices.
		position.forced_choice = int(position.winning_choices == 1 and position.successors.size() >= 3)

	var opening_live_dead_ends := 0
	for successor in first.successors:
		if successor >= 0 and not positions[successor].can_win:
			opening_live_dead_ends += 1

	return {
		"shortest": shortest,
		"shortest_count": shortest_count,
		"total_active_states": positions.size(),
		"winnable_active_states": win_parents.size(),
		"opening_actions": first.successors.size(),
		"winnable_openings": first.winning_choices,
		"opening_live_dead_ends": opening_live_dead_ends,
		"minimum_forced_choices": _minimum_forced_choices(positions, direct_win_parents),
	}


static func _minimum_forced_choices(positions: Array[Position], win_parents: Array[int]) -> int:
	# Reverse search by the accumulated number of decisions with just one winning option.
	var layers: Array[Array] = [[], []]
	var distances := PackedInt32Array()
	distances.resize(positions.size())
	distances.fill(-1)
	for index in win_parents:
		var cost := positions[index].forced_choice
		distances[index] = cost
		layers[cost].append(index)

	var cost := 0
	while cost < layers.size():
		var cursor := 0
		while cursor < layers[cost].size():
			var index: int = layers[cost][cursor]
			cursor += 1
			if distances[index] != cost:
				continue
			if index == 0:
				return cost
			for parent in positions[index].parents:
				var next_cost := cost + positions[parent].forced_choice
				if distances[parent] >= 0 and distances[parent] <= next_cost:
					continue
				distances[parent] = next_cost
				if next_cost == layers.size():
					layers.append([])
				layers[next_cost].append(parent)
		cost += 1
	return -1


static func _key(board: GameState) -> String:
	var units := PackedStringArray()
	for unit in board.units:
		units.append("%s/%d/%d" % [unit.pos, unit.coins, unit.stun_turns] if unit.alive else "dead")
	# Entry coins and unit order are fixed. Ordinary bag IDs and split bags do not affect play.
	var coins_by_cell := PackedInt32Array()
	coins_by_cell.resize(board.board_size.x * board.board_size.y)
	var vaults := PackedStringArray()
	for bag in board.bags:
		if bag.is_vault():
			vaults.append("%s/%d/%d" % [bag.pos, bag.required_coins, bag.coins])
			continue
		coins_by_cell[bag.pos.y * board.board_size.x + bag.pos.x] += bag.coins
	vaults.sort()
	return "|".join(units) + str(coins_by_cell) + "|".join(vaults)

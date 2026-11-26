extends SceneTree

const LEVEL: PuzzleLevelData = preload("res://levels/level_04.tres")
const SCENE: PackedScene = preload("res://scenes/PuzzleLevel04.tscn")
const PLAYER_ID := PuzzleLevelData.PLAYER_ID
const A1 := Vector2i(0, 0)
const B1 := Vector2i(1, 0)
const C1 := Vector2i(2, 0)
const A2 := Vector2i(0, 1)
const B2 := Vector2i(1, 1)
const B3 := Vector2i(1, 2)
const C3 := Vector2i(2, 2)
const WIN_ROUTE := [
	[ActionType.MOVE, A2], [ActionType.MOVE, B3], [ActionType.MOVE, A2],
	[ActionType.MOVE, B1], [ActionType.THROW, C1], [ActionType.MOVE, C1],
	[ActionType.MOVE, B2], [ActionType.THROW, C3], [ActionType.MOVE, C3],
]
const DEAD_END_ROUTE := [
	[ActionType.MOVE, B1], [ActionType.STAY, B1], [ActionType.STAY, B1],
	[ActionType.MOVE, A1], [ActionType.THROW, C1],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures := 0
	if not _test_thrower_and_dead_end():
		push_error("puzzle_level_04_smoke: thrower, independent branches, or dead end changed")
		failures += 1

	var session := PuzzleSession.new()
	var shortest := Vector2i(-1, 0)
	if session.start_level(LEVEL):
		shortest = _search(session, LEVEL.optimal_turns)
	if shortest != Vector2i(9, 12):
		push_error("puzzle_level_04_smoke: expected 9 turns and 12 shortest routes, got %s" % shortest)
		failures += 1

	if not await _test_scene():
		push_error("puzzle_level_04_smoke: manual confirmation, win, score, or restart changed")
		failures += 1
	if failures == 0:
		print("puzzle_level_04_smoke: PASS (minimum 9 turns, 12 shortest routes, proven live dead end)")
	quit(0 if failures == 0 else 1)


func _test_thrower_and_dead_end() -> bool:
	var start := PuzzleSession.new()
	if not start.start_level(LEVEL):
		return false
	var aiming := start.fork()
	if not aiming.submit_turn(ActionType.MOVE, A2):
		return false
	var armed := aiming.preview_enemy_intent(3)
	var unarmed := aiming.preview_enemy_intent(4)
	if (
		start.get_board_snapshot().turn_index != 0
		or armed == null or armed.type != ActionType.THROW or armed.target_pos != A2
		or armed.throw_amount != 1 or unarmed == null or unarmed.type != ActionType.STAY
	):
		return false

	var trapped := start.fork()
	for step: Array in DEAD_END_ROUTE:
		if not trapped.submit_turn(step[0], step[1]):
			return false
	var board := trapped.get_board_snapshot()
	var player := board.get_unit_by_id(PLAYER_ID)
	return (
		trapped.get_phase() == PuzzleSession.Phase.ACTIVE and player.coins == 1
		and player.pos == A1 and board.bags.is_empty()
		and board.get_unit_by_id(2).stun_turns == 1
		and _search(trapped) == Vector2i.ZERO
	)


# The round number does not affect any policy in this level.
# Returns (-1, 0) if the depth cap is reached before the state space is exhausted.
func _search(start: PuzzleSession, max_turns: int = -1) -> Vector2i:
	var initial_key := _board_key(start.get_board_snapshot())
	var frontier := {initial_key: [start, 1]}
	var visited := {initial_key: true}
	var depth := 0
	while not frontier.is_empty() and (max_turns < 0 or depth < max_turns):
		depth += 1
		var next := {}
		var wins := 0
		for node: Array in frontier.values():
			var session: PuzzleSession = node[0]
			var path_count: int = node[1]
			for action in PuzzleActions.list_intents(session.get_board_snapshot(), PLAYER_ID):
				var branch := session.fork()
				if not branch.submit_turn(action.type, action.target_pos):
					return Vector2i(-1, 0)
				match branch.get_phase():
					PuzzleSession.Phase.WON:
						wins += path_count
					PuzzleSession.Phase.ACTIVE:
						var key := _board_key(branch.get_board_snapshot())
						if next.has(key):
							next[key][1] += path_count
						elif not visited.has(key):
							next[key] = [branch, path_count]
		if wins > 0:
			return Vector2i(depth, wins)
		for key in next:
			visited[key] = true
		frontier = next
	return Vector2i.ZERO if frontier.is_empty() else Vector2i(-1, 0)


func _board_key(board: GameState) -> String:
	var units := PackedStringArray()
	for unit in board.units:
		units.append("%s/%d/%d" % [unit.pos, unit.coins, unit.stun_turns] if unit.alive else "dead")
	var coins_by_cell := PackedInt32Array()
	coins_by_cell.resize(board.board_size.x * board.board_size.y)
	for bag in board.bags:
		coins_by_cell[bag.pos.y * board.board_size.x + bag.pos.x] += bag.coins
	return "|".join(units) + str(coins_by_cell)


func _test_scene() -> bool:
	var view := SCENE.instantiate()
	root.add_child(view)
	await process_frame
	var board: PuzzleBoardView = view.get_node("%Board")
	var status: Label = view.get_node("%Status")
	var result: Label = view.get_node("%Result")
	var submit: Button = view.get_node("%Submit")
	var restart: Button = view.get_node("%Restart")
	var okay := status.text.contains("回合 0") and status.text.contains("0 / 5")
	for step: Array in WIN_ROUTE:
		var turn_before := status.text
		var side: float = board.call("_cell_size")
		var origin: Vector2 = board.call("_board_origin", side)
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_LEFT if step[0] == ActionType.MOVE else MOUSE_BUTTON_RIGHT
		var cell: Vector2i = step[1]
		click.position = origin + (Vector2(cell) + Vector2(0.5, 0.5)) * side
		board._gui_input(click)
		okay = okay and status.text == turn_before
		submit.pressed.emit()
	okay = (
		okay and status.text.contains("5 / 5") and result.visible and submit.disabled
		and result.text.contains("9 回合") and result.text.contains("得分 0.56")
	)
	restart.pressed.emit()
	okay = okay and not result.visible and not submit.disabled and status.text.contains("回合 0")
	view.queue_free()
	await process_frame
	return okay

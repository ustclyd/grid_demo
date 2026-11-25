extends SceneTree

const LEVEL: PuzzleLevelData = preload("res://levels/level_02.tres")
const SCENE: PackedScene = preload("res://scenes/PuzzleLevel02.tscn")
const PLAYER_ID := PuzzleLevelData.PLAYER_ID
const GUARD_ID := 2
const MOVER_ID := 3
const PURSUER_ID := 4
const A1 := Vector2i(0, 0)
const B2 := Vector2i(1, 1)
const C3 := Vector2i(2, 2)
const REFERENCE_STEPS := [
	[ActionType.MOVE, A1],
	[ActionType.THROW, B2],
	[ActionType.MOVE, B2],
	[ActionType.THROW, C3],
	[ActionType.MOVE, C3],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures := 0
	if not _test_reference_route():
		push_error("puzzle_level_02_smoke: enemy previews, knockback conflict, stun, or score changed")
		failures += 1

	var shortest := _find_shortest_solutions()
	if shortest != Vector2i(5, 1):
		push_error("puzzle_level_02_smoke: expected 5 turns and one shortest route, found %s" % shortest)
		failures += 1

	if not await _test_scene():
		push_error("puzzle_level_02_smoke: scene controls, preview, win, score, or restart changed")
		failures += 1

	if failures == 0:
		print("puzzle_level_02_smoke: PASS (minimum 5 turns, exactly 1 shortest solution)")
	quit(0 if failures == 0 else 1)


func _test_reference_route() -> bool:
	var session := PuzzleSession.new()
	if not session.start_level(LEVEL) or session.get_target_coins() != 18:
		return false
	var scores: Array = []
	session.level_won.connect(func(coins: int, turns: int, score: float) -> void:
		scores.append([coins, turns, score])
	)
	if (
		not _matches_intent(session, GUARD_ID, ActionType.STAY, B2)
		or not _matches_intent(session, MOVER_ID, ActionType.MOVE, C3)
		or not _matches_intent(session, PURSUER_ID, ActionType.MOVE, B2)
	):
		return false

	if not session.submit_turn(ActionType.MOVE, A1):
		return false
	var board := session.get_board_snapshot()
	if (
		board.turn_index != 1 or board.get_unit_by_id(PURSUER_ID).alive
		or board.get_unit_by_id(GUARD_ID).coins != 9 or board.get_unit_by_id(MOVER_ID).coins != 3
		or not _matches_intent(session, MOVER_ID, ActionType.STAY, C3)
	):
		return false

	if not session.submit_turn(ActionType.THROW, B2):
		return false
	board = session.get_board_snapshot()
	if (
		board.get_unit_by_id(GUARD_ID).alive or board.get_unit_by_id(MOVER_ID).coins != 12
		or board.get_unit_by_id(PLAYER_ID).coins != 3
		or board.bags.size() != 1 or board.bags[0].pos != B2 or board.bags[0].coins != 3
	):
		return false

	if not session.submit_turn(ActionType.MOVE, B2) or not session.submit_turn(ActionType.THROW, C3):
		return false
	board = session.get_board_snapshot()
	if (
		board.get_unit_by_id(MOVER_ID).stun_turns != 1
		or not _matches_intent(session, MOVER_ID, ActionType.STAY, C3)
	):
		return false

	return (
		session.submit_turn(ActionType.MOVE, C3) and session.get_phase() == PuzzleSession.Phase.WON
		and session.get_board_snapshot().get_unit_by_id(PLAYER_ID).coins == 18
		and scores == [[12, 5, 2.4]]
	)


func _matches_intent(session: PuzzleSession, id: int, action_type: String, target: Vector2i) -> bool:
	var intent := session.preview_enemy_intent(id)
	return intent != null and intent.type == action_type and intent.target_pos == target


# Replay one representative per board at this depth and count every prefix that led to it.
func _find_shortest_solutions() -> Vector2i:
	var session := PuzzleSession.new()
	var frontier: Array = [{"path": [], "count": 1}]
	for depth in range(1, LEVEL.optimal_turns + 1):
		var next: Dictionary = {}
		var wins := 0
		for entry: Dictionary in frontier:
			var prefix: Array = entry.path
			if not _replay(session, prefix):
				return Vector2i(-1, 0)
			var actions := PuzzleActions.list_intents(session.get_board_snapshot(), PLAYER_ID)
			for action in actions:
				var candidate := prefix.duplicate()
				candidate.append(action)
				if not _replay(session, candidate):
					return Vector2i(-1, 0)
				if session.get_phase() == PuzzleSession.Phase.WON:
					wins += entry.count
				elif depth < LEVEL.optimal_turns and session.get_phase() == PuzzleSession.Phase.ACTIVE:
					var key := _level_02_board_key(session.get_board_snapshot())
					if next.has(key):
						next[key].count += entry.count
					else:
						next[key] = {"path": candidate, "count": entry.count}
		if wins > 0:
			return Vector2i(depth, wins)
		frontier = next.values()
	return Vector2i.ZERO


func _level_02_board_key(board: GameState) -> String:
	# Unit order and starting coins are fixed. Only current cells, coins and stun affect these
	# policies. With map mechanics disabled, separate bags in one cell behave like their sum.
	var units := PackedStringArray()
	for unit in board.units:
		units.append("%s/%d/%d" % [unit.pos, unit.coins, unit.stun_turns] if unit.alive else "dead")
	var coins_by_cell := PackedInt32Array()
	coins_by_cell.resize(board.board_size.x * board.board_size.y)
	for bag in board.bags:
		coins_by_cell[bag.pos.y * board.board_size.x + bag.pos.x] += bag.coins
	return "|".join(units) + str(coins_by_cell)


func _replay(session: PuzzleSession, path: Array) -> bool:
	if not session.start_level(LEVEL):
		return false
	for action: ActionIntent in path:
		if not session.submit_turn(action.type, action.target_pos):
			return false
	return true


func _test_scene() -> bool:
	var level_view := SCENE.instantiate()
	root.add_child(level_view)
	await process_frame
	var board_view: PuzzleBoardView = level_view.get_node("%Board")
	var level_rules: Label = level_view.get_node("%LevelRules")
	var submit: Button = level_view.get_node("%Submit")
	var restart: Button = level_view.get_node("%Restart")
	var result: Label = level_view.get_node("%Result")
	var status: Label = level_view.get_node("%Status")
	var previews: Dictionary = board_view.get("_enemy_intents")
	var okay := (
		level_rules.visible and level_rules.text.contains("追兵")
		and status.text.contains("6 / 18") and previews.size() == 3
	)
	if okay:
		okay = previews[PURSUER_ID].target_pos == B2 and previews[MOVER_ID].target_pos == C3

	var side: float = board_view.call("_cell_size")
	var origin: Vector2 = board_view.call("_board_origin", side)
	for step: Array in REFERENCE_STEPS:
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_LEFT if step[0] == ActionType.MOVE else MOUSE_BUTTON_RIGHT
		var cell: Vector2i = step[1]
		click.position = origin + (Vector2(cell) + Vector2(0.5, 0.5)) * side
		board_view._gui_input(click)
		submit.pressed.emit()

	okay = (
		okay and status.text.contains("18 / 18") and result.visible
		and result.text.contains("得分 2.40") and result.text.contains("达到最优")
		and submit.disabled
	)
	restart.pressed.emit()
	okay = okay and not result.visible and not submit.disabled and status.text.contains("6 / 18")
	level_view.queue_free()
	await process_frame
	return okay

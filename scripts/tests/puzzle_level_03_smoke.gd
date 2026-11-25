extends SceneTree

const LEVEL: PuzzleLevelData = preload("res://levels/level_03.tres")
const SCENE: PackedScene = preload("res://scenes/PuzzleLevel03.tscn")
const PLAYER_ID := PuzzleLevelData.PLAYER_ID
const PATROL_ID := 2
const A1 := Vector2i(0, 0)
const B2 := Vector2i(1, 1)
const B3 := Vector2i(1, 2)
const C1 := Vector2i(2, 0)
const LEFT_ROUTE := [
	[ActionType.MOVE, A1], [ActionType.MOVE, B2], [ActionType.STAY, B2], [ActionType.MOVE, C1],
]
const RIGHT_ROUTE := [
	[ActionType.MOVE, C1], [ActionType.MOVE, B2], [ActionType.STAY, B2], [ActionType.MOVE, A1],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures := 0
	if not _test_patrol():
		push_error("puzzle_level_03_smoke: patrol route or stun handling changed")
		failures += 1
	var shortest := _find_shortest_routes()
	if (
		LEVEL.optimal_turns != 4 or shortest.size() != 2
		or not shortest.has(LEFT_ROUTE) or not shortest.has(RIGHT_ROUTE)
	):
		push_error("puzzle_level_03_smoke: expected two mirror routes requiring a wait, found %s" % [shortest])
		failures += 1
	if not await _test_scene():
		push_error("puzzle_level_03_smoke: manual confirmation, win, score, or restart changed")
		failures += 1
	if failures == 0:
		print("puzzle_level_03_smoke: PASS (minimum 4 turns, exactly 2 mirror solutions, both wait)")
	quit(0 if failures == 0 else 1)


func _test_patrol() -> bool:
	var policy := LEVEL.enemies[0].policy as PuzzleBouncerPolicy
	if (
		not policy.accepts_spawn(B3, LEVEL.board_size)
		or policy.accepts_spawn(A1, LEVEL.board_size)
		or policy.accepts_spawn(B2, Vector2i(3, 2))
	):
		return false

	var session := PuzzleSession.new()
	if not session.start_level(LEVEL) or not _enemy_chooses(session, ActionType.MOVE, B2):
		return false
	if not session.submit_turn(ActionType.STAY) or not _enemy_chooses(session, ActionType.MOVE, B3):
		return false
	if not session.submit_turn(ActionType.STAY) or not _enemy_chooses(session, ActionType.MOVE, B2):
		return false

	if not session.start_level(LEVEL) or not session.submit_turn(ActionType.THROW, B2):
		return false
	var patrol := session.get_board_snapshot().get_unit_by_id(PATROL_ID)
	return (
		patrol.pos == B3 and patrol.stun_turns == 1
		and _enemy_chooses(session, ActionType.STAY, B3)
		and session.submit_turn(ActionType.STAY)
		and _enemy_chooses(session, ActionType.MOVE, B2)
	)


func _enemy_chooses(session: PuzzleSession, action_type: String, cell: Vector2i) -> bool:
	var intent := session.preview_enemy_intent(PATROL_ID)
	return intent != null and intent.type == action_type and intent.target_pos == cell


# This 3-by-3 level fits a direct breadth-first enumeration of action sequences.
func _find_shortest_routes() -> Array[Array]:
	var session := PuzzleSession.new()
	var frontier: Array[Array] = [[]]
	for depth in range(1, 5):
		var wins: Array[Array] = []
		var next: Array[Array] = []
		for prefix in frontier:
			if not _replay(session, prefix):
				return []
			var actions := PuzzleActions.list_intents(session.get_board_snapshot(), PLAYER_ID)
			for action in actions:
				var candidate := prefix + [[action.type, action.target_pos]]
				if not _replay(session, candidate):
					return []
				if session.get_phase() == PuzzleSession.Phase.WON:
					wins.append(candidate)
				elif depth < 4 and session.get_phase() == PuzzleSession.Phase.ACTIVE:
					next.append(candidate)
		if not wins.is_empty():
			return wins
		frontier = next
	return []


func _replay(session: PuzzleSession, steps: Array) -> bool:
	if not session.start_level(LEVEL):
		return false
	for step: Array in steps:
		if not session.submit_turn(step[0], step[1]):
			return false
	return true


func _test_scene() -> bool:
	var view := SCENE.instantiate()
	root.add_child(view)
	await process_frame
	var board: PuzzleBoardView = view.get_node("%Board")
	var status: Label = view.get_node("%Status")
	var result: Label = view.get_node("%Result")
	var submit: Button = view.get_node("%Submit")
	var stay: Button = view.get_node("%Stay")
	var restart: Button = view.get_node("%Restart")
	var okay := status.text.contains("回合 0") and status.text.contains("4 / 7")
	_click(board, A1)
	await create_timer(0.25).timeout
	okay = okay and status.text.contains("回合 0") and status.text.contains("4 / 7")
	submit.pressed.emit()
	okay = okay and status.text.contains("回合 1") and status.text.contains("5 / 7")

	_click(board, B2)
	submit.pressed.emit()
	stay.pressed.emit()
	submit.pressed.emit()
	okay = okay and status.text.contains("回合 3") and status.text.contains("6 / 7")
	_click(board, C1)
	submit.pressed.emit()
	okay = (
		okay and status.text.contains("7 / 7") and result.visible and submit.disabled
		and result.text.contains("4 回合") and result.text.contains("得分 0.75")
	)
	restart.pressed.emit()
	okay = okay and not result.visible and not submit.disabled and status.text.contains("回合 0")
	view.queue_free()
	await process_frame
	return okay


func _click(board: PuzzleBoardView, cell: Vector2i) -> void:
	var side: float = board.call("_cell_size")
	var origin: Vector2 = board.call("_board_origin", side)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = origin + (Vector2(cell) + Vector2(0.5, 0.5)) * side
	board._gui_input(click)

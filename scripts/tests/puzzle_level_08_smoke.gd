extends SceneTree

const Audit = preload("res://scripts/tests/puzzle_state_audit.gd")
const LEVEL: PuzzleLevelData = preload("res://levels/level_08.tres")
const SCENE: PackedScene = preload("res://scenes/PuzzleLevel08.tscn")
const PERIOD := 24
const A1 := Vector2i(0, 0)
const B1 := Vector2i(1, 0)
const B2 := Vector2i(1, 1)
const B3 := Vector2i(1, 2)
const C1 := Vector2i(2, 0)
const C2 := Vector2i(2, 1)
const C4 := Vector2i(2, 3)
const ROUTE := [
	[ActionType.STAY, C4], [ActionType.MOVE, B3], [ActionType.MOVE, B2],
	[ActionType.MOVE, C1], [ActionType.MOVE, B1], [ActionType.THROW, C2],
	[ActionType.THROW, A1], [ActionType.MOVE, A1], [ActionType.MOVE, B2],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cycle := _test_idle_cycle()
	var transfers := _test_coin_transfers()
	var stats := Audit.inspect(LEVEL, true)
	var no_throw := Audit.inspect(LEVEL, false, false)
	var verified: bool = (
		stats.get("shortest") == LEVEL.optimal_turns and stats.get("shortest_count") == 18
		and no_throw.get("shortest") == 0 and int(no_throw.get("total_active_states", 0)) > PERIOD
	)
	var playable := await _test_scene()
	if cycle and transfers and verified and playable:
		print("puzzle_level_08_smoke: PASS (24-turn idle cycle, best 9 turns, throwing required)")
	else:
		push_error("puzzle_level_08_smoke: cycle=%s transfers=%s graph=%s no_throw=%s scene=%s" % [
			cycle, transfers, stats, no_throw, playable,
		])
	quit(0 if cycle and transfers and verified and playable else 1)


func _test_idle_cycle() -> bool:
	var game := PuzzleSession.new()
	if not game.start_level(LEVEL):
		return false
	var opening := Audit._key(game.get_board_snapshot())
	for turn in range(1, PERIOD * 2 + 1):
		if not game.submit_turn(ActionType.STAY) or game.get_phase() != PuzzleSession.Phase.ACTIVE:
			return false
		var repeated := Audit._key(game.get_board_snapshot()) == opening
		if repeated != (turn % PERIOD == 0):
			return false
	return true


func _test_coin_transfers() -> bool:
	var game := PuzzleSession.new()
	if not game.start_level(LEVEL):
		return false
	for index in ROUTE.size():
		var move: Array = ROUTE[index]
		if not game.submit_turn(move[0], move[1]):
			return false
		var board := game.get_board_snapshot()
		if index == 5:
			var guard := board.get_unit_by_id(6)
			if guard.pos != C2 or guard.coins != 2 or guard.stun_turns != 1:
				return false
		if index == 6:
			var collector := board.get_unit_by_id(4)
			if board.get_unit_by_id(6).alive or collector.pos != C2 or collector.coins != 3:
				return false
		if index == 7:
			var collector := board.get_unit_by_id(4)
			if collector.pos != C1 or collector.coins != 4:
				return false
	return game.get_phase() == PuzzleSession.Phase.WON


func _test_scene() -> bool:
	var view := SCENE.instantiate()
	root.add_child(view)
	await process_frame
	var board: PuzzleBoardView = view.get_node("%Board")
	var status: Label = view.get_node("%Status")
	var result: Label = view.get_node("%Result")
	var submit: Button = view.get_node("%Submit")
	var restart: Button = view.get_node("%Restart")
	var okay := status.text.contains("回合 0") and status.text.contains("0 / 7")
	for step: Array in ROUTE:
		var before := status.text
		var side: float = board.call("_cell_size")
		var origin: Vector2 = board.call("_board_origin", side)
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_RIGHT if step[0] == ActionType.THROW else MOUSE_BUTTON_LEFT
		var cell: Vector2i = step[1]
		click.position = origin + (Vector2(cell) + Vector2(0.5, 0.5)) * side
		board._gui_input(click)
		okay = okay and status.text == before
		submit.pressed.emit()
	okay = (
		okay and status.text.contains("7 / 7") and result.visible and submit.disabled
		and result.text.contains("9 回合") and result.text.contains("得分 0.78")
	)
	restart.pressed.emit()
	okay = okay and not result.visible and not submit.disabled and status.text.contains("回合 0")
	view.queue_free()
	await process_frame
	return okay

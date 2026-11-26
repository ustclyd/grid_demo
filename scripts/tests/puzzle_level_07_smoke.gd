extends SceneTree

const Audit = preload("res://scripts/tests/puzzle_state_audit.gd")
const LEVEL: PuzzleLevelData = preload("res://levels/level_07.tres")
const SCENE: PackedScene = preload("res://scenes/PuzzleLevel07.tscn")
const A3 := Vector2i(0, 2)
const A4 := Vector2i(0, 3)
const B2 := Vector2i(1, 1)
const B3 := Vector2i(1, 2)
const C1 := Vector2i(2, 0)
const C3 := Vector2i(2, 2)
const ROUTE := [
	[ActionType.STAY, C3], [ActionType.MOVE, B3], [ActionType.MOVE, A4],
	[ActionType.MOVE, A3], [ActionType.THROW, B2], [ActionType.MOVE, B3],
	[ActionType.MOVE, B2], [ActionType.THROW, C1], [ActionType.MOVE, C1],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stats := Audit.inspect(LEVEL, true)
	print("puzzle_level_07_smoke graph: ", stats)
	var measured: bool = (
		stats.get("shortest") == LEVEL.optimal_turns and stats.get("shortest_count") == 13
	)
	var fights := _test_enemy_conflicts()
	var playable := await _test_scene()
	if measured and fights and playable:
		print("puzzle_level_07_smoke: PASS (standard rules, enemy collisions in both phases, best 9 turns)")
	else:
		push_error("puzzle_level_07_smoke: graph, enemy collisions, or scene replay changed")
	quit(0 if measured and fights and playable else 1)


func _test_enemy_conflicts() -> bool:
	var session := PuzzleSession.new()
	if not LEVEL.trail_cells.is_empty() or not session.start_level(LEVEL):
		return false
	var patrol := LEVEL.enemies[0].policy as PuzzlePatrollerPolicy
	if patrol == null or patrol.accepts_spawn(C3, LEVEL.board_size):
		return false

	var preview_board := session.get_board_snapshot()
	for index in patrol.route.size():
		preview_board.get_unit_by_id(2).pos = patrol.route[index]
		var intent := patrol.choose_intent(preview_board, 2, 1)
		if intent.type != ActionType.MOVE or intent.target_pos != patrol.route[(index + 1) % patrol.route.size()]:
			return false

	for index in 5:
		var step: Array = ROUTE[index]
		if not session.submit_turn(step[0], step[1]):
			return false
		var board := session.get_board_snapshot()
		if index == 2:
			var patrol_unit := board.get_unit_by_id(2)
			var guard := board.get_unit_by_id(4)
			if patrol_unit.alive or patrol_unit.pos != B2 or guard.pos != B2 or guard.coins != 2:
				return false
		if index == 4:
			var pushed_guard := board.get_unit_by_id(4)
			var corner_guard := board.get_unit_by_id(5)
			if pushed_guard.alive or pushed_guard.pos != C1 or not corner_guard.alive:
				return false
			if corner_guard.coins != 3 or board.units[0].pos != A3:
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
	var restart: Button = view.get_node("%Restart")
	var okay := status.text.contains("回合 0") and status.text.contains("0 / 6")
	for step: Array in ROUTE:
		var turn_before := status.text
		var side: float = board.call("_cell_size")
		var origin: Vector2 = board.call("_board_origin", side)
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_RIGHT if step[0] == ActionType.THROW else MOUSE_BUTTON_LEFT
		var cell: Vector2i = step[1]
		click.position = origin + (Vector2(cell) + Vector2(0.5, 0.5)) * side
		board._gui_input(click)
		okay = okay and status.text == turn_before
		submit.pressed.emit()
	okay = (
		okay and status.text.contains("6 / 6") and result.visible and submit.disabled
		and result.text.contains("9 回合") and result.text.contains("得分 0.67")
	)
	restart.pressed.emit()
	okay = okay and not result.visible and not submit.disabled and status.text.contains("回合 0")
	view.queue_free()
	await process_frame
	return okay

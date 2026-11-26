extends SceneTree

const Audit = preload("res://scripts/tests/puzzle_state_audit.gd")
const LEVEL: PuzzleLevelData = preload("res://levels/level_05.tres")
const SCENE: PackedScene = preload("res://scenes/PuzzleLevel05.tscn")
const A2 := Vector2i(0, 1)
const A3 := Vector2i(0, 2)
const B1 := Vector2i(1, 0)
const B2 := Vector2i(1, 1)
const B3 := Vector2i(1, 2)
const ROUTE := [
	[ActionType.MOVE, B2], [ActionType.MOVE, A3], [ActionType.STAY, A3],
	[ActionType.MOVE, A2], [ActionType.THROW, B1], [ActionType.MOVE, B1],
	[ActionType.MOVE, A2], [ActionType.THROW, B3], [ActionType.MOVE, B3],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stats := Audit.inspect(LEVEL)
	var measured: bool = (
		stats.get("shortest") == LEVEL.optimal_turns
		and stats.get("shortest_count") == 24
		and stats.get("total_active_states") == 4763
		and stats.get("winnable_active_states") == 4457
		and stats.get("opening_actions") == 4
		and stats.get("winnable_openings") == 1
		and stats.get("opening_live_dead_ends") == 2
		and stats.get("minimum_forced_choices") == 3
	)
	if not measured:
		push_error("puzzle_level_05_smoke: state graph changed: %s" % stats)
	var playable := await _test_scene()
	if not playable:
		push_error("puzzle_level_05_smoke: manual confirmation, win, score, or restart changed")
	if measured and playable:
		print("puzzle_level_05_smoke: PASS (1 of 4 openings wins, at least 3 forced choices, best 9 turns)")
	quit(0 if measured and playable else 1)


func _test_scene() -> bool:
	var view := SCENE.instantiate()
	root.add_child(view)
	await process_frame
	var board: PuzzleBoardView = view.get_node("%Board")
	var status: Label = view.get_node("%Status")
	var result: Label = view.get_node("%Result")
	var submit: Button = view.get_node("%Submit")
	var restart: Button = view.get_node("%Restart")
	var okay := status.text.contains("回合 0") and status.text.contains("0 / 4")
	for step: Array in ROUTE:
		var round_before := status.text
		var side: float = board.call("_cell_size")
		var origin: Vector2 = board.call("_board_origin", side)
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_RIGHT if step[0] == ActionType.THROW else MOUSE_BUTTON_LEFT
		var cell: Vector2i = step[1]
		click.position = origin + (Vector2(cell) + Vector2(0.5, 0.5)) * side
		board._gui_input(click)
		okay = okay and status.text == round_before
		submit.pressed.emit()
	okay = (
		okay and status.text.contains("4 / 4") and result.visible and submit.disabled
		and result.text.contains("9 回合") and result.text.contains("得分 0.44")
	)
	restart.pressed.emit()
	okay = okay and not result.visible and not submit.disabled and status.text.contains("回合 0")
	view.queue_free()
	await process_frame
	return okay

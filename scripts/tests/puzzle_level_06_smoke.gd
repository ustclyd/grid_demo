extends SceneTree

const LEVEL: PuzzleLevelData = preload("res://levels/level_06.tres")
const SCENE: PackedScene = preload("res://scenes/PuzzleLevel06.tscn")
const ROUTE := [0, 9, 18, 19, 20, 29, 28, 37, 38, 47, 48, 57, 56, 55, 46, 45, 54, 63, 72, 73, 64, 65, 74, 75, 66, 67, 76, 77, 78, 79, 80, 71, 62, 61, 70, 69, 68, 59, 60, 51, 52, 43, 42, 41, 40, 39, 30, 31, 22, 21, 12, 11, 2, 3, 4, 13, 14, 23, 24, 33, 34, 35, 26, 25, 16, 15, 6, 7, 8]
const EXTRA_ACTIONS := {
	5: [[ActionType.THROW, 28]],
	11: [[ActionType.THROW, 56], [ActionType.STAY, 57], [ActionType.STAY, 57], [ActionType.STAY, 57]],
	36: [[ActionType.THROW, 59]],
	46: [[ActionType.THROW, 31]],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var okay := _test_trail_rules()
	if not okay:
		push_error("puzzle_level_06_smoke: trail entry, branching, or goal checks failed")
	var playable := await _test_scene()
	if not playable:
		push_error("puzzle_level_06_smoke: reference route or scene restart failed")
	if okay and playable:
		print("puzzle_level_06_smoke: PASS (69 cells, playable 75-turn route)")
	quit(0 if okay and playable else 1)


func _test_trail_rules() -> bool:
	var level := PuzzleLevelData.new()
	level.board_size = Vector2i(3, 2)
	level.trail_cells.assign([Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN])
	level.trail_exit = Vector2i.DOWN
	level.player_coins = 2
	var bag := PuzzleBagSpawn.new()
	bag.cell = Vector2i.RIGHT
	bag.coins = 1
	level.bags.append(bag)

	var start := PuzzleSession.new()
	if not start.start_level(level):
		return false
	var game := start.fork()
	if game.submit_turn(ActionType.MOVE, Vector2i.ONE) or game.submit_turn(ActionType.THROW, Vector2i(2, 0)):
		return false
	if not game.submit_turn(ActionType.MOVE, Vector2i.RIGHT):
		return false
	var after := game.get_board_snapshot()
	if (
		after.units[0].coins != 3 or game.get_phase() != PuzzleSession.Phase.ACTIVE
		or not after.trail.has_left(Vector2i.ZERO) or start.get_board_snapshot().trail.has_left(Vector2i.ZERO)
		or game.submit_turn(ActionType.MOVE, Vector2i.ZERO)
	):
		return false
	return (
		game.submit_turn(ActionType.MOVE, Vector2i.ONE)
		and game.submit_turn(ActionType.MOVE, Vector2i.DOWN)
		and game.get_phase() == PuzzleSession.Phase.WON
	)


func _test_scene() -> bool:
	var view := SCENE.instantiate()
	root.add_child(view)
	await process_frame
	var board: PuzzleBoardView = view.get_node("%Board")
	var status: Label = view.get_node("%Status")
	var result: Label = view.get_node("%Result")
	var submit: Button = view.get_node("%Submit")
	var restart: Button = view.get_node("%Restart")
	var okay := status.text.contains("回合 0") and status.text.contains("未踏 68")
	for index in range(ROUTE.size() - 1):
		for action: Array in EXTRA_ACTIONS.get(index, []):
			_try_action(board, submit, action[0], action[1])
		_try_action(board, submit, ActionType.MOVE, ROUTE[index + 1])
	okay = (
		okay and status.text.contains("8 / 8") and status.text.contains("未踏 0")
		and status.text.contains("回合 75") and result.visible and submit.disabled
	)
	restart.pressed.emit()
	okay = okay and not result.visible and not submit.disabled and status.text.contains("未踏 68")
	view.queue_free()
	await process_frame
	return okay


func _try_action(board: PuzzleBoardView, submit: Button, action: String, index: int) -> void:
	var side: float = board.call("_cell_size")
	var origin: Vector2 = board.call("_board_origin", side)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_RIGHT if action == ActionType.THROW else MOUSE_BUTTON_LEFT
	var cell := Vector2i(index % 9, index / 9)
	click.position = origin + (Vector2(cell) + Vector2(0.5, 0.5)) * side
	board._gui_input(click)
	submit.pressed.emit()

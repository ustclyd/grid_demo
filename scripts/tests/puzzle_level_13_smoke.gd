extends SceneTree

const LEVEL: PuzzleLevelData = preload("res://levels/level_13.tres")
const SCENE: PackedScene = preload("res://scenes/PuzzleLevel13.tscn")
const REFERENCE := [
	[ActionType.MOVE, Vector2i(0, 0)], [ActionType.THROW, Vector2i(1, 0)],
	[ActionType.THROW, Vector2i(2, 0)], [ActionType.MOVE, Vector2i(1, 0)],
	[ActionType.MOVE, Vector2i(0, 0)], [ActionType.MOVE, Vector2i(1, 0)],
	[ActionType.MOVE, Vector2i(2, 0)], [ActionType.MOVE, Vector2i(1, 0)],
	[ActionType.THROW, Vector2i(2, 0)], [ActionType.STAY, Vector2i(1, 0)],
	[ActionType.THROW, Vector2i(2, 0)], [ActionType.MOVE, Vector2i(2, 0)],
	[ActionType.MOVE, Vector2i(2, 1)], [ActionType.THROW, Vector2i(1, 0)],
	[ActionType.MOVE, Vector2i(1, 2)], [ActionType.THROW, Vector2i(0, 2)],
]
const BLIND := [
	[ActionType.MOVE, Vector2i(0, 0)], [ActionType.THROW, Vector2i(1, 0)],
	[ActionType.THROW, Vector2i(2, 0)], [ActionType.MOVE, Vector2i(1, 0)],
	[ActionType.MOVE, Vector2i(2, 0)], [ActionType.MOVE, Vector2i(3, 0)],
	[ActionType.STAY, Vector2i(3, 0)], [ActionType.STAY, Vector2i(3, 0)],
	[ActionType.THROW, Vector2i(2, 0)], [ActionType.THROW, Vector2i(2, 1)],
	[ActionType.MOVE, Vector2i(2, 0)], [ActionType.MOVE, Vector2i(2, 1)],
	[ActionType.MOVE, Vector2i(3, 0)], [ActionType.STAY, Vector2i(3, 0)],
	[ActionType.STAY, Vector2i(3, 0)], [ActionType.STAY, Vector2i(3, 0)],
	[ActionType.THROW, Vector2i(2, 0)], [ActionType.THROW, Vector2i(2, 1)],
	[ActionType.MOVE, Vector2i(2, 0)], [ActionType.MOVE, Vector2i(2, 1)],
	[ActionType.MOVE, Vector2i(1, 2)],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var reference := _test_session(REFERENCE)
	var blind := _test_session(BLIND)
	var late_trap := _test_late_trap()
	var scene := await _test_scene()
	var valid_data := _test_invalid_data()
	var all_pass := reference and blind and late_trap and scene and valid_data
	if all_pass:
		print("puzzle_level_13_smoke: PASS (16/21-turn pressure wins, late trap, controls and restart)")
	else:
		push_error("puzzle_level_13_smoke: reference=%s blind=%s late_trap=%s scene=%s data=%s" % [
			reference, blind, late_trap, scene, valid_data,
		])
	quit(0 if all_pass else 1)


func _test_session(route: Array) -> bool:
	var game := PuzzleSession.new()
	if not game.start_level(LEVEL):
		return false
	for index in route.size():
		var step: Array = route[index]
		if game.get_phase() != PuzzleSession.Phase.ACTIVE or not game.submit_turn(step[0], step[1]):
			return false
	var board := game.get_board_snapshot()
	return (
		game.get_phase() == PuzzleSession.Phase.WON
		and board.turn_index == route.size()
		and board.occupied_pressure_cells().size() == board.pressure_cells.size()
		and board.get_unit_by_id(PuzzleLevelData.PLAYER_ID).coins < game.get_target_coins()
	)


func _test_late_trap() -> bool:
	var game := PuzzleSession.new()
	if not game.start_level(LEVEL):
		return false
	for index in REFERENCE.size() - 1:
		var step: Array = REFERENCE[index]
		if not game.submit_turn(step[0], step[1]):
			return false
	if not game.submit_turn(ActionType.STAY) or game.get_phase() != PuzzleSession.Phase.ACTIVE:
		return false
	var board := game.get_board_snapshot()
	if board.occupied_pressure_cells().size() != 3 or _living_units(board) != 4:
		return false
	# The same first conflict occurs for every player action on the next turn.
	for action in PuzzleActions.list_intents(board, PuzzleLevelData.PLAYER_ID):
		var branch := game.fork()
		if not branch.submit_turn(action.type, action.target_pos):
			return false
		if _living_units(branch.get_board_snapshot()) >= board.pressure_cells.size():
			return false
	return true


func _living_units(board: GameState) -> int:
	var count := 0
	for unit in board.units:
		if unit.alive and not unit.won:
			count += 1
	return count


func _test_invalid_data() -> bool:
	var level := LEVEL.duplicate() as PuzzleLevelData
	level.pressure_cells = [Vector2i.ZERO, Vector2i.ZERO]
	if level.validation_error().is_empty():
		return false
	level.pressure_cells = [Vector2i(-1, 0)]
	return not level.validation_error().is_empty()


func _test_scene() -> bool:
	var view := SCENE.instantiate()
	root.add_child(view)
	await process_frame
	var board: PuzzleBoardView = view.get_node("%Board")
	var status: Label = view.get_node("%Status")
	var submit: Button = view.get_node("%Submit")
	var restart: Button = view.get_node("%Restart")
	var result: Label = view.get_node("%Result")
	var first_status := status.text
	var okay := first_status.contains("回合 0") and first_status.contains("压板 0 / 4")
	for step: Array in REFERENCE:
		var before := status.text
		var side: float = board.call("_cell_size")
		var origin: Vector2 = board.call("_board_origin", side)
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_RIGHT if step[0] == ActionType.THROW else MOUSE_BUTTON_LEFT
		var cell: Vector2i = step[1]
		click.position = origin + (Vector2(cell) + Vector2(0.5, 0.5)) * side
		board._gui_input(click)
		okay = okay and status.text == before and not submit.disabled
		submit.pressed.emit()
	okay = (
		okay and status.text.contains("压板 4 / 4") and submit.disabled and result.visible
		and result.text.contains("压板全开") and result.text.contains("16 回合")
		and result.text.contains("达到最优回合数")
	)
	restart.pressed.emit()
	okay = okay and status.text == first_status and not result.visible and not submit.disabled
	view.queue_free()
	await process_frame
	return okay

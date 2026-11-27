extends SceneTree

const LEVEL: PuzzleLevelData = preload("res://levels/level_10.tres")
const SCENE: PackedScene = preload("res://scenes/PuzzleLevel10.tscn")
const ROUTE := [
	[ActionType.MOVE, Vector2i(1, 1)], [ActionType.MOVE, Vector2i(0, 2)],
	[ActionType.MOVE, Vector2i(1, 3)], [ActionType.THROW, Vector2i(3, 1)],
	[ActionType.MOVE, Vector2i(0, 2)], [ActionType.MOVE, Vector2i(1, 1)],
	[ActionType.MOVE, Vector2i(2, 0)], [ActionType.THROW, Vector2i(3, 1)],
	[ActionType.MOVE, Vector2i(1, 0)], [ActionType.MOVE, Vector2i(0, 0)],
	[ActionType.MOVE, Vector2i(1, 0)], [ActionType.STAY, Vector2i(1, 0)],
	[ActionType.MOVE, Vector2i(2, 1)], [ActionType.THROW, Vector2i(3, 1)],
	[ActionType.MOVE, Vector2i(2, 2)], [ActionType.MOVE, Vector2i(1, 2)],
	[ActionType.MOVE, Vector2i(0, 3)], [ActionType.MOVE, Vector2i(1, 2)],
	[ActionType.STAY, Vector2i(1, 2)], [ActionType.MOVE, Vector2i(2, 1)],
	[ActionType.MOVE, Vector2i(3, 1)], [ActionType.THROW, Vector2i(4, 0)],
	[ActionType.MOVE, Vector2i(4, 0)],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := PuzzleSession.new()
	var verified := game.start_level(LEVEL) and game.get_target_coins() == 7
	if verified:
		for index in ROUTE.size():
			var action: Array = ROUTE[index]
			if not game.submit_turn(action[0], action[1]):
				verified = false
				break
			if index == 10 or index == 16 or index == 17:
				var expected := 0 if index == 17 else 2
				verified = verified and _remaining_vaults(game.get_board_snapshot()) == expected
		verified = verified and game.get_phase() == PuzzleSession.Phase.WON
		verified = verified and game.get_board_snapshot().turn_index == LEVEL.optimal_turns
	var view_ok := await _test_controls()
	if verified and view_ok:
		print("puzzle_level_10_smoke: PASS (23-turn replay, three vault transitions, controls)")
	else:
		push_error("puzzle_level_10_smoke: replay=%s controls=%s" % [verified, view_ok])
	quit(0 if verified and view_ok else 1)


func _remaining_vaults(board: GameState) -> int:
	var count := 0
	for bag in board.bags:
		if bag.is_vault():
			count += 1
	return count


func _test_controls() -> bool:
	var view := SCENE.instantiate()
	root.add_child(view)
	await process_frame
	var board: PuzzleBoardView = view.get_node("%Board")
	var status: Label = view.get_node("%Status")
	var submit: Button = view.get_node("%Submit")
	var restart: Button = view.get_node("%Restart")
	var result: Label = view.get_node("%Result")
	var first_status := status.text
	var okay := first_status.contains("回合 0") and first_status.contains("2 / 7")
	for step: Array in ROUTE:
		var before := status.text
		var side: float = board.call("_cell_size")
		var origin: Vector2 = board.call("_board_origin", side)
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_RIGHT if step[0] == ActionType.THROW else MOUSE_BUTTON_LEFT
		click.position = origin + (Vector2(step[1]) + Vector2(0.5, 0.5)) * side
		board._gui_input(click)
		okay = okay and status.text == before and not submit.disabled
		submit.pressed.emit()
	okay = (
		okay and status.text.contains("7 / 7") and submit.disabled and result.visible
		and result.text.contains("23 回合") and result.text.contains("达到最优回合数")
	)
	restart.pressed.emit()
	okay = okay and status.text == first_status and not result.visible and not submit.disabled
	view.queue_free()
	await process_frame
	return okay

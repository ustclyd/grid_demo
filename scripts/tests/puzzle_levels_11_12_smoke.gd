extends SceneTree

const Audit = preload("res://scripts/tests/puzzle_state_audit.gd")

const LEVEL_11: PuzzleLevelData = preload("res://levels/level_11.tres")
const LEVEL_12: PuzzleLevelData = preload("res://levels/level_12.tres")
const SCENE_11: PackedScene = preload("res://scenes/PuzzleLevel11.tscn")
const SCENE_12: PackedScene = preload("res://scenes/PuzzleLevel12.tscn")
const ROUTE_11 := [
	[ActionType.THROW, Vector2i(2, 2)], [ActionType.MOVE, Vector2i(0, 1)],
	[ActionType.MOVE, Vector2i(0, 2)], [ActionType.MOVE, Vector2i(1, 3)],
	[ActionType.MOVE, Vector2i(0, 2)], [ActionType.MOVE, Vector2i(1, 2)],
	[ActionType.MOVE, Vector2i(2, 2)], [ActionType.MOVE, Vector2i(3, 2)],
	[ActionType.MOVE, Vector2i(4, 1)], [ActionType.MOVE, Vector2i(4, 0)],
	[ActionType.STAY, Vector2i(4, 0)], [ActionType.MOVE, Vector2i(3, 0)],
	[ActionType.MOVE, Vector2i(2, 0)], [ActionType.STAY, Vector2i(2, 0)],
	[ActionType.MOVE, Vector2i(1, 1)], [ActionType.MOVE, Vector2i(0, 1)],
	[ActionType.THROW, Vector2i(1, 0)], [ActionType.MOVE, Vector2i(1, 0)],
	[ActionType.MOVE, Vector2i(2, 0)], [ActionType.MOVE, Vector2i(3, 1)],
	[ActionType.MOVE, Vector2i(4, 2)], [ActionType.THROW, Vector2i(3, 3)],
	[ActionType.MOVE, Vector2i(3, 3)],
]
const ROUTE_12 := [
	[ActionType.MOVE, Vector2i(0, 1)], [ActionType.THROW, Vector2i(2, 3)],
	[ActionType.MOVE, Vector2i(1, 2)], [ActionType.MOVE, Vector2i(0, 2)],
	[ActionType.MOVE, Vector2i(1, 2)], [ActionType.MOVE, Vector2i(2, 3)],
	[ActionType.MOVE, Vector2i(3, 2)], [ActionType.MOVE, Vector2i(4, 1)],
	[ActionType.MOVE, Vector2i(4, 0)], [ActionType.MOVE, Vector2i(4, 1)],
	[ActionType.STAY, Vector2i(4, 1)], [ActionType.MOVE, Vector2i(3, 0)],
	[ActionType.MOVE, Vector2i(2, 1)], [ActionType.STAY, Vector2i(2, 1)],
	[ActionType.THROW, Vector2i(1, 0)], [ActionType.MOVE, Vector2i(1, 0)],
	[ActionType.MOVE, Vector2i(1, 1)], [ActionType.MOVE, Vector2i(2, 2)],
	[ActionType.THROW, Vector2i(3, 3)], [ActionType.MOVE, Vector2i(3, 3)],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var playable_11 := await _replay_scene(SCENE_11, LEVEL_11, ROUTE_11, 8)
	var playable_12 := await _replay_scene(SCENE_12, LEVEL_12, ROUTE_12, 8)
	var dead_end_11 := _loses_zero_coin_qualifier(LEVEL_11, ActionType.THROW, Vector2i(1, 0))
	var dead_end_12 := _checks_level_12_trap()
	var okay := playable_11 and playable_12 and dead_end_11 and dead_end_12
	if okay:
		print("puzzle_levels_11_12_smoke: PASS (23/20-turn scene replays, restarts, live dead ends)")
	else:
		push_error("puzzle_levels_11_12_smoke: scenes=%s,%s dead_ends=%s,%s" % [
			playable_11, playable_12, dead_end_11, dead_end_12,
		])
	quit(0 if okay else 1)


func _loses_zero_coin_qualifier(level: PuzzleLevelData, action: String, target: Vector2i) -> bool:
	var game := PuzzleSession.new()
	if not game.start_level(level) or not game.submit_turn(action, target):
		return false
	if game.get_phase() != PuzzleSession.Phase.ACTIVE:
		return false
	return _zero_coin_status(game.get_board_snapshot()) == Vector2i(3, 2)


func _checks_level_12_trap() -> bool:
	var game := PuzzleSession.new()
	if not game.start_level(LEVEL_12):
		return false
	var prefix := [
		[ActionType.THROW, Vector2i(2, 0)], [ActionType.MOVE, Vector2i(0, 1)],
		[ActionType.MOVE, Vector2i(1, 2)], [ActionType.MOVE, Vector2i(0, 1)],
	]
	for step: Array in prefix:
		if not game.submit_turn(step[0], step[1]):
			return false
	if game.get_phase() != PuzzleSession.Phase.ACTIVE:
		return false
	var board := game.get_board_snapshot()
	if _zero_coin_status(board) != Vector2i(1, 1):
		return false

	# Search the surviving branches that still have enough zero-coin units.
	var pending: Array[PuzzleSession] = [game]
	var visited := {Audit._key(board): true}
	var index := 0
	while index < pending.size():
		var current := pending[index]
		for action in PuzzleActions.list_intents(current.get_board_snapshot(), PuzzleLevelData.PLAYER_ID):
			var branch := current.fork()
			if not branch.submit_turn(action.type, action.target_pos):
				return false
			if branch.get_phase() == PuzzleSession.Phase.LOST:
				continue
			var next_board := branch.get_board_snapshot()
			var status := _zero_coin_status(next_board)
			if status.x == 0:
				return false
			var key := Audit._key(next_board)
			if status.x <= status.y and not visited.has(key):
				visited[key] = true
				pending.append(branch)
		index += 1
	return true


func _zero_coin_status(board: GameState) -> Vector2i:
	var vaults := 0
	var qualifiers := 0
	for bag in board.bags:
		if bag.is_vault() and bag.required_coins == 0:
			vaults += 1
	for unit in board.units:
		if unit.alive and unit.coins == 0:
			qualifiers += 1
	return Vector2i(vaults, qualifiers)


func _replay_scene(scene: PackedScene, level: PuzzleLevelData, route: Array, total: int) -> bool:
	var view := scene.instantiate()
	root.add_child(view)
	await process_frame
	var board: PuzzleBoardView = view.get_node("%Board")
	var title: Label = view.get_node("%Title")
	var status: Label = view.get_node("%Status")
	var submit: Button = view.get_node("%Submit")
	var restart: Button = view.get_node("%Restart")
	var result: Label = view.get_node("%Result")
	var initial_status := status.text
	var okay := (
		title.text == level.title and not result.visible and initial_status.contains("回合 0")
		and initial_status.contains("%d / %d" % [level.player_coins, total])
	)
	for step: Array in route:
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
	okay = okay and status.text.contains("持币 %d / %d" % [total, total]) and submit.disabled
	okay = okay and result.visible and result.text.contains("通关") and result.text.contains("%d 回合" % route.size())
	restart.pressed.emit()
	okay = okay and status.text == initial_status and not result.visible and not submit.disabled
	view.queue_free()
	await process_frame
	return okay

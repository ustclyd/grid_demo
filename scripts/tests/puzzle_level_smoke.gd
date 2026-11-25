
extends SceneTree

const LEVEL_01: PuzzleLevelData = preload("res://levels/level_01.tres")
const LEVEL_SCENE: PackedScene = preload("res://scenes/PuzzleLevel.tscn")


class ProbePolicy extends PuzzleEnemyPolicy:
	@export var mutate_snapshot := false
	@export var invalid_actor := false

	func is_available() -> bool:
		return true

	func choose_intent(board: GameState, unit_id: int, player_id: int) -> ActionIntent:
		var player := board.get_unit_by_id(player_id)
		if player.coins != 5:
			return null
		if mutate_snapshot:
			player.coins = 1000
		return PuzzleActions.create_intent(board, player_id if invalid_actor else unit_id, ActionType.STAY)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cases := {
		"level one is winnable in exactly two minimum turns": _test_optimal_first_level,
		"terminal outcome emits once and restart restores coins": _test_outcomes_and_restart,
		"longer solutions score lower": _test_slower_solution,
		"invalid input and stun leave the turn unspent": _test_intent_validation,
		"level recipes reject bad boards and unavailable enemy kinds": _test_bad_level_data,
		"enemy policies read isolated snapshots": _test_policy_snapshot,
		"invalid enemy intent is rejected without changing game state": _test_invalid_enemy_intent,
		"zero-coin enemies can survive a win": _test_zero_coin_enemy,
	}
	var failures := 0
	for label in cases:
		var test_case: Callable = cases[label]
		if not test_case.call():
			push_error("puzzle_level_smoke: " + label)
			failures += 1
	if not await _test_scene():
		push_error("puzzle_level_smoke: scene input, score display, or restart did not match")
		failures += 1

	var count := cases.size() + 1
	if failures == 0:
		print("puzzle_level_smoke: PASS (%d cases, verified minimum 2 turns)" % count)
	else:
		print("puzzle_level_smoke: FAIL (%d of %d cases)" % [failures, count])
	quit(0 if failures == 0 else 1)


func _test_optimal_first_level() -> bool:
	var session := PuzzleSession.new()
	if not session.start_level(LEVEL_01):
		return false
	var starting_intents := PuzzleActions.list_intents(session.get_board_snapshot(), PuzzleLevelData.PLAYER_ID)
	var types: Array[String] = []
	for intent in starting_intents:
		types.append(intent.type)
		if not session.start_level(LEVEL_01) or not session.submit_turn(intent.type, intent.target_pos):
			return false
		if session.get_phase() == PuzzleSession.Phase.WON:
			return false
	if types != [ActionType.STAY, ActionType.MOVE, ActionType.THROW] or starting_intents[2].throw_amount != 2:
		return false

	var scores: Array = []
	session.level_won.connect(func(coins: int, turns: int, score: float) -> void:
		scores.append([coins, turns, score])
	)
	if not session.start_level(LEVEL_01) or not session.submit_turn(ActionType.THROW, Vector2i.RIGHT):
		return false
	var after_throw := session.get_board_snapshot()
	if after_throw.get_unit_by_id(2).stun_turns != 1 or session.get_phase() != PuzzleSession.Phase.ACTIVE:
		return false
	if not session.submit_turn(ActionType.MOVE, Vector2i.RIGHT):
		return false
	var after_win := session.get_board_snapshot()
	return (
		session.get_phase() == PuzzleSession.Phase.WON and LEVEL_01.optimal_turns == 2
		and after_win.turn_index == 2 and after_win.get_unit_by_id(1).coins == 6
		and scores == [[1, 2, 0.5]]
	)


func _test_outcomes_and_restart() -> bool:
	var session := PuzzleSession.new()
	var losses: Array[int] = []
	var scores: Array[float] = []
	session.level_lost.connect(func(turns: int) -> void: losses.append(turns))
	session.level_won.connect(func(_coins: int, _turns: int, score: float) -> void: scores.append(score))

	if not session.start_level(LEVEL_01) or not session.submit_turn(ActionType.MOVE, Vector2i.RIGHT):
		return false
	if session.get_phase() != PuzzleSession.Phase.LOST or losses != [1] or session.submit_turn(ActionType.STAY):
		return false
	if not session.start_level(LEVEL_01) or not session.submit_turn(ActionType.THROW, Vector2i.RIGHT):
		return false
	if not session.submit_turn(ActionType.MOVE, Vector2i.RIGHT) or session.submit_turn(ActionType.STAY):
		return false
	if scores != [0.5] or session.get_board_snapshot().turn_index != 2 or not session.start_level(LEVEL_01):
		return false
	var snapshot := session.get_board_snapshot()
	snapshot.get_unit_by_id(1).coins = 100
	var restarted := session.get_board_snapshot()
	return (
		session.get_phase() == PuzzleSession.Phase.ACTIVE and restarted.turn_index == 0
		and restarted.get_unit_by_id(1).coins == 5 and restarted.get_unit_by_id(2).coins == 1
		and restarted.get_unit_by_id(2).stun_turns == 0 and session.get_target_coins() == 6
	)


func _test_slower_solution() -> bool:
	var session := PuzzleSession.new()
	var scores: Array = []
	session.level_won.connect(func(coins: int, turns: int, score: float) -> void:
		scores.append([coins, turns, score])
	)
	return (
		session.start_level(LEVEL_01) and session.submit_turn(ActionType.STAY)
		and session.submit_turn(ActionType.THROW, Vector2i.RIGHT) and session.submit_turn(ActionType.MOVE, Vector2i.RIGHT)
		and scores.size() == 1 and scores[0][0] == 1 and scores[0][1] == 3
		and is_equal_approx(scores[0][2], 1.0 / 3.0)
	)


func _test_intent_validation() -> bool:
	var session := PuzzleSession.new()
	if not session.start_level(LEVEL_01):
		return false
	if session.submit_turn(ActionType.THROW, Vector2i.ZERO) or session.submit_turn(ActionType.MOVE, Vector2i(2, 0)):
		return false
	if session.submit_turn("unknown", Vector2i.RIGHT) or session.get_board_snapshot().turn_index != 0:
		return false
	var board := session.get_board_snapshot()
	var player := board.get_unit_by_id(1)
	player.stun_turns = 1
	var options := PuzzleActions.list_intents(board, 1)
	if options.size() != 1 or options[0].type != ActionType.STAY:
		return false
	player.stun_turns = 0
	player.coins = 1
	return PuzzleActions.create_intent(board, 1, ActionType.THROW, Vector2i.RIGHT) == null


func _test_bad_level_data() -> bool:
	var session := PuzzleSession.new()
	if not session.start_level(LEVEL_01) or session.start_level(null):
		return false
	var data := PuzzleLevelData.new()
	if session.start_level(data):
		return false
	data.board_size = Vector2i(0, 1)
	if session.start_level(data):
		return false
	data.board_size = Vector2i(2, 1)
	var enemy := _spawn(Vector2i.ZERO, 1, PuzzleSentryPolicy.new())
	data.enemies.append(enemy)
	if session.start_level(data):
		return false
	enemy.cell = Vector2i.RIGHT
	enemy.coins = -1
	if session.start_level(data):
		return false
	enemy.coins = 1
	enemy.policy = PuzzleEnemyPolicy.new()
	enemy.policy.kind = PuzzleEnemyPolicy.Kind.PURSUER
	if session.start_level(data):
		return false
	enemy.policy = PuzzleSentryPolicy.new()
	var bad_bag := PuzzleBagSpawn.new()
	bad_bag.cell = Vector2i(4, 0)
	data.bags.append(bad_bag)
	return not session.start_level(data) and session.get_board_snapshot().turn_index == 0


func _test_policy_snapshot() -> bool:
	var session := PuzzleSession.new()
	var mutator := ProbePolicy.new()
	mutator.mutate_snapshot = true
	var data := PuzzleLevelData.new()
	data.board_size = Vector2i(3, 1)
	data.player_coins = 5
	data.enemies.assign([_spawn(Vector2i(1, 0), 1, mutator), _spawn(Vector2i(2, 0), 1, ProbePolicy.new())])
	if not session.start_level(data) or not session.submit_turn(ActionType.STAY):
		return false
	return session.get_board_snapshot().get_unit_by_id(1).coins == 5 and session.get_board_snapshot().turn_index == 1


func _test_invalid_enemy_intent() -> bool:
	var session := PuzzleSession.new()
	var invalid := ProbePolicy.new()
	invalid.invalid_actor = true
	var data := PuzzleLevelData.new()
	data.player_coins = 5
	data.enemies.append(_spawn(Vector2i.RIGHT, 1, invalid))
	if not session.start_level(data) or session.submit_turn(ActionType.STAY):
		return false
	return session.get_board_snapshot().turn_index == 0 and session.get_phase() == PuzzleSession.Phase.ACTIVE


func _test_zero_coin_enemy() -> bool:
	var session := PuzzleSession.new()
	var data := PuzzleLevelData.new()
	data.player_coins = 5
	data.enemies.append(_spawn(Vector2i.RIGHT, 0, PuzzleSentryPolicy.new()))
	var bag := PuzzleBagSpawn.new()
	bag.coins = 2
	data.bags.append(bag)
	if not session.start_level(data) or not session.submit_turn(ActionType.STAY):
		return false
	var board := session.get_board_snapshot()
	return session.get_phase() == PuzzleSession.Phase.WON and board.get_unit_by_id(2).alive


func _test_scene() -> bool:
	var scene := LEVEL_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	var board_view := scene.get_node("%Board") as PuzzleBoardView
	var result := scene.get_node("%Result") as Label
	var status := scene.get_node("%Status") as Label
	var intent := scene.get_node("%Intent") as Label
	var submit := scene.get_node("%Submit") as Button
	var restart := scene.get_node("%Restart") as Button
	var okay := status.text.contains("0") and status.text.contains("5 / 6") and not submit.disabled
	_click(board_view, Vector2i.RIGHT, MOUSE_BUTTON_RIGHT)
	okay = okay and intent.text.contains("2")
	submit.pressed.emit()
	okay = okay and status.text.contains("3 / 6") and not result.visible

	_click(board_view, Vector2i.RIGHT, MOUSE_BUTTON_LEFT)
	submit.pressed.emit()
	okay = okay and result.visible and result.text.contains("0.50") and result.text.contains("达到最优")
	okay = okay and submit.disabled and status.text.contains("6 / 6")
	submit.pressed.emit()
	okay = okay and status.text.begins_with("回合 2")
	restart.pressed.emit()
	okay = okay and not result.visible and not submit.disabled and status.text.begins_with("回合 0")
	_click(board_view, Vector2i.RIGHT, MOUSE_BUTTON_LEFT)
	submit.pressed.emit()
	okay = okay and result.visible and result.text.contains("被击败") and submit.disabled
	scene.queue_free()
	return okay


func _click(board_view: PuzzleBoardView, cell: Vector2i, button: MouseButton) -> void:
	var side := board_view._cell_size()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = button
	mouse.pressed = true
	mouse.position = board_view._board_origin(side) + (Vector2(cell) + Vector2(0.5, 0.5)) * side
	board_view._gui_input(mouse)


func _spawn(cell: Vector2i, coins: int, policy: PuzzleEnemyPolicy) -> PuzzleEnemySpawn:
	var result := PuzzleEnemySpawn.new()
	result.cell = cell
	result.coins = coins
	result.policy = policy
	return result

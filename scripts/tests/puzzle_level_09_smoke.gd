extends SceneTree

const LEVEL: PuzzleLevelData = preload("res://levels/level_09.tres")
const SCENE: PackedScene = preload("res://scenes/PuzzleLevel09.tscn")
const D1 := Vector2i(3, 0)
const DESIGN_ROUTE := [
	[ActionType.THROW, Vector2i(1, 3)], [ActionType.MOVE, Vector2i(3, 2)],
	[ActionType.STAY, Vector2i(3, 2)], [ActionType.MOVE, Vector2i(2, 3)],
	[ActionType.MOVE, Vector2i(1, 3)], [ActionType.MOVE, Vector2i(0, 3)],
	[ActionType.MOVE, Vector2i(1, 3)], [ActionType.MOVE, Vector2i(2, 2)],
	[ActionType.THROW, Vector2i(2, 1)], [ActionType.MOVE, Vector2i(2, 3)],
	[ActionType.MOVE, Vector2i(1, 2)], [ActionType.THROW, Vector2i(3, 0)],
	[ActionType.MOVE, Vector2i(2, 1)], [ActionType.MOVE, Vector2i(3, 0)],
	[ActionType.THROW, Vector2i(3, 1)], [ActionType.MOVE, Vector2i(2, 0)],
	[ActionType.MOVE, Vector2i(2, 1)], [ActionType.MOVE, Vector2i(1, 2)],
	[ActionType.THROW, Vector2i(2, 1)], [ActionType.THROW, Vector2i(3, 2)],
	[ActionType.THROW, Vector2i(1, 1)], [ActionType.STAY, Vector2i(1, 2)],
	[ActionType.MOVE, Vector2i(2, 1)], [ActionType.MOVE, Vector2i(3, 0)],
	[ActionType.MOVE, Vector2i(3, 1)], [ActionType.MOVE, Vector2i(3, 2)],
	[ActionType.MOVE, Vector2i(2, 1)], [ActionType.MOVE, Vector2i(1, 2)],
	[ActionType.MOVE, Vector2i(0, 1)], [ActionType.THROW, Vector2i(1, 0)],
	[ActionType.MOVE, Vector2i(1, 0)], [ActionType.MOVE, Vector2i(1, 1)],
]
const BLIND_ROUTE := [
	[ActionType.THROW, Vector2i(3, 0)], [ActionType.MOVE, Vector2i(3, 0)],
	[ActionType.STAY, Vector2i(3, 0)], [ActionType.MOVE, Vector2i(2, 1)],
	[ActionType.MOVE, Vector2i(1, 2)], [ActionType.MOVE, Vector2i(0, 3)],
	[ActionType.THROW, Vector2i(1, 3)], [ActionType.THROW, Vector2i(0, 1)],
	[ActionType.THROW, Vector2i(2, 3)], [ActionType.MOVE, Vector2i(1, 2)],
	[ActionType.MOVE, Vector2i(0, 1)], [ActionType.MOVE, Vector2i(1, 1)],
	[ActionType.MOVE, Vector2i(2, 0)], [ActionType.THROW, Vector2i(3, 0)],
	[ActionType.MOVE, Vector2i(1, 1)], [ActionType.MOVE, Vector2i(1, 2)],
	[ActionType.MOVE, Vector2i(2, 3)], [ActionType.THROW, Vector2i(0, 3)],
	[ActionType.THROW, Vector2i(1, 3)], [ActionType.MOVE, Vector2i(2, 2)],
	[ActionType.MOVE, Vector2i(3, 2)], [ActionType.STAY, Vector2i(3, 2)],
	[ActionType.MOVE, Vector2i(3, 1)], [ActionType.MOVE, Vector2i(3, 0)],
	[ActionType.MOVE, Vector2i(2, 1)], [ActionType.MOVE, Vector2i(2, 2)],
	[ActionType.MOVE, Vector2i(1, 3)], [ActionType.MOVE, Vector2i(0, 3)],
	[ActionType.MOVE, Vector2i(0, 2)], [ActionType.MOVE, Vector2i(1, 1)],
	[ActionType.THROW, Vector2i(1, 0)], [ActionType.MOVE, Vector2i(1, 0)],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var designer := _test_route(DESIGN_ROUTE, true)
	var blind := _test_route(BLIND_ROUTE, false)
	var pickup := _test_vault_pickup()
	var scene := await _test_scene()
	var passed := designer and blind and pickup and scene
	if passed:
		print("puzzle_level_09_smoke: PASS (two 32-turn wins, exact wallet, UI and restart)")
	else:
		push_error("puzzle_level_09_smoke: designer=%s blind=%s pickup=%s scene=%s" % [
			designer, blind, pickup, scene,
		])
	quit(0 if passed else 1)


func _test_route(route: Array, enemy_opens_first: bool) -> bool:
	var game := PuzzleSession.new()
	if not game.start_level(LEVEL) or game.get_target_coins() != 26:
		return false
	for index in route.size():
		var step: Array = route[index]
		if game.get_phase() != PuzzleSession.Phase.ACTIVE or not game.submit_turn(step[0], step[1]):
			print("Rejected turn ", index + 1, ": ", game.last_error)
			return false
		var board := game.get_board_snapshot()
		var player := board.get_unit_by_id(1)
		if not player.alive:
			print("Player defeated on turn ", index + 1)
			return false
		if index == 0:
			var bouncer := board.get_unit_by_id(3)
			if enemy_opens_first:
				if bouncer.pos != D1 or bouncer.coins != 5 or _has_vault(board, D1):
					return false
			elif not _has_vault(board, D1) or bouncer.stun_turns != 1 or player.coins != 2:
				return false
		if index == 1 and not enemy_opens_first:
			if _has_vault(board, D1) or player.coins != 5:
				return false
	if game.get_phase() != PuzzleSession.Phase.WON:
		print("Final board: player holds ", game.get_board_snapshot().units[0].coins)
	return game.get_phase() == PuzzleSession.Phase.WON


func _test_vault_pickup() -> bool:
	var level := PuzzleLevelData.new()
	level.player_coins = 1
	var vault := PuzzleBagSpawn.new()
	vault.required_coins = 3
	vault.coins = 4
	level.bags.append(vault)
	var loose := PuzzleBagSpawn.new()
	loose.coins = 2
	level.bags.append(loose)
	var game := PuzzleSession.new()
	if not game.start_level(level):
		return false
	# The vault is listed first in the resource, but loose coins are picked up first.
	if not game.submit_turn(ActionType.STAY) or game.get_phase() != PuzzleSession.Phase.WON:
		return false

	level.player_coins = 2
	if not game.start_level(level) or not game.submit_turn(ActionType.STAY):
		return false
	var board := game.get_board_snapshot()
	if board.units[0].coins != 4 or not _has_vault(board, Vector2i.ZERO):
		return false

	# A stunned unit standing at the vault must spend its stun before it can collect.
	board.units[0].coins = 3
	board.units[0].stun_turns = 1
	var intent := PuzzleActions.create_intent(board, 1, ActionType.STAY)
	var after := TurnResolver.new().resolve_turn(board, [intent]).state_after
	if not _has_vault(after, Vector2i.ZERO) or after.units[0].stun_turns != 0:
		return false

	var duplicate := vault.duplicate() as PuzzleBagSpawn
	level.bags.append(duplicate)
	return not game.start_level(level)


func _has_vault(board: GameState, cell: Vector2i) -> bool:
	for bag in board.bags:
		if bag.pos == cell and bag.is_vault():
			return true
	return false


func _test_scene() -> bool:
	var view := SCENE.instantiate()
	root.add_child(view)
	await process_frame
	var board: PuzzleBoardView = view.get_node("%Board")
	var status: Label = view.get_node("%Status")
	var result: Label = view.get_node("%Result")
	var submit: Button = view.get_node("%Submit")
	var restart: Button = view.get_node("%Restart")
	var okay := status.text.contains("回合 0") and status.text.contains("3 / 26")
	for step: Array in BLIND_ROUTE:
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
		okay and status.text.contains("26 / 26") and submit.disabled and result.visible
		and result.text.contains("32 回合") and result.text.contains("得分 0.72")
	)
	restart.pressed.emit()
	okay = okay and not result.visible and not submit.disabled and status.text.contains("回合 0")
	view.queue_free()
	await process_frame
	return okay

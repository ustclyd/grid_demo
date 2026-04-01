extends Node2D

const GRID_COUNT := 7
const CELL_SIZE := 96.0
const GRID_COLOR := Color(0.85, 0.85, 0.85)
const PLAYER_COLOR := Color(0.2, 0.6, 1.0)
const TEST_ENEMY_COLOR := Color(1.0, 0.35, 0.35)
const TEST_MOVER_COLOR := Color(1.0, 0.6, 0.2)
const ALERT_COLOR := Color(1.0, 0.9, 0.2)
const TIMER_IDLE_COLOR := Color(0.2, 0.6, 1.0)
const TIMER_EXECUTING_COLOR := Color(1.0, 0.25, 0.25)
const LINE_WIDTH := 2.0
const PLAYER_RING_WIDTH := 3.0
const TURN_INTERVAL := 5.0
const EXECUTE_DURATION := 1.0
const DEBUG_TEXT_SIZE := 16
const DEBUG_LINE_HEIGHT := 18.0
const TEST_SCENARIO_STAYER := 0
const TEST_SCENARIO_MOVER := 1
const TEST_SCENARIO_THREE_WAY := 2
const TEST_SCENARIO_SWAP := 3
const TEST_SCENARIO_TIE := 4
const TEST_SCENARIO_PICK := 5
const TEST_SCENARIO_PICK_EMPTY := 6
const TEST_SCENARIO_PICK_MULTI := 7
const TEST_SCENARIO_PICK_REMOTE := 8
const TEST_SCENARIO_PICK_CONFLICT := 9
const TEST_SCENARIO_THROW := 10
const TEST_SCENARIO_THROW_LOW_COIN := 11
const TEST_SCENARIO_THROW_TWO_COINS := 12
const TEST_SCENARIO_THROW_CONFLICT := 13
const TEST_SCENARIO_THROW_KNOCKBACK := 14
const TEST_SCENARIO_THROW_CONFLICT2 := 15
const TEST_SCENARIO_THROW_MULTI_HIT := 16
const TEST_SCENARIO_PORTAL_BASIC := 17
const TEST_SCENARIO_PORTAL_CONFLICT := 18
const TEST_SCENARIO_EXIT_BASIC := 19
const TEST_SCENARIO_EXIT_CONFLICT := 20
const TEST_SCENARIO_EXIT_QUEUED := 21
const TEST_SCENARIO_PORTAL_BAG := 22
const TEST_SCENARIO_EXIT_BAG := 23
const TEST_SCENARIO_EXIT_UNIT_BAG := 24

var player_grid := Vector2i(0, GRID_COUNT - 1)
var player_alive := true
var player_coins := 0
var player_entry_coins := 0
var test_enemy_grid := Vector2i(1, GRID_COUNT - 1)
var test_enemy_alive := true
var test_enemy_coins := 1
var test_enemy_entry_coins := 1
var test_mover_grid := Vector2i(3, GRID_COUNT - 1)
var test_mover_alive := false
var test_mover_coins := 2
var test_mover_entry_coins := 2
var test_bags: Array[BagState] = []
var test_tiles: Array[TileState] = []
var test_portal_pairs: Array[PortalPairState] = []
var pending_target := Vector2i.ZERO
var has_pending_target := false
var is_executing := false
var turn_start_time := 0.0
var timer_font: Font
var current_test_scenario := TEST_SCENARIO_STAYER

var game_state: GameState
var turn_resolver := TurnResolver.new()
var turn_presentation := TurnPresentation.new()
var current_player_intent: ActionIntent
var last_turn_result: TurnResult
var last_playback_events: Array[PlaybackEvent] = []

@onready var timer: Timer = $Timer


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)
	timer.timeout.connect(_on_timer_timeout)
	timer.wait_time = TURN_INTERVAL
	timer.stop()
	timer.start()
	turn_start_time = Time.get_ticks_msec() / 1000.0
	timer_font = ThemeDB.fallback_font
	set_process(true)
	queue_redraw()
	_initialize_runtime_state()


func _process(_delta: float) -> void:
	queue_redraw()


func _input(event: InputEvent) -> void:
	if is_executing:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var clicked_grid := _screen_to_grid(event.position)
			var clicked_bag_id := _get_clicked_bag_id(event.position)
			var clicked_any_bag := _is_clicking_any_bag(event.position)
			if clicked_bag_id != -1:
				has_pending_target = false
				pending_target = player_grid
				_set_current_intent_pick(clicked_bag_id)
			elif clicked_any_bag:
				has_pending_target = false
				pending_target = player_grid
				_set_current_intent_stay()
			elif _is_valid_move_target(player_grid, clicked_grid):
				pending_target = clicked_grid
				has_pending_target = true
				_set_current_intent_move(clicked_grid)
			else:
				has_pending_target = false
				pending_target = player_grid
				_set_current_intent_stay()
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var clicked_grid := _screen_to_grid(event.position)
			if _is_inside_grid(clicked_grid):
				has_pending_target = false
				pending_target = player_grid
				_set_current_intent_throw(clicked_grid)
				queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_set_test_scenario(TEST_SCENARIO_STAYER)
			KEY_2:
				_set_test_scenario(TEST_SCENARIO_MOVER)
			KEY_3:
				_set_test_scenario(TEST_SCENARIO_THREE_WAY)
			KEY_4:
				_set_test_scenario(TEST_SCENARIO_SWAP)
			KEY_5:
				_set_test_scenario(TEST_SCENARIO_TIE)
			KEY_6:
				_set_test_scenario(TEST_SCENARIO_PICK)
			KEY_7:
				_set_test_scenario(TEST_SCENARIO_PICK_EMPTY)
			KEY_8:
				_set_test_scenario(TEST_SCENARIO_PICK_MULTI)
			KEY_9:
				_set_test_scenario(TEST_SCENARIO_PICK_REMOTE)
			KEY_0:
				_set_test_scenario(TEST_SCENARIO_PICK_CONFLICT)
			KEY_T:
				_set_test_scenario(TEST_SCENARIO_THROW)
			KEY_Y:
				_set_test_scenario(TEST_SCENARIO_THROW_LOW_COIN)
			KEY_U:
				_set_test_scenario(TEST_SCENARIO_THROW_TWO_COINS)
			KEY_I:
				_set_test_scenario(TEST_SCENARIO_THROW_CONFLICT)
			KEY_O:
				_set_test_scenario(TEST_SCENARIO_THROW_KNOCKBACK)
			KEY_P:
				_set_test_scenario(TEST_SCENARIO_THROW_CONFLICT2)
			KEY_G:
				_set_test_scenario(TEST_SCENARIO_THROW_MULTI_HIT)
			KEY_H:
				_set_test_scenario(TEST_SCENARIO_PORTAL_BASIC)
			KEY_J:
				_set_test_scenario(TEST_SCENARIO_PORTAL_CONFLICT)
			KEY_K:
				_set_test_scenario(TEST_SCENARIO_EXIT_BASIC)
			KEY_L:
				_set_test_scenario(TEST_SCENARIO_EXIT_CONFLICT)
			KEY_Q:
				_set_test_scenario(TEST_SCENARIO_EXIT_QUEUED)
			KEY_W:
				_set_test_scenario(TEST_SCENARIO_PORTAL_BAG)
			KEY_E:
				_set_test_scenario(TEST_SCENARIO_EXIT_BAG)
			KEY_R:
				_set_test_scenario(TEST_SCENARIO_EXIT_UNIT_BAG)


func _draw() -> void:
	var grid_pixel_size := Vector2(CELL_SIZE * GRID_COUNT, CELL_SIZE * GRID_COUNT)
	var grid_origin := (get_viewport_rect().size - grid_pixel_size) * 0.5

	for y in GRID_COUNT:
		for x in GRID_COUNT:
			var cell_position := grid_origin + Vector2(x * CELL_SIZE, y * CELL_SIZE)
			draw_rect(
				Rect2(cell_position, Vector2.ONE * CELL_SIZE),
				GRID_COLOR,
				false,
				LINE_WIDTH
			)

	for tile in test_tiles:
		if tile.tile_type == TileType.PORTAL:
			_draw_portal_tile(tile)
		elif tile.tile_type == TileType.EXIT_PORTAL:
			_draw_exit_portal_tile(tile)

	if player_alive:
		var player_center := _grid_to_screen_center(player_grid)
		draw_arc(player_center, CELL_SIZE * 0.14, 0.0, TAU, 48, PLAYER_COLOR, PLAYER_RING_WIDTH)
		_draw_unit_overlay(1, player_center, PLAYER_COLOR)

		if is_executing:
			_draw_alert_mark(player_center)

	if test_enemy_alive:
		var enemy_center := _grid_to_screen_center(test_enemy_grid)
		draw_arc(enemy_center, CELL_SIZE * 0.14, 0.0, TAU, 48, TEST_ENEMY_COLOR, PLAYER_RING_WIDTH)
		_draw_unit_overlay(2, enemy_center, TEST_ENEMY_COLOR)

	if test_mover_alive:
		var mover_center := _grid_to_screen_center(test_mover_grid)
		draw_arc(mover_center, CELL_SIZE * 0.14, 0.0, TAU, 48, TEST_MOVER_COLOR, PLAYER_RING_WIDTH)
		_draw_unit_overlay(3, mover_center, TEST_MOVER_COLOR)

	for bag in test_bags:
		_draw_bag(bag)

	_draw_timer_text()
	_draw_debug_panel()


func _on_timer_timeout() -> void:
	is_executing = true
	queue_redraw()

	await get_tree().create_timer(EXECUTE_DURATION).timeout

	_sync_game_state_from_legacy()
	var intents: Array[ActionIntent] = []
	intents.append(_build_player_intent_from_legacy())
	intents.append(_build_test_enemy_intent())
	if test_mover_alive:
		intents.append(_build_test_mover_intent())
	last_turn_result = turn_resolver.resolve_turn(game_state, intents)
	last_playback_events = turn_presentation.build_events(last_turn_result)
	_apply_turn_result_to_legacy()

	has_pending_target = false
	_set_current_intent_stay()
	is_executing = false
	turn_start_time = Time.get_ticks_msec() / 1000.0
	timer.start()
	queue_redraw()


func _grid_to_screen_center(grid: Vector2i) -> Vector2:
	var grid_pixel_size := Vector2(CELL_SIZE * GRID_COUNT, CELL_SIZE * GRID_COUNT)
	var grid_origin := (get_viewport_rect().size - grid_pixel_size) * 0.5
	return grid_origin + (Vector2(grid) + Vector2.ONE * 0.5) * CELL_SIZE


func _screen_to_grid(screen_position: Vector2) -> Vector2i:
	var grid_pixel_size := Vector2(CELL_SIZE * GRID_COUNT, CELL_SIZE * GRID_COUNT)
	var grid_origin := (get_viewport_rect().size - grid_pixel_size) * 0.5
	var local_position := screen_position - grid_origin
	return Vector2i(
		int(floor(local_position.x / CELL_SIZE)),
		int(floor(local_position.y / CELL_SIZE))
	)


func _is_inside_grid(grid: Vector2i) -> bool:
	return (
		grid.x >= 0
		and grid.y >= 0
		and grid.x < GRID_COUNT
		and grid.y < GRID_COUNT
	)


func _is_adjacent_grid(from_grid: Vector2i, to_grid: Vector2i) -> bool:
	var delta_x: int = absi(to_grid.x - from_grid.x)
	var delta_y: int = absi(to_grid.y - from_grid.y)

	if delta_x == 0 and delta_y == 0:
		return false

	return delta_x <= 1 and delta_y <= 1


func _is_valid_move_target(from_grid: Vector2i, to_grid: Vector2i) -> bool:
	return _is_inside_grid(to_grid) and _is_adjacent_grid(from_grid, to_grid)


func _is_valid_throw_target(from_grid: Vector2i, to_grid: Vector2i) -> bool:
	if not _is_inside_grid(to_grid):
		return false

	var delta := to_grid - from_grid
	var abs_x := absi(delta.x)
	var abs_y := absi(delta.y)

	if abs_x == 0 and abs_y == 0:
		return false

	var max_delta := maxi(abs_x, abs_y)
	if max_delta < 1 or max_delta > 2:
		return false

	return (
		abs_x == 0
		or abs_y == 0
		or abs_x == abs_y
	)


func _draw_alert_mark(player_center: Vector2) -> void:
	var mark_top := player_center + Vector2(0, -CELL_SIZE * 0.75)
	var mark_bottom := player_center + Vector2(0, -CELL_SIZE * 0.45)
	draw_line(mark_top, mark_bottom, ALERT_COLOR, 4.0)

	var dot_center := player_center + Vector2(0, -CELL_SIZE * 0.32)
	draw_circle(dot_center, 4.0, ALERT_COLOR)


func _draw_timer_text() -> void:
	var display_text := ""
	var display_color := TIMER_IDLE_COLOR

	if is_executing:
		display_text = "%.2fs" % TURN_INTERVAL
		display_color = TIMER_EXECUTING_COLOR
	else:
		var elapsed: float = clampf(TURN_INTERVAL - timer.time_left, 0.0, TURN_INTERVAL)
		display_text = "%.2fs" % snappedf(elapsed, 0.01)
		display_color = TIMER_IDLE_COLOR

	draw_string(
		timer_font,
		Vector2(20, 40),
		display_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		28,
		display_color
	)


func _draw_debug_panel() -> void:
	var lines := []
	lines.append("Scenario: %s  Turn: %d  Phase: %s" % [
		_get_test_scenario_name(),
		game_state.turn_index if game_state != null else 0,
		"Execute" if is_executing else "Input"
	])
	lines.append("Keys: 1-0 Pick/Move, T/Y/U/I/O/P/G Throw, H/J/W Portal, K/L/Q/E/R Exit")
	lines.append("")
	lines.append("Units")
	lines.append(_format_unit_status_line(1, "P1"))
	lines.append(_format_unit_status_line(2, "E2"))
	lines.append(_format_unit_status_line(3, "E3"))
	lines.append("")
	lines.append("Portals")
	lines.append_array(_format_portal_status_lines())
	lines.append("")
	lines.append("Last Turn")

	if last_turn_result == null:
		lines.append("No turn result yet.")
	else:
		lines.append("Moved: %s" % _format_int_array(last_turn_result.moved_unit_ids))
		lines.append("Picked: %s" % _format_record_list(last_turn_result.picked_bag_records))
		lines.append("Thrown: %s" % _format_throw_records(last_turn_result.thrown_bag_records))
		lines.append("Dropped: %s" % _format_drop_records(last_turn_result.dropped_bag_records))
		lines.append("Conflict1: survivors=%s defeated=%s" % [
			_format_int_array(last_turn_result.conflict1_survivor_unit_ids),
			_format_int_array(last_turn_result.conflict1_defeated_unit_ids)
		])
		lines.append("Knockback: %s" % _format_knockback_records(last_turn_result.knocked_back_records))
		lines.append("PortalReady: %s" % _format_portal_records(last_turn_result.portal_ready_records))
		lines.append("Teleported: %s" % _format_portal_records(last_turn_result.teleport_records))
		lines.append("ExitReady: %s" % _format_exit_records(last_turn_result.exit_ready_records))
		lines.append("Exited: %s" % _format_exit_records(last_turn_result.exit_records))
		lines.append("ExitRefresh: %s" % _format_exit_refresh_records(last_turn_result.exit_refresh_records))
		lines.append("OverheatedPairs: %s" % _format_int_array(last_turn_result.overheated_portal_pair_ids))
		lines.append("Conflict2: survivors=%s defeated=%s" % [
			_format_int_array(last_turn_result.conflict2_survivor_unit_ids),
			_format_int_array(last_turn_result.conflict2_defeated_unit_ids)
		])
		lines.append("ForcedStay next turn: %s" % _format_int_array(last_turn_result.forced_stay_unit_ids))
		lines.append("Dead: %s" % _format_int_array(last_turn_result.dead_unit_ids))

	var start_pos := Vector2(20, 80)
	var line_index := 0
	for line in lines:
		if line == "":
			line_index += 1
			continue
		draw_string(
			timer_font,
			start_pos + Vector2(0, line_index * DEBUG_LINE_HEIGHT),
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			DEBUG_TEXT_SIZE,
			Color(0.92, 0.92, 0.92)
		)
		line_index += 1


func _draw_unit_overlay(unit_id: int, center: Vector2, color: Color) -> void:
	var unit := _get_runtime_unit(unit_id)
	if unit == null:
		return

	if unit.forced_stay_turns > 0:
		draw_string(
			timer_font,
			center + Vector2(-CELL_SIZE * 0.16, -CELL_SIZE * 0.22),
			"FS%d" % unit.forced_stay_turns,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			color
		)

	if last_turn_result != null:
		for record in last_turn_result.knocked_back_records:
			if int(record.get("unit_id", -1)) != unit_id:
				continue
			draw_string(
				timer_font,
				center + Vector2(-CELL_SIZE * 0.18, -CELL_SIZE * 0.36),
				"KB",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				14,
				ALERT_COLOR
			)
			return


func _initialize_runtime_state() -> void:
	game_state = GameState.new()
	current_player_intent = ActionIntent.new()
	current_player_intent.actor_id = 1
	_set_test_scenario(TEST_SCENARIO_STAYER)
	_sync_game_state_from_legacy()
	_set_current_intent_stay()


func _sync_game_state_from_legacy() -> void:
	if game_state == null:
		game_state = GameState.new()

	game_state.board_size = Vector2i(GRID_COUNT, GRID_COUNT)

	var player_unit: UnitState = game_state.get_unit_by_id(1)
	if player_unit == null:
		player_unit = UnitState.new()
		player_unit.id = 1
		game_state.units.append(player_unit)

	player_unit.prev_pos = player_unit.pos
	player_unit.pos = player_grid
	player_unit.entry_coins = player_entry_coins
	player_unit.coins = player_coins
	player_unit.alive = player_alive

	var test_enemy_unit: UnitState = game_state.get_unit_by_id(2)
	if test_enemy_unit == null:
		test_enemy_unit = UnitState.new()
		test_enemy_unit.id = 2
		game_state.units.append(test_enemy_unit)

	test_enemy_unit.prev_pos = test_enemy_unit.pos
	test_enemy_unit.pos = test_enemy_grid
	test_enemy_unit.entry_coins = test_enemy_entry_coins
	test_enemy_unit.coins = test_enemy_coins
	test_enemy_unit.alive = test_enemy_alive

	var test_mover_unit: UnitState = game_state.get_unit_by_id(3)
	if test_mover_unit == null:
		test_mover_unit = UnitState.new()
		test_mover_unit.id = 3
		game_state.units.append(test_mover_unit)

	test_mover_unit.prev_pos = test_mover_unit.pos
	test_mover_unit.pos = test_mover_grid
	test_mover_unit.entry_coins = test_mover_entry_coins
	test_mover_unit.coins = test_mover_coins
	test_mover_unit.alive = test_mover_alive

	game_state.bags.clear()
	for test_bag in test_bags:
		game_state.bags.append(test_bag.duplicate_state())
	game_state.tiles.clear()
	for test_tile in test_tiles:
		game_state.tiles.append(test_tile.duplicate_state())
	game_state.exit_portal_tile = Vector2i.ZERO
	for test_tile in test_tiles:
		if test_tile.tile_type == TileType.EXIT_PORTAL:
			game_state.exit_portal_tile = test_tile.pos
			break
	game_state.portal_pairs.clear()
	for pair in test_portal_pairs:
		game_state.portal_pairs.append(pair.duplicate_state())


func _apply_turn_result_to_legacy() -> void:
	if last_turn_result == null:
		return

	if last_turn_result.state_after == null:
		return

	var player_unit := last_turn_result.state_after.get_unit_by_id(1)
	if player_unit != null:
		player_grid = player_unit.pos
		player_alive = player_unit.alive
		player_coins = player_unit.coins

	var test_enemy_unit := last_turn_result.state_after.get_unit_by_id(2)
	if test_enemy_unit != null:
		test_enemy_grid = test_enemy_unit.pos
		test_enemy_alive = test_enemy_unit.alive
		test_enemy_coins = test_enemy_unit.coins
		test_enemy_entry_coins = test_enemy_unit.entry_coins

	var test_mover_unit := last_turn_result.state_after.get_unit_by_id(3)
	if test_mover_unit != null:
		test_mover_grid = test_mover_unit.pos
		test_mover_alive = test_mover_unit.alive
		test_mover_coins = test_mover_unit.coins
		test_mover_entry_coins = test_mover_unit.entry_coins

	test_bags.clear()
	for bag in last_turn_result.state_after.bags:
		test_bags.append(bag.duplicate_state())
	test_tiles.clear()
	for tile in last_turn_result.state_after.tiles:
		test_tiles.append(tile.duplicate_state())
	test_portal_pairs.clear()
	for pair in last_turn_result.state_after.portal_pairs:
		test_portal_pairs.append(pair.duplicate_state())

	game_state = last_turn_result.state_after


func _set_current_intent_move(target: Vector2i) -> void:
	if current_player_intent == null:
		current_player_intent = ActionIntent.new()
		current_player_intent.actor_id = 1

	current_player_intent.type = ActionType.MOVE
	current_player_intent.target_pos = target
	current_player_intent.target_bag_id = -1
	current_player_intent.throw_amount = 0


func _set_current_intent_stay() -> void:
	if current_player_intent == null:
		current_player_intent = ActionIntent.new()
		current_player_intent.actor_id = 1

	current_player_intent.type = ActionType.STAY
	current_player_intent.target_pos = player_grid
	current_player_intent.target_bag_id = -1
	current_player_intent.throw_amount = 0


func _set_current_intent_pick(bag_id: int) -> void:
	if current_player_intent == null:
		current_player_intent = ActionIntent.new()
		current_player_intent.actor_id = 1

	if not _is_valid_pick_target(bag_id):
		_set_current_intent_stay()
		return

	current_player_intent.type = ActionType.PICK
	current_player_intent.target_pos = player_grid
	current_player_intent.target_bag_id = bag_id
	current_player_intent.throw_amount = 0


func _set_current_intent_throw(target: Vector2i) -> void:
	if current_player_intent == null:
		current_player_intent = ActionIntent.new()
		current_player_intent.actor_id = 1

	var throw_amount := _get_throw_amount(player_coins)
	if throw_amount <= 0 or not _is_valid_throw_target(player_grid, target):
		_set_current_intent_stay()
		return

	current_player_intent.type = ActionType.THROW
	current_player_intent.target_pos = target
	current_player_intent.target_bag_id = -1
	current_player_intent.throw_amount = throw_amount


func _build_player_intent_from_legacy() -> ActionIntent:
	if current_player_intent == null:
		_set_current_intent_stay()

	var intent := ActionIntent.new()
	intent.actor_id = current_player_intent.actor_id
	intent.type = current_player_intent.type
	intent.target_pos = current_player_intent.target_pos
	intent.target_bag_id = current_player_intent.target_bag_id
	intent.throw_amount = current_player_intent.throw_amount

	if current_player_intent.type == ActionType.PICK or current_player_intent.type == ActionType.THROW:
		return intent

	if not has_pending_target:
		intent.type = ActionType.STAY
		intent.target_pos = player_grid

	return intent


func _build_test_enemy_intent() -> ActionIntent:
	var intent := ActionIntent.new()
	intent.actor_id = 2
	intent.type = ActionType.STAY
	intent.target_pos = test_enemy_grid
	intent.target_bag_id = -1
	intent.throw_amount = 0

	if current_test_scenario == TEST_SCENARIO_THROW_CONFLICT2:
		intent.type = ActionType.MOVE
		intent.target_pos = Vector2i(1, GRID_COUNT - 1)
	elif current_test_scenario == TEST_SCENARIO_THROW_MULTI_HIT:
		intent.type = ActionType.THROW
		intent.target_pos = Vector2i(2, GRID_COUNT - 1)
		intent.throw_amount = _get_throw_amount(test_enemy_coins)
	elif current_test_scenario == TEST_SCENARIO_PORTAL_CONFLICT:
		intent.type = ActionType.STAY
		intent.target_pos = test_enemy_grid

	return intent


func _build_test_mover_intent() -> ActionIntent:
	var intent := ActionIntent.new()
	intent.actor_id = 3
	intent.type = ActionType.STAY
	intent.target_pos = test_mover_grid
	intent.target_bag_id = -1
	intent.throw_amount = 0

	match current_test_scenario:
		TEST_SCENARIO_MOVER:
			intent.type = ActionType.MOVE
			intent.target_pos = Vector2i(2, GRID_COUNT - 1)
		TEST_SCENARIO_THREE_WAY:
			intent.type = ActionType.MOVE
			intent.target_pos = Vector2i(1, GRID_COUNT - 1)
		TEST_SCENARIO_SWAP:
			intent.type = ActionType.MOVE
			intent.target_pos = Vector2i(0, GRID_COUNT - 1)
		TEST_SCENARIO_TIE:
			intent.type = ActionType.MOVE
			intent.target_pos = Vector2i(1, GRID_COUNT - 1)
		TEST_SCENARIO_PICK_CONFLICT:
			intent.type = ActionType.MOVE
			intent.target_pos = Vector2i(0, GRID_COUNT - 1)
		TEST_SCENARIO_THROW_CONFLICT:
			intent.type = ActionType.MOVE
			intent.target_pos = Vector2i(0, GRID_COUNT - 1)
		TEST_SCENARIO_THROW_KNOCKBACK:
			intent.type = ActionType.MOVE
			intent.target_pos = Vector2i(1, GRID_COUNT - 1)
		TEST_SCENARIO_THROW_CONFLICT2:
			intent.type = ActionType.MOVE
			intent.target_pos = Vector2i(2, GRID_COUNT - 1)
		TEST_SCENARIO_THROW_MULTI_HIT:
			intent.type = ActionType.MOVE
			intent.target_pos = Vector2i(2, GRID_COUNT - 1)

	return intent


func _get_test_scenario_name() -> String:
	match current_test_scenario:
		TEST_SCENARIO_STAYER:
			return "Stayer"
		TEST_SCENARIO_MOVER:
			return "Mover"
		TEST_SCENARIO_THREE_WAY:
			return "ThreeWay"
		TEST_SCENARIO_SWAP:
			return "Swap"
		TEST_SCENARIO_TIE:
			return "Tie"
		TEST_SCENARIO_PICK:
			return "Pick"
		TEST_SCENARIO_PICK_EMPTY:
			return "PickEmpty"
		TEST_SCENARIO_PICK_MULTI:
			return "PickMulti"
		TEST_SCENARIO_PICK_REMOTE:
			return "PickRemote"
		TEST_SCENARIO_PICK_CONFLICT:
			return "PickConflict"
		TEST_SCENARIO_THROW:
			return "Throw"
		TEST_SCENARIO_THROW_LOW_COIN:
			return "ThrowLowCoin"
		TEST_SCENARIO_THROW_TWO_COINS:
			return "ThrowTwoCoins"
		TEST_SCENARIO_THROW_CONFLICT:
			return "ThrowConflict"
		TEST_SCENARIO_THROW_KNOCKBACK:
			return "ThrowKnockback"
		TEST_SCENARIO_THROW_CONFLICT2:
			return "ThrowConflict2"
		TEST_SCENARIO_THROW_MULTI_HIT:
			return "ThrowMultiHit"
		TEST_SCENARIO_PORTAL_BASIC:
			return "PortalBasic"
		TEST_SCENARIO_PORTAL_CONFLICT:
			return "PortalConflict"
		TEST_SCENARIO_EXIT_BASIC:
			return "ExitBasic"
		TEST_SCENARIO_EXIT_CONFLICT:
			return "ExitConflict"
		TEST_SCENARIO_EXIT_QUEUED:
			return "ExitQueued"
		TEST_SCENARIO_PORTAL_BAG:
			return "PortalBag"
		TEST_SCENARIO_EXIT_BAG:
			return "ExitBag"
		TEST_SCENARIO_EXIT_UNIT_BAG:
			return "ExitUnitBag"
	return "Unknown"


func _format_int_array(values: Array[int]) -> String:
	if values.is_empty():
		return "[]"
	return str(values)


func _format_vec2i(pos: Vector2i) -> String:
	return "(%d,%d)" % [pos.x, pos.y]


func _format_record_list(records: Array[Dictionary]) -> String:
	if records.is_empty():
		return "[]"
	return str(records)


func _format_throw_records(records: Array[Dictionary]) -> String:
	if records.is_empty():
		return "[]"

	var parts: Array[String] = []
	for record in records:
		var unit_id := int(record.get("unit_id", -1))
		var coins := int(record.get("coins", 0))
		var from_pos: Vector2i = record.get("from", Vector2i.ZERO)
		var to_pos: Vector2i = record.get("to", Vector2i.ZERO)
		parts.append("U%d %s->%s $%d" % [unit_id, _format_vec2i(from_pos), _format_vec2i(to_pos), coins])
	return "[" + ", ".join(parts) + "]"


func _format_drop_records(records: Array[Dictionary]) -> String:
	if records.is_empty():
		return "[]"

	var parts: Array[String] = []
	for record in records:
		var unit_id := int(record.get("unit_id", -1))
		var coins := int(record.get("coins", 0))
		var pos: Vector2i = record.get("pos", Vector2i.ZERO)
		parts.append("U%d -> %s $%d" % [unit_id, _format_vec2i(pos), coins])
	return "[" + ", ".join(parts) + "]"


func _format_knockback_records(records: Array[Dictionary]) -> String:
	if records.is_empty():
		return "[]"

	var parts: Array[String] = []
	for record in records:
		var unit_id := int(record.get("unit_id", -1))
		var from_pos: Vector2i = record.get("from", Vector2i.ZERO)
		var to_pos: Vector2i = record.get("to", Vector2i.ZERO)
		parts.append("U%d %s->%s" % [unit_id, _format_vec2i(from_pos), _format_vec2i(to_pos)])
	return "[" + ", ".join(parts) + "]"


func _format_portal_records(records: Array[Dictionary]) -> String:
	if records.is_empty():
		return "[]"

	var parts: Array[String] = []
	for record in records:
		var pair_id := int(record.get("pair_id", -1))
		var from_pos: Vector2i = record.get("from", Vector2i.ZERO)
		var to_pos: Vector2i = record.get("to", Vector2i.ZERO)
		if record.has("unit_id"):
			var unit_id := int(record.get("unit_id", -1))
			parts.append("U%d P%d %s->%s" % [unit_id, pair_id, _format_vec2i(from_pos), _format_vec2i(to_pos)])
		else:
			var bag_id := int(record.get("bag_id", -1))
			var coins := int(record.get("coins", 0))
			parts.append("B%d P%d %s->%s $%d" % [bag_id, pair_id, _format_vec2i(from_pos), _format_vec2i(to_pos), coins])
	return "[" + ", ".join(parts) + "]"


func _format_exit_records(records: Array[Dictionary]) -> String:
	if records.is_empty():
		return "[]"

	var parts: Array[String] = []
	for record in records:
		var from_pos: Vector2i = record.get("from", Vector2i.ZERO)
		if record.has("unit_id"):
			var unit_id := int(record.get("unit_id", -1))
			if record.has("coins"):
				var coins := int(record.get("coins", 0))
				parts.append("U%d %s $%d" % [unit_id, _format_vec2i(from_pos), coins])
			else:
				parts.append("U%d %s" % [unit_id, _format_vec2i(from_pos)])
		else:
			var bag_id := int(record.get("bag_id", -1))
			var coins := int(record.get("coins", 0))
			parts.append("B%d %s $%d" % [bag_id, _format_vec2i(from_pos), coins])
	return "[" + ", ".join(parts) + "]"


func _format_exit_refresh_records(records: Array[Dictionary]) -> String:
	if records.is_empty():
		return "[]"

	var parts: Array[String] = []
	for record in records:
		var from_pos: Vector2i = record.get("from", Vector2i.ZERO)
		var to_pos: Vector2i = record.get("to", Vector2i.ZERO)
		parts.append("%s->%s" % [_format_vec2i(from_pos), _format_vec2i(to_pos)])
	return "[" + ", ".join(parts) + "]"


func _format_unit_status_line(unit_id: int, label: String) -> String:
	var unit := _get_runtime_unit(unit_id)
	if unit == null:
		return "%s: <none>" % label

	var intent := _get_runtime_intent(unit_id)
	var intent_text := _format_intent_summary(intent)
	var queued_text := "-"
	if unit.has_queued_teleport:
		queued_text = _format_vec2i(unit.queued_teleport_to)
	return "%s pos=%s coins=%d entry=%d alive=%s won=%s fs=%d qtp=%s qex=%s tp=%s intent=%s" % [
		label,
		_format_vec2i(unit.pos),
		unit.coins,
		unit.entry_coins,
		"Y" if unit.alive else "N",
		"Y" if unit.won else "N",
		unit.forced_stay_turns,
		queued_text,
		"Y" if unit.queued_exit else "N",
		"Y" if unit.teleported_this_turn else "N",
		intent_text
	]


func _format_portal_status_lines() -> Array[String]:
	if test_portal_pairs.is_empty():
		return ["<none>"]

	var lines: Array[String] = []
	for pair in test_portal_pairs:
		lines.append("P%d %s<->%s cd=%d hot=%s" % [
			pair.id,
			_format_vec2i(pair.entry_a),
			_format_vec2i(pair.entry_b),
			pair.cooldown_turns,
			"Y" if pair.is_overheated else "N"
		])
	return lines


func _get_runtime_unit(unit_id: int) -> UnitState:
	if game_state == null:
		return null
	return game_state.get_unit_by_id(unit_id)


func _get_runtime_intent(unit_id: int) -> ActionIntent:
	match unit_id:
		1:
			return _build_player_intent_from_legacy()
		2:
			if not test_enemy_alive:
				return null
			return _build_test_enemy_intent()
		3:
			if not test_mover_alive:
				return null
			return _build_test_mover_intent()
	return null


func _format_intent_summary(intent: ActionIntent) -> String:
	if intent == null:
		return "null"

	match intent.type:
		ActionType.MOVE:
			return "MOVE%s" % _format_vec2i(intent.target_pos)
		ActionType.PICK:
			return "PICK bag=%d" % intent.target_bag_id
		ActionType.THROW:
			return "THROW%s $%d" % [_format_vec2i(intent.target_pos), intent.throw_amount]
		ActionType.STAY:
			return "STAY"

	return String(intent.type)


func _set_test_scenario(scenario_id: int) -> void:
	current_test_scenario = scenario_id
	game_state = GameState.new()
	has_pending_target = false
	pending_target = player_grid
	player_alive = true
	player_coins = 0
	player_entry_coins = 0
	test_enemy_alive = true
	test_enemy_coins = 1
	test_enemy_entry_coins = 1
	test_mover_alive = false
	test_mover_coins = 2
	test_mover_entry_coins = 2
	test_bags.clear()
	test_tiles.clear()
	test_portal_pairs.clear()

	match scenario_id:
		TEST_SCENARIO_STAYER:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			test_enemy_grid = Vector2i(1, GRID_COUNT - 1)
			test_mover_grid = Vector2i(3, GRID_COUNT - 1)
		TEST_SCENARIO_MOVER:
			player_grid = Vector2i(1, GRID_COUNT - 2)
			test_enemy_grid = Vector2i(4, GRID_COUNT - 1)
			test_mover_grid = Vector2i(3, GRID_COUNT - 1)
			test_mover_alive = true
		TEST_SCENARIO_THREE_WAY:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			test_enemy_grid = Vector2i(1, GRID_COUNT - 1)
			test_mover_grid = Vector2i(2, GRID_COUNT - 1)
			test_mover_alive = true
		TEST_SCENARIO_SWAP:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			test_enemy_grid = Vector2i(4, GRID_COUNT - 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(1, GRID_COUNT - 1)
			test_mover_alive = true
		TEST_SCENARIO_TIE:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			player_coins = 1
			player_entry_coins = 1
			test_enemy_grid = Vector2i(4, GRID_COUNT - 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(2, GRID_COUNT - 1)
			test_mover_alive = true
			test_mover_coins = 1
			test_mover_entry_coins = 1
		TEST_SCENARIO_PICK:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			test_enemy_grid = Vector2i(4, GRID_COUNT - 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(4, GRID_COUNT - 2)
			test_mover_alive = false
			_add_test_bag(1001, player_grid, 3)
		TEST_SCENARIO_PICK_EMPTY:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			test_enemy_grid = Vector2i(4, GRID_COUNT - 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(4, GRID_COUNT - 2)
			test_mover_alive = false
		TEST_SCENARIO_PICK_MULTI:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			test_enemy_grid = Vector2i(4, GRID_COUNT - 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(4, GRID_COUNT - 2)
			test_mover_alive = false
			_add_test_bag(1001, player_grid, 1)
			_add_test_bag(1002, player_grid, 3)
			_add_test_bag(1003, player_grid, 5)
		TEST_SCENARIO_PICK_REMOTE:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			test_enemy_grid = Vector2i(4, GRID_COUNT - 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(4, GRID_COUNT - 2)
			test_mover_alive = false
			_add_test_bag(1001, Vector2i(1, GRID_COUNT - 1), 3)
		TEST_SCENARIO_PICK_CONFLICT:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			test_enemy_grid = Vector2i(4, GRID_COUNT - 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(1, GRID_COUNT - 1)
			test_mover_alive = true
			test_mover_coins = 1
			test_mover_entry_coins = 1
			_add_test_bag(1001, player_grid, 3)
		TEST_SCENARIO_THROW:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			player_coins = 5
			player_entry_coins = 5
			test_enemy_grid = Vector2i(4, GRID_COUNT - 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(4, GRID_COUNT - 2)
			test_mover_alive = false
		TEST_SCENARIO_THROW_LOW_COIN:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			player_coins = 1
			player_entry_coins = 1
			test_enemy_grid = Vector2i(4, GRID_COUNT - 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(4, GRID_COUNT - 2)
			test_mover_alive = false
		TEST_SCENARIO_THROW_TWO_COINS:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			player_coins = 2
			player_entry_coins = 2
			test_enemy_grid = Vector2i(4, GRID_COUNT - 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(4, GRID_COUNT - 2)
			test_mover_alive = false
		TEST_SCENARIO_THROW_CONFLICT:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			player_coins = 5
			player_entry_coins = 5
			test_enemy_grid = Vector2i(4, GRID_COUNT - 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(1, GRID_COUNT - 1)
			test_mover_alive = true
			test_mover_coins = 1
			test_mover_entry_coins = 1
		TEST_SCENARIO_THROW_KNOCKBACK:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			player_coins = 5
			player_entry_coins = 5
			test_enemy_grid = Vector2i(4, GRID_COUNT - 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(2, GRID_COUNT - 1)
			test_mover_alive = true
			test_mover_coins = 1
			test_mover_entry_coins = 1
		TEST_SCENARIO_THROW_CONFLICT2:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			player_coins = 5
			player_entry_coins = 5
			test_enemy_grid = Vector2i(2, GRID_COUNT - 1)
			test_enemy_alive = true
			test_enemy_coins = 0
			test_enemy_entry_coins = 0
			test_mover_grid = Vector2i(1, GRID_COUNT - 1)
			test_mover_alive = true
			test_mover_coins = 1
			test_mover_entry_coins = 1
		TEST_SCENARIO_THROW_MULTI_HIT:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			player_coins = 5
			player_entry_coins = 5
			test_enemy_grid = Vector2i(2, GRID_COUNT - 3)
			test_enemy_alive = true
			test_enemy_coins = 5
			test_enemy_entry_coins = 5
			test_mover_grid = Vector2i(1, GRID_COUNT - 1)
			test_mover_alive = true
			test_mover_coins = 1
			test_mover_entry_coins = 1
		TEST_SCENARIO_PORTAL_BASIC:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			test_enemy_grid = Vector2i(5, 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(5, 2)
			test_mover_alive = false
			_add_test_portal_pair(1, Vector2i(1, GRID_COUNT - 1), Vector2i(5, 2), 0)
		TEST_SCENARIO_PORTAL_CONFLICT:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			test_enemy_grid = Vector2i(5, 2)
			test_enemy_alive = true
			test_enemy_coins = 0
			test_enemy_entry_coins = 0
			test_mover_grid = Vector2i(5, 1)
			test_mover_alive = false
			_add_test_portal_pair(1, Vector2i(1, GRID_COUNT - 1), Vector2i(5, 2), 0)
		TEST_SCENARIO_EXIT_BASIC:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			test_enemy_grid = Vector2i(5, 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(5, 2)
			test_mover_alive = false
			_add_test_exit_portal(Vector2i(1, GRID_COUNT - 1))
		TEST_SCENARIO_EXIT_CONFLICT:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			test_enemy_grid = Vector2i(1, GRID_COUNT - 1)
			test_enemy_alive = true
			test_enemy_coins = 0
			test_enemy_entry_coins = 0
			test_mover_grid = Vector2i(5, 2)
			test_mover_alive = false
			_add_test_exit_portal(Vector2i(1, GRID_COUNT - 1))
		TEST_SCENARIO_EXIT_QUEUED:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			test_enemy_grid = Vector2i(1, GRID_COUNT - 1)
			test_enemy_alive = true
			test_enemy_coins = 0
			test_enemy_entry_coins = 0
			test_mover_grid = Vector2i(5, 2)
			test_mover_alive = false
			_add_test_exit_portal(Vector2i(1, GRID_COUNT - 1))
		TEST_SCENARIO_PORTAL_BAG:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			player_coins = 5
			player_entry_coins = 5
			test_enemy_grid = Vector2i(5, 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(5, 2)
			test_mover_alive = false
			_add_test_portal_pair(1, Vector2i(1, GRID_COUNT - 1), Vector2i(5, 2), 0)
		TEST_SCENARIO_EXIT_BAG:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			player_coins = 5
			player_entry_coins = 5
			test_enemy_grid = Vector2i(5, 1)
			test_enemy_alive = false
			test_mover_grid = Vector2i(5, 2)
			test_mover_alive = false
			_add_test_exit_portal(Vector2i(1, GRID_COUNT - 1))
		TEST_SCENARIO_EXIT_UNIT_BAG:
			player_grid = Vector2i(0, GRID_COUNT - 1)
			player_coins = 5
			player_entry_coins = 5
			test_enemy_grid = Vector2i(1, GRID_COUNT - 1)
			test_enemy_alive = true
			test_enemy_coins = 0
			test_enemy_entry_coins = 0
			test_mover_grid = Vector2i(5, 2)
			test_mover_alive = false
			_add_test_exit_portal(Vector2i(1, GRID_COUNT - 1))

	_set_current_intent_stay()
	if game_state != null:
		_sync_game_state_from_legacy()
		if scenario_id == TEST_SCENARIO_EXIT_QUEUED:
			var queued_enemy := game_state.get_unit_by_id(2)
			if queued_enemy != null:
				queued_enemy.queued_exit = true
	queue_redraw()


func _add_test_bag(bag_id: int, grid: Vector2i, coins: int) -> void:
	var bag := BagState.new()
	bag.id = bag_id
	bag.pos = grid
	bag.coins = coins
	test_bags.append(bag)


func _add_test_portal_pair(pair_id: int, entry_a: Vector2i, entry_b: Vector2i, color_id: int) -> void:
	var pair := PortalPairState.new()
	pair.id = pair_id
	pair.entry_a = entry_a
	pair.entry_b = entry_b
	pair.color_id = color_id
	pair.refresh_overheat_state()
	test_portal_pairs.append(pair)

	var tile_a := TileState.new()
	tile_a.pos = entry_a
	tile_a.tile_type = TileType.PORTAL
	tile_a.portal_pair_id = pair_id
	tile_a.portal_color_id = color_id
	test_tiles.append(tile_a)

	var tile_b := TileState.new()
	tile_b.pos = entry_b
	tile_b.tile_type = TileType.PORTAL
	tile_b.portal_pair_id = pair_id
	tile_b.portal_color_id = color_id
	test_tiles.append(tile_b)


func _add_test_exit_portal(pos: Vector2i) -> void:
	var tile := TileState.new()
	tile.pos = pos
	tile.tile_type = TileType.EXIT_PORTAL
	test_tiles.append(tile)


func _get_throw_amount(coins: int) -> int:
	if coins <= 1:
		return 0
	return int(floor(float(coins) / 2.0))


func _is_valid_pick_target(bag_id: int) -> bool:
	var bag := _get_test_bag_by_id(bag_id)
	return bag != null and bag.pos == player_grid


func _get_clicked_bag_id(screen_position: Vector2) -> int:
	for bag in test_bags:
		if bag.pos != player_grid:
			continue

		var center := _get_bag_draw_center(bag)
		if center.distance_to(screen_position) <= CELL_SIZE * 0.11:
			return bag.id

	return -1


func _get_test_bag_by_id(bag_id: int) -> BagState:
	for bag in test_bags:
		if bag.id == bag_id:
			return bag
	return null


func _is_clicking_any_bag(screen_position: Vector2) -> bool:
	for bag in test_bags:
		var center := _get_bag_draw_center(bag)
		if center.distance_to(screen_position) <= CELL_SIZE * 0.11:
			return true
	return false


func _draw_bag(bag: BagState) -> void:
	var center := _get_bag_draw_center(bag)
	draw_circle(center, CELL_SIZE * 0.08, Color(0.95, 0.8, 0.2))
	draw_string(
		timer_font,
		center + Vector2(CELL_SIZE * 0.1, CELL_SIZE * 0.03),
		str(bag.coins),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		Color(0.95, 0.9, 0.7)
	)

	var marker := ""
	if bag.queued_exit:
		marker = "QE"
	elif bag.has_queued_teleport:
		marker = "QT"

	if marker != "":
		draw_string(
			timer_font,
			center + Vector2(-CELL_SIZE * 0.12, -CELL_SIZE * 0.10),
			marker,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color(1.0, 0.95, 0.5)
		)


func _draw_portal_tile(tile: TileState) -> void:
	var center := _grid_to_screen_center(tile.pos)
	var pair := _get_test_portal_pair_by_id(tile.portal_pair_id)
	var color := _get_portal_color(tile.portal_color_id)
	if pair != null and pair.is_overheated:
		color = Color(0.55, 0.55, 0.55)

	draw_arc(center, CELL_SIZE * 0.22, 0.0, TAU, 48, color, 3.0)
	draw_arc(center, CELL_SIZE * 0.10, 0.0, TAU, 48, color, 2.0)

	if pair != null and pair.is_overheated:
		draw_string(
			timer_font,
			center + Vector2(-CELL_SIZE * 0.10, CELL_SIZE * 0.02),
			str(pair.cooldown_turns),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			color
		)


func _draw_exit_portal_tile(tile: TileState) -> void:
	var center := _grid_to_screen_center(tile.pos)
	var color := Color(0.95, 0.9, 0.25)
	draw_arc(center, CELL_SIZE * 0.24, 0.0, TAU, 48, color, 3.0)
	draw_arc(center, CELL_SIZE * 0.14, 0.0, TAU, 48, color, 2.0)
	draw_line(center + Vector2(-CELL_SIZE * 0.08, 0), center + Vector2(CELL_SIZE * 0.08, 0), color, 2.0)
	draw_line(center + Vector2(0, -CELL_SIZE * 0.08), center + Vector2(0, CELL_SIZE * 0.08), color, 2.0)


func _get_bag_draw_center(bag: BagState) -> Vector2:
	var same_cell_bags: Array[BagState] = []
	for candidate in test_bags:
		if candidate.pos == bag.pos:
			same_cell_bags.append(candidate)

	same_cell_bags.sort_custom(func(a: BagState, b: BagState): return a.id < b.id)

	var bag_index := 0
	for index in range(same_cell_bags.size()):
		if same_cell_bags[index].id == bag.id:
			bag_index = index
			break

	var base_center := _grid_to_screen_center(bag.pos)
	var start_x := -CELL_SIZE * 0.22
	var step_x := CELL_SIZE * 0.18
	return base_center + Vector2(start_x + bag_index * step_x, CELL_SIZE * 0.18)


func _get_test_portal_pair_by_id(pair_id: int) -> PortalPairState:
	for pair in test_portal_pairs:
		if pair.id == pair_id:
			return pair
	return null


func _get_portal_color(color_id: int) -> Color:
	match color_id:
		0:
			return Color(0.2, 0.9, 0.85)
		1:
			return Color(0.95, 0.55, 0.2)
	return Color(0.2, 0.9, 0.85)

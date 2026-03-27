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
const TEST_SCENARIO_STAYER := 0
const TEST_SCENARIO_MOVER := 1
const TEST_SCENARIO_THREE_WAY := 2
const TEST_SCENARIO_SWAP := 3
const TEST_SCENARIO_TIE := 4

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
			if _is_inside_grid(clicked_grid) and _is_adjacent_grid(player_grid, clicked_grid):
				pending_target = clicked_grid
				has_pending_target = true
				_set_current_intent_move(clicked_grid)
			else:
				has_pending_target = false
				pending_target = player_grid
				_set_current_intent_stay()
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

	if player_alive:
		var player_center := _grid_to_screen_center(player_grid)
		draw_arc(player_center, CELL_SIZE * 0.14, 0.0, TAU, 48, PLAYER_COLOR, PLAYER_RING_WIDTH)

		if is_executing:
			_draw_alert_mark(player_center)

	if test_enemy_alive:
		var enemy_center := _grid_to_screen_center(test_enemy_grid)
		draw_arc(enemy_center, CELL_SIZE * 0.14, 0.0, TAU, 48, TEST_ENEMY_COLOR, PLAYER_RING_WIDTH)

	if test_mover_alive:
		var mover_center := _grid_to_screen_center(test_mover_grid)
		draw_arc(mover_center, CELL_SIZE * 0.14, 0.0, TAU, 48, TEST_MOVER_COLOR, PLAYER_RING_WIDTH)

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
	var lines := [
		"Scenario: %s" % _get_test_scenario_name(),
		"Keys: 1=Stayer 2=Mover 3=ThreeWay 4=Swap 5=Tie"
	]

	if last_turn_result != null:
		lines.append("Moved: %s" % _format_int_array(last_turn_result.moved_unit_ids))
		lines.append("Survivors: %s" % _format_int_array(last_turn_result.conflict1_survivor_unit_ids))
		lines.append("Defeated: %s" % _format_int_array(last_turn_result.conflict1_defeated_unit_ids))
		lines.append("Dead: %s" % _format_int_array(last_turn_result.dead_unit_ids))

	var start_pos := Vector2(20, 80)
	for index in range(lines.size()):
		draw_string(
			timer_font,
			start_pos + Vector2(0, index * 24),
			lines[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20,
			Color(0.92, 0.92, 0.92)
		)


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
	player_unit.won = false

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
	test_enemy_unit.won = false

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
	test_mover_unit.won = false


func _apply_turn_result_to_legacy() -> void:
	if last_turn_result == null:
		return

	if last_turn_result.state_after == null:
		return

	var player_unit := last_turn_result.state_after.get_unit_by_id(1)
	if player_unit != null:
		player_grid = player_unit.pos
		player_alive = player_unit.alive

	var test_enemy_unit := last_turn_result.state_after.get_unit_by_id(2)
	if test_enemy_unit != null:
		test_enemy_grid = test_enemy_unit.pos
		test_enemy_alive = test_enemy_unit.alive

	var test_mover_unit := last_turn_result.state_after.get_unit_by_id(3)
	if test_mover_unit != null:
		test_mover_grid = test_mover_unit.pos
		test_mover_alive = test_mover_unit.alive

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


func _build_player_intent_from_legacy() -> ActionIntent:
	if current_player_intent == null:
		_set_current_intent_stay()

	var intent := ActionIntent.new()
	intent.actor_id = current_player_intent.actor_id
	intent.type = current_player_intent.type
	intent.target_pos = current_player_intent.target_pos
	intent.target_bag_id = current_player_intent.target_bag_id
	intent.throw_amount = current_player_intent.throw_amount

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
	return "Unknown"


func _format_int_array(values: Array[int]) -> String:
	if values.is_empty():
		return "[]"
	return str(values)


func _set_test_scenario(scenario_id: int) -> void:
	current_test_scenario = scenario_id
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

	_set_current_intent_stay()
	if game_state != null:
		_sync_game_state_from_legacy()
	queue_redraw()

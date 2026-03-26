extends Node2D

const GRID_COUNT := 7
const CELL_SIZE := 96.0
const GRID_COLOR := Color(0.85, 0.85, 0.85)
const PLAYER_COLOR := Color(0.2, 0.6, 1.0)
const ALERT_COLOR := Color(1.0, 0.9, 0.2)
const TIMER_IDLE_COLOR := Color(0.2, 0.6, 1.0)
const TIMER_EXECUTING_COLOR := Color(1.0, 0.25, 0.25)
const LINE_WIDTH := 2.0
const PLAYER_RING_WIDTH := 3.0
const TURN_INTERVAL := 5.0
const EXECUTE_DURATION := 1.0

var player_grid := Vector2i(0, GRID_COUNT - 1)
var pending_target := Vector2i.ZERO
var has_pending_target := false
var is_executing := false
var turn_start_time := 0.0
var timer_font: Font

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

	var player_center := _grid_to_screen_center(player_grid)
	draw_arc(player_center, CELL_SIZE * 0.14, 0.0, TAU, 48, PLAYER_COLOR, PLAYER_RING_WIDTH)

	if is_executing:
		_draw_alert_mark(player_center)

	_draw_timer_text()


func _on_timer_timeout() -> void:
	is_executing = true
	queue_redraw()

	await get_tree().create_timer(EXECUTE_DURATION).timeout

	_sync_game_state_from_legacy()
	var intents: Array[ActionIntent] = []
	intents.append(_build_player_intent_from_legacy())
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


func _initialize_runtime_state() -> void:
	game_state = GameState.new()
	current_player_intent = ActionIntent.new()
	current_player_intent.actor_id = 1
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
		player_unit.entry_coins = 0
		player_unit.coins = 0
		game_state.units.append(player_unit)

	player_unit.prev_pos = player_unit.pos
	player_unit.pos = player_grid
	player_unit.alive = true
	player_unit.won = false


func _apply_turn_result_to_legacy() -> void:
	if last_turn_result == null:
		return

	if last_turn_result.state_after == null:
		return

	var player_unit := last_turn_result.state_after.get_unit_by_id(1)
	if player_unit == null:
		return

	player_grid = player_unit.pos
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

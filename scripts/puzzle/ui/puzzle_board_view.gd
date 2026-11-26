class_name PuzzleBoardView
extends Control

signal cell_clicked(cell: Vector2i, button: MouseButton)

const LIGHT_TILE := Color("#253750")
const DARK_TILE := Color("#1d2c41")
const PLAYER_COLOR := Color("#74cef5")
const ENEMY_COLOR := Color("#ff967d")
const COIN_COLOR := Color("#f8cd73")

var _board: GameState
var _selection: ActionIntent
var _enemy_names: Dictionary[int, String]
var _enemy_intents: Dictionary[int, ActionIntent]


func present(
	board: GameState,
	selection: ActionIntent,
	enemy_names: Dictionary[int, String] = {},
	enemy_intents: Dictionary[int, ActionIntent] = {},
) -> void:
	_board = board
	_selection = selection
	_enemy_names = enemy_names
	_enemy_intents = enemy_intents
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _board == null or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return

	var side := _cell_size()
	if side <= 0.0:
		return
	var cell := Vector2i(((event.position - _board_origin(side)) / side).floor())
	if Rect2i(Vector2i.ZERO, _board.board_size).has_point(cell):
		cell_clicked.emit(cell, event.button_index)
		accept_event()


func _draw() -> void:
	if _board == null:
		return
	var side := _cell_size()
	if side <= 0.0:
		return
	var origin := _board_origin(side)
	for y in _board.board_size.y:
		for x in _board.board_size.x:
			var cell := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(cell) * side, Vector2.ONE * side).grow(-2.0)
			var tile_color := LIGHT_TILE if (x + y) % 2 == 0 else DARK_TILE
			if _board.trail != null:
				if not _board.trail.is_floor(cell):
					continue
				if _board.trail.has_left(cell):
					tile_color = Color("#252830")
			draw_rect(rect, tile_color)
			if _board.trail != null and cell == _board.trail.exit_cell:
				draw_rect(rect.grow(-2.0), COIN_COLOR, false, 2.0)
				_draw_label(rect.position + rect.size * Vector2(0.80, 0.17), "终", side * 0.17, COIN_COLOR)
			var coordinate_center := origin + (Vector2(cell) + Vector2(0.17, 0.16)) * side
			_draw_label(coordinate_center, _cell_name(cell), side * 0.12, Color("#a1b5cb"))
			if _selection != null and _selection.target_pos == cell:
				var color := COIN_COLOR if _selection.type == ActionType.THROW else PLAYER_COLOR
				draw_rect(rect, color, false, 3.0)

	var bags_by_cell := {}
	for bag in _board.bags:
		bags_by_cell[bag.pos] = bags_by_cell.get(bag.pos, 0) + bag.coins
	for cell in bags_by_cell:
		var center := origin + (Vector2(cell) + Vector2(0.25, 0.78)) * side
		_draw_label(center, "$%d" % bags_by_cell[cell], side * 0.13, COIN_COLOR)

	for unit in _board.units:
		if not unit.alive or unit.won:
			continue
		var center := origin + (Vector2(unit.pos) + Vector2(0.5, 0.5)) * side
		var is_player := unit.id == PuzzleLevelData.PLAYER_ID
		var color := PLAYER_COLOR if is_player else ENEMY_COLOR
		draw_circle(center, side * 0.22, color)
		_draw_label(center, str(unit.coins), side * 0.19, Color("#101d2c"))
		var name_text: String = "玩家" if is_player else _enemy_names.get(unit.id, "敌人")
		_draw_label(center + Vector2(0.0, -side * 0.30), name_text, side * 0.12, color)
		if unit.stun_turns > 0:
			_draw_label(center + Vector2(0.0, side * 0.33), "硬直", side * 0.12, COIN_COLOR)
		elif _enemy_intents.has(unit.id):
			var intent := _enemy_intents[unit.id]
			var preview := "待机"
			if intent.type == ActionType.MOVE:
				preview = "→ " + _cell_name(intent.target_pos)
			elif intent.type == ActionType.THROW:
				preview = "投 " + _cell_name(intent.target_pos)
			_draw_label(center + Vector2(0.0, side * 0.33), preview, side * 0.12, color)


func _cell_name(cell: Vector2i) -> String:
	if cell.x < 26:
		return "%s%d" % [char(65 + cell.x), cell.y + 1]
	return "(%d,%d)" % [cell.x + 1, cell.y + 1]


func _cell_size() -> float:
	return minf(176.0, minf(size.x / _board.board_size.x, size.y / _board.board_size.y))


func _board_origin(side: float) -> Vector2:
	return (size - Vector2(_board.board_size) * side) * 0.5


func _draw_label(center: Vector2, label: String, scale: float, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var font_size := maxi(8, roundi(scale))
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := font.get_ascent(font_size) - text_size.y * 0.5
	draw_string(font, center + Vector2(-text_size.x * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

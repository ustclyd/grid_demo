extends Control

@export var level: PuzzleLevelData

var _session := PuzzleSession.new()
var _selection: ActionIntent
var _enemy_names: Dictionary[int, String] = {}

@onready var _title: Label = %Title
@onready var _status: Label = %Status
@onready var _intent_label: Label = %Intent
@onready var _rules: Label = %LevelRules
@onready var _result: Label = %Result
@onready var _board_view: PuzzleBoardView = %Board
@onready var _stay_button: Button = %Stay
@onready var _submit_button: Button = %Submit
@onready var _restart_button: Button = %Restart


func _ready() -> void:
	_board_view.cell_clicked.connect(_on_cell_clicked)
	_stay_button.pressed.connect(_select_stay)
	_submit_button.pressed.connect(_submit)
	_restart_button.pressed.connect(_restart)
	_session.level_won.connect(_on_level_won)
	_session.level_lost.connect(_on_level_lost)
	_restart()


func _restart() -> void:
	_result.hide()
	_selection = null
	_enemy_names.clear()
	_rules.hide()
	if not _session.start_level(level):
		_board_view.present(null, null)
		_status.text = ""
		_intent_label.text = _session.last_error
		_submit_button.disabled = true
		_stay_button.disabled = true
		return
	_title.text = level.title
	_rules.text = level.play_hint
	_rules.visible = not level.play_hint.is_empty()
	var has_trail := not level.trail_cells.is_empty()
	_board_view.custom_minimum_size = Vector2(580, 555) if has_trail else Vector2(
		520, clampf(level.board_size.y * 130.0, 218.0, 390.0)
	)
	for index in level.enemies.size():
		_enemy_names[index + 2] = level.enemies[index].policy.get_display_name()
	_select_stay()


func _on_cell_clicked(cell: Vector2i, button: MouseButton) -> void:
	if _session.get_phase() != PuzzleSession.Phase.ACTIVE:
		return

	var board := _session.get_board_snapshot()
	var player := board.get_unit_by_id(PuzzleLevelData.PLAYER_ID)
	if cell == player.pos:
		_select_stay()
		return
	var action_type := ActionType.MOVE if button == MOUSE_BUTTON_LEFT else ActionType.THROW
	var intent := PuzzleActions.create_intent(board, player.id, action_type, cell)
	if intent == null:
		if board.trail != null and board.trail.has_left(cell) and action_type == ActionType.MOVE:
			_intent_label.text = "该格已封闭。仍保留上一次选择。"
		else:
			_intent_label.text = "该格不可执行此动作，保留上一次选择。"
		return
	_selection = intent
	_refresh()


func _select_stay() -> void:
	if _session.get_phase() != PuzzleSession.Phase.ACTIVE:
		return
	_selection = PuzzleActions.create_intent(_session.get_board_snapshot(), PuzzleLevelData.PLAYER_ID, ActionType.STAY)
	_refresh()


func _submit() -> void:
	if _selection == null:
		return
	if not _session.submit_turn(_selection.type, _selection.target_pos):
		if _session.last_error != "":
			_intent_label.text = _session.last_error
		return
	_selection = null
	if _session.get_phase() == PuzzleSession.Phase.ACTIVE:
		_select_stay()
	else:
		_refresh()


func _refresh() -> void:
	var board := _session.get_board_snapshot()
	var player := board.get_unit_by_id(PuzzleLevelData.PLAYER_ID)
	_status.text = "回合 %d    持币 %d / %d" % [board.turn_index, player.coins, _session.get_target_coins()]
	if board.trail != null:
		_status.text += "    未踏 %d" % board.trail.remaining_cells()
	var active := _session.get_phase() == PuzzleSession.Phase.ACTIVE
	_stay_button.disabled = not active
	_submit_button.disabled = not active
	if active:
		_intent_label.text = _selection_text(player)
	else:
		_intent_label.text = ""
	var enemy_intents: Dictionary[int, ActionIntent] = {}
	for unit_id in _enemy_names:
		var intent := _session.preview_enemy_intent(unit_id)
		if intent != null:
			enemy_intents[unit_id] = intent
	_board_view.present(board, _selection, _enemy_names, enemy_intents)


func _selection_text(player: UnitState) -> String:
	if player.stun_turns > 0:
		return "硬直 · 结束回合后尝试恢复"
	match _selection.type:
		ActionType.MOVE:
			return "已选择 · 移动"
		ActionType.THROW:
			return "已选择 · 投掷 %d 币" % _selection.throw_amount
		_:
			return "已选择 · 待机"


func _on_level_won(coins: int, turns: int, score: float) -> void:
	_result.text = "通关 · 净收集 %d 币 · %d 回合 · 得分 %.2f" % [coins, turns, score]
	if level.optimal_turns > 0:
		if turns == level.optimal_turns:
			_result.text += "\n达到最优回合数"
		elif turns > level.optimal_turns:
			_result.text += "\n比最优解多用 %d 回合" % (turns - level.optimal_turns)
		else:
			_result.text += "\n快于已记录的参考解"
	_result.show()


func _on_level_lost(turns: int) -> void:
	_result.text = "玩家被击败 · 用时 %d 回合" % turns
	_result.show()

class_name PuzzleSession
extends RefCounted

signal level_won(collected_coins: int, turns: int, score: float)
signal level_lost(turns: int)

enum Phase { IDLE, ACTIVE, WON, LOST }

var last_error := ""

var _phase: Phase = Phase.IDLE
var _target_coins: int

var _board: GameState
var _starting_coins: int
var _resolver := TurnResolver.new()
var _enemy_policies: Dictionary[int, PuzzleEnemyPolicy] = {}


func start_level(level: PuzzleLevelData) -> bool:
	last_error = "缺少关卡数据。" if level == null else level.validation_error()
	if last_error != "":
		return false

	_board = level.build_board()
	_starting_coins = level.player_coins
	_target_coins = 0
	for unit in _board.units:
		_target_coins += unit.coins
	for bag in _board.bags:
		_target_coins += bag.coins

	_enemy_policies.clear()
	for index in level.enemies.size():
		_enemy_policies[index + 2] = level.enemies[index].policy.duplicate(true) as PuzzleEnemyPolicy
	_phase = Phase.ACTIVE
	return true


func get_phase() -> Phase:
	return _phase


func get_target_coins() -> int:
	return _target_coins


func get_board_snapshot() -> GameState:
	return _board.duplicate_state() if _board != null else null


func fork() -> PuzzleSession:
	var branch := PuzzleSession.new()
	branch._phase = _phase
	branch._target_coins = _target_coins
	branch._starting_coins = _starting_coins
	# The resolver replaces the board with a new state, and callers only receive snapshots.
	branch._board = _board
	branch._enemy_policies = _enemy_policies.duplicate()
	return branch


func preview_enemy_intent(unit_id: int) -> ActionIntent:
	if _phase != Phase.ACTIVE or not _enemy_policies.has(unit_id):
		return null
	var unit := _board.get_unit_by_id(unit_id)
	if not unit.alive or unit.won:
		return null
	if unit.stun_turns > 0:
		return PuzzleActions.create_intent(_board, unit_id, ActionType.STAY)

	# Each policy sees an isolated copy of the same starting board.
	var proposed := _enemy_policies[unit_id].choose_intent(
		_board.duplicate_state(), unit_id, PuzzleLevelData.PLAYER_ID
	)
	if proposed == null or proposed.actor_id != unit_id:
		return null
	var checked := PuzzleActions.create_intent(_board, unit_id, proposed.type, proposed.target_pos)
	if checked == null or checked.throw_amount != proposed.throw_amount:
		return null
	return checked


func submit_turn(action_type: String, target: Vector2i = Vector2i.ZERO) -> bool:
	if _phase != Phase.ACTIVE:
		return false

	var player_intent := PuzzleActions.create_intent(_board, PuzzleLevelData.PLAYER_ID, action_type, target)
	if player_intent == null:
		last_error = "该动作当前不可执行。"
		return false

	var intents: Array[ActionIntent] = [player_intent]
	for unit in _board.units:
		if unit.id == PuzzleLevelData.PLAYER_ID or not unit.alive or unit.won:
			continue
		var intent := preview_enemy_intent(unit.id)
		if intent == null:
			last_error = "敌人 %d 的行动不符合规则。" % unit.id
			return false
		intents.append(intent)

	last_error = ""
	_board = _resolver.resolve_turn(_board, intents).state_after
	var player := _board.get_unit_by_id(PuzzleLevelData.PLAYER_ID)
	var turns := _board.turn_index
	if not player.alive:
		_phase = Phase.LOST
		level_lost.emit(turns)
	elif _goal_is_met(player):
		_phase = Phase.WON
		var collected := player.coins - _starting_coins if _board.pressure_cells.is_empty() else 0
		level_won.emit(collected, turns, float(collected) / turns)
	return true


func _goal_is_met(player: UnitState) -> bool:
	if _board.trail != null and not _board.trail.is_complete(player.pos):
		return false
	if not _board.pressure_cells.is_empty():
		return _board.occupied_pressure_cells().size() == _board.pressure_cells.size()
	return player.coins == _target_coins

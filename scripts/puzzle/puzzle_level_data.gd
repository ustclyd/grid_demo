class_name PuzzleLevelData
extends Resource

const PLAYER_ID := 1

@export var title := ""
@export_multiline var play_hint := ""
@export var board_size := Vector2i(2, 1)
@export var player_cell := Vector2i.ZERO
@export var player_coins: int = 0
@export var enemies: Array[PuzzleEnemySpawn] = []
@export var bags: Array[PuzzleBagSpawn] = []
@export var optimal_turns: int = 0
@export var trail_cells: Array[Vector2i] = []
@export var trail_exit := Vector2i.ZERO


func validation_error() -> String:
	if board_size.x <= 0 or board_size.y <= 0:
		return "棋盘尺寸必须为正数。"
	var bounds := Rect2i(Vector2i.ZERO, board_size)
	if not bounds.has_point(player_cell) or player_coins < 0:
		return "玩家出生格或持币无效。"
	var trail: PuzzleTrail
	if not trail_cells.is_empty():
		trail = PuzzleTrail.new(trail_cells, trail_exit)
		for cell in trail_cells:
			if not bounds.has_point(cell):
				return "路线存在越界格。"
		if trail.remaining_cells() != trail_cells.size() - 1:
			return "路线存在重复格。"
		if not trail.is_floor(player_cell) or not trail.is_floor(trail_exit) or player_cell == trail_exit:
			return "路线的起点或终点无效。"
	if optimal_turns < 0:
		return "最优回合数须为非负数。"

	var occupied: Dictionary[Vector2i, bool] = {}
	occupied[player_cell] = true
	var available_coins := 0
	for index in enemies.size():
		var enemy := enemies[index]
		if enemy == null or not bounds.has_point(enemy.cell) or enemy.coins < 0 or occupied.has(enemy.cell):
			return "第 %d 个敌人的位置或持币无效。" % (index + 1)
		if enemy.policy == null or not enemy.policy.is_available():
			return "第 %d 个敌人的策略还未实现。" % (index + 1)
		if trail != null and not trail.is_floor(enemy.cell):
			return "第 %d 个敌人必须出生在可行走格。" % (index + 1)
		if not enemy.policy.accepts_spawn(enemy.cell, board_size):
			return "第 %d 个敌人的出生格与行动路线不匹配。" % (index + 1)
		occupied[enemy.cell] = true
		available_coins += enemy.coins
	for index in bags.size():
		var bag := bags[index]
		if bag == null or not bounds.has_point(bag.cell) or bag.coins <= 0:
			return "第 %d 个钱袋的位置或金额无效。" % (index + 1)
		if trail != null and not trail.is_floor(bag.cell):
			return "第 %d 个钱袋必须放在可行走格。" % (index + 1)
		available_coins += bag.coins
	if available_coins == 0:
		return "开局必须有待收集的金币。"
	return ""


func build_board() -> GameState:
	var board := GameState.new()
	board.board_size = board_size
	if not trail_cells.is_empty():
		board.trail = PuzzleTrail.new(trail_cells, trail_exit)
	board.units.append(_make_unit(PLAYER_ID, player_cell, player_coins))
	for index in enemies.size():
		var spawn := enemies[index]
		board.units.append(_make_unit(index + 2, spawn.cell, spawn.coins))
	for index in bags.size():
		var spawn := bags[index]
		var bag := BagState.new()
		bag.id = index + 1
		bag.pos = spawn.cell
		bag.coins = spawn.coins
		board.bags.append(bag)
	return board


func _make_unit(id: int, cell: Vector2i, coins: int) -> UnitState:
	var unit := UnitState.new()
	unit.id = id
	unit.pos = cell
	unit.prev_pos = cell
	unit.coins = coins
	unit.entry_coins = coins
	return unit

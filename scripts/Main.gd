extends Node2D

# ================================
# 这一部分是“常量 const”
# ================================
#
# `const` 的意思是“常量”。
# 你可以把它理解成“提前写死、通常不会在运行时修改的固定配置”。

# 网格一共是 7 x 7。
const GRID_COUNT := 7

# 每个格子的边长是 96 像素。
# 这个值变大以后，整个网格也会一起变大。
const CELL_SIZE := 96.0

# 网格线颜色：浅灰色。
const GRID_COLOR := Color(0.85, 0.85, 0.85)

# 玩家圆圈颜色：蓝色。
const PLAYER_COLOR := Color(0.2, 0.6, 1.0)

# 感叹号颜色：黄色。
const ALERT_COLOR := Color(1.0, 0.9, 0.2)

# 计时器在“可操作阶段”的文字颜色：蓝色。
const TIMER_IDLE_COLOR := Color(0.2, 0.6, 1.0)

# 计时器在“执行阶段”的文字颜色：红色。
const TIMER_EXECUTING_COLOR := Color(1.0, 0.25, 0.25)

# 网格线宽。
const LINE_WIDTH := 2.0

# 玩家空心圆圈描边的线宽。
const PLAYER_RING_WIDTH := 3.0

# 中心格子的索引。
const CENTER_INDEX := int(GRID_COUNT / 2)

# 每 5 秒结算一次动作。
const TURN_INTERVAL := 5.0

# 真正执行动作的阶段持续 0.5 秒。
const EXECUTE_DURATION := 0.5


# ================================
# 这一部分是“变量 var”
# ================================
#
# `var` 的意思是“变量”。
# 变量在运行过程中是可以改变的。

# 玩家当前所在的格子坐标。
var player_grid := Vector2i(CENTER_INDEX, CENTER_INDEX)

# 玩家点击后，等待下一次结算时要移动到的目标格子。
var pending_target := Vector2i.ZERO

# 是否已经记录了一个待执行目标。
var has_pending_target := false

# 当前是否处于执行阶段。
var is_executing := false

# 这一轮开始的时间点。
# 我们用它来计算“现在距离本轮开始过了多久”。
var turn_start_time := 0.0

# 用来绘制左上角计时文字的字体对象。
# 一开始先是空，等 `_ready()` 时再真正拿到。
var timer_font: Font


# ================================
# 这一部分是“节点引用”
# ================================
#
# 场景里已经有一个子节点叫 `Timer`。
@onready var timer: Timer = $Timer


# ================================
# 生命周期函数：_ready
# ================================
#
# 当节点准备好以后，Godot 会自动调用这个函数一次。
func _ready() -> void:
	# 当窗口大小变化时，重新绘制。
	get_viewport().size_changed.connect(queue_redraw)

	# 每次 Timer 超时，就自动调用我们的回调函数。
	timer.timeout.connect(_on_timer_timeout)

	# 把计时器间隔明确设置为 5 秒。
	timer.wait_time = TURN_INTERVAL

	# 记录这一轮开始的时间。
	# `Time.get_ticks_msec()` 会返回程序运行到现在经过了多少毫秒。
	# 我们除以 1000.0，把它换算成秒。
	turn_start_time = Time.get_ticks_msec() / 1000.0

	# 获取默认字体，用来绘制左上角计时文本。
	timer_font = ThemeDB.fallback_font

	# 启动每帧更新。
	# 因为左上角的计时数字需要持续变化，所以需要不断重绘。
	set_process(true)

	# 请求第一次绘制。
	queue_redraw()


# ================================
# 每帧更新函数：_process
# ================================
#
# `_process(delta)` 会在每一帧自动调用一次。
# 这里我们不做复杂逻辑，只是为了让左上角计时器不断刷新。
func _process(_delta: float) -> void:
	queue_redraw()


# ================================
# 输入函数：_input
# ================================
#
# 当鼠标、键盘等输入发生时，Godot 会自动调用这个函数。
func _input(event: InputEvent) -> void:
	# 如果当前正在执行动作，就忽略所有操作。
	if is_executing:
		return

	# 判断是否为“鼠标左键按下”。
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var clicked_grid := _screen_to_grid(event.position)

			# 只有点在网格内部，才记录目标格子。
			if _is_inside_grid(clicked_grid):
				pending_target = clicked_grid
				has_pending_target = true
				queue_redraw()


# ================================
# 绘制函数：_draw
# ================================
#
# 所有可视内容都在这里画出来。
func _draw() -> void:
	var grid_pixel_size := Vector2(CELL_SIZE * GRID_COUNT, CELL_SIZE * GRID_COUNT)
	var grid_origin := (get_viewport_rect().size - grid_pixel_size) * 0.5

	# 画 7x7 网格。
	for y in GRID_COUNT:
		for x in GRID_COUNT:
			var cell_position := grid_origin + Vector2(x * CELL_SIZE, y * CELL_SIZE)
			draw_rect(
				Rect2(cell_position, Vector2.ONE * CELL_SIZE),
				GRID_COLOR,
				false,
				LINE_WIDTH
			)

	# 计算玩家圆圈中心。
	var player_center := _grid_to_screen_center(player_grid)

	# 画玩家空心圆圈。
	# 半径改得更小，保持仍然位于格子正中心。
	draw_arc(player_center, CELL_SIZE * 0.14, 0.0, TAU, 48, PLAYER_COLOR, PLAYER_RING_WIDTH)

	# 执行阶段显示感叹号。
	if is_executing:
		_draw_alert_mark(player_center)

	# 最后画左上角计时器。
	_draw_timer_text()


# ================================
# 计时器回调：每 5 秒执行一次
# ================================
#
# 每当 Timer 走完 5 秒，就会自动调用这个函数。
func _on_timer_timeout() -> void:
	# 进入执行阶段。
	is_executing = true
	queue_redraw()

	# 等待 0.5 秒。
	# 这段时间左上角固定显示 5.00s，颜色改成红色。
	await get_tree().create_timer(EXECUTE_DURATION).timeout

	# 如果之前有记录目标格子，就真正移动玩家。
	if has_pending_target:
		player_grid = pending_target

	# 清空上一轮输入。
	has_pending_target = false

	# 退出执行阶段，开始新的一轮。
	is_executing = false
	turn_start_time = Time.get_ticks_msec() / 1000.0
	queue_redraw()


# ================================
# 工具函数：格子坐标 -> 屏幕像素中心点
# ================================
func _grid_to_screen_center(grid: Vector2i) -> Vector2:
	var grid_pixel_size := Vector2(CELL_SIZE * GRID_COUNT, CELL_SIZE * GRID_COUNT)
	var grid_origin := (get_viewport_rect().size - grid_pixel_size) * 0.5
	return grid_origin + (Vector2(grid) + Vector2.ONE * 0.5) * CELL_SIZE


# ================================
# 工具函数：屏幕像素位置 -> 格子坐标
# ================================
func _screen_to_grid(screen_position: Vector2) -> Vector2i:
	var grid_pixel_size := Vector2(CELL_SIZE * GRID_COUNT, CELL_SIZE * GRID_COUNT)
	var grid_origin := (get_viewport_rect().size - grid_pixel_size) * 0.5
	var local_position := screen_position - grid_origin

	return Vector2i(
		int(floor(local_position.x / CELL_SIZE)),
		int(floor(local_position.y / CELL_SIZE))
	)


# ================================
# 工具函数：判断是否在网格内部
# ================================
func _is_inside_grid(grid: Vector2i) -> bool:
	return (
		grid.x >= 0
		and grid.y >= 0
		and grid.x < GRID_COUNT
		and grid.y < GRID_COUNT
	)


# ================================
# 工具函数：画感叹号
# ================================
func _draw_alert_mark(player_center: Vector2) -> void:
	var mark_top := player_center + Vector2(0, -CELL_SIZE * 0.75)
	var mark_bottom := player_center + Vector2(0, -CELL_SIZE * 0.45)
	draw_line(mark_top, mark_bottom, ALERT_COLOR, 4.0)

	var dot_center := player_center + Vector2(0, -CELL_SIZE * 0.32)
	draw_circle(dot_center, 4.0, ALERT_COLOR)


# ================================
# 工具函数：画左上角计时文字
# ================================
#
# 操作阶段：
# - 显示 0.00s 到 5.00s
# - 蓝色
#
# 执行阶段：
# - 固定显示 5.00s
# - 红色
func _draw_timer_text() -> void:
	var display_text := ""
	var display_color := TIMER_IDLE_COLOR

	if is_executing:
		display_text = "%.2fs" % TURN_INTERVAL
		display_color = TIMER_EXECUTING_COLOR
	else:
		var now_time: float = Time.get_ticks_msec() / 1000.0
		var elapsed: float = clampf(now_time - turn_start_time, 0.0, TURN_INTERVAL)

		# `snapped(elapsed, 0.01)` 的作用是把数字处理到 0.01 的精度。
		# `"%0.2f"` 的作用是格式化成保留两位小数。
		display_text = "%.2fs" % snappedf(elapsed, 0.01)
		display_color = TIMER_IDLE_COLOR

	# 在屏幕左上角绘制文字。
	# 坐标 (20, 40) 表示距离左边 20 像素，距离上边大约 40 像素的位置。
	draw_string(timer_font, Vector2(20, 40), display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, display_color)

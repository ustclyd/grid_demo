extends Node2D
# 第 1 行：
# `extends` 是 GDScript 里的关键字，意思是“继承”。
# 你可以先把“继承”简单理解成：
# “这份脚本是给哪一种节点类型使用的”。
# `Node2D` 是 Godot 里专门用于 2D 游戏的节点类型。
# 所以这一行的白话意思是：
# “这份脚本要挂在一个 2D 节点上，这个节点拥有 2D 坐标、旋转、缩放等能力。”


const GRID_COUNT := 7
# 第 4 行：
# `const` 是“常量”的意思。
# 常量就是：先写死、一般不在运行过程中改变的值。
# `GRID_COUNT` 是你自己起的名字，意思是“网格数量”。
# 名字为什么全大写？
# 因为程序员通常用“全大写”提醒自己：这是常量。
# `:=` 是“定义并赋值”的写法。
# 这里就是把数字 7 存进 `GRID_COUNT`。
# 白话意思：
# “网格的行列数是 7，也就是 7x7。”

const CELL_SIZE := 96.0
# 第 14 行：
# `CELL_SIZE` 可以理解成“每个格子的尺寸”。
# 这里写 `96.0`，而不是 `96`。
# 带 `.0` 表示它是一个“浮点数”，也就是带小数概念的数字。
# 在 Godot 里，坐标和图形绘制经常使用浮点数。
# 白话意思：
# “每个格子的宽和高都是 96 像素。”

const GRID_COLOR := Color(0.85, 0.85, 0.85)
# 第 21 行：
# `Color(...)` 是 Godot 用来表示颜色的类型。
# 括号里的三个数字分别代表：
# - 红色 red
# - 绿色 green
# - 蓝色 blue
# 它们不是 0 到 255，而是 0.0 到 1.0。
# `0.85, 0.85, 0.85` 会得到浅灰色。
# 白话意思：
# “网格线用浅灰色来画。”

const PLAYER_COLOR := Color(0.2, 0.6, 1.0)
# 第 29 行：
# 这也是一种颜色。
# `0.2, 0.6, 1.0` 是偏蓝的颜色。
# 白话意思：
# “玩家小圆圈用蓝色画。”

const ALERT_COLOR := Color(1.0, 0.9, 0.2)
# 第 35 行：
# 这是执行动作时感叹号使用的颜色。
# 这个值会得到偏黄色。
# 白话意思：
# “执行阶段玩家头上的感叹号用黄色画。”

const TIMER_IDLE_COLOR := Color(0.2, 0.6, 1.0)
# 第 41 行：
# 这是左上角计时器在“操作阶段”时使用的文字颜色。
# 这里仍然使用蓝色。

const TIMER_EXECUTING_COLOR := Color(1.0, 0.25, 0.25)
# 第 45 行：
# 这是左上角计时器在“执行阶段”时使用的颜色。
# 这里是红色。

const LINE_WIDTH := 2.0
# 第 49 行：
# `LINE_WIDTH` 表示“线条宽度”。
# 这里的 2.0 表示网格边框线宽是 2 像素。

const PLAYER_RING_WIDTH := 3.0
# 第 53 行：
# 这是玩家空心圆圈边框的线宽。
# 因为玩家是“空心圆”，所以只需要画外圈线条，不需要填充内部。

const CENTER_INDEX := int(GRID_COUNT / 2)
# 第 57 行：
# `CENTER_INDEX` 意思是“中心索引”。
# 7x7 的网格索引从 0 开始到 6 结束。
# 中间那个索引就是 3。
# `GRID_COUNT / 2` 先得到 3.5 或 3 的数值概念，
# `int(...)` 的作用是“转成整数”。
# 所以最终结果是 3。
# 白话意思：
# “7 格的中间位置索引是 3。”

const TURN_INTERVAL := 5.0
# 第 66 行：
# `TURN_INTERVAL` 是“每轮操作阶段持续多久”。
# 单位是秒。
# 这里写 5.0，表示玩家每次有 5 秒时间做输入。

const EXECUTE_DURATION := 1.0
# 第 71 行：
# `EXECUTE_DURATION` 是“执行阶段持续多久”。
# 也就是红色阶段持续多久，玩家被锁住多久。
# 这里是 1.0 秒。


var player_grid := Vector2i(0, GRID_COUNT - 1)
# 第 78 行：
# `var` 是“变量”的意思。
# 变量和常量不同，它在程序运行时可以改变。
# `player_grid` 的意思是“玩家所在的格子坐标”。
# `Vector2i` 是 Godot 的一种数据类型：
# - `Vector2` 表示“二维坐标”
# - 后面的 `i` 表示“integer”，也就是整数版
# 所以 `Vector2i(0, 6)` 可以理解成坐标 `(x=0, y=6)`。
# 这里为什么是 `GRID_COUNT - 1`？
# 因为如果网格有 7 行，索引是 0 到 6，最底下一行是 6。
# 所以这一行的白话意思是：
# “玩家一开始出生在左下角格子。”

var pending_target := Vector2i.ZERO
# 第 91 行：
# `pending` 的意思是“等待中的、待处理的”。
# `target` 的意思是“目标”。
# 所以 `pending_target` 就是“等待下一轮执行的目标格子”。
# `Vector2i.ZERO` 是 Godot 提供的一个现成值，意思是 `(0, 0)`。
# 注意：
# 这里的 `(0, 0)` 只是初始化默认值，不代表真的要移动到这里。

var has_pending_target := false
# 第 99 行：
# `has_pending_target` 是一个布尔变量。
# “布尔”意思是它只有两个值：
# - `true` 表示“是 / 有”
# - `false` 表示“否 / 没有”
# 这个变量的作用是：
# “当前有没有记录一个准备执行的目标格子？”
# 一开始是 `false`，因为还没有点击任何目标。

var is_executing := false
# 第 108 行：
# `is_executing` 的意思是“当前是否正在执行动作”。
# 如果它是 `true`，说明玩家正处于红色执行阶段，不能操作。
# 如果它是 `false`，说明玩家正处于蓝色输入阶段，可以点击。

var turn_start_time := 0.0
# 第 114 行：
# `turn_start_time` 的意思是“这一轮开始的时间”。
# 我们后面会拿“当前时间 - 这一轮开始时间”，算出已经过去了多少秒。

var timer_font: Font
# 第 119 行：
# 这一行定义了一个变量 `timer_font`。
# 冒号 `:` 后面的 `Font` 是“类型标注”，表示：
# “这个变量应该存放一个字体对象。”
# 字体对象的作用是：后面在屏幕左上角画文字时要用。
# 这里暂时没给它赋值，等 `_ready()` 里再真正拿到字体。


@onready var timer: Timer = $Timer
# 第 126 行：
# `@onready` 是一个注解。
# 你先把它理解成：
# “等这个节点和它的子节点都准备好以后，再执行这行赋值。”
# `timer` 是变量名。
# `: Timer` 表示这个变量的类型是 `Timer` 节点。
# `=` 是普通赋值。
# `$Timer` 是 Godot 的简写语法，意思是：
# “找到当前节点下面名叫 `Timer` 的子节点。”
# 所以这一行白话意思是：
# “等场景准备好后，把子节点 `Timer` 取出来，保存到 `timer` 变量里，后面方便直接使用。”


func _ready() -> void:
	# 第 136 行：
	# `func` 是“定义函数”的关键字。
	# `_ready` 是函数名。
	# `()` 表示这个函数不接收参数。
	# `-> void` 表示这个函数没有返回值。
	# `_ready()` 是 Godot 内置会自动调用的生命周期函数之一。
	# 生命周期函数，你可以理解成：
	# “不是你手动调用，而是引擎在特定时机自动调用的函数。”
	# `_ready()` 的调用时机是：
	# “当前节点进入场景，并准备好以后，自动执行一次。”

	get_viewport().size_changed.connect(queue_redraw)
	# 第 145 行：
	# `get_viewport()` 是一个函数调用。
	# 它会返回“当前游戏画面对应的视口对象”。
	# 视口可以先理解成“实际显示游戏内容的画面区域”。
	# `.size_changed` 是这个视口对象上的一个“信号”。
	# 信号可以理解成“某件事情发生时发出的通知”。
	# 这里的意思是“窗口大小发生变化”。
	# `.connect(queue_redraw)` 的意思是：
	# “当 size_changed 这个信号发生时，就调用 queue_redraw 这个函数。”
	# `queue_redraw()` 的作用是：请求重新绘制。
	# 白话意思：
	# “如果窗口大小变了，就重新画一遍网格和玩家。”

	timer.timeout.connect(_on_timer_timeout)
	# 第 157 行：
	# `timer` 是前面取到的 Timer 节点。
	# `.timeout` 是 Timer 的信号，意思是“计时结束了”。
	# `.connect(_on_timer_timeout)` 表示：
	# “当 Timer 倒计时结束，就调用 `_on_timer_timeout()` 这个函数。”
	# 这是一种“信号连接”写法。
	# 白话意思：
	# “每轮计时结束时，自动执行我们的结算逻辑。”

	timer.wait_time = TURN_INTERVAL
	# 第 165 行：
	# `wait_time` 是 Timer 的属性，意思是“等待时间”。
	# 这里把它设置为 `TURN_INTERVAL`，也就是 5 秒。
	# 白话意思：
	# “让计时器每次等待 5 秒再超时。”

	timer.stop()
	# 第 171 行：
	# `stop()` 是 Timer 的方法，也就是 Timer 节点自带的函数。
	# 调用它会让当前计时器停止。
	# 为什么要先停？
	# 因为场景里 Timer 可能自动启动过，为了确保它从新的设置重新开始，先停掉更稳。

	timer.start()
	# 第 177 行：
	# `start()` 会让 Timer 开始计时。
	# 因为前面刚设置了 `wait_time = 5.0`，
	# 所以这里启动后，它会按 5 秒一轮计时。

	turn_start_time = Time.get_ticks_msec() / 1000.0
	# 第 183 行：
	# `Time.get_ticks_msec()` 会返回：
	# “程序从启动到现在，一共过了多少毫秒”
	# 毫秒是千分之一秒。
	# 所以除以 `1000.0` 后，就变成“秒”。
	# 这一行的白话意思是：
	# “记录当前这一轮开始的时间点（单位：秒）。”

	timer_font = ThemeDB.fallback_font
	# 第 191 行：
	# `ThemeDB` 是 Godot 里跟主题、字体等 UI 资源有关的东西。
	# `fallback_font` 可以简单理解成“默认备用字体”。
	# 我们把它赋值给 `timer_font`，
	# 这样后面画左上角计时器文字时就有字体可用。

	set_process(true)
	# 第 198 行：
	# `set_process(true)` 的意思是：
	# “开启每帧更新，也就是允许 `_process()` 每一帧自动运行。”
	# 为什么要开？
	# 因为左上角计时器要不停变化，不是画一次就结束。
	# 所以需要每一帧都刷新。

	queue_redraw()
	# 第 205 行：
	# `queue_redraw()` 不是“立刻马上画”，
	# 而是“告诉 Godot：这个节点需要重新绘制，请在接下来的绘制阶段调用 `_draw()`。”
	# 白话意思：
	# “准备第一次把画面画出来。”


func _process(_delta: float) -> void:
	# 第 213 行：
	# `_process()` 也是 Godot 自动调用的生命周期函数。
	# 它通常会在每一帧调用一次。
	# `(_delta: float)` 里的 `delta` 表示“上一帧到这一帧经过了多少秒”。
	# 前面的下划线 `_delta` 表示：
	# “这个参数虽然传进来了，但我这段代码里暂时不用它。”
	# `: float` 表示这个参数是浮点数。
	# 这个函数这里的作用很简单：
	# 每一帧都请求重绘，这样左上角计时器数字才能连续更新。

	queue_redraw()
	# 第 223 行：
	# 每一帧都请求重新绘制。


func _input(event: InputEvent) -> void:
	# 第 227 行：
	# `_input()` 也是 Godot 自动调用的函数。
	# 当有输入事件发生时，比如鼠标点击、键盘按键，它就会被调用。
	# `event` 是参数名。
	# `: InputEvent` 表示它的类型是“输入事件”。

	if is_executing:
	# 第 233 行：
	# `if` 是“如果”的意思，用来做条件判断。
	# 如果 `is_executing` 为真，说明当前是执行阶段。
	# 执行阶段玩家不能操作。
		return
		# 第 237 行：
		# `return` 的意思是“立刻结束当前函数，不再往下执行”。
		# 所以这两行合起来的白话意思是：
		# “如果现在正在执行动作，就直接忽略这次输入。”

	if event is InputEventMouseButton:
	# 第 243 行：
	# `is` 是类型判断语法。
	# 这里表示：
	# “如果这次输入事件是鼠标按键事件”
	# 只有鼠标按键事件才会继续往下判断。

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 第 248 行：
			# `button_index` 表示按下的是哪个鼠标按键。
			# `MOUSE_BUTTON_LEFT` 表示鼠标左键。
			# `==` 是“等于”的意思。
			# `and` 是“并且”的意思。
			# `event.pressed` 表示这是不是“按下”的那一刻。
			# 所以整句的意思是：
			# “如果这是鼠标左键被按下的事件”

			var clicked_grid := _screen_to_grid(event.position)
			# 第 257 行：
			# 这里定义了一个局部变量 `clicked_grid`。
			# “局部变量”意思是：只在当前函数这块代码里临时使用。
			# `event.position` 是鼠标点击的屏幕像素位置。
			# `_screen_to_grid(...)` 是我们自己下面写的一个工具函数。
			# 它的作用是把“屏幕像素坐标”换算成“网格坐标”。
			# 白话意思：
			# “把鼠标点到的位置，转换成第几列第几行。”

			if _is_inside_grid(clicked_grid) and _is_adjacent_grid(player_grid, clicked_grid):
				# 第 267 行：
				# 这里又是一个 `if` 条件判断。
				# `_is_inside_grid(clicked_grid)` 的意思是：
				# “点击的位置是否在网格内部？”
				# `_is_adjacent_grid(player_grid, clicked_grid)` 的意思是：
				# “点击的格子是否和玩家当前位置相邻？”
				# 两个条件要同时满足，才允许移动。

				pending_target = clicked_grid
				# 第 276 行：
				# 如果点击合法，就把目标格子记录下来。
				# 注意：这里只是“记录目标”，不是立刻移动。

				has_pending_target = true
				# 第 280 行：
				# 标记为“这一轮已经有待执行目标了”。

			else:
				# 第 283 行：
				# `else` 的意思是“否则”。
				# 也就是：
				# 如果刚才那个合法移动条件不成立，就走这里。
				# 包括几种情况：
				# - 点到自己所在格子
				# - 点到不相邻格子
				# - 点到网格外面
				# 这些都视为“待机”

				has_pending_target = false
				# 第 292 行：
				# 表示“没有有效移动目标”。

				pending_target = player_grid
				# 第 296 行：
				# 把待执行目标设置成玩家当前格子本身。
				# 白话意思：
				# “这轮结算时保持原地不动。”

			queue_redraw()
			# 第 301 行：
			# 输入状态变了以后，请求重新绘制。


func _draw() -> void:
	# 第 305 行：
	# `_draw()` 是 Godot 的绘制回调函数。
	# 当这个节点需要被画出来时，Godot 会自动调用它。
	# 网格、玩家、感叹号、左上角计时器，都是在这里画的。

	var grid_pixel_size := Vector2(CELL_SIZE * GRID_COUNT, CELL_SIZE * GRID_COUNT)
	# 第 311 行：
	# `Vector2` 表示二维坐标或二维尺寸。
	# 这里不是“格子坐标”，而是“像素尺寸”。
	# `CELL_SIZE * GRID_COUNT` 就是：
	# 96 * 7 = 672
	# 所以整个网格宽 672 像素，高 672 像素。

	var grid_origin := (get_viewport_rect().size - grid_pixel_size) * 0.5
	# 第 318 行：
	# `get_viewport_rect().size` 表示当前游戏窗口的尺寸。
	# “窗口尺寸 - 网格尺寸” 得到剩余空白区域。
	# 再乘 `0.5`，就是左右各分一半、上下各分一半。
	# 所以 `grid_origin` 的意思是：
	# “网格左上角应该放在屏幕哪里，才能让整个网格居中。”

	for y in GRID_COUNT:
		# 第 325 行：
		# `for` 是循环语法。
		# 这里表示 y 从 0 到 6 依次取值。
		# 因为 GRID_COUNT 是 7。

		for x in GRID_COUNT:
			# 第 329 行：
			# 这一层表示 x 也从 0 到 6。
			# 两层循环组合起来，就是把 7x7 共 49 个格子全部遍历一遍。

			var cell_position := grid_origin + Vector2(x * CELL_SIZE, y * CELL_SIZE)
			# 第 334 行：
			# 这里计算当前格子的左上角像素位置。
			# x 每增加 1，就往右偏移一个格子宽度。
			# y 每增加 1，就往下偏移一个格子高度。

			draw_rect(
				Rect2(cell_position, Vector2.ONE * CELL_SIZE),
				GRID_COLOR,
				false,
				LINE_WIDTH
			)
			# 第 339 到 344 行：
			# `draw_rect(...)` 是 Godot 提供的绘图函数，作用是画矩形。
			# `Rect2(...)` 表示一个矩形区域。
			# 第一个参数 `cell_position` 是矩形左上角位置。
			# 第二个参数 `Vector2.ONE * CELL_SIZE` 表示矩形大小。
			# `Vector2.ONE` 就是 `(1, 1)`。
			# `(1,1) * 96` 就得到 `(96,96)`。
			# 第三个参数 `false` 表示“只画边框，不填充内部”。
			# 第四个参数 `LINE_WIDTH` 表示线宽。
			# 白话意思：
			# “把当前这个格子的边框画出来。”

	var player_center := _grid_to_screen_center(player_grid)
	# 第 356 行：
	# 这里调用我们自己写的工具函数 `_grid_to_screen_center(...)`。
	# 它会把玩家所在的“格子坐标”，换算成屏幕上的“像素中心点”。
	# 因为画圆时需要知道的是像素位置，而不是第几格。

	draw_arc(player_center, CELL_SIZE * 0.14, 0.0, TAU, 48, PLAYER_COLOR, PLAYER_RING_WIDTH)
	# 第 361 行：
	# `draw_arc(...)` 是画圆弧/圆环的函数。
	# 因为起始角度到结束角度刚好是一整圈，所以看起来就是圆。
	# 参数依次可以先这样理解：
	# - `player_center`：圆心在哪
	# - `CELL_SIZE * 0.14`：半径多大
	# - `0.0`：从 0 度开始
	# - `TAU`：画到一整圈结束
	# - `48`：把圆分成多少段来近似绘制
	# - `PLAYER_COLOR`：颜色
	# - `PLAYER_RING_WIDTH`：描边宽度
	# `TAU` 是一个数学常量，等于一整圈弧度，大约 6.28318，也就是 2π。
	# 白话意思：
	# “在玩家所在格子的中心，画一个较小的蓝色空心圆。”

	if is_executing:
		# 第 374 行：
		# 如果现在是执行阶段，就额外画一个感叹号。
		_draw_alert_mark(player_center)
		# 第 376 行：
		# 调用我们自己写的 `_draw_alert_mark(...)` 函数。
		# 这个函数会在玩家头上画黄色感叹号。

	_draw_timer_text()
	# 第 380 行：
	# 不管是不是执行阶段，都要画左上角计时器文字。


func _on_timer_timeout() -> void:
	# 第 384 行：
	# 这个函数名字是我们自己起的。
	# 但它之所以会自动执行，是因为前面在 `_ready()` 里写了：
	# `timer.timeout.connect(_on_timer_timeout)`
	# 所以 Timer 一旦超时，这个函数就会被自动调用。
	# 你可以把它理解成：
	# “每一轮结算时运行的主逻辑函数。”

	is_executing = true
	# 第 392 行：
	# 先把状态改成“正在执行”。
	# 这样输入就会被锁住，计时器文字也会变红。

	queue_redraw()
	# 第 396 行：
	# 立刻请求重绘，让感叹号和红色计时器显示出来。

	await get_tree().create_timer(EXECUTE_DURATION).timeout
	# 第 400 行：
	# `await` 是“等待”的意思。
	# 这一句非常重要。
	# 它的白话意思是：
	# “创建一个只持续 EXECUTE_DURATION 秒的临时计时器，
	# 然后等它超时以后，再继续往下执行后面的代码。”
	# `get_tree()` 会拿到场景树。
	# 场景树可以理解成“整个场景里所有节点的组织系统”。
	# `.create_timer(...)` 会临时创建一个计时器。
	# `.timeout` 表示等待这个临时计时器结束。
	# 因为 `EXECUTE_DURATION` 现在是 1.0，
	# 所以这句的实际效果就是：
	# “红色执行阶段持续 1 秒。”

	if has_pending_target:
		# 第 412 行：
		# 如果这一轮之前记录过合法目标，
		# 那么就在这里真正移动玩家。
		player_grid = pending_target
		# 第 415 行：
		# 把玩家当前坐标改成记录下来的目标格子。
		# 这就是“真正发生移动”的地方。

	has_pending_target = false
	# 第 420 行：
	# 这一轮结算完以后，把目标记录清空。

	is_executing = false
	# 第 424 行：
	# 执行阶段结束，玩家重新可以操作。

	turn_start_time = Time.get_ticks_msec() / 1000.0
	# 第 428 行：
	# 新一轮开始了，所以重新记录新一轮的开始时间。

	queue_redraw()
	# 第 432 行：
	# 再重绘一次，让画面恢复到蓝色操作阶段状态。


func _grid_to_screen_center(grid: Vector2i) -> Vector2:
	# 第 436 行：
	# 这是一个“工具函数”。
	# 工具函数的意思是：
	# “专门负责某个小任务，方便别的地方重复调用。”
	# 它接收一个参数 `grid`，类型是 `Vector2i`。
	# 它会返回一个 `Vector2`。
	# 白话意思：
	# “给我一个格子坐标，我帮你算出这个格子的屏幕中心点。”

	var grid_pixel_size := Vector2(CELL_SIZE * GRID_COUNT, CELL_SIZE * GRID_COUNT)
	# 第 444 行：
	# 先算出整个网格的像素尺寸。

	var grid_origin := (get_viewport_rect().size - grid_pixel_size) * 0.5
	# 第 447 行：
	# 再算出网格左上角位置。

	return grid_origin + (Vector2(grid) + Vector2.ONE * 0.5) * CELL_SIZE
	# 第 450 行：
	# `return` 的意思是“把结果返回出去”。
	# `Vector2(grid)` 是把整数坐标 `Vector2i` 转成普通 `Vector2`。
	# `Vector2.ONE * 0.5` 等于 `(0.5, 0.5)`。
	# 它的意义是：从格子左上角偏移到格子中心。
	# 最后再乘 `CELL_SIZE`，就把“第几格”变成“像素坐标”。
	# 加上 `grid_origin` 后，就得到屏幕上的真实位置。


func _screen_to_grid(screen_position: Vector2) -> Vector2i:
	# 第 459 行：
	# 这个工具函数和上一个相反。
	# 上一个是“格子 -> 屏幕”
	# 这个是“屏幕 -> 格子”
	# 白话意思：
	# “给我一个鼠标点击的屏幕像素位置，我帮你算出它点中了哪一个格子。”

	var grid_pixel_size := Vector2(CELL_SIZE * GRID_COUNT, CELL_SIZE * GRID_COUNT)
	# 第 466 行：
	# 先算网格尺寸。

	var grid_origin := (get_viewport_rect().size - grid_pixel_size) * 0.5
	# 第 469 行：
	# 再算网格左上角。

	var local_position := screen_position - grid_origin
	# 第 472 行：
	# `local_position` 的意思是“局部位置”。
	# 也就是：
	# 把鼠标点击的全屏位置，转换成“相对于网格左上角”的位置。

	return Vector2i(
		int(floor(local_position.x / CELL_SIZE)),
		int(floor(local_position.y / CELL_SIZE))
	)
	# 第 477 到 480 行：
	# `local_position.x / CELL_SIZE` 表示：
	# 鼠标点到了第几列的大概位置。
	# `floor(...)` 表示“向下取整”。
	# 比如 2.8 会变成 2。
	# `int(...)` 表示把结果明确转成整数。
	# y 的计算也是同理。
	# 最后返回一个 `Vector2i(列索引, 行索引)`。


func _is_inside_grid(grid: Vector2i) -> bool:
	# 第 487 行：
	# 这是判断函数。
	# 它的作用是检查：给定的格子坐标是否在 7x7 网格内部。
	# `-> bool` 表示这个函数会返回布尔值：
	# - `true`：在网格里
	# - `false`：不在网格里

	return (
		grid.x >= 0
		and grid.y >= 0
		and grid.x < GRID_COUNT
		and grid.y < GRID_COUNT
	)
	# 第 494 到 499 行：
	# 这四个条件合起来的意思是：
	# - x 不能小于 0
	# - y 不能小于 0
	# - x 不能大于等于 7
	# - y 不能大于等于 7
	# 如果都满足，说明这个格子在网格范围内。


func _is_adjacent_grid(from_grid: Vector2i, to_grid: Vector2i) -> bool:
	# 第 504 行：
	# 这个函数专门用来判断两个格子是不是“相邻”。
	# `from_grid` 是起点格子，也就是玩家当前所在格子。
	# `to_grid` 是目标格子，也就是玩家想去的格子。

	var delta_x: int = absi(to_grid.x - from_grid.x)
	# 第 510 行：
	# `delta_x` 的意思是“x 方向相差多少格”。
	# `to_grid.x - from_grid.x` 先算出横向差值。
	# `absi(...)` 是整数绝对值函数。
	# 绝对值意思是：不管正负，只要距离大小。
	# 比如 -1 和 1 的绝对值都变成 1。

	var delta_y: int = absi(to_grid.y - from_grid.y)
	# 第 517 行：
	# `delta_y` 就是 y 方向相差多少格。

	if delta_x == 0 and delta_y == 0:
		# 第 520 行：
		# 如果横向差 0、纵向差也 0，
		# 说明点击的是玩家自己所在的格子。
		# 这种情况不算移动。
		return false
		# 第 525 行：
		# 返回 false，表示“不相邻可移动”。

	return delta_x <= 1 and delta_y <= 1
	# 第 528 行：
	# 如果横向最多差 1 格，纵向最多也差 1 格，
	# 那就说明目标在玩家周围 8 个格子范围内。
	# 这就符合“相邻移动”的规则。


func _draw_alert_mark(player_center: Vector2) -> void:
	# 第 533 行：
	# 这个工具函数专门负责画玩家头上的感叹号。
	# 参数 `player_center` 是玩家圆圈中心点的屏幕像素位置。

	var mark_top := player_center + Vector2(0, -CELL_SIZE * 0.75)
	# 第 538 行：
	# 这是感叹号竖线的顶部位置。
	# `Vector2(0, 负数)` 表示“只往上移动”。

	var mark_bottom := player_center + Vector2(0, -CELL_SIZE * 0.45)
	# 第 542 行：
	# 这是感叹号竖线的底部位置。

	draw_line(mark_top, mark_bottom, ALERT_COLOR, 4.0)
	# 第 545 行：
	# `draw_line(...)` 是画线函数。
	# 它会在顶部点和底部点之间画一条黄色竖线。

	var dot_center := player_center + Vector2(0, -CELL_SIZE * 0.32)
	# 第 549 行：
	# 这是感叹号底部那个小圆点的位置。

	draw_circle(dot_center, 4.0, ALERT_COLOR)
	# 第 552 行：
	# `draw_circle(...)` 会画一个实心小圆点。
	# 这样竖线 + 小圆点 合起来看起来就是感叹号。


func _draw_timer_text() -> void:
	# 第 556 行：
	# 这个工具函数负责画左上角计时器文字。

	var display_text := ""
	# 第 559 行：
	# `display_text` 表示“要显示的文字内容”。
	# 先给一个空字符串 `""`。
	# 字符串就是文字。

	var display_color := TIMER_IDLE_COLOR
	# 第 563 行：
	# `display_color` 表示“显示文字的颜色”。
	# 默认先设成蓝色，也就是操作阶段颜色。

	if is_executing:
		# 第 566 行：
		# 如果当前在执行阶段：

		display_text = "%.2fs" % TURN_INTERVAL
		# 第 569 行：
		# 这里使用了字符串格式化。
		# `"%.2fs"` 的意思是：
		# “把一个数字格式化成保留 2 位小数，并在后面加上字母 s”
		# `% TURN_INTERVAL` 的意思是把 `TURN_INTERVAL` 这个值填进去。
		# 所以结果会是 `"5.00s"`。

		display_color = TIMER_EXECUTING_COLOR
		# 第 575 行：
		# 执行阶段文字改成红色。

	else:
		# 第 578 行：
		# 如果不是执行阶段，那就是操作阶段。

		var elapsed: float = clampf(TURN_INTERVAL - timer.time_left, 0.0, TURN_INTERVAL)
		# 第 581 行：
		# `timer.time_left` 的意思是：当前这一轮还剩多少秒。
		# `TURN_INTERVAL - timer.time_left` 就得到：已经过去了多少秒。
		# `clampf(...)` 是浮点数版本的限制函数。
		# 它会把结果限制在最小 0.0、最大 TURN_INTERVAL 之间。
		# `: float` 表示这个变量类型明确是浮点数。
		# 白话意思：
		# “计算这一轮已经过去了多少秒，并保证它不会超出 0 到 5 这个范围。”

		display_text = "%.2fs" % snappedf(elapsed, 0.01)
		# 第 590 行：
		# `snappedf(elapsed, 0.01)` 的作用是：
		# 把数字对齐到 0.01 的精度，也就是保留两位小数的步进。
		# 然后再用 `"%.2fs"` 格式化成类似 `4.37s` 这样的字符串。

		display_color = TIMER_IDLE_COLOR
		# 第 595 行：
		# 操作阶段文字使用蓝色。

	draw_string(timer_font, Vector2(20, 40), display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, display_color)
	# 第 598 行：
	# `draw_string(...)` 是画文字的函数。
	# 参数可以先这样记：
	# - `timer_font`：用什么字体画
	# - `Vector2(20, 40)`：文字画在屏幕左上角附近的位置
	# - `display_text`：具体显示什么文字
	# - `HORIZONTAL_ALIGNMENT_LEFT`：左对齐
	# - `-1`：这里表示不限制宽度
	# - `28`：字体大小
	# - `display_color`：文字颜色
	# 白话意思：
	# “把计时器文字画在屏幕左上角。”

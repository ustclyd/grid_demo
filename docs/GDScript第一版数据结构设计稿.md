---
type: tech_design
title: GDScript第一版数据结构设计稿
status: draft
updated: 2026-03-26
---

# GDScript第一版数据结构设计稿

本文档用于把当前原型的规则文档，落成可编码的第一版 GDScript 数据结构与代码分层方案。

关联文档：
- [回合结算顺序说明（修订版第四版）](/d:/GameDev/grid_demo/docs/回合结算顺序说明（修订版第四版）.md)
- [回合执行表现顺序](/d:/GameDev/grid_demo/docs/回合执行表现顺序.md)

---

## 一、收口结论

本设计满足以下两类要求：

1. 数据结构要求
- `TileState` 只保存“这个格上有什么”以及它关联哪个门对
- 新增 `PortalPairState`，专门管理双向门对的共享状态
- `UnitState / ActionIntent / BagState / TileState / PortalPairState / GameState` 都包含你要求的核心字段

2. 代码结构要求
- `TurnResolver` 只负责规则结算
- `TurnPresentation` 只负责把结算结果转成表现事件序列
- `Main.gd` 或场景控制器只负责播放表现事件

当前设计不会把动画逻辑塞进规则函数。

---

## 二、推荐目录结构

```text
scripts/
  model/
    action_type.gd
    tile_type.gd
    playback_event_type.gd
    unit_state.gd
    action_intent.gd
    bag_state.gd
    tile_state.gd
    portal_pair_state.gd
    game_state.gd
    turn_result.gd
    playback_event.gd
  rules/
    turn_resolver.gd
  presentation/
    turn_presentation.gd
    turn_playback.gd
```

---

## 三、数据结构设计

## 3.1 结论

- 需要单独加“传送门对数据结构”
- 不建议只把过热参数塞进单个 `TileState`
- 原因：过热作用于“一对双向门”的两个入口整体，不是某一个单元格独立状态

## 3.2 推荐做法

- `TileState` 只保存“这个格上有什么”以及它关联哪个门对
- `PortalPairState` 专门管理：
  - 两个入口坐标
  - 当前是否过热
  - 剩余冷却回合
  - 是否已被玩家发现
  - UI 颜色标识

---

## 四、模型层类定义

以下内容是第一版推荐字段设计。这里是设计稿，不是最终实现代码。

## 4.1 `UnitState`

职责：
- 保存一个单位的真实规则状态

建议字段：

| 字段 | 含义 |
| --- | --- |
| `id` | 单位唯一标识 |
| `pos` | 当前格坐标 |
| `prev_pos` | 上一回合所在格，用于砸回；若本回合开始先传送，则记录传送前的门格 |
| `coins` | 当前持币 |
| `entry_coins` | 入场带入金币，用于同金币时比较 |
| `alive` | 是否存活 |
| `won` | 是否已撤离成功 |
| `forced_stay_turns` | 剩余强制待机回合数 |
| `queued_teleport_to` | 下一回合开始时的预约传送目标 |
| `queued_exit` | 下一回合开始时是否执行撤离 |
| `teleported_this_turn` | 本回合开始时是否刚通过 `portal` 传送，用于调试与判定追踪 |
| `discovered_portal_ids` | 该玩家已经乘坐并记录过的传送门对 ID 列表 |

推荐草稿：

```gdscript
class_name UnitState
extends RefCounted

var id: int
var pos: Vector2i
var prev_pos: Vector2i

var coins: int = 0
var entry_coins: int = 0

var alive: bool = true
var won: bool = false

var forced_stay_turns: int = 0

var queued_teleport_to: Vector2i
var has_queued_teleport: bool = false

var queued_exit: bool = false
var teleported_this_turn: bool = false

var discovered_portal_ids: Array[int] = []
```

## 4.2 `ActionIntent`

职责：
- 保存一个单位本回合最终提交的动作意图

建议字段：

| 字段 | 含义 |
| --- | --- |
| `actor_id` | 执行动作的单位 ID |
| `type` | `MOVE / STAY / PICK / THROW` |
| `target_pos` | 移动或投掷目标格 |
| `target_bag_id` | `PICK` 的目标钱袋 |
| `throw_amount` | 本回合扔出的金币数量 |

推荐草稿：

```gdscript
class_name ActionIntent
extends RefCounted

var actor_id: int
var type: String = ActionType.STAY

var target_pos: Vector2i
var target_bag_id: int = -1
var throw_amount: int = 0
```

## 4.3 `BagState`

职责：
- 保存地图上一个钱袋的真实状态

建议字段：

| 字段 | 含义 |
| --- | --- |
| `id` | 钱袋唯一标识 |
| `pos` | 所在格坐标 |
| `coins` | 钱袋金币数 |
| `is_throw_bag` | 是否为本回合投掷生成的钱袋 |
| `is_ultimate_bag` | 是否为终极钱袋 |

推荐草稿：

```gdscript
class_name BagState
extends RefCounted

var id: int
var pos: Vector2i
var coins: int = 0

var is_throw_bag: bool = false
var is_ultimate_bag: bool = false
```

## 4.4 `TileState`

职责：
- 保存单个格子的地形/环境状态

建议字段：

| 字段 | 含义 |
| --- | --- |
| `pos` | 格坐标 |
| `tile_type` | 普通格 / `portal` / `exit_portal` |
| `portal_pair_id` | 若该格是普通传送门入口，则记录所属双向门对 ID |
| `portal_color_id` | 后期表现层可用的颜色标识 |
| `has_storm` | 该格是否已被风暴吞噬 |

推荐草稿：

```gdscript
class_name TileState
extends RefCounted

var pos: Vector2i
var tile_type: String = TileType.NORMAL

var portal_pair_id: int = -1
var portal_color_id: int = -1

var has_storm: bool = false
```

## 4.5 `PortalPairState`

职责：
- 管理一对双向普通传送门的共享状态

建议字段：

| 字段 | 含义 |
| --- | --- |
| `id` | 传送门对唯一标识 |
| `entry_a` | 入口 A 坐标 |
| `entry_b` | 入口 B 坐标 |
| `cooldown_turns` | 剩余冷却回合数 |
| `is_overheated` | 是否处于过热状态 |
| `color_id` | 该门对的表现颜色 ID |
| `discovered_by_player_ids` | 哪些玩家已发现这对门 |

说明：
- `is_overheated` 和 `cooldown_turns` 有信息重叠
- 第一版可以保留两者，方便读代码
- 后续若觉得重复，可只保留 `cooldown_turns`

推荐草稿：

```gdscript
class_name PortalPairState
extends RefCounted

var id: int
var entry_a: Vector2i
var entry_b: Vector2i

var cooldown_turns: int = 0
var is_overheated: bool = false

var color_id: int = -1
var discovered_by_player_ids: Array[int] = []
```

## 4.6 `GameState`

职责：
- 保存整张地图与整局游戏的真实状态

建议字段：

| 字段 | 含义 |
| --- | --- |
| `turn_index` | 当前回合数 |
| `storm_active` | 风暴是否已启动 |
| `storm_center` | 风暴中心格 |
| `storm_radius` | 当前风暴扩散半径 |
| `storm_expand_every_turns` | 风暴每几回合扩散一次 |
| `ultimate_bag_id` | 当前终极钱袋 ID |
| `exit_portal_tile` | 当前撤离门所在格 |
| `portal_pairs` | 当前地图中的所有双向传送门对 |

第一版推荐补充字段：
- `board_size`
- `units`
- `bags`
- `tiles`

推荐草稿：

```gdscript
class_name GameState
extends RefCounted

var board_size: Vector2i = Vector2i(7, 7)
var turn_index: int = 0

var units: Array[UnitState] = []
var bags: Array[BagState] = []
var tiles: Array[TileState] = []
var portal_pairs: Array[PortalPairState] = []

var storm_active: bool = false
var storm_center: Vector2i
var storm_radius: int = 0
var storm_expand_every_turns: int = 2

var ultimate_bag_id: int = -1
var exit_portal_tile: Vector2i
```

---

## 五、代码分层设计

以下部分用于满足你要求的“三层结构”。

## 5.1 `TurnResolver`

职责：
- 只计算规则结果
- 输入 `GameState + intents`
- 输出“本回合结算结果”

不负责：
- Tween
- 节点动画
- UI 播放顺序
- 等待时间

说明：
- `TurnResolver` 必须只处理规则真相
- 不依赖 `Node2D`、`Timer`、`Tween`、`AnimationPlayer`

推荐入口：

```gdscript
class_name TurnResolver
extends RefCounted

func resolve_turn(state: GameState, intents: Array[ActionIntent]) -> TurnResult:
	var result := TurnResult.new()
	result.state_before = state
	result.intents = intents

	# 这里按回合结算文档顺序实现
	# 0. 下一回合开始前处理
	# 1. intent 收集
	# 2. PICK/THROW 资源变化
	# 3. 理论目标格
	# 4. 环境致死
	# 5. 冲突判定1
	# 6. 砸回
	# 7. 冲突判定2
	# 8. 死亡掉落
	# 9. 强制待机
	# 10. 传送预约
	# 11. 撤离预约
	# 12. 地图事件

	result.state_after = state
	return result
```

## 5.2 `TurnResult`

职责：
- 统一承接一次规则结算的结果
- 给 `TurnPresentation` 提供稳定输入

推荐草稿：

```gdscript
class_name TurnResult
extends RefCounted

var state_before: GameState
var state_after: GameState

var intents: Array[ActionIntent] = []

var moved_unit_ids: Array[int] = []
var teleported_unit_ids: Array[int] = []
var knocked_back_unit_ids: Array[int] = []
var dead_unit_ids: Array[int] = []

var picked_bag_records: Array[Dictionary] = []
var thrown_bag_records: Array[Dictionary] = []
var dropped_bag_ids: Array[int] = []

var forced_stay_unit_ids: Array[int] = []
var portal_ready_unit_ids: Array[int] = []
var exit_ready_unit_ids: Array[int] = []
var overheated_portal_pair_ids: Array[int] = []
```

说明：
- `TurnResult` 属于规则层输出，不属于表现层
- 后续如果需要更强类型，可以把 `Dictionary` 进一步拆成结构类

## 5.3 `TurnPresentation`

职责：
- 把 `TurnResolver` 的结算结果转换为“表现事件序列”
- 例如：
  - `show_intent`
  - `move_unit`
  - `throw_bag`
  - `pick_bag`
  - `conflict1_result`
  - `knockback_unit`
  - `conflict2_result`
  - `drop_bag`
  - `teleport_unit`
  - `exit_unit`

不负责：
- 真正修改规则状态
- 决定谁活谁死

推荐草稿：

```gdscript
class_name TurnPresentation
extends RefCounted

func build_events(turn_result: TurnResult) -> Array[PlaybackEvent]:
	var events: Array[PlaybackEvent] = []
	return events
```

## 5.4 `PlaybackEvent`

职责：
- 表示一个可播放的表现事件

推荐草稿：

```gdscript
class_name PlaybackEvent
extends RefCounted

var type: String
var start_time: float = 0.0
var duration: float = 0.0

var unit_id: int = -1
var bag_id: int = -1
var portal_pair_id: int = -1

var from_pos: Vector2i
var to_pos: Vector2i

var amount: int = 0
var extra: Dictionary = {}
```

## 5.5 `TurnPlayback`

职责：
- 按顺序播放 `TurnPresentation` 生成的表现事件
- 真正驱动 `Tween / Timer / AnimationPlayer`

说明：
- `TurnPlayback` 只播，不算规则
- 它可以是单独脚本，也可以挂在场景控制节点上

推荐草稿：

```gdscript
class_name TurnPlayback
extends RefCounted

func play(main_node: Node, events: Array[PlaybackEvent]) -> void:
	pass
```

## 5.6 `Main.gd` 或场景控制器

职责：
- 驱动 `Tween / Timer / AnimationPlayer`
- 按顺序播放 `TurnPresentation` 生成的表现事件
- 播放完成后再进入下一回合输入阶段

说明：
- `Main.gd` 不应该再自己承担规则结算逻辑
- 它应该成为“输入、调度、播放”的上层控制器

推荐流程：

1. 收集玩家输入，生成 `ActionIntent`
2. 调用 `TurnResolver.resolve_turn(...)`
3. 调用 `TurnPresentation.build_events(...)`
4. 调用 `TurnPlayback.play(...)`
5. 播放完成后，把场景刷新到 `TurnResult.state_after`
6. 进入下一回合输入阶段

---

## 六、与现有要求的逐项对照

## 6.1 数据结构要求检查

`UnitState`
- 满足

`ActionIntent`
- 满足

`BagState`
- 满足

`TileState`
- 满足

`PortalPairState`
- 满足

`GameState`
- 满足

额外说明：
- `GameState` 在你要求的字段基础上补了 `board_size / units / bags / tiles`
- 这是必要补充，否则无法承载整局状态

## 6.2 代码结构要求检查

`TurnResolver`
- 满足“只算规则结果”

`TurnPresentation`
- 满足“把规则结果转成表现事件序列”

`TurnPlayback`
- 满足“负责播放，不负责规则”

`Main.gd`
- 满足“驱动播放并控制回合推进”

额外说明：
- 这里把你原文里的 “TurnPresentation 或 TurnPlayback” 拆成两层
- 这是更稳的做法
- 如果你想简化，第一版也可以先把两者合并成一个类

---

## 七、第一版实现建议

为了避免你一下子改太多，建议按下面顺序落地：

1. 先建模型类
- `UnitState`
- `ActionIntent`
- `BagState`
- `TileState`
- `PortalPairState`
- `GameState`

2. 再建规则结果类
- `TurnResult`

3. 再建规则层
- `TurnResolver`

4. 再建表现层
- `PlaybackEvent`
- `TurnPresentation`
- `TurnPlayback`

5. 最后才改 `Main.gd`
- 把它从“规则脚本”改成“场景调度器”

---

## 八、当前判断

这份设计已经满足你刚列出的两组硬性要求：

- 符合“回合结算顺序说明”的数据结构字段
- 符合“TurnResolver / TurnPresentation / Main.gd” 的分层要求

如果后面要继续推进，下一步最合理的不是继续补文档，而是开始创建这些脚本骨架。

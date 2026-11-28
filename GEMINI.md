# Grid Demo 项目规则（Antigravity Workspace Rules）

## 1. 项目定位与设计理念
- **项目**：`grid_demo`（Godot 4.6.1 / GDScript / 2D 确定性方格解谜）。
- **核心方向**：做成一关一关的数学味棋盘谜题（参考《14 种扫雷变体》的清晰规则、《Tiling Town》的结构推理、《Opus Magnum》的先首通后最优）。
- **视觉与交互原则**：保留手动回合、公开意图、可见余额与棋子状态；界面只展示意图、状态与结果，不承载规则计算。

## 2. 本机关键路径
- **游戏仓库**：`D:\GameDev\grid_demo`（当前开发分支 `puzzle-prototype`，远端 `ustclyd/grid_demo`；旧原型留存于 `refactor-turn-model` 分支 `b18623d`）。
- **Godot 编辑器**：`D:\Godot\Godot_v4.6.1-stable_win64.exe`
- **Godot 控制台（无头测试）**：`D:\Godot\Godot_v4.6.1-stable_win64_console.exe`
- **Obsidian 笔记仓库**：`D:\仓库\游戏开发`
  - 开发交接：`01-项目管理\Grid Demo 开发交接.md`
  - 设计手册：`01-项目管理\Grid Demo 游戏设计手册\Grid Demo 游戏设计手册.md`
  - 每日开发日志：`10-开发日志\YYYY\YYYY-MM\YYYY-MM-DD.md`（模板：`90-模板\每日开发记录模板.md`）
- **仓库内设计文档**：`docs/谜题关卡与敌人设计.md`、`docs/README_提交流程.md`、`docs/README_PowerShell脚本讲义.md`。

## 3. 核心规则与架构红线
- **回合结算顺序**（以 `scripts/rules/turn_resolver.gd` 为准）：
  1. 敌人与玩家基于同一回合起点的棋盘确定意图；
  2. 投掷扣币（余额 ≥ 2，投出 `floor(coins / 2)`）并落袋；
  3. 同步走位（默认八方向一格，支持换位）；
  4. 首次同格冲突（主动待机优先 > 非硬直优先 > 当前持币少 > 入场持币少 > 单位 ID 小）；
  5. 批量击退（基于首次冲突后的同一棋盘：主动待机沿投掷方向推 1 格，移动/投掷回本轮起点，已硬直留原格；同向多袋推 1 格，异向抵消）；
  6. 二次冲突（常规排序，无主动待机优先）；
  7. 死亡掉币；
  8. 自动拾币与精确余额金库开启（先收散币/掉落，再判精确余额开库；硬直开局、本轮投手、被推离目标者不具备拾取资格）；
  9. 更新硬直与地图附加状态，判定胜负（金币全收 / 路线终点 / 同步压板）。
- **统一入口**：实玩 UI（`PuzzleLevelView`）、敌人策略（`PuzzleEnemyPolicy`）与 BFS 审计求解器（`scripts/tests/puzzle_state_audit.gd`）必须共用 `PuzzleSession` / `TurnResolver`；若新增带记忆的敌人或地图机制，必须同步纳入快照、`fork()` 和求解状态键。

## 4. 协作方式与教学约定
- **先对齐再动手**：讨论规则改动或新系统前，先评估与现有规则的潜在冲突、举具体棋盘案例并明确预期；确认后再封装实现与补自动测试。
- **边做边教**：写代码、改架构或跑命令时，主动给出可复现命令与预期结果，并简明解释涉及的 GDScript 语法、设计模式、PowerShell 机制或游戏项目管理思路，帮助用户持续提升技术与项目管理能力。
- **关卡开发双 Agent 工作法**：设计新关卡时，区分“出题与参考解/活局死路分析”和“只看题面与公开规则的独立盲解”，最后用生产 `PuzzleSession` 跑回放与状态审计，并交由用户实玩定标难度。

## 5. 验证、日志与 Git 同步流程
- **运行测试**：新增脚本或切换工作区时先运行 `& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\GameDev\grid_demo' --import`。改动共享规则后跑相关回归测试（`stay_push_smoke`、`auto_pickup_smoke`、`portal_bag_smoke` 及受影响的 `puzzle_level*_smoke`），确保全部退出码为 `0`。
- **过程日志**：每个有结果的阶段（`Design` / `Implementation` / `Test` / `Sync`）用 `grid-demo-workflow` 技能的 `Add-GridDemoLog.ps1` 追加记录到当日 Obsidian 日志。
- **审慎提交**：只暂存本轮明确交付的文件，提交前检查 `git diff --cached --check` 与 `git diff --cached`；提交后确认 `.git/hooks/post-commit` 调用 `scripts/update_obsidian_log.ps1` 已写入当日日志的「今日提交」。不为了记日志做空提交。
- **推送远端**：当用户要求 `push` 时，在项目根目录执行：
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_commit.ps1 -PushOnly
  git ls-remote --symref origin HEAD refs/heads/puzzle-prototype
  ```
  核验 `origin/puzzle-prototype` 与远端默认分支哈希一致并记录实际提交号。

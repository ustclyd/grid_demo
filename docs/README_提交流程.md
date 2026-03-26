# 提交流程

这份文档是给完全新手准备的。
你以后每次改完代码，只要照着这里的步骤做，就能：

1. 提交本地代码
2. 自动写入 Obsidian 开发日志
3. 在需要的时候把代码上传到 GitHub

## 0. 你要先知道的事

你现在已经有两份可用脚本：

- [dev_commit.ps1](d:\GameDev\grid_demo\scripts\dev_commit.ps1)
- [update_obsidian_log.ps1](d:\GameDev\grid_demo\scripts\update_obsidian_log.ps1)

它们的关系是：

- 你平时手动运行的是 `dev_commit.ps1`
- `dev_commit.ps1` 负责执行 Git 提交
- Git 提交成功后，会自动触发 `update_obsidian_log.ps1`
- `update_obsidian_log.ps1` 负责写 Obsidian 开发日志

所以你平时不需要手动运行日志脚本。

## 1. 以后用什么终端

以后你可以直接用：

- `VS Code`
- 底部终端
- `PowerShell`

一般来说，不需要专门再开 `Git Bash`。

## 2. 每次提交之前，先怎么打开终端

按下面顺序做：

1. 打开 `VS Code`
2. 打开你的项目文件夹 `D:\GameDev\grid_demo`
3. 看顶部菜单栏
4. 点击 `终端`
5. 点击 `新建终端`

这时 VS Code 底部会弹出一个终端窗口。

如果你看到类似：

```powershell
PS D:\GameDev\grid_demo>
```

说明你已经在正确目录里了。

如果你看到的不是这个路径，比如：

```powershell
PS C:\Users\你的名字>
```

那就输入：

```powershell
cd D:\GameDev\grid_demo
```

然后按回车。

## 3. 每次改完代码后，第一步做什么

先输入：

```powershell
git status
```

然后按回车。

这句的作用是：

- 看哪些文件改了
- 看当前 Git 状态正不正常
- 确认你是在正确的仓库里

这是你以后最常用的检查命令。

## 4. 最推荐的提交方法

### 4.1 只提交，不上传 GitHub

在终端里输入：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_commit.ps1 -Message "这里写本次修改说明"
```

例如：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_commit.ps1 -Message "feat: 完成玩家相邻格移动"
```

输入后按回车。

这句会自动做这些事：

1. `git add .`
2. `git commit -m "..."`
3. commit 成功后自动写入 Obsidian 日志

### 4.2 提交并上传 GitHub

如果你这次还想顺手上传到 GitHub，就输入：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_commit.ps1 -Message "这里写本次修改说明" -Push
```

例如：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_commit.ps1 -Message "fix: 修复日志脚本" -Push
```

这句会自动做：

1. `git add .`
2. `git commit -m "..."`
3. 自动写入 Obsidian 日志
4. `git push`

## 5. 为什么命令前面要写这么长一串 PowerShell

你现在不能直接运行：

```powershell
.\scripts\dev_commit.ps1 -Message "..."
```

因为你的系统默认禁止直接运行 `.ps1` 脚本。

所以我们现在固定用这种方式：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_commit.ps1 -Message "..."
```

它的意思是：

- 启动一个新的 PowerShell 进程
- 临时绕过脚本执行限制
- 然后运行你指定的脚本文件

你现在不用去改系统设置，直接记住这条命令就够了。

## 6. 每次提交后的检查方法

### 6.1 检查 Git 提交是否成功

如果提交成功，终端通常会看到类似：

```text
[master abc1234] feat: 某个功能
 1 file changed, 10 insertions(+), 2 deletions(-)
```

重点看这一行：

```text
[master abc1234] ...
```

只要看到这一行，通常就说明 commit 已经成功了。

### 6.2 检查 Obsidian 日志是否成功写入

去打开今天的开发日志文件。

路径规则是：

```text
D:\obsidian\仓库\游戏开发\10-开发日志\YYYY\YYYY-MM\YYYY-MM-DD.md
```

比如今天是 `2026-03-25`，那就是：

```text
D:\obsidian\仓库\游戏开发\10-开发日志\2026\2026-03\2026-03-25.md
```

打开之后，找到：

```md
#### 六、Git 记录
##### 今日提交
```

下面应该会多出一条类似：

```md
- [x] `abc1234` 2026-03-25 15:30:00 [master] feat: 某个功能 | files: scripts/Main.gd
```

如果有，说明日志写入成功。

## 7. 如果命令报错了，先怎么判断是哪一步错了

### 情况 A：看到了 `[master xxxx] ...`

这表示：

- Git commit 成功了

如果后面又出现红字报错，那通常是：

- commit 后自动执行的日志脚本出了问题

也就是：

- 提交成功
- 写日志失败

### 情况 B：根本没有看到 `[master xxxx] ...`

这表示 commit 本身就失败了。

这时应该优先检查：

- `git status`
- 提交说明有没有写好
- 是否有冲突或其他 Git 错误

### 情况 C：提交成功了，但 `-Push` 时报错

这表示：

- 本地提交成功
- 上传 GitHub 失败

常见原因是：

- 没配置远程仓库
- 没登录 GitHub
- 网络问题

## 8. 你以后最短记忆版

### 普通提交

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_commit.ps1 -Message "本次修改说明"
```

### 提交并上传 GitHub

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_commit.ps1 -Message "本次修改说明" -Push
```

## 9. 一次完整示例

假设你刚改完 `scripts/Main.gd`，准备提交。

你应该这样做：

1. 打开 VS Code
2. 顶部点击 `终端`
3. 点击 `新建终端`
4. 在底部终端输入：

```powershell
cd D:\GameDev\grid_demo
```

5. 回车
6. 输入：

```powershell
git status
```

7. 回车
8. 输入：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_commit.ps1 -Message "feat: 调整玩家移动逻辑"
```

9. 回车
10. 看终端是否出现 `[master xxxx] ...`
11. 去 Obsidian 打开今天日志，检查是否写入成功

## 10. 如果你只想先测试脚本是否正常

可以做一个空提交测试：

```powershell
git commit --allow-empty -m "test hook"
```

或者直接用你的提交流程脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_commit.ps1 -Message "test hook"
```

## 11. 你以后最推荐的固定流程

每次改完代码以后：

1. 打开 VS Code 底部终端
2. 输入：
   ```powershell
   git status
   ```
3. 然后输入：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_commit.ps1 -Message "本次修改说明"
   ```
4. 如果这次要上传 GitHub，就加 `-Push`

就这么简单。

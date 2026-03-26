# PowerShell 脚本讲义

这份文档专门解释这两个脚本：

- [dev_commit.ps1](d:\GameDev\grid_demo\scripts\dev_commit.ps1)
- [update_obsidian_log.ps1](d:\GameDev\grid_demo\scripts\update_obsidian_log.ps1)

注意：

- 这份文档是“讲义版”
- 目的是帮助你理解脚本的作用和 PowerShell 基础语法
- 不再把大量中文解释写回脚本本体，避免因为编码问题把脚本弄坏

## 1. 这两个脚本分别干什么

### `dev_commit.ps1`

这是“提交入口脚本”。

你平时主动运行的是它。

它做的事情很简单：

1. `git add .`
2. `git commit -m "你的说明"`
3. 如果你写了 `-Push`，再执行 `git push`

你可以把它理解成：

> “把我平时最常做的提交动作打包成一个命令”

### `update_obsidian_log.ps1`

这是“日志自动记录脚本”。

你平时不是手动运行它，而是它会在 commit 成功后被 Git 自动触发。

它负责：

1. 读取最近一次 commit 的信息
2. 找到今天的 Obsidian 日志文件
3. 如果今天日志不存在，就用模板创建
4. 初始化环境记录
5. 把这次 commit 写进“六、Git 记录”

你可以把它理解成：

> “每次 commit 后，自动帮我更新开发日志”

## 2. 它们两个怎么串起来工作

工作顺序是：

1. 你手动运行 `dev_commit.ps1`
2. `dev_commit.ps1` 执行 `git commit`
3. Git commit 成功
4. Git 的 `post-commit hook` 自动运行
5. hook 调用 `update_obsidian_log.ps1`
6. 日志文件被更新

所以这不是两个互相独立的脚本，而是一前一后配合工作。

## 3. `dev_commit.ps1` 逐段讲解

### 参数区

脚本开头会有：

```powershell
param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [switch]$Push
)
```

这段的意思是：

- 这个脚本运行时可以接收参数
- `-Message` 是必须写的
- `-Push` 是可选开关

#### 语法解释

`param(...)`

- 表示“脚本参数声明区”
- 告诉 PowerShell：这个脚本运行时可以接收哪些输入

`[string]$Message`

- `[string]` 表示参数类型是字符串
- `$Message` 是变量名
- 它会保存你的提交说明

`[switch]$Push`

- `[switch]` 表示这是一个布尔开关参数
- 写了 `-Push` 就相当于 true
- 不写就相当于 false

`[Parameter(Mandatory = $true)]`

- 这是参数附加设置
- 表示这个参数是必填项

### 错误控制

```powershell
$ErrorActionPreference = "Stop"
```

意思是：

- 只要遇到错误
- 就立刻停止脚本

目的是避免前面失败了，后面还继续执行。

### 执行 Git 命令

```powershell
git add .
git commit -m $Message
```

这两句分别表示：

- 把当前目录所有改动加入暂存区
- 用 `$Message` 做一次提交

### 检查 commit 是否失败

```powershell
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
```

#### 语法解释

`if (...) { ... }`

- 条件判断
- 如果括号里的条件成立，就执行花括号中的代码

`$LASTEXITCODE`

- PowerShell 特殊变量
- 表示刚刚那个外部命令的退出码

`-ne`

- 不等于

所以整句白话是：

> 如果刚才的 git commit 失败了，就立刻退出脚本

### 可选 push

```powershell
if ($Push) {
    git push
    exit $LASTEXITCODE
}
```

意思是：

- 如果你运行脚本时写了 `-Push`
- 就在 commit 后继续执行 `git push`

## 4. `update_obsidian_log.ps1` 逐段讲解

### 参数区

```powershell
param(
    [string]$VaultRoot = "",
    [string]$TemplatePath = ""
)
```

意思是：

- 这个脚本也能接收参数
- `VaultRoot` 表示 Obsidian 仓库根目录
- `TemplatePath` 表示模板文件路径
- 如果你不传，它后面会自动补默认值

### 默认路径函数

脚本里有这种函数：

```powershell
function Get-DefaultVaultRoot { ... }
function Get-DefaultTemplatePath { ... }
```

意思是：

- 如果你没手动传路径
- 就由这些函数帮你算出默认路径

### 为什么要用 Unicode 拼中文

脚本里你会看到：

```powershell
function New-UnicodeString { ... }
```

和这种写法：

```powershell
New-UnicodeString @(0x4ED3, 0x5E93)
```

原因是：

- 你当前环境里，PowerShell 脚本本体写很多中文容易被编码搞坏
- 所以脚本里尽量不用直接写中文
- 改成用 Unicode 码点在运行时拼出中文

你可以把它理解成：

> “源码里先存数字，运行时再变回中文”

### `Get-CommitInfo`

这个函数负责读最近一次 commit 的信息。

它会拿到：

- 短 hash
- 标题
- 正文
- 分支名
- 当前时间
- 改动文件列表

### `Get-DailyLogPath`

这个函数负责按日期生成日志路径。

比如：

- 年：`2026`
- 月：`2026-03`
- 日：`2026-03-25`

最后拼成：

```text
D:\obsidian\仓库\游戏开发\10-开发日志\2026\2026-03\2026-03-25.md
```

### `New-DailyLogFromTemplate`

这个函数负责：

- 如果今天日志不存在
- 就复制模板
- 替换掉模板里的日期占位符
- 生成今天的新日志文件

### `Initialize-DailyLogEnvironmentSection`

这个函数负责第一次创建日志后，自动填写一部分环境信息，例如：

- Git 版本
- VS Code 版本
- Godot 版本
- Git 路径
- 项目目录

### `Write-CommitEntryToDailyLog`

这个函数负责把 commit 真正写进日志。

它会：

1. 找到 `六、Git 记录`
2. 找到 `今日提交`
3. 跳过模板占位行
4. 插入新的 commit 记录

最后写出的效果类似：

```md
- [x] `abc1234` 2026-03-25 15:30:00 [master] feat: 调整移动逻辑 | files: scripts/Main.gd
```

## 5. 你现在最该记住的 PowerShell 基础语法

### 变量

PowerShell 变量以 `$` 开头：

```powershell
$Message
$VaultRoot
$LASTEXITCODE
```

### 参数

脚本参数写在：

```powershell
param(...)
```

### 条件判断

```powershell
if (条件) {
    执行这里
}
```

### 函数

```powershell
function 函数名 {
    代码
}
```

### 返回值

```powershell
return 某个值
```

### 注释

```powershell
# 这是注释
```

注意：

- `#` 后面这一整行都会被当成注释
- 所以代码不能写到注释同一行后面
- 这也是你前面脚本反复报语法错的重要原因之一

## 6. 这次你踩过的坑，最关键是什么

最关键的一点就是：

> 在 PowerShell 脚本里，注释和代码一定要分行

例如这是错的思路：

```powershell
# 这是注释 param(
```

因为 `param(` 也会被当成注释的一部分，PowerShell 根本看不到。

正确做法是：

```powershell
# 这是注释
param(
```

## 7. 你以后怎么理解这两个脚本

最简单的记法：

- `dev_commit.ps1`
  你手动点的“提交按钮”

- `update_obsidian_log.ps1`
  提交成功后自动帮你写日志的“后台助手”

## 8. 你以后实际怎么用

普通提交：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_commit.ps1 -Message "本次修改说明"
```

提交并上传 GitHub：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_commit.ps1 -Message "本次修改说明" -Push
```

## 9. 你现在应该怎么继续学

建议顺序：

1. 先熟悉 `git status`
2. 再熟悉 `dev_commit.ps1` 的使用
3. 再理解 `param`、`if`、`function`
4. 最后再回来看 `update_obsidian_log.ps1`

因为第二个脚本明显更复杂，不适合一开始就死啃。

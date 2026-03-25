# 提交流程

这份说明是给完全没用过命令行的新手准备的。你以后每次改完代码，基本照着这份文档做就可以。

## 1. 用什么工具

以后你可以直接用 `PowerShell`，不必专门开 `Git Bash`。

最推荐的方式是：

1. 打开 `VS Code`
2. 打开你的项目文件夹 `D:\GameDev\grid_demo`
3. 点击顶部菜单 `终端`
4. 点击 `新建终端`
5. 底部出现一个终端窗口

如果终端前面显示的是：

```powershell
PS D:\GameDev\grid_demo>
```

说明你已经在正确的地方了。

如果不是这个路径，就输入：

```powershell
cd D:\GameDev\grid_demo
```

然后按回车。

## 2. 每次改完代码后先做什么

先看一眼 Git 状态，输入：

```powershell
git status
```

这句的作用是：

- 看哪些文件被改了
- 看哪些文件还没提交
- 确认当前 Git 仓库状态正常

这是你以后最常用的第一句。

## 3. 最推荐的提交方式

你现在已经有一个提交脚本：

```powershell
.\scripts\dev_commit.ps1 -Message "这里写本次改动说明"
```

比如：

```powershell
.\scripts\dev_commit.ps1 -Message "feat: 完成相邻格移动逻辑"
```

这句会自动做这些事：

1. `git add .`
2. `git commit -m "你的说明"`
3. commit 成功后自动写入 Obsidian 当日日志

## 4. 如果这次还想顺手上传 GitHub

就在命令后面加 `-Push`：

```powershell
.\scripts\dev_commit.ps1 -Message "fix: 修复计时器和日志脚本" -Push
```

这句会自动做：

1. `git add .`
2. `git commit -m "..."`
3. 自动写入 Obsidian 日志
4. `git push`

## 5. 如果你想手动一步一步做

也可以，不用脚本，直接输入：

```powershell
git status
git add .
git commit -m "这里写本次改动说明"
```

如果还要上传 GitHub，再输入：

```powershell
git push
```

注意：

- 你就算手动用 `git commit -m "..."`，Obsidian 日志也还是会自动写
- 因为仓库里已经装了 `post-commit` hook

## 6. 提交说明怎么写

建议你每次 commit 都写清楚“这次到底改了什么”。

常见写法：

```text
feat: 新增一个功能
fix: 修复一个问题
refactor: 重构代码但不改功能
docs: 修改文档
setup: 配置环境
```

例子：

```powershell
.\scripts\dev_commit.ps1 -Message "feat: 实现玩家每 5 秒结算一次移动"
.\scripts\dev_commit.ps1 -Message "fix: 修复 Obsidian 日志脚本编码问题"
.\scripts\dev_commit.ps1 -Message "docs: 新增提交流程说明"
```

## 7. 一次完整示例

假设你刚改完 `Main.gd`，准备提交。

在 VS Code 底部 PowerShell 终端输入：

```powershell
git status
.\scripts\dev_commit.ps1 -Message "feat: 调整玩家移动规则"
```

如果你这次还想同步 GitHub：

```powershell
git status
.\scripts\dev_commit.ps1 -Message "feat: 调整玩家移动规则" -Push
```

## 8. 如果提交后想确认有没有成功

输入：

```powershell
git log --oneline -5
```

这句会显示最近 5 次提交。

如果你看到刚才写的提交说明，说明提交成功了。

然后再去 Obsidian 打开今天的日志文件，检查：

- 是否写到了 `六、Git 记录`
- 是否新增了一条提交记录

## 9. 如果报错了先看哪

如果命令执行后报错，先看错误属于哪一类：

- `git` 报错：通常是 Git 命令本身问题
- `powershell` 报错：通常是脚本问题
- `push` 报错：通常是 GitHub 远程仓库或登录问题
- Obsidian 日志没写进去：通常是 hook 或路径权限问题

如果你看不懂报错，不要自己乱改。把终端完整报错复制出来，再处理。

## 10. 以后最短操作版本

以后你只要记住下面两句就够了。

普通提交：

```powershell
.\scripts\dev_commit.ps1 -Message "本次修改说明"
```

提交并上传 GitHub：

```powershell
.\scripts\dev_commit.ps1 -Message "本次修改说明" -Push
```

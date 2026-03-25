# 这份脚本是“Obsidian 开发日志自动记录脚本”。
#
# 它会在每次 Git commit 成功后自动运行。
# 运行流程是：
# 1. 读取最近一次 commit 的信息
# 2. 根据当天日期，计算出今天的日志文件路径
# 3. 如果今天的日志还不存在，就先根据模板创建
# 4. 如果是新文件，就顺手填一下“环境记录”
# 5. 最后把这次 commit 信息写进“六、Git 记录 / 今日提交”
#
# 你可以把它理解成：
# “每次 commit 后，自动帮我记开发日志”

param(
    # 这里是脚本参数区。
    # 这两个参数都不是必须写的。
    # 如果你不传，它后面会自己用默认路径。

    [string]$VaultRoot = "",
    # `$VaultRoot` 表示 Obsidian 仓库根目录。
    # 默认值先写成空字符串。
    # 如果运行脚本时没有主动传这个参数，后面会自动计算默认路径。

    [string]$TemplatePath = ""
    # `$TemplatePath` 表示模板文件路径。
    # 同样先给空字符串，后面再补默认值。
)

$ErrorActionPreference = "Stop"
# 遇到错误就停止。
# 这样能避免“前面失败了，后面还继续写文件”。

function New-UnicodeString {
    # 这个函数负责：
    # “把一组 Unicode 码点数字，转成真正的字符串”
    #
    # 为什么要这样写？
    # 因为你之前直接把中文写在 PowerShell 源码里，容易被编码搞坏。
    # 现在改成源码里只写数字，运行时再拼出中文，稳定很多。

    param(
        [int[]]$CodePoints
        # `[int[]]` 表示“整数数组”。
        # 例如：
        # @(0x4ED3, 0x5E93)
        # 就是一组整数数组。
    )

    return (-join ($CodePoints | ForEach-Object { [char]$_ }))
    # 这里分三步理解：
    #
    # `ForEach-Object { [char]$_ }`
    #   把数组里的每一个整数都转成字符
    #
    # `$_`
    #   表示当前遍历到的那个元素
    #
    # `-join (...)`
    #   把这些字符拼成一个完整字符串
}

function Add-Prefix {
    # 这个函数负责：
    # “给一段 Unicode 拼出来的中文前后加上固定前缀或后缀”

    param(
        [string]$Prefix,
        [int[]]$CodePoints,
        [string]$Suffix = ""
    )
    # 这里有 3 个参数：
    #
    # `$Prefix`
    #   前缀，比如 `##### `
    #
    # `$CodePoints`
    #   中间那段中文的 Unicode 数组
    #
    # `$Suffix`
    #   后缀，默认是空字符串

    return $Prefix + (New-UnicodeString $CodePoints) + $Suffix
    # 把“前缀 + 中文 + 后缀”拼成完整字符串。
}

function Get-DefaultVaultRoot {
    # 这个函数返回你的默认 Obsidian 仓库根目录。

    $warehouse = New-UnicodeString @(0x4ED3, 0x5E93)
    $gameDev = New-UnicodeString @(0x6E38, 0x620F, 0x5F00, 0x53D1)

    return Join-Path "D:\obsidian" (Join-Path $warehouse $gameDev)
    # `Join-Path` 用来拼接路径。
    # 比直接手写字符串路径更稳。
}

function Get-DefaultTemplatePath {
    # 这个函数返回默认模板路径。

    $templateFolder = New-UnicodeString @(0x6A21, 0x677F)
    $dailyTemplate = New-UnicodeString @(0x6BCF, 0x65E5, 0x5F00, 0x53D1, 0x8BB0, 0x5F55, 0x6A21, 0x677F)

    return Join-Path (Get-DefaultVaultRoot) (Join-Path ("90-" + $templateFolder) ($dailyTemplate + ".md"))
}

if ([string]::IsNullOrWhiteSpace($VaultRoot)) {
    # 如果 `$VaultRoot` 是空的、null 或只有空格，
    # 就使用默认 Obsidian 仓库路径。
    $VaultRoot = Get-DefaultVaultRoot
}

if ([string]::IsNullOrWhiteSpace($TemplatePath)) {
    # 如果没有传模板路径，就使用默认模板路径。
    $TemplatePath = Get-DefaultTemplatePath
}

$colon = [char]0xFF1A
$backtickChar = [char]0x0060
# 这里先准备两个常用字符：
#
# `$colon`
#   全角冒号 `：`
#
# `$backtickChar`
#   反引号 `` ` ``

$GitSectionHeader = Add-Prefix "#### " @(0x516D,0x3001,0x0047,0x0069,0x0074,0x0020,0x8BB0,0x5F55)
$TodaySubmitHeader = Add-Prefix "##### " @(0x4ECA,0x65E5,0x63D0,0x4EA4)
$SoftwareSectionHeader = Add-Prefix "##### " @(0x8F6F,0x4EF6,0x7248,0x672C)
$PathsSectionHeader = Add-Prefix "##### " @(0x5B89,0x88C5,0x8DEF,0x5F84)
$DailyLogFolder = Add-Prefix "10-" @(0x5F00,0x53D1,0x65E5,0x5FD7)
# 这几行是在创建固定标题文本，例如：
# - `#### 六、Git 记录`
# - `##### 今日提交`
# - `##### 软件版本`
# - `##### 安装路径`

$Windows11TemplateLine = "- Windows  11"
$Windows11NormalizedLine = "- Windows 11"
$RemarkLine = Add-Prefix "- " @(0x5907,0x6CE8) $colon
$GodotLabel = Add-Prefix "- Godot" @() $colon
$VsCodeLabel = Add-Prefix "- VS Code" @() $colon
$CodexLabel = Add-Prefix "- Codex " @(0x6269,0x5C55) $colon
$GitLabel = Add-Prefix "- Git" @() $colon
$ProjectDirectoryLabel = Add-Prefix "- " @(0x9879,0x76EE,0x76EE,0x5F55) $colon
$GitBashLabel = Add-Prefix "- Git Bash" @() $colon
$PlaceholderCommitLineA = "-  " + $backtickChar + "..." + $backtickChar
$PlaceholderCommitLineB = "- " + $backtickChar + "..." + $backtickChar
# 这一组变量用于：
# - 匹配模板里固定的标签行
# - 匹配模板里的占位行 `- \`...\``

function Get-CommitInfo {
    # 这个函数负责：
    # “读取最近一次 commit 的信息”

    $hash = (git rev-parse --short HEAD).Trim()
    $subject = (git log -1 --pretty=%s).Trim()
    $body = (git log -1 --pretty=%b).Trim()
    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    $time = Get-Date
    $changedFiles = @(git show --pretty="" --name-only HEAD | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    # 这里分别读取：
    #
    # `$hash`
    #   最近一次 commit 的短 hash
    #
    # `$subject`
    #   commit 标题
    #
    # `$body`
    #   commit 正文
    #
    # `$branch`
    #   当前分支名
    #
    # `$time`
    #   当前时间
    #
    # `$changedFiles`
    #   最近一次 commit 改动了哪些文件

    return [pscustomobject]@{
        Hash = $hash
        Subject = $subject
        Body = $body
        Branch = $branch
        Time = $time
        ChangedFiles = [string[]]$changedFiles
    }
    # `[pscustomobject]@{ ... }` 会创建一个“自定义对象”。
    # 这样后面就能写：
    # `$CommitInfo.Hash`
    # `$CommitInfo.Subject`
    # 这种清晰的访问方式。
}

function Get-DailyLogPath {
    # 这个函数负责：
    # “根据日期生成今天日志文件的完整路径”

    param(
        [string]$Root,
        [datetime]$Date
    )

    $year = $Date.ToString("yyyy")
    $month = $Date.ToString("yyyy-MM")
    $day = $Date.ToString("yyyy-MM-dd")
    # 这里把日期分别格式化成年、年月、完整日期字符串。

    return Join-Path $Root (Join-Path $DailyLogFolder (Join-Path $year (Join-Path $month ($day + ".md"))))
}

function New-DailyLogFromTemplate {
    # 这个函数负责：
    # “如果今天的日志文件不存在，就根据模板创建一份”

    param(
        [string]$TemplateFile,
        [string]$TargetFile,
        [datetime]$Date
    )

    $targetDir = Split-Path -Path $TargetFile -Parent
    # 取出目标文件所在的文件夹路径。

    if (-not (Test-Path -Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    # 如果目标文件夹还不存在，就先创建。

    $content = Get-Content -Path $TemplateFile -Raw -Encoding UTF8
    # 按 UTF-8 把模板整份读成一个大字符串。

    $dateText = $Date.ToString("yyyy-MM-dd")
    $content = $content.Replace("{{date:YYYY-MM-DD}}", $dateText)
    $content = $content.Replace("{{date}}", $dateText)
    # 把模板里的日期占位符替换成真实日期。

    Set-Content -Path $TargetFile -Value $content -Encoding UTF8
    # 把替换后的内容写入新文件。
}

function Get-CommandText {
    # 这个函数负责：
    # “尝试运行某个命令，并读取它的版本信息第一行”
    #
    # 例如：
    # git --version
    # code --version

    param(
        [string]$CommandName,
        [string[]]$ArgumentList = @("--version")
    )

    try {
        $command = Get-Command $CommandName -ErrorAction Stop
        # 先确认这个命令在当前系统里存在。

        $output = & $command.Source @ArgumentList 2>$null | Select-Object -First 1
        # `&` 是 PowerShell 的调用运算符，用来执行命令。
        # `@ArgumentList` 表示把参数数组展开传进去。
        # `2>$null` 表示丢弃错误输出。
        # `Select-Object -First 1` 表示只取第一行。

        if ($output) {
            return ([string]$output).Trim()
        }
    }
    catch {
        # 如果命令不存在，或者执行失败，就安静地忽略。
    }

    return ""
    # 如果拿不到版本信息，就返回空字符串。
}

function Get-CommandPath {
    # 这个函数负责：
    # “读取某个命令在系统里对应的实际路径”

    param(
        [string]$CommandName
    )

    try {
        $command = Get-Command $CommandName -ErrorAction Stop
        return $command.Source
    }
    catch {
        return ""
    }
}

function Initialize-DailyLogEnvironmentSection {
    # 这个函数负责：
    # “在第一次创建当日日志后，把环境记录里能自动探测到的内容填进去”

    param(
        [string]$LogFile
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]](Get-Content -Path $LogFile -Encoding UTF8))
    # 这里按“每一行一个元素”的方式读取日志文件。

    $gitVersion = Get-CommandText -CommandName "git"
    $codeVersion = Get-CommandText -CommandName "code"
    $godotVersion = Get-CommandText -CommandName "godot"
    if ([string]::IsNullOrWhiteSpace($godotVersion)) {
        $godotVersion = Get-CommandText -CommandName "Godot"
    }

    $gitPath = Get-CommandPath -CommandName "git"
    $codePath = Get-CommandPath -CommandName "code"
    $godotPath = Get-CommandPath -CommandName "godot"
    if ([string]::IsNullOrWhiteSpace($godotPath)) {
        $godotPath = Get-CommandPath -CommandName "Godot"
    }
    # 这里尽量探测：
    # - 软件版本
    # - 命令所在路径

    $currentSubSection = ""
    # 这个变量用于跟踪当前遍历到的是不是：
    # - 软件版本
    # - 安装路径

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $trimmedLine = $lines[$i].Trim()

        if ($trimmedLine -eq $SoftwareSectionHeader) {
            $currentSubSection = "software"
            continue
        }

        if ($trimmedLine -eq $PathsSectionHeader) {
            $currentSubSection = "paths"
            continue
        }

        if ($trimmedLine.StartsWith("##### ")) {
            $currentSubSection = ""
        }
        # 这一段逻辑的意思是：
        # 当扫描到某个小节标题时，记录当前在哪个小节里。

        if ($trimmedLine -eq $Windows11TemplateLine) {
            $lines[$i] = $Windows11NormalizedLine
        }
        elseif ($trimmedLine -eq $RemarkLine) {
            $lines[$i] = $RemarkLine
        }
        elseif ($trimmedLine.StartsWith($GodotLabel)) {
            if ($currentSubSection -eq "software" -and $godotVersion) {
                $lines[$i] = $GodotLabel + " " + $godotVersion
            }
            elseif ($currentSubSection -eq "paths" -and $godotPath) {
                $lines[$i] = $GodotLabel + " " + $godotPath
            }
        }
        elseif ($trimmedLine.StartsWith($VsCodeLabel)) {
            if ($currentSubSection -eq "software" -and $codeVersion) {
                $lines[$i] = $VsCodeLabel + " " + $codeVersion
            }
            elseif ($currentSubSection -eq "paths" -and $codePath) {
                $lines[$i] = $VsCodeLabel + " " + $codePath
            }
        }
        elseif ($trimmedLine.StartsWith($CodexLabel)) {
            $lines[$i] = $CodexLabel
        }
        elseif ($trimmedLine.StartsWith($GitLabel)) {
            if ($currentSubSection -eq "software" -and $gitVersion) {
                $lines[$i] = $GitLabel + " " + $gitVersion
            }
            elseif ($currentSubSection -eq "paths" -and $gitPath) {
                $lines[$i] = $GitLabel + " " + $gitPath
            }
        }
        elseif ($trimmedLine.StartsWith($ProjectDirectoryLabel)) {
            $lines[$i] = $ProjectDirectoryLabel + " " + (Get-Location).Path
        }
        elseif ($trimmedLine.StartsWith($GitBashLabel)) {
            if ($gitPath) {
                $gitDir = Split-Path -Path $gitPath -Parent
                $gitRootDir = Split-Path -Path $gitDir -Parent
                $gitBashPath = Join-Path $gitRootDir "git-bash.exe"

                if (Test-Path -Path $gitBashPath) {
                    $lines[$i] = $GitBashLabel + " " + $gitBashPath
                }
                else {
                    $lines[$i] = $GitBashLabel + " " + $gitPath
                }
            }
        }
        # 这一大段 `if / elseif` 的作用就是：
        # 根据当前行是什么标签，把模板里的空白内容换成自动探测到的信息。
    }

    Set-Content -Path $LogFile -Value $lines -Encoding UTF8
    # 把更新后的行列表写回原文件。
}

function Write-CommitEntryToDailyLog {
    # 这个函数负责：
    # “把最近一次 commit 记录写进日志”

    param(
        [string]$LogFile,
        [pscustomobject]$CommitInfo
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]](Get-Content -Path $LogFile -Encoding UTF8))

    $timestamp = $CommitInfo.Time.ToString("yyyy-MM-dd HH:mm:ss")
    $message = $CommitInfo.Subject
    # 先准备好最基础的日志内容：
    # - 时间
    # - commit 标题

    if ($CommitInfo.Body) {
        $bodyText = ($CommitInfo.Body -replace "\r?\n", " / ").Trim()
        # 如果 commit 有正文，就把多行正文压成一行。

        if ($bodyText) {
            $message = ("{0} | {1}" -f $message, $bodyText)
        }
    }

    $changedFilesText = ""
    if ($CommitInfo.ChangedFiles.Count -gt 0) {
        $changedFilesText = (" | files: {0}" -f (($CommitInfo.ChangedFiles | ForEach-Object { $_.Trim() }) -join ", "))
    }
    # 这里把本次 commit 改动的文件列表也拼成一段文字。

    $entry = ("- [x] {0}{1}{0} {2} [{3}] {4}{5}" -f $backtickChar, $CommitInfo.Hash, $timestamp, $CommitInfo.Branch, $message, $changedFilesText)
    # 最终生成一条 Markdown 记录，例如：
    # - [x] `abc1234` 2026-03-25 15:30:00 [master] feat: xxx | files: a, b

    $todaySubmitIndex = -1
    $gitSectionIndex = -1
    # 用来记录：
    # - “今日提交”标题行在哪
    # - “六、Git 记录”标题行在哪

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $trimmedLine = $lines[$i].Trim()

        if ($trimmedLine -eq $TodaySubmitHeader) {
            $todaySubmitIndex = $i
            break
        }

        if ($trimmedLine -eq $GitSectionHeader) {
            $gitSectionIndex = $i
        }
    }

    if ($todaySubmitIndex -ge 0) {
        # 如果已经找到了“今日提交”小标题，
        # 就把新的 commit 记录插入到它下面。

        $insertIndex = $todaySubmitIndex + 1

        while ($insertIndex -lt $lines.Count) {
            $currentLine = $lines[$insertIndex].Trim()

            if ($currentLine.StartsWith("- [x]")) {
                $insertIndex++
                continue
            }

            if ($currentLine -eq $PlaceholderCommitLineA -or $currentLine -eq $PlaceholderCommitLineB) {
                $lines.RemoveAt($insertIndex)
                continue
            }

            break
        }

        $lines.Insert($insertIndex, $entry)
    }
    elseif ($gitSectionIndex -ge 0) {
        # 如果找到了“大标题 六、Git 记录”，
        # 但还没有“今日提交”，
        # 就先补小标题，再插入一条记录。

        $insertIndex = $gitSectionIndex + 1
        $lines.Insert($insertIndex, "")
        $lines.Insert($insertIndex + 1, $TodaySubmitHeader)
        $lines.Insert($insertIndex + 2, $entry)
    }
    else {
        # 如果连“六、Git 记录”这一节都不存在，
        # 就在文件末尾新建这一节。

        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim() -ne "") {
            $lines.Add("")
        }

        $lines.Add($GitSectionHeader)
        $lines.Add($TodaySubmitHeader)
        $lines.Add($entry)
    }

    Set-Content -Path $LogFile -Value $lines -Encoding UTF8
    # 把最终结果写回日志文件。
}

$commitInfo = Get-CommitInfo
# 先读取最近一次 commit 的信息。

$dailyLogPath = Get-DailyLogPath -Root $VaultRoot -Date $commitInfo.Time
# 根据 commit 时间，算出今天的日志文件路径。

if (-not (Test-Path -Path $dailyLogPath)) {
    # 如果今天日志还不存在，就先创建。
    New-DailyLogFromTemplate -TemplateFile $TemplatePath -TargetFile $dailyLogPath -Date $commitInfo.Time

    # 创建完以后，再初始化一次环境记录。
    Initialize-DailyLogEnvironmentSection -LogFile $dailyLogPath
}

Write-CommitEntryToDailyLog -LogFile $dailyLogPath -CommitInfo $commitInfo
# 最后，把这次 commit 真正写进今天的日志文件。

param(
    [string]$VaultRoot = "D:\obsidian\仓库\游戏开发",
    [string]$TemplatePath = "D:\obsidian\仓库\游戏开发\90-模板\每日开发记录模板.md"
)

$ErrorActionPreference = "Stop"

function Get-CommitInfo {
    $hash = (git rev-parse --short HEAD).Trim()
    $subject = (git log -1 --pretty=%s).Trim()
    $body = (git log -1 --pretty=%b).Trim()
    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    $time = Get-Date

    return [pscustomobject]@{
        Hash = $hash
        Subject = $subject
        Body = $body
        Branch = $branch
        Time = $time
    }
}

function Get-DailyLogPath {
    param(
        [string]$Root,
        [datetime]$Date
    )

    $year = $Date.ToString("yyyy")
    $month = $Date.ToString("yyyy-MM")
    $day = $Date.ToString("yyyy-MM-dd")

    return Join-Path $Root "10-开发日志\$year\$month\$day.md"
}

function New-DailyLogFromTemplate {
    param(
        [string]$TemplateFile,
        [string]$TargetFile,
        [datetime]$Date
    )

    $targetDir = Split-Path -Path $TargetFile -Parent
    if (-not (Test-Path -Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $content = Get-Content -Path $TemplateFile -Raw -Encoding UTF8
    $dateText = $Date.ToString("yyyy-MM-dd")
    $content = $content.Replace("{{date:YYYY-MM-DD}}", $dateText)
    $content = $content.Replace("{{date}}", $dateText)

    Set-Content -Path $TargetFile -Value $content -Encoding UTF8
}

function Add-CommitEntryToDailyLog {
    param(
        [string]$LogFile,
        [pscustomobject]$CommitInfo
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]](Get-Content -Path $LogFile -Encoding UTF8))

    $timestamp = $CommitInfo.Time.ToString("yyyy-MM-dd HH:mm:ss")
    $message = $CommitInfo.Subject
    if ($CommitInfo.Body) {
        $message = "$message | $($CommitInfo.Body -replace '\r?\n', ' / ')"
    }

    $entry = "- [x] ``$($CommitInfo.Hash)`` $timestamp [$($CommitInfo.Branch)] $message"

    $todaySubmitIndex = -1
    $gitSectionIndex = -1

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq "##### 今日提交") {
            $todaySubmitIndex = $i
            break
        }

        if ($lines[$i].Trim() -eq "#### 八、Git 记录") {
            $gitSectionIndex = $i
        }
    }

    if ($todaySubmitIndex -ge 0) {
        $insertIndex = $todaySubmitIndex + 1
        while ($insertIndex -lt $lines.Count -and $lines[$insertIndex].Trim().StartsWith("- [x]")) {
            $insertIndex++
        }
        $lines.Insert($insertIndex, $entry)
    }
    elseif ($gitSectionIndex -ge 0) {
        $insertIndex = $gitSectionIndex + 1
        $lines.Insert($insertIndex, "")
        $lines.Insert($insertIndex + 1, "##### 今日提交")
        $lines.Insert($insertIndex + 2, $entry)
    }
    else {
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim() -ne "") {
            $lines.Add("")
        }
        $lines.Add("#### 八、Git 记录")
        $lines.Add("##### 今日提交")
        $lines.Add($entry)
    }

    Set-Content -Path $LogFile -Value $lines -Encoding UTF8
}

$commitInfo = Get-CommitInfo
$dailyLogPath = Get-DailyLogPath -Root $VaultRoot -Date $commitInfo.Time

if (-not (Test-Path -Path $dailyLogPath)) {
    New-DailyLogFromTemplate -TemplateFile $TemplatePath -TargetFile $dailyLogPath -Date $commitInfo.Time
}

Add-CommitEntryToDailyLog -LogFile $dailyLogPath -CommitInfo $commitInfo

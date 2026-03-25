# Obsidian daily log updater for post-commit hook.
# Creates today's log from template if missing, initializes environment
# section, then appends the latest commit entry under the Git section.

param(
    [string]$VaultRoot = "",
    [string]$TemplatePath = ""
)

$ErrorActionPreference = "Stop"

function New-UnicodeString {
    param(
        [int[]]$CodePoints
    )

    return (-join ($CodePoints | ForEach-Object { [char]$_ }))
}

function Add-Prefix {
    param(
        [string]$Prefix,
        [int[]]$CodePoints,
        [string]$Suffix = ""
    )

    return $Prefix + (New-UnicodeString $CodePoints) + $Suffix
}

function Get-DefaultVaultRoot {
    $warehouse = New-UnicodeString @(0x4ED3, 0x5E93)
    $gameDev = New-UnicodeString @(0x6E38, 0x620F, 0x5F00, 0x53D1)
    return Join-Path "D:\obsidian" (Join-Path $warehouse $gameDev)
}

function Get-DefaultTemplatePath {
    $templateFolder = New-UnicodeString @(0x6A21, 0x677F)
    $dailyTemplate = New-UnicodeString @(0x6BCF, 0x65E5, 0x5F00, 0x53D1, 0x8BB0, 0x5F55, 0x6A21, 0x677F)
    return Join-Path (Get-DefaultVaultRoot) (Join-Path ("90-" + $templateFolder) ($dailyTemplate + ".md"))
}

if ([string]::IsNullOrWhiteSpace($VaultRoot)) {
    $VaultRoot = Get-DefaultVaultRoot
}

if ([string]::IsNullOrWhiteSpace($TemplatePath)) {
    $TemplatePath = Get-DefaultTemplatePath
}

$colon = [char]0xFF1A
$backtickChar = [char]0x0060

$GitSectionHeader = Add-Prefix "#### " @(0x516D,0x3001,0x0047,0x0069,0x0074,0x0020,0x8BB0,0x5F55)
$TodaySubmitHeader = Add-Prefix "##### " @(0x4ECA,0x65E5,0x63D0,0x4EA4)
$SoftwareSectionHeader = Add-Prefix "##### " @(0x8F6F,0x4EF6,0x7248,0x672C)
$PathsSectionHeader = Add-Prefix "##### " @(0x5B89,0x88C5,0x8DEF,0x5F84)
$DailyLogFolder = Add-Prefix "10-" @(0x5F00,0x53D1,0x65E5,0x5FD7)

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

function Get-CommitInfo {
    $hash = (git rev-parse --short HEAD).Trim()
    $subject = (git log -1 --pretty=%s).Trim()
    $body = (git log -1 --pretty=%b).Trim()
    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    $time = Get-Date
    $changedFiles = @(git show --pretty="" --name-only HEAD | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    return [pscustomobject]@{
        Hash = $hash
        Subject = $subject
        Body = $body
        Branch = $branch
        Time = $time
        ChangedFiles = [string[]]$changedFiles
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

    return Join-Path $Root (Join-Path $DailyLogFolder (Join-Path $year (Join-Path $month ($day + ".md"))))
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

function Get-CommandText {
    param(
        [string]$CommandName,
        [string[]]$ArgumentList = @("--version")
    )

    try {
        $command = Get-Command $CommandName -ErrorAction Stop
        $output = & $command.Source @ArgumentList 2>$null | Select-Object -First 1
        if ($output) {
            return ([string]$output).Trim()
        }
    }
    catch {
    }

    return ""
}

function Get-CommandPath {
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

function Test-IsCommitEntryLine {
    param(
        [string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $false
    }

    $trimmedLine = $Line.Trim()

    if (-not $trimmedLine.StartsWith("- ")) {
        return $false
    }

    $hashPattern = [regex]::Escape($backtickChar) + "[0-9a-fA-F]{7,40}" + [regex]::Escape($backtickChar)
    $timePattern = "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}"

    return [regex]::IsMatch($trimmedLine, $hashPattern) -and [regex]::IsMatch($trimmedLine, $timePattern)
}

function Initialize-DailyLogEnvironmentSection {
    param(
        [string]$LogFile
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]](Get-Content -Path $LogFile -Encoding UTF8))

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

    $currentSubSection = ""

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
    }

    Set-Content -Path $LogFile -Value $lines -Encoding UTF8
}

function Write-CommitEntryToDailyLog {
    param(
        [string]$LogFile,
        [pscustomobject]$CommitInfo
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]](Get-Content -Path $LogFile -Encoding UTF8))

    $timestamp = $CommitInfo.Time.ToString("yyyy-MM-dd HH:mm:ss")
    $message = $CommitInfo.Subject
    if ($CommitInfo.Body) {
        $bodyText = ($CommitInfo.Body -replace "\r?\n", " / ").Trim()
        if ($bodyText) {
            $message = ("{0} | {1}" -f $message, $bodyText)
        }
    }

    $changedFilesText = ""
    if ($CommitInfo.ChangedFiles.Count -gt 0) {
        $changedFilesText = (" | files: {0}" -f (($CommitInfo.ChangedFiles | ForEach-Object { $_.Trim() }) -join ", "))
    }

    $entry = ("- {0}{1}{0} {2} [{3}] {4}{5}" -f $backtickChar, $CommitInfo.Hash, $timestamp, $CommitInfo.Branch, $message, $changedFilesText)

    $todaySubmitIndex = -1
    $gitSectionIndex = -1

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
        $insertIndex = $todaySubmitIndex + 1

        while ($insertIndex -lt $lines.Count) {
            $currentLine = $lines[$insertIndex].Trim()
            if (Test-IsCommitEntryLine -Line $currentLine) {
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
        $insertIndex = $gitSectionIndex + 1
        $lines.Insert($insertIndex, "")
        $lines.Insert($insertIndex + 1, $TodaySubmitHeader)
        $lines.Insert($insertIndex + 2, $entry)
    }
    else {
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim() -ne "") {
            $lines.Add("")
        }
        $lines.Add($GitSectionHeader)
        $lines.Add($TodaySubmitHeader)
        $lines.Add($entry)
    }

    Set-Content -Path $LogFile -Value $lines -Encoding UTF8
}

$commitInfo = Get-CommitInfo
$dailyLogPath = Get-DailyLogPath -Root $VaultRoot -Date $commitInfo.Time

if (-not (Test-Path -Path $dailyLogPath)) {
    New-DailyLogFromTemplate -TemplateFile $TemplatePath -TargetFile $dailyLogPath -Date $commitInfo.Time
    Initialize-DailyLogEnvironmentSection -LogFile $dailyLogPath
}

Write-CommitEntryToDailyLog -LogFile $dailyLogPath -CommitInfo $commitInfo

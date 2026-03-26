# Commit helper script.
# Steps:
# 1. git add .
# 2. git commit -m "message"
# 3. optional git push when -Push is provided
#
# Push behavior:
# - If the current branch already has an upstream, run `git push`
# - If the current branch does not have an upstream yet, run
#   `git push -u origin <current-branch>`

# Parameters:
# -Message : required commit message
# -Push    : optional switch, runs git push after commit
param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [switch]$Push
)

# Stop immediately on errors.
$ErrorActionPreference = "Stop"

# Stage all changes.
git add .

# Create the commit with the provided message.
git commit -m $Message

# Stop if commit failed.
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Push only when -Push was passed.
if ($Push) {
    $currentBranch = (git branch --show-current).Trim()
    if (-not $currentBranch) {
        Write-Error "Failed to determine current git branch."
        exit 1
    }

    git rev-parse --abbrev-ref --symbolic-full-name "@{u}" *> $null
    $hasUpstream = ($LASTEXITCODE -eq 0)

    if ($hasUpstream) {
        git push
    }
    else {
        git push -u origin $currentBranch
    }

    exit $LASTEXITCODE
}

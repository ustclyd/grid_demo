# Commit helper script.
# Steps:
# 1. git add .
# 2. git commit -m "message"
# 3. optional git push when -Push is provided

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
    git push
    exit $LASTEXITCODE
}

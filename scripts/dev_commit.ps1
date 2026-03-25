param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [switch]$Push
)

$ErrorActionPreference = "Stop"

git add .
git commit -m $Message

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($Push) {
    git push
    exit $LASTEXITCODE
}

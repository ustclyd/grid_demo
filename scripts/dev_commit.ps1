# Commit from the project root. With -PushOnly, upload existing commits.
# A repository can opt a development branch into publishing to origin's default
# branch with: git config --local gridDemo.contributionBranch <branch>

[CmdletBinding(DefaultParameterSetName = 'Commit')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Commit')]
    [string]$Message,

    [Parameter(ParameterSetName = 'Commit')]
    [switch]$Push,

    [Parameter(Mandatory = $true, ParameterSetName = 'PushOnly')]
    [switch]$PushOnly,

    [switch]$BranchOnly
)

$ErrorActionPreference = 'Stop'
$shouldPush = $Push -or $PushOnly

Push-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
try {
    if ($shouldPush) {
        $branch = git branch --show-current
        if ($LASTEXITCODE -ne 0 -or -not $branch) {
            throw 'Check out a local branch before pushing.'
        }
    }

    if (-not $PushOnly) {
        git add .
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        git commit -m $Message
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    if (-not $shouldPush) { return }

    $branchRef = "refs/heads/$branch"
    $upstream = git for-each-ref --format='%(upstream:short)' $branchRef
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $contributionBranch = git config --local --get gridDemo.contributionBranch
    if ($LASTEXITCODE -gt 1) { exit $LASTEXITCODE }
    if ($BranchOnly -or $branch -cne $contributionBranch) {
        if ($upstream) {
            git push
        }
        else {
            git push -u origin $branch
        }
        exit $LASTEXITCODE
    }

    $remoteHead = git ls-remote --symref --exit-code origin HEAD
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $defaultRef = $null
    foreach ($line in $remoteHead) {
        if ($line -match '^ref: (refs/heads/\S+)\s+HEAD$') {
            $defaultRef = $Matches[1]
            break
        }
    }
    if (-not $defaultRef) {
        throw 'Could not identify the default branch on origin.'
    }

    $commit = git rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $refspecs = @("${commit}:${branchRef}")
    if ($defaultRef -cne $branchRef) { $refspecs += "${commit}:${defaultRef}" }

    # Keep the original author and commit dates. Git rejects non-fast-forward
    # updates and the remote applies both branch updates as a single operation.
    git push --atomic origin @refspecs
    if ($LASTEXITCODE -ne 0) {
        $pushExit = $LASTEXITCODE
        Write-Warning 'Publish failed. Check the remote branches before retrying with -PushOnly.'
        exit $pushExit
    }

    if (-not $upstream) {
        git branch --set-upstream-to "origin/$branch" $branch
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    Write-Host "Published $commit to origin/$branch and the default branch ($defaultRef)."
}
finally {
    Pop-Location
}

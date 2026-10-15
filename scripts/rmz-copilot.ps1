$repoRoot = Split-Path -Parent $PSScriptRoot

$offRequested = $args.Count -eq 1 -and $args[0] -ceq '--off'
if ($args.Count -gt 0 -and -not $offRequested) {
    throw 'Usage: rmz-copilot [--off]'
}

Push-Location -LiteralPath $repoRoot
try {
    if ($offRequested) {
        & vagrant suspend
        $suspendExitCode = $LASTEXITCODE
        if ($suspendExitCode -ne 0) {
            throw "vagrant suspend failed with exit code $suspendExitCode."
        }
    }
    else {
        & vagrant up
        $upExitCode = $LASTEXITCODE
        if ($upExitCode -ne 0) {
            throw "vagrant up failed with exit code $upExitCode."
        }

        & vagrant ssh
    }
}
finally {
    Pop-Location
}

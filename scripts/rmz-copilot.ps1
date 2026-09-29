$repoRoot = Split-Path -Parent $PSScriptRoot

Push-Location -LiteralPath $repoRoot
try {
    & vagrant up
    $upExitCode = $LASTEXITCODE
    if ($upExitCode -ne 0) {
        throw "vagrant up failed with exit code $upExitCode."
    }

    & vagrant ssh
}
finally {
    Pop-Location
}

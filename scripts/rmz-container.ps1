$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$composeDirectory = Join-Path $repoRoot '.devcontainer'
$composeFile = Join-Path $composeDirectory 'compose.yaml'
$workspaceFolder = "/workspace/$([System.IO.Path]::GetFileName($repoRoot))"

$recreateRequested = $args.Count -eq 1 -and $args[0] -ceq '--recreate'
$stopRequested = $args.Count -eq 1 -and $args[0] -ceq '--stop'
$downRequested = $args.Count -eq 1 -and $args[0] -ceq '--down'
if ($args.Count -gt 0 -and -not ($recreateRequested -or $stopRequested -or $downRequested)) {
    throw 'Usage: rmz-container [--recreate | --stop | --down]'
}
if (-not (Test-Path -LiteralPath $composeFile -PathType Leaf)) {
    throw "Docker Compose configuration was not found at '$composeFile'."
}

$composePrefix = @(
    'compose'
    '--project-name'
    'rmz-container'
    '--file'
    $composeFile
)

Push-Location -LiteralPath $repoRoot
try {
    if ($stopRequested) {
        $dockerArguments = $composePrefix + @('stop')
        & docker @dockerArguments
        $stopExitCode = $LASTEXITCODE
        if ($stopExitCode -ne 0) {
            throw "docker compose stop failed with exit code $stopExitCode."
        }
    }
    elseif ($downRequested) {
        $dockerArguments = $composePrefix + @('down')
        & docker @dockerArguments
        $downExitCode = $LASTEXITCODE
        if ($downExitCode -ne 0) {
            throw "docker compose down failed with exit code $downExitCode."
        }
    }
    else {
        $dockerArguments = $composePrefix + @('up', '--detach')
        if ($recreateRequested) {
            $dockerArguments += @('--build', '--force-recreate')
        }

        & docker @dockerArguments
        $upExitCode = $LASTEXITCODE
        if ($upExitCode -ne 0) {
            throw "docker compose up failed with exit code $upExitCode."
        }

        $dockerArguments = $composePrefix + @(
            'exec'
            '--interactive'
            '--tty'
            '--workdir'
            $workspaceFolder
            'workspace'
            '/bin/bash'
        )
        & docker @dockerArguments
    }
}
finally {
    Pop-Location
}

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptsDirectory = Join-Path $repoRoot 'scripts'
$setupScript = Join-Path $scriptsDirectory 'setup-rmz-container.ps1'
$tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) (
    'rmz-container-tests-' + [System.Guid]::NewGuid().ToString('N')
)
$profilePath = Join-Path $tempDirectory 'Microsoft.PowerShell_profile.ps1'
$initialLocation = Get-Location
$devcontainerDirectory = Join-Path $repoRoot '.devcontainer'
$composeFile = Join-Path $devcontainerDirectory 'compose.yaml'
$workspaceFolder = "/workspace/$([System.IO.Path]::GetFileName($repoRoot))"
$composePrefix = "compose --project-name rmz-container --file $composeFile"
$global:DockerCalls = [System.Collections.Generic.List[string]]::new()
$global:DockerUpExitCode = 0
$global:DockerExecExitCode = 0
$global:DockerStopExitCode = 0
$global:DockerDownExitCode = 0

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param(
        [string]$Expected,
        [string]$Actual,
        [string]$Message
    )

    if ($Expected -cne $Actual) {
        throw "$Message Expected '$Expected'; got '$Actual'."
    }
}

function docker {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$DockerArguments
    )

    if ($DockerArguments.Count -eq 0) {
        throw 'The launcher called docker without arguments.'
    }

    [void]$global:DockerCalls.Add(
        "$($DockerArguments -join ' ')|$((Get-Location).Path)"
    )
    $global:LASTEXITCODE = 0
    if ($DockerArguments -contains 'up') {
        $global:LASTEXITCODE = $global:DockerUpExitCode
    }
    elseif ($DockerArguments -contains 'exec') {
        $global:LASTEXITCODE = $global:DockerExecExitCode
    }
    elseif ($DockerArguments -contains 'stop') {
        $global:LASTEXITCODE = $global:DockerStopExitCode
    }
    elseif ($DockerArguments -contains 'down') {
        $global:LASTEXITCODE = $global:DockerDownExitCode
    }
}

try {
    New-Item -ItemType Directory -Path $tempDirectory | Out-Null
    [System.IO.File]::WriteAllText(
        $profilePath,
        "# existing profile setting`r`n",
        [System.Text.UTF8Encoding]::new($true)
    )

    & $setupScript -ProfilePath $profilePath | Out-Null
    & $setupScript -ProfilePath $profilePath | Out-Null
    $profileContents = [System.IO.File]::ReadAllText($profilePath)
    Assert-True ($profileContents.Contains('# existing profile setting')) `
        'The setup script must preserve existing PowerShell profile content.'
    Assert-Equal '1' (
        [System.Text.RegularExpressions.Regex]::Matches(
            $profileContents,
            [System.Text.RegularExpressions.Regex]::Escape(
                '# >>> rmz-container setup >>>'
            )
        ).Count.ToString()
    ) 'The setup script must not duplicate its profile block.'

    $newProfileDirectory = Join-Path $tempDirectory 'new-profile'
    $newProfilePath = Join-Path $newProfileDirectory 'profile.ps1'
    & $setupScript -ProfilePath $newProfilePath | Out-Null
    Assert-True (Test-Path -LiteralPath $newProfilePath -PathType Leaf) `
        'The setup script must create a missing profile and its directory.'

    $incompleteProfilePath = Join-Path $tempDirectory 'incomplete-profile.ps1'
    $incompleteProfile = "# >>> rmz-container setup >>>`r`n"
    [System.IO.File]::WriteAllText(
        $incompleteProfilePath,
        $incompleteProfile,
        [System.Text.UTF8Encoding]::new($true)
    )
    $incompleteProfileThrown = $false
    try {
        & $setupScript -ProfilePath $incompleteProfilePath | Out-Null
    }
    catch {
        $incompleteProfileThrown = $true
    }
    Assert-True $incompleteProfileThrown `
        'The setup script must reject an incomplete managed profile block.'
    Assert-Equal $incompleteProfile `
        ([System.IO.File]::ReadAllText($incompleteProfilePath)) `
        'The setup script must preserve a profile with an incomplete block.'

    . $profilePath
    Push-Location -LiteralPath $tempDirectory
    try {
        rmz-container
        Assert-Equal "$composePrefix up --detach|$repoRoot" $global:DockerCalls[0] `
            'The default command must create or start the container from the repository.'
        Assert-Equal (
            "$composePrefix exec --interactive --tty --workdir $workspaceFolder workspace /bin/bash|$repoRoot"
        ) $global:DockerCalls[1] `
            'The default command must open an interactive shell in this repository.'
        Assert-Equal '2' $global:DockerCalls.Count.ToString() `
            'A successful launch must run exactly two Docker commands.'
        Assert-Equal $tempDirectory (Get-Location).Path `
            'The launcher must restore the caller location.'

        $global:DockerCalls.Clear()
        rmz-container --recreate
        Assert-Equal (
            "$composePrefix up --detach --build --force-recreate|$repoRoot"
        ) $global:DockerCalls[0] `
            'The --recreate option must rebuild and recreate the container.'
        Assert-Equal (
            "$composePrefix exec --interactive --tty --workdir $workspaceFolder workspace /bin/bash|$repoRoot"
        ) $global:DockerCalls[1] `
            'The --recreate option must open an interactive shell after creation.'
        Assert-Equal '2' $global:DockerCalls.Count.ToString() `
            'The --recreate option must run exactly two Docker commands.'

        $global:DockerCalls.Clear()
        rmz-container --off
        Assert-Equal "$composePrefix stop|$repoRoot" $global:DockerCalls[0] `
            'The --off option must stop the container from the repository.'
        Assert-Equal '1' $global:DockerCalls.Count.ToString() `
            'The --off option must not open a shell.'

        $global:DockerCalls.Clear()
        rmz-container --down
        Assert-Equal "$composePrefix down|$repoRoot" $global:DockerCalls[0] `
            'The --down option must stop and remove the container.'
        Assert-Equal '1' $global:DockerCalls.Count.ToString() `
            'The --down option must not open a shell.'

        $global:DockerCalls.Clear()
        $global:DockerUpExitCode = 37
        $upFailureThrown = $false
        try {
            rmz-container
        }
        catch {
            $upFailureThrown = $true
        }
        Assert-True $upFailureThrown `
            'The launcher must report a failed container start.'
        Assert-Equal '1' $global:DockerCalls.Count.ToString() `
            'A failed container start must not open a shell.'
        Assert-Equal $tempDirectory (Get-Location).Path `
            'The launcher must restore the caller location after startup fails.'
        $global:DockerUpExitCode = 0

        $global:DockerCalls.Clear()
        $global:DockerStopExitCode = 41
        $stopFailureThrown = $false
        try {
            rmz-container --off
        }
        catch {
            $stopFailureThrown = $true
        }
        Assert-True $stopFailureThrown `
            'The launcher must report a failed container stop.'
        Assert-Equal '1' $global:DockerCalls.Count.ToString() `
            'A failed stop must not run additional Docker commands.'
        $global:DockerStopExitCode = 0

        $global:DockerCalls.Clear()
        $global:DockerDownExitCode = 43
        $downFailureThrown = $false
        try {
            rmz-container --down
        }
        catch {
            $downFailureThrown = $true
        }
        Assert-True $downFailureThrown `
            'The launcher must report a failed container removal.'
        Assert-Equal '1' $global:DockerCalls.Count.ToString() `
            'A failed removal must not run additional Docker commands.'
        $global:DockerDownExitCode = 0

        $global:DockerCalls.Clear()
        $global:DockerExecExitCode = 29
        rmz-container
        Assert-Equal '2' $global:DockerCalls.Count.ToString() `
            'The launcher must not treat an interactive shell exit as a startup failure.'
        $global:DockerExecExitCode = 0

        $global:DockerCalls.Clear()
        $invalidOptionThrown = $false
        try {
            rmz-container --unknown
        }
        catch {
            $invalidOptionThrown = $true
        }
        Assert-True $invalidOptionThrown `
            'The launcher must reject unknown options.'
        Assert-Equal '0' $global:DockerCalls.Count.ToString() `
            'An invalid option must not run Docker.'

        $multipleOptionsThrown = $false
        try {
            rmz-container --off --down
        }
        catch {
            $multipleOptionsThrown = $true
        }
        Assert-True $multipleOptionsThrown `
            'The launcher must reject multiple lifecycle options.'
    }
    finally {
        Pop-Location
    }
}
finally {
    $global:LASTEXITCODE = 0
    Set-Location -LiteralPath $initialLocation.Path
    if (Test-Path -LiteralPath $tempDirectory) {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force
    }
}

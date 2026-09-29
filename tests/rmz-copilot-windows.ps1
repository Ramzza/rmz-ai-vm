$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$setupScript = Join-Path $repoRoot 'scripts\setup-rmz-copilot.ps1'
$tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) (
    'rmz-copilot-tests-' + [System.Guid]::NewGuid().ToString('N')
)
$profilePath = Join-Path $tempDirectory 'Microsoft.PowerShell_profile.ps1'
$initialLocation = Get-Location
$global:VagrantCalls = [System.Collections.Generic.List[string]]::new()
$global:VagrantUpExitCode = 0
$global:VagrantSshExitCode = 0

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

function vagrant {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$VagrantArguments
    )

    if ($VagrantArguments.Count -eq 0) {
        throw 'The launcher called vagrant without a command.'
    }

    [void]$global:VagrantCalls.Add(
        "$($VagrantArguments -join ' ')|$((Get-Location).Path)"
    )
    if ($VagrantArguments[0] -eq 'up') {
        $global:LASTEXITCODE = $global:VagrantUpExitCode
    }
    elseif ($VagrantArguments[0] -eq 'ssh') {
        $global:LASTEXITCODE = $global:VagrantSshExitCode
    }
    else {
        $global:LASTEXITCODE = 99
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
                '# >>> rmz-copilot setup >>>'
            )
        ).Count.ToString()
    ) 'The setup script must not duplicate its profile block.'

    $newProfilePath = Join-Path $tempDirectory 'new-profile\profile.ps1'
    & $setupScript -ProfilePath $newProfilePath | Out-Null
    Assert-True (Test-Path -LiteralPath $newProfilePath -PathType Leaf) `
        'The setup script must create a missing profile and its directory.'

    $incompleteProfilePath = Join-Path $tempDirectory 'incomplete-profile.ps1'
    $incompleteProfile = "# >>> rmz-copilot setup >>>`r`n"
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
        rmz-copilot
        Assert-Equal "up|$repoRoot" $global:VagrantCalls[0] `
            'The launcher must run vagrant up from the repository root.'
        Assert-Equal "ssh|$repoRoot" $global:VagrantCalls[1] `
            'The launcher must run vagrant ssh after vagrant up.'
        Assert-Equal $tempDirectory (Get-Location).Path `
            'The launcher must restore the caller location.'
        Assert-Equal '2' $global:VagrantCalls.Count.ToString() `
            'A successful launch must run exactly two Vagrant commands.'

        $global:VagrantCalls.Clear()
        $global:VagrantUpExitCode = 41
        $upFailureThrown = $false
        try {
            rmz-copilot
        }
        catch {
            $upFailureThrown = $true
        }
        Assert-True $upFailureThrown `
            'The launcher must report a failed vagrant up.'
        Assert-Equal '1' $global:VagrantCalls.Count.ToString() `
            'The launcher must not start SSH when vagrant up fails.'
        Assert-Equal "up|$repoRoot" $global:VagrantCalls[0] `
            'A failed vagrant up must run from the repository root.'
        Assert-Equal $tempDirectory (Get-Location).Path `
            'The launcher must restore the caller location after a failure.'

        $global:VagrantCalls.Clear()
        $global:VagrantUpExitCode = 0
        foreach ($guestExitCode in @(1, 29)) {
            $global:VagrantSshExitCode = $guestExitCode
            $sshExitThrown = $false
            try {
                rmz-copilot
            }
            catch {
                $sshExitThrown = $true
            }
            Assert-True (-not $sshExitThrown) `
                "The launcher must not treat guest shell exit code '$guestExitCode' as an SSH failure."
            Assert-Equal $guestExitCode.ToString() $global:LASTEXITCODE.ToString() `
                'The launcher must preserve the guest shell exit code.'
            Assert-Equal '2' $global:VagrantCalls.Count.ToString() `
                'The launcher must attempt SSH after successful vagrant up.'
            Assert-Equal $tempDirectory (Get-Location).Path `
                'The launcher must restore the caller location after the SSH session ends.'
            $global:VagrantCalls.Clear()
        }
    }
    finally {
        Pop-Location
    }

    $global:LASTEXITCODE = 0
    Write-Output 'PowerShell rmz-copilot tests passed.'
}
finally {
    Set-Location -LiteralPath $initialLocation
    if (Test-Path -LiteralPath $tempDirectory) {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force
    }
}

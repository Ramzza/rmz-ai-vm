[CmdletBinding()]
param(
    [string]$ProfilePath = $PROFILE
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
    throw 'A PowerShell profile path is required.'
}

$launcherPath = Join-Path $PSScriptRoot 'rmz-copilot.ps1'
if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) {
    throw "The host launcher was not found at '$launcherPath'."
}

$profileDirectory = Split-Path -Parent $ProfilePath
if ($profileDirectory) {
    New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
}

$profileContents = ''
if (Test-Path -LiteralPath $ProfilePath -PathType Leaf) {
    $profileContents = [System.IO.File]::ReadAllText($ProfilePath)
}
elseif (Test-Path -LiteralPath $ProfilePath) {
    throw "The PowerShell profile path '$ProfilePath' is not a file."
}

$startMarker = '# >>> rmz-copilot setup >>>'
$endMarker = '# <<< rmz-copilot setup <<<'
$escapedLauncherPath = $launcherPath.Replace("'", "''")
$managedBlock = @(
    $startMarker
    'function rmz-copilot {'
    "    & '$escapedLauncherPath'"
    '}'
    $endMarker
) -join [System.Environment]::NewLine

$startIndex = $profileContents.IndexOf(
    $startMarker,
    [System.StringComparison]::Ordinal
)
$endIndex = $profileContents.IndexOf(
    $endMarker,
    [System.StringComparison]::Ordinal
)
if (($startIndex -ge 0) -ne ($endIndex -ge 0)) {
    throw "The PowerShell profile contains an incomplete rmz-copilot setup block."
}
if ($startIndex -ge 0) {
    if ($endIndex -lt $startIndex) {
        throw "The PowerShell profile contains an invalid rmz-copilot setup block."
    }

    $afterBlock = $endIndex + $endMarker.Length
    $profileContents = $profileContents.Substring(0, $startIndex) +
        $managedBlock +
        $profileContents.Substring($afterBlock)
}
else {
    $separator = ''
    if (
        $profileContents.Length -gt 0 -and
        -not $profileContents.EndsWith("`n") -and
        -not $profileContents.EndsWith("`r")
    ) {
        $separator = [System.Environment]::NewLine
    }

    $profileContents += $separator + $managedBlock + [System.Environment]::NewLine
}

[System.IO.File]::WriteAllText(
    $ProfilePath,
    $profileContents,
    [System.Text.UTF8Encoding]::new($true)
)

Write-Output "Installed rmz-copilot in '$ProfilePath'. Open a new PowerShell session to use it."

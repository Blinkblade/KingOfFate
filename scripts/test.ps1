#Requires -Version 5.1
<#
.SYNOPSIS
    Unified entry point for the KingOfFate test suite.

.DESCRIPTION
    Locates the project root from its own path (never from the current directory) and
    runs every test suite that currently exists.

    Right now that is the Phase 0 smoke test in tests/smoke/.
    As the project grows, further suites get added here.

    Exit code: 0 = PASS, non-zero = FAIL.

.PARAMETER RuntimeTest
    Also run the optional engine launch test (starts one automated round).

.PARAMETER Suite
    Which suite to run. Defaults to 'smoke'.

.EXAMPLE
    pwsh -File scripts/test.ps1
    pwsh -File scripts/test.ps1 -RuntimeTest
#>
[CmdletBinding()]
param(
    [switch]$RuntimeTest,
    [ValidateSet('smoke', 'all')]
    [string]$Suite = 'smoke'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..')).ProviderPath

$smoke = Join-Path $RepoRoot 'tests\smoke\smoke.ps1'

if (-not (Test-Path -LiteralPath $smoke)) {
    Write-Host "[fail] smoke test not found: $smoke" -ForegroundColor Red
    exit 2
}

$smokeArgs = @{ RepoRoot = $RepoRoot }
if ($RuntimeTest) { $smokeArgs.RuntimeTest = $true }

& $smoke @smokeArgs
exit $LASTEXITCODE

#Requires -Version 5.1
<#
.SYNOPSIS
    Unified entry point for the KingOfFate test suite.

.DESCRIPTION
    Locates the project root from its own path (never from the current directory)
    and runs every test suite that currently exists:

      smoke   tests/smoke/smoke.ps1            project invariants, engine baseline,
                                               runtime files, build artifact
      tools   tests/tools/run_tool_tests.ps1   the P5 character asset tools

    Exit code: 0 = PASS, non-zero = FAIL.

.PARAMETER RuntimeTest
    Also run the optional engine launch test (verifies start-up health: process,
    window and responsiveness). Only applies to the smoke suite.

.PARAMETER Suite
    Which suites to run. Defaults to 'all'.

.PARAMETER Full
    Passed to the tools suite: also export all sprites of a real character and
    render a montage. Slower; use it after changing anything under tools/.
#>
[CmdletBinding()]
param(
    [switch]$RuntimeTest,
    [ValidateSet('smoke', 'tools', 'all')]
    [string]$Suite = 'all',
    [switch]$Full
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..')).ProviderPath

$smoke = Join-Path $RepoRoot 'tests\smoke\smoke.ps1'
$tools = Join-Path $RepoRoot 'tests\tools\run_tool_tests.ps1'

$failures = @()

function Invoke-Suite {
    param([string]$Name, [string]$Path, [hashtable]$Arguments)
    Write-Host ''
    Write-Host "=== suite: $Name ===" -ForegroundColor White
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "[fail] suite script not found: $Path" -ForegroundColor Red
        $script:failures += $Name
        return
    }
    & $Path @Arguments
    if ($LASTEXITCODE -ne 0) { $script:failures += $Name }
}

if ($Suite -eq 'smoke' -or $Suite -eq 'all') {
    $smokeArgs = @{ RepoRoot = $RepoRoot }
    if ($RuntimeTest) { $smokeArgs.RuntimeTest = $true }
    Invoke-Suite -Name 'smoke' -Path $smoke -Arguments $smokeArgs
}

if ($Suite -eq 'tools' -or $Suite -eq 'all') {
    $toolArgs = @{ RepoRoot = $RepoRoot }
    if ($Full) { $toolArgs.Full = $true }
    Invoke-Suite -Name 'tools' -Path $tools -Arguments $toolArgs
}

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host ("TEST SUITE FAILED: {0}" -f ($failures -join ', ')) -ForegroundColor Red
    Write-Host ''
    exit 1
}

Write-Host 'ALL TEST SUITES PASS' -ForegroundColor Green
Write-Host ''
exit 0

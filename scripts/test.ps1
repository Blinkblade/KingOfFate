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
      frame   tools/frame_data.py --check      frame advantage and hitbox-vs-artwork
                                               for every character under game/chars

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
    [ValidateSet('smoke', 'tools', 'frame', 'all')]
    [string]$Suite = 'all',
    [string]$Python = 'python',
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

function Invoke-FrameCheck {
    param([string]$CharsRoot, [string]$ToolPath, [string]$Python = 'python')
    Write-Host ''
    Write-Host '=== suite: frame ===' -ForegroundColor White
    if (-not (Test-Path -LiteralPath $ToolPath)) {
        Write-Host "[fail] tool not found: $ToolPath" -ForegroundColor Red
        $script:failures += 'frame'
        return
    }
    if (-not (Test-Path -LiteralPath $CharsRoot)) {
        Write-Host "[fail] character root not found: $CharsRoot" -ForegroundColor Red
        $script:failures += 'frame'
        return
    }
    # Every character directory that carries its own <name>.zss -- labs and
    # data-less stubs are skipped instead of being reported as broken.
    $dirs = @(Get-ChildItem -LiteralPath $CharsRoot -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName ($_.Name + '.zss')) } |
        Sort-Object Name)
    if ($dirs.Count -eq 0) {
        Write-Host '[fail] no character directories with a .zss found' -ForegroundColor Red
        $script:failures += 'frame'
        return
    }
    $bad = 0
    foreach ($d in $dirs) {
        $out = @(& $Python $ToolPath $d.FullName '--check' 2>&1 | ForEach-Object { "$_" })
        if ($LASTEXITCODE -ne 0) {
            $bad++
            Write-Host ("[fail] {0}" -f $d.Name) -ForegroundColor Red
            $out | Where-Object { $_ -match '^\s+- |^FAIL' } |
                ForEach-Object { Write-Host ("       {0}" -f $_.Trim()) }
        } else {
            Write-Host ("[ ok ] {0}" -f $d.Name) -ForegroundColor Green
        }
    }
    Write-Host ("frame: {0} checked, {1} failed" -f $dirs.Count, $bad) -ForegroundColor DarkGray
    if ($bad -gt 0) { $script:failures += 'frame' }
}

if ($Suite -eq 'smoke' -or $Suite -eq 'all') {
    $smokeArgs = @{ RepoRoot = $RepoRoot }
    if ($RuntimeTest) { $smokeArgs.RuntimeTest = $true }
    Invoke-Suite -Name 'smoke' -Path $smoke -Arguments $smokeArgs
}

if ($Suite -eq 'tools' -or $Suite -eq 'all') {
    $toolArgs = @{ RepoRoot = $RepoRoot; Python = $Python }
    if ($Full) { $toolArgs.Full = $true }
    Invoke-Suite -Name 'tools' -Path $tools -Arguments $toolArgs
}

if ($Suite -eq 'frame' -or $Suite -eq 'all') {
    Invoke-FrameCheck -CharsRoot (Join-Path $RepoRoot 'game\chars') `
                      -ToolPath (Join-Path $RepoRoot 'tools\frame_data.py') `
                      -Python $Python
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

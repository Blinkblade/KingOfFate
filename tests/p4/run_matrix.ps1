#Requires -Version 5.1
<#
.SYNOPSIS
    Runs a matrix of head-to-head matches and reports which ones stayed clean.

.DESCRIPTION
    P4 asked for "multiple combinations of matches with no problems". Doing that
    by hand means six copy-pasted command lines whose results nobody can
    reproduce. This script owns the matrix: every combination lives here, each
    run delegates to tests/p3/run_match_watch.ps1, and the result of a
    configuration is decided by ONE machine-checkable line in each harness
    report -- `crashlogs : 0 new during the run`.

    It deliberately does not look at screenshots. Whether a run "worked" is a
    question about the engine's own crash logs; what the frames contain is read
    afterwards, separately, by tools/read_frame_text.py.

.PARAMETER RunSec
    Wall-clock seconds per match (default 24). Long enough for both AI to
    actually reach each other and trade hits.

.PARAMETER OutDir
    Where screenshots and reports go. Default logs/p4/matrix.

.PARAMETER Only
    Run only the configurations whose name contains this string.

.EXAMPLE
    pwsh -File tests/p4/run_matrix.ps1
    pwsh -File tests/p4/run_matrix.ps1 -Only mirror -RunSec 15
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [int]$RunSec = 24,
    [int]$WarmupSec = 10,
    [int]$Shots = 4,
    [string]$OutDir,
    [string]$Only
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot | Split-Path -Parent }
if (-not $OutDir)   { $OutDir = Join-Path $RepoRoot 'logs\p4\matrix' }
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$harness = Join-Path $RepoRoot 'tests\p3\run_match_watch.ps1'

# The matrix. Every KingOfFate character vs every other, both seat orders, plus
# an asymmetric AI level to catch "only works when both sides cheat equally".
$matrix = @(
    @{ Name = 'b_vs_a';  P1 = 'test_fighter_b'; P2 = 'test_fighter_a'; Ai1 = 8; Ai2 = 8 }
    @{ Name = 'a_vs_b';  P1 = 'test_fighter_a'; P2 = 'test_fighter_b'; Ai1 = 8; Ai2 = 8 }
    @{ Name = 'mirror_b'; P1 = 'test_fighter_b'; P2 = 'test_fighter_b'; Ai1 = 8; Ai2 = 8 }
    @{ Name = 'mirror_a'; P1 = 'test_fighter_a'; P2 = 'test_fighter_a'; Ai1 = 8; Ai2 = 8 }
    @{ Name = 'asym_ai'; P1 = 'test_fighter_b'; P2 = 'test_fighter_a'; Ai1 = 3; Ai2 = 8 }
    @{ Name = 'vs_kfm';  P1 = 'test_fighter_b'; P2 = 'kfm_zss';        Ai1 = 8; Ai2 = 8 }
)

if ($Only) { $matrix = @($matrix | Where-Object { $_.Name -like "*$Only*" }) }

Write-Host '============================================================'
Write-Host ' P4 match matrix'
Write-Host ('   repo     : {0}' -f $RepoRoot)
Write-Host ('   outdir   : {0}' -f $OutDir)
Write-Host ('   configs  : {0}' -f ($matrix.Name -join ', '))
Write-Host '============================================================'

$results = New-Object System.Collections.ArrayList
$failed = 0

foreach ($cfg in $matrix) {
    $prefix = 'm_' + $cfg.Name
    Write-Host ('{0}--- {1} : {2} vs {3} (ai {4}/{5}) ---' -f [Environment]::NewLine, $cfg.Name, $cfg.P1, $cfg.P2, $cfg.Ai1, $cfg.Ai2)

    try {
        & pwsh -NoProfile -File $harness `
            -P1 $cfg.P1 -P2 $cfg.P2 -Stage 'stage0' `
            -Ai1 $cfg.Ai1 -Ai2 $cfg.Ai2 `
            -RoundTime 60 -RunSec $RunSec -WarmupSec $WarmupSec -Shots $Shots `
            -OutDir $OutDir -Prefix $prefix -ShowDebug 2>&1 | ForEach-Object { Write-Host ('      ' + $_) }
        $exit = $LASTEXITCODE
    } catch {
        Write-Host ('      EXCEPTION: ' + $_.Exception.Message)
        $exit = -1
    }

    $report = Join-Path $OutDir ($prefix + '_report.txt')
    $crashLine = $null
    if (Test-Path -LiteralPath $report) {
        $crashLine = (Select-String -LiteralPath $report -Pattern '^crashlogs' -Encoding utf8 | Select-Object -Last 1).Line
    }

    if ($exit -eq 0 -and $crashLine -and $crashLine -match '0 new') {
        $verdict = 'PASS'
    } else {
        $verdict = 'FAIL'
        $failed++
    }

    Write-Host ('      => {0}   (harness exit={1}, crash line: {2})' -f $verdict, $exit, $crashLine)
    [void]$results.Add([pscustomobject]@{
        Config    = $cfg.Name
        P1        = $cfg.P1
        P2        = $cfg.P2
        Ai        = ('{0}/{1}' -f $cfg.Ai1, $cfg.Ai2)
        Exit      = $exit
        CrashLog  = ($crashLine -replace 'crashlogs\s*:\s*', '')
        Verdict   = $verdict
    })
}

Write-Host ''
Write-Host '============================================================'
Write-Host ' matrix summary'
Write-Host '============================================================'
$results | Format-Table -AutoSize | Out-String | Write-Host

$summaryPath = Join-Path $OutDir 'matrix_summary.txt'
$lines = @('P4 match matrix summary', ('generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')), '')
foreach ($r in $results) {
    $lines += ('{0,-10} {1,-16} vs {2,-16} ai={3,-5} exit={4,-4} crash={5,-24} {6}' -f $r.Config, $r.P1, $r.P2, $r.Ai, $r.Exit, $r.CrashLog, $r.Verdict)
}
$lines += ''
$lines += ('total={0}  FAIL={1}' -f $results.Count, $failed)
[System.IO.File]::WriteAllLines($summaryPath, $lines, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ('written: {0}' -f $summaryPath)

if ($failed -gt 0) { exit 1 }
Write-Host 'MATCH MATRIX PASS'
exit 0

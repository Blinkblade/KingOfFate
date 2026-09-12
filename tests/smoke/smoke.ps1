#Requires -Version 5.1
<#
.SYNOPSIS
    KingOfFate phase-level smoke test.

.DESCRIPTION
    Verifies the minimum set of invariants the project depends on:

      A. the IKEMEN GO submodule exists and still points at the pinned baseline
      B. the engine runtime directories are present
      C. the engine has been built
      D. the basic files needed to actually run a match are present
      E. the project scaffolding / documentation exists

    With -RuntimeTest it additionally launches the engine for a single automated
    round and checks that it starts and exits cleanly.

    Exit code: 0 = PASS, non-zero = FAIL.

.PARAMETER RepoRoot
    Project root. Defaults to the grandparent of this script.

.PARAMETER ExpectedEngineCommit
    The pinned IKEMEN GO commit. Override only when the baseline is intentionally
    updated (see CONTRIBUTING.md "Engine changes").

.PARAMETER RuntimeTest
    Also launch the engine for one automated round.

.PARAMETER RuntimeTimeoutSec
    How long the engine must stay alive and responsive before the launch is
    considered healthy. The test instance is terminated afterwards.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$ExpectedEngineCommit = 'ba516193bba83f13f0b63ddce314d8719793931f',
    [switch]$RuntimeTest,
    [int]$RuntimeTimeoutSec = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).ProviderPath
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath

$EngineDir = Join-Path $RepoRoot 'engine\ikemen-go'
$Executable = Join-Path $EngineDir 'Ikemen_GO.exe'

$script:Results = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param(
        [Parameter(Mandatory)][string]$Group,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Passed,
        [string]$Detail = ''
    )
    $script:Results.Add([pscustomobject]@{
            Group  = $Group
            Name   = $Name
            Passed = $Passed
            Detail = $Detail
        })
}

function Test-PathCheck {
    param([string]$Group, [string]$Name, [string]$Path, [string]$Kind = 'any')
    $exists = Test-Path -LiteralPath $Path
    if ($exists -and $Kind -eq 'file') { $exists = -not (Get-Item -LiteralPath $Path).PSIsContainer }
    if ($exists -and $Kind -eq 'dir') { $exists = (Get-Item -LiteralPath $Path).PSIsContainer }
    $rel = $Path
    if ($Path.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $Path.Substring($RepoRoot.Length).TrimStart('\', '/')
    }
    Add-Check -Group $Group -Name $Name -Passed $exists -Detail $rel
    return $exists
}

Write-Host ''
Write-Host 'KingOfFate smoke test' -ForegroundColor White
Write-Host "root: $RepoRoot" -ForegroundColor DarkGray
Write-Host ('-' * 72) -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# A. Submodule + pinned baseline
# ---------------------------------------------------------------------------
Write-Host 'A. engine submodule / pinned baseline' -ForegroundColor Cyan

Test-PathCheck -Group 'A' -Name 'submodule directory exists' -Path $EngineDir -Kind 'dir' | Out-Null
Test-PathCheck -Group 'A' -Name 'submodule git metadata exists' -Path (Join-Path $EngineDir '.git') | Out-Null
Test-PathCheck -Group 'A' -Name '.gitmodules exists' -Path (Join-Path $RepoRoot '.gitmodules') -Kind 'file' | Out-Null

$engineHead = ''
$engineBranch = ''
if (Test-Path -LiteralPath (Join-Path $EngineDir '.git')) {
    try {
        $engineHead = (& git -C $EngineDir rev-parse HEAD 2>$null | Select-Object -First 1)
        if ($engineHead) { $engineHead = $engineHead.Trim() }
    }
    catch { $engineHead = '' }
    try {
        $engineBranch = (& git -C $EngineDir branch --show-current 2>$null | Select-Object -First 1)
    }
    catch { $engineBranch = '' }
}

$headOk = ($engineHead -eq $ExpectedEngineCommit)
Add-Check -Group 'A' -Name 'engine baseline commit matches pin' -Passed $headOk `
    -Detail ("expected {0} / found {1}" -f $ExpectedEngineCommit.Substring(0, 12), $(if ($engineHead) { $engineHead.Substring(0, [Math]::Min(12, $engineHead.Length)) } else { '<none>' }))

if ($engineBranch) {
    Add-Check -Group 'A' -Name 'engine on integration branch kingoffate/rc5' -Passed ($engineBranch -eq 'kingoffate/rc5') -Detail $engineBranch
}

$gitmodulesOk = $false
$gm = Join-Path $RepoRoot '.gitmodules'
if (Test-Path -LiteralPath $gm) {
    $gmText = Get-Content -LiteralPath $gm -Raw
    $gitmodulesOk = ($gmText -match 'engine/ikemen-go') -and ($gmText -match 'Blinkblade/Ikemen-GO\.git')
}
Add-Check -Group 'A' -Name '.gitmodules points at the engine fork' -Passed $gitmodulesOk -Detail 'engine/ikemen-go -> Blinkblade/Ikemen-GO'

# ---------------------------------------------------------------------------
# B. Runtime directories
# ---------------------------------------------------------------------------
Write-Host 'B. engine runtime directories' -ForegroundColor Cyan
foreach ($d in @('data', 'font', 'external', 'chars', 'stages')) {
    Test-PathCheck -Group 'B' -Name "runtime dir: $d/" -Path (Join-Path $EngineDir $d) -Kind 'dir' | Out-Null
}

# ---------------------------------------------------------------------------
# C. Build artifact
# ---------------------------------------------------------------------------
Write-Host 'C. build artifact' -ForegroundColor Cyan
$exeOk = Test-PathCheck -Group 'C' -Name 'engine executable built' -Path $Executable -Kind 'file'
if ($exeOk) {
    $size = (Get-Item -LiteralPath $Executable).Length
    Add-Check -Group 'C' -Name 'executable size is plausible (> 5 MB)' -Passed ($size -gt 5MB) -Detail ("{0:N2} MB" -f ($size / 1MB))
}

# ---------------------------------------------------------------------------
# D. Basic files required to run a match
# ---------------------------------------------------------------------------
Write-Host 'D. basic runtime files' -ForegroundColor Cyan
$requiredFiles = @(
    @{ n = 'default motif (data/ikemen1/system.def)'; p = 'data\ikemen1\system.def' },
    @{ n = 'fight screen (data/fight.def)'; p = 'data\fight.def' },
    @{ n = 'test character (chars/kfm/kfm.def)'; p = 'chars\kfm\kfm.def' },
    @{ n = 'test stage (stages/stage0.def)'; p = 'stages\stage0.def' }
)
foreach ($f in $requiredFiles) {
    Test-PathCheck -Group 'D' -Name $f.n -Path (Join-Path $EngineDir $f.p) -Kind 'file' | Out-Null
}

# ---------------------------------------------------------------------------
# E. Project scaffolding
# ---------------------------------------------------------------------------
Write-Host 'E. project scaffolding' -ForegroundColor Cyan
$scaffold = @(
    @{ n = 'README.md'; p = 'README.md' },
    @{ n = 'CONTRIBUTING.md'; p = 'CONTRIBUTING.md' },
    @{ n = 'docs/development_status.md'; p = 'docs\development_status.md' },
    @{ n = 'docs/environment.md'; p = 'docs\environment.md' },
    @{ n = 'docs/iterations/README.md'; p = 'docs\iterations\README.md' },
    @{ n = '.github/pull_request_template.md'; p = '.github\pull_request_template.md' },
    @{ n = 'scripts/build_engine.ps1'; p = 'scripts\build_engine.ps1' },
    @{ n = 'scripts/run_game.ps1'; p = 'scripts\run_game.ps1' },
    @{ n = 'scripts/test.ps1'; p = 'scripts\test.ps1' }
)
foreach ($f in $scaffold) {
    Test-PathCheck -Group 'E' -Name $f.n -Path (Join-Path $RepoRoot $f.p) -Kind 'file' | Out-Null
}

# ---------------------------------------------------------------------------
# F. Optional runtime test
# ---------------------------------------------------------------------------
if ($RuntimeTest) {
    Write-Host 'F. runtime test (one automated round)' -ForegroundColor Cyan
    if (-not (Test-Path -LiteralPath $Executable)) {
        Add-Check -Group 'F' -Name 'engine launch' -Passed $false -Detail 'executable missing'
    }
    else {
        # The executable resolves SDL2/libxmp/FFmpeg from the MSYS2 mingw64 prefix when
        # the build used the system FFmpeg (BUILD_FFMPEG=no) and did not bundle DLLs.
        if (-not (Test-Path -LiteralPath (Join-Path $EngineDir 'SDL2.dll'))) {
            foreach ($c in @($env:MSYS2_ROOT, $env:MSYS2_HOME, 'C:\msys64', 'D:\msys64')) {
                if ([string]::IsNullOrWhiteSpace($c)) { continue }
                $mb = Join-Path $c 'mingw64\bin'
                if (Test-Path -LiteralPath (Join-Path $mb 'SDL2.dll')) {
                    $env:PATH = "$mb;$env:PATH"
                    Write-Host "     dll path: $mb" -ForegroundColor DarkGray
                    break
                }
            }
        }

        # Quick VS flags as documented by the engine's own help text. Note that this
        # RC5 baseline does not implement an automatic "quit after N rounds": the
        # "-rounds" key is parsed but never read by the engine, so this test verifies
        # start-up health and then terminates the process itself.
        $args = @('-p1', 'kfm', '-p2', 'kfm', '-s', 'stage0', '-windowed', '-nosound', '-nomusic')
        $proc = $null
        $started = $false
        $failure = ''
        try {
            $proc = Start-Process -FilePath $Executable -WorkingDirectory $EngineDir -ArgumentList $args -PassThru
            $started = $true
        }
        catch { $failure = $_.Exception.Message }

        Add-Check -Group 'F' -Name 'engine process starts' -Passed $started -Detail $(if ($started) { "pid $($proc.Id)" } else { $failure })

        if ($started) {
            # Wait for a real window to appear (the engine creates it during video init).
            $windowDeadline = (Get-Date).AddSeconds(90)
            $windowed = $false
            while ((Get-Date) -lt $windowDeadline) {
                $proc.Refresh()
                if ($proc.HasExited) { break }
                if ($proc.MainWindowHandle -ne 0) { $windowed = $true; break }
                Start-Sleep -Milliseconds 500
            }
            Add-Check -Group 'F' -Name 'engine creates a game window' -Passed $windowed -Detail $(if ($windowed) { "title '$($proc.MainWindowTitle)'" } else { 'no window created' })

            # The engine must keep running without crashing or exiting on its own.
            $graceDeadline = (Get-Date).AddSeconds($RuntimeTimeoutSec)
            $crashed = $false
            $exitCode = $null
            while ((Get-Date) -lt $graceDeadline) {
                $proc.Refresh()
                if ($proc.HasExited) { $crashed = $true; $exitCode = $proc.ExitCode; break }
                Start-Sleep -Milliseconds 500
            }
            $responsive = $false
            if (-not $crashed) { $proc.Refresh(); $responsive = $proc.Responding }
            Add-Check -Group 'F' -Name "engine stays alive and responsive for ${RuntimeTimeoutSec}s" -Passed (-not $crashed -and $responsive) `
                -Detail $(if ($crashed) { "exited early with code $exitCode" } elseif ($responsive) { 'ok, terminating test instance' } else { 'process not responding' })

            if (-not $proc.HasExited) {
                try { $proc.Kill(); $proc.WaitForExit(10000) | Out-Null } catch { }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
Write-Host ('-' * 72) -ForegroundColor DarkGray
foreach ($r in $script:Results) {
    $mark = 'PASS'
    $colour = 'Green'
    if (-not $r.Passed) { $mark = 'FAIL'; $colour = 'Red' }
    $line = "  [{0}] {1}" -f $mark, $r.Name
    if ($r.Detail) { $line += "   ($($r.Detail))" }
    Write-Host $line -ForegroundColor $colour
}

$failed = @($script:Results | Where-Object { -not $_.Passed })
$total = $script:Results.Count

Write-Host ('-' * 72) -ForegroundColor DarkGray
Write-Host ("smoke test: {0}/{1} checks passed" -f ($total - $failed.Count), $total) -ForegroundColor $(if ($failed.Count -eq 0) { 'Green' } else { 'Red' })

if ($failed.Count -gt 0) {
    Write-Host ''
    Write-Host 'Failed checks:' -ForegroundColor Red
    foreach ($f in $failed) {
        $msg = "  - [$($f.Group)] $($f.Name)"
        if ($f.Detail) { $msg += "  -> $($f.Detail)" }
        Write-Host $msg -ForegroundColor Red
    }
    Write-Host ''
    exit 1
}

Write-Host ''
Write-Host 'SMOKE TEST PASS' -ForegroundColor Green
Write-Host ''
exit 0

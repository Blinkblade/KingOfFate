#Requires -Version 5.1
<#
.SYNOPSIS
    Tests for the KingOfFate character asset tools (P5).

.DESCRIPTION
    Exercises the three command line tools and the shared reader against

      * the real characters in game/chars/            (happy path)
      * generated fixtures in tests/fixtures/assets/  (happy path + every failure mode)
      * deliberately broken input                     (exit codes and error messages)

    Coverage per tool:

      sffctl    inspect / export / montage, --json, every exit code, --overwrite,
                deterministic file names, missing sprite, missing file, wrong type,
                unsupported version, truncated file, bad signature
      airtool   inspect / validate, action selection, exit codes, duplicate action,
                empty action, box-count mismatch, orphan box line, missing sprite,
                bad time, and both halves of the P4 projectile case (a per-frame
                Clsn1 in front of a -1 hold must be reported as not persistent; the
                same animation with Clsn1Default must not be)
      validate_character
                a consistent fixture character, the three real characters, a
                character with missing files, one whose script asks for an animation
                that does not exist, one whose SFF is an unsupported version

    The whole suite never deletes anything and never writes outside logs/p5.

    Exit code: 0 = PASS, non-zero = FAIL.

.PARAMETER RepoRoot
    Project root. Defaults to the grandparent of this script.

.PARAMETER Python
    Python interpreter to use. Defaults to 'python' from PATH.
    Requires Python 3.8 or newer; the tools use the standard library only.

.PARAMETER Full
    Also export all 282 sprites of a real character and build a montage. Slower,
    so it is not part of the default run; run it before a release, or after
    changing anything under tools/.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$Python = 'python',
    [switch]$Full
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

$ToolsDir = Join-Path $RepoRoot 'tools'
$Fixtures = Join-Path $RepoRoot 'tests\fixtures\assets'
$WorkDir = Join-Path $RepoRoot 'logs\p5\tool-tests'
$Sffctl = Join-Path $ToolsDir 'sffctl\sffctl.py'
$Airtool = Join-Path $ToolsDir 'airtool\airtool.py'
$Validate = Join-Path $ToolsDir 'character_validate\validate_character.py'
$MakeFixtures = Join-Path $RepoRoot 'tests\fixtures\make_fixtures.py'
$VerifyDecoders = Join-Path $RepoRoot 'tests\fixtures\verify_decoders.py'
$CheckExport = Join-Path $ScriptDir 'check_export.py'

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

# Runs the tools with an expected exit code and optional output substrings.
function Invoke-Tool {
    param(
        [Parameter(Mandatory)][string]$Group,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][int]$Expect,
        [string[]]$MustContain = @()
    )
    $lines = @()
    $code = -1
    try {
        $lines = @(& $Python @Arguments 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
    }
    catch {
        $lines = @("$($_.Exception.Message)")
        $code = -1
    }
    $text = ($lines -join "`n")

    $ok = ($code -eq $Expect)
    $detail = "exit $code (expected $Expect)"
    if ($ok) {
        foreach ($needle in $MustContain) {
            if ($text -notlike "*$needle*") {
                $ok = $false
                $detail = "exit $code, but output does not contain '$needle'"
                break
            }
        }
    }
    Add-Check -Group $Group -Name $Label -Passed $ok -Detail $detail
    return [pscustomobject]@{ Code = $code; Text = $text; Lines = $lines }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

Write-Host ''
Write-Host 'KingOfFate asset tool tests' -ForegroundColor White
Write-Host "root:   $RepoRoot" -ForegroundColor DarkGray
Write-Host "python: $Python" -ForegroundColor DarkGray
Write-Host ('-' * 72) -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# 0. Preconditions
# ---------------------------------------------------------------------------
Write-Host '0. preconditions' -ForegroundColor Cyan

$resolved = $null
try { $resolved = (Get-Command $Python -ErrorAction Stop).Source } catch { }
Add-Check -Group '0' -Name 'python interpreter is available' -Passed ($null -ne $resolved) `
    -Detail $(if ($resolved) { $resolved } else { "cannot find '$Python' on PATH" })

if ($null -eq $resolved) {
    Write-Host 'Cannot continue without a Python interpreter.' -ForegroundColor Red
    exit 1
}

foreach ($f in @($Sffctl, $Airtool, $Validate, $MakeFixtures, $VerifyDecoders, $CheckExport)) {
    Add-Check -Group '0' -Name "tool exists: $(Split-Path -Leaf $f)" `
        -Passed (Test-Path -LiteralPath $f)
}

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

# ---------------------------------------------------------------------------
# 1. Fixtures and the shared reader
# ---------------------------------------------------------------------------
Write-Host '1. fixtures and reader' -ForegroundColor Cyan

Invoke-Tool -Group '1' -Label 'generated fixtures match the tracker' `
    -Arguments @($MakeFixtures, '--check') -Expect 0 | Out-Null
Invoke-Tool -Group '1' -Label 'decoded pixels match known patterns and goldens' `
    -Arguments @($VerifyDecoders) -Expect 0 -MustContain @('decoder checks:') | Out-Null

# ---------------------------------------------------------------------------
# 2. sffctl inspect
# ---------------------------------------------------------------------------
Write-Host '2. sffctl inspect' -ForegroundColor Cyan

$realSff = Join-Path $RepoRoot 'game\chars\test_fighter_b\test_fighter_b.sff'
$r = Invoke-Tool -Group '2' -Label 'real container is summarised' `
    -Arguments @($Sffctl, 'inspect', $realSff) -Expect 0 `
    -MustContain @('Version:   2.0.1.0', 'Sprites:   282', 'Palettes:  16')
$rJson = Invoke-Tool -Group '2' -Label 'inspect --json runs' `
    -Arguments @($Sffctl, 'inspect', $realSff, '--json') -Expect 0 -MustContain @('"sprite_count"')
$json = $null
$jsonError = ''
try { $json = ($rJson.Text | ConvertFrom-Json) } catch { $jsonError = $_.Exception.Message }
Add-Check -Group '2' -Name 'real container is summarised (--json)' -Passed ($null -ne $json) `
    -Detail $jsonError
if ($null -ne $json) {
    $shapeOk = ($json.version -eq '2.0.1.0') -and ($json.sprite_count -eq 282) -and
               ($json.sprites.Count -gt 0) -and
               ($null -ne $json.sprites[0].group) -and ($null -ne $json.sprites[0].axis_x)
    Add-Check -Group '2' -Name '--json exposes version, count, group and axis' -Passed $shapeOk
}

foreach ($c in @(
        @{ n = 'missing file is IO (3)'; p = (Join-Path $Fixtures 'nope.sff'); e = 3; m = 'no such file' },
        @{ n = 'directory instead of file is IO (3)'; p = $Fixtures; e = 3; m = 'is a directory' },
        @{ n = 'SFF v1 is UNSUPPORTED (4)'; p = (Join-Path $Fixtures 'unsupported_v1.sff'); e = 4; m = 'SFF v1' },
        @{ n = 'truncated file is CORRUPT (5)'; p = (Join-Path $Fixtures 'truncated.sff'); e = 5; m = 'truncated or corrupt' },
        @{ n = 'bad signature is CORRUPT (5)'; p = (Join-Path $Fixtures 'bad_signature.sff'); e = 5; m = 'bad SFF signature' }
    )) {
    Invoke-Tool -Group '2' -Label $c.n -Arguments @($Sffctl, 'inspect', $c.p) `
        -Expect $c.e -MustContain @($c.m) | Out-Null
}

# ---------------------------------------------------------------------------
# 3. sffctl export
# ---------------------------------------------------------------------------
Write-Host '3. sffctl export' -ForegroundColor Cyan

$fixSff = Join-Path $Fixtures 'minimal_v2.sff'
$outA = Join-Path $WorkDir 'fixture_a'
$outB = Join-Path $WorkDir 'fixture_b'

Invoke-Tool -Group '3' -Label 'fixture container exports all sprites' `
    -Arguments @($Sffctl, 'export', $fixSff, '--out', $outA, '--overwrite') `
    -Expect 0 -MustContain @('exported 3 of 3') | Out-Null

$named = $true
foreach ($name in @('0_0.png', '1_0.png', '2_0.png')) {
    if (-not (Test-Path -LiteralPath (Join-Path $outA $name))) { $named = $false }
}
Add-Check -Group '3' -Name 'files are named <group>_<image>.png' -Passed $named

Invoke-Tool -Group '3' -Label 'written PNGs match the container exactly' `
    -Arguments @($CheckExport, '--sff', $fixSff, '--out', $outA) -Expect 0 `
    -MustContain @('3 file(s) verified, 0 problem(s)') | Out-Null

Invoke-Tool -Group '3' -Label 'a second export into a fresh directory is byte-identical' `
    -Arguments @($Sffctl, 'export', $fixSff, '--out', $outB, '--overwrite') -Expect 0 | Out-Null
$same = $true
foreach ($name in @('0_0.png', '1_0.png', '2_0.png')) {
    if ((Get-Sha256 (Join-Path $outA $name)) -ne (Get-Sha256 (Join-Path $outB $name))) { $same = $false }
}
Add-Check -Group '3' -Name 'export is deterministic (same bytes)' -Passed $same

Invoke-Tool -Group '3' -Label 'existing files are not overwritten by default' `
    -Arguments @($Sffctl, 'export', $fixSff, '--out', $outA) -Expect 1 `
    -MustContain @('SFF_EXPORT_NO_OVERWRITE') | Out-Null

Invoke-Tool -Group '3' -Label 'a missing sprite fails with exit 1' `
    -Arguments @($Sffctl, 'export', $fixSff, '--out', $outA, '--sprite', '99,99') -Expect 1 `
    -MustContain @('is not in') | Out-Null

Invoke-Tool -Group '3' -Label 'a usage error exits 2' `
    -Arguments @($Sffctl, 'export', $fixSff) -Expect 2 | Out-Null

if ($Full) {
    $outAll = Join-Path $WorkDir 'real_all'
    Invoke-Tool -Group '3' -Label 'all 282 real sprites export and verify' `
        -Arguments @($Sffctl, 'export', $realSff, '--out', $outAll, '--overwrite') `
        -Expect 0 -MustContain @('exported 282 of 282') | Out-Null
    Invoke-Tool -Group '3' -Label 'exported real sprites match the container' `
        -Arguments @($CheckExport, '--sff', $realSff, '--out', $outAll) -Expect 0 `
        -MustContain @('282 file(s) verified, 0 problem(s)') | Out-Null

    $montage1 = Join-Path $WorkDir 'montage_1.png'
    $montage2 = Join-Path $WorkDir 'montage_2.png'
    Invoke-Tool -Group '3' -Label 'montage renders every sprite' `
        -Arguments @($Sffctl, 'montage', $realSff, '--out', $montage1) -Expect 0 `
        -MustContain @('282 sprite(s) drawn') | Out-Null
    Invoke-Tool -Group '3' -Label 'montage is deterministic' `
        -Arguments @($Sffctl, 'montage', $realSff, '--out', $montage2) -Expect 0 | Out-Null
    $montageSame = (Test-Path -LiteralPath $montage1) -and
                   ((Get-Sha256 $montage1) -eq (Get-Sha256 $montage2))
    Add-Check -Group '3' -Name 'montage output is byte-identical between runs' -Passed $montageSame
}

# ---------------------------------------------------------------------------
# 4. airtool inspect
# ---------------------------------------------------------------------------
Write-Host '4. airtool inspect' -ForegroundColor Cyan

$realAir = Join-Path $RepoRoot 'game\chars\test_fighter_b\test_fighter_b.air'
Invoke-Tool -Group '4' -Label 'real animation table is summarised' `
    -Arguments @($Airtool, 'inspect', $realAir) -Expect 0 `
    -MustContain @('Actions:  88', 'infinite') | Out-Null

$r = Invoke-Tool -Group '4' -Label 'a single action can be inspected' `
    -Arguments @($Airtool, 'inspect', $realAir, '--action', '1005') -Expect 0 `
    -MustContain @('Infinite element: yes', 'Duration:  infinite')
Add-Check -Group '4' -Name 'action 1005 reports an -1 hold' -Passed ($r.Text -like '*has a -1 hold*')

$r2 = Invoke-Tool -Group '4' -Label 'action data is available as JSON' `
    -Arguments @($Airtool, 'inspect', $realAir, '--action', '210', '--json') -Expect 0
$j2 = $null
$jsonError = ''
try { $j2 = ($r2.Text | ConvertFrom-Json) } catch { $jsonError = $_.Exception.Message }
Add-Check -Group '4' -Name 'JSON action carries elements and collision modes' `
    -Passed ($null -ne $j2 -and $j2.actions[0].element_data.Count -eq 8) -Detail $jsonError
if ($null -ne $j2) {
    $active = $j2.actions[0].element_data | Where-Object { $_.clsn1.mode -eq 'per-frame' }
    Add-Check -Group '4' -Name 'the active element carries a per-frame attack box' `
        -Passed ($null -ne $active -and $active.clsn1.count -eq 2)
}

Invoke-Tool -Group '4' -Label 'an unknown action exits 1' `
    -Arguments @($Airtool, 'inspect', $realAir, '--action', '77777') -Expect 1 `
    -MustContain @('are not in') | Out-Null
Invoke-Tool -Group '4' -Label 'a missing file exits 3' `
    -Arguments @($Airtool, 'inspect', (Join-Path $Fixtures 'nope.air')) -Expect 3 `
    -MustContain @('no such file') | Out-Null

# ---------------------------------------------------------------------------
# 5. airtool validate (fixtures: every failure mode)
# ---------------------------------------------------------------------------
Write-Host '5. airtool validate' -ForegroundColor Cyan

function Test-AirFixture {
    param(
        [string]$Label, [string]$File, [int]$Expect,
        [string[]]$MustContain = @(), [string[]]$MustNotContain = @()
    )
    $toolArgs = @($Airtool, 'validate', (Join-Path $Fixtures $File), '--sff',
        (Join-Path $Fixtures 'minimal_v2.sff'))
    $result = Invoke-Tool -Group '5' -Label $Label -Arguments $toolArgs -Expect $Expect `
        -MustContain $MustContain
    foreach ($needle in $MustNotContain) {
        if ($result.Text -like "*$needle*") {
            $script:Results.Add([pscustomobject]@{
                    Group = '5'; Name = "$Label (must not report $needle)"; Passed = $false
                    Detail = 'it was reported'
                })
        }
        else {
            $script:Results.Add([pscustomobject]@{
                    Group = '5'; Name = "$Label (must not report $needle)"; Passed = $true; Detail = ''
                })
        }
    }
    return $result
}

Test-AirFixture -Label 'a clean table validates' -File 'ok.air' -Expect 0 | Out-Null
Test-AirFixture -Label 'a duplicate action is an error' -File 'dup_action.air' -Expect 1 `
    -MustContain @('AIR_DUPLICATE_ACTION') | Out-Null
Test-AirFixture -Label 'an empty action is an error' -File 'empty_action.air' -Expect 1 `
    -MustContain @('AIR_EMPTY_ACTION') | Out-Null
Test-AirFixture -Label 'a box count mismatch is an error' -File 'bad_box_count.air' -Expect 1 `
    -MustContain @('AIR_BOX_COUNT_MISMATCH') | Out-Null
Test-AirFixture -Label 'a missing sprite is an error' -File 'missing_sprite.air' -Expect 1 `
    -MustContain @('AIR_MISSING_SPRITE') | Out-Null
Test-AirFixture -Label 'an impossible time is an error' -File 'bad_time.air' -Expect 1 `
    -MustContain @('AIR_BAD_TIME') | Out-Null
Test-AirFixture -Label 'an orphan box line is a warning, not an error' -File 'orphan_box.air' `
    -Expect 0 -MustContain @('AIR_ORPHAN_BOX_LINE') | Out-Null

# The two halves of the P4 projectile case. Reported separately, and then checked
# at the data level: the parser must not confuse a per-frame box with a default.
Test-AirFixture -Label 'P4 negative: per-frame Clsn1 in front of a -1 hold is flagged' `
    -File 'p4_per_frame_hold.air' -Expect 0 -MustContain @('AIR_ATTACK_NOT_PERSISTENT') | Out-Null
Test-AirFixture -Label 'P4 positive: Clsn1Default in front of a -1 hold is not flagged' `
    -File 'p4_default_hold.air' -Expect 0 -MustContain @('AIR_ATTACK_PERSISTENT') `
    -MustNotContain @('AIR_ATTACK_NOT_PERSISTENT') | Out-Null

foreach ($case in @(
        @{ f = 'p4_per_frame_hold.air'; mode = 'none'; count = 0; label = 'per-frame' },
        @{ f = 'p4_default_hold.air'; mode = 'default'; count = 1; label = 'default' }
    )) {
    $r = Invoke-Tool -Group '5' -Label "$($case.label) hold element collision is parsed as expected" `
        -Arguments @($Airtool, 'inspect', (Join-Path $Fixtures $case.f), '--action', '1005',
            '--json') -Expect 0
    $parsed = $null
    try { $parsed = ($r.Text | ConvertFrom-Json) } catch { }
    $ok = $false
    if ($null -ne $parsed) {
        $hold = $parsed.actions[0].element_data | Where-Object { $_.infinite }
        $ok = ($null -ne $hold) -and ($hold.clsn1.mode -eq $case.mode) -and
              ($hold.clsn1.count -eq $case.count)
    }
    Add-Check -Group '5' -Name "$($case.label) hold element: mode=$($case.mode), boxes=$($case.count)" `
        -Passed $ok
}

# ---------------------------------------------------------------------------
# 6. character_validate
# ---------------------------------------------------------------------------
Write-Host '6. character_validate' -ForegroundColor Cyan

Invoke-Tool -Group '6' -Label 'a consistent fixture character passes' `
    -Arguments @($Validate, (Join-Path $Fixtures 'char_ok')) -Expect 0 `
    -MustContain @('Character: char_ok', 'DEF', 'PASS') | Out-Null

foreach ($character in @('_template', 'test_fighter_a', 'test_fighter_b')) {
    Invoke-Tool -Group '6' -Label "the real character $character validates" `
        -Arguments @($Validate, (Join-Path $RepoRoot "game\chars\$character")) -Expect 0 `
        -MustContain @('SFF content', 'PASS', 'AIR content') | Out-Null
}

Invoke-Tool -Group '6' -Label 'a character with missing files fails' `
    -Arguments @($Validate, (Join-Path $Fixtures 'char_missing_files')) -Expect 1 `
    -MustContain @('DEF_UNRESOLVED_FILE') | Out-Null
Invoke-Tool -Group '6' -Label 'a script asking for a missing animation fails' `
    -Arguments @($Validate, (Join-Path $Fixtures 'char_zss_missing_anim')) -Expect 1 `
    -MustContain @('ZSS_MISSING_ACTION') | Out-Null
Invoke-Tool -Group '6' -Label 'an unsupported SFF version fails' `
    -Arguments @($Validate, (Join-Path $Fixtures 'char_v1_sprite')) -Expect 1 `
    -MustContain @('SFF_UNSUPPORTED') | Out-Null
Invoke-Tool -Group '6' -Label 'a missing character exits 3' `
    -Arguments @($Validate, (Join-Path $Fixtures 'no_such_character')) -Expect 3 `
    -MustContain @('no such character') | Out-Null

$r = Invoke-Tool -Group '6' -Label 'the verdict is available as JSON' `
    -Arguments @($Validate, (Join-Path $RepoRoot 'game\chars\test_fighter_b'), '--json') -Expect 0
$verdict = $null
$jsonError = ''
try { $verdict = ($r.Text | ConvertFrom-Json) } catch { $jsonError = $_.Exception.Message }
Add-Check -Group '6' -Name 'JSON verdict lists per-item statuses' `
    -Passed ($null -ne $verdict -and $verdict.checks.Count -ge 8 -and
             ($verdict.checks | Where-Object { $_.name -eq 'AIR -> SFF sprites' }).Count -eq 1) `
    -Detail $jsonError

# ---------------------------------------------------------------------------
# 7. nothing was left behind
# ---------------------------------------------------------------------------
Write-Host '7. workspace hygiene' -ForegroundColor Cyan

# The tools are read-only, so a test run must not touch the engine submodule and
# must not scatter PNGs outside the ignored logs directory.
$status = @(& git -C $RepoRoot status --porcelain 2>$null)
$engineTouched = @($status | Where-Object { $_ -match 'engine/ikemen-go' })
Add-Check -Group '7' -Name 'the engine submodule was not modified' -Passed ($engineTouched.Count -eq 0) `
    -Detail ($engineTouched -join '; ')
$strayPng = @($status | Where-Object { $_ -match '\.png$' -and $_ -notmatch 'logs/' })
Add-Check -Group '7' -Name 'no PNG was written outside logs/' -Passed ($strayPng.Count -eq 0) `
    -Detail ($strayPng -join '; ')
$characterTouched = @($status | Where-Object { $_ -match 'game/chars/' -and $_ -notmatch 'test_fighter_b\.air$' })
Add-Check -Group '7' -Name 'no character file other than the AIR sprite fix changed' `
    -Passed ($characterTouched.Count -eq 0) -Detail ($characterTouched -join '; ')

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
Write-Host ('-' * 72) -ForegroundColor DarkGray
foreach ($r in $script:Results) {
    $mark = 'PASS'
    $colour = 'Green'
    if (-not $r.Passed) { $mark = 'FAIL'; $colour = 'Red' }
    $line = "  [$mark] {0,-4} {1}" -f $r.Group, $r.Name
    if (-not $r.Passed -and $r.Detail) { $line += "   ($($r.Detail))" }
    Write-Host $line -ForegroundColor $colour
}

$failed = @($script:Results | Where-Object { -not $_.Passed })
$total = $script:Results.Count

Write-Host ('-' * 72) -ForegroundColor DarkGray
Write-Host ("asset tool tests: {0}/{1} checks passed" -f ($total - $failed.Count), $total) `
    -ForegroundColor $(if ($failed.Count -eq 0) { 'Green' } else { 'Red' })

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
Write-Host 'ASSET TOOL TESTS PASS' -ForegroundColor Green
Write-Host ''
exit 0

#Requires -Version 5.1
<#
.SYNOPSIS
    P6: demonstrate every wired move of the preview Archer, one move per run,
    and keep screenshots as evidence.

.DESCRIPTION
    The owner tried the character by hand and could not input the motions on a
    keyboard. This driver does the inputs for them.

    One engine run per move, because that is what makes the evidence clean:
      * Synthetic input only reaches the engine for TAB, RETURN and the arrow
        keys (P1 experiments, section E0). Everything else is swallowed before
        the command layer sees it. So each run rebinds the one or two buttons
        that move needs onto TAB/RETURN through tests/p2/inject_phases.ps1
        -ButtonMap, which snapshots save/config.ini and restores it in a
        finally block.
      * F3 is the engine's debug hotkey `powMax(1); powMax(2)`; two presses at
        the start of the run give every super its meter without landing a hit.
      * -NoStillShots + -SettleSec 0 + 0.03 s motion steps keeps the phases
        tight enough that the key release and the next key press land inside
        the same 60 Hz frame: the engine then records a clean direction
        transition instead of a neutral in between. Measured: with a 0.02 s
        settle the 41236/236236 motions left neutral frames in the buffer and
        never matched; with settle 0 they do. A
        per-phase still costs ~0.2 s of wall clock while the game keeps
        advancing, which pushed multi-phase motions past their command window
        (measured: 623 with its 0.25 s default window failed with stills and
        worked without).
      * The trailing -Shots land right after the last phase, i.e. inside the
        move's animation, so each run leaves 3 frames carrying the debug
        overlay's `ActionID` / `State No` for that move.

    Evidence is read back with tests/p6/read_move_evidence.py.

.EXAMPLE
    pwsh -File tests/p6/demo_moves.ps1                 # every move
    pwsh -File tests/p6/demo_moves.ps1 -Only UBW_41236_x
#>
[CmdletBinding()]
param(
    [string]$P1 = 'emiya_v2',
    [string]$P2 = 'test_fighter_b',
    [string]$Stage = 'stage0',
    [string]$Only = '',
    [int]$WarmupSec = 10,
    [double]$SettleSec = 0.0,
    [double]$TapSettleSec = 0.07,
    [string]$OutDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).ProviderPath
$Harness = Join-Path $RepoRoot 'tests\p2\inject_phases.ps1'
if (-not $OutDir) { $OutDir = Join-Path $RepoRoot 'logs\p6\moves2' }
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

# Virtual-key codes. Arrows are extended keys; inject_phases handles that.
$L = '0x25'; $U = '0x26'; $R = '0x27'; $D = '0x28'
$TAB = '0x09'; $RET = '0x0D'; $F3 = '0x72'

# Button presses (0.25 s hold so the trailing shots land mid-animation).
$BTN_X = "$TAB`:0.08"; $BTN_Y = "$RET`:0.08"
$BTN_B = "$TAB`:0.08"; $BTN_A = "$RET`:0.08"
$BTN_Z = "$TAB`:0.08"; $BTN_C = "$RET`:0.08"
$FILL = @("$F3`:0.10", "$F3`:0.10")

# Discrete motion phases, one direction per phase (0.05 s), so the sequence the
# engine records is exactly the motion the command expects.
$QCF_M = @("$D`:0.03", "$D+$R`:0.03", "$R`:0.03")
$HCF_M = @("$L`:0.03", "$L+$D`:0.03", "$D`:0.03", "$D+$R`:0.03", "$R`:0.03")
$DP_M = @("$R`:0.03", "$D`:0.03", "$D+$R`:0.03")
$HB_M = @("$D`:0.03", "$D+$L`:0.03", "$L`:0.03")
$HCB_FWD_M = @("$D`:0.03", "$D+$L`:0.03", "$L`:0.03", "$D+$L`:0.03", "$D`:0.03",
    "$D+$R`:0.03", "$R`:0.03")
$DD_M = @("$D`:0.03", "$D`:0.03")
$QCF2_M = @($QCF_M + $QCF_M)

$moves = @(
    @{ name = 'x_light_punch';       map = 'x=TAB';          motion = @();      button = $BTN_X },
    @{ name = 'y_heavy_punch';       map = 'y=RETURN';       motion = @();      button = $BTN_Y },
    @{ name = 'z_heavy_punch';       map = 'z=TAB';          motion = @();      button = $BTN_Z },
    @{ name = 'a_light_kick';        map = 'a=RETURN';       motion = @();      button = $BTN_A },
    @{ name = 'b_heavy_kick';        map = 'b=TAB';          motion = @();      button = $BTN_B },
    @{ name = 'traceP_D_D_x'; settle = 'tap';        map = 'x=TAB';          motion = $DD_M;    button = $BTN_X },
    @{ name = 'traceS_D_D_y'; settle = 'tap';        map = 'y=RETURN';       motion = $DD_M;    button = $BTN_Y },
    @{ name = 'traceK_D_D_a'; settle = 'tap';        map = 'a=RETURN';       motion = $DD_M;    button = $BTN_A },
    @{ name = 'hassya_D_D_b'; settle = 'tap';        map = 'b=TAB';          motion = $DD_M;    button = $BTN_B },
    @{ name = 'taikuuS_623_y';       map = 'y=RETURN';       motion = $DP_M;    button = $BTN_Y },
    @{ name = 'taikuuHS_623_b';      map = 'b=TAB';          motion = $DP_M;    button = $BTN_B },
    @{ name = 'yumiS_41236_y';       map = 'y=RETURN';       motion = $HCF_M;   button = $BTN_Y },
    @{ name = 'yumiHS_41236_b';      map = 'b=TAB';          motion = $HCF_M;   button = $BTN_B },
    @{ name = 'kakato_214_a';        map = 'a=RETURN';       motion = $HB_M;    button = $BTN_A },
    @{ name = 'tokusyu_F_b';         map = 'b=TAB';          motion = @(); button = "$R+$TAB`:0.15" },
    @{ name = 'nage_F_c';            map = 'c=RETURN';       motion = @(); button = "$R+$RET`:0.15" },
    @{ name = 'nage_b_B_c';          map = 'c=RETURN';       motion = @(); button = "$L+$RET`:0.15" },
    @{ name = 'tuika_FF_c';          map = 'c=RETURN';       motion = @("$R`:0.05", "$R`:0.05"); button = "$RET`:0.15" },
    @{ name = 'kusari_2141236_b';    map = 'b=TAB';          motion = $HCB_FWD_M; button = $BTN_B },
    @{ name = 'ComboRash_2141236_y'; map = 'y=RETURN';       motion = $HCB_FWD_M; button = $BTN_Y },
    @{ name = 'UBW_41236_x';         map = 'x=TAB';          motion = $HCF_M;   button = $BTN_X },
    @{ name = 'UBW_S_41236_z';       map = 'z=TAB';          motion = $HCF_M;   button = $BTN_Z },
    @{ name = 'UBW_R_41236_a';       map = 'a=RETURN';       motion = $HCF_M;   button = $BTN_A },
    @{ name = 'UBWX_236236_z';       map = 'z=TAB';          motion = $QCF2_M;  button = $BTN_Z },
    @{ name = 'RO_236236_x';         map = 'x=TAB';          motion = $QCF2_M;  button = $BTN_X },
    @{ name = 'DC_236236_a';         map = 'a=RETURN';       motion = $QCF2_M;  button = $BTN_A },
    @{ name = 'AIR_236236_y';        map = 'y=RETURN';       motion = $QCF2_M;  button = $BTN_Y },
    @{ name = 'FF_dash'; settle = 'tap';             map = '';               motion = @("$R`:0.03", "$R`:0.03"); button = '' },
    @{ name = 'BB_backhop'; settle = 'tap';          map = '';               motion = @("$L`:0.03", "$L`:0.03"); button = '' },
    @{ name = 'BREAK_back_x_a';      map = 'x=TAB,a=RETURN'; motion = @();      button = "$L+$TAB+$RET`:0.15" }
)

$index = New-Object System.Collections.Generic.List[string]
foreach ($m in $moves) {
    if ($Only -and $m.name -ne $Only) { continue }
    $phases = @($FILL + $m.motion)
    if ($m.button) { $phases += $m.button }
    $prefix = "p6mv_$($m.name)"
    $mapLabel = if ($m.map) { $m.map } else { 'none' }
    Write-Host ("=== {0}  (buttons: {1})  {2} phase(s)" -f $m.name, $mapLabel, $phases.Count) -ForegroundColor Cyan

    $arguments = @{
        P1 = $P1; P2 = $P2; Stage = $Stage; Ai1 = 0; Ai2 = 0
        WarmupSec = $WarmupSec; Prefix = $prefix; OutDir = $OutDir
        ShowDebug = $true; NoBurst = $true; NoStillShots = $true
        SettleSec = $(if ($m.settle -eq 'tap') { $TapSettleSec } else { $SettleSec });
        Shots = 6; ShotIntervalSec = 0.12
        Phases = ($phases -join ',')
    }
    if ($m.map) { $arguments['ButtonMap'] = $m.map }
    $runLog = Join-Path $OutDir "${prefix}_run.txt"
    & pwsh -File $Harness @arguments *> $runLog

    $index.Add(("{0}`t{1}`t{2}" -f $m.name, $mapLabel, (($m.motion + @($m.button)) -join ' ')))
}
$index | Out-File -Encoding utf8 (Join-Path $OutDir 'moves_index.txt')
Write-Host "all requested moves done -> $OutDir"

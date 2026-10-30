#Requires -Version 5.1
<#
.SYNOPSIS
    Render fixed Archer art poses in the engine for checking axes, FX and palettes.
.DESCRIPTION
    Creates only a runtime fixture, archer_art_review. It holds three attack/roll
    poses and loops their cosmetic effects. This is a visual review, not a combat
    or input test. The tracked character and its timings are never modified.
#>
[CmdletBinding()]
param([int]$RunSec = 28, [string]$OutDir)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).ProviderPath
$source = Join-Path $repo 'game\chars\archer'
$fixture = Join-Path $repo 'engine\ikemen-go\chars\archer_art_review'
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $fixture -Recurse -Force
$definition = [IO.File]::ReadAllText((Join-Path $source 'archer.def'))
$definition = $definition.Replace('name         = "archer"', 'name         = "archer_art_review"')
$definition = $definition.Replace('"Archer (Emiya)"', '"Archer art review"')
$definition = $definition.Replace('pal.defaults = 1,2,3,4', 'pal.defaults = 2')
[IO.File]::WriteAllText((Join-Path $fixture 'archer_art_review.def'), $definition)
$states = [IO.File]::ReadAllText((Join-Path $source 'archer.zss'))
$states += @'

# Runtime-only visual review fixture. The original -3 is empty.
if roundState = 2 && stateNo < 9800 { changeState{value: 9800} }

'@
$poses = @(
    @{ State = 9800; Anim = 1300; Elem = 7; Effect = 7260; Next = 9801 },
    @{ State = 9801; Anim = 1400; Elem = 7; Effect = 7230; Next = 9802 },
    @{ State = 9802; Anim = 110; Elem = 4; Effect = 7270; Next = 9800 }
)
foreach ($pose in $poses) {
    $states += @"

[StateDef $($pose.State); type: S; movetype: I; physics: N; ctrl: 0; velset: 0,0; anim: $($pose.Anim);]
changeAnim{value: $($pose.Anim); elem: $($pose.Elem)}
if numExplod($($pose.Effect)) = 0 {
    explod{anim: $($pose.Effect); ID: $($pose.Effect); postype: p1; pos: 0,0;
        scale: 0.48,0.48; bindtime: -1; removetime: -2; ownpal: 1; sprpriority: 3;}
}
if time = 119 { changeState{value: $($pose.Next)} }

"@
}
[IO.File]::WriteAllText((Join-Path $fixture 'archer.zss'), $states)
if (-not $OutDir) { $OutDir = Join-Path $repo 'logs\p6\art-pass\review' }
& (Join-Path $repo 'tests\p3\run_match_watch.ps1') -P1 archer_art_review -P2 archer `
    -Ai1 0 -Ai2 0 -RunSec $RunSec -WarmupSec 12 -Shots 8 -Prefix art_review -OutDir $OutDir
exit $LASTEXITCODE

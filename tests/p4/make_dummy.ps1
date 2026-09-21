#Requires -Version 5.1
<#
.SYNOPSIS
    Materialises scripted training dummies into the engine runtime, for Gate 7.

.DESCRIPTION
    Gate 7 needs an opponent that guards, or jumps, *on demand*. The engine can
    be told to do exactly that from a character script:

        assertSpecial{flag: autoGuard}   <- engine-level forced guard
        assertInput{flag: U}             <- holds "up", i.e. keeps jumping

    (both copied from data/training.zss:82-83 and :204-209, which is how the
    built-in Training mode drives its own dummy). Put them in [StateDef -3] and
    they re-apply every single tick, so no human has to stand at the menu.

    These dummies are TEST FIXTURES, not characters. They are written only into
    engine/ikemen-go/chars/ (git-ignored inside the submodule) so game/chars/
    -- the tracked source of truth -- stays clean. Re-run this script any time
    after a fresh clone.

.PARAMETER Variant
    plain (no assert = control), guard, jump, or all (default).

.EXAMPLE
    pwsh -File tests/p4/make_dummy.ps1
    pwsh -File tests/p4/make_dummy.ps1 -Variant guard
#>
[CmdletBinding()]
param(
    [ValidateSet('plain', 'guard', 'jump', 'all')]
    [string]$Variant = 'all',
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot | Split-Path -Parent }
$src      = Join-Path $RepoRoot 'game\chars\_template'
$runtime  = Join-Path $RepoRoot 'engine\ikemen-go\chars'

if (-not (Test-Path -LiteralPath $src)) { throw "template not found: $src" }
if (-not (Test-Path -LiteralPath $runtime)) { throw "runtime chars dir not found: $runtime" }

# What each variant forces, every tick, from [StateDef -3].
$asserts = @{
    plain = @()
    guard = @('assertSpecial{flag: autoGuard}')
    jump  = @('assertInput{flag: U}')
}
if ($Variant -eq 'all') { $names = @('plain', 'guard', 'jump') } else { $names = @($Variant) }

foreach ($v in $names) {
    $name = 'test_dummy_' + $v
    $dst  = Join-Path $runtime $name

    if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
    New-Item -ItemType Directory -Path $dst -Force | Out-Null

    # copy the template, renaming every _template.* to <name>.*
    foreach ($f in Get-ChildItem -LiteralPath $src -File) {
        $target = $f.Name.Replace('_template', $name)
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $dst $target)
    }

    # .def: point at the renamed files and call the character by its new name
    $def = Join-Path $dst ($name + '.def')
    $txt = [System.IO.File]::ReadAllText($def)
    $txt = $txt.Replace('_template', $name).Replace('"KOF Template"', ('"Dummy: {0}"' -f $v))
    [System.IO.File]::WriteAllText($def, $txt, (New-Object System.Text.UTF8Encoding($false)))

    # .zss: fill the existing [StateDef -3] instead of appending a duplicate
    $zss  = Join-Path $dst ($name + '.zss')
    $ztxt = [System.IO.File]::ReadAllText($zss)
    $body = ($asserts[$v] | ForEach-Object { '    ' + $_ }) -join "`r`n"
    # NOTE: ZSS comments start with '#', NOT ';'. A ';' here makes the engine
    # abort with "Invalid data: ;" (seen in save/logs/Ikemen_*.log), which is
    # exactly the silent-looking failure this whole harness exists to catch.
    $block = "[StateDef -3]`r`n# auto-generated test dummy ('$v'); see tests/p4/make_dummy.ps1`r`n"
    if ($body) { $block += $body + "`r`n" } else { $block += "# no assert: this is the control dummy`r`n" }
    $ztxt2 = [regex]::Replace($ztxt, '\[StateDef -3\][ \t]*\r?\n', { param($m) $block })
    if ($ztxt2 -eq $ztxt) { throw "could not find [StateDef -3] in $zss" }
    [System.IO.File]::WriteAllText($zss, $ztxt2, (New-Object System.Text.UTF8Encoding($false)))

    Write-Host ("[dummy] {0,-18} -> {1}" -f $name, $dst)
    foreach ($a in $asserts[$v]) { Write-Host ("        {0}" -f $a) }
    if (-not $asserts[$v]) { Write-Host '        (no assert - control)' }
}

Write-Host ''
Write-Host 'dummies are runtime-only (git-ignored); re-run this script after a fresh clone.'
exit 0

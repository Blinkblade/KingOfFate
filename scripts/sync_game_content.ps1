#Requires -Version 5.1
<#
.SYNOPSIS
    Copies KingOfFate's own game content into the IKEMEN GO runtime tree.

.DESCRIPTION
    The engine only loads characters, stages, system data and fonts from its own
    runtime root (engine/ikemen-go). KingOfFate's source of truth for that content
    lives under game/. This script bridges the two: it copies game/<dir>/* into
    <RuntimeRoot>/<dir>/.

    It exists because the runtime tree is inside the engine submodule, where the
    runtime directories are git-ignored - content placed there is NOT tracked and
    must never be the only copy of anything. This script is therefore one-way:

        game/    (tracked, source of truth)  ->  engine/ikemen-go/  (runtime, ignored)

    Properties:
      * idempotent   - running it twice leaves the same result
      * path-free    - every path is derived from this script's location
      * offline      - never runs git pull / reset / checkout / clean / checkout
      * additive     - only overwrites files that exist in game/; never deletes
                       anything in the runtime tree (the engine's own bundled
                       assets stay untouched)

.PARAMETER RuntimeRoot
    Runtime directory that holds Ikemen_GO.exe. Defaults to engine/ikemen-go.

.PARAMETER ContentRoot
    Source directory that holds the project's own game content. Defaults to game/.

.PARAMETER WhatIf
    List what would be copied without copying anything.

.EXAMPLE
    pwsh -File scripts/sync_game_content.ps1
    pwsh -File scripts/sync_game_content.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$RuntimeRoot,
    [string]$ContentRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..')).ProviderPath

if ([string]::IsNullOrWhiteSpace($ContentRoot)) { $ContentRoot = Join-Path $RepoRoot 'game' }
if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) { $RuntimeRoot = Join-Path $RepoRoot 'engine\ikemen-go' }

$ContentRoot = (Resolve-Path -LiteralPath $ContentRoot).ProviderPath
$RuntimeRoot = (Resolve-Path -LiteralPath $RuntimeRoot).ProviderPath

Write-Host "[sync ] repo    : $RepoRoot"
Write-Host "[sync ] content : $ContentRoot"
Write-Host "[sync ] runtime : $RuntimeRoot"

# The engine reads these directories from its runtime root. Only the ones that
# actually exist in game/ are synced.
$contentDirs = @('chars', 'stages', 'data', 'font', 'sound', 'external')

$copied = 0
$skipped = 0

foreach ($dir in $contentDirs) {
    $srcDir = Join-Path $ContentRoot $dir
    if (-not (Test-Path -LiteralPath $srcDir)) { continue }

    $dstDir = Join-Path $RuntimeRoot $dir
    $items = @(Get-ChildItem -LiteralPath $srcDir -Force | Where-Object { $_.Name -ne '.gitkeep' })
    if ($items.Count -eq 0) { continue }

    Write-Host ("[sync ] {0}/ -> {1}" -f $dir, $dstDir)

    foreach ($item in $items) {
        $target = Join-Path $dstDir $item.Name
        if ($PSCmdlet.ShouldProcess($target, 'copy')) {
            New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
            if ($item.PSIsContainer) {
                # Merge directory *contents* into the target. Copying the directory
                # itself would nest it (dst/dir/dir) whenever the target exists.
                New-Item -ItemType Directory -Force -Path $target | Out-Null
                Copy-Item -Path (Join-Path $item.FullName '*') -Destination $target -Recurse -Force
                Write-Host ("         dir  {0}" -f $item.Name)
            }
            else {
                Copy-Item -LiteralPath $item.FullName -Destination $target -Force
                Write-Host ("         file {0}" -f $item.Name)
            }
            $copied++
        }
        else {
            $skipped++
        }
    }
}

Write-Host ''
$mode = if ($WhatIfPreference) { ' (-WhatIf: nothing was copied)' } else { '' }
Write-Host ("[sync ] done: {0} item(s) copied, {1} skipped{2}" -f $copied, $skipped, $mode)
Write-Host '[sync ] note : runtime content is git-ignored inside the engine submodule;'
Write-Host '               the tracked source of truth stays under game/.'
exit 0

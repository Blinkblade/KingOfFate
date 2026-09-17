#Requires -Version 5.1
<#
.SYNOPSIS
    Builds a single montage image of the engine's state readout from many screenshots.

.DESCRIPTION
    Reading hundreds of 1280x720 game screenshots one by one is impractical. All the
    P1 experiments need is the debug overlay's last line, which lives at a fixed place
    in every capture:

        y 706..721, x 0..520  ->  "State No: NNN (P1); CTRL: c; Type: T; MoveType: M; ..."

    This script crops exactly that strip out of each requested screenshot, scales it
    x2 for legibility, stacks the strips into one tall image and labels each strip
    with the source file name. The result is a single image that shows, at a glance,
    which state every captured frame was in.

.PARAMETER Image
    Screenshot paths, or wildcard patterns, to include.

.PARAMETER Steps
    For a series like <tag>_burstNN.png, which burst numbers to include.
    Accepts a comma-separated string, a plain number list or burst names --
    e.g.  -Steps '1,2,3'  /  -Steps 'burst02,burst04'  /  -Steps 6,12,20.
    Empty = include every step.

    Why a string and not [int[]] (P3 fix): `pwsh -File` cannot bind a comma list
    to an array parameter -- `-Steps 1,2,3` is parsed as the single number 123
    (the commas are read as digit-group separators), so the filter silently
    matched nothing and the script printed "nothing selected". This is the same
    class of problem P1 hit with -HoldSeqVK and P2 with -Phases, and it is fixed
    the same way: take a string, split it inside the script.

.PARAMETER OutFile
    Where to write the montage PNG.

.EXAMPLE
    pwsh -File tests/p1/montage_states.ps1 -Image 'logs/p1/shots/e5_probe1_seq*_burst*.png' -Steps '6,12,20'
#>
[CmdletBinding()]
param(
    [string[]]$Image = @(),
    [string]$Steps = '6,12,20',
    [string]$OutFile,
    [int]$CropX = 0,
    [int]$CropY = 706,
    [int]$CropW = 520,
    [int]$CropH = 16,
    [int]$Region2Y = -1,
    [int]$Region2H = 0,
    [int]$Scale = 2,
    [int]$LabelWidth = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# -Steps arrives as a comma/space separated string (see the parameter help for why
# it is not [int[]]). Accept plain numbers and 'burstNN' names.
$StepList = @()
foreach ($tok in ($Steps -split '[,;\s]+')) {
    $t = $tok.Trim()
    if ($t -eq '') { continue }
    if ($t -match '^burst(\d+)$') { $StepList += [int]$Matches[1]; continue }
    if ($t -match '^\d+$') { $StepList += [int]$t; continue }
    throw "step token '$t' must be a number or 'burstNN'"
}

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).ProviderPath
if ([string]::IsNullOrWhiteSpace($OutFile)) { $OutFile = Join-Path $RepoRoot 'logs\p1\shots\montage_states.png' }

# Resolve the requested images, honouring both literal paths and globs.
$selected = New-Object System.Collections.Generic.List[string]
foreach ($item in $Image) {
    $p = $item
    if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $RepoRoot $p }
    if (Test-Path -LiteralPath $p -PathType Leaf) { $selected.Add((Resolve-Path -LiteralPath $p).ProviderPath); continue }
    $hits = @(Get-ChildItem -Path $p -File -ErrorAction SilentlyContinue | Sort-Object Name)
    foreach ($h in $hits) { $selected.Add($h.FullName) }
}

# Keep only the requested burst steps, ordered by series then step.
$rows = New-Object System.Collections.Generic.List[object]
foreach ($f in $selected) {
    $m = [regex]::Match([System.IO.Path]::GetFileName($f), '^(.*)_(before|after|burst\d+|\d+)\.png$')
    if (-not $m.Success) { continue }
    $step = 0
    if ($m.Groups[2].Value -match '^burst(\d+)$') { $step = [int]$Matches[1] }
    elseif ($m.Groups[2].Value -match '^\d+$') { $step = [int]$m.Groups[2].Value }
    $stepName = $m.Groups[2].Value
    if ($StepList.Count -gt 0 -and ($StepList -notcontains $step)) { continue }
    $rows.Add([pscustomobject]@{ Series = $m.Groups[1].Value; Step = $step; StepName = $stepName; Path = $f })
}
$rows = @($rows | Sort-Object Series, Step)
if ($rows.Count -eq 0) { Write-Host '[warn] nothing selected'; exit 0 }

$cellW = [int]($CropW * $Scale)
$cellH = [int]($CropH * $Scale)
$cell2H = if ($Region2Y -ge 0 -and $Region2H -gt 0) { [int]($Region2H * $Scale) } else { 0 }
$rowH = $cellH + $cell2H + 8
$canvasW = $LabelWidth + $cellW + 16
$canvasH = 8 + $rows.Count * $rowH

$canvas = New-Object System.Drawing.Bitmap($canvasW, $canvasH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.Clear([System.Drawing.Color]::FromArgb(255, 16, 16, 16))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$font = New-Object System.Drawing.Font('Consolas', 11)
$brush = [System.Drawing.Brushes]::White
$yo = 8
foreach ($r in $rows) {
    $src = [System.Drawing.Bitmap]::FromFile($r.Path)
    try {
        # region 2 first (e.g. the life/status lines), then region 1 (the state line)
        if ($cell2H -gt 0) {
            $rect2 = New-Object System.Drawing.Rectangle $CropX, $Region2Y, ([Math]::Min($CropW, $src.Width - $CropX)), ([Math]::Min($Region2H, $src.Height - $Region2Y))
            $dest2 = New-Object System.Drawing.Rectangle $LabelWidth, $yo, $cellW, $cell2H
            $g.DrawImage($src, $dest2, $rect2, [System.Drawing.GraphicsUnit]::Pixel)
        }
        $rect = New-Object System.Drawing.Rectangle $CropX, $CropY, ([Math]::Min($CropW, $src.Width - $CropX)), ([Math]::Min($CropH, $src.Height - $CropY))
        $dest = New-Object System.Drawing.Rectangle $LabelWidth, ($yo + $cell2H), $cellW, $cellH
        $g.DrawImage($src, $dest, $rect, [System.Drawing.GraphicsUnit]::Pixel)
    }
    finally { $src.Dispose() }
    $label = '{0} #{1}' -f $r.Series, $r.StepName
    $g.DrawString($label, $font, $brush, 4, ($yo + 20))
    $yo += $rowH
}
$g.Dispose()
$canvas.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
$canvas.Dispose()
$font.Dispose()
Write-Host "montage: $OutFile ($($rows.Count) rows)"

#Requires -Version 5.1
<#
.SYNOPSIS
    Reads the engine's debug readout out of the P1 capture screenshots.

.DESCRIPTION
    capture_match.ps1 saves a burst of screenshots while a key is held. The engine's
    debug overlay (Ctrl+D) prints a fixed block of text in the lower-left corner,
    and its last line is the player state readout:

        State No: 0 (P1); CTRL: 1; Type: S; MoveType: I; Physics: S; Time: 1234

    In this project's screenshots (1280x720) the debug block occupies y 672..719 and
    its last line, the state readout, is y 708..719 starting at x 12. The game is
    rendered from x 168 onwards, so cropping x 0..160 keeps the "State No: NNN (P1"
    part of the line sitting on the plain black letterbox - no stage background is
    included, which matters because the stage artwork animates and would otherwise
    swamp the comparison. The trailing "Time:" counter ticks every frame, so the
    crop stops long before it.

    The script therefore answers, for every burst series, "in which frames was the
    character NOT idle" without a human having to look at hundreds of images.

.PARAMETER Dir
    Directory holding the screenshots.

.PARAMETER Pattern
    Wildcard selecting the burst files, e.g. 'e5_probe1_seq*'.

.PARAMETER CropWidth
    Width of the cropped readout region, in pixels, from the left edge.

.PARAMETER CropHeight
    Height of the cropped readout region, in pixels, from the bottom edge.

.PARAMETER Threshold
    Channel difference (0-255) above which a pixel counts as changed.

.PARAMETER MinChanged
    Minimum number of changed pixels for a frame to be reported as "not idle".

.EXAMPLE
    pwsh -File tests/p1/analyze_shots.ps1 -Pattern 'e5_probe1_seq*'
#>
[CmdletBinding()]
param(
    [string]$Dir,
    [string]$Pattern = '*_seq*_burst*.png',
    [int]$CropWidth = 160,
    [int]$CropHeight = 12,
    [int]$Threshold = 40,
    [int]$MinChanged = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).ProviderPath
if ([string]::IsNullOrWhiteSpace($Dir)) { $Dir = Join-Path $RepoRoot 'logs\p1\shots' }

# Load a bitmap and copy a bottom-left crop out as 32bpp ARGB bytes.
function Get-CropBytes([string]$path, [int]$w, [int]$h) {
    $src = [System.Drawing.Bitmap]::FromFile($path)
    try {
        $bmp = New-Object System.Drawing.Bitmap($src.Width, $src.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.DrawImage($src, 0, 0, $src.Width, $src.Height)
        $g.Dispose()
        $cw = [Math]::Min($w, $src.Width)
        $ch = [Math]::Min($h, $src.Height)
        $rect = New-Object System.Drawing.Rectangle 0, ($src.Height - $ch), $cw, $ch
        $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $len = [Math]::Abs($data.Stride) * $ch
        $buf = New-Object byte[] $len
        [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buf, 0, $len)
        $bmp.UnlockBits($data)
        $bmp.Dispose()
        return , @{ Bytes = $buf; Stride = $data.Stride; Height = $ch }
    }
    finally { $src.Dispose() }
}

function Compare-Bytes($a, $b, [int]$threshold) {
    $n = [Math]::Min($a.Bytes.Length, $b.Bytes.Length)
    $changed = 0
    for ($i = 0; $i -lt $n; $i += 4) {
        $d = [Math]::Abs([int]$a.Bytes[$i] - [int]$b.Bytes[$i])
        $d2 = [Math]::Abs([int]$a.Bytes[$i + 1] - [int]$b.Bytes[$i + 1])
        $d3 = [Math]::Abs([int]$a.Bytes[$i + 2] - [int]$b.Bytes[$i + 2])
        if ($d -gt $threshold -or $d2 -gt $threshold -or $d3 -gt $threshold) { $changed++ }
    }
    return $changed
}

# Group the shots by burst series: <tag>_before.png / <tag>_burstNN.png / <tag>_after.png
$files = @(Get-ChildItem -Path $Dir -Filter $Pattern -File -ErrorAction SilentlyContinue)
if ($files.Count -eq 0) {
    Write-Host "[warn] no files match '$Pattern' in $Dir"
    exit 0
}

$tags = @{}
foreach ($f in $files) {
    $m = [regex]::Match($f.Name, '^(.*)_(before|after|burst\d+)\.png$')
    if (-not $m.Success) { continue }
    $tag = $m.Groups[1].Value
    if (-not $tags.ContainsKey($tag)) { $tags[$tag] = @() }
    $tags[$tag] += $f
}

$summary = New-Object System.Collections.Generic.List[string]
foreach ($tag in ($tags.Keys | Sort-Object)) {
    $ref = $tags[$tag] | Where-Object { $_.Name -like '*_before.png' } | Select-Object -First 1
    if (-not $ref) { $ref = $tags[$tag] | Where-Object { $_.Name -like '*_burst01.png' } | Select-Object -First 1 }
    if (-not $ref) { continue }

    $refCrop = Get-CropBytes $ref.FullName $CropWidth $CropHeight
    $results = @()
    foreach ($f in ($tags[$tag] | Where-Object { $_.Name -like '*_burst*.png' } | Sort-Object Name)) {
        $c = Get-CropBytes $f.FullName $CropWidth $CropHeight
        $changed = Compare-Bytes $refCrop $c $Threshold
        $results += [pscustomobject]@{ Name = $f.Name; Changed = $changed }
    }

    $hot = @($results | Where-Object { $_.Changed -ge $MinChanged })
    $max = ($results | Measure-Object -Property Changed -Maximum).Maximum
    $first = if ($hot.Count -gt 0) { $hot[0].Name } else { '-' }
    $summary.Add(('{0,-40} frames={1,3}  max={2,5}  active={3,3}  first_active={4}' -f $tag, $results.Count, $max, $hot.Count, $first))

    # compact profile: index of every frame whose change is a clear state switch
    $strong = @($results | Where-Object { $_.Changed -ge [Math]::Max($MinChanged, 20) })
    if ($strong.Count -gt 0) {
        $idx = ($strong | ForEach-Object { [int]([regex]::Match($_.Name, 'burst(\d+)').Groups[1].Value) })
        $summary.Add(('    strong frames: {0}' -f (($idx | Sort-Object | Select-Object -First 24) -join ',')))
    }
}

$outPath = Join-Path $Dir 'analysis_report.txt'
$header = "analyze_shots: pattern=$Pattern crop=${CropWidth}x${CropHeight} threshold=$Threshold minChanged=$MinChanged"
$lines = @($header, ('generated: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')), '') + $summary
$lines | Out-File -Encoding utf8 $outPath
$lines | ForEach-Object { Write-Host $_ }
exit 0

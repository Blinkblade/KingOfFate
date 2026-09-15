#Requires -Version 5.1
<#
.SYNOPSIS
    Measures the on-screen horizontal position of each character from a screenshot,
    by locating the white text clusters of the character name tags.

.DESCRIPTION
    The IKEMEN debug overlay does NOT print world coordinates, and the "%d" right after
    "P1:" in the overlay is the character's *id()*, not its position (see debug.lua:183).
    So when an experiment needs "how far did the character move", the only source is
    the picture itself.

    Each character name tag is drawn horizontally centred under that character's feet,
    so the centre of the tag's white pixel cluster IS the character's on-screen x.
    This script band-scans a horizontal strip of the screenshot, finds the columns that
    contain near-white pixels, groups them into clusters, and reports each cluster's
    left edge, right edge, width and centre.

    Typical use: run it over the "before" frame and a few burst frames of a baseline run
    and of a modified run, then compare how far the left-most cluster (P1) travelled.

    NOTE: when two characters stand very close together their name tags overlap and merge
    into a single wide cluster. Those frames cannot be used for a per-character reading —
    watch the reported width; a merged cluster shows up as roughly double the usual width.

    A useful companion trick is to launch the match with the opponent disabled
    (-Ai2 0) so that P2 stands perfectly still: its constant reading then serves as a
    built-in reference for the pixel scale and for camera movement.

.PARAMETER Files
    Comma-separated screenshot file names, relative to logs/p1/shots.
    Use the capture_match.ps1 -Prefix value to find them.

.PARAMETER BandY
    First image row of the strip to scan. The name tag band is around y=604..619 at
    1280x720 (find it with a row scan if the resolution differs).

.PARAMETER BandH
    Height of the strip to scan.

.PARAMETER XMin / XMax
    Horizontal window to search. Narrowing it avoids picking up unrelated white UI text.

.PARAMETER Gap
    A run of white-free columns longer than this starts a new cluster.

.PARAMETER MinWidth
    Clusters narrower than this are treated as specks and dropped.

.PARAMETER OutFile
    Where to write the report. The report is worth committing alongside the screenshots
    as the numeric half of the evidence.

.EXAMPLE
    pwsh -File tests/p1/measure_positions.ps1 `
        -Files 'e1_base_seq01_walkFwd_before.png,e1_base_seq01_walkFwd_burst02.png' `
        -XMin 300 -XMax 1200 -OutFile docs/evidence/p1/e1_ab_measure.txt
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Files,
    [int]$BandY = 604,
    [int]$BandH = 16,
    [int]$XMin = 0,
    [int]$XMax = 1280,
    [int]$Gap = 24,
    [int]$MinWidth = 8,
    [string]$ShotsDir,
    [Parameter(Mandatory = $true)][string]$OutFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).ProviderPath
if ([string]::IsNullOrWhiteSpace($ShotsDir)) { $ShotsDir = Join-Path $RepoRoot 'logs\p1\shots' }

$list = @($Files -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
if ($list.Count -eq 0) { throw 'no files given' }

Write-Host "[measure] shots : $ShotsDir"
Write-Host "[measure] band  : y $BandY..$($BandY + $BandH - 1), x $XMin..$XMax"
Write-Host "[measure] files : $($list.Count)"

$out = New-Object System.Collections.ArrayList
[void]$out.Add("# measure_positions.ps1 - on-screen character positions from name tags")
[void]$out.Add("# band y $BandY..$($BandY + $BandH - 1); search x $XMin..$XMax; cluster gap $Gap; min width $MinWidth")
[void]$out.Add("# columns found are reported as [left..right centre=<px> width=<px>], left to right")
[void]$out.Add('')

foreach ($f in $list) {
    $src = Join-Path $ShotsDir $f
    if (-not (Test-Path -LiteralPath $src)) {
        [void]$out.Add(("{0,-46} MISSING" -f $f))
        Write-Host "[measure] MISSING $f"
        continue
    }

    $bmp = New-Object System.Drawing.Bitmap $src
    $rect = New-Object System.Drawing.Rectangle $XMin, $BandY, ($XMax - $XMin), $BandH
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
                          [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $bytes = New-Object byte[] ($stride * $BandH)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $bmp.UnlockBits($data)
    $bmp.Dispose()

    # count near-white pixels per column
    $cols = New-Object int[] ($XMax - $XMin)
    for ($y = 0; $y -lt $BandH; $y++) {
        $base = $y * $stride
        for ($x = 0; $x -lt ($XMax - $XMin); $x++) {
            $i = $base + $x * 4
            if ($bytes[$i] -gt 190 -and $bytes[$i + 1] -gt 190 -and $bytes[$i + 2] -gt 190) { $cols[$x]++ }
        }
    }

    # group runs of non-empty columns into clusters
    $lefts = New-Object System.Collections.ArrayList
    $rights = New-Object System.Collections.ArrayList
    $start = -1; $prev = -100
    for ($x = 0; $x -lt $cols.Length; $x++) {
        if ($cols[$x] -gt 0) {
            if ($start -lt 0) { $start = $x }
            elseif ($x - $prev -gt $Gap) {
                [void]$lefts.Add($start + $XMin); [void]$rights.Add($prev + $XMin)
                $start = $x
            }
            $prev = $x
        }
    }
    if ($start -ge 0) { [void]$lefts.Add($start + $XMin); [void]$rights.Add($prev + $XMin) }

    $parts = New-Object System.Collections.ArrayList
    for ($k = 0; $k -lt $lefts.Count; $k++) {
        $l = $lefts[$k]; $r = $rights[$k]
        if (($r - $l) -lt $MinWidth) { continue }
        $c = [math]::Round(($l + $r) / 2.0)
        [void]$parts.Add(("[{0}..{1} centre={2} width={3}]" -f $l, $r, $c, ($r - $l)))
    }

    [void]$out.Add(("{0,-46} {1}" -f $f, ($parts -join ' ')))
    Write-Host ("[measure] {0,-46} {1}" -f $f, ($parts -join ' '))
}

$dir = Split-Path -Parent $OutFile
if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}
Set-Content -LiteralPath $OutFile -Value ($out -join "`r`n") -Encoding UTF8
Write-Host "[measure] written: $OutFile"
exit 0

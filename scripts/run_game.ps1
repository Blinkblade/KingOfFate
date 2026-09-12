#Requires -Version 5.1
<#
.SYNOPSIS
    Launches the built KingOfFate runtime (IKEMEN GO engine).

.DESCRIPTION
    Locates the project root from its own path, finds the built executable, checks
    that the runtime assets are present, and starts the game.

    It deliberately NEVER builds anything. If the executable is missing it tells you
    to run scripts/build_engine.ps1 first.

.PARAMETER RuntimeRoot
    Directory that holds Ikemen_GO.exe together with data/, font/, external/,
    chars/ and stages/. Defaults to engine/ikemen-go.

.PARAMETER Msys2Root
    MSYS2 installation root, used to locate the MinGW64 runtime DLLs
    (SDL2/libxmp/FFmpeg...). Only needed when those DLLs are not bundled next to
    the executable. Defaults to -Msys2Root > $env:MSYS2_ROOT > $env:MSYS2_HOME >
    the usual install locations; nothing is hardcoded.

.PARAMETER Wait
    Wait for the game process to exit before returning.

.PARAMETER ExtraArgs
    Extra command line arguments passed through to the engine,
    e.g. -ExtraArgs '-p1','kfm','-p2','kfm','--rounds','1','--windowed'

.PARAMETER CheckOnly
    Run every preflight check but do not launch the game.

.EXAMPLE
    pwsh -File scripts/run_game.ps1
    pwsh -File scripts/run_game.ps1 -Wait
    pwsh -File scripts/run_game.ps1 -CheckOnly
    pwsh -File scripts/run_game.ps1 -ExtraArgs '-p1','kfm','-p2','kfm','-s','stage0','--rounds','1','--windowed'
#>
[CmdletBinding()]
param(
    [string]$RuntimeRoot,
    [string]$Msys2Root,
    [switch]$Wait,
    [string[]]$ExtraArgs,
    [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..')).ProviderPath

if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) {
    $RuntimeRoot = Join-Path $RepoRoot 'engine\ikemen-go'
}
$RuntimeRoot = (Resolve-Path -LiteralPath $RuntimeRoot).ProviderPath

$Executable = Join-Path $RuntimeRoot 'Ikemen_GO.exe'

function Write-Step([string]$Text) { Write-Host "[ run ] $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text) { Write-Host "[ ok  ] $Text" -ForegroundColor Green }
function Write-Err([string]$Text) { Write-Host "[fail] $Text" -ForegroundColor Red }

Write-Step "Project root : $RepoRoot"
Write-Step "Runtime root : $RuntimeRoot"

# ---------------------------------------------------------------------------
# Executable
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $Executable)) {
    Write-Err "executable not found: $Executable"
    Write-Host ''
    Write-Host '       Build the engine first:' -ForegroundColor Yellow
    Write-Host '           pwsh -File scripts/build_engine.ps1' -ForegroundColor Yellow
    Write-Host ''
    exit 2
}
$exe = Get-Item -LiteralPath $Executable
Write-Ok ("executable   : {0}  ({1:N2} MB, {2})" -f $exe.Name, ($exe.Length / 1MB), $exe.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))

# ---------------------------------------------------------------------------
# Runtime assets
# ---------------------------------------------------------------------------
$requiredDirs = @('data', 'font', 'external', 'chars', 'stages')
$requiredFiles = @(
    'data\ikemen1\system.def',   # default motif (screenpack)
    'data\fight.def',            # fight screen
    'chars\kfm\kfm.def',         # a playable character
    'stages\stage0.def'          # a playable stage
)

$missing = New-Object System.Collections.Generic.List[string]
foreach ($d in $requiredDirs) {
    if (-not (Test-Path -LiteralPath (Join-Path $RuntimeRoot $d))) { $missing.Add("$d\ (directory)") }
}
foreach ($f in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $RuntimeRoot $f))) { $missing.Add($f) }
}

if ($missing.Count -gt 0) {
    Write-Err 'runtime assets are incomplete:'
    $missing | ForEach-Object { Write-Host "         - $_" -ForegroundColor Yellow }
    Write-Host ''
    Write-Host '       Unpack the official engine screenpack next to the executable,' -ForegroundColor Yellow
    Write-Host '       or point -RuntimeRoot at a directory that already has them.' -ForegroundColor Yellow
    Write-Host '       See docs/environment.md for how this environment was prepared.' -ForegroundColor Yellow
    Write-Host ''
    exit 3
}

Write-Ok 'runtime assets: data/ font/ external/ chars/ stages/ all present'
Write-Host '         motif   : data/ikemen1/system.def'
Write-Host '         char    : chars/kfm/kfm.def'
Write-Host '         stage   : stages/stage0.def'
Write-Host ''

# ---------------------------------------------------------------------------
# Runtime DLL search path
# ---------------------------------------------------------------------------
# When the engine is linked against the system FFmpeg (BUILD_FFMPEG=no) the engine
# build script does not bundle the runtime DLLs, so the executable resolves them
# from the MSYS2 mingw64 prefix. Prepend that directory to the PATH of the game
# process. If the DLLs are ever bundled next to the executable this is skipped.
function Resolve-Msys2MingwBin {
    $candidates = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($Msys2Root)) { $candidates.Add($Msys2Root) }
    foreach ($n in 'MSYS2_ROOT', 'MSYS2_HOME') {
        $v = [System.Environment]::GetEnvironmentVariable($n)
        if (-not [string]::IsNullOrWhiteSpace($v)) { $candidates.Add($v) }
    }
    $candidates.Add('C:\msys64')
    $candidates.Add('D:\msys64')
    foreach ($c in $candidates) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        $p = Join-Path $c 'mingw64\bin'
        if (Test-Path -LiteralPath (Join-Path $p 'SDL2.dll')) { return $p }
    }
    return $null
}

if (-not (Test-Path -LiteralPath (Join-Path $RuntimeRoot 'SDL2.dll'))) {
    $mingwBin = Resolve-Msys2MingwBin
    if ($mingwBin) {
        $env:PATH = "$mingwBin;$env:PATH"
        Write-Ok "DLL path     : $mingwBin  (prepended to the game process PATH)"
    }
    else {
        Write-Host '[warn ] DLL path     : no bundled DLLs next to the exe and no MSYS2 mingw64/bin found' -ForegroundColor Yellow
        Write-Host '       the game may fail to start with a missing-DLL error.' -ForegroundColor Yellow
        Write-Host '       Build with BUILD_FFMPEG=auto, or pass -Msys2Root <path>.' -ForegroundColor Yellow
    }
}
else {
    Write-Ok 'DLL path     : runtime DLLs are bundled next to the executable'
}
Write-Host ''

if ($CheckOnly) {
    Write-Ok 'preflight checks PASS (game not launched, -CheckOnly)'
    exit 0
}

# ---------------------------------------------------------------------------
# Launch
# ---------------------------------------------------------------------------
$argList = @()
if ($ExtraArgs) { $argList += $ExtraArgs }

Write-Step 'launching the game...'
if ($argList.Count -gt 0) {
    Write-Host ("         arguments: " + ($argList -join ' '))
}

$startArgs = @{
    FilePath         = $Executable
    WorkingDirectory = $RuntimeRoot
}
if ($argList.Count -gt 0) { $startArgs.ArgumentList = $argList }
if ($Wait) { $startArgs.Wait = $true; $startArgs.PassThru = $true }

$proc = Start-Process @startArgs

if ($Wait) {
    $code = $proc.ExitCode
    Write-Host ''
    if ($code -eq 0) {
        Write-Ok "game exited normally (exit code 0)"
        exit 0
    }
    Write-Err "game exited with code $code"
    exit 1
}

Write-Ok "game started (PID $($proc.Id))"
Write-Host ''
Write-Host '  The window runs independently of this shell.' -ForegroundColor DarkGray
Write-Host ''
exit 0

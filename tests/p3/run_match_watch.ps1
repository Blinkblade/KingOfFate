#Requires -Version 5.1
<#
.SYNOPSIS
    Runs one IKEMEN GO match unattended, screenshots it periodically, and reports
    any engine crash log the run produced.

.DESCRIPTION
    Why this exists (P3):
      * tests/p1/capture_match.ps1 and tests/p2/inject_phases.ps1 cover *input* and
        *screenshots*. They do not answer "did the engine itself complain?".
      * The engine is built as a Windows GUI-subsystem binary - its stdout is not
        writable, so Start-Process -RedirectStandardOutput yields an EMPTY file
        (verified in P3: 25 s run, 0 lines). Console capture is therefore impossible.
      * What the engine DOES leave behind on a fatal error (ZSS parse error, panic)
        is a crash log at  engine/ikemen-go/save/logs/Ikemen_<timestamp>.log
        plus a popup window (src/main.go:381-401).
      * Non-fatal warnings such as `changed to invalid state NNN` are printed to the
        in-game console and are visible in screenshots.

    So the reliable unattended check is: run the match, watch for NEW crash logs,
    and keep the screenshots (the frames carry the in-game console + debug readout).

    Differences from capture_match.ps1: no key injection at all, plain AI-vs-AI (or
    AI-vs-idle) runs, longer durations, crash-log diffing, lighter screenshots.

.PARAMETER Ai1 / Ai2
    AI level 1-8. 0 omits the -p1.ai / -p2.ai flag (engine default = no AI).

.PARAMETER RunSec
    Total run time. Screenshots are taken evenly across the run.

.PARAMETER Shots
    How many screenshots to take (default 6).

.PARAMETER ShowDebug / ShowClsn
    Send Ctrl+D (state readout) / Ctrl+C (collision boxes) after launch, using the
    same focus + verify-retry logic as capture_match.ps1.

.EXAMPLE
    pwsh -File tests/p3/run_match_watch.ps1 -P1 test_fighter_a -P2 kfm_zss `
        -Ai1 8 -Ai2 8 -RunSec 60 -ShowDebug -Prefix p3_ai_vs_ai
#>
[CmdletBinding()]
param(
    [string]$P1 = 'test_fighter_a',
    [string]$P2 = 'kfm_zss',
    [string]$Stage = 'stage0',
    [int]$RoundTime = 60,
    [int]$Ai1 = 8,
    [int]$Ai2 = 8,
    [int]$RunSec = 60,
    [int]$WarmupSec = 14,
    [int]$Shots = 6,
    [string]$Prefix = 'watch',
    [string]$OutDir,
    [switch]$ShowClsn,
    [switch]$ShowDebug,
    [string[]]$ExtraArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).ProviderPath
$RuntimeRoot = Join-Path $RepoRoot 'engine\ikemen-go'
$Exe = Join-Path $RuntimeRoot 'Ikemen_GO.exe'
$CrashLogDir = Join-Path $RuntimeRoot 'save\logs'

if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $RepoRoot 'logs\p3\shots' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if (-not (Test-Path -LiteralPath $Exe)) {
    Write-Host "[fail] executable not found: $Exe" -ForegroundColor Red
    exit 2
}

# ---------------------------------------------------------------------------
# Runtime DLL search path (same discovery order as scripts/run_game.ps1)
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath (Join-Path $RuntimeRoot 'SDL2.dll'))) {
    $found = $null
    foreach ($c in @($env:MSYS2_ROOT, $env:MSYS2_HOME, 'C:\msys64', 'D:\msys64')) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        $p = Join-Path $c 'mingw64\bin'
        if (Test-Path -LiteralPath (Join-Path $p 'SDL2.dll')) { $found = $p; break }
    }
    if ($found) { $env:PATH = "$found;$env:PATH"; Write-Host "[ info] DLL path: $found" }
    else { Write-Host '[warn ] no MSYS2 mingw64/bin found - the game may fail to start' -ForegroundColor Yellow }
}

# ---------------------------------------------------------------------------
# Win32 helpers (focus + PrintWindow; identical approach to tests/p1)
# ---------------------------------------------------------------------------
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace P3Watch -Name Win -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
[DllImport("user32.dll")] public static extern uint MapVirtualKey(uint uCode, uint uMapType);
[DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
[DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr lpdwProcessId);
[DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
'@

$KEYEVENTF_KEYUP = 0x0002
$VK_CONTROL = 0x11
$VK_MENU = 0x12

# Bring the game window to the foreground, with retries.
#
# Why the retries and the ALT press (P4 finding):
#   `SetForegroundWindow` is refused when the calling process does not satisfy any of
#   the foreground rules -- in practice on this machine it is *intermittently* refused
#   because the session has no recent physical keyboard activity
#   (`HKCU:\Control Panel\Desktop\ForegroundLockTimeout = 200000`).
#   P4 hit this on the very first Gate-2 run: the report said
#       focus: foreground acquired=False
#   and every screenshot then carried NO state readout, i.e. the run was silently
#   worthless. A back-to-back rerun succeeded on the first try, so it is a race, not
#   a hard failure -- exactly the kind of flakiness that must not be left in.
#   Pressing and releasing ALT makes the OS count it as fresh user input, which is the
#   documented way to release the foreground lock; combined with AttachThreadInput and
#   3 attempts the acquisition became reliable (verified over repeated runs).
function Focus-Window([IntPtr]$hwnd) {
    if ($hwnd -eq [IntPtr]::Zero) { return $false }
    $target = [P3Watch.Win]::GetWindowThreadProcessId($hwnd, [IntPtr]::Zero)
    $mine = [P3Watch.Win]::GetCurrentThreadId()
    $scan = [byte][P3Watch.Win]::MapVirtualKey([byte]$VK_MENU, 0)
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        [void][P3Watch.Win]::ShowWindow($hwnd, 9)          # SW_RESTORE
        $attached = $false
        if ($target -ne 0 -and $target -ne $mine) {
            [void][P3Watch.Win]::AttachThreadInput($mine, $target, $true)
            $attached = $true
        }
        [P3Watch.Win]::keybd_event([byte]$VK_MENU, $scan, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 60
        [void][P3Watch.Win]::SetForegroundWindow($hwnd)
        Start-Sleep -Milliseconds 60
        [P3Watch.Win]::keybd_event([byte]$VK_MENU, $scan, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
        if ($attached) {
            [void][P3Watch.Win]::AttachThreadInput($mine, $target, $false)
        }
        Start-Sleep -Milliseconds 250
        if ([P3Watch.Win]::GetForegroundWindow() -eq $hwnd) { return $true }
    }
    return $false
}

function Send-CtrlKey([int]$vk) {
    $scan = [byte][P3Watch.Win]::MapVirtualKey([byte]$VK_CONTROL, 0)
    [P3Watch.Win]::keybd_event([byte]$VK_CONTROL, $scan, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    $scan2 = [byte][P3Watch.Win]::MapVirtualKey([byte]$vk, 0)
    [P3Watch.Win]::keybd_event([byte]$vk, $scan2, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [P3Watch.Win]::keybd_event([byte]$vk, $scan2, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [P3Watch.Win]::keybd_event([byte]$VK_CONTROL, $scan, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
}

function Save-Shot([IntPtr]$hwnd, [string]$path) {
    $r = New-Object P3Watch.Win+RECT
    [void][P3Watch.Win]::GetClientRect($hwnd, [ref]$r)
    $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
    if ($w -le 0 -or $h -le 0) { return $false }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    $ok = [P3Watch.Win]::PrintWindow($hwnd, $hdc, 2)
    $g.ReleaseHdc($hdc); $g.Dispose()
    if ($ok) { $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png) }
    $bmp.Dispose()
    return $ok
}

# The debug overlay is drawn as near-white text over the bottom-left corner of the
# client area. Sending Ctrl+D is NOT enough: the toggle is occasionally missed and
# the screenshots then look plausible but carry no state readout at all (P3 hit this
# on its first AI run). Check the result instead of assuming it, exactly like
# tests/p1/capture_match.ps1 and tests/p2/inject_phases.ps1 do.
function Test-DebugOverlay([IntPtr]$hwnd) {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) 'p3_overlay_probe.png'
    if (-not (Save-Shot $hwnd $tmp)) { return $false }
    $bmp = [System.Drawing.Bitmap]::FromFile($tmp)
    try {
        $w = $bmp.Width; $h = $bmp.Height
        $n = 0
        for ($y = [Math]::Max(0, $h - 60); $y -lt $h; $y += 2) {
            for ($x = 0; $x -lt [Math]::Min(520, $w); $x += 2) {
                $p = $bmp.GetPixel($x, $y)
                $mx = [Math]::Max($p.R, [Math]::Max($p.G, $p.B))
                $mn = [Math]::Min($p.R, [Math]::Min($p.G, $p.B))
                if ($mn -gt 170 -and ($mx - $mn) -lt 60) { $n++ }
            }
        }
        return ($n -ge 50)
    }
    finally {
        $bmp.Dispose()
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Launch
# ---------------------------------------------------------------------------
$argList = @(
    '-p1', $P1, '-p2', $P2, '-s', $Stage,
    '-windowed', '-nosound', '-time', "$RoundTime"
)
if ($Ai1 -gt 0) { $argList += @('-p1.ai', "$Ai1") }
if ($Ai2 -gt 0) { $argList += @('-p2.ai', "$Ai2") }
if ($ExtraArgs) { $argList += $ExtraArgs }

$report = New-Object System.Collections.Generic.List[string]
$report.Add("harness   : tests/p3/run_match_watch.ps1")
$report.Add("args      : " + ($argList -join ' '))
$report.Add("outdir    : $OutDir")

# Crash-log baseline: anything that appears after this timestamp is from this run.
$before = @()
if (Test-Path -LiteralPath $CrashLogDir) {
    $before = @(Get-ChildItem -LiteralPath $CrashLogDir -Filter 'Ikemen_*.log' -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Name)
}
$startTime = Get-Date
$report.Add("crashlogs : $($before.Count) existing before the run")

$proc = Start-Process -FilePath $Exe -WorkingDirectory $RuntimeRoot -ArgumentList $argList -PassThru
$report.Add("process   : pid=$($proc.Id)")
Write-Host "[p3   ] pid=$($proc.Id)  args=$($argList -join ' ')"

Start-Sleep -Seconds $WarmupSec
if ($proc.HasExited) {
    $report.Add("early exit: exitcode=$($proc.ExitCode)  (0xC0000135 = a runtime DLL was not found)")
    $report | Out-File -Encoding utf8 (Join-Path $OutDir "${Prefix}_report.txt")
    Get-Content (Join-Path $OutDir "${Prefix}_report.txt")
    exit 1
}

$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 24; $i++) {
    $p = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if ($p -and $p.MainWindowHandle -ne 0) { $hwnd = $p.MainWindowHandle; break }
    Start-Sleep -Milliseconds 500
}
$report.Add("window    : hwnd=$hwnd")
if ($hwnd -eq [IntPtr]::Zero) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    $report.Add('window    : NO WINDOW HANDLE')
    $report | Out-File -Encoding utf8 (Join-Path $OutDir "${Prefix}_report.txt")
    exit 2
}

$report.Add("focus     : foreground acquired=$(Focus-Window $hwnd)")

if ($ShowClsn) { Send-CtrlKey 0x43 }   # Ctrl+C
if ($ShowDebug) {
    # Ctrl+D is a TOGGLE, and Test-DebugOverlay is slow (a PrintWindow plus a
    # pixel scan), so the P3 loop -- "press, wait 350 ms, check" x3 -- could end up
    # pressing an even number of times and leaving the overlay OFF, or checking
    # before the overlay had rendered. P4 hit exactly that: two consecutive runs
    # with `focus: foreground acquired=True` but
    # `debug: WARNING - debug overlay could not be enabled` and therefore zero
    # state readout in every screenshot.
    # Fixed by checking FIRST (never press when it is already on) and giving the
    # engine time to render between attempts.
    $on = $false
    for ($i = 1; $i -le 4; $i++) {
        if (Test-DebugOverlay $hwnd) { $on = $true; $report.Add("debug     : overlay already ON (check $i)"); break }
        Send-CtrlKey 0x44              # Ctrl+D (toggle)
        Start-Sleep -Milliseconds 800
        if (Test-DebugOverlay $hwnd) { $on = $true; $report.Add("debug     : overlay ON (attempt $i)"); break }
        $report.Add("debug     : overlay not detected (attempt $i)")
    }
    if (-not $on) {
        $report.Add('debug     : WARNING - debug overlay could not be enabled; the screenshots carry no state readout')
        Write-Host '[p3   ] WARNING: debug overlay could not be enabled' -ForegroundColor Yellow
    }
}

# Already burned WarmupSec; spread the shots over what is left.
$remain = [Math]::Max(4, $RunSec - $WarmupSec)
$interval = [Math]::Max(1, [int][Math]::Floor($remain / [Math]::Max(1, $Shots)))

for ($i = 1; $i -le $Shots; $i++) {
    if ($proc.HasExited) { break }
    $file = Join-Path $OutDir ("{0}_{1:d2}.png" -f $Prefix, $i)
    $ok = Save-Shot $hwnd $file
    $report.Add(("shot      : {0} ok={1} -> {2}" -f $i, $ok, $file))
    if ($i -lt $Shots) { Start-Sleep -Seconds $interval }
}

if (-not $proc.HasExited) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
    $report.Add("stop      : process killed by harness")
}

# ---------------------------------------------------------------------------
# Crash logs created during this run
# ---------------------------------------------------------------------------
$new = @()
if (Test-Path -LiteralPath $CrashLogDir) {
    $new = @(Get-ChildItem -LiteralPath $CrashLogDir -Filter 'Ikemen_*.log' -ErrorAction SilentlyContinue |
        Where-Object { $before -notcontains $_.Name } |
        Sort-Object LastWriteTime)
}
$report.Add("crashlogs : $($new.Count) new during the run")
foreach ($f in $new) {
    $report.Add("            $($f.Name)  ($($f.LastWriteTime))")
    $err = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue |
        Where-Object { $_ -match '^Error:' } | Select-Object -First 1
    if ($err) { $report.Add("            -> $err") }
}

$report | Out-File -Encoding utf8 (Join-Path $OutDir "${Prefix}_report.txt")

Write-Host "[p3   ] report: $(Join-Path $OutDir "${Prefix}_report.txt")"
if ($new.Count -eq 0) { Write-Host '[p3   ] no engine crash log was produced' -ForegroundColor Green }
else { Write-Host "[p3   ] $($new.Count) engine crash log(s) - inspect the report" -ForegroundColor Red }
exit 0

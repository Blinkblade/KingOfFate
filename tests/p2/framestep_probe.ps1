#Requires -Version 5.1
<#
.SYNOPSIS
    P2/P4 harness: pause the match and advance it ONE TICK at a time, taking a
    screenshot after every tick.

.DESCRIPTION
    Why this exists
    ---------------
    Several P4 gates need evidence about *timing* (when exactly does state 200
    turn into state 1000?) rather than just "the state changed". Wall-clock
    injection cannot answer that: Save-Shot -> PrintWindow blocks this OpenGL
    window's render thread, so the engine slows to roughly 10% while frames are
    being captured and every wall-clock assumption collapses.

    IKEMEN's own debug script (engine/ikemen-go/external/script/debug.lua,
    engine-side, NOT modified by us) binds three hotkeys that remove time from
    the equation entirely:

        PAUSE        -> togglePause()            sys.paused = !sys.paused
        SCROLLLOCK   -> frameStep()              sys.frameStepFlag = true
        Ctrl+S       -> changeSpeed()            cycle accel 1 -> 2 -> 4 -> 0.25

    With sys.paused = true the fight loop skips every update unless
    frameStepFlag is set (src/fightscreen.go:3430), so one SCROLLLOCK = exactly
    one game tick, no matter how long the screenshot takes. Combined with the
    debug overlay - which prints
        "State No: %d (P%d); CTRL: %s; Type: %s; MoveType: %s; Physics: %s; Time: %d"
    and
        "ActionID: %d (P%d); SPR: %d,%d; ElemNo: %d/%d; Time: %d/%d (%d/%d)"
    this gives a per-tick, readable state trace.

    Input during a step
    -------------------
    Keys are held across one or more steps and released afterwards, so a motion
    input (QCF etc.) can be entered one tick at a time. The command buffer is
    tick-based, so pausing never decays it.

.PARAMETER Steps
    ONE comma-separated string of "keys:ticks" tokens. Keys are virtual-key
    codes, decimal or 0x-hex, '+'-separated. "none" (or "-") means no keys.
    Example: '0x28:1','0x28+0x27:1','0x27:1','0x27+0x09:1','none:12'

.PARAMETER ApproachSec
    Hold Right (0x27) this long, in real time, BEFORE pausing, so the two
    characters are in range. 0 = start stepping where they stand.

.PARAMETER SlowSteps
    Number of Ctrl+S presses before pausing (0 = keep normal speed).
    changeSpeed() cycles 1 -> 2 -> 4 -> 0.25, so 3 presses = quarter speed.
    Only useful together with -NoPause.

.PARAMETER PauseAfterApproach
    Default on: pause the match before stepping. Disable with -NoPause to run
    the steps in real time (slow motion recommended then).

.EXAMPLE
    # walk into range, pause, then tap A and watch state 200 unfold tick by tick
    pwsh -File tests/p2/framestep_probe.ps1 -P1 test_fighter_b -P2 test_fighter_a `
        -ApproachSec 2.2 -ShowDebug -ShowClsn -Prefix fs_a `
        -Steps '0x09:2','none:24'
#>
[CmdletBinding()]
param(
    [string]$P1 = 'test_fighter_b',
    [string]$P2 = 'test_fighter_a',
    [string]$Stage = 'stage0',
    [int]$RoundTime = 60,
    [int]$Ai1 = 0,
    [int]$Ai2 = 0,
    [int]$WarmupSec = 14,
    [double]$ApproachSec = 0,
    [int]$SlowSteps = 0,
    [string]$Steps = 'none:8',
    [string]$Prefix = 'fs',
    [string]$OutDir,
    [switch]$ShowClsn,
    [switch]$ShowDebug,
    [switch]$NoPause,
    [int]$TickWaitMs = 220,
    [int]$TrailingShots = 0,
    [int]$TimeoutSec = 240
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -Steps arrives as ONE comma-separated string: pwsh -File cannot bind an array
# parameter from a comma list (same constraint as -Phases in inject_phases.ps1).
$StepList = @()
foreach ($tok in ($Steps -split '[,;\s]+')) {
    $t = $tok.Trim()
    if ($t -eq '') { continue }
    $kv = $t -split ':', 2
    if ($kv.Count -ne 2) { throw "step token '$t' must be 'keys:ticks'" }
    $keys = @()
    $raw = $kv[0].Trim()
    if ($raw -ne '' -and $raw -ne 'none' -and $raw -ne '-') {
        foreach ($k in ($raw -split '\+')) {
            $k = $k.Trim()
            if ($k -eq '') { continue }
            if ($k -match '^0[xX]') { $keys += [Convert]::ToInt32($k.Substring(2), 16) }
            else { $keys += [int]$k }
        }
    }
    $StepList += , @{ keys = $keys; ticks = [int]$kv[1] }
}

$ScriptDir = $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).ProviderPath
$RuntimeRoot = Join-Path $RepoRoot 'engine\ikemen-go'
$Exe = Join-Path $RuntimeRoot 'Ikemen_GO.exe'

if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $RepoRoot 'logs\p2\shots' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if (-not (Test-Path -LiteralPath $Exe)) {
    Write-Host "[fail] executable not found: $Exe" -ForegroundColor Red
    Write-Host '       build it first: pwsh -File scripts/build_engine.ps1' -ForegroundColor Yellow
    exit 2
}

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
# Win32 core (own namespace so it can coexist with the other harnesses)
# ---------------------------------------------------------------------------
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace FsLab -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
[DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
[DllImport("user32.dll")] public static extern uint MapVirtualKey(uint uCode, uint uMapType);
[DllImport("user32.dll")] public static extern IntPtr GetWindowThreadProcessId(IntPtr hWnd, IntPtr lpdwProcessId);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
[DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
[DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
'@

function Focus-Window([IntPtr]$hwnd) {
    for ($i = 0; $i -lt 6; $i++) {
        if ([FsLab.Win]::GetForegroundWindow() -eq $hwnd) { return $true }
        $target = [FsLab.Win]::GetWindowThreadProcessId($hwnd, [IntPtr]::Zero)
        $self = [FsLab.Win]::GetCurrentThreadId()
        [void][FsLab.Win]::ShowWindow($hwnd, 9)
        if ($target -ne $self) { [void][FsLab.Win]::AttachThreadInput($self, $target, $true) }
        [void][FsLab.Win]::SetForegroundWindow($hwnd)
        if ($target -ne $self) { [void][FsLab.Win]::AttachThreadInput($self, $target, $false) }
        Start-Sleep -Milliseconds 120
    }
    return ([FsLab.Win]::GetForegroundWindow() -eq $hwnd)
}

$KEYEVENTF_KEYUP = 0x0002
$KEYEVENTF_EXTENDEDKEY = 0x0001
$WM_KEYDOWN = 0x0100
$WM_KEYUP = 0x0101
$VK_CTRL = 0x11
$script:hwnd = [IntPtr]::Zero

# Arrow keys and the rest of the navigation block (VK_PRIOR 0x21 .. VK_DOWN 0x28)
# share scan codes with the numeric keypad. Without KEYEVENTF_EXTENDEDKEY the
# engine sees "numpad 8" instead of "UP" and the input silently does nothing.
function Is-ExtendedVK([int]$vk) {
    return (($vk -ge 0x21 -and $vk -le 0x2E) -or $vk -eq 0x6F)
}

function Send-KeyDown([int]$vk) {
    $scan = [byte][FsLab.Win]::MapVirtualKey([byte]$vk, 0)
    $flags = 0
    if (Is-ExtendedVK $vk) { $flags = $KEYEVENTF_EXTENDEDKEY }
    [FsLab.Win]::keybd_event([byte]$vk, $scan, [uint32]$flags, [UIntPtr]::Zero)
    [void][FsLab.Win]::PostMessage($script:hwnd, $WM_KEYDOWN, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16)))
}
function Send-KeyUp([int]$vk) {
    $scan = [byte][FsLab.Win]::MapVirtualKey([byte]$vk, 0)
    $flags = $KEYEVENTF_KEYUP
    if (Is-ExtendedVK $vk) { $flags = $flags -bor $KEYEVENTF_EXTENDEDKEY }
    [FsLab.Win]::keybd_event([byte]$vk, $scan, [uint32]$flags, [UIntPtr]::Zero)
    [void][FsLab.Win]::PostMessage($script:hwnd, $WM_KEYUP, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16) -bor 0xC0000000))
}
function Tap-Key([int]$vk, [int]$holdMs = 80) {
    Send-KeyDown $vk
    Start-Sleep -Milliseconds $holdMs
    Send-KeyUp $vk
    Start-Sleep -Milliseconds 60
}
function Send-CtrlKey([int]$vk) {
    [void](Focus-Window $script:hwnd)
    $scan = [byte][FsLab.Win]::MapVirtualKey([byte]$vk, 0)
    $scanCtrl = [byte][FsLab.Win]::MapVirtualKey($VK_CTRL, 0)
    [FsLab.Win]::keybd_event([byte]$VK_CTRL, $scanCtrl, 0, [UIntPtr]::Zero)
    [void][FsLab.Win]::PostMessage($script:hwnd, $WM_KEYDOWN, [IntPtr]$VK_CTRL, [IntPtr]0)
    Start-Sleep -Milliseconds 60
    [FsLab.Win]::keybd_event([byte]$vk, $scan, 0, [UIntPtr]::Zero)
    [void][FsLab.Win]::PostMessage($script:hwnd, $WM_KEYDOWN, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16)))
    Start-Sleep -Milliseconds 80
    [FsLab.Win]::keybd_event([byte]$vk, $scan, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
    [void][FsLab.Win]::PostMessage($script:hwnd, $WM_KEYUP, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16) -bor 0xC0000000))
    Start-Sleep -Milliseconds 40
    [FsLab.Win]::keybd_event([byte]$VK_CTRL, $scanCtrl, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
    [void][FsLab.Win]::PostMessage($script:hwnd, $WM_KEYUP, [IntPtr]$VK_CTRL, [IntPtr]0)
    Start-Sleep -Milliseconds 60
}

function Save-Shot([IntPtr]$hwnd, [string]$path) {
    $r = New-Object FsLab.Win+RECT
    [void][FsLab.Win]::GetClientRect($hwnd, [ref]$r)
    $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
    if ($w -le 0 -or $h -le 0) { return $false }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    # PW_RENDERFULLCONTENT: without it an OpenGL window captures as black.
    $ok = [FsLab.Win]::PrintWindow($hwnd, $hdc, 2)
    $g.ReleaseHdc($hdc); $g.Dispose()
    if ($ok) { $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png) }
    $bmp.Dispose()
    return $ok
}

function Test-DebugOverlay([IntPtr]$hwnd) {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) 'fs_overlay_probe.png'
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
$argList = @('-p1', $P1, '-p2', $P2, '-s', $Stage, '-windowed', '-nosound', '-time', "$RoundTime")
if ($Ai1 -gt 0) { $argList += @('-p1.ai', "$Ai1") }
if ($Ai2 -gt 0) { $argList += @('-p2.ai', "$Ai2") }

$report = New-Object System.Collections.Generic.List[string]
$report.Add('harness   : tests/p2/framestep_probe.ps1')
$report.Add('args      : ' + ($argList -join ' '))
$report.Add('steps     : ' + $Steps)
$report.Add('outdir    : ' + $OutDir)

$proc = Start-Process -FilePath $Exe -WorkingDirectory $RuntimeRoot -ArgumentList $argList -PassThru
$report.Add("process   : pid=$($proc.Id)")

Start-Sleep -Seconds $WarmupSec
if ($proc.HasExited) {
    $report.Add("early exit: exitcode=$($proc.ExitCode)")
    $report | Out-File -Encoding utf8 (Join-Path $OutDir "${Prefix}_report.txt")
    $report | ForEach-Object { Write-Host $_ }
    exit 1
}

for ($i = 0; $i -lt 24; $i++) {
    $p = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if ($p -and $p.MainWindowHandle -ne 0) { $script:hwnd = $p.MainWindowHandle; break }
    Start-Sleep -Milliseconds 500
}
$report.Add("window    : hwnd=$script:hwnd")
if ($script:hwnd -eq [IntPtr]::Zero) {
    $report.Add('window    : NO WINDOW HANDLE')
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    $report | Out-File -Encoding utf8 (Join-Path $OutDir "${Prefix}_report.txt")
    $report | ForEach-Object { Write-Host $_ }
    exit 2
}
[void](Focus-Window $script:hwnd)

if ($ShowClsn) { Send-CtrlKey 0x43; $report.Add('sent      : Ctrl+C toggleClsnDisplay') }
if ($ShowDebug) {
    $on = $false
    for ($i = 1; $i -le 3; $i++) {
        Send-CtrlKey 0x44
        Start-Sleep -Milliseconds 350
        if (Test-DebugOverlay $script:hwnd) { $report.Add("debug     : overlay ON (attempt $i)"); $on = $true; break }
        $report.Add("debug     : overlay not detected (attempt $i)")
    }
    if (-not $on) { $report.Add('debug     : WARNING - debug overlay could not be enabled') }
}
if ($SlowSteps -gt 0) {
    for ($i = 0; $i -lt $SlowSteps; $i++) {
        Send-CtrlKey 0x53
        Start-Sleep -Milliseconds 200
    }
    $report.Add("sent      : Ctrl+S x$SlowSteps (changeSpeed)")
}

# Approach in real time (P1 faces right at round start, so Right closes distance).
if ($ApproachSec -gt 0) {
    [void](Focus-Window $script:hwnd)
    Send-KeyDown 0x27
    Start-Sleep -Milliseconds ([int]($ApproachSec * 1000))
    Send-KeyUp 0x27
    Start-Sleep -Milliseconds 150
    $report.Add("approach  : held Right for ${ApproachSec}s")
    $ap = Join-Path $OutDir ("{0}_approach.png" -f $Prefix)
    [void](Save-Shot $script:hwnd $ap)
}

# Pause: from here on the fight only advances when we send SCROLLLOCK.
$paused = $false
if (-not $NoPause) {
    [void](Focus-Window $script:hwnd)
    Tap-Key 0x13 120          # VK_PAUSE -> togglePause()
    Start-Sleep -Milliseconds 400
    $pa = Join-Path $OutDir ("{0}_paused.png" -f $Prefix)
    [void](Save-Shot $script:hwnd $pa)
    $report.Add('sent      : PAUSE (togglePause) -> ' + $pa)
    $paused = $true
}

# ---------------------------------------------------------------------------
# Tick loop
# ---------------------------------------------------------------------------
$tick = 0
$si = 0
foreach ($st in $StepList) {
    $si++
    if ($proc.HasExited) { $report.Add("exited    : before step group $si"); break }
    $label = if ($st.keys.Count -eq 0) { 'none' } else { (($st.keys | ForEach-Object { '{0:X2}' -f $_ }) -join '+') }
    [void](Focus-Window $script:hwnd)
    foreach ($vk in $st.keys) { Send-KeyDown $vk }

    for ($k = 0; $k -lt $st.ticks; $k++) {
        if ($proc.HasExited) { break }
        $tick++
        if ($paused) { Tap-Key 0x91 60 }        # VK_SCROLL -> frameStep()
        else { Start-Sleep -Milliseconds 16 }
        Start-Sleep -Milliseconds $TickWaitMs
        $f = Join-Path $OutDir ("{0}_g{1:d2}_{2}_t{3:d3}.png" -f $Prefix, $si, $label, $tick)
        $ok = Save-Shot $script:hwnd $f
        if (-not $ok) { $report.Add("shot      : t$tick FAILED") }
    }

    foreach ($vk in $st.keys) { Send-KeyUp $vk }
    Start-Sleep -Milliseconds 120
    $report.Add("group     : #$si keys=$label ticks=$($st.ticks) (ends at tick $tick)")
}

for ($i = 1; $i -le $TrailingShots; $i++) {
    if ($proc.HasExited) { break }
    $f = Join-Path $OutDir ("{0}_trail{1:d2}.png" -f $Prefix, $i)
    $ok = Save-Shot $script:hwnd $f
    $report.Add("trailing  : $i ok=$ok")
    if ($i -lt $TrailingShots) { Start-Sleep -Milliseconds 600 }
}

if (-not $proc.HasExited) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    $report.Add('stop      : process killed by harness')
}
else {
    $report.Add("stop      : engine exited by itself, exitcode=$($proc.ExitCode)")
}
$report.Add("ticks     : $tick")

$reportPath = Join-Path $OutDir "${Prefix}_report.txt"
$report | Out-File -Encoding utf8 $reportPath
$report | ForEach-Object { Write-Host $_ }
exit 0

#Requires -Version 5.1
<#
.SYNOPSIS
    P1 evidence harness: runs a Quick-VS match with the P1 lab character and
    captures window screenshots (optionally with the engine's debug overlays).

.DESCRIPTION
    IKEMEN GO's P1-phase verification is visual: a modification is only proven when
    the running engine visibly behaves differently. This helper makes that
    reproducible without a human at the keyboard:

      * launches the built engine directly with Quick-VS arguments
      * brings the game window to the foreground and posts the engine's own debug
        hotkeys (Ctrl+C = collision boxes, Ctrl+D = debug/state readout) - both were
        read from the engine's external/script/debug.lua, not guessed
      * captures the game window with PrintWindow(PW_RENDERFULLCONTENT), so the
        screenshot works even while the window is in the background
      * optionally holds a key (movement experiments) or taps a key repeatedly
        (command experiments)
      * writes a report next to the screenshots

    It never modifies game content and never touches git. It is a test harness for
    Phase P1, not a second build/run entry point - use scripts/run_game.ps1 for
    normal play and scripts/test.ps1 for the regression suite.

.PARAMETER P1
    Character name for player 1 (resolved by the engine under chars/).

.PARAMETER P2
    Character name for player 2.

.PARAMETER Stage
    Stage name for -s.

.PARAMETER RoundTime
    Round time in seconds (-1 = infinite).

.PARAMETER Ai1 / Ai2
    AI level 1-8 for that player. 0 means "no AI" (human input expected).

.PARAMETER WarmupSec
    Seconds to wait after launch before the first screenshot.

.PARAMETER Shots
    Number of screenshots to take.

.PARAMETER ShotIntervalSec
    Seconds between screenshots.

.PARAMETER TimeoutSec
    Hard limit: the process is killed after this many seconds.

.PARAMETER Prefix
    File name prefix for the screenshots.

.PARAMETER OutDir
    Output directory. Defaults to logs/p1/shots/.

.PARAMETER ShowClsn
    Send Ctrl+C (collision box display) once the match is on screen.

.PARAMETER ShowDebug
    Send Ctrl+D (debug / state / life readout) once the match is on screen.

.PARAMETER HoldVK
    Virtual key code to hold down for HoldSec seconds (e.g. 0x27 = Right arrow,
    0x41 = 'A').

.PARAMETER HoldSec
    How long to hold HoldVK.

.PARAMETER TapVK
    Virtual key code to tap repeatedly (e.g. 0x41 = 'A').

.PARAMETER TapCount
    Number of taps.

.PARAMETER TapIntervalMs
    Delay between taps in milliseconds.

.PARAMETER HoldSeqVK
    Virtual key codes to hold one after another, separated by commas. Each key is
    held for -HoldSec with the same burst captures as -HoldVK, then released, then
    -HoldSeqGapSec is waited out before the next one. This makes it possible to
    probe several inputs in a single engine launch (the engine only needs to be
    started once), which is how the P1 lab maps "which key reaches the engine".

.PARAMETER HoldSeqName
    Optional labels for -HoldSeqVK, used in the file names and the report.

.PARAMETER HoldSeqGapSec
    Seconds to wait between two -HoldSeqVK entries (lets the character return to a
    controllable state).

.PARAMETER MatchLog
    When set, passes -log <path> to the engine so a completed match writes its
    stats there and the engine exits by itself.

.EXAMPLE
    pwsh -File tests/p1/capture_match.ps1 -P1 p1_kfm_zss_lab -P2 kfm_zss -ShowClsn -ShowDebug -Prefix e0_baseline

.EXAMPLE
    pwsh -File tests/p1/capture_match.ps1 -P1 p1_kfm_zss_lab -Ai1 0 -HoldVK 0x27 -HoldSec 2 -Prefix e1_walk
#>
[CmdletBinding()]
param(
    [string]$P1 = 'p1_kfm_zss_lab',
    [string]$P2 = 'kfm_zss',
    [string]$Stage = 'stage0',
    [int]$RoundTime = 30,
    [int]$Ai1 = 8,
    [int]$Ai2 = 8,
    [int]$WarmupSec = 14,
    [int]$Shots = 4,
    [int]$ShotIntervalSec = 6,
    [int]$TimeoutSec = 120,
    [string]$Prefix = 'match',
    [string]$OutDir,
    [switch]$ShowClsn,
    [switch]$ShowDebug,
    [int]$HoldVK = -1,
    [double]$HoldSec = 0,
    [int]$TapVK = -1,
    [int]$TapCount = 0,
    [int]$TapIntervalMs = 700,
    [string]$HoldSeqVK = '',
    [string]$HoldSeqName = '',
    [string]$HoldSeqSec = '',
    [double]$HoldSeqGapSec = 1.2,
    [string]$MatchLog,
    [string[]]$ExtraArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -HoldSeqVK / -HoldSeqName arrive as comma-separated strings because pwsh -File
# cannot bind an array parameter from a comma list. Accept decimal or 0x-hex.
$HoldSeqVKList = @()
foreach ($tok in ($HoldSeqVK -split '[,;\s]+')) {
    $t = $tok.Trim()
    if ($t -eq '') { continue }
    if ($t -match '^0[xX]') { $HoldSeqVKList += [Convert]::ToInt32($t.Substring(2), 16) }
    else { $HoldSeqVKList += [int]$t }
}
$HoldSeqNameList = @()
foreach ($tok in ($HoldSeqName -split '[,;\s]+')) {
    $t = $tok.Trim()
    if ($t -ne '') { $HoldSeqNameList += $t }
}
$HoldSeqSecList = @()
foreach ($tok in ($HoldSeqSec -split '[,;\s]+')) {
    $t = $tok.Trim()
    if ($t -ne '') { $HoldSeqSecList += [double]$t }
}

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).ProviderPath
$RuntimeRoot = Join-Path $RepoRoot 'engine\ikemen-go'
$Exe = Join-Path $RuntimeRoot 'Ikemen_GO.exe'

if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $RepoRoot 'logs\p1\shots' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if (-not (Test-Path -LiteralPath $Exe)) {
    Write-Host "[fail] executable not found: $Exe" -ForegroundColor Red
    Write-Host '       build it first: pwsh -File scripts/build_engine.ps1' -ForegroundColor Yellow
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
# Win32 helpers
# ---------------------------------------------------------------------------
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace P1Lab -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
[DllImport("user32.dll")] public static extern uint MapVirtualKey(uint uCode, uint uMapType);
[DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr lpdwProcessId);
[DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
[DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
'@

# The engine reads the keyboard through SDL, which only reports keys while its
# window is the foreground window. SetForegroundWindow alone is usually refused
# for a background process, so the AttachThreadInput workaround is used and the
# result is verified instead of assumed.
function Focus-Window([IntPtr]$hwnd) {
    for ($i = 0; $i -lt 6; $i++) {
        if ([P1Lab.Win]::GetForegroundWindow() -eq $hwnd) { return $true }
        $target = [P1Lab.Win]::GetWindowThreadProcessId($hwnd, [IntPtr]::Zero)
        $self = [P1Lab.Win]::GetCurrentThreadId()
        [void][P1Lab.Win]::ShowWindow($hwnd, 9)   # SW_RESTORE
        if ($target -ne $self) { [void][P1Lab.Win]::AttachThreadInput($self, $target, $true) }
        [void][P1Lab.Win]::SetForegroundWindow($hwnd)
        if ($target -ne $self) { [void][P1Lab.Win]::AttachThreadInput($self, $target, $false) }
        Start-Sleep -Milliseconds 120
    }
    return ([P1Lab.Win]::GetForegroundWindow() -eq $hwnd)
}

$WM_KEYDOWN = 0x0100
$WM_KEYUP = 0x0101
$KEYEVENTF_KEYUP = 0x0002
$VK_CTRL = 0x11

# Send a key press to the game. AppActivate is attempted first so the real input
# queue receives it (keeps SDL's modifier tracking correct); a direct window
# message with a proper scan code in lParam is sent as well.
function Send-Key([IntPtr]$hwnd, [int]$procId, [int]$vk, [switch]$Ctrl, [switch]$UpOnly) {
    [void](Focus-Window $hwnd)
    $k = [byte]$vk
    $scan = [byte][P1Lab.Win]::MapVirtualKey($k, 0)
    $lDown = [IntPtr](1 -bor ($scan -shl 16))
    $lUp = [IntPtr](1 -bor ($scan -shl 16) -bor 0xC0000000)

    if ($Ctrl) {
        $scanCtrl = [byte][P1Lab.Win]::MapVirtualKey($VK_CTRL, 0)
        [P1Lab.Win]::keybd_event([byte]$VK_CTRL, $scanCtrl, 0, [UIntPtr]::Zero)
        [void][P1Lab.Win]::PostMessage($hwnd, $WM_KEYDOWN, [IntPtr]$VK_CTRL, [IntPtr]0)
        Start-Sleep -Milliseconds 60
    }
    [P1Lab.Win]::keybd_event($k, $scan, 0, [UIntPtr]::Zero)
    [void][P1Lab.Win]::PostMessage($hwnd, $WM_KEYDOWN, [IntPtr]$vk, $lDown)
    Start-Sleep -Milliseconds 80
    [P1Lab.Win]::keybd_event($k, $scan, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
    [void][P1Lab.Win]::PostMessage($hwnd, $WM_KEYUP, [IntPtr]$vk, $lUp)
    if ($Ctrl) {
        Start-Sleep -Milliseconds 40
        [P1Lab.Win]::keybd_event([byte]$VK_CTRL, $scanCtrl, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
        [void][P1Lab.Win]::PostMessage($hwnd, $WM_KEYUP, [IntPtr]$VK_CTRL, [IntPtr]0)
    }
    Start-Sleep -Milliseconds 60
}

# Press / release a key without the built-in delay, so the caller can pick the
# exact moment to take a screenshot (attack animations are only a few frames long).
function Press-VK([IntPtr]$hwnd, [int]$procId, [int]$vk) {
    [void](Focus-Window $hwnd)
    $k = [byte]$vk
    $scan = [byte][P1Lab.Win]::MapVirtualKey($k, 0)
    [P1Lab.Win]::keybd_event($k, $scan, 0, [UIntPtr]::Zero)
    [void][P1Lab.Win]::PostMessage($hwnd, $WM_KEYDOWN, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16)))
}
function Release-VK([IntPtr]$hwnd, [int]$vk) {
    $k = [byte]$vk
    $scan = [byte][P1Lab.Win]::MapVirtualKey($k, 0)
    [P1Lab.Win]::keybd_event($k, $scan, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
    [void][P1Lab.Win]::PostMessage($hwnd, $WM_KEYUP, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16) -bor 0xC0000000))
}

# Hold a key down for a while (used for held direction / button experiments).
function Hold-Key([IntPtr]$hwnd, [int]$procId, [int]$vk, [double]$seconds) {
    [void](Focus-Window $hwnd)
    $k = [byte]$vk
    $scan = [byte][P1Lab.Win]::MapVirtualKey($k, 0)
    [P1Lab.Win]::keybd_event($k, $scan, 0, [UIntPtr]::Zero)
    [void][P1Lab.Win]::PostMessage($hwnd, $WM_KEYDOWN, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16)))
    Start-Sleep -Milliseconds ([int]([math]::Round($seconds * 1000)))
    [P1Lab.Win]::keybd_event($k, $scan, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
    [void][P1Lab.Win]::PostMessage($hwnd, $WM_KEYUP, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16) -bor 0xC0000000))
    Start-Sleep -Milliseconds 120
}

function Save-Shot([IntPtr]$hwnd, [string]$path) {
    $r = New-Object P1Lab.Win+RECT
    [void][P1Lab.Win]::GetClientRect($hwnd, [ref]$r)
    $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
    if ($w -le 0 -or $h -le 0) { return $false }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    $ok = [P1Lab.Win]::PrintWindow($hwnd, $hdc, 2)   # PW_RENDERFULLCONTENT
    $g.ReleaseHdc($hdc); $g.Dispose()
    if ($ok) { $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png) }
    $bmp.Dispose()
    return $ok
}

# The debug overlay is drawn as near-white text over the bottom-left corner of the
# client area. If the toggle keypress is missed the screenshots look plausible but
# carry no state readout at all, so the result is checked instead of assumed.
function Test-DebugOverlay([IntPtr]$hwnd) {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) 'p1_overlay_probe.png'
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
# Build the engine command line
# ---------------------------------------------------------------------------
$argList = @(
    '-p1', $P1, '-p2', $P2, '-s', $Stage,
    '-windowed', '-nosound', '-time', "$RoundTime"
)
if ($Ai1 -gt 0) { $argList += @('-p1.ai', "$Ai1") }
if ($Ai2 -gt 0) { $argList += @('-p2.ai', "$Ai2") }
if (-not [string]::IsNullOrWhiteSpace($MatchLog)) { $argList += @('-log', $MatchLog) }
if ($ExtraArgs) { $argList += $ExtraArgs }

$report = New-Object System.Collections.Generic.List[string]
$report.Add("harness   : tests/p1/capture_match.ps1")
$report.Add("args      : " + ($argList -join ' '))
$report.Add("outdir    : $OutDir")

$proc = Start-Process -FilePath $Exe -WorkingDirectory $RuntimeRoot -ArgumentList $argList -PassThru
$report.Add("process   : pid=$($proc.Id)")

Start-Sleep -Seconds $WarmupSec
if ($proc.HasExited) {
    $report.Add("early exit: exitcode=$($proc.ExitCode)")
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
    $report.Add('window    : NO WINDOW HANDLE')
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    $report | Out-File -Encoding utf8 (Join-Path $OutDir "${Prefix}_report.txt")
    Get-Content (Join-Path $OutDir "${Prefix}_report.txt")
    exit 2
}

$focused = Focus-Window $hwnd
$report.Add("focus     : foreground acquired=$focused")

$cr = New-Object P1Lab.Win+RECT
[void][P1Lab.Win]::GetClientRect($hwnd, [ref]$cr)
$report.Add("client    : $($cr.Right - $cr.Left)x$($cr.Bottom - $cr.Top)")

if ($ShowClsn) { Send-Key $hwnd $proc.Id 0x43 -Ctrl; $report.Add('sent      : Ctrl+C toggleClsnDisplay') }
if ($ShowDebug) {
    # toggle it, then verify it is really on; a missed keypress would otherwise be
    # invisible in the report while making every screenshot useless
    $on = $false
    for ($i = 1; $i -le 3; $i++) {
        Send-Key $hwnd $proc.Id 0x44 -Ctrl
        Start-Sleep -Milliseconds 350
        if (Test-DebugOverlay $hwnd) {
            $report.Add("debug     : overlay ON (attempt $i)")
            $on = $true
            break
        }
        $report.Add("debug     : overlay not detected (attempt $i)")
    }
    if (-not $on) { $report.Add('debug     : WARNING - debug overlay could not be enabled') }
}

if ($HoldVK -gt 0 -and $HoldSec -gt 0) {
    $shotBefore = Join-Path $OutDir ("{0}_hold_before.png" -f $Prefix)
    [void](Save-Shot $hwnd $shotBefore)
    $report.Add("hold      : vk=0x$('{0:X2}' -f $HoldVK) for ${HoldSec}s (before shot: $shotBefore)")
    # press, then burst-capture while the key is held: attacks are only a few
    # frames long, so a single shot after the release can miss them entirely
    [void](Focus-Window $hwnd)
    $vk = [byte]$HoldVK
    $scan = [byte][P1Lab.Win]::MapVirtualKey($vk, 0)
    [P1Lab.Win]::keybd_event($vk, $scan, 0, [UIntPtr]::Zero)
    [void][P1Lab.Win]::PostMessage($hwnd, $WM_KEYDOWN, [IntPtr]$HoldVK, [IntPtr](1 -bor ($scan -shl 16)))
    # capture as fast as the window can be copied, for the whole duration of the
    # hold: KFM's attacks are only ~20 ticks long, so a fixed capture timeline
    # drifts (each Save-Shot costs tens of ms) and can miss the state entirely
    $holdMs = [int]([math]::Round($HoldSec * 1000))
    $deadline = (Get-Date).AddMilliseconds($holdMs)
    $bi = 0
    while ((Get-Date) -lt $deadline) {
        $bi++
        $bf = Join-Path $OutDir ("{0}_hold_burst{1:d2}.png" -f $Prefix, $bi)
        [void](Save-Shot $hwnd $bf)
        $report.Add("holdburst : shot $bi -> $bf")
    }
    [P1Lab.Win]::keybd_event($vk, $scan, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
    [void][P1Lab.Win]::PostMessage($hwnd, $WM_KEYUP, [IntPtr]$HoldVK, [IntPtr](1 -bor ($scan -shl 16) -bor 0xC0000000))
    Start-Sleep -Milliseconds 400
    $shotAfter = Join-Path $OutDir ("{0}_hold_after.png" -f $Prefix)
    [void](Save-Shot $hwnd $shotAfter)
    $report.Add("hold      : after shot: $shotAfter")
}

if ($TapVK -gt 0 -and $TapCount -gt 0) {
    for ($t = 1; $t -le $TapCount; $t++) {
        # shot at the moment the move is executing, then again once the hit has
        # resolved (the debug readout keeps showing the resulting life value)
        Press-VK $hwnd $proc.Id $TapVK
        Start-Sleep -Milliseconds 70
        $shotLive = Join-Path $OutDir ("{0}_tap{1:d2}_live.png" -f $Prefix, $t)
        [void](Save-Shot $hwnd $shotLive)
        Start-Sleep -Milliseconds 130
        Release-VK $hwnd $TapVK
        Start-Sleep -Milliseconds 900
        $shotSettle = Join-Path $OutDir ("{0}_tap{1:d2}_settle.png" -f $Prefix, $t)
        [void](Save-Shot $hwnd $shotSettle)
        $report.Add("tap       : #$t vk=0x$('{0:X2}' -f $TapVK) live=$shotLive settle=$shotSettle")
        Start-Sleep -Milliseconds $TapIntervalMs
    }
}

if ($HoldSeqVKList.Count -gt 0) {
    # Probe several inputs in one engine launch. Each key is held on its own (so
    # only one key can be responsible for whatever happens), captured in a burst,
    # then released and allowed to settle before the next one.
    for ($k = 0; $k -lt $HoldSeqVKList.Count; $k++) {
        $vk = $HoldSeqVKList[$k]
        if ($vk -le 0) { continue }
        $label = if ($k -lt $HoldSeqNameList.Count) { $HoldSeqNameList[$k] } else { 'k{0:d2}' -f ($k + 1) }
        $sec = if ($k -lt $HoldSeqSecList.Count) { $HoldSeqSecList[$k] } else { $HoldSec }
        $tag = '{0}_seq{1:d2}_{2}' -f $Prefix, ($k + 1), $label

        $shotBefore = Join-Path $OutDir ("{0}_before.png" -f $tag)
        [void](Save-Shot $hwnd $shotBefore)

        [void](Focus-Window $hwnd)
        $b = [byte]$vk
        $sc = [byte][P1Lab.Win]::MapVirtualKey($b, 0)
        [P1Lab.Win]::keybd_event($b, $sc, 0, [UIntPtr]::Zero)
        [void][P1Lab.Win]::PostMessage($hwnd, $WM_KEYDOWN, [IntPtr]$vk, [IntPtr](1 -bor ($sc -shl 16)))

        $holdMs = [int]([math]::Round($sec * 1000))
        $deadline = (Get-Date).AddMilliseconds($holdMs)
        $bi = 0
        while ((Get-Date) -lt $deadline) {
            $bi++
            $bf = Join-Path $OutDir ("{0}_burst{1:d2}.png" -f $tag, $bi)
            [void](Save-Shot $hwnd $bf)
        }

        [P1Lab.Win]::keybd_event($b, $sc, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
        [void][P1Lab.Win]::PostMessage($hwnd, $WM_KEYUP, [IntPtr]$vk, [IntPtr](1 -bor ($sc -shl 16) -bor 0xC0000000))
        Start-Sleep -Milliseconds 300
        $shotAfter = Join-Path $OutDir ("{0}_after.png" -f $tag)
        [void](Save-Shot $hwnd $shotAfter)

        $report.Add("holdseq   : #$($k + 1) vk=0x$('{0:X2}' -f $vk) label=$label hold=${sec}s bursts=$bi before=$shotBefore after=$shotAfter")
        Start-Sleep -Milliseconds ([int]([math]::Round($HoldSeqGapSec * 1000)))
    }
}

$start = Get-Date
$idx = 0
while ($idx -lt $Shots) {
    if ($proc.HasExited) { $report.Add("exited    : during loop, exitcode=$($proc.ExitCode)"); break }
    if ((New-TimeSpan -Start $start).TotalSeconds -gt $TimeoutSec) { $report.Add('timeout   : shot loop limit reached'); break }
    $idx++
    $f = Join-Path $OutDir ("{0}_{1:d2}.png" -f $Prefix, $idx)
    $ok = Save-Shot $hwnd $f
    $report.Add("shot      : $idx ok=$ok -> $f")
    if ($idx -lt $Shots) { Start-Sleep -Seconds $ShotIntervalSec }
}

if (-not $proc.HasExited) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    $report.Add('stop      : process killed by harness')
}
else {
    $report.Add("stop      : engine exited by itself, exitcode=$($proc.ExitCode)")
}
if (-not [string]::IsNullOrWhiteSpace($MatchLog)) {
    $report.Add("matchlog  : $MatchLog exists=$(Test-Path -LiteralPath $MatchLog)")
}

$reportPath = Join-Path $OutDir "${Prefix}_report.txt"
$report | Out-File -Encoding utf8 $reportPath
$report | ForEach-Object { Write-Host $_ }
exit 0

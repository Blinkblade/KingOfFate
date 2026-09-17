#Requires -Version 5.1
<#
.SYNOPSIS
    P2 harness: runs a Quick-VS match and injects PHASES of key input, where
    each phase may hold SEVERAL keys at the same time.

.DESCRIPTION
    tests/p1/capture_match.ps1 can hold or tap ONE key at a time. That is
    enough for single-button probes, but it cannot express:
      * simultaneous keys   (throw = hold Forward + press button y)
      * motion inputs       (QCF = D, then D+F, then F, then button x)

    This helper adds exactly that, reusing the same Win32 injection core and
    screenshot approach as the P1 harness. It is a test tool, not a second
    game entry point - normal play stays on scripts/run_game.ps1, regression
    on scripts/test.ps1.

    Phases are a comma list of "keys:seconds" tokens, e.g.

      -Phases '0x27:2.8','0x28:0.10','0x28+0x27:0.10','0x27:0.10','0x09:0.35'

    (= walk forward into the opponent, then QCF + A). '+' means the keys are
    held simultaneously during that phase. Every key is released at the end of
    its phase and a short settle gap follows, so phases are cleanly separable
    in the burst screenshots.

    HARD RULES inherited from P1 (see tests/p1/README.md):
      * inject with -Ai1 0 (the default here): an AI-controlled P1 eats the
        injected input silently and the run proves nothing
      * only TAB (0x09), RETURN (0x0D) and the arrow keys (0x25-0x28) are
        known to reach the engine; letters and navigation keys do not
        (P1 experiments doc, section E0; arrows verified in E1/E5)
      * the debug overlay's "P1: <n>" is the character ID, not a coordinate;
        positions can only be measured in pixels or via displayToClipboard

.PARAMETER Phases
    ONE comma-separated string of "keys:seconds" tokens. Keys are virtual-key
    codes, decimal or 0x-hex, '+'-separated. Example:
    -Phases '0x27+0x0D:1.0' holds Right + RETURN for one second (throw attempt
    at contact range).

.EXAMPLE
    pwsh -File tests/p2/inject_phases.ps1 -Prefix v11_throw `
        -Phases '0x27:2.8','0x27+0x0D:1.0' -ShowDebug -ShowClsn
#>
[CmdletBinding()]
param(
    [string]$P1 = '_template',
    [string]$P2 = 'kfm_zss',
    [string]$Stage = 'stage0',
    [int]$RoundTime = 60,
    [int]$Ai1 = 0,
    [int]$Ai2 = 0,
    [int]$WarmupSec = 14,
    [int]$Shots = 2,
    [int]$ShotIntervalSec = 4,
    [int]$TimeoutSec = 180,
    [string]$Prefix = 'phases',
    [string]$OutDir,
    [switch]$ShowClsn,
    [switch]$ShowDebug,
    [string]$Phases = '',
    [double]$SettleSec = 0.3,
    [switch]$NoStillShots
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -Phases arrives as ONE comma-separated string because pwsh -File cannot bind
# an array parameter from a comma list (same reason -HoldSeqVK is a string in
# the P1 harness). Tokens: "keys:seconds", keys '+-separated.
$PhaseList = @()
foreach ($tok in ($Phases -split '[,;\s]+')) {
    $t = $tok.Trim()
    if ($t -eq '') { continue }
    $kv = $t -split ':', 2
    if ($kv.Count -ne 2) { throw "phase token '$t' must be 'keys:seconds'" }
    $keys = @()
    foreach ($k in ($kv[0] -split '\+')) {
        $k = $k.Trim()
        if ($k -eq '') { continue }
        if ($k -match '^0[xX]') { $keys += [Convert]::ToInt32($k.Substring(2), 16) }
        else { $keys += [int]$k }
    }
    if ($keys.Count -eq 0) { throw "phase token '$t' has no keys" }
    $PhaseList += , @{ keys = $keys; sec = [double]$kv[1] }
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

# Same DLL discovery order as scripts/run_game.ps1 / capture_match.ps1
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
# Win32 core (same approach as tests/p1/capture_match.ps1, own namespace so
# both harnesses can be loaded in one session)
# ---------------------------------------------------------------------------
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace P2Lab -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
[DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
[DllImport("user32.dll")] public static extern uint MapVirtualKey(uint uCode, uint uMapType);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr lpdwProcessId);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
[DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
[DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
'@

function Focus-Window([IntPtr]$hwnd) {
    for ($i = 0; $i -lt 6; $i++) {
        if ([P2Lab.Win]::GetForegroundWindow() -eq $hwnd) { return $true }
        $target = [P2Lab.Win]::GetWindowThreadProcessId($hwnd, [IntPtr]::Zero)
        $self = [P2Lab.Win]::GetCurrentThreadId()
        [void][P2Lab.Win]::ShowWindow($hwnd, 9)
        if ($target -ne $self) { [void][P2Lab.Win]::AttachThreadInput($self, $target, $true) }
        [void][P2Lab.Win]::SetForegroundWindow($hwnd)
        if ($target -ne $self) { [void][P2Lab.Win]::AttachThreadInput($self, $target, $false) }
        Start-Sleep -Milliseconds 120
    }
    return ([P2Lab.Win]::GetForegroundWindow() -eq $hwnd)
}

$KEYEVENTF_KEYUP = 0x0002
$WM_KEYDOWN = 0x0100
$WM_KEYUP = 0x0101
$VK_CTRL = 0x11
$script:hwnd = [IntPtr]::Zero

# Inject = keybd_event (global input queue) AND PostMessage WM_KEYDOWN/UP
# straight into the game window. The P1 harness does the same double delivery;
# keybd_event alone proved flaky here (P2 finding: a lone keybd_event tap is
# focus-sensitive and can be lost entirely).
function Send-CtrlKey([int]$vk) {
    [void](Focus-Window $script:hwnd)
    $scan = [byte][P2Lab.Win]::MapVirtualKey([byte]$vk, 0)
    $scanCtrl = [byte][P2Lab.Win]::MapVirtualKey($VK_CTRL, 0)
    $lDown = [IntPtr](1 -bor ($scan -shl 16))
    $lUp = [IntPtr](1 -bor ($scan -shl 16) -bor 0xC0000000)
    [P2Lab.Win]::keybd_event([byte]$VK_CTRL, $scanCtrl, 0, [UIntPtr]::Zero)
    [void][P2Lab.Win]::PostMessage($script:hwnd, $WM_KEYDOWN, [IntPtr]$VK_CTRL, [IntPtr]0)
    Start-Sleep -Milliseconds 60
    [P2Lab.Win]::keybd_event([byte]$vk, $scan, 0, [UIntPtr]::Zero)
    [void][P2Lab.Win]::PostMessage($script:hwnd, $WM_KEYDOWN, [IntPtr]$vk, $lDown)
    Start-Sleep -Milliseconds 80
    [P2Lab.Win]::keybd_event([byte]$vk, $scan, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
    [void][P2Lab.Win]::PostMessage($script:hwnd, $WM_KEYUP, [IntPtr]$vk, $lUp)
    Start-Sleep -Milliseconds 40
    [P2Lab.Win]::keybd_event([byte]$VK_CTRL, $scanCtrl, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
    [void][P2Lab.Win]::PostMessage($script:hwnd, $WM_KEYUP, [IntPtr]$VK_CTRL, [IntPtr]0)
    Start-Sleep -Milliseconds 60
}

# Arrow keys (and the other "navigation" keys) are EXTENDED keys: they share their
# scan codes with the numeric keypad (UP == numpad 8, etc.). Without
# KEYEVENTF_EXTENDEDKEY the target sees "numpad 8" instead of "UP", and the engine's
# direction input never moves -- silently, because the key *is* delivered.
# P4 hit this: QCF injection degraded into a single-button attack, and a 2-second
# UP hold did not make the character jump at all (logs/p2/shots/p4_jump_p01_26_after.png).
# The fix is the same flag Windows itself sets for these keys.
$KEYEVENTF_EXTENDEDKEY = 0x0001
function Is-ExtendedVK([int]$vk) {
    # VK_PRIOR(0x21) .. VK_DOWN(0x28), plus the numpad/divide & numlock block
    return (($vk -ge 0x21 -and $vk -le 0x2E) -or $vk -eq 0x6F)
}
function Press-Key([int]$vk) {
    $scan = [byte][P2Lab.Win]::MapVirtualKey([byte]$vk, 0)
    $flags = 0
    if (Is-ExtendedVK $vk) { $flags = $KEYEVENTF_EXTENDEDKEY }
    [P2Lab.Win]::keybd_event([byte]$vk, $scan, [uint32]$flags, [UIntPtr]::Zero)
    [void][P2Lab.Win]::PostMessage($script:hwnd, $WM_KEYDOWN, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16)))
}
function Release-Key([int]$vk) {
    $scan = [byte][P2Lab.Win]::MapVirtualKey([byte]$vk, 0)
    $flags = $KEYEVENTF_KEYUP
    if (Is-ExtendedVK $vk) { $flags = $flags -bor $KEYEVENTF_EXTENDEDKEY }
    [P2Lab.Win]::keybd_event([byte]$vk, $scan, [uint32]$flags, [UIntPtr]::Zero)
    [void][P2Lab.Win]::PostMessage($script:hwnd, $WM_KEYUP, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16) -bor 0xC0000000))
}

function Save-Shot([IntPtr]$hwnd, [string]$path) {
    $r = New-Object P2Lab.Win+RECT
    [void][P2Lab.Win]::GetClientRect($hwnd, [ref]$r)
    $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
    if ($w -le 0 -or $h -le 0) { return $false }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    $ok = [P2Lab.Win]::PrintWindow($hwnd, $hdc, 2)   # PW_RENDERFULLCONTENT
    $g.ReleaseHdc($hdc); $g.Dispose()
    if ($ok) { $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png) }
    $bmp.Dispose()
    return $ok
}

function Test-DebugOverlay([IntPtr]$hwnd) {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) 'p2_overlay_probe.png'
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
# Engine launch (same argument shape as the P1 harness; NO -pN.ai when the
# level is 0, so a report without "-p1.ai" certifies human-input mode)
# ---------------------------------------------------------------------------
$argList = @(
    '-p1', $P1, '-p2', $P2, '-s', $Stage,
    '-windowed', '-nosound', '-time', "$RoundTime"
)
if ($Ai1 -gt 0) { $argList += @('-p1.ai', "$Ai1") }
if ($Ai2 -gt 0) { $argList += @('-p2.ai', "$Ai2") }

$report = New-Object System.Collections.Generic.List[string]
$report.Add("harness   : tests/p2/inject_phases.ps1")
$report.Add("args      : " + ($argList -join ' '))
$report.Add("outdir    : $OutDir")
$report.Add("phases    : " + ($Phases -join ' | '))

$proc = Start-Process -FilePath $Exe -WorkingDirectory $RuntimeRoot -ArgumentList $argList -PassThru
$report.Add("process   : pid=$($proc.Id)")

Start-Sleep -Seconds $WarmupSec
if ($proc.HasExited) {
    $report.Add("early exit: exitcode=$($proc.ExitCode)")
    $report | Out-File -Encoding utf8 (Join-Path $OutDir "${Prefix}_report.txt")
    Get-Content (Join-Path $OutDir "${Prefix}_report.txt")
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
    Get-Content (Join-Path $OutDir "${Prefix}_report.txt")
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

# ---------------------------------------------------------------------------
# Phase injection: press all keys of the phase, burst-capture while held,
# release, settle. Burst naming: <prefix>_pNN_<keys>_burstMM.png
# ---------------------------------------------------------------------------
$pi = 0
foreach ($ph in $PhaseList) {
    $pi++
    if ($proc.HasExited) { $report.Add("exited    : before phase $pi"); break }
    $label = ($ph.keys | ForEach-Object { '{0:X2}' -f $_ }) -join '+'
    $tag = '{0}_p{1:d2}_{2}' -f $Prefix, $pi, $label
    $sec = $ph.sec

    # before/after stills cost ~100 ms each; -NoStillShots skips them so the
    # gap between two phases stays inside tight command windows (FF time=10)
    if (-not $NoStillShots) {
        $before = Join-Path $OutDir ("{0}_before.png" -f $tag)
        [void](Save-Shot $script:hwnd $before)
    }

    [void](Focus-Window $script:hwnd)
    foreach ($vk in $ph.keys) { Press-Key $vk }

    $deadline = (Get-Date).AddMilliseconds([int]($sec * 1000))
    $bi = 0
    while ((Get-Date) -lt $deadline) {
        $bi++
        $bf = Join-Path $OutDir ("{0}_burst{1:d2}.png" -f $tag, $bi)
        [void](Save-Shot $script:hwnd $bf)
    }

    foreach ($vk in $ph.keys) { Release-Key $vk }
    Start-Sleep -Milliseconds ([int]($SettleSec * 1000))

    if (-not $NoStillShots) {
        $after = Join-Path $OutDir ("{0}_after.png" -f $tag)
        [void](Save-Shot $script:hwnd $after)
        $report.Add("phase     : #$pi keys=$label hold=${sec}s bursts=$bi before=$before after=$after")
    }
    else {
        $report.Add("phase     : #$pi keys=$label hold=${sec}s bursts=$bi (no stills)")
    }
}

# ---------------------------------------------------------------------------
# Generic trailing shots (usually the recovery / result of the last phase)
# ---------------------------------------------------------------------------
$start = Get-Date
$idx = 0
while ($idx -lt $Shots) {
    if ($proc.HasExited) { $report.Add("exited    : during shots, exitcode=$($proc.ExitCode)"); break }
    if ((New-TimeSpan -Start $start).TotalSeconds -gt $TimeoutSec) { $report.Add('timeout   : shot loop limit reached'); break }
    $idx++
    $f = Join-Path $OutDir ("{0}_{1:d2}.png" -f $Prefix, $idx)
    $ok = Save-Shot $script:hwnd $f
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

$reportPath = Join-Path $OutDir "${Prefix}_report.txt"
$report | Out-File -Encoding utf8 $reportPath
$report | ForEach-Object { Write-Host $_ }
exit 0

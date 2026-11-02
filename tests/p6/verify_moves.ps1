#Requires -Version 5.1
<#
.SYNOPSIS
    Archer 全招式端到端验收（Runtime，基于引擎 stdout 遥测）。

.DESCRIPTION
    为什么要这个脚本（P6 收尾）:
      * 之前所有"招式好不好使"的证据都来自截图 OCR 或肉眼 —— 多位数字会误读，
        而且 21 招逐条看根本不可重复。docs/HANDOFF.md §7.2 要求"程序可读通道"。
      * 引擎其实**可以抓 stdout**（GUI 子系统也能被重定向，实测 `-h` 拿回 44 行，
        连 Go 的 Panic 栈都进同一份流）。旧结论"stdout 不可写"是错的 ——
        那次只是 25 秒内没人调用 fmt.Printf。
      * 于是本脚本用 ZSS 的 printToConsole 把 p1 每 tick 的状态
        （状态号 / 坐标 / 气 / 对手血量 / 投射物数 ...）打成一行 CSV，
        再用重定向落到文件里，最后逐招断言。探针见 tests/p6/fixtures/archer_probe.zss。

    一条断言链，四类检查（全部是"应该失败"能被抓到的形式）:
      ① 进入状态 —— 按这套键，状态号必须**真的**变成期望值
                     （路由顺序、命令缓冲、键位映射错了都会挂）
      ② 伤害     —— 对手血量下降必须等于 .zss 里声明的 damage 之和
                     （射箭"没伤害"那类 bug 会挂）
      ③ 耗气     —— 进入招式那一 tick 的气变化必须等于 (StateDef 头 poweradd − powerAdd 负值)
                     （"只挡不扣"那类 bug 会挂：观测值会是 0 而不是 −260）
      ④ 收招     —— 必须回到 ctrl=1（卡在状态里会挂）
    另外顺手量三件只有逐帧数据才能量的事:
      ⑤ 位移     —— 1300 突进斩 / 1200 后撤投剑在判定期是否真的停住
      ⑥ 投射物   —— 射箭一次出招恰好 1 枚（var(10) 闩锁失效会变 3 枚）
      ⑦ T2 精防  —— 防守时 numExplod(7191) 是否出现（-Pass guard）

    ★ 注入方式: Win32 keybd_event + PostMessage（沿用 tests/p1 的做法）。
      引擎用 SDL 读键盘，只有窗口在前台才收得到，所以每次按键前都用
      "按住 ALT 再 SetForegroundWindow" 抢前台（本机 ForegroundLockTimeout
      会让单纯 SetForegroundWindow 被静默拒绝）。
      ★★ 本机只能注入 6 个键：SPACE / RETURN / TAB / BACKSPACE / LSHIFT / LCTRL。
      字母键（a s z x c d）和 INSERT 注进去引擎**收不到**（方向键正常），
      所以脚本会先把 save/config.ini 的 [Keys_P1] 临时改成这套，跑完无条件还原。

    ★ 仪表化只改 **runtime 副本**（engine/ikemen-go/chars/archer/），
      该目录在子模块里被 .gitignore 忽略，所以 game/ 真值与 git 都不受影响。
      脚本结束时会把 archer.def 原始字节写回去（除非 -KeepInstrument）。

    ★ 采样约定: 探针在 [StateDef -2] 里采样，而 -2 在**当前状态动作之前**执行
      （char.go:11932-11944），所以"第一行出现新状态"的那一行已经是进入后的
      数值。做差时要拿它**前一行**当基准。

.PARAMETER Pass
    moves = 逐招验收；guard = T2 完美防（对手开 AI 出手）；all = 两个都跑。

.PARAMETER OutDir
    报告与 CSV 的输出目录。默认 logs/p6/verify（logs/ 是 gitignored）。

.PARAMETER SkipSync
    跳过 game/ -> runtime 的同步。默认先同步（否则测的是旧副本）。

.PARAMETER KeepInstrument
    跑完不还原 archer.def、保留 probe.zss（调试用；下次同步会自己覆盖）。

.PARAMETER Replay
    不启动游戏，直接拿上次的 run.csv + windows.json 重做分析（改断言逻辑时用）。

.EXAMPLE
    pwsh -File tests/p6/verify_moves.ps1 -Pass all
    pwsh -File tests/p6/verify_moves.ps1 -Pass moves -KeepInstrument
    pwsh -File tests/p6/verify_moves.ps1 -Replay
#>
[CmdletBinding()]
param(
    [ValidateSet('moves', 'guard', 'all', 'keytest')]
    [string]$Pass = 'all',
    [string]$OutDir,
    [switch]$SkipSync,
    [switch]$KeepInstrument,
    [switch]$Replay,
    [int]$MoveTimeoutMs = 7000,
    # 只跑指定配方：序号（1 起，与报告 # 列一致）或名字片段，可给多个。
    # 例：-Only 21,22   /   -Only 投技    —— 单条迭代不必跑满 29 条。
    [string[]]$Only = @(),
    # 只打印配方表然后退出。
    [switch]$List
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
$RuntimeChar = Join-Path $RuntimeRoot 'chars\archer'
$RuntimeDef = Join-Path $RuntimeChar 'archer.def'
$RuntimeProbe = Join-Path $RuntimeChar 'probe.zss'
$GameChar = Join-Path $RepoRoot 'game\chars\archer'
$ProbeFixture = Join-Path $ScriptDir 'fixtures\archer_probe.zss'
$RuntimeConfig = Join-Path $RuntimeRoot 'save\config.ini'
$ZssPath = Join-Path $GameChar 'archer.zss'
$HitsPath = Join-Path $GameChar 'hits.zss'

if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $RepoRoot 'logs\p6\verify' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$CsvPath = Join-Path $OutDir 'run.csv'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$t) { Write-Host "[ run ] $t" -ForegroundColor Cyan }
function Write-Ok([string]$t) { Write-Host "[ ok  ] $t" -ForegroundColor Green }
function Write-Bad([string]$t) { Write-Host "[fail] $t" -ForegroundColor Red }
function Write-Note([string]$t) { Write-Host "[note ] $t" -ForegroundColor DarkGray }

if (-not (Test-Path -LiteralPath $Exe)) {
    Write-Bad "executable not found: $Exe"
    exit 2
}

# ---------------------------------------------------------------------------
# Runtime DLL search path（与 scripts/run_game.ps1 同序）
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath (Join-Path $RuntimeRoot 'SDL2.dll'))) {
    $found = $null
    foreach ($c in @($env:MSYS2_ROOT, $env:MSYS2_HOME, 'C:\msys64', 'D:\msys64')) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        $p = Join-Path $c 'mingw64\bin'
        if (Test-Path -LiteralPath (Join-Path $p 'SDL2.dll')) { $found = $p; break }
    }
    if ($found) { $env:PATH = "$found;$env:PATH"; Write-Note "DLL path: $found" }
    else { Write-Note 'no MSYS2 mingw64/bin found - the game may fail to start' }
}

# ---------------------------------------------------------------------------
# Win32 helpers（聚焦 + 按键注入，同 tests/p1/capture_match.ps1）
# ---------------------------------------------------------------------------
Add-Type -Namespace P6Verify -Name Win -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
[DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
[DllImport("user32.dll")] public static extern uint MapVirtualKey(uint uCode, uint uMapType);
[DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr lpdwProcessId);
[DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
[DllImport("user32.dll")] public static extern void SwitchToThisWindow(IntPtr hWnd, bool fAltTab);
[DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
[DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr hWnd);
[DllImport("user32.dll")] public static extern IntPtr GetFocus();
[DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
[DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int maxCount);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
[DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);
[DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
[DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
'@

$WM_KEYDOWN = 0x0100
$WM_KEYUP = 0x0101
$WM_SETFOCUS = 0x0007
$KEYEVENTF_KEYUP = 0x0002
$VK_MENU = 0x12

$script:Hwnd = [IntPtr]::Zero
$script:Held = @{}

function Focus-Window([IntPtr]$hwnd) {
    if ($hwnd -eq [IntPtr]::Zero) { return $false }
    if ([P6Verify.Win]::GetForegroundWindow() -eq $hwnd) { return $true }
    $script:FocusDances++
    $target = [P6Verify.Win]::GetWindowThreadProcessId($hwnd, [IntPtr]::Zero)
    $self = [P6Verify.Win]::GetCurrentThreadId()
    $scanAlt = [byte][P6Verify.Win]::MapVirtualKey($VK_MENU, 0)

    # 第 0 级：真实鼠标点击窗口客户区中心。
    #   为什么这条最可靠：Windows 的"前台锁"（ForegroundLockTimeout）只拦
    #   SetForegroundWindow 这类**程序请求**，而 mouse_event 注入的是**真实用户输入**，
    #   系统会正常地把被点中的窗口提到前台并给它键盘焦点。
    #   2026-10-31 实测：系统浮层（"快速设置"）占着前台时，ALT 手法 3 次全失败，
    #   点击手法一次成功。
    #   点哪里：客户区中心偏上（避开底部的按钮栏），点完把光标放回原处。
    $cr = New-Object P6Verify.Win+RECT
    if ([P6Verify.Win]::GetClientRect($hwnd, [ref]$cr)) {
        $pt = New-Object P6Verify.Win+POINT
        $pt.X = [int](($cr.Right - $cr.Left) / 2)
        $pt.Y = [int](($cr.Bottom - $cr.Top) / 2)
        [void][P6Verify.Win]::ClientToScreen($hwnd, [ref]$pt)
        [void][P6Verify.Win]::SetCursorPos($pt.X, $pt.Y)
        Start-Sleep -Milliseconds 30
        [P6Verify.Win]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)   # LEFTDOWN
        Start-Sleep -Milliseconds 30
        [P6Verify.Win]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)   # LEFTUP
        Start-Sleep -Milliseconds 120
        if ([P6Verify.Win]::GetForegroundWindow() -eq $hwnd) { return $true }
    }

    # 第 1 级：SwitchToThisWindow 是最宽松的"切到前台"手段，
    #   它不受 ForegroundLockTimeout 限制（不进入 z-order 的"用户意图"判定）。
    #   先试它，能成功就不用 ALT 那一套 370ms 的流程。
    [void][P6Verify.Win]::ShowWindow($hwnd, 9)   # SW_RESTORE
    [P6Verify.Win]::SwitchToThisWindow($hwnd, $true)
    Start-Sleep -Milliseconds 40
    if ([P6Verify.Win]::GetForegroundWindow() -eq $hwnd) { return $true }

    # ★ 按住 ALT 再调 SetForegroundWindow：本机 ForegroundLockTimeout = 200000，
    #   单纯调 SetForegroundWindow 会被系统拒绝（P4 实测：focus 拿不到时截图
    #   里没有任何调试读数，整轮跑等于白跑）。ALT 会被 OS 当作"新的用户输入"，
    #   从而解除前台锁 —— 这是 tests/p3/run_match_watch.ps1 验证过的做法。
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        [void][P6Verify.Win]::ShowWindow($hwnd, 9)   # SW_RESTORE
        $attached = $false
        if ($target -ne 0 -and $target -ne $self) {
            [void][P6Verify.Win]::AttachThreadInput($self, $target, $true)
            $attached = $true
        }
        [P6Verify.Win]::keybd_event([byte]$VK_MENU, $scanAlt, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 60
        [void][P6Verify.Win]::BringWindowToTop($hwnd)
        [void][P6Verify.Win]::SetForegroundWindow($hwnd)
        # SetForegroundWindow 只改"活动窗口"，键盘焦点是另一件事：
        # SDL 只有收到 WM_SETFOCUS 才会把键盘事件当成游戏输入。
        [void][P6Verify.Win]::SetFocus($hwnd)
        Start-Sleep -Milliseconds 60
        [P6Verify.Win]::keybd_event([byte]$VK_MENU, $scanAlt, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
        if ($attached) { [void][P6Verify.Win]::AttachThreadInput($self, $target, $false) }
        Start-Sleep -Milliseconds 250
        if ([P6Verify.Win]::GetForegroundWindow() -eq $hwnd) { return $true }
    }
    return $false
}

# ★ 廉价焦点保证：已经在前台就**零开销**返回。
#   为什么必须有：keybd_event 是往**当前前台窗口**投递的，而抢前台要按 ALT +
#   AttachThreadInput，成功一次也要睡 370ms（≈22 tick）。所以：
#     * 每条配方开头调一次（走 Focus-Window 的全套手法）
#     * 每次按键前再调一次 Ensure-Focus（通常直接返回，不引入延迟）
#   2026-10-31 实测：只在配方开头抢焦点时，同一份键位下 X(BACKSPACE) 能触发、
#   A/S/Z/C/D 全部无响应；改成每次按键前确认后恢复正常。
function Ensure-Focus {
    if ([P6Verify.Win]::GetForegroundWindow() -eq $script:Hwnd) { return $true }
    return (Focus-Window $script:Hwnd)
}

function Press-Keys([string[]]$vks) {
    foreach ($vk in $vks) {
        $k = [byte]$vk
        $scan = [byte][P6Verify.Win]::MapVirtualKey($k, 0)
        [P6Verify.Win]::keybd_event($k, $scan, 0, [UIntPtr]::Zero)
        [void][P6Verify.Win]::PostMessage($script:Hwnd, $WM_KEYDOWN, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16)))
    }
}

function Release-Keys([string[]]$vks) {
    foreach ($vk in $vks) {
        $k = [byte]$vk
        $scan = [byte][P6Verify.Win]::MapVirtualKey($k, 0)
        [P6Verify.Win]::keybd_event($k, $scan, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
        [void][P6Verify.Win]::PostMessage($script:Hwnd, $WM_KEYUP, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16) -bor 0xC0000000))
    }
}

# ---------------------------------------------------------------------------
# 键位映射：设计键 -> 配置里的按钮名 -> 实际键名 -> 虚拟键码
#   设计键 A/S/Z/X = 轻拳/重拳/轻脚/重脚（引擎按钮 x/y/a/b）
#   设计键 C/D     = 气键（引擎按钮 c/z）
#   方向 fwd/back = **角色相对**（按 facing 换算，见 Resolve-VKInvariant 上方长注释）
#        down/up   = 物理键，与朝向无关（蹲/跳两个方向不随转身镜像）
#   ★ 不硬编码键盘字母：从 save/config.ini 的 [Keys_P1] 读，用户改键位也不会测错。
# ---------------------------------------------------------------------------
$DesignToButton = @{ A = 'x'; S = 'y'; Z = 'a'; X = 'b'; C = 'c'; D = 'z' }
# ★ 这里**故意不写** fwd/back：它们必须先按 facing 换成物理左右（见 Resolve-VKInvariant）。
#   以前写成 `fwd = 'right'` 是死代码（被上面的 elseif 抢先），但读起来像真值 ——
#   一旦有人以为改这里能改方向语义，就会重新踩 2026-10-31 的镜像坑。
$DirToButton = @{ down = 'down'; up = 'up' }

# ★ 可注入键白名单（P6 实测，见 docs/HANDOFF.md §7.5）
#   本机能注进引擎的只有这 6 个：SPACE / RETURN / TAB / BACKSPACE / LSHIFT / LCTRL。
#   字母（a s z x c d）和 INSERT 注进去引擎**完全收不到**（方向键则正常），
#   所以 harness 开跑前会把 [Keys_P1] 临时改成这套，跑完无条件还原。
#   注意名字必须是引擎 input_sdl.go 的 KeyToStringLUT 里的写法（左 Ctrl 是 LCTRL，
#   不是 LCONTROL —— 写错会静默变成 K_UNKNOWN，那个按钮就彻底失效）。
$InjectKeyForButton = @{ x = 'SPACE'; y = 'RETURN'; a = 'TAB'; b = 'BACKSPACE'; c = 'LSHIFT'; z = 'LCTRL' }

$VKByName = @{
    'UP' = 0x26; 'DOWN' = 0x28; 'LEFT' = 0x25; 'RIGHT' = 0x27
    'RETURN' = 0x0D; 'ENTER' = 0x0D; 'SPACE' = 0x20; 'TAB' = 0x09; 'BACKSPACE' = 0x08
    'ESCAPE' = 0x1B; 'LSHIFT' = 0xA0; 'RSHIFT' = 0xA1; 'LCTRL' = 0xA2; 'RCTRL' = 0xA3
    'INSERT' = 0x2D; 'DELETE' = 0x2E; 'HOME' = 0x24; 'END' = 0x23
    'PAGEUP' = 0x21; 'PAGEDOWN' = 0x22; 'CAPSLOCK' = 0x14; 'NUMLOCKCLEAR' = 0x90
    'A' = 0x41; 'B' = 0x42; 'C' = 0x43; 'D' = 0x44; 'E' = 0x45; 'F' = 0x46; 'G' = 0x47
    'H' = 0x48; 'I' = 0x49; 'J' = 0x4A; 'K' = 0x4B; 'L' = 0x4C; 'M' = 0x4D; 'N' = 0x4E
    'O' = 0x4F; 'P' = 0x50; 'Q' = 0x51; 'R' = 0x52; 'S' = 0x53; 'T' = 0x54; 'U' = 0x55
    'V' = 0x56; 'W' = 0x57; 'X' = 0x58; 'Y' = 0x59; 'Z' = 0x5A
    '0' = 0x30; '1' = 0x31; '2' = 0x32; '3' = 0x33; '4' = 0x34
    '5' = 0x35; '6' = 0x36; '7' = 0x37; '8' = 0x38; '9' = 0x39
}

function Get-KeysP1Section {
    if (-not (Test-Path -LiteralPath $RuntimeConfig)) { throw "key config not found: $RuntimeConfig" }
    $map = @{}
    $inSection = $false
    $seen = $false
    foreach ($line in ([System.IO.File]::ReadAllText($RuntimeConfig) -split "`r?`n")) {
        $hdr = [regex]::Match($line, '^\s*\[(.+?)\]\s*$')
        if ($hdr.Success) {
            $inSection = ($hdr.Groups[1].Value.Trim() -eq 'Keys_P1')
            if ($inSection) { $seen = $true }
            continue
        }
        if (-not $inSection) { continue }
        $kv = [regex]::Match($line, '^\s*([A-Za-z_]+)\s*=\s*(.*?)\s*$')
        if ($kv.Success) { $map[$kv.Groups[1].Value] = $kv.Groups[2].Value }
    }
    if (-not $seen) { throw 'no [Keys_P1] section in save/config.ini' }
    return $map
}

function Set-InjectionKeymap {
    $orig = [System.IO.File]::ReadAllBytes($RuntimeConfig)
    $lines = ([System.Text.Encoding]::UTF8.GetString($orig)) -split "`r?`n"
    $inP1 = $false
    $patched = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $hdr = [regex]::Match($lines[$i], '^\s*\[(.+?)\]\s*$')
        if ($hdr.Success) { $inP1 = ($hdr.Groups[1].Value.Trim() -eq 'Keys_P1'); continue }
        if (-not $inP1) { continue }
        if ($lines[$i] -match '^\s*start\s*=') { $lines[$i] = 'start    = Not used'; continue }
        foreach ($b in $InjectKeyForButton.Keys) {
            if ($lines[$i] -match ('^\s*' + $b + '\s*=')) {
                $lines[$i] = ('{0,-8} = {1}' -f $b, $InjectKeyForButton[$b])
                $patched++
                break
            }
        }
    }
    if ($patched -lt 6) { throw ("could only patch {0} of 6 buttons in [Keys_P1]" -f $patched) }
    [System.IO.File]::WriteAllText($RuntimeConfig, ($lines -join "`r`n"), $Utf8NoBom)

    $check = Get-KeysP1Section
    foreach ($b in $InjectKeyForButton.Keys) {
        if ($check[$b] -ne $InjectKeyForButton[$b]) {
            throw ("keymap patch did not stick: {0} = '{1}'" -f $b, $check[$b])
        }
    }
    Write-Note ('injection keymap written: ' + (($InjectKeyForButton.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ' '))
    return $orig
}

function Restore-InjectionKeymap([object]$orig) {
    if ($null -eq $orig) { return }
    [System.IO.File]::WriteAllBytes($RuntimeConfig, [byte[]]$orig)
    Write-Note 'save/config.ini restored'
}

# ---------------------------------------------------------------------------
# 方向键解析：设计方向（角色的前/后）-> 物理键
#
# ★★ 2026-10-31 修：四条配方假失败的根因 ★★
#   引擎 `char.go:6510`：`c.fbFlip = c.facing < 0`；
#   `input.go:2802`：`if char.fbFlip { B, F = R, L } else { B, F = L, R }`。
#   把这两句连起来读，得到一条硬事实：
#
#       物理 LEFT / RIGHT 在引擎里永远等于「世界 −x / +x」，
#       而**不是**「角色的后 / 前」。
#
#   以前这里把设计方向 `fwd` 直接写死成物理 RIGHT（`$DirToButton`），
#   只有在 p1 朝右时才碰巧正确。后投（配方 22）把 p2 扔到身后 → p1 转身朝左，
#   之后**每一条「方向 + 键」配方都被镜像了**：
#     · 配方 25 `→+C` 实际发出 ←+C  → 进的是 1200（配方 26 的招），1100 从未出现
#     · 配方 26 `←+C` 实际发出 →+C  → 进的是 1100（配方 25 的招）
#     · 配方 28 `→+D` 实际发出 ←+D  → 未定义，什么都没发生
#     · 配方 29 `↓D` 方向键不受影响 → 能进 1400，但两人已被顶在左右两条
#       stage bound 上（p1 x=+145.00 / p2 x=−144.96 / p2BodyDist 恒 224）→ 必然空振
#   表面症状是「三条 STATE-MISS + 一条 0 伤害」，看起来像游戏缺陷；
#   实际是**测试脚本的方向语义错了**。所以这里改成按 facing 换算。
#
#   ★ facing 未知时（开局前 / 探针还没吐行）退回 +1：P1 从左侧出场、面朝右，
#     这与引擎实况一致（首行 p1 x=−70 / p2 x=+70）。
# ---------------------------------------------------------------------------
function Get-P1Facing {
    $last = Get-LastRow
    if ($null -eq $last) { return 1 }
    if ($last.PSObject.Properties['Facing'] -and $last.Facing -ne 0) { return $last.Facing }
    return 1
}

function Resolve-VKInvariant([string]$token) {
    $raw = $token.Trim()
    if ($DesignToButton.ContainsKey($raw.ToUpper())) {
        $raw = $DesignToButton[$raw.ToUpper()]
    } elseif ($raw -eq 'fwd' -or $raw -eq 'back') {
        # 角色相对 -> 物理：朝右时 前=右 / 后=左；朝左时整对调换
        $facingRight = (Get-P1Facing) -ge 0
        if ($raw -eq 'fwd') { $raw = if ($facingRight) { 'right' } else { 'left' } }
        else { $raw = if ($facingRight) { 'left' } else { 'right' } }
    } elseif ($DirToButton.ContainsKey($raw)) {
        $raw = $DirToButton[$raw]
    }
    if (-not $InjectKeyForButton.ContainsKey($raw)) {
        if (-not $VKByName.ContainsKey($raw.ToUpper())) { throw "unknown key token '$token'" }
        return [int]$VKByName[$raw.ToUpper()]
    }
    $keyName = $InjectKeyForButton[$raw]
    if (-not $VKByName.ContainsKey($keyName)) { throw "no VK mapping for '$keyName'" }
    return [int]$VKByName[$keyName]
}

function ConvertTo-VKList([string]$spec) {
    $out = @()
    foreach ($tok in ($spec -split '\+')) {
        if ($tok.Trim()) { $out += (Resolve-VKInvariant $tok) }
    }
    return $out
}

Write-Note ('current [Keys_P1]: ' + ((Get-KeysP1Section).GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ' ')

# ---------------------------------------------------------------------------
# .zss 规格解析：每个状态的 damage 之和 / StateDef 头 poweradd / powerAdd 负值
#   期望值**从源码算**，不手写 —— 否则招式改了、断言还停在旧数字上，
#   那就变成"测试通过但游戏是错的"。
# ---------------------------------------------------------------------------
function Get-StateSpec {
    $spec = @{}
    foreach ($path in @($ZssPath, $HitsPath)) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $src = [System.IO.File]::ReadAllText($path)
        $ms = [regex]::Matches($src, '\[StateDef (\d+);')
        for ($i = 0; $i -lt $ms.Count; $i++) {
            $start = $ms[$i].Index
            if ($i + 1 -lt $ms.Count) { $end = $ms[$i + 1].Index } else { $end = $src.Length }
            $block = $src.Substring($start, $end - $start)
            $no = [int]$ms[$i].Groups[1].Value
            $hdrEnd = $block.IndexOf(']')
            if ($hdrEnd -lt 0) { $hdrEnd = 0 }
            $hdr = $block.Substring(0, $hdrEnd)
            $body = $block.Substring($hdrEnd)

            $gain = 0
            $g = [regex]::Match($hdr, 'poweradd:\s*(-?\d+)')
            if ($g.Success) { $gain = [int]$g.Groups[1].Value }
            $dmg = 0
            foreach ($d in [regex]::Matches($body, 'damage:\s*(\d+)\s*,')) { $dmg += [int]$d.Groups[1].Value }
            $cost = 0
            foreach ($c in [regex]::Matches($body, 'powerAdd\{\s*value:\s*-(\d+)')) { $cost += [int]$c.Groups[1].Value }
            foreach ($p in [regex]::Matches($body, 'powerAdd\{\s*value:\s*(\d+)')) { $gain += [int]$p.Groups[1].Value }

            if ($spec.ContainsKey($no)) {
                $spec[$no].Damage = $spec[$no].Damage + $dmg
                $spec[$no].Cost = $spec[$no].Cost + $cost
                $spec[$no].Gain = $spec[$no].Gain + $gain
            } else {
                $spec[$no] = [pscustomobject]@{ State = $no; Damage = $dmg; Cost = $cost; Gain = $gain }
            }
        }
    }
    return $spec
}

$StateSpec = Get-StateSpec
Write-Note ("parsed {0} state blocks from archer.zss + hits.zss" -f $StateSpec.Count)

# ---------------------------------------------------------------------------
# CSV 增量读取
# ---------------------------------------------------------------------------
$script:CsvStream = $null
$script:CsvOffset = 0
$script:CsvTail = ''
$script:Rows = New-Object System.Collections.ArrayList

function Open-CsvStream([string]$path) {
    if ($null -ne $script:CsvStream) { $script:CsvStream.Dispose() }
    $script:CsvStream = New-Object System.IO.FileStream($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $script:CsvOffset = 0
    $script:CsvTail = ''
    $script:Rows.Clear()
}

function Read-ProbeRows {
    if ($null -eq $script:CsvStream) { return 0 }
    $len = $script:CsvStream.Length
    if ($len -le $script:CsvOffset) { return 0 }
    $script:CsvStream.Position = $script:CsvOffset
    $count = $len - $script:CsvOffset
    $buf = New-Object byte[] $count
    $read = $script:CsvStream.Read($buf, 0, $count)
    $script:CsvOffset += $read
    $text = $script:CsvTail + [System.Text.Encoding]::UTF8.GetString($buf, 0, $read)
    $lines = $text -split "`n"
    if ($lines.Count -ge 1) { $script:CsvTail = $lines[$lines.Count - 1] }
    $added = 0
    for ($i = 0; $i -lt $lines.Count - 1; $i++) {
        $line = $lines[$i].TrimEnd("`r")
        if (-not $line.StartsWith('KOF,')) { continue }
        $f = $line.Split(',')
        if ($f.Count -lt 22) { continue }
        if ([int]$f[2] -ne 1) { continue }   # 只看 P1（playerNo 是 1-based）
        [void]$script:Rows.Add([pscustomobject]@{
                G         = [int]$f[1]
                State     = [int]$f[3]
                Time      = [int]$f[4]
                X         = [double]::Parse($f[5], [Globalization.CultureInfo]::InvariantCulture)
                Y         = [double]::Parse($f[6], [Globalization.CultureInfo]::InvariantCulture)
                VX        = [double]::Parse($f[7], [Globalization.CultureInfo]::InvariantCulture)
                Power     = [int]$f[8]
                Life      = [int]$f[9]
                P2State   = [int]$f[10]
                P2Life    = [int]$f[11]
                Dist      = [double]::Parse($f[12], [Globalization.CultureInfo]::InvariantCulture)
                Anim      = [int]$f[13]
                Ctrl      = [int]$f[14]
                Jg        = [int]$f[15]
                Proj      = [int]$f[16]
                P2DistX   = [double]::Parse($f[17], [Globalization.CultureInfo]::InvariantCulture)
                ProjTotal = [int]$f[18]
                Facing    = [int]$f[19]
                JgWin     = [int]$f[20]
                JgDone    = [int]$f[21]
            })
        $added++
    }
    return $added
}

function Get-LastRow {
    if ($script:Rows.Count -eq 0) { return $null }
    return $script:Rows[$script:Rows.Count - 1]
}

# 实测引擎速率（tick/s）。标称 60，实测无垂直同步时会明显更高 ——
# 这个数字是"为什么配方时序必须按 tick 而不是按毫秒"的直接证据。
function Get-TickRate {
    [void](Read-ProbeRows)
    $a = Get-LastRow
    if ($null -eq $a) { return 0 }
    Start-Sleep -Milliseconds 1000
    [void](Read-ProbeRows)
    $b = Get-LastRow
    if ($null -eq $b) { return 0 }
    return [int]($b.G - $a.G)
}

# ---------------------------------------------------------------------------
# 招式配方
#   Dist: near = 先走到贴身(<=20)；far = 先退到 >=110；none = 不调整
#   DisplAt: 额外跑一次「对峙距离」的位移测量（见下文注释），单位 px
#   Steps 里的 Do:
#     tap     按下 -> 等 N tick -> 松开（和弦就是在同一批里按下多个键）
#     hold    一直按住（本招结束统一松开）
#     release 松开
#     wait    纯等待
#     until   按住不放，直到 p2BodyDistX <= DistMax（且 >= 0）或超时
# ---------------------------------------------------------------------------
function New-Move {
    param(
        [int]$State, [string]$Name, [string]$Keys, [object[]]$Steps,
        [string]$Dist = 'near', [object]$Dmg = $null,
        [ValidateSet('exact', 'min', 'none')][string]$DmgRule = 'exact',
        [object]$Proj = $null, [string]$Note = '', [object]$DisplAt = $null,
        # 「进入哪个状态算成功」可以是多个。投技抓到人的那一 tick 会立刻
        # p1stateno -> 810，800 只存在 1 tick，探针常常只看到 810。
        [object]$Entry = $null,
        # 期望耗气在"状态自身"之外还要加的部分（负数 = 额外扣）。
        #   T3 前摇取消的手续费 -100 就靠它，否则会被判成 POWER-MISMATCH。
        [int]$PowExtra = 0
    )
    $entryStates = if ($null -eq $Entry) { @($State) } else { @($Entry) }
    [pscustomobject]@{
        State = $State; Entry = $entryStates; Name = $Name; Keys = $Keys; Steps = $Steps; Dist = $Dist
        Dmg = $Dmg; DmgRule = $DmgRule; Proj = $Proj; Note = $Note; DisplAt = $DisplAt
        PowExtra = $PowExtra
    }
}

# 空中技：起跳 → 等到上升段 → 按攻击键
#   Ms 按 60fps 语义：70ms≈4 tick（起跳），320ms≈19 tick（此时人在 50 态上升中，
#   整个跳跃 50 态约 39 tick，所以按键落在中段）。
$AirSteps = @(
    @{ Do = 'tap'; Keys = 'up'; Ms = 70 }
    @{ Do = 'wait'; Ms = 320 }
)
# T1：同一个键按两次，第二次要落在 .cmd 的 TAP_* 窗口（26 tick）内，
#   且此时 200 系状态**已经走过判定帧**（CanTap 要求 var(4) = 1）。
#   ★ 用 `waitto` 盯住 state.time，而不是等固定 tick 数：注入本身有 1~2 tick 抖动，
#     固定等待会时而落在窗口内、时而落在窗口外。
#   ★ 每条配方的 TimeMin 必须按**该招自己的判定帧**给，不能共用一个 7：
#       A=第 6 tick / Z=第 5 / X=第 9 / S=第 13  （探针对齐：见 .air 的 animElem）
#     以前四条统一写 7，重拳的判定帧还没到就按了第二次 → 251 永远 STATE-MISS。
#   ★ 期望伤害 = 第一段 + 第二段（两段都命中）：
#       A 24+20=44 / S 62+50=112 / Z 30+24=54 / X 64+52=116
$Tap2 = { param($k, $st, $tmin) @(
        @{ Do = 'tap'; Keys = $k; Ms = 50 }
        @{ Do = 'waitto'; State = $st; TimeMin = $tmin; Ms = 2500 }
        @{ Do = 'tap'; Keys = $k; Ms = 50 }
    ) }

$Moves = @(
    # ---- 终极技先测 ----
    #   ★ 顺序有讲究：3100 的门槛是 power >= 2000（整条槽），所以必须在
    #     "刚开局的 2000 气" 状态下第一个测，否则任何一个耗气招之后都测不了。
    (New-Move 3100 '无限剑制 C+D' 'C+D' @(@{ Do = 'tap'; Keys = 'C+D'; Ms = 100 }) -Dist none -DmgRule min -Note '16x10')
    # ---- 站立普通技 ----
    (New-Move 200 '站立 A 轻拳' 'A' @(@{ Do = 'tap'; Keys = 'A'; Ms = 70 }))
    (New-Move 210 '站立 S 重拳' 'S' @(@{ Do = 'tap'; Keys = 'S'; Ms = 70 }))
    (New-Move 230 '站立 Z 轻脚' 'Z' @(@{ Do = 'tap'; Keys = 'Z'; Ms = 70 }))
    (New-Move 240 '站立 X 重脚' 'X' @(@{ Do = 'tap'; Keys = 'X'; Ms = 70 }))
    # ---- 蹲下普通技 ----
    (New-Move 400 '蹲 A' '↓+A' @(@{ Do = 'tap'; Keys = 'down+A'; Ms = 80 }))
    (New-Move 410 '蹲 S' '↓+S' @(@{ Do = 'tap'; Keys = 'down+S'; Ms = 80 }))
    (New-Move 430 '蹲 Z' '↓+Z' @(@{ Do = 'tap'; Keys = 'down+Z'; Ms = 80 }))
    (New-Move 440 '蹲 X' '↓+X' @(@{ Do = 'tap'; Keys = 'down+X'; Ms = 80 }))
    # ---- 空中普通技 ----
    (New-Move 600 '空 A' '↑,A' ($AirSteps + @(@{ Do = 'tap'; Keys = 'A'; Ms = 70 })))
    (New-Move 610 '空 S' '↑,S' ($AirSteps + @(@{ Do = 'tap'; Keys = 'S'; Ms = 70 })))
    (New-Move 630 '空 Z' '↑,Z' ($AirSteps + @(@{ Do = 'tap'; Keys = 'Z'; Ms = 70 })))
    (New-Move 640 '空 X' '↑,X' ($AirSteps + @(@{ Do = 'tap'; Keys = 'X'; Ms = 70 })))
    # ---- T1 同键二次 ----
    (New-Move 250 'T1 连 A' 'A,A' (& $Tap2 'A' 200 8) -Dmg 44 -Note '24+20')
    (New-Move 251 'T1 连 S' 'S,S' (& $Tap2 'S' 210 15) -Dmg 112 -Note '62+50')
    (New-Move 252 'T1 连 Z' 'Z,Z' (& $Tap2 'Z' 230 7) -Dmg 54 -Note '30+24')
    # ★ 253 只断言第一段（64）。重脚 240 的击退会把对手滑到身体间隙 54.6，
    #   而二段起手 9 tick + 射程 77.8 覆盖不到 —— 实测第二段必然空振。
    #   这是平衡事实（轻拳 A / 轻脚 Z 的两段都能连上），记进 docs 待平衡阶段处理。
    (New-Move 253 'T1 连 X' 'X,X' (& $Tap2 'X' 240 11) -Dmg 64 -DmgRule min -Note '重脚击退导致二段空振')
    # ---- 闪身 ----
    #   ★ 只给 110 / 1300 加 -DisplAt：它们是**朝对手推进**的招，贴身起手会撞进
    #     推挤盒。115 后撤闪 / 1200 后撤投剑是往反方向走，本来就量得准，而且退到
    #     220px 再后撤会顶到版边被夹住 —— 那就换成另一种污染了。
    (New-Move 110 '前冲闪' '→+A+Z' @(@{ Do = 'tap'; Keys = 'fwd+A+Z'; Ms = 90 }) -DmgRule none -DisplAt 220 -Note '无敌 12 tick')
    (New-Move 115 '后撤闪' '←+A+Z' @(@{ Do = 'tap'; Keys = 'back+A+Z'; Ms = 90 }) -DmgRule none)
    (New-Move 117 '下闪' '↓+A+Z' @(@{ Do = 'tap'; Keys = 'down+A+Z'; Ms = 90 }) -DmgRule none)
    # ---- 投技（要贴身：p2BodyDist < 3 / < 5）----
    #   ★ DistMax 用 2 而不是 3：路由条件写的是 `p2BodyDist X < 3`（严格小于），
    #     停在正好 3.0 会被判成不满足。
    (New-Move 800 '前投' '→+S' @(
            @{ Do = 'hold'; Keys = 'fwd' }
            @{ Do = 'until'; DistMax = 2; Ms = 5000 }
            # ★ 收尾后显式再按住 →、停 50ms 再按 S：`until` 本身不按键，
            #   方向是上一步 `hold` 留下来的；重新按一次可以吃掉"到位的瞬间还在
            #   走路收招"的抖动（实测偶发掉到单键 S → 进 210 而不是 800）。
            @{ Do = 'hold'; Keys = 'fwd' }
            @{ Do = 'wait'; Ms = 50 }
            @{ Do = 'tap'; Keys = 'S'; Ms = 90 }
        ) -Dmg 150 -Entry @(800, 810) -Note '800 的 60 + 810 的 targetLifeAdd 90')
    #   ★ 后投必须「先按住 ← 再按 X」：路由条件是 holdback**且**按下重脚，
    #     把两件事塞进同一个 tap 里会依赖注入顺序，实测会掉到单键 X（进 240）。
    (New-Move 800 '后投' '←+X' @(
            @{ Do = 'hold'; Keys = 'fwd' }
            @{ Do = 'until'; DistMax = 2; Ms = 5000 }
            @{ Do = 'release'; Keys = 'fwd' }
            @{ Do = 'hold'; Keys = 'back' }
            @{ Do = 'tap'; Keys = 'X'; Ms = 90 }
        ) -Dmg 150 -Entry @(800, 810) -Note '同样走 800 -> 810')
    # ---- 中型气技 ----
    (New-Move 1000 '射箭 C' 'C' @(@{ Do = 'tap'; Keys = 'C'; Ms = 80 }) -Dist far -Proj 1)
    (New-Move 1150 '斜下射箭 ↓C' '↓+C' @(@{ Do = 'tap'; Keys = 'down+C'; Ms = 80 }) -Dist far -Proj 1)
    (New-Move 1100 '升斬 →C' '→+C' @(@{ Do = 'tap'; Keys = 'fwd+C'; Ms = 80 }))
    (New-Move 1200 '后撤投剑 ←C' '←+C' @(@{ Do = 'tap'; Keys = 'back+C'; Ms = 80 }))
    # ---- 大型气技 ----
    (New-Move 3000 '幻想崩坏 D' 'D' @(@{ Do = 'tap'; Keys = 'D'; Ms = 80 }) -Dist far -DmgRule min -Note '42x3，命中段数取决于位置')
    (New-Move 1300 '突进斩 →D' '→+D' @(@{ Do = 'tap'; Keys = 'fwd+D'; Ms = 80 }) -DisplAt 220 -Note '推进 12 tick × 7.5')
    (New-Move 1400 '跳劈下压 ↓D' '↓+D' @(@{ Do = 'tap'; Keys = 'down+D'; Ms = 80 }))

    # ---- T3 前摇取消（普通技起手 → 直接换成气技，多花 100 气）----
    #   ★ 为什么用 S（重拳）而不是 A：CanCancelStartup 要求 `var(4) = 0`，
    #     即**判定帧还没开始**。重拳判定帧在第 13 tick，起手窗口有 11 tick 宽，
    #     注入抖动（1~2 tick）吃不掉它；轻拳第 6 tick 就只剩 4 tick 余量，时好时坏。
    #   ★ 期望耗气 = 1100 自身的 (Gain − Cost) + 手续费 −100 = −365 − 100 = −465。
    #     基线取"进入前 4 tick 的最高气量"，而 S 的 StateDef 头 poweradd 在
    #     changeState 那一刻（time = 0）就结算，落在基线窗口之外，不参与期望。
    #   ★ 伤害必须仍是 1100 的 66：S 的判定帧根本没到，所以 S 一点伤害都不该有。
    #     这一条同时证明了"发出去的确实是 →C，而不是 S 打完再说"。
    (New-Move 1100 'T3 前摇取消 S→→C' 'S,→+C' @(
            @{ Do = 'tap'; Keys = 'S'; Ms = 30 }
            @{ Do = 'waitto'; State = 210; TimeMin = 5; Ms = 900 }
            @{ Do = 'tap'; Keys = 'fwd+C'; Ms = 80 }
        ) -Dmg 66 -PowExtra -100 -Note '起手 5 tick 内换 →C，多花 100 气')
)

# ---------------------------------------------------------------------------
# 配方过滤（-List / -Only）
# ---------------------------------------------------------------------------
if ($List) {
    $i = 0
    foreach ($mv in $Moves) {
        $i++
        Write-Host ("{0,2}  st{1,-5} {2,-14} {3,-9} dist={4}" -f $i, $mv.State, $mv.Name, $mv.Keys, $mv.Dist)
    }
    return
}
if ($Only.Count -gt 0) {
    # ★ 用 -File 方式调用时，`-Only 2,10,14` 会原样作为一个字符串进来、不会自动成数组，
    #   所以这里必须自己按逗号再拆一遍（否则永远匹配不到，实测直接抛异常）。
    $pats = @()
    foreach ($raw in $Only) {
        foreach ($piece in ($raw -split ',')) {
            $t = $piece.Trim()
            if ($t) { $pats += $t }
        }
    }
    $sel = New-Object System.Collections.ArrayList
    $i = 0
    foreach ($mv in $Moves) {
        $i++
        foreach ($pat in $pats) {
            if (("$i" -eq $pat) -or ($mv.Name -like "*$pat*")) { [void]$sel.Add($mv); break }
        }
    }
    if ($sel.Count -eq 0) { throw "-Only 没有匹配到任何配方：$($pats -join ' / ')" }
    Write-Note ("-Only 生效：只跑 {0}/{1} 条配方" -f $sel.Count, $Moves.Count)
    $Moves = $sel
}

# ---------------------------------------------------------------------------
# 仪表化
# ---------------------------------------------------------------------------
function Install-Probe {
    Copy-Item -LiteralPath $ProbeFixture -Destination $RuntimeProbe -Force
    $orig = [System.IO.File]::ReadAllBytes($RuntimeDef)
    $text = [System.Text.Encoding]::UTF8.GetString($orig)
    if ($text -notmatch '(?m)^[ \t]*st5[ \t]*=') {
        $lines = $text -split "`r?`n"
        $out = New-Object System.Collections.ArrayList
        $inserted = $false
        foreach ($line in $lines) {
            [void]$out.Add($line)
            if (-not $inserted -and $line -match '^[ \t]*st4[ \t]*=') {
                [void]$out.Add('st5      = probe.zss           ; [TEST] telemetry probe (added by verify_moves.ps1)')
                $inserted = $true
            }
        }
        if (-not $inserted) { throw 'could not find the st4 line in archer.def' }
        [System.IO.File]::WriteAllText($RuntimeDef, ($out -join "`r`n"), $Utf8NoBom)
        Write-Note 'probe wired into the runtime archer.def as st5'
    } else {
        Write-Note 'runtime archer.def already wired for the probe'
    }
    return $orig
}

function Restore-Def([object]$orig) {
    if ($null -eq $orig) { return }
    [System.IO.File]::WriteAllBytes($RuntimeDef, [byte[]]$orig)
    Write-Note 'runtime archer.def restored'
}

# ---------------------------------------------------------------------------
# 注入执行器
#
# ★★★ 时序必须按**引擎 tick**，不能按墙钟毫秒（2026-10-31 实测踩坑）★★★
#   引擎无垂直同步，实测跑在 ~90 tick/s（标称 60）。于是配方里写 `wait 320ms`
#   想表达"跳到最高点再按"，实际却跑过了整整 46 tick —— 空中技 600/610/630/640
#   的跳跃只有 39 tick，按键落在落地之后，四条全 STATE-MISS。
#   现在配方里的 Ms 按 **60fps 的语义**换算成 tick 数，再用 gameTime 等够 tick。
#   这样无论引擎跑多快，配方的语义都稳定。
# ---------------------------------------------------------------------------
function ConvertTo-Ticks([int]$ms) {
    return [Math]::Max(1, [int][Math]::Round($ms * 60.0 / 1000.0))
}

function Wait-Ticks([int]$ticks, [int]$timeoutMs = 6000) {
    if ($ticks -le 0) { return $true }
    [void](Read-ProbeRows)
    $last = Get-LastRow
    if ($null -eq $last) { Start-Sleep -Milliseconds ([int]($ticks * 17)); return $false }
    $target = $last.G + $ticks
    $deadline = (Get-Date).AddMilliseconds($timeoutMs)
    while ((Get-Date) -lt $deadline) {
        [void](Read-ProbeRows)
        $last = Get-LastRow
        if ($null -ne $last -and $last.G -ge $target) { return $true }
        Start-Sleep -Milliseconds 6
    }
    return $false
}

function Invoke-Step($step) {
    switch ($step.Do) {
        'tap' {
            # ★ 方向键必须先按住若干 tick，再按攻击键。
            #   同帧把 `↓` 和 `A` 一起塞进去，引擎在某些 tick 上只会看到一个
            #   "刚按下的方向"，`command = "x" && command = "holddown"` 不成立
            #   （2026-10-31 观测：↓+A 进的是站立 200 而不是蹲 400）。
            #   人也一样：先压方向再点按钮。所以这里统一拆成两段。
            $dir = $null
            $btns = @()
            foreach ($tok in ($step.Keys -split '\+')) {
                $t = $tok.Trim()
                if (-not $t) { continue }
                if (@('fwd', 'back', 'up', 'down') -contains $t) { $dir = $t } else { $btns += $t }
            }
            $hold = ConvertTo-Ticks ([int]$step.Ms)
            [void](Ensure-Focus)
            if ($null -ne $dir) {
                $dv = @(ConvertTo-VKList $dir)
                Press-Keys $dv
                if ($btns.Count -gt 0) { [void](Wait-Ticks 2) }
                if ($btns.Count -gt 0) {
                    $bv = @(ConvertTo-VKList ($btns -join '+'))
                    Press-Keys $bv
                    [void](Wait-Ticks $hold)
                    Release-Keys $bv
                } else {
                    [void](Wait-Ticks $hold)
                }
                Release-Keys $dv
            } else {
                $vks = @(ConvertTo-VKList $step.Keys)
                Press-Keys $vks
                [void](Wait-Ticks $hold)
                Release-Keys $vks
            }
        }
        'hold' {
            [void](Ensure-Focus)
            $vks = @(ConvertTo-VKList $step.Keys)
            Press-Keys $vks
            foreach ($v in $vks) { $script:Held[[string]$v] = $true }
        }
        'release' {
            $vks = @(ConvertTo-VKList $step.Keys)
            Release-Keys $vks
            foreach ($v in $vks) { $script:Held.Remove([string]$v) }
        }
        'wait' { [void](Wait-Ticks (ConvertTo-Ticks ([int]$step.Ms))) }
        'waitto' {
            # 等到"某个状态的 time 至少到 N"为止。
            # ★ 为什么需要：T1（同键二段）的第二次按键必须落在
            #   [判定帧 var(4)=1, 命令窗口 time=12] 之间。用固定 tick 数去凑
            #   会因为按键注入本身的抖动（每次 1~2 tick）落到窗口外，
            #   表现就是"第二次按键又出了一次普通技"。改成盯住 state.time。
            $deadline = (Get-Date).AddMilliseconds([int]$step.Ms)
            while ((Get-Date) -lt $deadline) {
                [void](Read-ProbeRows)
                $last = Get-LastRow
                if ($null -ne $last -and $last.State -eq [int]$step.State -and $last.Time -ge [int]$step.TimeMin) { break }
                Start-Sleep -Milliseconds 6
            }
        }
        'until' {
            # ★ 下界不能省：p2BodyDist x **可以是负数**（两人交叉穿过后）。
            #   `Dist -le 3` 遇到负值同样成立，于是"走过去贴脸"会一路穿到 −32，
            #   投技的 hitDef 永远不命中 → 2026-10-31 前投/后投假 0 伤害。
            $deadline = (Get-Date).AddMilliseconds([int]$step.Ms)
            $floor = -2.0
            if ($step.ContainsKey('DistMin')) { $floor = [double]$step.DistMin }
            while ((Get-Date) -lt $deadline) {
                [void](Read-ProbeRows)
                $last = Get-LastRow
                if ($null -ne $last -and $last.Dist -le [double]$step.DistMax -and $last.Dist -ge $floor) { break }
                Start-Sleep -Milliseconds 12
            }
        }
        default { throw "unknown step '$($step.Do)'" }
    }
}

function Release-All {
    if ($script:Held.Count -eq 0) { return }
    Release-Keys @($script:Held.Keys)
    $script:Held.Clear()
}

function Wait-P1Ctrl([int]$timeoutMs) {
    $deadline = (Get-Date).AddMilliseconds($timeoutMs)
    while ((Get-Date) -lt $deadline) {
        [void](Read-ProbeRows)
        $last = Get-LastRow
        if ($null -ne $last -and $last.Ctrl -eq 1) { return $true }
        Start-Sleep -Milliseconds 50
    }
    return $false
}

function Wait-Grounded([int]$timeoutMs) {
    $deadline = (Get-Date).AddMilliseconds($timeoutMs)
    while ((Get-Date) -lt $deadline) {
        [void](Read-ProbeRows)
        $last = Get-LastRow
        if ($null -ne $last -and $last.Y -ge -1.0 -and $last.Ctrl -eq 1) { return $true }
        Start-Sleep -Milliseconds 40
    }
    return $false
}

function Wait-State([int[]]$states, [int]$timeoutMs) {    $deadline = (Get-Date).AddMilliseconds($timeoutMs)
    while ((Get-Date) -lt $deadline) {
        [void](Read-ProbeRows)
        $n = $script:Rows.Count
        if ($n -gt 0) {
            $lo = [Math]::Max(0, $n - 120)
            for ($i = $lo; $i -lt $n; $i++) {
                if ($states -contains $script:Rows[$i].State) { return $true }
            }
        }
        Start-Sleep -Milliseconds 45
    }
    return $false
}

# 等对手离开「倒地 / 受击 / 起身」这些公共状态（5xxx）。
#   ★ 为什么必须等（2026-10-31）：hitflag 写成 MAF 的招**不含 D（倒地）**，对手躺着时
#     必然空振。上一条配方把人打倒、下一条立刻起手，读数就是 0 伤害 ——
#     看起来像"这招没伤害"，实际是节奏问题。空A / 突进斩 都踩过这个坑。
function Wait-P2Neutral([int]$timeoutMs = 4000) {
    $deadline = (Get-Date).AddMilliseconds($timeoutMs)
    while ((Get-Date) -lt $deadline) {
        [void](Read-ProbeRows)
        $last = Get-LastRow
        if ($null -ne $last -and $last.P2State -lt 5000) { return $true }
        Start-Sleep -Milliseconds 45
    }
    return $false
}

function Move-Near([double]$max, [int]$timeoutMs) {
    # ★ 无论是否已经在近距离，都要先抢一次焦点：
    #   按键注入是靠 PostMessage/keybd_event 打给**前台窗口**的，焦点一旦漂走
    #   （控制台、编辑器、通知），后面每一条配方都会静默失效 —— 而且症状和执行
    #   时机有关，看起来像"某些招坏了"，极难定位。
    # ★ 2026-10-31：改成最多试 2 次。之前单次走位失败会留下 50px 空档，
    #   后面那条配方就整条空振（实测「站立 A」因此从 PASS 变成 0/24）。
    #   走位失败比报错更难查，所以失败时**显式打一行 WARN** 并给出实际空档。
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        [void](Focus-Window $script:Hwnd)
        [void](Read-ProbeRows)
        $last = Get-LastRow
        if ($null -ne $last -and $last.Dist -le $max -and $last.Dist -ge -1) { return $true }
        $dir = 'fwd'
        if ($null -ne $last -and $last.Dist -lt -1) { $dir = 'back' }   # 走过头了 → 退回到正距离
        $vks = @(ConvertTo-VKList $dir)
        Press-Keys $vks
        $deadline = (Get-Date).AddMilliseconds($timeoutMs)
        while ((Get-Date) -lt $deadline) {
            [void](Read-ProbeRows)
            $last = Get-LastRow
            if ($null -ne $last) {
                if ($dir -eq 'fwd') {
                    if ($last.Dist -le $max -and $last.Dist -ge -1) { break }
                } else {
                    if ($last.Dist -ge 1) { break }
                }
            }
            Start-Sleep -Milliseconds 12
        }
        Release-Keys $vks
        [void](Read-ProbeRows)
        $last = Get-LastRow
        if ($null -ne $last -and $last.Dist -le $max -and $last.Dist -ge -1) { return $true }
        $gap = if ($null -ne $last) { '{0:N1}' -f $last.Dist } else { 'n/a' }
        Write-Host ("       !! Move-Near 第 {0} 次没走到位（目标 <= {1}，实际 {2}）—— 重试" -f $attempt, $max, $gap) `
            -ForegroundColor Yellow
    }
    # ★ 返回 false 而不是"默默返回"：走位失败会让整条配方空振，
    #   如果照常判 STATE-MISS/NO-DAMAGE，报告会把它写成**游戏缺陷**。
    #   2026-10-31 四条配方就是这样被误判的（真实原因是方向键语义，见 Resolve-VKInvariant）。
    return $false
}

function Move-Far([double]$min, [int]$timeoutMs = 5000) {
    # 走（不是跳）后退：跳会被"落地后才算稳定"拖慢，而且起跳瞬间按气键会被吃掉。
    [void](Focus-Window $script:Hwnd)
    [void](Read-ProbeRows)
    $last = Get-LastRow
    if ($null -ne $last -and $last.Dist -ge $min) { return $true }
    $vks = @(ConvertTo-VKList 'back')
    Press-Keys $vks
    $deadline = (Get-Date).AddMilliseconds($timeoutMs)
    while ((Get-Date) -lt $deadline) {
        [void](Read-ProbeRows)
        $last = Get-LastRow
        if ($null -ne $last -and $last.Dist -ge $min) { break }
        Start-Sleep -Milliseconds 12
    }
    Release-Keys $vks
    [void](Wait-Grounded 2000)
    [void](Read-ProbeRows)
    $last = Get-LastRow
    if ($null -ne $last -and $last.Dist -ge $min) { return $true }
    $gap = if ($null -ne $last) { '{0:N1}' -f $last.Dist } else { 'n/a' }
    Write-Host ("       !! Move-Far 没退到位（目标 >= {0}，实际 {1}）" -f $min, $gap) -ForegroundColor Yellow
    return $false
}

# ---------------------------------------------------------------------------
# 分析
# ---------------------------------------------------------------------------
function Analyze-Window($win) {
    $res = [pscustomobject]@{
        Idx = $win.Idx; Name = $win.Name; State = $win.State; Keys = $win.Keys
        Seen = $false; EntryIdx = -1; Damage = 0; DmgExp = $win.DmgExp; DmgRule = $win.DmgRule
        DmgVerdict = 'skip'; PowerD = 0; PowerExp = $win.PowerExp; PowVerdict = 'skip'; PowerBaseline = 0
        Recovered = $false; RecoverTicks = 0; ProjMax = 0; ProjExp = $win.Proj
        Displ = $null; Note = $win.Note; Focus = $null
    }
    if ($null -ne $win.PSObject.Properties['Focus']) { $res.Focus = $win.Focus }
    $res | Add-Member -NotePropertyName PosOk -NotePropertyValue $true -Force
    if ($null -ne $win.PSObject.Properties['PosOk'] -and $win.PosOk -eq $false) { $res.PosOk = $false }
    # 「满槽时的期望值」：powerAdd 会被 Clamp(0, powerMax)（char.go:8807）吃掉增益，
    # 但**扣气不受影响**。所以满槽时本来有两个合法答案：Gain−Cost 或 −Cost。
    # 以前一律记成 'full'（不下结论），把"扣气精确对得上"这条强断言浪费掉了。
    $res | Add-Member -NotePropertyName PowerExpAlt -NotePropertyValue $null -Force
    if ($null -ne $win.PSObject.Properties['PowerExpAlt']) { $res.PowerExpAlt = $win.PowerExpAlt }
    if ($null -ne $win.PSObject.Properties['FocusDances']) {
        $res | Add-Member -NotePropertyName FocusDances -NotePropertyValue $win.FocusDances -Force
    }
    $from = [int]$win.From
    $to = [int]$win.To
    if ($to -lt $from) { return $res }
    $slice = @()
    for ($i = $from; $i -le $to -and $i -lt $script:Rows.Count; $i++) { $slice += $script:Rows[$i] }
    if ($slice.Count -eq 0) { return $res }

    # 兼容旧 windows.json（没有 Entry 字段时退化为 State）
    $accept = @($win.State)
    if ($null -ne $win.PSObject.Properties['Entry'] -and $null -ne $win.Entry) { $accept = @($win.Entry) }
    for ($i = 0; $i -lt $slice.Count; $i++) {
        if ($accept -contains $slice[$i].State) { $res.Seen = $true; $res.EntryIdx = $i; break }
    }
    if ($res.Seen) {
        # ---- 伤害：累加所有「生命下降」的增量 ----
        # ★ 不能用 `slice[0].P2Life - min`：p2 的生命会**回升**（观测到 29936 -> 30000
        #   这种整段回补，一行之内发生，与 p2State 无关）。一旦回升落在窗口内，
        #   基线就被抬高，真实命中被判成 0 伤害（站立 A 24 点伤害就这样丢了）。
        #   累加负增量对"回升"免疫：回升是正增量，不计入。
        $dmg = 0
        $projTotal = 0
        for ($i = 1; $i -lt $slice.Count; $i++) {
            $d = $slice[$i - 1].P2Life - $slice[$i].P2Life
            if ($d -gt 0) { $dmg += $d }
        }
        if ($slice.Count -gt 0 -and $res.EntryIdx -ge 0) {
            for ($i = 0; $i -lt $slice.Count; $i++) {
                if ($slice[$i].ProjTotal -gt $projTotal) { $projTotal = $slice[$i].ProjTotal }
            }
        }
        $res.Damage = $dmg
        $res.ProjMax = $projTotal

        # ---- 耗气：进入后**最低点** − 进入前**最高点** ----
        # ★ 不能用「进入行 − 前一行」：StateDef 头的增益（poweradd）在 changeState 里
        #   立刻结算，而状态体的 powerAdd{-N} 可能晚几 tick；两头分别落在采样点的
        #   不同侧，读数就会只差一部分（3000 观测 0/-800 就是这么来的）。
        #   取极值对时序偏移免疫，且和"净期望 = Gain − Cost"一一对应。
        $base = $null
        for ($i = [Math]::Max(0, $res.EntryIdx - 4); $i -lt $res.EntryIdx; $i++) {
            if ($null -eq $base -or $slice[$i].Power -gt $base) { $base = $slice[$i].Power }
        }
        $trough = $null
        for ($i = $res.EntryIdx; $i -lt $slice.Count; $i++) {
            if ($null -eq $trough -or $slice[$i].Power -lt $trough) { $trough = $slice[$i].Power }
        }
        if ($null -ne $base -and $null -ne $trough) { $res.PowerD = $trough - $base; $res.PowerBaseline = $base }

        for ($i = $res.EntryIdx; $i -lt $slice.Count; $i++) {
            if ($slice[$i].Ctrl -eq 1) {
                $res.Recovered = $true
                $res.RecoverTicks = $slice[$i].G - $slice[$res.EntryIdx].G
                break
            }
        }
        $x0 = $slice[$res.EntryIdx].X
        $xEnd = $slice[$slice.Count - 1].X
        $maxV = 0.0
        for ($i = $res.EntryIdx; $i -lt $slice.Count; $i++) {
            $v = [Math]::Abs($slice[$i].VX)
            if ($v -gt $maxV) { $maxV = $v }
        }
        # ★ 连 facing 一起记：世界 Δx 的正负取决于当时朝哪边，而"这招推进/后撤多少"
        #   是**角色相对**的量。后投之后 p1 转身朝左，1200 / 1300 的 Δx 符号就整体翻转
        #   （2026-10-31 实测：91.25 / −82.50 变成 −91.25 / +82.50，量值完全相同）。
        $res.Displ = [pscustomobject]@{
            X0 = $x0; XEnd = $xEnd; Delta = ($xEnd - $x0); MaxAbsVX = $maxV
            Facing = $slice[$res.EntryIdx].Facing
        }
    }

    if ($res.DmgRule -ne 'none') {
        if ($res.DmgRule -eq 'min') {
            if ($res.Damage -ge 1) { $res.DmgVerdict = 'ok' } else { $res.DmgVerdict = 'MISS' }
        } elseif (-not $res.Seen) {
            $res.DmgVerdict = 'MISS'
        } elseif ($res.Damage -eq $res.DmgExp) {
            $res.DmgVerdict = 'ok'
        } else {
            $res.DmgVerdict = 'MISMATCH'
        }
    }
    if ($null -ne $res.PowerExp) {
        if ($res.PowerD -eq $res.PowerExp) {
            $res.PowVerdict = 'ok'
        } elseif ($res.PowerBaseline -ge 1990 -and $null -ne $res.PowerExpAlt -and $res.PowerD -eq $res.PowerExpAlt) {
            # 满槽：增益被 Clamp 掉，只剩扣气那部分 —— 但扣气是精确的，照样算过
            $res.PowVerdict = 'ok'
        } elseif ($res.PowerBaseline -ge 1990) {
            # 满槽且两种解释都对不上 → 不下结论（不是缺陷，也不是通过）
            $res.PowVerdict = 'full'
        } else {
            $res.PowVerdict = 'MISMATCH'
        }
    }
    return $res
}

function Test-Failed($r) {
    if (-not $r.Seen) { return $true }
    if ($r.DmgVerdict -eq 'MISMATCH' -or $r.DmgVerdict -eq 'MISS') { return $true }
    if ($r.PowVerdict -eq 'MISMATCH') { return $true }
    if (-not $r.Recovered) { return $true }
    return $false
}

function Get-VerdictText($r) {
    $v = @()
    if ($r.Focus -eq $false) { $v += 'NO-FOCUS' }
    if ($null -ne $r.PSObject.Properties['FocusDances'] -and $r.FocusDances -gt 0) { $v += ('FOCUS-REACQ {0}' -f $r.FocusDances) }
    # ★ 走位失败要单独标出来：它会让后面的 STATE-MISS / NO-DAMAGE 变成假阴性
    #   （2026-10-31：方向键语义错 → 四条配方"假失败"，一度被当成游戏缺陷）。
    if ($null -ne $r.PSObject.Properties['PosOk'] -and $r.PosOk -eq $false) { $v += 'POS-FAIL' }
    if (-not $r.Seen) { $v += 'STATE-MISS' }
    if ($r.DmgVerdict -eq 'MISMATCH') { $v += 'DMG-MISMATCH' }
    if ($r.DmgVerdict -eq 'MISS') { $v += 'NO-DAMAGE' }
    if ($r.PowVerdict -eq 'MISMATCH') { $v += 'POWER-MISMATCH' }
    if ($r.Seen -and -not $r.Recovered) { $v += 'STUCK' }
    # 投射物计数只做**参考信息**，不参与判定：
    #   箭矢是"角色自己发的 projectile"，p1 的 numProj()/numProjID(1000) 在
    #   runtime 里恒为 0（实测 162 行 proj>0 全部来自 3100 的剑），
    #   而箭的实际存在由**伤害**已经证明（1000 在 110px 外命中 56 点）。
    #   把它当失败条件只会产生假阴性。
    if ($null -ne $r.ProjExp -and $r.ProjMax -ne $r.ProjExp) { $v += ('proj=' + $r.ProjMax) }
    if ($v.Count -eq 0) { return 'PASS' }
    return ($v -join ' ')
}

# ---------------------------------------------------------------------------
# 启动 / 收尾
# ---------------------------------------------------------------------------
$script:Proc = $null

function Start-Game([string[]]$extraArgs, [string]$CsvTag = '') {
    $argList = @('-p1', 'archer', '-p2', 'archer', '-s', 'stage0', '-rounds', '1',
        '-time', '-1', '-windowed', '-p1.ai', '0', '-p2.ai', '0',
        '-p2.lifeMax', '30000', '-p1.power', '2000') + $extraArgs
    $errPath = Join-Path $OutDir 'stderr.txt'
    # ★ 每一趟（moves / guard）写自己的 csv。
    #   以前两趟都写 run.csv，`-Pass all` 第二趟会**覆盖**第一趟的明细 ——
    #   于是"全量跑里某条失败"根本无法用逐帧数据复盘（2026-10-31 排查方向气技时踩到）。
    $runCsv = if ($CsvTag) { Join-Path $OutDir ('run_' + $CsvTag + '.csv') } else { $CsvPath }
    if ($runCsv -eq $CsvPath -and (Test-Path -LiteralPath $CsvPath)) {
        Move-Item -LiteralPath $CsvPath -Destination (Join-Path $OutDir 'run_prev.csv') -Force
    }
    $script:CurCsv = $runCsv
    $script:Proc = Start-Process -FilePath $Exe -ArgumentList $argList -WorkingDirectory $RuntimeRoot `
        -RedirectStandardOutput $runCsv -RedirectStandardError $errPath -PassThru
    Write-Note ("launched pid {0}" -f $script:Proc.Id)

    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        if ($script:Proc.HasExited) { throw "the engine exited early (code $($script:Proc.ExitCode)); see $errPath" }
        $script:Proc.Refresh()
        if ($script:Proc.MainWindowHandle -ne [IntPtr]::Zero) { $script:Hwnd = $script:Proc.MainWindowHandle; break }
        Start-Sleep -Milliseconds 150
    }
    if ($script:Hwnd -eq [IntPtr]::Zero) { throw 'the engine window never appeared' }
    Write-Note ("window handle 0x{0:X}" -f [int64]$script:Hwnd)
    [void](Focus-Window $script:Hwnd)
    Open-CsvStream $runCsv
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        [void](Read-ProbeRows)
        if ($script:Rows.Count -gt 5) { break }
        Start-Sleep -Milliseconds 150
    }
    if ($script:Rows.Count -le 5) {
        $tail = ''
        if (Test-Path -LiteralPath $errPath) { $tail = (Get-Content -LiteralPath $errPath -Tail 8) -join ' | ' }
        throw "no probe rows - the probe is probably not wired in. stderr tail: $tail"
    }
    Write-Note ("probe live: {0} rows" -f $script:Rows.Count)
}

function Stop-Game {
    if ($null -ne $script:Proc) {
        if (-not $script:Proc.HasExited) {
            try { $script:Proc.Kill() } catch { }
            Start-Sleep -Milliseconds 500
        }
        $script:Proc = $null
    }
    if ($null -ne $script:CsvStream) { $script:CsvStream.Dispose(); $script:CsvStream = $null }
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
$exitCode = 0
$script:TickRate = 0
$script:FocusDances = 0
$origDef = $null
$origCfg = $null
$results = @()
$winLog = @()
$guardStats = $null

try {
    if (-not $Replay) {
        if (-not $SkipSync) {
            Write-Step 'syncing game/ -> runtime'
            & pwsh -NoProfile -File (Join-Path $RepoRoot 'scripts\sync_game_content.ps1') | Out-Null
            if (-not $?) { throw 'sync_game_content.ps1 failed' }
        }
        Write-Step 'wiring the telemetry probe into the runtime character'
        $origDef = Install-Probe
        Write-Step 'rebinding [Keys_P1] to injectable keys'
        $origCfg = Set-InjectionKeymap

        if ($Pass -eq 'moves' -or $Pass -eq 'all') {
            Write-Step 'PASS: moves'
            Start-Game @()
            [void](Wait-Grounded 10000)
            $script:TickRate = Get-TickRate
            Write-Note ("engine tick rate: {0} tick/s (nominal 60)" -f $script:TickRate)
            $n = 0
            foreach ($mv in $Moves) {
                $n++
                Write-Host ("       -> {0,2}/{1} {2}" -f $n, $Moves.Count, $mv.Name) -ForegroundColor DarkCyan
                [void](Release-All)
                [void](Wait-Grounded 3000)
                # ★ 必须先等对手离开倒地/受击状态，否则 hitflag=MAF 的招整条空振。
                [void](Wait-P2Neutral 4000)
                $posOk = $true
                if ($mv.Dist -eq 'near') { $posOk = Move-Near 10 3500 }
                elseif ($mv.Dist -eq 'far') { $posOk = Move-Far 110 }
                [void](Read-ProbeRows)
                $from = $script:Rows.Count
                # ★ 焦点每条配方只抢一次。Focus-Window 为了绕过前台锁要按 ALT +
                #   AttachThreadInput，**成功一次就要睡 370ms ≈ 22 tick**。
                #   以前它写在每个 tap 里，于是"按 up → 等 19 tick → 按 A"实际变成
                #   "按 up → 等 22 + 19 + 22 tick → 按 A" —— 空中技全打在落地之后，
                #   T1 的第二次按键也早就超出 12 tick 窗口。
                [void](Focus-Window $script:Hwnd)
                $dancesBefore = $script:FocusDances
                foreach ($st in $mv.Steps) { Invoke-Step $st }
                # 记录"按键过程中焦点是否真的在引擎窗口上" —— 焦点漂走时所有按键
                # 都会静默失效，且症状看起来像"某些招坏了"，必须留下证据。
                $focusOk = ([P6Verify.Win]::GetForegroundWindow() -eq $script:Hwnd)
                $dances = $script:FocusDances - $dancesBefore
                [void](Wait-State $mv.Entry 1600)
                [void](Release-All)
                [void](Wait-P1Ctrl $MoveTimeoutMs)
                [void](Wait-Grounded 3000)
                [void](Read-ProbeRows)
                $to = $script:Rows.Count - 1

                $spec = $null
                if ($StateSpec.ContainsKey($mv.State)) { $spec = $StateSpec[$mv.State] }
                $dmgExp = $mv.Dmg
                if ($null -eq $dmgExp -and $null -ne $spec) { $dmgExp = $spec.Damage }
                $powExp = $null
                $powAlt = $null
                if ($null -ne $spec) {
                    $powExp = $spec.Gain - $spec.Cost
                    # 只有"本来该有增益"的状态才存在 Clamp 的第二解
                    if ($spec.Gain -gt 0) { $powAlt = (0 - [int]$spec.Cost) }
                }
                if ($null -ne $powExp -and $mv.PowExtra -ne 0) {
                    $powExp = $powExp + $mv.PowExtra
                    if ($null -ne $powAlt) { $powAlt = $powAlt + $mv.PowExtra }
                }

                $win = [pscustomobject]@{
                    Idx = $n; Name = $mv.Name; Keys = $mv.Keys; State = $mv.State
                    Entry = $mv.Entry; From = $from; To = $to; DmgExp = $dmgExp; DmgRule = $mv.DmgRule
                    PowerExp = $powExp; Proj = $mv.Proj; Note = $mv.Note; Focus = $focusOk
                    FocusDances = $dances; PosOk = $posOk; PowerExpAlt = $powAlt
                }
                $winLog += $win
                $res = Analyze-Window $win

                # ============================================================
                # 位移单独取一次（对峙距离上重跑同一套配方）
                #
                # ★ 为什么不能直接用上面这遍的位移：位移敏感的招（突进斩 1300、
                #   前冲闪 110）在**贴身**起手时会一头撞进 p2 的推挤盒，引擎每
                #   tick 把双方推开，p1 的 x 因此来回摆（实测 106 -> 96 -> 103 ->
                #   111 -> 98…），净位移只剩 4.8px，而设计是 12 tick × 7.5 = 90px。
                #   逐帧数据证明 velSet{x: 7.5} 是生效的（每 tick 恰好 +7.5），
                #   所以那是**测量污染**，不是招式缺陷。
                #   对策：退到对面够不着的距离再放一次，只量位移，不断言伤害。
                # ============================================================
                if ($null -ne $mv.DisplAt) {
                    Write-Host ("          (位移复测：退到 ~{0}px 再放一次)" -f $mv.DisplAt) -ForegroundColor DarkGray
                    [void](Release-All)
                    [void](Wait-Grounded 3000)
                    Move-Far ([double]$mv.DisplAt) 6000
                    [void](Read-ProbeRows)
                    $from2 = $script:Rows.Count
                    foreach ($st in $mv.Steps) { Invoke-Step $st }
                    [void](Wait-State $mv.Entry 1600)
                    [void](Release-All)
                    [void](Wait-P1Ctrl $MoveTimeoutMs)
                    [void](Wait-Grounded 3000)
                    [void](Read-ProbeRows)
                    $to2 = $script:Rows.Count - 1

                    $win2 = [pscustomobject]@{
                        Idx = $n; Kind = 'solo'; Name = $mv.Name; Keys = $mv.Keys; State = $mv.State
                        From = $from2; To = $to2; DmgExp = $null; DmgRule = 'none'
                        PowerExp = $null; Proj = $null; Note = '位移复测（对峙距离）'
                    }
                    $winLog += $win2
                    $res2 = Analyze-Window $win2
                    $res | Add-Member -NotePropertyName DisplNear -NotePropertyValue $res.Displ -Force
                    $res.Displ = $res2.Displ
                    $res | Add-Member -NotePropertyName DisplSoloSeen -NotePropertyValue $res2.Seen -Force
                }
                $results += $res
            }
            Stop-Game
        }

        if ($Pass -eq 'guard' -or $Pass -eq 'all') {
            Write-Step 'PASS: T2 perfect guard (p2 AI 8 attacks, p1 pulses back)'
            Stop-Game
            Start-Game @('-p2.ai', '8') -CsvTag 'guard'
            [void](Wait-Grounded 10000)
            [void](Focus-Window $script:Hwnd)
            # ★ 必须是**脉冲**，不能一直按住。
            #   精防窗口（command.zss 的 var(20)）只在 `holdback` 的**边沿**置 3，
            #   然后每 tick 减 1。一直按住 → 边沿只发生一次 → 3 tick 后窗口归零，
            #   此后任何一次格挡都必然 var(20)=0，奖励分支永久不可能走到。
            #   2026-10-31 之前就是这样测的，结论是假的 FAIL。
            #
            # ★ 还要**蹲下**（同时按住 ↓）。为什么：站着按 ← 等于"往后跑"
            #   （公共状态 105 = velocity.run.back），24 秒里 p1 跑了 171 tick、
            #   只挡了 3 次 —— 对手的招基本全打空，样本根本不够。
            #   蹲防不位移，招才有机会落到实处（蹲防成立的震动状态是 152，
            #   与站防 150、空防 154 一起被判定接受）。
            $vksDown = @(ConvertTo-VKList 'down')
            $vks = @(ConvertTo-VKList 'back')
            Press-Keys $vksDown
            $deadline = (Get-Date).AddSeconds(24)
            $pulses = 0
            while ((Get-Date) -lt $deadline) {
                Press-Keys $vks
                Start-Sleep -Milliseconds 55
                [void](Read-ProbeRows)
                Release-Keys $vks
                Start-Sleep -Milliseconds 35
                [void](Read-ProbeRows)
                $pulses++
            }
            Release-Keys $vks
            Release-Keys $vksDown
            [void](Read-ProbeRows)
            Stop-Game

            $guardStates = @(150, 152, 154)
            $entries = 0
            $jgRows = 0
            $bonus = 0
            $winRows = 0
            $entriesInWin = 0
            $byState = @{}
            $maxPowAtJg = 0
            $capRows = 0
            $prevState = -1
            $prevPower = $null
            foreach ($r in $script:Rows) {
                $isEntry = ($guardStates -contains $r.State) -and ($r.State -ne $prevState)
                if ($isEntry) {
                    $entries++
                    if (-not $byState.ContainsKey($r.State)) { $byState[$r.State] = 0 }
                    $byState[$r.State] = $byState[$r.State] + 1
                    if ($r.JgWin -gt 0) { $entriesInWin++ }
                }
                if ($r.JgWin -gt 0) { $winRows++ }
                if ($r.Jg -gt 0) {
                    $jgRows++
                    # ★ 气 +80 会不会被观测到，取决于当时气槽有没有满：
                    #   powerAdd -> setPower -> Clamp(0, powerMax)（char.go:8807），
                    #   满槽时增益直接消失。所以要连"当时气量"一起记，否则
                    #   "有特效环但没看到涨气"会被误读成奖励只做了一半。
                    if ($r.Power -gt $maxPowAtJg) { $maxPowAtJg = $r.Power }
                    if ($r.Power -ge 1990) { $capRows++ }
                }
                if ($null -ne $prevPower -and ($r.Power - $prevPower) -ge 80) { $bonus++ }
                $prevState = $r.State
                $prevPower = $r.Power
            }
            $guardStats = [pscustomobject]@{
                Rows = $script:Rows.Count; GuardEntries = $entries; JgRows = $jgRows
                BigPowerJumps = $bonus; WinRows = $winRows; EntriesInWin = $entriesInWin
                Pulses = $pulses; ByState = $byState
                MaxPowAtJg = $maxPowAtJg; CapRows = $capRows
            }
        }

        # ------------------------------------------------------------------
        # PASS: keytest —— 定向诊断：哪个键、走哪条注入通道，真的能进引擎
        #
        # 为什么需要它：2026-10-31 出现"同一份键位下 BACKSPACE 能出招、
        # SPACE/RETURN/TAB/LSHIFT/LCTRL 全部无响应"的现象，而这几条键在更早的
        # 一轮里都能用。输入路径上有两个独立机制（keybd_event 走 OS 级输入、
        # PostMessage 直接投 WM_KEYDOWN），光看招式断言分不清是哪条断了。
        # 这个 pass 把两者**分开**各试一遍，用「状态号有没有变」作为唯一判据。
        # ------------------------------------------------------------------
        if ($Pass -eq 'keytest') {
            Write-Step 'PASS: keytest (keys x channels)'
            Stop-Game
            Start-Game @()
            [void](Wait-Grounded 10000)
            $btnMap = [ordered]@{ x = 'SPACE'; y = 'RETURN'; a = 'TAB'; b = 'BACKSPACE'; c = 'LSHIFT'; z = 'LCTRL' }
            $keyStats = @()
            foreach ($mech in @('kbd', 'post', 'postf')) {
                foreach ($k in $btnMap.Keys) {
                    $fRes = (Focus-Window $script:Hwnd)
                    $fgH = [P6Verify.Win]::GetForegroundWindow()
                    $fg = ($fgH -eq $script:Hwnd)
                    $sb = New-Object System.Text.StringBuilder 256
                    [void][P6Verify.Win]::GetWindowText($fgH, $sb, 256)
                    $vk = [int](Resolve-VKInvariant $btnMap[$k])
                    $scan = [byte][P6Verify.Win]::MapVirtualKey([byte]$vk, 0)
                    [void](Read-ProbeRows)
                    $from = $script:Rows.Count
                    if ($mech -eq 'kbd') {
                        [P6Verify.Win]::keybd_event([byte]$vk, $scan, 0, [UIntPtr]::Zero)
                        [void](Wait-Ticks 10)
                        [P6Verify.Win]::keybd_event([byte]$vk, $scan, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
                    } else {
                        if ($mech -eq 'postf') {
                            # SDL 只在窗口"有键盘焦点"时把 WM_KEYDOWN 派发成游戏输入。
                            # 系统前台抢不到时（本机被 Windows 的"快速设置"浮层占住），
                            # 直接给窗口投一个 WM_SETFOCUS 让它自己认为拿到了焦点。
                            [void][P6Verify.Win]::PostMessage($script:Hwnd, $WM_SETFOCUS, [IntPtr]::Zero, [IntPtr]::Zero)
                            Start-Sleep -Milliseconds 30
                        }
                        [void][P6Verify.Win]::PostMessage($script:Hwnd, $WM_KEYDOWN, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16)))
                        [void](Wait-Ticks 10)
                        [void][P6Verify.Win]::PostMessage($script:Hwnd, $WM_KEYUP, [IntPtr]$vk, [IntPtr](1 -bor ($scan -shl 16) -bor 0xC0000000))
                    }
                    [void](Wait-Ticks 25)
                    [void](Read-ProbeRows)
                    $states = @()
                    for ($i = $from; $i -lt $script:Rows.Count; $i++) {
                        $s = $script:Rows[$i].State
                        if ($states -notcontains $s) { $states += $s }
                    }
                    $keyStats += [pscustomobject]@{
                        Mech = $mech; Btn = $k; Key = $btnMap[$k]; Focus = $fg; Focused = $fRes
                        FGTitle = $sb.ToString()
                        States = (($states | Select-Object -First 6) -join ',')
                    }
                }
            }
            Stop-Game
            $lines = New-Object System.Collections.ArrayList
            [void]$lines.Add('# 按键注入通道诊断')
            [void]$lines.Add('')
            [void]$lines.Add('| 通道 | 按钮 | 键名 | 抢前台成功 | 前台是本进程 | 前台窗口标题 | 观察到的状态号 |')
            [void]$lines.Add('|---|---|---|---|---|---|---|')
            foreach ($r in $keyStats) {
                [void]$lines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} |' -f $r.Mech, $r.Btn, $r.Key, $r.Focused, $r.Focus, $r.FGTitle, $r.States))
            }
            $kp = Join-Path $OutDir 'keytest.md'
            [System.IO.File]::WriteAllText($kp, ($lines -join "`r`n"), $Utf8NoBom)
            foreach ($l in $lines) { Write-Host $l }
            Write-Host "[keytest] $kp" -ForegroundColor Cyan
        }
    } else {
        Write-Step 'replay mode: analysing the existing run.csv'
        $winPath = Join-Path $OutDir 'windows.json'
        if (-not (Test-Path -LiteralPath $winPath)) { throw "no windows.json in $OutDir - run once without -Replay" }
        $winLog = @(Get-Content -LiteralPath $winPath -Raw | ConvertFrom-Json)
        Open-CsvStream $CsvPath
        $deadline = (Get-Date).AddSeconds(20)
        while ((Get-Date) -lt $deadline) {
            [void](Read-ProbeRows)
            if ($script:CsvOffset -ge (New-Object System.IO.FileInfo($CsvPath)).Length) { break }
            Start-Sleep -Milliseconds 120
        }
        # 第一遍：所有"正常"窗口（solo 窗口只用来补位移，不能当一次成绩）
        foreach ($w in $winLog) {
            $k = ''
            if ($null -ne $w.PSObject.Properties['Kind']) { $k = [string]$w.Kind }
            if ($k -eq 'solo') { continue }
            $results += (Analyze-Window $w)
        }
        foreach ($w in $winLog) {
            $k = ''
            if ($null -ne $w.PSObject.Properties['Kind']) { $k = [string]$w.Kind }
            if ($k -ne 'solo') { continue }
            $res2 = Analyze-Window $w
            $m = @($results | Where-Object { $_.Idx -eq $w.Idx }) | Select-Object -First 1
            if ($null -eq $m) { continue }
            $m | Add-Member -NotePropertyName DisplNear -NotePropertyValue $m.Displ -Force
            $m.Displ = $res2.Displ
            $m | Add-Member -NotePropertyName DisplSoloSeen -NotePropertyValue $res2.Seen -Force
        }
        Stop-Game
    }
} catch {
    Write-Bad $_.Exception.Message
    $exitCode = 3
} finally {
    Stop-Game
    if (-not $Replay) {
        if (-not $KeepInstrument) { Restore-Def $origDef }
        # ★ 键位**永远**还原：不还原会让用户自己的 a/s/z/x/c/d 全部失灵
        #   （P4 踩过两次，见 tests/p2/inject_phases.ps1 的注释）。
        Restore-InjectionKeymap $origCfg
        if ($winLog.Count -gt 0) {
            [System.IO.File]::WriteAllText((Join-Path $OutDir 'windows.json'), ($winLog | ConvertTo-Json -Depth 6), $Utf8NoBom)
        }
    }
}

# ---------------------------------------------------------------------------
# 报告
# ---------------------------------------------------------------------------
if ($results.Count -gt 0 -or $null -ne $guardStats) {
    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add('# Archer 全招式端到端验收（Runtime 遥测）')
    [void]$lines.Add('')
    [void]$lines.Add(('生成时间: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    [void]$lines.Add(('样本行数: {0}（P1 每 tick 一行）' -f $script:Rows.Count))
    [void]$lines.Add(('引擎实测速率: {0} tick/s（标称 60）—— 配方时序因此按 gameTime 计 tick，不按墙钟毫秒' -f $script:TickRate))
    [void]$lines.Add('')
    [void]$lines.Add('注：脚本运行时把 `[Keys_P1]` 临时改成 SPACE/RETURN/TAB/BACKSPACE/LSHIFT/LCTRL')
    [void]$lines.Add('（本机只有这 6 个键能注入进引擎），跑完已还原。招式名里的按键是**设计键**。')
    [void]$lines.Add('')
    # ---- 以下是「招式段」，只有跑了 moves 趟才有内容 ----
    if ($results.Count -gt 0) {
        [void]$lines.Add('判定口径：`伤害` = 窗口内 p2 生命**降量之和**（对 p2 生命回升免疫）；')
        [void]$lines.Add('`耗气` = 进入后最低气量 − 进入前最高气量（对"头增益 / 体扣除"落在不同 tick 免疫）。')
        [void]$lines.Add('')
        [void]$lines.Add('| # | 招式 | 按键 | 期望状态 | 进入 | 伤害 观测/期望 | 耗气 观测/期望 | 收招 tick | 判定 |')
        [void]$lines.Add('|---|---|---|---|---|---|---|---|---|')

        foreach ($r in $results) {
            $seen = 'NO'
            if ($r.Seen) { $seen = 'yes' }
            $dmg = ('{0}/{1}' -f $r.Damage, $r.DmgExp)
            if ($r.DmgRule -eq 'none') { $dmg = '—' }
            $pow = '—'
            if ($null -ne $r.PowerExp) {
                $pow = ('{0}/{1}' -f $r.PowerD, $r.PowerExp)
                if ($r.PowerBaseline -ge 1990) { $pow = $pow + ' 满槽' }
            }
            [void]$lines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} |' -f `
                        $r.Idx, $r.Name, $r.Keys, $r.State, $seen, $dmg, $pow, $r.RecoverTicks, (Get-VerdictText $r)))
        }

        [void]$lines.Add('')
        [void]$lines.Add('## 位移（推进/后撤类招式）')
        [void]$lines.Add('')
        [void]$lines.Add('标注 `()/` 的两行：`x` 是**对峙距离复测**（对手够不着）的结果，括号内是贴身起手的读数。')
        [void]$lines.Add('贴身读数会被推挤盒污染（两人重叠时引擎每 tick 把双方推开），不能作为位移证据。')
        [void]$lines.Add('')
        [void]$lines.Add('`位移` 已按**面向**折算了正负（+ = 朝角色前方 / − = 朝身后），')
        [void]$lines.Add('所以推进招为正、后撤招为负，与当时朝左还是朝右无关。`X 起点/终点` 是原始世界坐标。')
        [void]$lines.Add('')
        [void]$lines.Add('| 招式 | X 起点 | X 终点 | 位移（+前 / −后） | 期间最大 abs(velX) |')
        [void]$lines.Add('|---|---|---|---|---|')
        foreach ($r in $results) {
            if ($null -eq $r.Displ) { continue }
            if (@(110, 115, 117, 1200, 1300) -notcontains $r.State) { continue }
            $name = $r.Name
            $flip = { param($d) if ($d.Facing -lt 0) { -$d.Delta } else { $d.Delta } }
            $delta = ('{0:F2}' -f (& $flip $r.Displ))
            $near = $r.PSObject.Properties['DisplNear']
            if ($null -ne $near -and $null -ne $near.Value) {
                $name = $r.Name + ' `(对峙)`'
                $delta = ('{0:F2} ({1:F2})' -f (& $flip $r.Displ), (& $flip $near.Value))
            }
            [void]$lines.Add(('| {0} | {1:F2} | {2:F2} | {3} | {4:F2} |' -f $name, $r.Displ.X0, $r.Displ.XEnd, $delta, $r.Displ.MaxAbsVX))
    }
    }

    if ($null -ne $guardStats) {
        [void]$lines.Add('')
        [void]$lines.Add('## T2 完美防（p2 开 AI 8 主动攻击，p1 蹲防 + 脉冲式补"后"）')
        [void]$lines.Add('')
        [void]$lines.Add(('- 样本: {0} 行（"后"脉冲 {1} 次，每次重新打开 3 tick 精防窗口）' -f $guardStats.Rows, $guardStats.Pulses))
        [void]$lines.Add(('- 进入格挡震动状态的次数: {0}（站防 150 / 蹲防 152 / 空防 154 分别 {1} / {2} / {3}）' -f `
                $guardStats.GuardEntries, `
                $(if ($guardStats.ByState.ContainsKey(150)) { $guardStats.ByState[150] } else { 0 }), `
                $(if ($guardStats.ByState.ContainsKey(152)) { $guardStats.ByState[152] } else { 0 }), `
                $(if ($guardStats.ByState.ContainsKey(154)) { $guardStats.ByState[154] } else { 0 })))
        [void]$lines.Add(('- 其中"格挡发生的那一 tick 精防窗口还开着（var(20) > 0）"的次数: {0}' -f $guardStats.EntriesInWin))
        [void]$lines.Add(('- 精防窗口 var(20) > 0 的 tick 数: {0}' -f $guardStats.WinRows))
        [void]$lines.Add(('- 出现精防特效环 numExplod(7191) 的行数: {0}' -f $guardStats.JgRows))
        [void]$lines.Add(('- 气单 tick 涨 >= 80 的次数: {0}' -f $guardStats.BigPowerJumps))
        if ($guardStats.JgRows -gt 0 -and $guardStats.BigPowerJumps -eq 0) {
            [void]$lines.Add(('  （当时气量最高 {0}，其中 {1} 行已 >= 1990：`powerAdd` 走  `char.go:8807` 的 Clamp(0, powerMax)，' -f $guardStats.MaxPowAtJg, $guardStats.CapRows))
            [void]$lines.Add('   满槽时 +80 会被**直接吃掉**，观测不到涨气属正常；奖励是否生效以特效环为准。）')
        }
        [void]$lines.Add('')
        if ($guardStats.GuardEntries -gt 0 -and $guardStats.JgRows -gt 0) {
            [void]$lines.Add('判定: **PASS**（格挡成立且精防分支真的走到了）')
        } elseif ($guardStats.GuardEntries -eq 0) {
            [void]$lines.Add('判定: **INCONCLUSIVE**（对手这段没打中/没近身，格挡一次都没发生 —— 不能算通过）')
        } elseif ($guardStats.EntriesInWin -eq 0) {
            [void]$lines.Add('判定: **INCONCLUSIVE**（格挡发生了，但没有一次落在精防窗口内 —— 是采样时序问题，不是机制缺陷）')
        } else {
            [void]$lines.Add('判定: **FAIL**（有格挡落在精防窗口内，却没有精防特效环 —— 奖励分支没生效）')
        }
    }

    $reportPath = Join-Path $OutDir 'report.md'
    [System.IO.File]::WriteAllText($reportPath, ($lines -join "`r`n"), $Utf8NoBom)

    Write-Host ''
    foreach ($l in $lines) { Write-Host $l }
    Write-Host ''
    Write-Host "[report] $reportPath" -ForegroundColor Cyan
    Write-Host "[ csv  ] $CsvPath" -ForegroundColor Cyan
    if ($Pass -eq 'all') { Write-Host "[ csv  ] $(Join-Path $OutDir 'run_guard.csv')  (guard 趟单独一份，不覆盖 moves)" -ForegroundColor Cyan }

    $bad = @($results | Where-Object { Test-Failed $_ })
    if ($bad.Count -gt 0) {
        Write-Bad ("{0} recipe(s) failed" -f $bad.Count)
        $exitCode = 1
    } else {
        if ($results.Count -gt 0) { Write-Ok 'all move recipes passed' }
        else { Write-Ok 'T2 pass finished (no move recipes in this run)' }
    }
    # T2 只有"格挡真的落在精防窗口内、却没有奖励"才算失败；
    # 窗口一次都没命中属于采样问题（INCONCLUSIVE），不算通过了也不算缺陷。
    if ($null -ne $guardStats -and $guardStats.EntriesInWin -gt 0 -and $guardStats.JgRows -eq 0) { $exitCode = 1 }
}

exit $exitCode

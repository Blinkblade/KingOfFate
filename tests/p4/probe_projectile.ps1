#Requires -Version 5.1
<#
.SYNOPSIS
    Fighter B 投射物运行时读数：屏幕上到底有几枚波、隔多久一发、能不能打中人。

.DESCRIPTION
    为什么需要这个脚本:
      「远程无限波」这条反馈修了两轮，两轮的依据都是**算术** ——
      "出招 42 + 冷却 240 = 282 tick 一轮，所以 4.7 秒一波"。
      但从来没有人在这局游戏里数过屏幕上同时有几枚波、两波之间隔了多少 tick。
      算术成立不等于体感成立：第一轮正是"算术上留了 102 tick 空白，体感却是
      一直在防"（见 docs/iterations/20261103-... §9.2）。

    做法（沿用 P6 已经验证过的通道）:
      ZSS 的 printToConsole -> stdout -> 重定向到文件。探针是
      tests/p4/fighter_b_probe.zss，逐 tick 打出
      状态 / 双方血量 / 双方轴心距离 / 气 / numProjID(1000) / numProj。
      于是三个原本只能靠肉眼的问题变成读数：
        ① 屏幕上同时有几枚波      -> projAll 的最大值
        ② 两波之间隔多少 tick     -> projAll 0 -> >0 的边沿之间的 gameTime 差
        ③ 波到底打不打得到人      -> p2Life 下降时 |p2DistX| 是否远大于手长（约 70）

    只改 **runtime 副本**（engine/ikemen-go/chars/<P1>/）。该目录在子模块里被
    .gitignore 忽略，所以 game/ 真值与 git 都不受影响。脚本结束时会把 .def 的
    原始字节写回去（除非 -KeepInstrument）。

.PARAMETER RunSec
    跑多少秒后强杀引擎并分析。默认 45 秒（够打完一回合）。

.PARAMETER Ai2
    对手 AI 等级。默认 0 = 不还手。**别随手改成 8**：
    对手还手时掉血无法归因到"波"，本脚本的核心断言就失效了。

.PARAMETER OutDir
    报告与原始 CSV 的输出目录。默认 logs/p4/probe（gitignored）。

.EXAMPLE
    pwsh -File tests\p4\probe_projectile.ps1
    pwsh -File tests\p4\probe_projectile.ps1 -RunSec 60 -P2 test_fighter_a
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$P1 = 'test_fighter_b',
    [string]$P2 = 'archer',
    [int]$Ai1 = 8,
    [int]$Ai2 = 0,
    [int]$RunSec = 45,
    [int]$RoundTime = 99,
    [string]$Stage = 'stage0',
    [string]$OutDir,
    [switch]$SkipSync,
    [switch]$KeepInstrument
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).ProviderPath
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $RepoRoot 'logs\p4\probe' }
if (-not (Test-Path -LiteralPath $OutDir)) { [void](New-Item -ItemType Directory -Path $OutDir -Force) }

$RuntimeRoot = Join-Path $RepoRoot 'engine\ikemen-go'
$Exe = Join-Path $RuntimeRoot 'Ikemen_GO.exe'

# Runtime DLL search path（与 tests/p3/run_match_watch.ps1、tests/p6/verify_moves.ps1
# 同一个发现顺序）。不补这一段，引擎会以 0xC0000135 立刻退出 ——
# 那是 STATUS_DLL_NOT_FOUND（MinGW 运行时 dll 不在 PATH 上），不是角色问题。
$dllDir = $null
foreach ($c in @($env:MSYS2_ROOT, $env:MSYS2_HOME, 'C:\msys64', 'D:\msys64')) {
    if ([string]::IsNullOrWhiteSpace($c)) { continue }
    $p = Join-Path $c 'mingw64\bin'
    if (Test-Path -LiteralPath (Join-Path $p 'libgcc_s_seh-1.dll')) { $dllDir = $p; break }
}
if ($null -ne $dllDir) { $env:PATH = "$dllDir;$env:PATH" }
else { Write-Host '[warn ] no MSYS2 mingw64/bin found - the game may fail to start' -ForegroundColor Yellow }
$RuntimeChar = Join-Path $RuntimeRoot ('chars\' + $P1)
$ProbeSrc = Join-Path $ScriptDir 'fighter_b_probe.zss'
$DefPath = Join-Path $RuntimeChar ($P1 + '.def')
$ProbeDst = Join-Path $RuntimeChar 'probe.zss'
$CsvPath = Join-Path $OutDir 'run.csv'
$ErrPath = Join-Path $OutDir 'stderr.txt'
$ReportPath = Join-Path $OutDir 'report.txt'

$script:Lines = New-Object System.Collections.Generic.List[string]
function Write-Note([string]$text) {
    $script:Lines.Add($text)
    Write-Host $text
}

# ---------------------------------------------------------------------------
# 0. 前置检查
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $Exe)) {
    throw "engine executable missing: $Exe (run scripts\build_engine.ps1 first)"
}
if (-not (Test-Path -LiteralPath $DefPath)) { throw "no such def: $DefPath" }
if (-not (Test-Path -LiteralPath $ProbeSrc)) { throw "no such probe: $ProbeSrc" }

if (-not $SkipSync) {
    Write-Note '[probe] syncing game/ -> runtime ...'
    & (Join-Path $RepoRoot 'scripts\sync_game_content.ps1') *> $null
    if (-not $?) { throw 'sync failed' }
}
if (-not (Test-Path -LiteralPath $DefPath)) { throw "sync removed the def: $DefPath" }

# ---------------------------------------------------------------------------
# 1. 装上探针（只改 runtime 副本），记录原始字节以便还原
# ---------------------------------------------------------------------------
$origDef = [IO.File]::ReadAllBytes($DefPath)
$script:Proc = $null
$restoreNeeded = $true

try {
    Copy-Item -LiteralPath $ProbeSrc -Destination $ProbeDst -Force

    # 在 [Files] 段的末尾插一行 st5 = probe.zss。st5 是合法键名
    # （compiler.go:8163 的 ^st[0-9]*$），且 -2 号状态在 common1 里没人用。
    $text = [IO.File]::ReadAllText($DefPath)
    if ($text -notmatch '(?m)^\s*st5\s*=') {
        # ★ 变量名不能叫 $lines：PowerShell 变量名大小写不敏感，
        #   它会和脚本级的 $script:Lines（报告行缓冲，List[string]）撞成同一个，
        #   把它覆盖成 string[]，之后 Write-Note 的 .Add() 就会抛
        #   "Collection was of a fixed size."
        $defLines = $text -split "`r?`n"
        $out = New-Object System.Collections.Generic.List[string]
        $inFiles = $false
        $inserted = $false
        foreach ($line in $defLines) {
            if ($line -match '^\s*\[') {
                if ($inFiles -and -not $inserted) {
                    $out.Add('st5 = probe.zss')
                    $inserted = $true
                }
                $inFiles = ($line -match '^\s*\[Files\]')
                $out.Add($line)
                continue
            }
            $out.Add($line)
        }
        if ($inFiles -and -not $inserted) {
            $out.Add('st5 = probe.zss')
            $inserted = $true
        }
        if (-not $inserted) { throw 'could not find a [Files] section in the def' }
        [IO.File]::WriteAllText($DefPath, ($out -join "`r`n"), (New-Object Text.UTF8Encoding($false)))
    }
    Write-Note ("[probe] instrumented {0}" -f $DefPath)

    # -----------------------------------------------------------------------
    # 2. 起局（不注入任何按键：双方行为完全由 AI 决定）
    # -----------------------------------------------------------------------
    if (Test-Path -LiteralPath $CsvPath) {
        Move-Item -LiteralPath $CsvPath -Destination (Join-Path $OutDir 'run_prev.csv') -Force
    }
    $argList = @('-p1', $P1, '-p2', $P2, '-s', $Stage, '-rounds', '1',
        '-time', $RoundTime, '-windowed', '-nosound',
        '-p1.ai', $Ai1, '-p2.ai', $Ai2)
    Write-Note ("[probe] {0} vs {1}  ai {2}/{3}  {4}s" -f $P1, $P2, $Ai1, $Ai2, $RunSec)
    $script:Proc = Start-Process -FilePath $Exe -ArgumentList $argList `
        -WorkingDirectory $RuntimeRoot -RedirectStandardOutput $CsvPath `
        -RedirectStandardError $ErrPath -PassThru
    Write-Note ("[probe] pid {0}" -f $script:Proc.Id)

    # 窗口出现即视为启动成功；它不需要前台焦点（没有按键注入）。
    $deadline = (Get-Date).AddSeconds(30)
    $hwnd = [IntPtr]::Zero
    while ((Get-Date) -lt $deadline) {
        if ($script:Proc.HasExited) {
            throw ("the engine exited early (code {0}); see {1}" -f $script:Proc.ExitCode, $ErrPath)
        }
        $script:Proc.Refresh()
        if ($script:Proc.MainWindowHandle -ne [IntPtr]::Zero) { $hwnd = $script:Proc.MainWindowHandle; break }
        Start-Sleep -Milliseconds 200
    }
    if ($hwnd -eq [IntPtr]::Zero) { throw 'the engine window never appeared' }

    Start-Sleep -Seconds $RunSec
}
finally {
    if ($null -ne $script:Proc -and -not $script:Proc.HasExited) {
        Stop-Process -Id $script:Proc.Id -Force
        Start-Sleep -Milliseconds 600
    }
    # 还原：.def 写回原始字节，探针移走（logs/ 是 gitignored，不放 .tmp 之外）
    if ($restoreNeeded) {
        if (Test-Path -LiteralPath $ProbeDst) {
            Move-Item -LiteralPath $ProbeDst -Destination (Join-Path $OutDir 'probe_used.zss') -Force
        }
        if (-not $KeepInstrument) {
            [IO.File]::WriteAllBytes($DefPath, $origDef)
            Write-Note '[probe] runtime def restored'
        }
        else {
            Write-Note '[probe] -KeepInstrument: def left instrumented'
        }
    }
}

# ---------------------------------------------------------------------------
# 3. 解析
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $CsvPath)) { throw "no probe output: $CsvPath" }

$rows = New-Object System.Collections.Generic.List[object]
foreach ($line in [IO.File]::ReadAllLines($CsvPath)) {
    if (-not $line.StartsWith('KOF,')) { continue }
    $f = $line.Split(',')
    if ($f.Count -lt 12) { continue }
    try {
        $rows.Add([pscustomobject]@{
                g      = [int]$f[1]
                state  = [int]$f[2]
                p2state = [int]$f[3]
                life   = [int]$f[4]
                p2life = [int]$f[5]
                dist   = [double]$f[6]
                power  = [int]$f[7]
                p1000  = [int]$f[8]
                pall   = [int]$f[9]
                ctrl   = [int]$f[10]
                cd     = [int]$f[11]
            })
    }
    catch { }
}

if ($rows.Count -eq 0) {
    throw "the probe printed nothing usable ($CsvPath). Check $ErrPath"
}

$spanStart = $rows[0].g
$spanEnd = $rows[$rows.Count - 1].g
$maxProj = 0
foreach ($r in $rows) { if ($r.pall -gt $maxProj) { $maxProj = $r.pall } }

# 发射边沿：projAll 从 0 变成 >0
$bursts = New-Object System.Collections.Generic.List[int]
$prev = 0
foreach ($r in $rows) {
    if ($prev -eq 0 -and $r.pall -gt 0) { $bursts.Add($r.g) }
    $prev = $r.pall
}

# 招式起手：状态**跳进** 1000 / 1010 / 3000 的那一 tick。
# ★ 这比"投射物边沿"更能定性 —— 一次出招可能连发 2~3 枚，边沿会数成一次，
#   但如果 projAll 在出招中途归零（命中即消失），边沿又会把同一招数成两次。
$waves = New-Object System.Collections.Generic.List[object]
$prevState = -1
foreach ($r in $rows) {
    if ($r.state -ne $prevState -and ($r.state -eq 1000 -or $r.state -eq 1010 -or $r.state -eq 3000)) {
        $waves.Add([pscustomobject]@{ g = $r.g; state = $r.state; cd = $r.cd; power = $r.power })
    }
    $prevState = $r.state
}

$gaps = New-Object System.Collections.Generic.List[int]
for ($i = 1; $i -lt $waves.Count; $i++) { $gaps.Add($waves[$i].g - $waves[$i - 1].g) }

$cdAfterSpawn = @($waves | Select-Object -First 3 | ForEach-Object { $_.cd })

# 掉血事件：p2life 比上一行低
$hits = New-Object System.Collections.Generic.List[object]
for ($i = 1; $i -lt $rows.Count; $i++) {
    $d = $rows[$i - 1].p2life - $rows[$i].p2life
    if ($d -gt 0) {
        $hits.Add([pscustomobject]@{
                g = $rows[$i].g; dmg = $d; dist = [math]::Abs($rows[$i].dist)
                proj = $rows[$i].pall; state = $rows[$i].state
            })
    }
}
$rangedHits = @($hits | Where-Object { $_.dist -gt 100 })

# ---------------------------------------------------------------------------
# 4. 报告
# ---------------------------------------------------------------------------
Write-Note ''
Write-Note ('=' * 72)
Write-Note 'Fighter B 投射物运行时读数'
Write-Note ('=' * 72)
Write-Note ("rows        : {0}  (gameTime {1} .. {2}, {3} tick)" -f $rows.Count, $spanStart, $spanEnd, ($spanEnd - $spanStart))
Write-Note ("on screen   : max projAll = {0}" -f $maxProj)
Write-Note ("waves       : {0} start(s)  (1000 = {1}, 1010 = {2}, 3000 = {3})" -f `
        $waves.Count,
        @($waves | Where-Object { $_.state -eq 1000 }).Count,
        @($waves | Where-Object { $_.state -eq 1010 }).Count,
        @($waves | Where-Object { $_.state -eq 3000 }).Count)
if ($waves.Count -gt 0) {
    # ★ 冷却读数：这一列回答"var(1) := 240 到底执行了没有"。
    #   >0 = 赋值生效，之后每 tick 递减；恒为 0 = 赋值没跑到（或招式不是 AI 触发的）。
    Write-Note ("cooldown    : var(1) at first wave starts = {0}" -f ($cdAfterSpawn -join ', '))
}
if ($gaps.Count -gt 0) {
    $sorted = @($gaps | Sort-Object)
    $median = $sorted[[int][math]::Floor($sorted.Count / 2)]
    Write-Note ("gap (ticks) : min {0} / median {1} / max {2}" -f $sorted[0], $median, $sorted[$sorted.Count - 1])
    Write-Note ("              (合约值 = 冷却 240 tick ≈ 4 s；不要按 42+240 算 ——")
    Write-Note ("               冷却在招式期间照样递减，周期就是冷却值本身)")
}
Write-Note ("damage      : {0} event(s), {1} at |dist| > 100 (= 只能来自投射物)" -f $hits.Count, $rangedHits.Count)
foreach ($h in ($rangedHits | Select-Object -First 5)) {
    Write-Note ("              g={0,-6} -{1,-4} hp  |dist|={2,5:N1}  projOnScreen={3}" -f $h.g, $h.dmg, $h.dist, $h.proj)
}

# 断言（只有"确定是错的"才判失败）
$problems = New-Object System.Collections.Generic.List[string]
if ($maxProj -gt 3) { $problems.Add("max projAll = $maxProj > 3 (Super 一次 3 发是上限)") }
# 冷却赋值是否真的执行了：除第一次起手外，每次起手时 var(1) 都应该是刚写进去的正值。
# 恒为 0 = `var(1) := N` 又在 changeState 后面（引擎换状态就吞掉后面的语句）。
$cdDead = @($waves | Select-Object -Skip 1 | Where-Object { $_.cd -le 0 })
if ($cdDead.Count -gt 0) {
    $problems.Add(("var(1) reads 0 at {0} wave start(s) -- the cooldown assignment never ran" -f $cdDead.Count))
}
if ($gaps.Count -gt 0) {
    $tooClose = @($gaps | Where-Object { $_ -lt 200 })
    if ($tooClose.Count -gt 0) {
        $problems.Add(("two waves only {0} tick(s) apart (cooldown 240); 该角色不该有 200 tick 以内的连发" -f $tooClose[0]))
    }
}
if ($rangedHits.Count -eq 0) {
    $problems.Add('no damage landed at range -- the projectile never connected')
}

Write-Note ''
if ($problems.Count -eq 0) {
    Write-Note 'VERDICT: PASS'
}
else {
    Write-Note 'VERDICT: FAIL'
    foreach ($p in $problems) { Write-Note ("  - {0}" -f $p) }
}
Write-Note ("report     : {0}" -f $ReportPath)
[IO.File]::WriteAllLines($ReportPath, $script:Lines, (New-Object Text.UTF8Encoding($false)))

if ($problems.Count -gt 0) { exit 1 }
exit 0

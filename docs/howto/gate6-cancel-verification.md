# 如何验证 Gate 6 —— 取消链（200 → 1000）

> 目标读者：下一个要补这条 Gate 的人（可以是人，也可以是自动化）。
> 本文只写**怎么做、看什么数、怎么判**，不含任何"应该没问题"的推测。

---

## 0. 先明确"什么算通过"

Gate 6 问的不是"236+A 能不能出波"（那个早就被证实了），而是：
**站立轻拳（状态 200）能不能在它自己的取消窗口里被切成气弹（状态 1000）。**

判据来自两处可以确定读到的东西：

**① 状态 200 有多长**（`design/characters/test_fighter_b/moves.csv` 第 2 行）：

| 项 | 值 |
| --- | --- |
| 起手 Startup | 3 tick |
| 判定 Active | 4 tick |
| 收招 Recovery | 13 tick |
| **合计** | **20 tick** |
| 判定帧 | `animElem 3`（取消窗口从这一帧打开） |

**② 取消窗口是什么**（`game/chars/test_fighter_b/test_fighter_b.zss:157-158`）：

```
if animElem = 3 {
    var(4) := 1;      # 判定帧开始 → 打开取消窗口
```

配合 `command.zss:81` 的放行条件
`var(3) > 0 && var(3) < lv && var(4) = 1 && var(0) = 0`
（等级严格递增 + 判定帧已开始 + 本次攻击还没取消过）。

**所以判据是：**

| 现象 | 结论 |
| --- | --- |
| 状态 200 只持续 **几 tick**（明显 < 20）就变成 1000，且 1000 紧跟着开始 | **取消成立 → PASS** |
| 状态 200 跑满 ~20 tick 回到 0，**之后**才出现 1000 | 不是取消，是"打完再出下一招" → **FAIL / 未证明** |

> 这正是老证据失败的地方：Phase Report 里记的是
> "`State 200 @ Frame 952` → `State 1000 @ Frame 1007`"，间隔约 55 帧，
> 远大于 20 tick 的窗口 —— 完全无法排除"先打完再另起一招"。

---

## 1. 前置条件

```powershell
pwsh -File scripts\sync_game_content.ps1          # game/ → 运行时
pwsh -File scripts\build_engine.ps1 -BuildFfmpeg no
pwsh -File tests\p4\make_dummy.ps1                # 生成 test_dummy_plain（惰性靶子）
```

`make_dummy.ps1` 只往 `engine/ikemen-go/chars/` 写，不碰 `game/chars/`（真值目录）。

---

## 2. 第 1 步：先量"200 自然有多长"（对照组）

不打取消，只按一下 x，逐 tick 看状态 200 自己活多久。

```powershell
pwsh -File tests\p2\framestep_probe.ps1 `
    -P1 test_fighter_b -P2 test_dummy_plain -Ai1 0 -Ai2 0 `
    -WarmupSec 10 -ShowDebug `
    -OutDir logs\p4\gate6 -Prefix g6_base `
    -Steps 'none:6,0x09:2,none:26'
```

* `-Steps` 的单位是 **tick 不是秒**（`none:6` 先空推 6 tick，避开回合开始的不可控期；
  `0x09:2` 按住 x 两 tick；再空推 26 tick 看 200 自然收尾）。
* 一个 SCROLLLOCK = 一个游戏 tick，**截图再慢也不影响时序**（`src/fightscreen.go:3430`）。

---

## 3. 第 2 步：取消跑

同样的前置，但在 200 还在打的时候把 236+A 输进去。

```powershell
pwsh -File tests\p2\framestep_probe.ps1 `
    -P1 test_fighter_b -P2 test_dummy_plain -Ai1 0 -Ai2 0 `
    -WarmupSec 10 -ShowDebug `
    -OutDir logs\p4\gate6 -Prefix g6_cancel `
    -Steps 'none:6,0x09:2,none:2,0x28:1,0x28+0x27:1,0x27:1,0x09:1,none:20'
```

时间轴（tick）：

| tick | 输入 | 预期状态 |
| --- | --- | --- |
| 1–6 | 无 | 0（站） |
| 7–8 | 按住 x | **200 开始**（约 tick 8） |
| 9–10 | 无 | 200（判定帧已开，`var(4)=1`） |
| 11 | ↓ | 200（缓冲 QCF） |
| 12 | ↓→ | 200 |
| 13 | → | 200 |
| 14 | x | **若取消成立：1000 从这一 tick 开始** |

QCF 的 `time=25` 是 **tick** 计，暂停不会让它衰减，所以一次一格完全在窗口内。

---

## 4. 第 3 步：读数（别用眼睛）

```powershell
python tools\read_frame_text.py logs\p4\gate6
```

输出里认这两行（`debug.lua` 写死的格式）：

```
State No: %d (P%d); CTRL: %s; Type: %s; MoveType: %s; Physics: %s; Time: %d
ActionID: %d (P%d); SPR: %d,%d; ElemNo: %d/%d; Time: %d/%d (%d/%d)
```

只看 P1 的 `State No`（因为注入只作用于 P1）。把每个 tick 的状态号排成序列，例如：

```
t001..t006  0
t008..t013  200      <- 200 只活了 6 tick（远小于 20）
t014..t032  1000     <- 紧接着就是气弹
```

**任何一步读数不确定时，用 `tools\dump_glyphs.py <png> --band 1` 把像素原样打成点阵核对**
——不要凭印象。

---

## 5. 第 4 步：判定

| 检查 | 对照（g6_base） | 取消跑（g6_cancel） |
| --- | --- | --- |
| 200 持续多少 tick | ≈ **20** | **明显更短**（个位数到十几） |
| 1000 是否紧接 200 | 无 1000 | 有，且 200→1000 相邻 |
| 中间是否回到过 0 | 是（打完回站） | **否** |

三条同时成立 ⇒ **Gate 6 PASS**。
若 200 跑满 20 tick 才出现 1000 ⇒ 保持 **BLOCKED**，并把实测序列写进证据文件。

---

## 6. 第 5 步：记录

1. 把两条 tick 序列存到 `docs/evidence/p4/gate6_cancel_sequence.txt`
   （格式参考同目录的 `gate7_dummy_matrix.txt`：写清命令、每 tick 读数、判定）。
2. 更新 `docs/phase_reports/P4-test-fighter-b.md` 的 Gate 6 小节（现在是 §"Gate 6 — Cancel"）。
3. 更新 `docs/P4-summary.md` §9「已知问题」第 2 条。
4. 填 `docs/howto/gate-verification-in-training-mode.md` §6 的结果记录表。

**只有做完第 6 步，Gate 6 才算真正完成** —— 序列存在你自己的终端里不算证据。

---

## 7. 已知的坑（都已踩过，别再踩）

| 坑 | 症状 | 处理 |
| --- | --- | --- |
| **回合开始不可控期** | 开头几 tick 按 x 没反应，序列里看不到 200 | `-Steps` 最前面加 `none:6`（或更多）让"FIGHT!"过去 |
| **步进脚本没绑键位** | 方向键有效（能看到蹲下 10/11），但 x 完全没反应，永远到不了 1000 | 已修：`framestep_probe.ps1` 现在自己快照/还原 `save/config.ini`（和 `inject_phases` 一致）。**别手工改 config.ini** |
| **`AttachThreadInput` 间歇崩溃** | 报"无法将值 XXXX 的 IntPtr 转换为 UInt32"，且**时好时坏** | 已修：`GetWindowThreadProcessId` 的返回值声明改回 `uint`（Win32 返回 DWORD，`inject_phases` 一直是对的） |
| **暂停态下截图失败** | 报告里一片 `shot : tN FAILED`，一帧都没存下来 | 重跑；必要时加大 `-TickWaitMs`（默认 220）。`PrintWindow` 对 OpenGL 窗口会阻塞渲染线程，这是已知特性 |
| **连拍把引擎拖到 ~10% 速度** | 用 `inject_phases` 连拍时注入全落在不可控期，看着正常实际什么都没做 | 逐 tick 取证就用 `framestep_probe`，别用连拍拼时间序 |
| **ZSS 注释** | 写 `;` 注释 → 引擎直接 `Invalid data: ;` 退出 | ZSS 只认 `#` |
| **数字一样 ≠ 成功** | 实验组和对照组读数完全相同（Gate 7 跳跃第一版就栽在这） | 先问："如果什么都没发生，这个数会是多少？"一样就是没生效 |

---

## 8. 人工路径（自动化跑不通时的备选）

引擎自带 Training 模式 + 真实键盘也能做同样的事：
`PAUSE` 暂停、`SCROLLLOCK` 单帧、`Ctrl+D` 开覆盖层，然后看屏幕上
`State No` 的变化。步骤和判定完全一样，只是把上面的命令换成手按。
手册在 `docs/howto/gate-verification-in-training-mode.md` §5。

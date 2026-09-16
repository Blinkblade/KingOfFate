# tests/p3 — Test Fighter A 验证装置

P3 阶段的运行时验证工具。**不是**第二套 harness：P1/P2 的工具仍是主体，
这里只补它们**表达不了**的那一件事。

## run_match_watch.ps1 — 无人值守跑一局 + 崩溃日志监视

### 为什么需要它

| 想知道 | 该用什么 |
| --- | --- |
| 某个按键/搓招把角色带进了哪个状态 | `tests/p1/capture_match.ps1`、`tests/p2/inject_phases.ps1` |
| 角色移动了多远 | `tests/p1/measure_positions.ps1` |
| 把多帧读数拼成一张图 | `tests/p1/montage_states.ps1` |
| **引擎自己有没有报错 / 角色能不能加载** | **本脚本** |

原因是 P3 才发现的两条事实：

1. **引擎的控制台输出抓不到（至少不能指望）。** 实测三种情形：
   - (a) `Start-Process -RedirectStandardOutput <file>` → **空文件**
     （P3 实测：跑 25 s，0 行）。GUI 子系统进程不把 stdout 交给这个句柄。
   - (b) 让 harness **直接**在控制台会话里运行（父进程的 stdout 被上层捕获）→
     引擎的启动横幅（`Ikemen, GO!` / `Check A: Selecting Renderer` …）**会**出现在
     父进程的输出里，能读到。
   - (c) 中间再套一层脚本并 `*>> log` 重定向 → 又**抓不到**（P3 在 13 份 batch 日志
     里逐条搜过，0 行）。
   结论：不要依赖控制台输出做**自动断言**；要读启动横幅就用情形 (b)，
   要判断"有没有报错"则看下面第 2 条。
2. **致命错误（ZSS 解析错误、panic）真正的落地形态是**
   `engine/ikemen-go/save/logs/Ikemen_<时间戳>.log`
   （`src/main.go:381-401`），外加一个弹窗。
   而**非致命告警**（例如 `changed to invalid state 180`）只画在游戏内控制台里，
   **只会出现在截图里**。

所以无人值守唯一可靠的自动化判据是：
**跑一局 → 对比 `save/logs/` 有没有新日志 → 保留截图**。

### 用法

```powershell
# AI vs AI 跑 100 秒，每 8 秒抓一张带状态读数的图，最后报告有没有新崩溃日志
pwsh -File tests/p3/run_match_watch.ps1 -P1 test_fighter_a -P2 kfm_zss `
    -Ai1 8 -Ai2 8 -RunSec 100 -Shots 12 -RoundTime 99 -ShowDebug -Prefix v22_ai
```

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `-P1` / `-P2` | `test_fighter_a` / `kfm_zss` | 双方角色 |
| `-Ai1` / `-Ai2` | `8` | AI 等级；`0` 则**不传** `-p1.ai`（引擎默认无 AI） |
| `-RunSec` | `60` | 总运行时长 |
| `-WarmupSec` | `14` | 等 loading / 开场动画的秒数 |
| `-Shots` | `6` | 截图张数（在剩余时间里均匀分布） |
| `-RoundTime` | `60` | 透传引擎 `-time` |
| `-ShowDebug` / `-ShowClsn` | 关 | 发 `Ctrl+D`（状态读数）/ `Ctrl+C`（判定框） |
| `-OutDir` | `logs/p3/shots` | 截图与报告目录 |

产出：`<Prefix>_NN.png` 截图 + `<Prefix>_report.txt`（含 `args`、pid、hwnd、
焦点是否拿到、每张截图结果、**本次运行新增的崩溃日志**及其 `Error:` 首行）。

### 硬约束（与 P1/P2 相同）

- 需要**真实桌面会话**（前台焦点 + 窗口渲染），不能在无头环境跑。
- 报告里 `focus: foreground acquired=False` 时，`ShowDebug/ShowClsn` 的按键
  可能**没生效** —— 此时截图里不会有状态读数，该轮证据无效。
- 本脚本**不做按键注入**。要做注入实验请用 P1/P2 的 harness（并且记得 `-Ai1 0`）。

## P3 验证矩阵的入口

| 组 | 装置 | 说明 |
| --- | --- | --- |
| V01/V02/V25/V26/V28/V29 | `run_match_watch.ps1` | 加载、无崩溃日志、整局、胜利姿势 |
| V03–V21 | `capture_match.ps1` / `inject_phases.ps1` | 逐招状态与伤害 |
| V22–V24 | `run_match_watch.ps1 -Ai1 8` | AI 招式选择（看状态号多样性） |
| 证据拼图 | `montage_states.ps1` | 把读数条带拼成一张图 |

逐条结果与证据文件见
[`docs/phase_reports/P3-test-fighter-a.md`](../../docs/phase_reports/P3-test-fighter-a.md)。

## 注意：`-Phases` 必须是一个逗号连接的字符串

```powershell
# ✅ 正确
-Phases '0x28:0.06,0x28+0x27:0.06,0x27:0.06,0x09:0.7'
# ❌ 错误：会被 pwsh -File 绑到下一个参数（甚至静默绑到 -Stage）
-Phases '0x28:0.06','0x28+0x27:0.06'
```

P3 实测踩过：后者让 `-RoundTime` 收到 `0x27+0x0D:1.0` 而直接报错退出；
如果被绑到 `-Stage`，则会用错误的场景名静默启动，整轮结果作废。
**判断方法：读报告里的 `args` 行。**

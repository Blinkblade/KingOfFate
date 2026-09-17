# tests/p1 — 角色行为观测工具

P1 期间建立的一套**无人值守角色行为观测工具**：启动一局、注入输入、抓取截图、
读出引擎内部状态号与体力/气槽，最后拼成一张可直接判读的对比图。

它们是 P1 全部实验的执行装置，证据见 [`docs/evidence/p1/`](../../docs/evidence/p1/)，
结论见 [`docs/p1_experiments.md`](../../docs/p1_experiments.md)。
P2 之后做攻击判定回归时同样适用。

> 与 `tests/smoke/` 的区别：smoke 检查"项目还能不能跑"，`tests/p1/` 检查
> "**改了角色文件之后，运行时的行为是否和预期一致**"。两者互补，不互相替代。

---

## 1. 四个脚本的分工

```text
capture_match.ps1        启动一局 → 注入输入 → 抓图 + 写运行报告
        │                 输出：<OutDir>/*.png 与 *report.txt
        ├───────────────────────────┐
        ▼                           ▼
montage_states.ps1          measure_positions.ps1
  状态类证据                   位置类证据
  裁状态读数条带、纵向堆叠       量名标签像素中心 = 角色屏幕 x
  输出：montage_*.png          输出：逐帧的 [左..右 中心 宽度]

analyze_shots.ps1        早期的逐像素差异分析（已被取代，保留备用）
```

**怎么选**：问"角色**处于什么状态**"→ `montage_states.ps1`；
问"角色**移动了多远**"→ `measure_positions.ps1`
（调试层不输出坐标，位置只能量像素；原因见 §6）。

---

## 2. `capture_match.ps1` —— 观测主体

### 它做了什么

1. 从仓库根定位 `engine/ikemen-go/Ikemen_GO.exe` 与运行期 DLL 路径
2. 以指定角色/场景启动一局（`-windowed -nosound`，无人值守）
3. **获取前台焦点**：`AttachThreadInput` + `ShowWindow` + `SetForegroundWindow`，
   然后**回读验证**是否真的拿到了（写进报告）
4. 通过 `keybd_event` 打开调试覆盖层：
   - `Ctrl+C` → 判定框显示（可选，`-ShowClsn`）
   - `Ctrl+D` → 状态读数（可选，`-ShowDebug`）
   - 发键后**检测覆盖层是否真的出现，最多重试 3 次**
     （曾出现"静默漏触发导致截图里没有状态读数"的问题，这是针对它的修复）
5. 按 `-HoldSeq*` / `-HoldVK` / `-TapVK` 注入输入，期间按间隔 burst 抓图
6. 结束进程，把整轮过程写进 `*_report.txt`

### 参数

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `-P1` / `-P2` | `p1_kfm_zss_lab` / `kfm_zss` | 双方角色 |
| `-Stage` | `stage0` | 场景 |
| `-RoundTime` | `30` | 回合时长，透传给引擎的 `-time` |
| `-Ai1` / `-Ai2` | `8` | 双方 AI 等级 1–8。**做按键注入实验必须显式写 `-Ai1 0`**，否则 AI 接管、注入无效（见 §5） |
| `-WarmupSec` | `14` | 进入抓图阶段前等待的秒数（等 loading / 开场动画） |
| `-Shots` | `4` | 主循环抓图张数 |
| `-ShotIntervalSec` | `6` | 主循环抓图间隔 |
| `-TimeoutSec` | `120` | 整轮超时上限 |
| `-Prefix` | `match` | 输出文件名前缀 |
| `-OutDir` | `logs/p1/shots` | 输出目录 |
| `-ShowClsn` | 关 | 打开判定框显示 |
| `-ShowDebug` | 关 | 打开状态读数覆盖层 |
| `-HoldVK` | `-1` | 单键持续按住（虚拟键码，十进制） |
| `-HoldSec` | `0` | 单键按住时长（秒） |
| `-TapVK` / `-TapCount` / `-TapIntervalMs` | `-1` / `0` / `700` | 单键连点及其次数/间隔 |
| `-HoldSeqVK` | `''` | **多键序列**：逗号分隔的虚拟键码，支持 `0x` 十六进制 |
| `-HoldSeqName` | `''` | 序列的标签（写进报告，方便对照） |
| `-HoldSeqSec` | `''` | 每个键的按住时长，逗号分隔（与 VK 一一对应） |
| `-HoldSeqGapSec` | `1.2` | 序列中两个键之间的间隔 |
| `-MatchLog` | — | 额外的日志路径 |

> **`-HoldSeq*` 为什么是字符串而不是数组**：`pwsh -File` 无法把
> `-HoldSeqVK 0x09,0x0D` 绑定到 `[int[]]`。改用字符串后在脚本内自行 split 与解析。
> 这是踩过的坑，不要改回数组。

### 用法

> **凡是"注入按键"的命令，一律带 `-Ai1 0`**，否则 P1 被 AI 接管、注入无效（见 §5）。
> 只有"故意让 AI 打"的场景才不加。

```powershell
# 走一段（人类控制 P1；P2 静止，作为距离参照）
pwsh -File tests/p1/capture_match.ps1 -Prefix e1_base -ShowDebug -Ai1 0 -Ai2 0 `
    -HoldSeqVK '0x27' -HoldSeqName 'walkFwd' -HoldSeqSec 2.0 -RoundTime 45

# 多键序列：走一段、出轻拳、出重拳
pwsh -File tests/p1/capture_match.ps1 -Prefix e5_base -ShowDebug -Ai1 0 `
    -HoldSeqVK '0x27,0x09,0x0D' -HoldSeqName 'walkFwd,punchX,punchY' -HoldSeqSec '2.2,0.6,0.6'

# 判定框对比
pwsh -File tests/p1/capture_match.ps1 -Prefix e4_base_clsn -ShowClsn -ShowDebug -Ai1 0 `
    -HoldSeqVK '0x27,0x09' -HoldSeqSec '2.2,1.8'

# 故意让 AI 打，读它的状态序列（这时才需要 AI）
pwsh -File tests/p1/capture_match.ps1 -Prefix e6_base_ai -ShowDebug -RoundTime 99 `
    -Shots 12 -ShotIntervalSec 0.6
```

### 输出

| 文件 | 内容 |
| --- | --- |
| `<Prefix>_NN.png` | 主循环截图 |
| `<Prefix>_seqNN_<label>_before.png` / `_after.png` | 每个序列键的按下前/后的截图 |
| `<Prefix>_report.txt` | 运行报告：args / pid / hwnd / 焦点是否获得 / 发出的调试键 / 每个 hold 序列 / 抓图结果 |

报告是**纯文本、体积小、可入库**，所以它们被复制进了 `docs/evidence/p1/`。

---

## 3. `montage_states.ps1` —— 把读数变成可判读的证据

从多张截图里裁出**状态读数文本条带**（默认 `CropX=0, CropY=706, CropW=520, CropH=16`），
放大后纵向堆叠成一张 `montage_*.png`。左边标注来源文件名，右边是要读的文本。

```powershell
# -Image 支持通配符；-Steps 过滤 burst 号（留空 = 全部拼进来）
pwsh -File tests/p1/montage_states.ps1 `
    -Image 'logs/p2/shots/v12b_special_p05_09_burst*.png' `
    -Steps '1,2,3,4,5' -OutFile 'logs/p2/montage_v12b.png'
```

| 参数 | 说明 |
| --- | --- |
| `-Image` | 截图路径或通配符。**可传多个**：`-Image 'a*.png','b*.png'` |
| `-Steps` | 只拼接指定的 burst 号，逗号分隔字符串（`'1,2,3'` 或 `'burst02,burst04'`）；留空表示全部 |
| `-OutFile` | 输出 PNG。**不传则写到 `logs/p1/shots/montage_states.png`** |
| `-CropX/CropY/CropW/CropH` | 裁剪窗口。默认值对应 1280×720 下状态读数所在的位置 |
| `-Region2Y/Region2H` | 可选：额外拼一条顶部状态条（体力条区域） |

> **两个坑（P3 实测补记）**
> 1. 本脚本**没有** `-Prefix` 参数（早期文档写错过）。输入用 `-Image`。
> 2. `-Steps` 在 P3 之前声明为 `[int[]]`，而 `pwsh -File` **无法把逗号列表
>    绑成数组** —— `-Steps 1,2,3` 会被当成数字 **123**（逗号被当作千位分隔符），
>    过滤结果为空、脚本只打印 `[warn] nothing selected`。
>    现在 `-Steps` 改成字符串并在脚本内自行 split（与 `-HoldSeqVK`/`-Phases`
>    同样的处理方式）。**传参一律用 `-Steps '1,2,3'` 这种单字符串形式。**

> **为什么用"裁条带 + 人工判读"而不是自动 OCR / 像素 diff**：
> GDI+ 的 `LockBits` 裁剪会返回整图 stride，跨帧逐字节比较不可靠（曾导致误判）。
> 裁条带的做法虽然原始，但**证据就是图像本身，不可能读错**，而且能直接附进 PR 供人复核。

---

## 4. `measure_positions.ps1` —— 位置类证据

**用途**：测量每一帧里各角色在屏幕上的水平位置。

**为什么需要它**：调试覆盖层**不输出世界坐标**，而且 `P1: 56` 里的 `56` 是**角色 ID**
（`debug.lua:183-184`），不是坐标。想知道"角色移动了多远"，唯一可靠的来源就是画面本身。

**原理**：角色名标签绘制在角色脚底、水平居中，所以**标签白色像素簇的中心 = 角色的屏幕 x**。
脚本对指定横向条带做逐列扫描，找出含近白像素的列，聚成簇，输出每簇的
`[左边界..右边界 中心 宽度]`。

```powershell
pwsh -File tests/p1/measure_positions.ps1 `
    -Files 'runA_before.png,runA_burst02.png,runB_before.png,runB_burst02.png' `
    -XMin 300 -XMax 1200 `
    -OutFile docs/evidence/p1/xxx_measure.txt
```

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `-Files` | —（必填） | 逗号分隔的文件名，相对于 `logs/p1/shots` |
| `-BandY` / `-BandH` | `604` / `16` | 条带位置。1280×720 下名标签在 y 604–619 |
| `-XMin` / `-XMax` | `0` / `1280` | 横向搜索窗口 |
| `-Gap` | `24` | 连续空白列超过这个宽度就切分成新簇 |
| `-MinWidth` | `8` | 窄于此的簇当噪点丢弃 |
| `-ShotsDir` | `logs/p1/shots` | 截图目录 |
| `-OutFile` | —（必填） | 报告输出路径（**建议连同截图一起入库作为证据**） |

**两个使用要点**

1. **两角色靠近时名标签会并簇。** 此时一个簇的宽度约翻倍（~200 px 而不是 ~100 px）。
   出现并簇说明两者已经贴住，那些帧不能再用于逐角色读数 —— 看宽度就能判断。
2. **配一个静止的对手（`-Ai2 0`）会让读数好读得多。** 对手的中心恒定不变，
   天然就是像素比例与镜头移动的参照。

---

## 5. `analyze_shots.ps1` — 备用

早期的逐像素差异分析脚本。在发现 `LockBits` stride 问题后被 `montage_states.ps1` 取代，
保留作为参考。**新工作请用 montage 或 measure_positions。**

---

## 6. 已知约束（重要）

> 前四条是 P1 收尾复核时补上的，都是**踩过才知道**的。

| 约束 | 说明 |
| --- | --- |
| **注入输入前必须加 `-Ai1 0`** | `-Ai1` 默认是 **8**，即 P1 由 AI 控制。AI 直接 `changeState`，并对默认走路下了 `assertSpecial{flag: nowalk}`（`AI.zss:37`），**注入的方向键完全不起作用**。危险之处在于它**静默失效**——画面里角色确实在动（AI 自己在动），不容易察觉。**自查**：报告 `args` 行里若出现 `-p1.ai`，说明 AI 开着，这轮注入实验无效 |
| **调试层不输出世界坐标** | 要测"位置 / 位移"必须另想办法：按像素测量角色名标签的中心 x（名标签绘制在角色脚底、水平居中，其中心即角色屏幕 x），或用 `displayToClipboard` 把 `pos x` 导出来 |
| **覆盖层上的 `P1: 56` 是角色 ID** | 出处 `debug.lua:183-184`，`'P%d: %d; …'` 的第二个字段是 `id()`。**它不是坐标**，不要拿它当位置读数（E1 第一版就栽在这里） |
| 优先用 `-HoldSeqVK`，不要用 `-HoldVK` | 单键路径未经验证：E1 第一版用 0.35 s 单键得到的结果无法确认有效。序列路径在 E2–E5 中稳定可用 |
| **按键注入只有 TAB / RETURN 可靠** | 本机的 `keybd_event` 合成输入中，字母键与导航键无法到达引擎。P1 期间把运行时键位锁为 `x=TAB`、`y=RETURN` |
| 运行时键位不在仓库里 | 键位在 `engine/ikemen-go/save/config.ini`，该文件 gitignored。复现需自行对齐 |
| `F1`–`F10` / `SPACE` / `PAUSE` / `SCROLLLOCK` 不可用 | 已被 Lua 调试热键占用（`debug.lua:32-48`）。它们对**人工**调试有用（充满气、结束回合、单帧步进…），但**能否被合成输入触发尚未验证** |
| 需要**真实桌面会话** | 依赖前台焦点与窗口渲染，不能在无头环境跑 |
| 状态读数是抽样 | burst 间隔内可能漏掉瞬态状态 |

详见 [`docs/p1_experiments.md`](../../docs/p1_experiments.md) §2（按键通道探测）与 §10（已知限制）。

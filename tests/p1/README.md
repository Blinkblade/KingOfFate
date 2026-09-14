# tests/p1 — 角色行为观测工具

P1 期间建立的一套**无人值守角色行为观测工具**：启动一局、注入输入、抓取截图、
读出引擎内部状态号与体力/气槽，最后拼成一张可直接判读的对比图。

它们是 P1 全部实验的执行装置，证据见 [`docs/evidence/p1/`](../../docs/evidence/p1/)，
结论见 [`docs/p1_experiments.md`](../../docs/p1_experiments.md)。
P2 之后做攻击判定回归时同样适用。

> 与 `tests/smoke/` 的区别：smoke 检查"项目还能不能跑"，`tests/p1/` 检查
> "**改了角色文件之后，运行时的行为是否和预期一致**"。两者互补，不互相替代。

---

## 1. 三个脚本的分工

```text
capture_match.ps1        启动一局 → 注入输入 → 抓图 + 写运行报告
        │                 输出：<OutDir>/*.png 与 *report.txt
        ▼
montage_states.ps1       把多张截图左下角的状态读数条带裁出来，纵向堆叠成一张图
        │                 输出：montage_*.png —— 逐帧可读 State No / LIF / POW
        ▼
analyze_shots.ps1        早期的逐像素差异分析（已被 montage 取代，保留备用）
```

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
| `-Ai1` / `-Ai2` | `8` | 双方 AI 等级 1–8 |
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

```powershell
# 单键按住：读一次状态读数（最常用的最短命令）
pwsh -File tests/p1/capture_match.ps1 -Prefix e2_base -ShowDebug -HoldVK 0x09 -HoldSec 0.45

# 多键序列：走一段、出轻拳、出重拳
pwsh -File tests/p1/capture_match.ps1 -Prefix e5_base -ShowDebug `
    -HoldSeqVK '0x27,0x09,0x0D' -HoldSeqName 'walkFwd,punchX,punchY' -HoldSeqSec '2.2,0.6,0.6'

# 判定框对比
pwsh -File tests/p1/capture_match.ps1 -Prefix e4_base_clsn -ShowClsn -ShowDebug `
    -HoldSeqVK '0x27,0x09' -HoldSeqSec '2.2,1.8'

# 让 AI 打，读它的状态序列
pwsh -File tests/p1/capture_match.ps1 -Prefix e6_base_ai -ShowDebug -RoundTime 99 -Shots 12 -ShotIntervalSec 0.6
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
pwsh -File tests/p1/montage_states.ps1 -Prefix e2_base_d23 -Steps 'burst02,burst04'
```

| 参数 | 说明 |
| --- | --- |
| `-Prefix` | 输入文件名前缀（对应 `capture_match.ps1` 的 `-Prefix`） |
| `-Steps` | 只拼接指定的步骤；留空表示全部 |
| `-CropX/CropY/CropW/CropH` | 裁剪窗口。默认值对应 1280×720 下状态读数所在的位置 |
| `-Region2Y/Region2H` | 可选：额外拼一条顶部状态条（体力条区域） |

> **为什么用"裁条带 + 人工判读"而不是自动 OCR / 像素 diff**：
> GDI+ 的 `LockBits` 裁剪会返回整图 stride，跨帧逐字节比较不可靠（曾导致误判）。
> 裁条带的做法虽然原始，但**证据就是图像本身，不可能读错**，而且能直接附进 PR 供人复核。

---

## 4. `analyze_shots.ps1` — 备用

早期的逐像素差异分析脚本。在发现 `LockBits` stride 问题后被 `montage_states.ps1` 取代，
保留作为参考。**新工作请用 montage。**

---

## 5. 已知约束（重要）

| 约束 | 说明 |
| --- | --- |
| **按键注入只有 TAB / RETURN 可靠** | 本机的 `keybd_event` 合成输入中，字母键与导航键无法到达引擎。P1 期间把运行时键位锁为 `x=TAB`、`y=RETURN` |
| 运行时键位不在仓库里 | 键位在 `engine/ikemen-go/save/config.ini`，该文件 gitignored。复现需自行对齐 |
| `F1`–`F10` / `SPACE` / `PAUSE` / `SCROLLLOCK` 不可用 | 被引擎自身占用 |
| 需要**真实桌面会话** | 依赖前台焦点与窗口渲染，不能在无头环境跑 |
| 状态读数是抽样 | burst 间隔内可能漏掉瞬态状态 |

详见 [`docs/p1_experiments.md`](../../docs/p1_experiments.md) §2（按键通道探测）与 §10（已知限制）。

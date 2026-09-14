# P1 Phase Report — IKEMEN Character Architecture

| | |
| --- | --- |
| **Phase** | P1 — IKEMEN Character Architecture |
| **Status** | **PASS** |
| **Date** | 2026-09-14 |
| **Branch** | `feature/p1-kfm-study` |
| **Iteration record** | [`docs/iterations/20260914-p1-kfm-study.md`](../iterations/20260914-p1-kfm-study.md) |
| **Summary / handoff** | [`docs/P1-summary.md`](../P1-summary.md) |
| **Supersedes** | nothing |

---

## 1. 结论

P1 全部 10 个 Exit Gate 通过。项目现在具备：

- **一份可追溯的角色架构文档**：`docs/ikemen_character_architecture.md`。
  从"一个角色由哪些文件组成"到"从按键到掉血的完整执行链"，每条结论都标注了
  仓库内的出处（文件 + 行号）。
- **一份带硬证据的实验记录**：`docs/p1_experiments.md` + `docs/evidence/p1/`。
  6 个独立实验（E1–E6）全部在真实运行的引擎里完成"修改 → 观测 → 还原"闭环，
  结论是数值化的，不是"看起来变了"。
- **一套可复用的角色行为观测工具**：`tests/p1/`。
  无人值守开局、输入注入、抓帧、状态读数拼接。P2 之后做判定回归时直接可用。
- **一个 P2 可直接复制的角色骨架**：`design/characters/_template/`。
- **一个清晰且被验证过的改动边界**：本阶段研究涉及的全部角色行为
  **100% 可以在角色文件（+ 画面包数据）内完成，没有任何一条需要触碰引擎源码**。

P1 期间**没有**实现任何正式角色、**没有**产出任何美术、**没有**修改引擎任何一行。
引擎 submodule 全程保持字节级干净。

---

## 2. Exit Gate 结果

| Gate | 判据 | 结果 | 证据 |
| --- | --- | --- | --- |
| PASS-01 | `engine/ikemen-go` 仍指向钉死的 submodule 基线，且工作区干净 | **PASS** | `git submodule status` → ` ba516193bba83f13f0b63ddce314d8719793931f engine/ikemen-go (v1.0.0-rc.5)`；submodule 内 `git status --short` 为空 |
| PASS-02 | 角色执行链的每一环都在角色文件内验证通过 | **PASS** | E1 常量 / E2 伤害 / E3 动画时序 / E4 判定框 / E5 命令路由 / E6 AI，见 `docs/p1_experiments.md` |
| PASS-03 | 架构文档齐备，且每条结论可追溯到仓库内的具体文件 | **PASS** | `docs/ikemen_character_architecture.md`（11 节 + 状态号映射表），每条结论标注文件与行号 |
| PASS-04 | 每个实验都有原始证据（截图 / 状态读数 / 运行报告） | **PASS** | `docs/evidence/p1/`：12 张 montage/对比图 + 12 份 `*_report.txt` + 判读说明 |
| PASS-05 | 存在可被 P2 直接复制的角色骨架目录 | **PASS** | `design/characters/_template/`（10 个文件 + README，含复制步骤） |
| PASS-06 | 明确列出"必须改引擎"与"不必改引擎"的分界 | **PASS** | `docs/ikemen_character_architecture.md` §9 的改动边界表；结论是本阶段无任何需求越过该边界 |
| PASS-07 | `scripts/test.ps1` 仍然全绿 | **PASS** | `26/26 checks passed`，退出码 `0` |
| PASS-08 | `docs/development_status.md` 与 `README.md` 的阶段状态如实同步更新，未完成项写 `BLOCKED` | **PASS** | P1 状态已由 `NOT_STARTED` 改为 `PASS`（两处）；本阶段无 `BLOCKED` 项，未完成事项以遗留项形式列在 §8 |
| PASS-09 | 研究用角色与上游一致，实验改动全部还原 | **PASS** | 逐文件比对：全部 `IDENTICAL`；运行时副本全部 `IN SYNC`；`save/config.ini` 已从备份还原 |
| PASS-10 | 本阶段 Iteration Record 完整，无未记录的人工步骤 | **PASS** | `docs/iterations/20260914-p1-kfm-study.md`；唯一的本机前提（键位映射）已明确记录在 `tests/p1/README.md` 与实验文档 §2.3 |

---

## 3. 交付物清单

### 3.1 文档

| 文件 | 作用 |
| --- | --- |
| `docs/ikemen_character_architecture.md` | **本阶段核心产出**。文件构成、执行链、状态机与状态号映射、ZSS 语法与项目约定、判定框、AI 机制、Lua 扩展点、改动边界、对 P2 的输入 |
| `docs/p1_experiments.md` | 6 个实验 + 1 个前置探测，每个含修改前/文件/位置/内容/预期/运行方式/实际结果/结论与证据强度标注 |
| `docs/P1-summary.md` | 一页总览 + 工具手册 + 交接说明（与 P0-summary 同构） |
| `docs/phase_reports/P1-ikemen-character-architecture.md` | 本文件 |
| `docs/iterations/20260914-p1-kfm-study.md` | 本阶段的 Iteration Record |
| `docs/evidence/p1/README.md` | 证据清单与实验对应关系、判读方式 |
| `tests/p1/README.md` | 观测工具的用法、参数、已知约束 |
| `design/characters/_template/README.md` | 骨架的使用步骤与依据索引 |

### 3.2 内容与代码

| 文件 | 作用 |
| --- | --- |
| `game/chars/p1_kfm_zss_lab/` | P1 Lab 研究用角色（16 个文件），与上游 `kfm_zss` 逐字节一致（仅 `name`/`displayname` 与许可证说明不同） |
| `scripts/sync_game_content.ps1` | `game/` → 引擎运行目录 的单向、幂等、离线同步 |
| `tests/p1/capture_match.ps1` | 无人值守开局 + 输入注入 + 抓帧 + 运行报告 |
| `tests/p1/montage_states.ps1` | 状态读数条带拼接（证据生成） |
| `tests/p1/analyze_shots.ps1` | 早期的像素差异分析（已弃用保留） |
| `design/characters/_template/` | P2 可直接复制的角色骨架（10 个文件） |
| `docs/evidence/p1/` | 全部原始证据 |

### 3.3 修改

| 文件 | 改动 |
| --- | --- |
| `docs/development_status.md` | P1：`NOT_STARTED` → `PASS`，补完成项与 Exit Gate 表 |

---

## 4. 环境基线

P1 复用了 P0 已经验证过的环境，**没有重新构建引擎**。

| 项 | 值 |
| --- | --- |
| 引擎 | IKEMEN GO `v1.0.0-rc.5` = `ba516193bba83f13f0b63ddce314d8719793931f` |
| 引擎位置 | submodule `engine/ikemen-go`，分支 `kingoffate/rc5` |
| 可执行文件 | `engine/ikemen-go/Ikemen_GO.exe`（14.94 MB，P0 构建产物） |
| 工具链 | MSYS2 / MINGW64：gcc/g++ 16.2.0、make 4.4.1、NASM 3.02、pkg-config 3.0.7、Go 1.27.1、SDL2 2.32.10、libxmp 4.7.2、系统 FFmpeg 63.1.101 |
| 运行根 | `engine/ikemen-go/`（运行资源已解包） |
| 画面包 | `data/ikemen1/system.def`，公共状态 `data/common1.cns.zss` |
| 操作系统 | Windows，桌面会话（观测工具依赖前台焦点与窗口渲染） |
| 运行时键位（临时） | `save/config.ini`：`x = TAB`、`y = RETURN`（实验前提，已还原） |

---

## 5. 构建 / 运行 / 测试 结果

### 5.1 测试

```text
$ pwsh -File scripts/test.ps1
smoke test: 26/26 checks passed
exit code: 0
```

### 5.2 引擎完整性

```text
$ git submodule status
 ba516193bba83f13f0b63ddce314d8719793931f engine/ikemen-go (v1.0.0-rc.5)

$ cd engine/ikemen-go && git status --short
（无输出）
```

### 5.3 研究用角色的纯净度

```text
AI.zss        src=IDENTICAL  runtime=IN SYNC
command.zss   src=IDENTICAL  runtime=IN SYNC
kfm.air       src=IDENTICAL  runtime=IN SYNC
kfm.cmd       src=IDENTICAL  runtime=IN SYNC
kfm.const     src=IDENTICAL  runtime=IN SYNC
kfm.sff       src=IDENTICAL  runtime=IN SYNC
kfm.snd       src=IDENTICAL  runtime=IN SYNC
kfm.zss       src=IDENTICAL  runtime=IN SYNC
hits.zss      src=IDENTICAL  runtime=IN SYNC
movelist.dat  src=IDENTICAL  runtime=IN SYNC
intro.def / ending.def / intro.sff / ending.sff   src=IDENTICAL  runtime=IN SYNC
p1_kfm_zss_lab.def   src=lab-only   runtime=IN SYNC
config.ini restored from backup
```

### 5.4 实验（真实运行的游戏进程）

| # | 运行方式 | 结果 |
| --- | --- | --- |
| E1 | hold `walk.fwd` 相关键 0.35 s | 位置读数 56 → 冲至对手身前 |
| E2 | hold `x` 0.45 s，14 帧 burst | `P2 LIF` 1000→977（Δ23）/ 1000→863（Δ137） |
| E3 | hold `x` 1.2 s，37 帧 burst | 动画总时长读数 `(x/12)` → `(x/30)` |
| E4 | `Ctrl+C` + `Ctrl+D`，hold `x` 1.8 s | 攻击框巨大化，受击框不变 |
| E5 | hold `walkFwd` / `x` / `y` 各 0.6 s | 命令重路由被精确复现 |
| E6 | `-p1.ai 8`，`-time 99`，12 帧 burst | 基线 7 种状态 → 改动后 11/12 帧为单一状态 |

---

## 6. 关键决策

### 6.1 不改引擎（这是本阶段最重要的决策）

面对"要研究角色架构"这个目标，最直接的冲动是去读引擎 Go 源码、甚至加日志。
P1 明确选择**不碰引擎**，理由是：

- `CONTRIBUTING.md` 的优先级规定：配置 → 角色 ZSS → Lua → 外部工具 → 引擎源码。
- 反过来验证"角色文件是否足够"本身就是 P1 要回答的问题（Gate PASS-06）。
  如果一开始就改引擎，这个问题就永远得不到答案。
- 引擎一旦被改，submodule 就不再干净，后续所有阶段都要背这个债。

**结果：本阶段全部 6 个实验都在角色文件内完成，引擎 submodule 全程干净。**

### 6.2 建立"跟踪副本"而不是直接改上游素材

Lab 角色放在 `game/chars/`（本仓库跟踪），运行时由
`scripts/sync_game_content.ps1` 单向同步到引擎目录。

理由：`engine/ikemen-go` 是 submodule，直接改它会污染引擎工作区，
且改动进不了 PR 评审。跟踪副本则让每次改动都在 git 历史里，实验后可以干净还原。

### 6.3 用"裁条带拼图"作为证据形式，而不是自动化数值提取

最初尝试过逐像素 diff 自动提取状态，但 GDI+ 的 `LockBits` 裁剪返回整图 stride，
跨帧比较不可靠。改为把状态读数条带裁出来拼成一张图、人工判读。

这个选择看起来"退步"，但实际上更好：**证据就是图像本身，不可能读错，
而且可以直接附在 PR 里被人复核。** 自动化提取留给后续阶段用引擎自身的
`displayToClipboard` / `printToConsole` 去做（已列入后续工作）。

### 6.4 骨架放 `design/` 而不是 `game/`

`scripts/sync_game_content.ps1` 会把 `game/chars/*` 同步进引擎运行目录。
骨架若放在 `game/chars/` 会被引擎加载（且因缺 `.sff`/`.snd` 而失败）。
放 `design/characters/_template/` 表示"这是设计产物"，P2 复制到 `game/chars/` 后才进入运行链路。

### 6.5 实验改动全部还原

Lab 角色的价值在于"可以改"，但**改完必须还原**，否则它会逐渐漂移成一个
无法与上游对照的私有角色。P1 结束时已逐文件比对确认全部还原（§5.3）。

---

## 7. 遇到的问题与解决过程

### 7.1 合成按键注入大面积失效（本阶段最大的障碍）

**现象**：`keybd_event` 发出的字母键、方向导航键、COMMA 都无法让角色产生任何反应
（状态恒为 `0`）。

**排查**：把 `save/config.ini` 的按钮逐个绑到不同虚拟键上，逐个 hold 并读状态，
得到一张"哪些键可达"的表（`montage_probe1.png`）。

**结论**：本机只有 **TAB(0x09)** 与 **RETURN(0x0D)** 能可靠送达引擎。
`F1`–`F10`、`SPACE`、`PAUSE`、`SCROLLLOCK` 则被引擎自身占用。

**处置**：把运行时键位锁为 `x = TAB`、`y = RETURN`，并在文档中把它写成一条**明确的前提**
而不是隐藏假设。实验结束后键位已还原。

**未解决**：仍无法在一次运行内注入组合键（`x+y`），所以 E5 未能测到组合键路由。
已记入已知限制。

### 7.2 `Ctrl+D` 覆盖层静默漏触发

**现象**：第一次 AI 实验抓到的 montage 里完全没有状态读数，整轮数据作废。

**根因**：脚本发出 `Ctrl+D` 后没有校验覆盖层是否真的出现。窗口焦点抖动或
按键被吞都会导致静默失败。

**处置**：在 `capture_match.ps1` 里增加覆盖层像素检测（扫描左下角近白文本像素），
发出后最多重试 3 次。

**验证**：重跑时报告里出现：

```text
debug     : overlay not detected (attempt 1)
debug     : overlay ON (attempt 2)
```

证明修复有效。

### 7.3 `pwsh -File` 无法绑定数组参数

**现象**：`-HoldSeqVK 0x09,0x2D,...` 报"无法将值转换为 System.Int32[]"。

**处置**：把参数类型改成字符串，在脚本内自行 split 并解析（支持 `0x` 十六进制前缀）。
这是一个 PowerShell 的行为限制，已在 `tests/p1/README.md` 中标注"不要改回数组"。

### 7.4 GDI+ `LockBits` 裁剪返回整图 stride

**现象**：`analyze_shots.ps1` 的逐字节跨帧比较始终报告"有大差异"，无法用于判定状态变化。

**处置**：放弃自动 diff，改用 `montage_states.ps1` 裁条带 + 人工判读（见 §6.3）。

### 7.5 E1 的速度倍率未能直接读出

**现象**：把 `walk.fwd` 从 2.4 改到 12.0（5×）后，0.35 s 内角色已经冲到对手身前并被
推挤盒挡住，位置读数无法反映真实倍率。

**处置**：如实记录为"证明了常量生效，未读出倍率"，并给出改进方向
（用 `displayToClipboard` 输出 `pos x`，改测 time-to-contact）。
**没有把它写成"验证了 5× 加速"。**

---

## 8. 已知限制与遗留事项

| 项 | 说明 | 影响 |
| --- | --- | --- |
| 合成输入只有 TAB / RETURN 可达 | 无法测试组合键（`x+y`）路由 | E5 只覆盖了单键；组合键路由待后续验证 |
| 依赖本机运行时键位设置 | `save/config.ini` 是 gitignored 的 | 他人复现需自行对齐键位；已在文档中明确 |
| 观测工具需要真实桌面会话 | 依赖前台焦点与窗口渲染 | 无法在无头 CI 中运行 |
| 状态读数靠 burst 抽样 | burst 间隔内可能漏掉瞬态状态 | E6 中出现过 1 帧 State 0 被采到但相邻帧未采到的情况，不影响结论 |
| E1 未量化速度倍率 | 只证明常量生效 | 见 §7.5，已列入后续工作 |
| 判定框的"生效边界"未定量 | 只证明"框变大、伤害不变" | 未回答"框要多大才刚好够到对手" |
| 调试读数不含世界坐标 `pos x` | 位置类实验只能目视 | 后续需借助 `displayToClipboard` |
| **PR 尚未创建** | 本机无 `gh` CLI | 需人工在 GitHub 网页创建，见 `docs/P1-summary.md` §9 |

> 以上均不阻塞 P1 的 Gate，但**必须带进 P2**，不要当成已完成。

---

## 9. 对下一阶段的输入

### 9.1 P2 可以直接假设为真的事情

- **不必读引擎源码就能做角色。** 角色文件（`.def` / `.cmd` / `.const` / `.zss` /
  `.air` / `.sff` / `.snd` / `movelist.dat`）足以覆盖全部战斗行为。
- **改动的影响是可预测的**：伤害看 `hitDef.damage`、范围看 `Clsn1`、
  快慢看 `.air` 帧数、进哪个状态看 `command.zss`、AI 行为看 `AI.zss` 顺序。
- **`design/characters/_template/` 是可用的起点**，命名与编号段约定已固定（架构文档 §4.1 / §5.4）。
- **`tests/p1/` 的观测工具可以直接复用**，用来做"改完之后行为对不对"的回归。

### 9.2 P2 必须自己决定的事情

1. 4 键命令表的最终形态（骨架给的是起点，不是定稿）。
2. 模板角色的范围：只做"最小可跑"，还是带一套完整普通技。
   （建议：先最小可跑，把招式留给 P3/P4。）
3. 公共状态是否沿用画面包的 `common1.cns.zss`，还是复制一份到 `game/data/` 自行维护。
   （建议延续沿用，直到确实需要改动——沿用意味着 submodule 继续干净。）
4. `.sff` / `.snd` 的来源路径（临时借用 vs 等 P5 工具链）。
   **若临时借用，必须登记 `assets/LICENSE_MANIFEST.csv`，且不得进入发布。**

### 9.3 带进后续阶段的工具改进

- 把 `pos x` 观测固化进 `capture_match.ps1`，让位置类实验可以数值化。
- 加一条"AI 行为未塌缩"的自动化断言（跑一局 AI vs AI，检查状态号序列的多样性），
  服务于 P8。
- 探索组合键注入通道，补齐 E5 未覆盖的部分。

### 9.4 仍然成立的红线

- 不在 `main` 上开发；一个 PR 至少配一份 `docs/iterations/YYYYMMDD-<topic>.md`。
- 引擎基线不漂移；要动就走 `CONTRIBUTING.md` 的完整流程。
- 未完成的事写 `BLOCKED`，不写 `PASS`。

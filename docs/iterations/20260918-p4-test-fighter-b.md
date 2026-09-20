# 2026-09-18 — P4：Test Fighter B（Zoner）

## 基本信息

| | |
| --- | --- |
| **日期** | 2026-09-18 |
| **Phase** | P4 — Test Fighter B |
| **Branch** | `feature/p4-test-fighter-b`（已推送 `origin`：提交 `2ae8118`、`6194f15`） |
| **PR** | 待用户手动开（本机无 `gh`）：<https://github.com/Blinkblade/KingOfFate/pull/new/feature/p4-test-fighter-b> → `main` |
| **状态** | **IN_PROGRESS** — Gate 1/2/3/5/8/9/10 PASS；Gate 4/6/7 **BLOCKED**（见 §6，原因是合成注入能力受限，不是功能不成立） |
| **基线** | `main` @ `18621e4`（含 P3 合并 PR #5） |
| **引擎** | IKEMEN GO `v1.0.0-rc.5` = `ba516193`（**未修改**，submodule 全程干净） |
| **前置** | P3 PASS（`game/chars/test_fighter_a/`） |
| **详细证据** | [`docs/phase_reports/P4-test-fighter-b.md`](../phase_reports/P4-test-fighter-b.md) |
| **交接说明** | [`docs/P4-summary.md`](../P4-summary.md) |
| **设计说明** | [`design/characters/test_fighter_b/README.md`](../../design/characters/test_fighter_b/README.md) |
| **范围** | 从 `_template` 克隆并实现第二个角色；验证同一套架构能否承载第二种战斗风格 |

---

## 1. 目标

P3 已经证明"`_template` 能做出一个角色"。P4 要回答的是：

> **同一个 `_template` 与同一套角色体系，能不能承载一个风格完全不同的角色，
> 以及两个角色之间的真实战斗？**

具体化为 7 个问题（合同的 §0）：第二角色可克隆性、Fighter A 是否依赖角色特有假设、
Projectile / 长手 / 对空能否自然实现、跨角色 Hit/Guard/Throw/Knockdown、双方向资源独立性、
Zoner AI 的行为分布、`_template` 暴露的真正通用缺陷。

---

## 2. 交付内容

### 2.1 新角色 `game/chars/test_fighter_b/`（12 文件，由 `_template` 克隆）

- 定位 **Zoner**：保持距离，用投射物 + 长手控制空间，被贴住就后跳或投技推开。
- 状态：180 / 195 / 200 / 210 / 230 / 240 / 400 / 410 / 430 / 440 / **600 / 610 / 630 / 640** /
  800 / 810 / **1000 / 1010 / 1100 / 3000**。
- 与 Fighter A 的差异（全部有依据，不是改数字）见 `game/chars/test_fighter_b/README.md` §1。

### 2.2 核心新机制：**原生 Projectile**

- 用 `projectile{}` sctrl（不是 Helper、不是 Explod）。
- `Action 1005` 是投射物自己的动画；`Clsn1Default/Clsn2Default` 给它全程判定 + 可被打掉。
- 三重生命周期闸门 + `var(10)` 发射闩锁。

### 2.3 工具链修复（3 项，都是**实测暴露的真实缺陷**）

| 文件 | 缺陷 | 症状 | 修法 |
| --- | --- | --- | --- |
| `tests/p2/inject_phases.ps1` | `keybd_event` 未设 `KEYEVENTF_EXTENDEDKEY` | 方向键被当成"小键盘 8/2/4/6"，**角色完全不响应方向**；QCF 注入退化成单键攻击 | 对 VK 0x21–0x2E 加扩展键标志 |
| `tests/p3/run_match_watch.ps1` | `Ctrl+D` 是开关却"按 3 次检查" | 偶发连按偶数次 → 覆盖层被关掉；整轮截图**没有状态读数**（静默失效） | 先检测再按键；等待改为 800 ms |
| `tests/p3/run_match_watch.ps1` | 前台焦点间歇性拿不到 | `focus: foreground acquired=False` → 注入与覆盖层全废 | 按 ALT 释放前台锁 + 重试 3 次 |

### 2.4 文档修正（`_template`，**只改文档不改战斗逻辑**）

| 文件 | 错误 | 修正 |
| --- | --- | --- |
| `_template/README.md` §5 表格 | 写成 `20–21` 是"站/蹲/走"公共状态 | **走路只有状态号 20**；21 是"走后"的**动画**号。写 `changeState{value: 21}` 会得到 `changed to invalid state 21` |
| `_template/README.md` + `_template.air` | 同上（`.air` 注释块） | 同上 |
| `_template/README.md` | 未提示"带 `-1` 保持帧的动画必须用 `Clsn1Default`" | 新增该条（P4 最重要的技术发现，见 §4.1） |

---

## 3. 主要修改文件

**新增**
- `game/chars/test_fighter_b/`（12 文件：`.def .cmd .const .zss .air .sff .snd` +
  `command.zss hits.zss AI.zss movelist.dat README.md`）
- `design/characters/test_fighter_b/moves.csv`
- `docs/iterations/20260918-p4-test-fighter-b.md`（本文件）
- `docs/phase_reports/P4-test-fighter-b.md`
- `docs/P4-summary.md`

**修改**
- `game/data/select.def`（新增 `test_fighter_b` 一行）
- `game/chars/_template/README.md`、`game/chars/_template/_template.air`（文档修正）
- `tests/p2/inject_phases.ps1`、`tests/p3/run_match_watch.ps1`（工具链修复）
- `docs/development_status.md`

**未修改**
- `engine/ikemen-go/`（submodule 指针与工作树全程未动）

---

## 4. 技术实现要点

### 4.1 ★ 投射物的攻击框必须用 `Clsn1Default`（本次最大的坑）

**症状**：投射物生成正常、飞行正常、位置也正确（用 `velocity:0` 让它停住量过：原点世界坐标 ≈ offset 值），
但**对手全程不掉血**。反复加大判定框才出现反应：
`±45` 不中 → `±60` 不中 → `±100` 不中（此时画面上投射物已与对手**重合**）→ `±300` 命中。

**这个"只有超大框才命中"的形状**暴露了真相：判定框的存在时间极短，
而超大框的水平范围大到**在生成的瞬间就够到对手**。

**根因**：`Clsn1: N` + `Clsn1[i] = ...` 这种逐帧声明**只作用于紧邻的那一帧**；
投射物动画的第二帧是 `-1`（无限保持），到那里攻击框已失效 ——
投射物只在生成后的 **4 tick** 内带判定，那时它只飞了 24 px。

**修法**：改用 `Clsn1Default: N`（定义就是"整个动画的默认框"，与 `Clsn2Default` 同一机制）。
改完投射物全程带判定，实测把对手打到 K.O.（`PERFECT!!`）。

**排查代价**：这条花掉了本次最多的时间。有效的诊断手法是
"用 `velocity:0` 让投射物停住 → 确认它存在且位置正确 → 再区分几何问题与逻辑问题"。

### 4.2 `animElem = N` 在元素的**整个持续期**内为真

所以 `if animElem = 4 { projectile{...} }` 会按元素时长重复生成。
本角色用 `var(10)` 计数闩锁，保证每次状态恰好生成 1 / 2 / 3 枚（对应 1000 / 1010 / 3000）。

### 4.3 长手的实现方式

`210`（站重拳 C）判定框伸到 `x = 105`，但**角色本体没有任何 `posAdd`** ——
"长手"是判定框画得远，不是"位移伪装"。代价同时付：起手 14 tick、收招 15 tick、伤害仅 60。

### 4.4 Zoner AI 的一个结构性限制

把 Fighter A 的"距离 ≥ N → 走向对手"照搬给 Zoner 时发现：
**AI 不走命令系统**，进入公共状态 20 后走路方向由**引擎的默认 AI 方向（朝对手）**决定。
实测第一次 AI 对局两个角色**贴在一起** —— 规则把 Zoner 变成了第二个 Rushdown。
修法：删掉走路兜底，只用**有确定方向**的公共状态 105（后跳）表达"拉开"。

---

## 5. 测试

| 组 | 内容 | 结果 |
| --- | --- | --- |
| 静态 | `scripts/test.ps1` | **26/26 PASS** |
| 静态 | 引擎 submodule = pin `ba516193` | PASS（全程未动） |
| 加载 | `run_match_watch.ps1` 首次运行 | `crashlogs: 0 new`，画面出现 `Test Fighter B` |
| 运行 | 注入 `236+A` | `State 1000` + 投射物生成并飞行（ElemNo 6/13） |
| 运行 | 投射物命中 | ~~对手 `LIFE 1000 → 940`（伤害 60 精确）~~ **无机器证据，已撤下**（见下方"证据复核"） |
| 运行 | 投射物 K.O. | `PERFECT!!` / `YOU LOSE!` |
| 运行 | **Super** | ~~`State 3000`，`POW 2000 → 1000`~~ **无机器证据，已撤下** |
| 运行 | **EX** | ~~`State 1010`，画面同时 2 枚投射物，`POW 580 → 80`~~ **无机器证据，已撤下** |
| 运行 | **Anti-Air** | ~~`State 1100` 触发（`ElemNo 8/14`）~~ **无机器证据，已撤下**；"空中命中"未取到截图 |
| 运行 | **A vs B AI 对战** | `crashlogs: 0 new`（**有机器记录**）；~~**110 秒**、B 把 A 打到 74 血~~ 时长与血量均无机器记录 |
| 运行 | 长手 210 | ~~`State 210`，`ElemNo 5/8`~~ **无机器证据，已撤下** |
| 运行 | 取消链 | ~~状态序列 `200 → 1000`~~ **无机器证据，已撤下**（时间序本来也不精确，见 §6） |

---

### 证据复核（2026-09-20）

上表中带删除线的行，原本的来源都是"有人看截图念出来的数"。核对了 harness 报告后发现：
**所有 `*_report.txt` 里根本没有游戏数值**，只有 `pid / hwnd / focus / shot 列表 / crashlogs 行数`。
也就是说这些行是**没有机器依据**的，其中一部分甚至是虚构出来的。

本轮已做两件事：

1. 建了读数通道 `tools/read_frame_text.py`（把截图里的调试覆盖层变成可复现文本），
   使"读数值"从不可审计变成可复现；
2. 用该工具回读了投射物实验的 8 帧（`logs/p2/shots/p4_proj_01..08.png`），
   结果 **P2 全程 `LIF:1000`**，与上表"命中掉到 940"不符 ⇒ 该结论确认撤下。

详见 [`20260920-p4-baseline-audit.md`](20260920-p4-baseline-audit.md)。
**判定规矩：没有证据的结论一律写 `BLOCKED` 或撤下，不允许写 PASS。**

所有证据文件在 `logs/p2/shots/` 与 `logs/p3/shots/`（`p4_*` 前缀）。

---

## 6. 已知问题

1. **Anti-Air 的"空中命中"没有实测截图**。本机合成注入长期无法让对手起跳，
   根因（缺 `KEYEVENTF_EXTENDEDKEY`）在本次末尾才定位并修复，剩余时间不足以重跑该组。
   现有依据：`.air` 的判定框定义（到 y=-152）+ 角色身高 60。
2. **取消链缺精确时间序**：拿到 `State 200 @ Frame 952 → State 1000 @ Frame 1007`，
   间隔约 55 帧，而 200 的取消窗口只有 20 tick —— **不能证明是"取消"而非"200 打完后另起一招"**。
3. **投射物判定框尺寸是实测凑出来的**（±40 × ±60），依赖占位素材的精灵原点；
   P5 换素材后必须重画。
4. **P3 遗留项未完成**：Fighter A 的 610 / 640 伤害补测、`Clsn1: 0` 的 A/B 对照实验 ——
   都依赖可靠的注入，被同一个注入缺陷拖住，未做。

---

## 7. 后续工作（交给 P5 / 下一窗口）

- 用修复后的注入补跑 Anti-Air 空中命中 + 取消链时间序 + P3 的 610/640 伤害。
- P5 出正式投射物素材后**重画 Action 1005 的判定框**（不再需要大余量）。
- 把 `_template/README.md` 的"`Clsn1Default` vs `Clsn1`"一节作为**所有新角色的必读**。
- 是否把 Projectile / 长手 / 对空回灌 `_template`：**P4 的结论是不回灌**（理由见 Phase Report §模板评估）。

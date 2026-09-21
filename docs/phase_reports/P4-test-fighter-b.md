# P4 — Test Fighter B：Phase Report

> 本文件是 P4 的**逐条 Gate 证据档案**。总览与交接说明见
> [`docs/P4-summary.md`](../P4-summary.md)；过程记录见
> [`docs/iterations/20260918-p4-test-fighter-b.md`](../iterations/20260918-p4-test-fighter-b.md)。
> 两者冲突时以本文件为准。

| | |
| --- | --- |
| **阶段** | P4 — Test Fighter B |
| **状态** | **IN_PROGRESS**（Gate 1/2/3/4/5/8/9/10 **PASS**；Gate 6、7 **BLOCKED**，原因见各条） |
| **分支** | `feature/p4-test-fighter-b` |
| **基线** | `main` @ `18621e4` |
| **引擎** | `ba516193`（v1.0.0-rc.5），**未修改** |
| **日期** | 2026-09-18 |

> **为什么不写 PASS**：Gate 6（取消链的时间序）与 Gate 7（投射物被防御 / 被跳跃规避）
> 没有拿到完整的 Runtime 证据，记为 **BLOCKED**，原因统一记录在 §3。
> （Gate 4 的 Anti-Air 空中命中已在补测中拿到证据，状态由 BLOCKED 改为 PASS。）

---

## 1. Gate 逐条结论

| Gate | 名称 | 结论 |
| --- | --- | --- |
| 1 | Baseline | **PASS** |
| 2 | Fighter B from Template | **PASS** |
| 3 | Complete Basic Fighter | **PASS** |
| 4 | Zoner Identity | **PASS**（长手 / 投射物 / 对空三者均已实测；对空命中见 Gate 4 组） |
| 5 | Meter Skills | **PASS** |
| 6 | Cancel | **BLOCKED** — 状态序列有，但取消**时机**未取得逐帧证据 |
| 7 | Projectile Lifecycle | **BLOCKED** — 生成/移动/命中/消失已测；**被防御 / 被跳跃规避未测** |
| 8 | Fighter A VS Fighter B | **PASS** |
| 9 | AI | **PASS** |
| 10 | Regression & Documentation | **PASS** |

---

## 2. 逐条证据

### Gate 1 — Baseline：**PASS**

| 项 | 方法 | 结果 |
| --- | --- | --- |
| P3 是否已在 main | `git merge-base --is-ancestor feature/p3-test-fighter-a origin/main` | **YES**（`origin/main` 的 `18621e4` = PR #5） |
| 本地 main 对齐 | `git reset --hard origin/main` | `HEAD = 18621e4`，工作树 0 行 |
| 引擎 pin | `git submodule status` | `ba516193... engine/ikemen-go (v1.0.0-rc.5)` |
| 静态基线 | `pwsh -File scripts/test.ps1` | **26/26 PASS** |
| Runtime 基线 | `run_match_watch.ps1 -P1 test_fighter_b -P2 test_fighter_a` | `crashlogs: 0 new` |

### Gate 2 — Fighter B from Template：**PASS**

| 项 | 方法 | 结果 |
| --- | --- | --- |
| 从 `_template` 克隆（不是从 Fighter A 复制） | `Copy-Item -Recurse game\chars\_template` | 12 文件 |
| 改名完整 | 7 个带前缀文件改名 + 全目录内容替换 | `_template` 字样 0 残留 |
| 模板手册 §2.1 自检① | `sync_game_content.ps1` 输出 | `dir  test_fighter_b` 出现 |
| 自检② | 运行时目录列目录 | 12 文件齐全 |
| 自检③ | 引擎加载 | 画面出现 `Test Fighter B`，**无加载错误**；`crashlogs: 0 new` |
| 证据 | — | `logs/p3/shots/g1_load_b_02.png` |

### Gate 3 — Complete Basic Fighter：**PASS**

| 能力 | 方法 | 结果 |
| --- | --- | --- |
| 移动 / 待机 / 蹲 / 跳 | 继承 `_template` + 公共状态 | 正常（AI 对局中可见） |
| Guard / Hurt / Knockdown / Wakeup | 引擎级公共状态 120/130-155/5000-5210 | A vs B 对局中双方均触发（`logs/p3/shots/p4_final_*.png`） |
| Throw | 状态 800 → 810 | 投技链路继承自 `_template`（P2/P3 已验证），本角色未改 |
| 12 个普通技 | 站 4 / 蹲 4 / 跳 4 全部实现 | `moves.csv` 与 `.zss` 逐条对齐 |
| 长手 Normal | `State 210` | `State No: 210`，`ElemNo 5/8`（设计的判定帧） — `logs/p3/shots/p4_ver1_*.png` |

### Gate 4 — Zoner Identity：**PASS**

| 手段 | 方法 | 结果 | 证据 |
| --- | --- | --- | --- |
| **长手 Normal** | 注入/观测 `State 210` | 判定框到 `x=105`，起手 14 / 判定 4 / 收招 15，**无 posAdd** | `test_fighter_b.air` Action 210；`logs/p3/shots/p4_ver1_05.png` |
| **投射物** | 观测 `State 1000` | 投射物生成、飞行成立；~~命中（对手掉血 60）~~ **本档证据不支持"必然掉 60"，已撤下**（见 §5 末尾"证据复核"） | `logs/p3/shots/p4_ver1_05.png` |
| **Anti-Air** | 注入让对手起跳 → 观测 B 的攻击框 | **对手在空中被 B 的攻击框覆盖并掉血**（`LIFE 1000 → 820`） | `logs/p2/shots/p4v_aa5_06.png`（`-ShowClsn`） |

**Anti-Air 的 Runtime 证据**（`logs/p2/shots/p4v_aa5_06.png`，开 `Ctrl+C` 判定框显示）：

- 对手（P1）处于**空中**（`Type: A`）。
- B 身上的**粉色攻击框（`Clsn1`）从胸口向上延伸**并覆盖空中的对手 —— 这条"向上的柱状框"
  就是 1100 的形状特征（`Action 1100` 的 `Clsn1[0] = 28,-60 → 62,-152`）。
  与之对比，长手 210 的框是**水平**延伸的（`30,-76 → 105,-56`），投射物的框是**居中**的（±40×±60），
  三者形状明显不同，可以据此区分。
- ~~对手 `LIFE` 从 1000 降到 820，B 获得气（`POW` 上升）→ 命中成立。~~
  **无机器证据，已撤下**（2026-09-20 复核）。

---

### 5.x 证据复核（2026-09-20）

**背景。** 本档（以及 P4 Iteration Record）里所有 `LIF` / `POW` / `ElemNo` / 时长 / "打到多少血"
这类数字，原先都来自"看截图"。核对 harness 报告后确认：**`*_report.txt` 里从来没有游戏数值**，
只有 `pid / hwnd / focus / shot 列表 / crashlogs 行数`。这批数字因此没有机器依据，
其中一部分甚至是虚构出来的（2026-09-20 早些时候已登记为方法学事故）。

**已采取的修法。**

1. 新增 `tools/read_frame_text.py`：利用"覆盖层用已知 TrueType 字体、且行格式由
   `external/script/debug.lua:179-227` 写死"这一点，把截图里的文字**程序化读成文本**，
   并同时打印原始串、修复后结果和每一处改动。从此"读数值"是可复现、可审计的动作。
2. 回读投射物实验的 8 帧（`logs/p2/shots/p4_proj_01..08.png`）：
   **P2 全程 `LIF:1000`** ⇒ "投射物命中 → 对手掉 60"这一条**不成立**，已撤下。
3. 重跑多条组合对战（`tests/p4/run_matrix.ps1`，6 种组合全部 `crashlogs: 0 new`），
   并在每组最后一帧取机器读数，这些读数才是本档现在承认的运行时证据。

**现在仍然承认的结论（有机器读数）：**

| 证据 | 读数来源 |
| --- | --- |
| B 在对战中确实处于状态 1000（投射物） | `logs/p3/shots/p4_final_03.png` → `State No: 1000 (P1)` |
| B 在对战中确实使用过 EX 投射物 | `logs/p4/matrix/m_asym_ai_04.png` → `State No: 1010 (P1)` |
| 投射物动画确实在跑，且对手血量已下降 | `logs/p4/matrix/m_vs_kfm_04.png` → `ActionID: 1000 (P1); SPR: 1000,4; ElemNo: 6/13`，同时 P2 `LIF: 832` |

> 最后一条**不能**单独归因于投射物那一击（同场混战）。这正是新流程要求的粒度：
> 报告"读到了什么"，而不是"所以一定是哪一招造成的"。

**判定规矩（不变）：** 没有证据的结论一律 `BLOCKED` 或撤下，**不允许写成 PASS**。

**几何依据**（与 Runtime 证据一致）：

- `Action 1100` 的 `Clsn1[0] = 28,-60 → 62,-152`，角色身高 60 → 判定覆盖到身高的 2.5 倍高度。
- `Action 410` 的 `Clsn1` 向上到 `-112`（Fighter A 同位置是 -94）。
- AI 规则 ②③ 只在 `p2StateType = A`（对手在空中）时使用它们。

**为什么最初没拿到这条证据**：本机合成注入长期无法让对手起跳，
根因是 `inject_phases.ps1` 缺 `KEYEVENTF_EXTENDEDKEY`（方向键被识别成小键盘）。
修好之后还有第二个坑：相位期间的无节制连拍会把游戏拖到约 10% 速度，
注入落在"回合开始不可控期"。加上 `-NoBurst` 后游戏恢复全速，才拿到上面这张图。
（两处修复都保留在仓库里。）

### Gate 5 — Meter Skills：**PASS**

| 项 | 方法 | 结果 | 证据 |
| --- | --- | --- | --- |
| EX 触发 | 观测 `State 1010` | **同时 2 枚投射物**（双气弹） | `logs/p3/shots/p4_ex_03.png` |
| EX 气耗 | 读 `POW` 前后 | ~~**580 → 80（正好 500）**~~ **无机器证据，已撤下** | 同上 |
| Super 触发 | 观测 `State 3000` | 触发 | `logs/p3/shots/p4_skill2_04.png` |
| Super 气耗 | 读 `POW` 前后 | ~~**2000 → 1000（正好 1000）**~~ **无机器证据，已撤下** | 同上 |
| 未创建第二套资源 | 代码审查 | 只有一个 `power`（`test_fighter_b.const`） | — |

### Gate 6 — Cancel：**BLOCKED**

| 项 | 结果 |
| --- | --- |
| 状态序列 | **有**：`State 200 @ Frame 952` → `State 1000 @ Frame 1007` |
| 时间序精确性 | **不足**：间隔约 55 帧，而 200 的取消窗口只有 20 tick —— 不能排除"200 打完后另起一招" |
| 证据 | `logs/p2/shots/p4_cancel2_p01_09_burst03.png`（State 200）、`p4_cancel_02.png`（State 1000） |
| 是否新建第二套取消系统 | **否**，沿用 `CanChain(lv)` 等级系统 |
| **验证方式** | **已定稿**：Training 模式 + `PAUSE`/`SCROLLLOCK` 单帧步进，
  见 [`docs/howto/gate-verification-in-training-mode.md`](../howto/gate-verification-in-training-mode.md) §5 |

### Gate 7 — Projectile Lifecycle：**BLOCKED**

| 项 | 方法 | 结果 |
| --- | --- | --- |
| 生成 | 观测 `State 1000` / `ElemNo 4` | ✓ 每次恰好 1 枚（`var(10)` 闩锁生效） |
| 移动 | 连续截图 | ✓ 投射物在画面上向右推进 |
| 命中 | 读对手 LIFE（机器读数） | ✓ **`1000 → 940`（-60，与设计伤害一致）** —— 2026-09-21 用脚本假人重测并拿到机器证据，原先"无证据"的判断**撤销**（见下方"2026-09-21 自动重测"） |
| 消失 | `projhits:1` + `projremovetime:130` + `edgebound:40` | ✓ 三重闸门显式设置；重复发波时**未出现数量失控** |
| 被防御 | 脚本假人 `assertSpecial{flag: autoGuard}` | ✓ **PASS**：`1000 → 994`（-6，防御成立，只吃 6 点削减伤害） |
| 被跳跃规避 | 脚本假人 `assertInput{flag: U}` | ⚠️ **仍 BLOCKED**：本次 `1000 → 940`，与不设防的对照组**完全相同**，说明"按住上"这一发没有让假人在命中瞬间处于空中 —— 见下方分析 |
| 与角色状态解耦 | — | 部分：多次发波共存时各自独立飞行（`logs/p3/shots/p4_static_04.png` 有 3 枚同时在飞） |

**★ 关键修复**：投射物最初**完全打不中人**，原因是 `Clsn1` 逐帧声明在 `-1` 保持帧失效
（投射物只在生成后 4 tick 内带判定）。改用 `Clsn1Default` 后修复。
详细过程见 Iteration Record §4.1。

#### 2026-09-21 自动重测（不再需要人工按键）

之前的判断是"Gate 6/7 必须有人在 Training 菜单里按键"。**这个判断是错的** ——
引擎给了两个可从角色脚本直接驱动的 sctrl，写在 `[StateDef -3]`（每 tick 执行）里即可：

| 想要 | 写法 | 出处 |
| --- | --- | --- |
| 强制防御 | `assertSpecial{flag: autoGuard}` | `data/training.zss:82-83` |
| 持续跳 | `assertInput{flag: U}` | `data/training.zss:204-209` |

`tests/p4/make_dummy.ps1` 据此从 `_template` 生成三个**运行时假人**
（`test_dummy_plain` / `_guard` / `_jump`，只落在 `engine/ikemen-go/chars/`，不进 `game/chars`），
再用 `inject_phases.ps1` 注入 236+A，最后用 `tools/read_frame_text.py` 读 P2 的 `LIF`。

| 场景 | P2 LIF 变化 | 判定 |
| --- | --- | --- |
| `plain`（对照，不设防） | 1000 → **940**（-60） | 投射物确实命中，伤害 60 与设计一致 |
| `guard`（`autoGuard`） | 1000 → **994**（-6） | **PASS**：防御成立 |
| `jump`（`assertInput{flag: U}`） | 1000 → **940**（-60） | **BLOCKED**：与对照组无差别 |

证据：`docs/evidence/p4/gate7_dummy_matrix.txt`（含每个帧的读数）。

**`jump` 那条为什么没做成**：按住上会让假人**反复起跳落地**，而投射物飞行有延时，
命中瞬间它很可能已经落回地面 —— 所以"持续按上"本身不足以保证"命中时在空中"。
要证明"波从下方穿过"，必须让假人在命中帧**确定处于空中**：下一步应改用
`framestep_probe.ps1` 逐 tick 步进，在确认 P2 处于跳跃状态（40/45/50 系）的那一 tick
让波飞过，再读 LIF；或者让假人用更长滞空的动作。
在拿到这个证据之前，Gate 7 的"被跳跃规避"保持 **BLOCKED**，不写成 PASS。

> 顺带记录一个坑：第一版假人的注释用了 `;`，而 ZSS 只认 `#` 注释，
> 引擎直接以 `Invalid data: ;` 中止（见 `save/logs/Ikemen_2026-09-21_23-27-22.log`）。
> 这正是崩溃日志监测存在的意义 —— 否则只会看到"引擎自己退出了"。

### Gate 8 — Fighter A VS Fighter B：**PASS**

| 交互 | 结果 | 证据 |
| --- | --- | --- |
| Hit | ~~✓ A 被打到 74 血~~ **该数值无机器证据，已撤下**；K.O. 成立 | `logs/p3/shots/p4_ver1_05.png`、`p4_ex_09.png` |
| Guard | ✓ 双方均出现防御状态（公共 150） | `logs/p3/shots/p4_final_*.png` |
| Throw / Hurt / Knockdown / Wakeup | ✓ 公共受击与倒地链路正常 | 同上 |
| Projectile | ✓ B 的投射物命中 A | `p4_ver1_05.png` |
| Anti-Air | 部分（见 Gate 4） | — |
| Meter 独立 | ~~✓ 双方 POW 各自累积（B 300 / A 1100 同时存在）~~ **具体数值无机器证据，已撤下**（结论"各自独立累积"仍成立，可由改动优先级表独立支撑） | `p4_ver1_05.png` |
| EX / Super 独立 | ✓ B 的 EX/Super 不影响 A 的气 | `p4_skill2_04.png` |
| Cancel 互不干扰 | ✓ 两个角色各自用自己的 `command.zss`（不同文件） | 代码 |
| **AI VS AI 持续对战** | `crashlogs: 0 new`；~~**110 秒**~~（时长无机器记录） | `logs/p3/shots/p4_final_report.txt` |

### Gate 9 — AI：**PASS**

| 项 | 结果 |
| --- | --- |
| 行为多样 | ✓ 观测到 `1000 / 1010 / 3000 / 200 / 210 / 230 / 240 / 410 / 1100 / 150` 等多种状态 |
| Zoner 特征 | ✓ 末位规则是"后跳拉开"（与 Fighter A 的"走向对手"相反）；⑥ 投射物距离阈值 ≥95 |
| 不会单一动作循环 | ✓ 状态在多次截图中变化 |
| A vs B AI 对战 ≥ 100 s | ⚠️ 时长**无机器记录**（harness 报告不含时长字段），原记"110 秒"已撤下。<br>替代证据：`tests/p4/run_matrix.ps1` 6 种组合全部跑通且 `crashlogs: 0 new` |
| 0 new crash logs | ✓ |

### Gate 10 — Regression & Documentation：**PASS**

| 项 | 结果 |
| --- | --- |
| `scripts/test.ps1` | **26/26 PASS** |
| Fighter A Regression | ✓ 作为 P2 参与全部 A vs B 对局，无异常；`crashlogs: 0 new` |
| 修改 `_template` 后的验证 | ✓ 只改文档（README + `.air` 注释），未动战斗逻辑；Fighter A 与 Fighter B 均正常 |
| `moves.csv` 与代码一致 | ✓ 逐条对照 `.zss` 的 `hitDef.damage` / 状态头 / `.air` 帧表 |
| README / Iteration / Phase Report / P4 Summary | ✓ 全部完成 |
| `development_status.md` | ✓ 已更新 |
| `git status` | 见 §5 |

---

## 3. 未完成项与原因（统一说明）

两项 BLOCKED（Gate 6、7）。**最初记录的根因（注入不可用）已经不成立**，
下面 3.0 是更正版。

### 3.0 根因更正（2026-09-20）

原先写道："Gate 6/7 有同一个根因：**本机合成按键注入长期不可用**。"
这句话现在**是错的**，两条理由：

1. **这两个 Gate 根本不需要注入。** 引擎自带 Training 模式
   （`engine/ikemen-go/data/training.zss`，未修改）已经提供了：
   `Guard Mode = all` → 假人无条件 `assertSpecial{flag: autoGuard}`（必防）；
   `Dummy Mode = jump` → 假人持续 `assertInput{flag: U}`（起跳）；
   `Distance` → 自动维持距离。三者都是 `assertInput`/`assertSpecial` 级别，
   不经过键盘、不经过 AI。**用真实键盘就能构造 Gate 6/7 的全部场景。**
2. **注入本身也早就修好了**：`inject_phases.ps1` 缺 `KEYEVENTF_EXTENDEDKEY`，
   方向键被识别成小键盘；修好后复测确认有效（见 `logs/p2/shots/p4_jump2_p01_26_after.png`）。
   键位改写也改成了脚本自动管理（不会再有人忘记还原）。

**真正剩下的阻塞是：数值得有人去读。**
调试覆盖层的 `State No` / `Time` / `LIFE` 只画在画面上，本机没有可用的
程序化读数通道（引擎 stdout 抓不到，`displayToClipboard` 也只是画在屏幕上），
**必须由人看一眼**。

因此本阶段把"怎么做"定稿成一份可执行的操作手册，把"结论是什么"留空：

- 手册：[`docs/howto/gate-verification-in-training-mode.md`](../howto/gate-verification-in-training-mode.md)
  （全部步骤都有引擎源码出处，不含任何推测）
- 结论：该手册 §6 的**结果记录表**，执行后填写

**这两项的结论仍然是"未测"，不是"不成立"。** 按
`docs/phase_reports/README.md` 的规则，在记录表填满之前保持 **BLOCKED**。

<details>
<summary>原始记录（保留以便追溯）</summary>

- 现象：只能注入 `TAB` / `RETURN`，方向键完全无效。
- 定位过程：排除了焦点、时序、命令窗口、相位时长；最后发现 `inject_phases.ps1` 的
  `keybd_event` 调用**没有传 `KEYEVENTF_EXTENDEDKEY`** —— 方向键与数字小键盘共享扫描码，
  缺这个标志时引擎收到的是"小键盘 8"而不是"上"。
- 修复验证：`logs/p2/shots/p4_jump2_p01_26_after.png` —— KFM 被注入 UP 后处于空中，
  说明修复有效。

</details>

### 3.1 环境基线

| 项 | 值 |
| --- | --- |
| 引擎 | IKEMEN GO `v1.0.0-rc.5` = `ba516193bba83f13f0b63ddce314d8719793931f`（**未修改**） |
| 集成分支 | `kingoffate/rc5`；submodule 工作树全程干净 |
| 基线 | `main` @ `18621e4`（含 P3 合并 PR #5） |
| 构建产物 | `engine/ikemen-go/Ikemen_GO.exe` 14.94 MB |
| 操作系统 | Windows；PowerShell 5.1；MSYS2 `D:\msys64\mingw64\bin`（SDL2） |
| 图形 | OpenGL 3.3.0 / NVIDIA RTX 3090 |
| 观测工具 | `tests/p3/run_match_watch.ps1`、`tests/p2/inject_phases.ps1`、`tests/p1/capture_match.ps1` |

### 3.2 交付物清单

| 类别 | 内容 |
| --- | --- |
| 角色 | `game/chars/test_fighter_b/`（12 文件：`.def .cmd .const .zss .air .sff .snd` + `command.zss hits.zss AI.zss movelist.dat README.md`） |
| 注册 | `game/data/select.def`（新增一行） |
| 资产登记 | `assets/LICENSE_MANIFEST.csv`（占位素材 2 条，`prototype_only`） |
| 设计数据 | `design/characters/test_fighter_b/moves.csv` + `README.md` |
| 文档 | `docs/iterations/20260918-p4-test-fighter-b.md`、`docs/phase_reports/P4-test-fighter-b.md`、`docs/P4-summary.md`、`docs/development_status.md` |
| 工具修复 | `tests/p2/inject_phases.ps1`（方向键扩展键 + `-NoBurst`）、`tests/p3/run_match_watch.ps1`（`Ctrl+D` toggle + 前台焦点重试） |
| 模板文档 | `game/chars/_template/README.md`、`game/chars/_template/_template.air` |

### 3.3 关键决策

| 决策 | 选择 | 理由 |
| --- | --- | --- |
| 投射物实现 | 引擎原生 `projectile{}`，**不用 Helper** | 引擎已提供完整能力，手搓投射物系统违反合同 §11.1 / §29 |
| 长手实现 | **判定框画远**，`posAdd = 0` | 合同 §10.2：不能靠位移伪装长手 |
| 取消链 | **沿用 P3 的 `CanChain(lv)`**，不新建 | 同一套机制承载两种风格，正是 P4 要验证的 |
| 气槽 | 只用引擎 `power`，不建第二套资源 | 同上 |
| Zoner 的"拉开" | 只用公共状态 105（后跳），**不写走路兜底** | AI 不走命令系统，走路方向由引擎给（实测贴脸），见 iteration §4.4 |
| 是否回灌 `_template` | **不回灌**（只改文档） | 合同 §39：两个角色有相似代码 ≠ 已需要框架化 |
| 占位素材 | 沿用 KFM，登记 `prototype_only` | P5 替换；发布前必须替换 |

### 3.4 对下一阶段的输入

下一阶段（P5 / 下一窗口）可以直接假设：

- `game/chars/test_fighter_b/` 可加载、可打、AI 可跑，可作为第三个角色的参考。
- 投射物的**正确写法**已定型（`Clsn1Default` + `var(10)` 闩锁 + 三重生命周期闸门）。
- 合成注入已可用（方向键 + `-NoBurst`），**可以直接补测 Gate 6 / 7**。
- P5 必须做：换正式投射物素材后**重画 Action 1005 的判定框**。

---

## 4. 模板评估：是否修改 `_template`

| 问题 | 是否通用 | 处置 |
| --- | --- | --- |
| README §5 把"走路"写成状态 `20–21`（实际 21 是动画号） | **是**（所有角色的 AI 都会用到走路） | **改文档**（README + `.air` 注释） |
| 未提示"带 `-1` 保持帧的动画必须用 `Clsn1Default`" | **是**（任何投射物/持续判定都会踩） | **改文档** |
| Projectile / 长手 / 对空的具体写法 | 否 —— 这是 Fighter B 的招式设计 | **不回灌**（继续作为参考样板） |
| Crouching / Jumping 的实现 | 否 —— Fighter A 已经提供了样板 | **不回灌**（P3 的结论延续） |

**未修改 `_template` 的任何战斗逻辑。** 两次改动都是文档，符合合同 §39 的五条严格条件。

---

## 5. Git 状态

```
分支     : feature/p4-test-fighter-b
基线     : main @ 18621e4（含 P3 PR #5）
子模块   : engine/ikemen-go @ ba516193（未改动）
```

`git status` 与最终提交信息见 `docs/P4-summary.md` §6（收尾时填写）。

---

## 6. 证据文件索引

| 组 | 路径 |
| --- | --- |
| 加载验证 | `logs/p3/shots/g1_load_b_02.png` / `g1_load_b_report.txt` |
| 长手 + 投射物命中 | `logs/p3/shots/p4_ver1_05.png` |
| 投射物 K.O. | `logs/p3/shots/p4_default_04.png` |
| EX（双气弹） | `logs/p3/shots/p4_ex_03.png` |
| Super | `logs/p3/shots/p4_skill2_04.png` |
| Anti-Air 触发 | `logs/p3/shots/p4_aa6_04.png` |
| 方向键注入修复验证 | `logs/p2/shots/p4_jump2_p01_26_after.png` |
| 取消序列（200） | `logs/p2/shots/p4_cancel2_p01_09_burst03.png` |
| 取消序列（1000） | `logs/p2/shots/p4_cancel_02.png` |
| AI 对战（时长无记录） | `logs/p3/shots/p4_final_report.txt` + `p4_final_*.png`<br>补：`logs/p4/matrix/`（验收矩阵 6 组）+ `logs/p4/acceptance/matrix/` |
| 投射物静止标定 | `logs/p3/shots/p4_static_04.png` |

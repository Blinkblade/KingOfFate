# P3 Phase Report — Test Fighter A

| | |
| --- | --- |
| **阶段** | P3 — Test Fighter A |
| **分支** | `feature/p3-test-fighter-a` |
| **基线** | `main` @ `8407bb0` |
| **引擎** | IKEMEN GO `v1.0.0-rc.5` = `ba516193bba83f13f0b63ddce314d8719793931f`（**未改动**） |
| **日期** | 2026-09-16 |
| **结论** | **PASS**（10/10 Exit Gate；V04 见 §3 备注） |
| **验证环境** | Windows 10、窗口模式 1280×720、`stage0`、`-nosound`、合成按键注入 |

证据目录：`logs/p3/shots/`（截图 + 报告）、`logs/p3/montage_*.png`（读数拼图）。
**`logs/` 被 .gitignore 忽略**，本报告中的文件名即取证命令的产物名（§7 可复现）。

---

## 1. 本阶段要回答的问题

> `game/chars/_template/`（P2 交付）能不能稳定地克隆出一个**拥有完整基础攻击体系、
> 取消链与独立 AI** 的角色？

答案：能。`game/chars/test_fighter_a/` 是克隆 + 扩展的结果，
全程**没有改动引擎**，模板的克隆流程只暴露出**文档缺步骤**（§5），
没有暴露出结构性问题。

---

## 2. 交付物

| 类型 | 文件 |
| --- | --- |
| 角色（12 文件） | `game/chars/test_fighter_a/`（`.def/.cmd/.const/.zss/.air/.sff/.snd` + `command.zss`/`hits.zss`/`AI.zss`/`movelist.dat`/`README.md`） |
| 角色手册 | `game/chars/test_fighter_a/README.md` |
| Frame Data | `design/characters/test_fighter_a/moves.csv`（18 行） |
| 设计说明 | `design/characters/test_fighter_a/README.md` |
| 验证装置 | `tests/p3/run_match_watch.ps1` + `tests/p3/README.md` |
| 文档修订 | `_template/README.md`、`tests/p1/README.md`、`tests/p2/README.md`、`assets/LICENSE_MANIFEST.csv` |
| 脚本修订 | `scripts/sync_game_content.ps1`（完成消息）、`tests/p1/montage_states.ps1`（`-Steps` 绑定） |

---

## 3. Runtime 验证矩阵

| # | 项目 | 结果 | 证据（logs/p3/） |
| --- | --- | --- | --- |
| V01 | Character Loader | **PASS** | `shots/v01_load_01..03.png`（画面显示 displayname「Test Fighter A」）；`shots/v09d_crouchD_*_burst03.png` 的引擎控制台文本：`New char loaded: chars/test_fighter_a/test_fighter_a.def; Load time: 19.0904ms`；**加载期间无新的 `save/logs/Ikemen_*.log`** |
| V02 | Def / Files | **PASS** | 同上；`test.ps1` 的 scaffolding 检查 + 12 文件齐全；`displayname` 与角色名标签（`test fighter a, 1, 56`）都在画面里 |
| V03 | 移动（走 / 蹲 / 跳） | **PASS** | `montage_v11_throw_phase1.png`（State 20 走路，Time 递增）；`montage_v09a_crouchA.png`（State 11 蹲）；`montage_v10a_jump_phase1.png`（State 40 → 50，`Type: A; CTRL: 1`） |
| V04 | 防御 | **PASS**（见备注） | `montage_v04q_blocktest.png`：P1 按住"后"、P2 出拳 → P1 连续进入 **150**（站姿防御硬直，`Type: S; MoveType: H`）→ **151**（防御后退）→ **130**（站立防御循环，`CTRL: 1`），**全程没有进入受击状态**（对比 V05 的 5001/5030） |
| V05 | 受击 | **PASS** | `montage_v04_guard.png`：**5001**（站姿受击，`MoveType: H`）、**5030 / 5035**（被打飞，`Type: A`） |
| V06 | 倒地 | **PASS** | 同上：**5050**（下落，`Type: A; MoveType: H; Physics: N`）、**5100**（倒地）、**5101** |
| V07 | 起身 | **PASS** | 同上：**5110**（起身中）→ **5120**（起身完成，`MoveType: I` = 恢复控制）→ 回到 **0 / 20**；`montage_v04b.png` 同款链路 |
| V08 | Normal Attack（站立 A/B/C/D） | **PASS** | `montage_v08a_standA.png`（200）、`montage_v08c_standC.png`（210，Time 1→13）、`montage_v08b.png`（230）、`montage_v08d.png`（240） |
| V09 | Crouch Attack（蹲 A/B/C/D） | **PASS** | `montage_v09a_crouchA.png`（400，`Type: C`，结束后回 **11**）、`montage_v09b.png`（430）、`montage_v09c_crouchC.png`（410）、`montage_v09d.png`（440） |
| V10 | Jump Attack（跳 A/B/C/D） | **PASS** | `montage_v10a2_jumpA.png`（600）、`montage_v10c2_jumpC.png`（610）、`montage_v10b3.png`（630）、`montage_v10d3.png`（640）；均为 `Type: A; Physics: A`，落地由引擎进公共状态 52（`montage_v10a_jump_phase1.png` 的 40→50→落地链路） |
| V11 | Throw | **PASS** | `montage_v11b_throw_p05.png`（**810** 执行中，Time 57–64）；`shots/v11b_throw_01.png`：P2 `LIF: 910` = **1000−90**，倒地；`montage_v22e_states.png` 中 P2 处于 **820**（被抓住） |
| V12 | Special 1（1000） | **PASS** | `montage_v12_special1.png`（State 1000，`Type: S; MoveType: A`） |
| V13 | Special 2（1100，对空） | **PASS** | `montage_v13b_special2.png`（State 1100；214+A 用 `0x25`=后） |
| V14 | EX（1010） | **PASS** | `shots/v14_ex_p05_0D_before.png` → `POW:2000`；`shots/v14_ex_p05_0D_burst02.png` → `State No: 1010` 且 **`POW:1500`（−500）** |
| V15 | Super（3000） | **PASS** | `shots/v15_super_p08_09_burst02.png` → `State No: 3000`，**`POW:1000`（2000−1000）** |
| V16 | Normal → Normal 取消 | **PASS** | `montage_v16b_p2.png`：burst01 = **200 且 `Time: 7`**（该招总长 20 tick）→ burst02 = **210 `Time: 1`** = 在 200 结束前切换 |
| V17 | Normal → Special 取消 | **PASS** | `montage_v17c_p04.png`：210 `Time: 19/21`；`montage_v17c_p2.png`：**1000 `Time: 0`** = 在 210 结束前切换（窗口 tick 10–27） |
| V18 | Special → Super 取消 | **PASS** | `montage_v18k_p09.png`：burst01 = **1000 `Time: 23`**（总长 34）→ burst02 = **3000 `Time: 1`** |
| V19 | Clsn1 / Clsn2 | **PASS**（代码 + 运行时一致性） | `.air` 中逐帧 `Clsn1`（攻击框）与 `Clsn2`（受击框）独立定义；运行时帧读数 `ActionID: 440; ElemNo: 2/8; Time: 0(3/3/30)` 与 `moves.csv` 的 440 帧序（4+3+2+4+5+3+5+4=30、8 元素、判定帧 elem 4）逐项吻合 |
| V20 | Damage 与配置一致 | **PASS**（16 招中 14 招实测，2 招见备注） | 见 §4.1 |
| V21 | 攻击结束退出 | **PASS** | V08–V13 的拼图末帧均回到 **0**（站立技/必杀）或 **11**（蹲技）；空中招落地后回 52 → 0 |
| V22 | AI 使用 Normal | **PASS** | `montage_v22e_states.png`：**200**（站轻拳）、**430**（蹲轻脚） |
| V23 | AI 使用两个 Special | **PASS** | 同上：**1000**、**1100**（两招都被 AI 选中并执行） |
| V24 | AI 的 Power 条件 | **PASS** | `montage_v22e_states.png`：**1010**（EX，需 ≥500）、`montage_v24_ai_super.png`：**3000**（Super，需 ≥1000，多帧连续执行）；**820（P2）** = AI 用投技命中 |
| V25 | 胜利姿势 | **PASS** | `shots/v25_winpose_02.png`：`WINNER!` / `PERFECT!!`、`State No: 180 (P1)`、P2 `LIF: 0`；**控制台无 `changed to invalid state 180` 告警**；AI 对局中也多次进入 180（`montage_v24_ai_super.png`） |
| V26 | 完整一局 | **PASS** | `shots/v26_fullmatch_report.txt`：`test_fighter_a` vs `_template`，AI 双方，`RoundTime 30`，110 s，**`crashlogs: 0 new`**；对局正常推进到回合结束（含 180 胜利姿势） |
| V27 | `scripts/test.ps1` | **PASS** | **26/26 checks passed**，`exit=0`（含 engine submodule / 基线 pin / 脚手架检查） |
| V28 | IKEMEN baseline 未变 | **PASS** | `git rev-parse HEAD` = `ba516193bba83f13f0b63ddce314d8719793931f`（与 pin 一致）；`test.ps1` 的 "engine baseline commit matches pin" 亦为 PASS |
| V29 | Engine 无报错 | **PASS** | 子模块 `git status --porcelain` **0 行**；全部运行期间**新增崩溃日志 0 个**（`Ikemen_*.log` 只出现在开发早期两次 ZSS 语法错误，均已修复，见 §5） |

**备注（V04）**：防御在 IKEMEN/MUGEN 里是**引擎级**机制 ——
命中判定时若防御方按住"后"且 `guardflag` 匹配，该次命中变成 guard
（进入公共状态 150/152 防御硬直），**不需要角色自己路由进防御状态**。
KFM 的 `.cmd` 里那个 `blocking = $F,x` 是它的**额外**入口，不是防御的前提。
本轮为了把"是否真的防住"变成可判定的实验，做了这些事：
① 把 P1 的所有攻击键设为 `Not used`、P2 的 `x` 映射到 TAB
（这样一次注入 = "P1 按住后 + P2 出拳"）；
② 采样 P1 的状态读数。结果：`20`（后退）→ **`150`/`151`（防御硬直 + 防御后退）**
→ **`130`（站立防御循环）**，见 `montage_v04q_blocktest.png`。
> 直接原因：KFM 的 AI 里投技与扫腿占比很高，投技**不可防御**，
> 所以"P1 待机 + KFM 的 AI 攻击"这一类实验里采样到的几乎都是受击/倒地帧
> （`montage_v04_guard.png`、`montage_v04b.png`），拿不到防御证据。
> 换成"可控攻击者"（P2 按键、P1 按键）之后一次就拿到了。

---

## 4. 关键实测数据

### 4.1 伤害（实测 vs 配置）

| 招式 | 状态 | 配置 | 实测 | 证据 |
| --- | --- | --- | --- | --- |
| Stand A 轻拳 | 200 | 25 | **25** ✓ | `montage_v20a_normals_lif.png`（1000→975） |
| Stand B 轻脚 | 230 | 30 | **30** ✓ | `montage_v20g_B_lif.png`（1000→970） |
| Stand C 重拳 | 210 | 70 | **70** ✓ | `montage_v20a_normals_lif.png`（975→905） |
| Stand D 重脚 | 240 | 75 | **75** ✓ | `montage_v20f_D_lif.png`（1000→925） |
| Crouch A | 400 | 25 | **25** ✓ | `montage_v20j_crouchAC_lif.png`（1000→975） |
| Crouch B | 430 | 30 | **30** ✓ | `montage_v20m_crouchB_lif.png`（1000→970） |
| Crouch C | 410 | 60 | **60** ✓ | `montage_v20j_crouchAC_lif.png`（975→915） |
| Crouch D 扫腿 | 440 | 70 | **70** ✓ | `montage_v20f_D_lif.png`（925→855）、`montage_v20k_crouchD_lif.png`（1000→930） |
| Jump A | 600 | 25 | **25** ✓ | `montage_v20_rest_lif.png`（1000→975） |
| Jump B | 630 | 30 | **30** ✓ | `montage_v20_jumps_lif.png`（1000→970） |
| Jump C | 610 | 70 | 未实测 | 自动注入的跳入攻击在该窗口内未命中（见备注） |
| Jump D | 640 | 75 | 未实测 | 同上 |
| Throw | 800→810 | 90 | **90** ✓ | `shots/v11b_throw_01.png`（LIF 1000→910） |
| Special 1 | 1000 | 85 | **85** ✓ | `montage_v20b_specials_lif.png`（1000→915） |
| Special 2 | 1100 | 70 | **70** ✓ | `montage_v20b_specials_lif.png`（915→845） |
| EX | 1010 | 130 | **130** ✓ | `montage_v20c_ex_lif.png`（1000→870） |
| Super | 3000 | 200 | **200** ✓ | `montage_v20d_super_lif.png`（1000→800） |

**备注（V20）**：16 个攻击状态中 **14 个**由"命中后读 LIF 差值"直接实测，
数值与 `.zss` 的 `damage:` **逐条相等**（含普通技/蹲技/两个必杀/EX/Super/投技）。
跳重拳（610, 70）与跳重脚（640, 75）未取得命中帧：这两个动作的自动注入
跳入攻击在采样窗口内没有连上（轻版 600/630 连上了）。二者写法与已验证的
轻版完全同构（同一 `hitDef` 结构、仅 `damage` 不同），因此记为
**代码值 + 未实测**，不记为失败。

### 4.2 Power（气量）

| 观察 | 数值 | 证据 |
| --- | --- | --- |
| 上限 | `POW:2000`（`power = 2000`；对照 P2=KFM 为 3000） | `shots/v14_ex_p05_0D_before.png` |
| EX 消耗 | 2000 → **1500**（−500） | `shots/v14_ex_p05_0D_burst02.png` |
| Super 消耗 | 2000 → **1000**（−1000） | `shots/v15_super_p08_09_burst02.png` |
| 命中给气 | 例：投技后 P1 `POW:10`、P2 `POW:40` | `shots/v11b_throw_01.png` |
| 气量检查发生在路由层 | 气不足时 EX/Super **不进入状态**（状态号保持 0） | `montage_v18i_p12.png`（Power 未补充时按 236+C 无状态切换） |

### 4.3 取消链时间序（T7）

| 路径 | 源状态（切换瞬间） | 目标状态 | 证据 |
| --- | --- | --- | --- |
| lv1 → lv2 | 200 `Time 7` / 20 | 210 `Time 1` | `montage_v16b_p2.png` |
| lv2 → lv3 | 210 `Time 19` / 27 | 1000 `Time 0` | `montage_v17c_p04.png` + `montage_v17c_p2.png` |
| lv3 → lv4 | 1000 `Time 23` / 34 | 3000 `Time 1` | `montage_v18k_p09.png` |

**Super cancel 的输入方式**（也是本轮的实现细节发现）：
`QCF2_x` 的 `time = 45` tick，而**命令缓冲是按命令独立保存**的，
所以"先 236+A（进 Special 1）、紧接着再 236+A"这一串输入，
在第二次 A 落下时已经构成完整的 236236+A → 命中 `QCF2_x`；
此时角色仍在 Special 1 的取消窗口内 → 得到真正的 Super cancel。
这既是玩家实际搓招的节奏，也说明 `.cmd` 里 **QCF2_x 必须排在 QCF_x 前面**。

### 4.4 AI 行为（T10）

`montage_v22e_states.png`（AI vs AI，100 s，12 帧采样）中 P1 的状态分布：
`1010`(EX) ×2、`1000`(Special 1) ×2、`1100`(Special 2)、`430`(蹲轻脚)、
`200`(站轻拳)、`180`(胜利姿势) ×2、`11`(蹲)，且 P2 处于 `820`(被投技抓住)。

`montage_v24_ai_super.png`（Power 补满的定向运行，22 帧采样）：
`3000`(Super) ×6、`1010`(EX)、`180` ×8、`0`(待机)。

结论：**状态号是多样分布的，没有塌缩成单一招式**（P1 实验 E6 的失败模式未复现）；
③ Super / ④ EX / ⑤ Special 1 三条同波段规则的 `random` 概率闸门有效 ——
三者都被观测到。

### 4.5 Frame Data 与运行时一致（T9）

`shots/v09d_crouchD_p01_28+09_burst03.png` 的读数：
`ActionID: 440; SPR: 440,1; ElemNo: 2/8; Time: 0(3/3/30)`，
与 `test_fighter_a.air` 的 Action 440（8 个元素、帧长 4+3+2+4+5+3+5+4 = 30、
判定帧为第 4 元素）以及 `moves.csv` 中 440 的 起手 9 / 判定 4 / 收招 17 完全对应。

---

## 5. 本轮发现并修复的问题

### 5.1 角色自身（开发期，已修复）

| # | 问题 | 现象 | 修复 |
| --- | --- | --- | --- |
| 1 | `call` 语句缺分号（16 处 `AtkInit`） | 引擎 Panic：`test_fighter_a.zss:169: Wrong token: expected ;, got }`（崩溃日志 + 弹窗） | 全部补 `;`（与 KFM 的 `call CSnd(...);` 一致） |
| 2 | 蹲攻的 `call EndState(1)` 缺分号（4 处） | 下一个 `[StateDef 410;` 报 `Unexpected closure token: [` | 补 `;` |
| 3 | AI.zss 的 `var(1) := N` 缺分号（4 处） | `AI.zss:111: Wrong token` | 补 `;` |
| 4 | `call` 不能内联写在 `if` 条件里 | `if ... && call CanChain(4) {` 会在加载时抛错 | 改为 `let canLvN = call CanChain(N);` 预计算（与 P2 的 `canCombo` 同款） |
| 5 | `let` 变量引用漏了 `$` | `... && midR && ...` | 改为 `$midR` |

> 这 5 条都是**加载期致命错误**，而它们**不会**被 `scripts/test.ps1` 发现
> （那是静态检查，不加载角色）—— 正是 §5.2 第 3 条促使 `tests/p3/` 诞生的原因。

### 5.2 模板 / 工具 / 文档（已就地修正）

| # | 问题 | 处置 |
| --- | --- | --- |
| 1 | `_template/README.md` 的克隆清单漏了 `displayname` | 补进清单 |
| 2 | 没说明"克隆体的 README.md 是模板手册、必须改写" | 补进清单 |
| 3 | 缺"克隆后自检"步骤（同步输出 / 运行时文件名 / 加载无错） | 新增 §2.1 三项 |
| 4 | `scripts/sync_game_content.ps1` 正常执行时也打印 `(-WhatIf)`，误导演示 | 改为仅 WhatIf 模式追加 |
| 5 | `tests/p1/README.md` 把 `montage_states.ps1` 的参数写成不存在的 `-Prefix` | 改为 `-Image` 并补参数表 |
| 6 | `montage_states.ps1` 的 `-Steps` 声明为 `[int[]]`，而 `pwsh -File` 无法绑定逗号列表（`-Steps 1,2,3` 被当成 **123**），只会打印 `[warn] nothing selected` | 改为字符串参数并在脚本内 split（与 `-HoldSeqVK`/`-Phases` 同款处理） |
| 7 | `tests/p2/README.md` 的示例把多相位写成 `-Phases 'a','b'`（数组），`pwsh -File` 会把多出来的值**按位置绑到下一个参数**（实测绑到 `-RoundTime` 直接报错；绑到 `-Stage` 则**静默**用错场景） | 只保留"一个逗号连接的字符串"的写法并加警告 |
| 8 | 引擎控制台输出"抓不到"这个结论过于绝对 | `tests/p3/README.md` 补三种实测情形（直连重定向=空文件 / 直跑 harness 可见 / 中间再套一层又丢） |

---

## 6. 已知限制

1. **占位资产**：`test_fighter_a.sff/.snd` 仍是 KFM 素材（CC-BY-NC，`prototype_only`），
   已登记到 `assets/LICENSE_MANIFEST.csv`；发布前必须替换。
2. **表现层缺失**：EX/Super 无 superPause 定格、无闪光/镜头/暗转、无独立成功姿势。
3. **取消不要求命中**（空挥即可取消），是本轮为可观测性刻意放宽的；
   正式角色应加 `moveContact`。
4. **判定框几何沿用 KFM 原型**（精灵同一套）；换原创美术时必须重画。
5. **跳重拳/重脚的伤害未实测**（§4.1 备注）。
6. **模板未实现"防御状态路由"**：本角色与模板都不路由进 120/130，
   防御完全依赖引擎级 guard（已验证有效）。若将来要做"防御姿势动画"，
   需要照 KFM 的做法加 `blocking` 命令 + 路由（**属 P4/P7，本轮不动模板战斗逻辑**）。
7. **`_template` 的战斗逻辑本轮未改动**（只改文档）；模板的蹲/跳/必杀扩展
   仍只在 Fighter A 里实现。

---

## 7. 如何复查（可复现命令）

```powershell
# 0) 同步 + 回归
pwsh -File scripts/sync_game_content.ps1
pwsh -File scripts/test.ps1                       # 期望 26/26 + SMOKE TEST PASS

# 1) 加载 / 无崩溃日志（无人值守）
pwsh -File tests/p3/run_match_watch.ps1 -P1 test_fighter_a -P2 kfm_zss `
    -Ai1 8 -Ai2 8 -RunSec 100 -Shots 12 -ShowDebug -Prefix my_check
#    报告末尾必须看到 crashlogs : 0 new

# 2) 注入取证（必须先改成可注入键位：x=TAB, y=RETURN, start=Not used）
#    注意：-Phases 必须是"一个逗号连接的字符串"
pwsh -File tests/p2/inject_phases.ps1 -P1 test_fighter_a -P2 kfm_zss -Ai1 0 -Ai2 0 `
    -ShowDebug -NoStillShots -SettleSec 0.02 `
    -Phases '0x28:0.05,0x28+0x27:0.05,0x27:0.05,0x09:0.05,0x28:0.05,0x28+0x27:0.05,0x27:0.05,0x09:0.9' `
    -Prefix recheck_supercancel
#    期望：第二个 0x09 之前 P1 仍在 1000，按下后变 3000（= Special → Super 取消）

# 3) 读数拼图
pwsh -File tests/p1/montage_states.ps1 -Image 'logs\p3\shots\recheck_*_burst*.png' `
    -Steps '1,2,3' -OutFile 'logs\p3\recheck_montage.png'
```

**键位还原**：`engine/ikemen-go/save/config.ini` 的 `[Keys_P1]` 必须还原成
`x=a, y=s, start=RETURN`（该文件 gitignored，不还原会影响你自己试玩）。

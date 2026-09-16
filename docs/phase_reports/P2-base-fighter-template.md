# P2 Phase Report — Base Fighter Template（基础格斗模板）

| | |
| --- | --- |
| **阶段** | P2 — Base Fighter Template |
| **状态** | **PASS**（10/10 Exit Gate 全绿；两项按合同 §17 明确标注为"需真人验证"） |
| **日期** | 2026-09-15（2026-09-16 审计修订） |
| **分支** | `feature/p2-character-template` |
| **引擎基线** | IKEMEN GO `v1.0.0-rc.5`（`ba516193bba83f13f0b63ddce314d8719793931f`），submodule 干净、未改动 |
| **过程记录** | [`docs/iterations/20260915-p2-character-template.md`](../iterations/20260915-p2-character-template.md) |
| **总览 / 交接** | [`docs/P2-summary.md`](../P2-summary.md) |
| **模板手册** | [`game/chars/_template/README.md`](../../game/chars/_template/README.md) |

---

## 1. 结论

P1 的设计骨架已经变成**真实可加载、可运行、可复制**的四键基础格斗角色，
放在 `game/chars/_template/`（11 个文件，Git 单一真源）。引擎一行未改。

本阶段交付"**能力 + 约定 + 证据**"三件套：

- **能力**：移动 / 防御 / 四键站立普通技 / 投技 / 必杀 / EX / 取消 / AI 对战，
  全部在真实 RC5 对局里跑过（见 §3 矩阵）。
- **约定**：状态号、变量台账、气槽语义、取消窗口、AI 优先级 —— 在代码里就地
  写清出处，并在本报告与模板手册中复述。
- **证据**：矩阵每一格都对应 `logs/` 下的帧截图与运行报告，可复查、可重放
  （命令见模板手册 §8）。

---

## 2. 交付物（T1–T9）

| 项 | 实现方式 | 状态 |
| --- | --- | --- |
| **T1 基础移动** | 全部走**公共状态**（0/10/11/20/21/40–52/100/105），模板只做双击方向键路由（FF→100、BB→105） | ✅ 实测 |
| **T2 四键站立普通技** | 自实现 200(A)/210(C)/230(B)/240(D)，伤害 **25/70/30/75**；起手帧、收招长度、退出路径各自独立 | ✅ A/C 实测命中；B/D 待真人 |
| **T3 防御 / 受击 / 倒地 / 起身** | 防御走公共 120/130–155（实测进 State 130）；受击/倒地/起身走公共 5000–5210；**投技受害方**自实现于 `hits.zss` 的 **820/821**（821 内含受身 → 5200/5210） | ✅ 实测 |
| **T4 基础投技** | 800 起手（`attr: S, NT`、`hitflag: M-`、`priority: 1, Miss`、`p2stateno: 820`）→ 810 执行（`targetBind` / `targetLifeAdd{value: -90}` / `targetState{value: 821}`） | ✅ 实测（伤害 90） |
| **T5 占位必杀** | QCF+A → 1000（按 `p2BodyDist X` 分支：近 **95** / 远 **85**）；QCF+C → 1010（**130**，`fall: 1` 强制击倒） | ✅ 实测 |
| **T6 气槽约定** | 只用引擎原生 `power`：**上限**由 `.const` 的 `power` 决定（不是起始值，对局起点为 0，跨回合保留）；收入 = 命中给气 + 状态头 `poweradd`；支出 = 路由层 `power >= 500` 门 + 状态内 `powerAdd{value: -500}` | ✅ 实测 |
| **T7 取消约定** | `command.zss` 的 `[Function Combo]`：地面自由态，或 200/230 的 `animElemTime(3) >= 0` 且 `var(0) = 0`；进必杀时 `var(0) := 1` 闩锁 | ✅ 实测（A → 必杀 2 段） |
| **T8 变量约定** | `_template.const` 变量台账：var(0) cancelUsed / var(1) aiCooldown / var(2) throwDirFwd / 10–39 角色私有 / 40–59 AI 私有 / 60+ 跨回合；map("canCombo") 只读 | ✅ |
| **T9 最小 AI 接口** | `AI.zss` 顺序 = 优先级：防御 → 200 → 1000/1010 → 800 → 走路；实测 AI 能打出普通技与必杀 | ✅ 实测 |

---

## 3. 运行时验证矩阵

装置：`tests/p1/capture_match.ps1`（单键）与 `tests/p2/inject_phases.ps1`
（多键相位，本阶段新增）。**所有注入运行都带 `-Ai1 0`**，每份运行报告的 `args`
行都核对过**不含 `-p1.ai`**；被引用的帧全部开着调试覆盖层。

| V | 断言 | 结果 | 证据（`logs/p1/shots/` 或 `logs/p2/shots/`） |
| --- | --- | --- | --- |
| V01 | 模板能被 RC5 加载 | **PASS** | 报告 `args` 干净；`New char loaded: chars/_template/_template.def` |
| V02 | 站立待机 | **PASS** | V03/V09 序列中的 State 0 |
| V03 | 四个方向键都到达引擎 | **PASS** | 0x27→20、0x25→21、0x28→10/11、0x26→41 |
| V04 | 防御可用 | **PASS** | `v04_guard_seq01_holdback_burst12.png`：StateNo **130**、防御给气 POW 458。备注：AI 8 级压制下最终被击倒属强度差异，非缺陷 |
| V05 | 蹲姿可达 | **PASS** | StateNo **11**、Type C |
| V06 | 跳跃可达 | **PASS** | StateNo 41（Type A） |
| V07 | 前冲 / 后跳 | **PASS** | StateNo 105 帧；100 与 KFM 对照（引擎序列计时说明见过程记录） |
| V09 | A = 200，伤害 25 | **PASS** | `v09b_normA_01.png`：P2 **LIF 975**、MoveType H、FIRST ATTACK |
| V10 | C = 210，伤害 70 | **PASS** | `v10_normC_01.png`：P2 **LIF 930** |
| V11 | 投技全链路 | **PASS** | `v11_throw_p02_27+0D_burst08.png`（810、Target 57）→ `burst20.png`（被抛飞）→ `v11_throw_02.png`：P2 **LIF 910**（−90）、回到 idle |
| V12 | QCF+A → 1000，伤害 95 | **PASS** | `v12b_special_p05_09_burst05.png`（StateNo 1000）→ `v12b_special_01.png`：P2 **LIF 905**、命中特效 |
| V13 | EX 气量门与扣除 | **PASS** | 先用 **F3**（`powMax`；热键可被合成注入触发）充满气 → `v13_ex_p06_0D_burst07.png`（StateNo **1010**、P1 POW **1000→500**）→ `v13_ex_01.png`：P2 **LIF 870**（−130） |
| V14 | 取消：200 → 1000 | **PASS** | `v14_cancel_p06_09_burst05.png`（已进 1000，P2 已 −25）→ `v14_cancel_01.png`：**一次取消打出 2 段**，P2 **LIF 880**（25+95），P1 POW 143（37+40+66） |
| V15 | AI 会用普通技 + 必杀 | **PASS** | `v15_ai_02.png`（站桩 KFM 被打到 LIF 130，Target 57）→ `v15_ai_03.png`（AI 自放 StateNo **1000**） |
| V16 | Clsn 可观测 | **PASS** | V09–V14 各帧均可见粉色 Clsn1 / 蓝色 Clsn2 |
| V17 | 受击 / 倒地 / 起身链 | **PASS** | V11 的抛飞 → 落地 → 恢复站立（`v11_throw_02.png` 的 StateNo 0） |
| V18 | 气量是否跨回合保留 | **PASS（行为已测定）** | `v18_powcarry_04.png`：第 1 回合充满气（POW 1000）→ 用 F1 击杀对手结束回合 → 第 2 回合开局（计时器 60、双方满血）时 P1 **POW 仍为 1000** → **保留**；`v19_winpose_04.png` 第二次独立复现 |
| V19 | 胜利姿势缺口与修正 | **PASS（先复现、后修正）** | 修正前：`v18_powcarry_02/03.png` 出现 `WARNING: _template (56) in state 180: changed to invalid state 180 (from state 0)`；补 `StateDef 180` + Action 180 后复跑：**告警消失**、胜者进 180 播姿势（`v19_winpose_02.png`）、回合正常推进 |
| — | **B/D 键、嘲讽（195）** | **需真人验证** | 本机合成注入到不了字母键与 start（合同 §17）；**不做替代性结论** |
| — | 蹲攻（400s）/ 跳攻（600s）/ 超杀（3000+） | **本阶段不实现** | 状态号已预留；路由中 `command != "holddown"` 已为蹲攻留位 |

---

## 4. 审计修正（2026-09-16）

P2 收尾后做了一次**全量结论审计**（逐条回到代码与原始帧核对）。查出并修正下列
问题 —— 均为"文档/注释与事实不符"，另含一个真缺陷（胜利姿势缺失）。

| # | 问题 | 性质 | 处置 |
| --- | --- | --- | --- |
| 1 | `_template.const` 把 `power` 写成"起始气量" | **机制性误解** | 改注释；机制另用 V18 实验重新测定 |
| 2 | 文档写"引擎每回合清零气量" | 同上的推论（当初由 MUGEN 语义推断，未实测） | 删除该结论，改为"**对局起点为 0、上限由 `const power` 决定、跨回合保留**（V18/V19 实测）" |
| 3 | B（230）伤害写成 15、D（240）写成 90 | 数值错误（实际 **30 / 75**） | 按 `_template.zss` 更正 |
| 4 | EX（1010）伤害写成 70 | **读数误判**（把 State 210 的 70 混进 EX 帧解读；实际 **130**） | 更正，证据改指事后静态帧（`v13_ex_01.png`：LIF 870） |
| 5 | 必杀 1000 只写"95" | 不完整（近 95 / 远 85 两套 `hitDef`） | 补全 |
| 6 | 写"`hits.zss` 只含 810 配套" | 事实错误（实际 **820/821**） | 更正 |
| 7 | 写"受身（recovery）状态未实现" | 事实错误（821 已实现 → 5200/5210） | 更正 |
| 8 | `var(2)`（投技方向记忆）被使用但未登记 | 台账缺口（违反 T8 自身约定） | 补登记 |
| 9 | 缺胜利姿势 `State 180` | **真缺陷**：回合结束引擎报 `changed to invalid state 180` | 补 `StateDef 180` + Action 180（占位），复跑 V19 验证告警消失 |
| 10 | `_template.air` 中 210 的注释仍写"轻拳 12 tick" | 陈旧注释（200 已是 20 tick） | 更正 |
| 11 | `tests/p2/README.md` 写矩阵为 "V01–V20" | 编号不符（实际 V01–V19） | 更正 |

**审计方法（可复用）**：结论不查"我记的"，只查三处 ——
① 代码里的实际值（`_template.zss` / `.air` / `.const` / `hits.zss`）；
② 原始帧里覆盖层的读数（**事后静态帧比连拍帧更适合读数字**，本轮 V13 的误判就出在连拍帧）；
③ **能实测的机制性结论必须实测**（"气量跨回合"这类不许用业界常识代替）。

---

## 5. 已知限制

1. **占位素材**：`_template.sff` / `_template.snd` 来自 P1 研究用的 KFM 素材
   （Elecbyte，**CC-BY-NC**，`usage = prototype_only`，已登记
   `assets/LICENSE_MANIFEST.csv`）。**每个克隆角色发布前必须替换**。
2. **蹲攻（400–440）/ 跳攻（600–640）/ 超杀（3000+）未实现**：状态号与命令已
   预留，路由为蹲攻留了 `command != "holddown"` 的位置。
3. **B/D 键与嘲讽的运行时证据需真人键盘**（本机合成注入不可达）。
4. **胜利姿势是占位**：只播一段姿势动画，无多姿势选择（181–189）与台词 ——
   属 P7 表现层范围；本阶段补它只是为消除引擎告警。
5. **手感数值是"可观测性优先"的占位值**：State 200 总长 20 tick、
   QCF `buffer.time = 14`、FF/BB `time = 25`；正式角色按手感调。
6. **取消窗口不要求 `moveContact`**（空挥也可取消），刻意放宽；
   收紧写法（`&& moveContact`）已在代码注释中给出。

---

## 6. 出口门（Exit Gates）

| 门 | 判定 |
| --- | --- |
| GATE-01 P1 基线在位 | PASS（`main` `99add4d` 含完整 P1；submodule 指针一致） |
| GATE-02 IKEMEN 基线未动 | PASS（HEAD `ba516193...`，submodule 干净） |
| GATE-03 单一模板真源 | PASS（`game/chars/_template/`；`design/` 已迁出） |
| GATE-04 可加载可运行 | PASS（V01 + 完整对局证据） |
| GATE-05 基础格斗能力 | PASS（V03/V04/V07/V09/V10/V17/V19） |
| GATE-06 战斗约定 | PASS（投技 V11、气槽 V13/V18、取消 V14、变量台账 T8） |
| GATE-07 AI 接口 | PASS（V15） |
| GATE-08 模板文档 | PASS（`game/chars/_template/README.md` 已重写为手册） |
| GATE-09 测试与回归 | PASS（`scripts/test.ps1` 26/26；新增 `tests/p2/`） |
| GATE-10 阶段收尾 | PASS（状态/过程记录/报告/总览 + Git 流程） |

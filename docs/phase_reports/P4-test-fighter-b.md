# P4 — Test Fighter B：Phase Report

> 本文件是 P4 的**逐条 Gate 证据档案**。总览与交接说明见
> [`docs/P4-summary.md`](../P4-summary.md)；过程记录见
> [`docs/iterations/20260918-p4-test-fighter-b.md`](../iterations/20260918-p4-test-fighter-b.md)。
> 两者冲突时以本文件为准。

| | |
| --- | --- |
| **阶段** | P4 — Test Fighter B |
| **状态** | **IN_PROGRESS**（Gate 1/2/3/5/8/9/10 PASS；Gate 4、6、7 部分通过，原因见各条） |
| **分支** | `feature/p4-test-fighter-b` |
| **基线** | `main` @ `18621e4` |
| **引擎** | `ba516193`（v1.0.0-rc.5），**未修改** |
| **日期** | 2026-09-18 |

> **为什么不写 PASS**：Gate 4（Anti-Air 的空中命中交互）、Gate 6（取消链的时间序）、
> Gate 7（投射物被防御 / 被跳跃规避）三项没有拿到完整的 Runtime 证据。
> 原因统一记录在 §3，不掩饰。

---

## 1. Gate 逐条结论

| Gate | 名称 | 结论 |
| --- | --- | --- |
| 1 | Baseline | **PASS** |
| 2 | Fighter B from Template | **PASS** |
| 3 | Complete Basic Fighter | **PASS** |
| 4 | Zoner Identity | **PASS（部分）** — 长手与投射物完整；Anti-Air 的空中命中未实测 |
| 5 | Meter Skills | **PASS** |
| 6 | Cancel | **PASS（部分）** — 状态序列有，时间序不精确 |
| 7 | Projectile Lifecycle | **PASS（部分）** — 生成/移动/命中/消失有；被防御/被跳跃规避未测 |
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

### Gate 4 — Zoner Identity：**PASS（部分）**

| 手段 | 方法 | 结果 | 证据 |
| --- | --- | --- | --- |
| **长手 Normal** | 注入/观测 `State 210` | 判定框到 `x=105`，起手 14 / 判定 4 / 收招 15，**无 posAdd** | `test_fighter_b.air` Action 210；`logs/p3/shots/p4_ver1_05.png` |
| **投射物** | 观测 `State 1000` | 投射物生成、飞行、命中（对手掉血 60） | `logs/p3/shots/p4_ver1_05.png` |
| **Anti-Air** | 观测 `State 1100` | 招式触发 ✓（`ElemNo 8/14`）；**"对手在空中被命中"未取得截图** | `logs/p3/shots/p4_aa6_04.png` |

**Anti-Air 的几何依据**（非 Runtime，如实标注）：

- `Action 1100` 的 `Clsn1[0] = 28,-60 → 62,-152`，角色身高 60 → 判定覆盖到身高的 2.5 倍高度。
- `Action 410` 的 `Clsn1` 向上到 `-112`（Fighter A 同位置是 -94）。
- AI 规则 ②③ 只在 `p2StateType = A`（对手在空中）时使用它们。

**未取得空中命中截图的原因**：本机合成注入长期无法让对手起跳。
根因（`inject_phases.ps1` 缺 `KEYEVENTF_EXTENDEDKEY`，方向键被识别成小键盘）在本次**末尾**才定位修复，
修复验证成功（`logs/p2/shots/p4_jump2_p01_26_after.png`：KFM `State 50` 在空中），
但剩余时间不足重跑 Anti-Air 组。

### Gate 5 — Meter Skills：**PASS**

| 项 | 方法 | 结果 | 证据 |
| --- | --- | --- | --- |
| EX 触发 | 观测 `State 1010` | **同时 2 枚投射物**（双气弹） | `logs/p3/shots/p4_ex_03.png` |
| EX 气耗 | 读 `POW` 前后 | **580 → 80（正好 500）** | 同上 |
| Super 触发 | 观测 `State 3000` | 触发 | `logs/p3/shots/p4_skill2_04.png` |
| Super 气耗 | 读 `POW` 前后 | **2000 → 1000（正好 1000）** | 同上 |
| 未创建第二套资源 | 代码审查 | 只有一个 `power`（`test_fighter_b.const`） | — |

### Gate 6 — Cancel：**PASS（部分）**

| 项 | 结果 |
| --- | --- |
| 状态序列 | **有**：`State 200 @ Frame 952` → `State 1000 @ Frame 1007` |
| 时间序精确性 | **不足**：间隔约 55 帧，而 200 的取消窗口只有 20 tick —— 不能排除"200 打完后另起一招" |
| 证据 | `logs/p2/shots/p4_cancel2_p01_09_burst03.png`（State 200）、`p4_cancel_02.png`（State 1000） |
| 是否新建第二套取消系统 | **否**，沿用 `CanChain(lv)` 等级系统 |

### Gate 7 — Projectile Lifecycle：**PASS（部分）**

| 项 | 方法 | 结果 |
| --- | --- | --- |
| 生成 | 观测 `State 1000` / `ElemNo 4` | ✓ 每次恰好 1 枚（`var(10)` 闩锁生效） |
| 移动 | 连续截图 | ✓ 投射物在画面上向右推进 |
| 命中 | 读对手 LIFE 与 POW | ✓ `LIFE 1000 → 940`（伤害 60）；K.O. 时出现 `PERFECT!!` |
| 消失 | `projhits:1` + `projremovetime:130` + `edgebound:40` | ✓ 三重闸门显式设置；重复发波时**未出现数量失控** |
| 被防御 | — | **未测**（需要可控的攻击方 + 防御方，AI 对战中难以指定时机） |
| 被跳跃规避 | — | **未测**（同上，且跳跃注入刚修复） |
| 与角色状态解耦 | — | 部分：多次发波共存时各自独立飞行（`logs/p3/shots/p4_static_04.png` 有 3 枚同时在飞） |

**★ 关键修复**：投射物最初**完全打不中人**，原因是 `Clsn1` 逐帧声明在 `-1` 保持帧失效
（投射物只在生成后 4 tick 内带判定）。改用 `Clsn1Default` 后修复。
详细过程见 Iteration Record §4.1。

### Gate 8 — Fighter A VS Fighter B：**PASS**

| 交互 | 结果 | 证据 |
| --- | --- | --- |
| Hit | ✓ A 被打到 74 血 / K.O. | `logs/p3/shots/p4_ver1_05.png`、`p4_ex_09.png` |
| Guard | ✓ 双方均出现防御状态（公共 150） | `logs/p3/shots/p4_final_*.png` |
| Throw / Hurt / Knockdown / Wakeup | ✓ 公共受击与倒地链路正常 | 同上 |
| Projectile | ✓ B 的投射物命中 A | `p4_ver1_05.png` |
| Anti-Air | 部分（见 Gate 4） | — |
| Meter 独立 | ✓ 双方 POW 各自累积（B 300 / A 1100 同时存在） | `p4_ver1_05.png` |
| EX / Super 独立 | ✓ B 的 EX/Super 不影响 A 的气 | `p4_skill2_04.png` |
| Cancel 互不干扰 | ✓ 两个角色各自用自己的 `command.zss`（不同文件） | 代码 |
| **AI VS AI 持续对战** | **110 秒，`crashlogs: 0 new`** | `logs/p3/shots/p4_final_report.txt` |

### Gate 9 — AI：**PASS**

| 项 | 结果 |
| --- | --- |
| 行为多样 | ✓ 观测到 `1000 / 1010 / 3000 / 200 / 210 / 230 / 240 / 410 / 1100 / 150` 等多种状态 |
| Zoner 特征 | ✓ 末位规则是"后跳拉开"（与 Fighter A 的"走向对手"相反）；⑥ 投射物距离阈值 ≥95 |
| 不会单一动作循环 | ✓ 状态在多次截图中变化 |
| A vs B AI 对战 ≥ 100 s | ✓ **110 秒** |
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

三项部分通过**有同一个根因**：**本机合成按键注入长期不可用**。

- 现象：只能注入 `TAB` / `RETURN`，方向键完全无效。
- 影响：无法让对手起跳（Anti-Air）、无法精确构造取消时机、无法让角色跳跃（投射物被规避）。
- 定位过程：排除了焦点、时序、命令窗口、相位时长；最后发现 `inject_phases.ps1` 的
  `keybd_event` 调用**没有传 `KEYEVENTF_EXTENDEDKEY`** —— 方向键与数字小键盘共享扫描码，
  缺这个标志时引擎收到的是"小键盘 8"而不是"上"。
- 修复验证：`logs/p2/shots/p4_jump2_p01_26_after.png` —— KFM 被注入 UP 后 `State 50`（在空中），
  说明**修复有效**。
- 剩余问题：修复发生在本次工作的末尾，重跑三个 Gate 的时间不够。

**因此这三项的结论是"未测"，不是"不成立"。** 修复已完成并留在仓库里，下一窗口可以直接补测。

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
| 110 秒 AI 对战 | `logs/p3/shots/p4_final_report.txt` + `p4_final_*.png` |
| 投射物静止标定 | `logs/p3/shots/p4_static_04.png` |

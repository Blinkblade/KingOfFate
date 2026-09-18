# P4 阶段性总结（Phase 4 Summary & Handoff）

| | |
| --- | --- |
| **阶段** | P4 — Test Fighter B |
| **状态** | **IN_PROGRESS**（Gate 1/2/3/5/8/9/10 PASS；Gate 4/6/7 部分通过） |
| **时间** | 2026-09-18 |
| **分支** | `feature/p4-test-fighter-b` |
| **基线** | `main` @ `18621e4`（含 P3 合并 PR #5） |
| **引擎** | `ba516193`（`v1.0.0-rc.5`）—— **全程未修改**，submodule 指针未动 |
| **详细报告** | [`docs/phase_reports/P4-test-fighter-b.md`](phase_reports/P4-test-fighter-b.md) |
| **过程记录** | [`docs/iterations/20260918-p4-test-fighter-b.md`](iterations/20260918-p4-test-fighter-b.md) |
| **核心产出** | [`game/chars/test_fighter_b/`](../game/chars/test_fighter_b/)（角色本体 · [手册](../game/chars/test_fighter_b/README.md)） |
| **设计数据** | [`design/characters/test_fighter_b/moves.csv`](../design/characters/test_fighter_b/moves.csv) |

> 与 Phase Report 的分工同 P1/P2/P3：Phase Report 是**逐条 Gate 的证据档案**，
> 本文是**总览 + 交接说明**。两者冲突时以 Phase Report 为准。

---

## 1. P4 的目的与答案

P3 已经证明"`_template` 能做出一个角色"。P4 要回答的是合同 §0 的 7 个问题：

| # | 问题 | 答案 |
| --- | --- | --- |
| 1 | 第二个风格完全不同的角色能否继续从 `_template` 开发？ | **能**。12 文件由 `_template` 克隆后扩展，没有新建框架 |
| 2 | Fighter A 是否依赖了角色特有的隐含假设？ | **没有**。Fighter B 只在 `_template` 与 Fighter A 提供的机制内改动。**唯一的隐含假设在工具层**（见 §5） |
| 3 | Projectile / 长手 / Anti-Air 能否在现有体系内自然实现？ | **能**。全部用角色层能力（`projectile{}` sctrl + `.air` 判定框 + 状态）实现，不需要改引擎 |
| 4 | 两角色之间的 Hit / Guard / Throw / Knockdown 是否正常？ | **正常**。A vs B 完整对局 110 秒，0 崩溃 |
| 5 | 双方的 Meter / Cancel / EX / Super 是否互不干扰？ | **互不干扰**。各自一个 `power`、各自的 `command.zss` |
| 6 | Zoner AI 能否形成不同的行为分布？ | **能**。末位规则从"走向对手"变成"后跳拉开"；主力从近身招变成投射物 |
| 7 | 是否暴露 `_template` 中真正属于"通用缺陷"的问题？ | **暴露了 3 个**：见 §4 |

---

## 2. 最终角色能力

**Test Fighter B —— Zoner（远程控制型）**

| 类别 | 内容 |
| --- | --- |
| 普通技 | 站 4 + 蹲 4 + 跳 4 = 12（状态 200/210/230/240、400/410/430/440、600/610/630/640） |
| **长手牵制** | **210 站重拳 C**：判定框到 `x=105`（Fighter A 最长 84），**角色本体不位移** |
| **对空 Normal** | **410 蹲重拳 C**：判定框向上到 `y=-112` |
| **投射物** | **1000 气弹**（236+A）：原生 `projectile{}`，伤害 60，速度 6 |
| **对空必杀** | **1100 升龙上勾拳**（623+A）：判定框向上到 `y=-152`，伤害 75，带击倒 |
| **EX** | **1010 双气弹**（236+C，−500 气）：一次 2 发，合计 110 |
| **Super** | **3000 气弹炮**（236236+A，−1000 气）：**3 连发弹幕**，合计 195 |
| 投技 | 800 → 810（`targetLifeAdd -90`） |
| Meter | 引擎原生 `power`，上限 2000，起点 0，跨回合保留 |
| Cancel | 沿用 P3 的 `CanChain(lv)` 等级系统（lv1 轻 → lv2 重 → lv3 必杀 → lv4 EX/Super） |
| AI | 规则 AI，顺序表 11 条，末位是"后跳拉开"（Zoner 特征） |

**关键状态编号**：`200/210/230/240 · 400/410/430/440 · 600/610/630/640 · 800/810 · 1000 投射物 · 1010 EX · 1100 对空 · 3000 Super`，
外加投射物自身的动画 **Action 1005**。

---

## 3. 两条最重要的技术结论

### 3.1 ★ 投射物的攻击框必须用 `Clsn1Default`，不能用 `Clsn1`

- 投射物动画是"一帧过渡 + 一帧 `-1` 保持"。`Clsn1: N` 这种逐帧声明**只作用于紧邻的那一帧**，
  到 `-1` 帧就失效 → 投射物只在生成后 **4 tick** 内带判定 → **视觉正常但打不中人**。
- 症状的形状很好认：**小判定框全不命中，只有超大判定框才命中**（超大框在生成的瞬间就够到对手）。
- 修法：`Clsn1Default: N`（与 `Clsn2Default` 同一机制，作用于整个动画）。
- 这条已写进 `_template/README.md`，**所有新角色必读**。

### 3.2 `animElem = N` 在元素的**整个持续期**内为真

所以发射投射物的写法必须是
`if animElem = 4 && var(10) = 0 { var(10) := 1; projectile{...} }`，
否则会按元素时长重复生成（3 枚而不是 1 枚）。

---

## 4. `_template` 暴露的通用缺陷（3 个）

| # | 缺陷 | 性质 | 处置 |
| --- | --- | --- | --- |
| 1 | README/`.air` 把"走路"写成状态 `20–21`（**21 其实是动画号**） | 文档错误，会误导所有角色的 AI | **已修文档**；实测原话 `changed to invalid state 21` |
| 2 | 未提示"带 `-1` 保持帧的动画必须用 `Clsn1Default`" | 文档缺失，P4 因此花了最多时间 | **已补文档** |
| 3 | 工具层：`inject_phases.ps1` 的方向键注入缺 `KEYEVENTF_EXTENDEDKEY` | 工具缺陷，让**所有方向相关的验证**失效 | **已修脚本** |

**未修改 `_template` 的任何战斗逻辑**，也**不回灌** Fighter B 的招式实现
（理由：`Crouching/Jumping/Normal` 的方法 Fighter A 已经提供；`Projectile/长手/对空` 是本角色的招式设计，
不是通用机制。合同 §39：两个角色出现相似代码 ≠ 已经需要框架化）。

---

## 5. 本阶段踩的坑（写给下一个窗口）

1. **投射物"飞得很好看但不伤人"** —— 根因是 `Clsn1` 的帧作用域（§3.1）。
   有效的诊断手法：**用 `velocity: 0` 把投射物停住**，先确认"它存在吗？位置对吗？"，
   再区分几何问题与逻辑问题。
2. **`changeState{value: 21}` 是非法状态** —— 走路只有状态 20。
3. **AI 不走命令系统 → 走路的**方向**由引擎给**，把 Fighter A 的"走向对手"抄给 Zoner
   会让两个角色贴在一起。修法：只用有确定方向的公共状态（105 后跳）。
4. **方向键注入需要 `KEYEVENTF_EXTENDEDKEY`**，否则引擎收到的是小键盘键。
   缺这个标志时**键确实被送达了**，所以失败是静默的。
5. **`Ctrl+D` 调试覆盖层是开关**：连按两次会关掉，而截图看不出来。
   harness 现在先检测再按键。
6. **前台焦点会间歇性丢失**，且失败是静默的（截图看着正常，但没有状态读数）。
   修法：ALT 释放前台锁 + 重试。

---

## 6. Git 收尾

```
分支  : feature/p4-test-fighter-b
基线  : main @ 18621e4（含 P3 合并 PR #5）
提交  : 2ae8118  feat: add zoner test fighter b
        23 files changed, 4827 insertions(+), 19 deletions(-)
推送  : 已推送 origin/feature/p4-test-fighter-b
子模块: engine/ikemen-go @ ba516193（未改动）
```

**创建 PR（本机无 `gh`，需要手动开）**：

```
https://github.com/Blinkblade/KingOfFate/pull/new/feature/p4-test-fighter-b
```

**PR 标题建议**：`P4: Test Fighter B（Zoner）`

**PR 描述要点**：见本文件 §1（7 个问题的答案）、§3（两条技术结论）、§6（状态 IN_PROGRESS 的原因）。

**P4 未 PASS，因此本分支的合并不是"阶段完成"，而是"阶段进度"** ——
下一窗口补完 Gate 4/6/7 后再按 P4 的 Exit Gate 重新评估。

---

## 7. 遗留项（明确记录，不藏）

| # | 事项 | 原因 | 归属 |
| --- | --- | --- | --- |
| 1 | Anti-Air 的**空中命中**实测 | 注入缺陷修复太晚 | 下一窗口（一条命令即可重跑） |
| 2 | 取消链的**精确时间序**（200 → 1000 落在 20 tick 窗口内） | 同上 | 下一窗口 |
| 3 | 投射物**被防御 / 被跳跃规避** | 同上 | 下一窗口 |
| 4 | P3 遗留：Fighter A 的 **610 / 640 伤害**补测、`Clsn1: 0` 的 A/B 对照 | 同上 | 下一窗口 |
| 5 | 投射物判定框尺寸重画 | 依赖占位素材 | **P5**（换素材后） |
| 6 | 占位 SFF/SND 替换 | — | P5/P6 |
| 7 | 正式平衡 / 胜率 / Tier | — | P10 |

**遗留项 1–4 共用一条命令模板**：

```powershell
# 先改 save/config.ini 的 [Keys_P1] 为 x=TAB（注入需要），测完还原
pwsh -File tests/p2/inject_phases.ps1 -P1 test_fighter_b -P2 test_fighter_a -Ai1 0 -Ai2 0 `
    -Phases '...' -SettleSec 0.02 -ShowDebug -ShowClsn
```

---

## 8. 下一阶段可以直接复用什么

| 想要 | 直接拿 |
| --- | --- |
| Zoner 角色的起点 | `game/chars/test_fighter_b/`（比 `_template` 多一套完整的远程体系） |
| **投射物的正确写法** | `test_fighter_b.zss` 的 State 1000/1010/3000 + `test_fighter_b.air` 的 Action 1005 |
| 长手 / 对空判定框的样板 | `test_fighter_b.air` 的 Action 210 / 410 / 1100 |
| 多段投射物（弹幕）的写法 | State 3000（3 发，`var(10)` 计数） |
| 取消链 | 与 Fighter A 相同：`command.zss` 的 `CanChain(lv)` + `AtkInit(lv)` |
| 观测装置 | `tests/p3/run_match_watch.ps1`（已修 focus 与 overlay）、`tests/p2/inject_phases.ps1`（已修方向键） |
| Frame Data 表格式 | `design/characters/test_fighter_b/moves.csv` |

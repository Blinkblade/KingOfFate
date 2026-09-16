# 2026-09-16 — P3 Test Fighter A

## 基本信息

| | |
| --- | --- |
| **日期** | 2026-09-16 |
| **Phase** | P3 — Test Fighter A |
| **Branch** | `feature/p3-test-fighter-a`（已推送 `origin`，首个提交 `b8a320f`） |
| **PR** | 待用户手动开（本机无 `gh`）：<https://github.com/Blinkblade/KingOfFate/pull/new/feature/p3-test-fighter-a> → `main` |
| **状态** | PASS（10/10 Exit Gate） |
| **基线** | `main` @ `8407bb0`（P2 已合入，PR #3） |
| **引擎** | IKEMEN GO `v1.0.0-rc.5`（`ba516193bba83f13f0b63ddce314d8719793931f`），未改动 |
| **前置** | P2 PASS（`game/chars/_template/`） |
| **详细证据** | [`docs/phase_reports/P3-test-fighter-a.md`](../phase_reports/P3-test-fighter-a.md) |
| **交接说明** | [`docs/P3-summary.md`](../P3-summary.md) |

---

## 1. 本次目标

本轮的目标是回答一个工程问题，而不是做一个角色：

> `game/chars/_template/` 能不能作为一个**稳定的角色生产起点**，
> 克隆出一个拥有完整基础攻击体系、取消链和独立 AI 的角色？

交付物是 `game/chars/test_fighter_a/`（12 文件）+ 设计数据 + 验证证据 + 三份文档。

## 2. P3 目标（合同 §0 / §9–§21）

| 编号 | 目标 | 结果 |
| --- | --- | --- |
| T1 | 蹲攻 400–440（4 个） | 完成 |
| T2 | 跳攻 600–640（4 个） | 完成 |
| T3 | 站立四键按技能表定位整理 | 完成（D 的判定框拉长到 x=84） |
| T4 | 2 个普通必杀 | 完成（1000 突进直拳 / 1100 升龙踢·对空） |
| T5 | EX 从"模板入口"变成真强化技 | 完成（1010：伤害 85→130、位移 22→32、加击倒） |
| T6 | 第一个 Super（3000+） | 完成（3000：236236+A，耗 1000 气，伤害 200） |
| T7 | 最小取消链 | 完成（等级系统，见 §6） |
| T8 | 投技作为角色实际动作 | 完成（沿用 800/810/820/821） |
| T9 | 第一次维护 Frame Data | 完成（`design/characters/test_fighter_a/moves.csv`） |
| T10 | 独立角色的基础 CPU AI | 完成（AI.zss：Normal / 2 Special / EX / Super / 投技） |

## 3. P2 输入

- `game/chars/_template/`（12 文件，P2 PASS 的模板）
- `game/chars/_template/README.md` 的克隆三步 + 状态号/变量/气槽/取消约定
- `tests/p1/`（观测装置）、`tests/p2/inject_phases.ps1`（多键相位注入）
- `assets/LICENSE_MANIFEST.csv`（占位素材登记）

## 4. Template 克隆结果（GATE-03 / GATE-04）

克隆**只按模板手册 §2 执行**，过程中发现手册缺三项，已在模板里就地修正
（不是绕过）：

| # | 模板手册的问题 | 处置 |
| --- | --- | --- |
| 1 | 改名清单只写了 `[Info] name`，漏了 `displayname`（画面显示名） | 补进清单 |
| 2 | 没说"克隆体里的 README.md 是模板手册、必须改写成自己的" | 补进清单 |
| 3 | 没有**验证步骤** —— 而 `scripts/test.ps1` 是静态检查，**根本不加载角色**，改名改错只能靠肉眼 | 新增手册 §2.1"克隆后自检"三项（同步输出里出现新目录、运行时目录内文件名正确、引擎无加载错误） |

另外修正两处与本轮无关但事实不符的文档/脚本问题：

| # | 问题 | 处置 |
| --- | --- | --- |
| 4 | `scripts/sync_game_content.ps1` 的完成消息无条件打印 `(-WhatIf)`，正常执行时也显示，误导使用者以为没真复制 | 改为仅在 WhatIf 模式下追加该标记 |
| 5 | `tests/p1/README.md` 把 `montage_states.ps1` 的参数写成 `-Prefix`（脚本没有这个参数） | 改正为 `-Image`，并补参数表 |

克隆结果：`game/chars/test_fighter_a/` 12 文件、`-p1 test_fighter_a` 可加载、
`displayname = "Test Fighter A"` 出现在画面上（证据 `logs/p3/shots/v01_load_01.png`）。

## 5. Fighter A 设计（新增动作）

| 类别 | 状态 | 说明 |
| --- | --- | --- |
| 蹲攻 | 400 / 430 / 410 / 440 | 全部下段（`guardflag: L`）；440 是扫腿（`Trip` + `fall: 1`） |
| 跳攻 | 600 / 630 / 610 / 640 | 空中；**不写落地逻辑**，靠引擎进公共状态 52 |
| 必杀 1 | 1000 | 236+A「突进直拳」：突进 22 px、伤害 85 |
| 必杀 2 | 1100 | 214+A「升龙踢」：判定框高到 y=-131 的对空技、伤害 70、击倒 |
| EX | 1010 | 236+C：伤害 130、突进 32 px、击倒，耗 500 气 |
| Super | 3000 | 236236+A：伤害 200、突进 44 px、击倒且不可受身，耗 1000 气 |

改动（相对模板）：`power` 上限 1000 → **2000**（模板的 1000 只够一次 EX，
放不下 1000 气的 Super —— 仍是引擎唯一的 `power`，不是第二套气槽）；
站立 D 的 `Clsn1` 从 x=67 拉长到 **x=84**（"最长距离重攻击"定位）。

状态号规律（本轮固定，与 KFM 一致）：`+0 = A 轻拳 / +10 = C 重拳 /
+30 = B 轻脚 / +40 = D 重脚`，站立 200 系、蹲 400 系、跳 600 系三段同构。

## 6. Frame Data

`design/characters/test_fighter_a/moves.csv` —— 18 行，逐招给出
State / Anim / Startup / Active / Recovery / Damage / Power / Cancel。
数值来源：`.air` 的帧长与 `.zss` 的 `damage`（两者都是代码真值），
方法：**逐个元素数帧**（`Startup` = 首个 Clsn1 帧之前的帧数之和）。

## 7. Cancel（T7）

在 `command.zss` 用一个函数 + 两个变量实现**等级递增**的取消链：

```text
lv1 轻普通技 → lv2 重普通技 → lv3 必杀 → lv4 EX/Super
```

- 每个攻击状态 `time = 0` 调 `AtkInit(lv)`：写 `var(3) = lv`、关 `var(4)`
- 首个判定帧把 `var(4)` 置 1（取消窗口开启）
- 放行 = `[Function CanChain(lv)]`：地面自由态，或 `var(3) < lv && var(4) = 1 && var(0) = 0`
- 等级只增不减 → **连段长度天然有上限（≤4 段），不可能无限循环**

## 8. AI（T10）

`AI.zss` 顺序表（顺序 = 优先级）：防御 → 对空（1100）→ Super → EX →
Special 1 → 近身普通技（200/430/210）→ 投技 → 走路。

③④⑤ 的距离波段相同，用 **Power 条件 + `random` 概率闸门**分开，
避免"一条宽条件吞掉后面全部"（P1 实验 E6 的失败模式）。

## 9. 测试（Runtime Test）

矩阵与证据见 Phase Report §3。本轮新增装置
`tests/p3/run_match_watch.ps1`（为什么需要它、怎么用见 `tests/p3/README.md`）。

**本轮踩到的注入坑（都会静默或半静默地毁掉证据）**：

| # | 坑 | 现象 | 处置 |
| --- | --- | --- | --- |
| 1 | `-Phases 'a','b'`（数组形式） | `pwsh -File` 把多出来的参数按位置绑到**下一个参数**（实测绑到 `-RoundTime` 直接报错；若绑到 `-Stage` 则**静默**用错场景） | 改成单个逗号字符串；补进 `tests/p2/README.md` 与 `tests/p3/README.md` |
| 2 | 跳攻注入：相位之间隔着截图 | 相位 2 按下时角色已落地 → 永远看不到空中招 | 相位 1 缩短到 0.30 s + `-NoStillShots` |
| 3 | 一次合成长按只维持约 1.2 s 的"前进" | 走路在到达对手前就停了（引擎在 forward buffer 清空时把角色退回状态 0） | 用**多次新按下**代替一次长按 |
| 4 | 取消链的窗口很短 | 第一次测试的后续按键落在源状态**结束之后**，测到的是"自由态出招"而不是取消 | 按帧数反推窗口（210：tick 10–27），把相位压到窗口内 |
| 5 | `Ctrl+D` 偶尔没被引擎接住 | 截图里没有状态读数，"看着像成功" | 给 `run_match_watch.ps1` 补了覆盖层检测 + 重试（3 次），并把结果写进报告 |
| 6 | 两个 harness 同时跑 | 两个游戏窗口抢焦点 → `foreground acquired=False`，注入与覆盖层全失效 | 串行执行；报告里保留焦点行便于自查 |

## 10. 回归（Regression）

- `scripts/test.ps1`：**26/26 PASS**（exit=0）
- IKEMEN baseline 未变（submodule HEAD = pin）、submodule 干净
- `_template` 自身：改名/扩展全部发生在 `test_fighter_a/`，
  模板只在**文档**层面被修正（§4），未改任何战斗逻辑

## 11. 主要修改文件

| 文件 | 变更 |
| --- | --- |
| `game/chars/test_fighter_a/`（新增 12 文件） | 角色本体：`.def/.cmd/.const/.zss/.air/.sff/.snd` + `command.zss`/`hits.zss`/`AI.zss`/`movelist.dat`/`README.md` |
| `design/characters/test_fighter_a/moves.csv`（新增） | Frame Data 表（18 行） |
| `design/characters/test_fighter_a/README.md`（新增） | 设计说明 |
| `tests/p3/run_match_watch.ps1`（新增） | 无人值守对局 + 引擎崩溃日志监视 + 覆盖层自检 |
| `tests/p3/README.md`（新增） | 装置说明（含三条 stdout 实测结论） |
| `docs/phase_reports/P3-test-fighter-a.md`（新增） | V01–V29 逐条证据 |
| `docs/P3-summary.md`（新增） | 交接说明 |
| `game/chars/_template/README.md`（修改） | 克隆清单补 `displayname` / README 改写 / §2.1 克隆后自检；§5.1 指向 Fighter A 的实现 |
| `scripts/sync_game_content.ps1`（修改） | `(-WhatIf)` 标记只在 WhatIf 模式打印 |
| `tests/p1/montage_states.ps1`（修改） | `-Steps` 由 `[int[]]` 改为字符串参数（`pwsh -File` 无法绑定逗号列表） |
| `tests/p1/README.md`（修改） | 参数表改为实际的 `-Image` 并记录 `-Steps` 陷阱 |
| `tests/p2/README.md`（修改） | `-Phases` 必须是单个逗号字符串 + 参数错绑的警告 |
| `assets/LICENSE_MANIFEST.csv`（修改） | 登记 `test_fighter_a.sff/.snd`（KFM 占位，`prototype_only`） |
| `README.md` / `docs/development_status.md`（修改） | 当前阶段更新为 P3 PASS |

## 12. 已知问题

1. 占位 SFF/SND（KFM，CC-BY-NC，`prototype_only`）—— 发布前必须替换。
2. Super/EX 无表现层（无 superPause、无闪光/镜头）；属 P7。
3. 取消不要求命中（空挥可取消），刻意放宽。
4. 蹲/跳判定框几何沿用 KFM 原型（精灵同一套）。
5. 跳重拳 610（70）/ 跳重脚 640（75）的伤害**未实测**（自动注入的跳入攻击
   在采样窗口内未命中；轻版 600/630 已实测 25/30）。
6. 模板与角色都不路由进防御状态；防御依赖引擎级 guard（已实测有效）。
   若将来要做防御姿势动画，需要 `blocking` 命令 + 路由（P4/P7）。
7. V19（Clsn 可视化）未取得带判定框的截图：`Ctrl+C` 是**状态型**切换，
   多次运行会交替开关，而直接改 `config.ini` 的 `ClsnDisplay=1` 也没有在
   本轮截图里体现。因此 V19 以"`.air` 定义 + 运行时 ElemNo/Time 对照"取证。
8. 环境提示：本轮期间用户桌面上有 Dota 2 等前台窗口时，harness 会拿到
   `foreground acquired=False`，注入与截图都不可信 —— **串行执行、且报告里
   要核对焦点行**。

## 13. 后续工作（给 P4）

- 开 PR：`feature/p3-test-fighter-a` → `main`，标题
  `P3: Test Fighter A — first independent fighter (normals / specials / EX / Super / cancel chain / AI)`。
- 见 [`docs/P3-summary.md`](../P3-summary.md) 的"P4 可以直接复用什么"一节。
- P4（Test Fighter B）应重点验证"第二个不同风格角色加入后体系是否通用"，
  而不是重复 P3 的"能不能做出角色"。

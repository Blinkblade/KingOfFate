# Iteration: 复核美术补强后的玩法规则，修掉五处「文档承诺、代码没做」

## 基本信息

- 日期：2026-10-31
- Phase：P6 — First Final-Art Character
- Branch：`feature/p6-first-final-art-character`
- PR：本轮未创建、未合并
- 状态：本地修复与机器验证 **PASS**；人工试玩与负责人决策仍 **BLOCKED**
- 接手基线：工作区未提交的美术补强改动（`00f00ec` 之上）

## 本次目标

负责人让 GPT 润色动画、特效与闪避逻辑之后，要求重新梳理项目并更新现状。复核的方式不是读描述，而是**把「文档/出招表/注释承诺的规则」逐条拿到代码和引擎源码里对账**。

结论：美术与特效部分是干净的（可重建、可校验、逐像素 0 不一致），但**玩法规则层有五处承诺是空的**，且都不报错、都能玩。

## 五个问题与修法

| # | 承诺在哪 | 代码实际 | 修法 |
| --- | --- | --- | --- |
| 1 | 出招表 / `movelist.dat`：射箭 **300 气**；`command.zss` 也要求 `power >= 300` | State 1000 **没有扣气行** → 300 气可无限射箭 | `if time = 0` 加 `powerAdd{value: -300}`（原 1000 是本角色主力手段，影响最大） |
| 2 | 出招表：升斬 **400 气** | State 1100 同样没有扣气行 | 加 `powerAdd{value: -400}` |
| 3 | 出招表 / `movelist.dat`：幻想崩坏 **800 气**；路由门槛也是 800 | State 3000 扣 **1000** → 扣穿到 0，"800 可放"变成"必须攒 1000" | 改为 `-800` |
| 4 | 出招表：闪身「前 12 tick 无敌 + 后 8 tick 可被惩罚」 | 状态级 `velSet` 每 tick 重写速度，`if time = 12 { velSet{x: 0} }` 下一 tick 即被覆盖 → **收招 8 tick 仍在滑**，可惩罚窗口不存在 | 位移改成 `if time < 12 {...}` / `if time >= 12 { velSet{x: 0} }` 分段 |
| 5 | 出招表用途表 / `AI.zss` 注释：「跳劈下压 = overhead 破防」 | `guardflag: MA` = H\|L = 上下都能防 | 改裸 `guardflag: H`（只能站防） |

附带第 6 处：**AI 绕过气量门槛**。AI 是直接 `changeState`，`command.zss` 里的 `power >= N` 对它完全不生效；射箭规则原本没有 `power` 条件，于是 AI 在 0 气时照样出箭（扣气被引擎夹在 0 值）——**人类修好扣气后，AI 仍然白嫖**。已给该规则补 `power >= 300`。

## 主要修改文件

- `game/chars/archer/archer.zss`（三处 `powerAdd`、两处闪身位移、一处 `guardflag`、过期的文件头/技能注释）
- `game/chars/archer/AI.zss`（射箭规则补气量门槛）
- `design/characters/archer/movelist.md`（闪身时长写法、位移分段教训、用途表里 overhead 的目标改对）
- `docs/PROGRESS.md`、`docs/HANDOFF.md`（现状、验证数字、新增引擎事实与踩坑行）

## 技术细节

`guardflag` 的语义取自引擎源码而不是记忆：`compiler.go` 的 `flagSub` 里 `M` 展开为 `HF_H | HF_L`，`char.go` 判防时只查 H / L / A 三个位。所以 `MA` 就是「站防、蹲防、空防都成立」，与 overhead 无关；overhead 必须是裸 `H`。

闪身位移的坑分两层：第一层是 `velSet` 写在 `if time = 0` 里只生效一帧（已有记录）；第二层是**写在状态级仍会被自己覆盖**——状态级每 tick 都把速度写回 11 / -10，一次性置零无效。所以"停住"必须也是一个每 tick 成立的条件。这一点已写进 `HANDOFF.md` §7.1 与出招表。

`<` 与 `>=` 在触发器里可用，先查了引擎自带 `common1.cns.zss` / `action.zss` 与 `compiler.go` 的运算符表才写。

## 测试

2026-10-31 实测：

| 检查 | 结果 |
| --- | --- |
| `python tools/audit_moveset.py` | **PASS**：Archer 0 项 |
| `python tools/character_validate/validate_character.py game/chars/archer` | **WARN**：0 错误、3 警告（110/115/117 前 12 tick 刻意无受击框）、14 INFO（11 个纯视觉动画无受击框）；退出码 0 |
| `pwsh -File scripts/test.ps1` | **PASS**：smoke 26/26、asset tool 86/86 |
| `pwsh -File scripts/test.ps1 -Full` | **PASS**：smoke 26/26、asset tool 91/91 |
| `scripts/sync_game_content.ps1` | **PASS**：6 item(s) copied；`game/` 与引擎运行目录四个文件 md5 全一致 |
| `tests/p3/run_match_watch.ps1 -P1 archer -P2 archer -Ai1 8 -Ai2 8 -RunSec 40 -Shots 3` | **PASS**：镜像 AI 对局正常启动、3 张截图、**0 新增崩溃日志** —— 这条是「改完 `.zss` 必须过引擎加载」的实证（`validate_character` 不解析 ZSS 语法） |
| 21 招伤害对账（`movelist.md` ↔ `.zss` 的 `hitDef.damage`） | **PASS**：21/21 一致，含 3000 三段合计 126、3100 十段合计 160 |

原始输出：`logs/verify-20261031-test.txt`、`logs/verify-20261031-test2.txt`（修复后）、`logs/verify-20261031-full.txt`、`logs/verify-20261031-sync.txt`、`logs/verify-20261031-load/`（对局报告 + 3 张截图）。

截图目检（仅作粗判）：红/炭灰两套配色同时出现、无绿色调试色；脚底无整条黑边；持剑待机与倒地姿势正常；无巨大色块或半截角色。这一条**不构成平衡或命中证据**。

## 已知问题

- **BLOCKED（待人工）**：闪身能否真穿箭、收招是否真的停住并可被确反、射箭扣 300 后的气账节奏、音效、整体手感。注入装置送不出可靠的双键同按，闪身只能人测。
- **BLOCKED（待人工）**：跳劈改成 overhead 后，蹲防会被打破；站防的答案是投技。这条是否就是想要的攻防循环需负责人确认。
- **未验证**：突进斩（1300）/ 后撤投剑（1200）换过美术动作后，状态里的 `posAdd` / 速度是否仍与新动作对齐。
- 本轮没有启动引擎，未新增任何运行时结论；此前的真实桌面对局截图仍属 2026-10-21 那一轮。

## 后续工作

先人工试玩上面两条 BLOCKED，再决定可选技术层（M1）与 P6 PR 合并（F3）。

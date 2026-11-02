# 交接文档（新窗口从零接手用）

> **这是接手的第一份文件。** 读完它再去读别的。
> 写于 2026-10-21；2026-10-31 复核并修掉四条玩法规则硬伤。分支 `feature/p6-first-final-art-character`，**尚未合并 main**。
>
> 最近一次实测（2026-10-31）：smoke **26/26** · asset tool **86/86（默认）/ 91/91（-Full）** · 招式体检 **0 项** · 角色校验 **WARN（0 错误、3 警告，对应闪身的刻意无敌窗口）** · Archer 镜像 AI 对局 40 s **0 新增崩溃日志**（ZSS 加载实证）· 出招表 21 招伤害与代码 **21/21 一致**。
>
> 2026-10-21 基础美术首轮补强：独立闪身动作、双刀突进、空中下斩、11 个纯视觉动画、四种正式配色和待机黑边清理。重建/预览见 [`art-pass.md`](../design/characters/archer/art-pass.md)。
>
> 2026-10-31 修掉「文档写着、代码没做」的五处：射箭/升斬不扣气、幻想崩坏多扣、闪身收招仍在前移、跳劈不是 overhead、AI 零气白嫖。详见 [`20261031-gameplay-rule-fixes.md`](iterations/20261031-gameplay-rule-fixes.md)。

---

## 一、这个项目是什么

**KingOfFate** —— 一个 2D 格斗游戏，用 IKEMEN GO 引擎 + 自制角色。

**目标不是"做一个格斗游戏"，而是"做一个操作门槛低、但深度足够的格斗游戏"**。
核心设计决定（见 [`game-design-charter.md`](game-design-charter.md)，**方向性最高优先级**）：

| 设计支柱 | 含义 | 落地方式 |
| --- | --- | --- |
| **人人能放** | 禁止搓招 | 所有技能 = 「方向+按钮」或「按钮+按钮」 |
| **量大管饱** | 招式多 = 正反馈频率高 | 每角色 20+ 招 |
| **反制为纲** | 深度来自拆解对手的选择 | 每招有可被确反的收招 + 空间/惩罚层 |
| **三层深度模型** | 广度 / 空间惩罚 / 可选技术 | 不是招式相克表 |

**操作分层只有一条规则**（不需要新增按键、不改引擎键位）：

```text
只用 A / S / Z / X  →  不耗气的普通招式
带 C 或 D           →  消耗气槽的技能（C 中型 300~400、D 大型 600~800、C+D 终极 2000）
```

---

## 二、现在做到哪里了

**P0–P5 全部完成并已合入 main。P6（第一个正式美术角色）功能已完成，卡在"人眼/耳朵/手感验收"和"PR 合并"。**

### 阶段回顾

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| P0 | 骨架（引擎 pin、目录、脚本） | ✅ 已合 main |
| P1 | 引擎架构实测（状态号、帧数据、判定框语义） | ✅ 已合 main |
| P2 | 角色模板（`_template`） | ✅ 已合 main |
| P3 | 首个角色（`test_fighter_a`） | ✅ 已合 main |
| P4 | 第二个角色（`test_fighter_b`，Zoner 样板） | ✅ 已合 main（有遗留问题，见第五节） |
| P5 | 资产工具链（SFF/AIR/SND 读写 + 校验） | ✅ 已合 main（PR #7 `9f8dcad`） |
| **P6** | **第一个正式美术角色 `game/chars/archer/`** | **进行中，未合并** |

### P6 已完成的东西

- **美术**：高清素材（1803 精灵 / 423 动作，站立 162×249），SFF v1→v2 转码完成
- **21 个攻击招式全部可用**：12 普通 + 投技 + 4 中型（带 C）+ 3 大型（带 D）+ 1 终极；另有 3 种闪身
- **每招都有可被确反的收招**（9~20 tick）—— 深度的来源
- **伤害已配平**（按"风险 × 回报"）
- **闪身系统**（KOF97 的 A+B）：12 tick 无敌 + 8 tick 可惩罚
- **可选技术层三个全部落地**：T1 同键二段（250~253）/ T2 完美防（格挡瞬间按 ← → +80 气 + 格挡环）/
  T3 前摇取消（普通技起手内按气键，多花 100 气）
- **端到端验收入口**：`pwsh -File tests/p6/verify_moves.ps1 -Pass all` ——
  30 条配方 + T2，全部有 Runtime 数字；**当前 30/30 PASS + T2 PASS**（2026-10-31）
- **招式体检工具**已接入回归
- 退役代码（旧 EX 1010）已删除

---

## 三、必须掌握的命名陷阱（**最容易搞错的地方**）

**同一个"键"有三套名字**，设计文档、引擎文件、键盘三者不一致：

| 设计文档里叫 | 引擎里叫 | **键盘实际按** | 说明 |
| --- | --- | --- | --- |
| `A`（轻拳） | `x` | **`a`** | |
| `S`（重拳） | `y` | **`s`** | |
| `Z`（轻脚） | `a` | **`z`** | |
| `X`（重脚） | `b` | **`x`** | |
| `C`（气键·中型） | `c` | **`c`** | |
| `D`（气键·大型） | `z` | **`d`** | ⚠️ 引擎里叫 `z`，但键盘是 `d` |
| `C`+`D`（终极） | `c`+`z` | **`c`+`d`** | |
| **闪身** | 方向 + `x`+`a` | **`→`/`←`/`↓` + `a`+`z`** | 方向配合轻拳+轻脚同时按；不带方向未定义闪身命令 |

方向键就是方向键。物理键位来自 `engine/ikemen-go/save/config.ini` 的 `[Keys_P1]`，四键分工来自 `archer.def` 的注释。

---

## 四、代码结构（改哪里能改什么）

```text
game/chars/archer/
├── archer.def        文件映射 + 四键→调色板映射（唯一实质内容就是映射）
├── archer.const      常量：体力/尺寸/速度/位移/变量台账
├── archer.cmd        命令定义：物理按键 → 命令名
├── command.zss       命令路由：命令名 → 状态号（★ 书写顺序 = 优先级，窄条件在前）
├── archer.zss        状态机本体（StateDef + 帧数据）
├── AI.zss            CPU AI（★ 书写顺序 = 优先级）
├── hits.zss          投技受击方状态
├── archer.air        动画 + 判定框（AIR）
├── archer.sff        精灵容器
├── archer.snd        音效
└── movelist.dat      游戏内出招表（纯展示）

design/characters/archer/
├── movelist.md       ★ 招式总表（数据全部实测，改完 .air 要重跑生成）
├── situation_table.md 情境标签表 + 覆盖检查
├── asset_map.csv     ★ 我们的动作号 → 源素材的组/图（换美术只改这张表）
└── README.md         角色设计与验收说明
```

**权威文档（按这个顺序读）**：
1. `docs/PROGRESS.md` — **进展总览 + 唯一清单，入口**
2. `docs/game-design-charter.md` — **总纲，方向性最高优先级**
3. `docs/HANDOFF.md` — 本文
4. `docs/GLOSSARY.md` — **术语表，讨论前先对齐用词**
5. `docs/character_asset_tooling.md` — 工具链权威说明
6. `docs/ikemen_character_architecture.md` — 引擎架构（状态号语义、判定框语义）
7. `docs/P6-acceptance-checklist.md` — 验收记录（31 项 PASS）
8. `docs/TODO-backlog.md` — 施工清单

---

## 五、当前问题（按严重度排序）

### 5.1 需要人实测（机器验不了）

| # | 问题 | 为什么机器验不了 |
| --- | --- | --- |
| **1** | **闪身（方向 + `a`+`z`）是否真的能穿过箭矢** | 注入测试装置送不出可靠的双键同按 |
| **2** | **伤害手感**（刚配平，需用眼睛看血条） | 需要人的判断 |
| **3** | **音效对不对**（哪个是打击感、哪个是格挡声） | 我按使用频次猜的映射（`9000,0` / `9000,1`），需试听 |
| **4** | **无限剑制的剑形态**（`c`+`d` 触发） | 之前是"实心光柱"，已换成剑阵，未目检 |
| **5** | **气账节奏**（2026-10-31 起射箭真的扣 300 气了） | 出招自带 +40，净扣 260 → 满槽 2000 约 7 发。"够不够用、会不会太紧"只有人能判断 |
| **6** | **三个可选技术层是否"有意思"** | T1 同键二段 / T2 完美防 / T3 前摇取消 —— 机器只证明了**能触发**（30/30 + T2 PASS），好不好玩要人打 |

### 5.2 已知未修完的技术项

| # | 项 | 说明 |
| --- | --- | --- |
| 1 | 四个气键技能的**垂直判定带**是统一算法给的 | 外缘按素材实测了，高度带没逐帧精调 |
| 2 | `test_fighter_b` 有 **7 项体检问题**（收招过短、受击框缺口、特效帧） | P4 遗留角色，本轮未动（守卫测试会标记非 P6 改动） |
| 3 | ~~突进斩（1300）/ 后撤投剑（1200）的位移与新动作是否对齐~~ | ✅ 2026-10-31 已复现：对峙距离 **+82.50 / −91.25**，期间最大 `abs(velX)` 6.38 / 5.53，收招后不再滑 |
| 4 | **T2 的样本量受 AI 行为限制** | 24 s 内只发生 3 次蹲防（对手出招中位距离 94.6，多数打空）。判定以「特效环出现」为准，样本数写进报告 |
| 5 | **T1 连 X（253）的二段不稳定** | 重脚击退把对手推到 `body gap 54.6`，二段 9 tick 射程 77.8 覆盖不到 → 按 `min` 判定。这是平衡事实，留 P10 |

> 2026-10-31 已修：射箭/升斬扣气、幻想崩坏扣气量、AI 用气门槛、闪身收招位移、跳劈 overhead —— 见 [`20261031-gameplay-rule-fixes.md`](iterations/20261031-gameplay-rule-fixes.md)。
> 2026-10-31 端到端验收又补掉 5 条：受击框预放大、投技三段空、T1 二段窗口、方向键语义（验收脚本侧）、T2 测试方式（验收脚本侧）—— 见 [`20261031-full-moveset-acceptance.md`](iterations/20261031-full-moveset-acceptance.md)。

### 5.3 需要负责人决策（卡住的）

| # | 项 | 卡在哪 |
| --- | --- | --- |
| **M1** | **可选技术层**（总纲 §3.3 建议 3~5 个：同键二次 / 完美防 / 前摇取消） | ✅ 三个都实现并机器验证；剩「好不好玩」要人判断（见 5.1 #6） |
| **F1** | 闪身够不够（作为"不耗气的脱身手段"） | 需试玩判断 |
| **F3** | **PR 合并 main** | 负责人明确「P6 等完善后再合入」 |

### 5.4 ⚠️ 最大风险：动画产能（P7 开工前必须有结论）

一个角色 20+ 招 = 20+ 段动画。**当前素材只能覆盖一部分**。
这是「量大管饱」能否落地的关键。对策方向：换动作更全的素材源 / AI 辅助重绘 / 招式复用。

**这条不解决，P7 会撞墙。**

---

## 六、接下来的事（推荐顺序）

```text
1. 试玩，把 5.1 的六项过掉（尤其闪身能不能穿过箭矢、三个可选技术层好不好玩）
2. 手感 OK → 合并 main（负责人明确要求「P6 等完善后再合入」）
3. 并行推进：动画产能的结论（决定 P7 怎么做）
4. 之后才是 P7（第二个正式角色）—— 直接复用 tests/p6/verify_moves.ps1 的配方表与探针接线
```

---

## 七、⚠️ 给接手者的警告（**这一节最值钱**）

这些坑**每一条都真实发生过**，而且大部分**引擎不报错**——招只是"不出伤害"或"看起来不对"，没有任何提示。

### 7.1 最容易重犯的错（每一条都真实发生过）

| 错误写法 | 真实行为 |
| --- | --- |
| 投射物动画没有 `Clsn1` | **完全不造成伤害**（状态脚本里 `damage: 60` 写得再对也没用） |
| 判定框存在 = 打得中 | ❌ 还要看**判定框与受击框是否重叠**。箭矢曾从头顶 1 个单位处飞过，全程打空 |
| `Clsn2: 0` = 无敌 | ❌ 那是**空数组**不是 nil；引擎用 `Clsn2 == nil` 判断。**要无敌就一行 Clsn2 都不写** |
| `velSet` 写在 `if time = 0` 里 | ❌ 只生效一帧 → **人物不动**。要移动必须写在**状态级**（每 tick 生效） |
| 状态级 `velSet` + `if time = 12 { velSet{x: 0} }` = 停住 | ❌ 下一 tick 状态级又把速度写回来 → **收招仍在滑**，"可被惩罚"不存在。要停住必须 `if time >= 12 { velSet{x: 0} }` **分段** |
| 路由层写了 `power >= 300` = 会扣气 | ❌ 门槛只**挡**不**扣**。扣气要状态里的 `powerAdd{value: -N}`；只挡不扣 = **300 气无限放** |
| AI 会遵守 `command.zss` 的气量门槛 | ❌ AI 直接 `changeState`，**完全绕过路由层** → 每条 AI 技能规则都要自带 `power >= N`，否则零气白嫖 |
| `guardflag: MA` = 破防 | ❌ 引擎里 `M = H|L`（`compiler.go` 的 `flagSub`）→ 上下都能防。**overhead 要写裸 `H`** |
| 帧高够大 = 人物帧 | ❌ 举臂拉弓的角色帧可达 396px。判据是**填充率 15~65% + 行宽有起伏** |
| 写了 `hitDef` = 打得中 | ❌ `clsnCheckSingle`（`char.go:10485`）先看 `len(clsn1) > 0`：**AIR 里没有 Clsn1 就永远打不中**。投技 0 伤害就是这么来的 |
| `hitflag: M-` 的 `-` = "某种附加条件" | ❌ `-` 在 `compiler.go:flagSub` 里是 `HF_MNS`，判据 `HF_MNS != 0 && hittmp > 0 → 打不中`，即**只打从没被打过的目标**。投技抓不到站着的人 |
| 文件头写"Clsn 已预放大" = 真的放大了 | ❌ 只放大 Clsn1、漏掉 Clsn2 时**不报任何错**，症状是一片招 0 伤害（受击框比推挤盒还窄）。改判框后必须**两头都查** |
| 按键窗口按墙钟毫秒估够用 | ❌ 命令缓冲按 **gameTime** 计时，而**命中停顿期间 gameTime 走、状态不走** → 一次重拳命中能吞掉 13 tick，窗口凭空少一半 |
| 设计方向 `fwd` 直接映射成键盘右键 | ❌ 引擎里**物理 LEFT/RIGHT 恒等于世界 −x/+x**（`char.go:6510` 的 `fbFlip` + `input.go:2802`），不是角色的前/后。p1 一转身，所有"方向 + 键"就镜像了 |
| `powerAdd{value: 80}` 一定观测得到 | ❌ 满槽时 `setPower` 会 `Clamp(0, powerMax)`（`char.go:8807`）把增益吃掉。**扣气不受影响**，增益要留余量才测得到 |
| 调试脚本留在 `external/mods/*.lua` | ❌ `external/script/main.lua:3986` 会 `require` 该目录里**每一个** lua，在 "NOW LOADING" 界面抛 Engine error 直接退出（2026-11-03 被一行 `error()` 探针卡死）。目录被 gitignore，`git status` 永远干净 —— 靠 `run_game.ps1` 预检（exit 4）发现 |

### 7.2 工作流纪律

- **改完 `.zss` 必须跑一次引擎加载** —— `validate_character` **不解析 ZSS 语法**，
  `hitsound::`（双冒号）能让整个角色加载失败而它不报
- **批量改脚本只改数据行、不动注释**；要加注释一律加在完整语句之后（注释吞参数踩过）
- **heredoc 有两个坑**：`<<'PYEOF'` 仍会**吞反斜杠**（`\d`→`d`，正则静默失配）；
  `<<PYEOF`（无引号）会让 markdown 里的**反引号被 bash 当命令执行**，吃掉文档内容
- **输入测试失败时，先怀疑测试装置，再怀疑角色**（踩过两次）
- **2026-10-31 第三次，也是最贵的一次**：验收脚本把设计方向写死成物理键，p1 一转身，
  四条配方全部镜像，报告上表现为「三个技能坏了」。两条硬规矩：
  ① **方向键一律按 `facing` 换算**（引擎里物理 L/R = 世界 ∓x）；
  ② **走位失败必须标 `POS-FAIL`**，不许伪装成 `STATE-MISS` —— 两者症状一模一样，会误导排查方向
- **改完招式跑体检**：`python tools/audit_moveset.py`
- **只通过过的检查不算检查** —— 必须有"应该失败"的用例（已有 `tests/fixtures/assets/char_broken_clsn`）

### 7.3 引擎事实（改任何数值前必读）

- 角色 `xscale = 0.48`，而 **`clsnBaseScale = {xscale, yscale}` → 所有判定框都会乘缩放**
  → AIR 里要写「世界尺寸 ×(1/0.48)」预放大
  例外 1：`projectile{ offset }` **不**跟随缩放
  例外 2：**Clsn3（推挤盒 / `sizeWidth`）用 `localscl`，不乘 `size.xscale`**
  （`char.go:10489-10501` 的 `clsnCheckSingle`：`if charbox == 3 { charscale = {localscl, localscl} }`）
- **`Clsn2Default` 是整个动画所有帧 Clsn2 的并集** —— 头部声明它，就必须预放大，
  否则受击框只有设计值的一半，而画面看起来完全正常
- **逐帧 `Clsn2: N` 只作用于紧邻的那一个元素** → 覆盖整段必须用 `Clsn2Default`
- **`animElem = N`** 会持续整个元素时长 → 投射物发射必须配 `var(10)` 闩锁
- **公共状态勿重实现**（0 / 20 / 50 / 100 / 105 / 170 / 5000+ 在 `engine/ikemen-go/data/common1.cns.zss`）
- 状态号：站立 200、蹲 400、跳 600；必杀 1000/1100；Super 3000；终极 3100；投 800/810；闪身 110/115/117
- **`guardflag` 的字母含义**（`compiler.go` 的 `flagSub`）：`H` = 只能站防、`L` = 只能蹲防、
  `M` = **H|L**（上下都行）、`A` = 可空中防。`char.go` 判防时只查 **H / L / A** 三个位，
  所以 `M` 之所以"上下都能防"是因为它展开成了 H|L。**overhead 必须写裸 `H`，`MA` 不是破防**
- **气量两件事互不替代**：`command.zss` 的 `power >= N` 只**挡**，状态里的 `powerAdd{value: -N}` 才**扣**。
  `power` 是上限（`.const` 里 2000）不是起始值，起点 0、跨 Round 保留；AI 走 `changeState` 绕过路由，需自带门槛
- **方向键的语义（最容易搞错的一条）**：`char.go:6510` 的 `fbFlip = facing < 0` 让
  `input.go:2802-2816` 把**物理 L/R** 换成角色的 B/F。连起来读的结论是：
  **物理 LEFT/RIGHT 永远等于世界 −x/+x**，与朝向无关；而角色的「前/后」需要按 `facing` 换算。
  从引擎外部注入按键时，这两件事必须分开处理（方向指令按 facing，走位按世界方向）。
- **命令缓冲按 gameTime 计时**：`buffer_hitpause` 关闭时（默认），命中停顿期间
  gameTime 照走、状态不执行 → 一次重击能吃掉十几个 tick 的窗口
- **遥测探针能读 `facing` 与 `var(n)`**（`tests/p6/fixtures/archer_probe.zss`），
  不必为观测再加引擎侧能力

---

## 八、命令速查

```powershell
# 构建（离线稳定跑法，实测 52s）
pwsh -File scripts/build_engine.ps1 -BuildFfmpeg no

# 运行
pwsh -File scripts/run_game.ps1            # 加 -CheckOnly 只做预检
                                           # 若 external/mods/ 里有 .lua 会拒绝启动（exit 4）
                                           # 确实要加载则 -AllowMods

# 全量回归（smoke + 工具测试，含招式体检）
pwsh -File scripts/test.ps1

# 把 game/ 同步到 engine/ikemen-go/（单向、幂等；**改完 game/ 必须跑**）
pwsh -File scripts/sync_game_content.ps1

# 角色校验
python tools/character_validate/validate_character.py game/chars/archer

# 招式体检（查那些引擎不报错的问题）
python tools/audit_moveset.py               # 干净=0，有问题=1

# 实测装置
pwsh -File tests/p6/verify_moves.ps1 -Pass all      # ★ 端到端全招式验收（30 条配方 + T2）
pwsh -File tests/p6/verify_moves.ps1 -List          # 只列出配方与编号
pwsh -File tests/p6/verify_moves.ps1 -Pass moves -Only 25,26,28    # 只跑指定配方（隔离排查）
pwsh -File tests/p6/verify_moves.ps1 -Pass guard     # 只跑 T2 完美防
pwsh -File tests/p2/inject_phases.ps1 -P1 archer -P2 test_fighter_b -Phases '0x09:0.12' -ButtonMap 'x=TAB' -Shots 3
pwsh -File tests/p3/run_match_watch.ps1 -P1 archer -P2 test_fighter_b -Ai1 8 -Ai2 8 -RunSec 30
```

`verify_moves.ps1` 的产物（`logs/p6/verify/`）：`report.md`（人读）、`run.csv`（moves 趟逐 tick）、
`run_guard.csv`（T2 趟，**单独一份**，不再被覆盖）、`windows.json`（每条配方的采样窗口）。
注意它会把 `[Keys_P1]` 临时改成 SPACE/RETURN/TAB/BACKSPACE/LSHIFT/LCTRL（本机只有这 6 个键能注入），
跑完无条件还原；跑的过程中不要动键盘。

**本机网络**：外网需手动启动 `http://127.0.0.1:7897`。**push 必须显式带代理**（直连会被掐断）：

```bash
git -c http.proxy=http://127.0.0.1:7897 -c https.proxy=http://127.0.0.1:7897 push origin <branch>
```

---

## 九、交付纪律

- 文档写实话：实测日期 / 真实结果 / 准确路径；**阶段 PASS 与 PR 合并分开报告**
- 未完成必须写 `BLOCKED`，不得写 `PASS`
- 素材许可进 `assets/LICENSE_MANIFEST.csv`；**占位素材绝不能当正式资产验收**
- 不在 `main` 开发；走 `feature/*` + PR（Squash Merge）；一个 PR ≥ 一份 `docs/iterations/YYYYMMDD-<topic>.md`
- 提交前：`git diff --check`、无 logs/导出残留、submodule 指针未动

---

## 十、一页速览

```text
项目       2D 格斗游戏，IKEMEN GO 引擎，自制角色
核心理念   无搓招 / 20+ 招 / 深度来自拆解对手选择
当前阶段   P6（第一个正式美术角色 Archer）功能完成，等试玩验收 + 合并
代码位置   game/chars/archer/          ← Git 真值
运行时     engine/ikemen-go/chars/     ← 由 sync 脚本单向生成
最重要文件 design/characters/archer/movelist.md（招式表，数据实测）
             docs/PROGRESS.md（进展总览 + 清单入口）
             docs/GLOSSARY.md（术语，讨论前先对齐）
回归       pwsh -File scripts/test.ps1 -Full → 26/26 + 91/91
验收       pwsh -File tests/p6/verify_moves.ps1 -Pass all → 30/30 + T2 PASS（Runtime 数字）
下一步     试玩验收（含三个可选技术层好不好玩）→ 合并 main → 解决动画产能 → P7
最大风险   动画产能（20+ 招 = 20+ 段动画），P7 前必须有结论
```

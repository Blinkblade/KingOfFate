# KingOfFate — Base Fighter Template（`game/chars/_template/`）

P2 交付的**可运行、可加载、可复制**的四键基础格斗角色模板（IKEMEN GO
`v1.0.0-rc.5`）。它已经在真实引擎里加载并打完了完整对局（证据见
`docs/phase_reports/P2-base-fighter-template.md` 的"运行时验证矩阵"一节）。

成功标准：**复制本目录 → 改名 → 换美术，就能开始做 KOF 风格角色，
而不需要重新研究角色内部结构。**

## 1. 它是什么 / 不是什么

| | |
| --- | --- |
| **是** | 一个真实可跑的角色：能走、跳、防御、四键站立普通技、投技、必杀、EX、取消、AI 对战 |
| **是** | 一份"每条约定都标注了依据与实测证据"的工程文档 |
| **不是** | 美术成品（精灵是 P1 研究用的 KFM 占位，见 §9）；不是角色框架/继承系统 |
| **不含** | 蹲攻（400–440）、跳攻（600–640）、超杀（3000+）—— 状态号已预留，见 §5 |
| **不提供** | 自动化、生成器、DSL、第二套气槽/取消系统（禁止过度设计，见合同 §29） |

## 2. 怎么克隆（三步）

```powershell
# 1) 复制（Git 真源在本目录；复制体才是你自己的角色）
#    注意：目标目录必须尚不存在 —— Copy-Item -Recurse 到已存在的目录
#    会嵌套成 <mychar>/_template/。
Copy-Item -Recurse game\chars\_template game\chars\<mychar>

# 2) 全目录把 "_template" 前缀替换成 "<mychar>"（文件名 + 文件内引用）
#    改名点清单：
#    - 7 个带前缀的文件名：
#        _template.def / .cmd / .const / .zss / .air / .sff / .snd
#    - 另外 5 个文件**没有**前缀，不要改名：
#        command.zss / hits.zss / AI.zss / movelist.dat / README.md
#      （它们的文件名由 _template.def 的 [Files] 段引用，改的是 def 里的引用）
#    - _template.def [Info] **name**（必须 = 目录名，-p1 用它定位）
#    - _template.def [Info] **displayname**（画面上显示的名字，别漏）
#    - _template.def [Info] versiondate（改成你的日期）
#    - _template.def [Files] 里的 11 条文件引用
#    - 各 .zss/.cmd/.air/.const 顶部注释里的文件自引用（纯注释，但保持一致）
#    - **README.md**：本文件是"_template 的手册"，不是新角色的手册。
#      克隆体必须把它改写成自己角色的说明（Fighter A 的做法见
#      game/chars/test_fighter_a/README.md）。

# 3) 同步到引擎运行目录并试跑
pwsh -File scripts/sync_game_content.ps1
pwsh -File scripts/run_game.ps1 -ExtraArgs '-p1','<mychar>','-p2','kfm_zss','-s','stage0','-windowed'
```

改名后**必须跑** `pwsh -File scripts/test.ps1` 确认仓库回归仍是绿的。

### 2.1 克隆后自检（3 项，别跳）

克隆过程中最容易漏的是"文件改名了但 def 里还指着旧名字"，而这类错误
**不会让脚本失败** —— 只有引擎加载时才会报。所以按顺序做：

```powershell
# ① 同步输出里必须出现新角色目录
pwsh -File scripts/sync_game_content.ps1
#   期望看到：  dir  <mychar>

# ② 运行时目录里必须真的是改名后的文件
Get-ChildItem engine\ikemen-go\chars\<mychar> | Select-Object Name
#   期望：<mychar>.def/.cmd/.const/.zss/.air/.sff/.snd + 5 个无前缀文件

# ③ 引擎控制台里必须没有加载错误
#   tests/p1/capture_match.ps1 只截画面、看不到引擎控制台输出，
#   所以 P3 补了 tests/p3/run_engine_capture.ps1：
pwsh -File tests/p3/run_engine_capture.ps1 -P1 <mychar> -P2 kfm_zss -RunSec 25
#   期望：日志里没有 "New char load failed" / "WARNING" / "invalid state"
#   并且画面里出现 <mychar> 的 displayname
```

> 背景：P3 实际克隆 Fighter A 时，上面的 ② ③ 两项是**新补的步骤** ——
> 原版说明只写到"改名 + 同步 + 跑 test.ps1"，而 `scripts/test.ps1`
> 是**仓库静态检查**，它不会加载角色。缺了 ② ③ 就只能靠肉眼发现"角色没加载成功"。

## 3. 四键映射（合同 §9）

物理键（IKEMEN 按钮名）→ 命令名 → 状态号 → AIR → HitDef，一条线看全：

| 键 | IKEMEN 按钮 | 命令名（.cmd） | 状态（站立） | damage |
| --- | --- | --- | --- | --- |
| **A 轻拳** | `x` | `x` | 200 | 25 |
| **B 轻脚** | `a` | `a` | 230 | 30 |
| **C 重拳** | `y` | `y` | 210 | 70 |
| **D 重脚** | `b` | `b` | 240 | 75 |

其余招式的伤害（都取自 `_template.zss` 的实际 `hitDef` / `targetLifeAdd`）：

| 招式 | 状态 | 伤害 | 备注 |
| --- | --- | --- | --- |
| 投技 | 800 → 810 | **90** | 走 `targetLifeAdd{value: -90}`，**不经过** `hitDef.damage` |
| Placeholder Special（QCF+A） | 1000 | **95 / 85** | 近版 95、远版 85（按 `p2BodyDist X < 40` 分支） |
| Placeholder EX Special（QCF+C） | 1010 | **130** | 耗 500 气；`fall: 1` 强制击倒 |

默认键盘：`x`=A 键、`a`=Z 键、`y`=S 键、`b`=X 键（`docs/controls.md` §2.2）。
投技 = 贴身 + 按住前/后 + C/D（命令 `y`/`b` + `holdfwd`/`holdback`）。

## 4. "想加一个 X" 怎么做

### 加一个新命令（例如 2624+A）
在 `_template.cmd` 追加 `[Command]`；**如果它以 `x` 结尾，新规则必须写在
`x` 单按规则之前** —— `command.zss` 的 `[StateDef -1]` 从上到下先命中者赢
（P1 实验 E5）。当前模板顺序（改顺序 = 改优先级，必须重跑运行时验证）：
EX(QCF_y) → 必杀(QCF_x) → 投技 → FF/BB → 站立四键 → 嘲讽。

### 加一个新状态
在 `_template.zss` 写 `[StateDef <号>]`（编号用 §5 的约定，不要自造区间）。
头部常用：`anim: <action>`、`physics: S/C/A/N`、`poweradd: N`、`ctrl: 0/1`。
退出路径必须显式（`changeState` 回 0 / 10 / 11 / 52，或让 physics 自然收招）。

### 加一个 HitDef（攻击判定）
在攻击状态里写 `hitDef{ ... }`（`{` 必须与控制器名同行）。模板样板的必填位：
`attr: S, NA`（姿态, 类别）、`hitflag: MAF`、`damage: N`、`animtype`、
`guardflag`、`sparkxy`、`hitsound`、`p1stateno`/`p2stateno`（投技用）。
**伤害与判定框完全解耦**（P1 E4）：改手感改 `.air` 帧数/Clsn，改数值改 `damage`。

### 加一个动作（AIR）
在 `_template.air` 加 `[Begin Action <号>]`，编号与状态号同族（200 技 → Action 200）。
`Clsn1`（攻击框，粉色）与 `Clsn2`（受击框，蓝色）逐帧独立标注；
调试时按 `Ctrl+C` 观测（本仓库所有运行时验证就是这么拍的）。

### 加公共常量 / 变量
数值放 `_template.const`（`[Data]/[Size]/[Velocity]/[Movement]`）；
变量占用见 §6 台账，新变量先登记再使用。

### 改 AI
`AI.zss` 的 `[StateDef -1]` 规则顺序 = AI 优先级（P1 E6）。加新招 = 在
合适的优先级位置插一条 `changeState`。**AI 改动后必须重新观测行为**
（用 `tests/p1/capture_match.ps1 -Ai1 8`，见 §8）。

## 5. 状态号约定（§11，来自 P1 架构文档，禁止重编号）

| 区间 | 内容 | 归属 |
| --- | --- | --- |
| 0 / 10–11 / 20–21 | 站 / 蹲 / 走 | **公共状态**（勿自实现） |
| 40–52 / 100 / 105 | 跳 / 前冲 / 后跳 | **公共状态** |
| 120 / 130–155 | 防御入口 / 站蹲防 | **公共状态**（模板实测 State 130 生效） |
| 180 | 胜利姿势（回合结束时引擎要求） | 自实现（占位，见 §11 第 4 条） |
| 195 | 嘲讽 | 自实现（样板在 `_template.zss`） |
| 200 / 210 / 230 / 240 | 站 A / C / B / D | 自实现 |
| 400–440 | 蹲攻 | **未实现，预留**（扩展点） |
| 600–640 | 跳攻 | **未实现，预留** |
| 800 / 810 | 投技触发 / 投掷执行 | 自实现（KFM 同款流程） |
| 820 / 821 | 投技受害方：被抓住 / 被甩出（含受身） | 自实现于 `hits.zss` |
| 1000 / 1010 | 必杀 / EX 必杀 | 自实现 |
| 3000+ | 超杀 | **未实现，预留** |
| 5000–5210 | 受击 / 倒地 / 起身 / 受身落点 | **公共状态**（勿自实现） |

模板自实现的状态：180、195、200、210、230、240、800、810、1000、1010，
以及 `hits.zss` 里的受击方状态 **820 / 821**。
`hits.zss` 只放"投技这种需要被抓住的特殊受击表现" —— 普通技的受击完全交给
公共状态 5000+，不要在这里重复实现。

### 5.1 参考实现：Fighter A 已经把预留区间填满了

模板**只留了号**，真正把它们实现出来的是 P3 的
[`game/chars/test_fighter_a/`](../test_fighter_a/)（可运行、已实测）。
做扩展动作时**直接读它**，不要从零摸索：

| 预留区间 | Fighter A 的实现 | 规律 |
| --- | --- | --- |
| 400–440 蹲攻 | 400 蹲A / 410 蹲C / 430 蹲B / 440 蹲D(扫腿) | `+0=A轻拳 +10=C重拳 +30=B轻脚 +40=D重脚`，与站立位 200/210/230/240 同构 |
| 600–640 跳攻 | 600 跳A / 610 跳C / 630 跳B / 640 跳D | 同上；空中招**不写落地逻辑**，靠引擎进公共状态 52 |
| 1000+ 必杀 | 1000 突进直拳 / 1100 升龙踢（对空） | 每个必杀独立状态号 + 独立动画号 |
| 1010 EX | 1010 EX 突进直拳 | 路由层查 `power >= 500`，状态内 `powerAdd{value: -500}` |
| 3000+ 超杀 | 3000 超必杀直拳 | 路由层查 `power >= 1000`，状态内 `powerAdd{value: -1000}` |

它同时给出两个模板没有的样板：
**取消链**（`command.zss` 的 `CanChain(lv)` 等级系统）
与**独立角色 AI**（`AI.zss`：Normal / 两个必杀 / EX / Super / 投技）。

## 6. 变量台账（先登记再占用）

| 变量 | 用途 | 生命周期 |
| --- | --- | --- |
| `var(0)` | 取消闩锁 cancelUsed（一次连段只许一次取消） | 每次进攻击状态清 0 |
| `var(1)` | AI 冷却 aiCooldown | AI 层私有 |
| `var(2)` | 投技方向 throwDirFwd（1 = 起手按的是"前"） | 每次投技起手时由 810 写入 |
| `var(10)`–`var(39)` | 角色私有 | 角色自己管 |
| `var(40)`–`var(59)` | AI 私有 | AI 层管 |
| `var(60)`+ | 跨回合持久（`IntPersistIndex = 60`） | 谨慎使用 |
| `fvar(0)`–`fvar(39)` | 浮点私有（`FloatPersistIndex = 40` 起持久） | |
| `map("canCombo")` | 只读：当前能否出必杀（`command.zss` 每帧写） | 禁止在状态里改 |

## 7. 气槽 / 取消约定（标准机制，无自造系统）

- **气槽** = IKEMEN 原生 `power`。`_template.const` 的 `power = 1000` 是**上限**，
  **不是起始值**：`char.go:3740` 的 `c.powerMax = gi.data.power` 说明了这一点
  （不写则默认上限 3000，见 `char.go:292`）。**对局开始时气量为 0**，而且
  **气量在对局内跨回合保留** —— 本机实测：第 1 回合用 F3 充满（POW 1000），
  击杀对手结束回合后，第 2 回合开局仍是 **POW 1000**（V18/V19 两轮独立复现）。
- **收入**：`hitDef` 命中给气（引擎按 `default.attack.lifetopowermul` 折算 ≈ 0.7×伤害，
  实测轻拳命中 POW 0→37、重拳 0→84）+ 状态头 `poweradd`（必杀进入 +40）。
  所以"起手就能放 EX"**不是**模板约定 —— 要先打中几次把气攒到 500。
- **支出**：EX 在路由层检查 `power >= 500`，State 1010 内 `powerAdd{value: -500}`
  扣除（实测 1000 → 500，帧证据 `v13_ex_p06_0D_burst07.png`；同一轮事后帧
  `v13_ex_01.png` 显示 P2 掉 130 血）。
- **取消**：`command.zss` 的 `Combo()` 函数返回"现在能否出必杀"：
  地面自由态，或 State 200/230 的 `animElemTime(3) >= 0`（首个攻击帧之后）
  且 `var(0) = 0`。取消发生时状态内把 `var(0)` 置 1 闩锁。
  实测：A 起手 → 取消窗口内 QCF+A → 必杀接管，**一次取消打出 2 段**
  （P2 LIF 880 = 25 + 95，`v14_cancel_01.png`）。

## 8. 运行时验证怎么跑（本机约束）

```powershell
# 玩家侧（可注入按键）：TAB(0x09)=A、RETURN(0x0D)=C、方向键可达
#   本机只有这些键能通过合成注入到达引擎（P1 E0；字母键不可达）
pwsh -File tests/p1/capture_match.ps1 -P1 _template -P2 kfm_zss -Ai1 0 ...
# 多键相位：相位列表必须是**一个逗号连接的字符串**（见 tests/p2/README.md 的坑）
pwsh -File tests/p2/inject_phases.ps1 -Phases '0x28:0.06,0x28+0x27:0.06,0x27:0.06,0x09:0.35' ...
# AI 侧（验证 AI 接口）
pwsh -File tests/p1/capture_match.ps1 -P1 _template -P2 kfm_zss -Ai1 8 ...
```

硬约束（继承自 P1，`tests/p1/README.md`）：
- 注入实验**必须** `-Ai1 0`（AI 吃掉注入输入会静默失败）；
- 注入用 `-HoldSeqVK` / `inject_phases.ps1 -Phases`（多键相位工具，投技/搓招就靠它）；
- 调试覆盖层的 `P1: <n>` 是角色 **ID 不是坐标**；
- 引擎热键（`F3` 充满气、`F1` 击杀对手、`F5` 回合计时归零）**可以**被合成注入
  触发（P2 实测：V13 靠 F3 攒气，V18/V19 靠 F1 造出回合结束）—— 它走的是引擎
  输入路径，和"角色命令层只有 TAB/RETURN 可达"是两条不同通道；
- 本机合成注入测不了 B/D 键与嘲讽（`start`）—— 需要真人键盘验证；
- 读数值时**优先看事后静态帧**（`*_01.png` / `*_02.png`），连拍帧容易读错
  （P2 审计时踩过一次）。

## 9. 占位 SFF/SND：来源与许可（§8）

- `_template.sff` / `_template.snd` **不是本项目的原创资产**。
- 来源：`game/chars/p1_kfm_zss_lab/` 的 `kfm.sff` / `kfm.snd`（Elecbyte 的
  Kung Fu Man，P1 角色架构研究用素材）。
- 许可：**CC-BY-NC**（非商业）。已登记在
  [`assets/LICENSE_MANIFEST.csv`](../../../assets/LICENSE_MANIFEST.csv)
  两行 `_template` 条目，`usage = prototype_only`。
- **从模板克隆的每个角色，在发布前必须把这两个文件替换成自己的原创美术/音频**，
  并更新许可清单。这是硬性要求，不是建议。

## 10. 同步与目录

- 本目录是 **Git 单一真源**（`design/characters/_template/` 已在 P2 迁出，
  那里只留设计散文）。任何修改改这里，不要改 `engine/ikemen-go/chars/`。
- `pwsh -File scripts/sync_game_content.ps1` 单向 `game/` → `engine/ikemen-go/`，
  **绝不反向**（引擎目录是生成物）。
- `stcommon = common1.cns.zss` 不在本目录是**正确的** —— 引擎从 `data/` 搜索，
  不要复制进来（理由见旧版 README 遗留说明与 `compiler.go:8361`）。

## 11. 已知限制（截至 P2 PASS）

1. 蹲攻（400–440）、跳攻（600–640）、超杀（3000+）：状态号与命令已预留，
   实现即扩展。（**受身已实现**：`hits.zss` 821 里通过 `canRecover` →
   5200 / 5210，命令 `recovery` = A+C。）
2. B/D 键与嘲讽的运行时证据依赖真人键盘（本机合成注入不可达）。
3. 精灵/音效是 KFM 占位 —— 每个克隆角色必须替换（§9）。
4. 胜利姿势（180）是**占位**：只播一段姿势动画，没有多姿势选择（181–189）与
   胜利台词 —— 那属于 P7 表现层。补它的直接原因是：回合结束时引擎会把胜者切进
   180，缺了这个状态引擎会打印
   `WARNING: <char> (nn) in state 180: changed to invalid state 180 (from state 0)`。
5. `_template.air` 的攻击帧时长（State 200 共 20 tick）是"可观测性优先"的
   调参值，正式角色按手感调。
6. 取消窗口刻意不要求 `moveContact`（空挥可取消）—— 降低联调门槛；
   正式角色加 `&& moveContact` 收紧。

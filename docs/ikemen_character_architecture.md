# IKEMEN Character Architecture — 角色是如何构成的

> **本文档是 P1（IKEMEN Character Architecture）的研究结论。**
>
> 目的是回答一个工程问题：**在 IKEMEN GO 上，一个角色由哪些文件组成、这些文件在运行时
> 如何协作、以及我们改什么就能改出什么效果。** 结论已经在本仓库内逐条实测验证，验证过程与
> 原始证据见 [`docs/p1_experiments.md`](p1_experiments.md) 与 [`docs/evidence/p1/`](evidence/p1/)。
>
> **可追溯性约定**：本文每条结论后面都标注了仓库内的出处（文件 + 行号）。
> 出处有两种：
> - `game/chars/p1_kfm_zss_lab/…` —— 本仓库跟踪的研究用角色副本（P1 Lab）
> - `engine/ikemen-go/…` —— 钉死的引擎基线（只读参考，未修改）
>
> 引擎基线：IKEMEN GO `v1.0.0-rc.5` = `ba516193bba83f13f0b63ddce314d8719793931f`。

---

## 1. 为什么需要这份文档

KingOfFate 的目标是**做角色和玩法**，不是重写引擎。因此"一个角色"的边界必须是清楚的：

- 哪些东西是**角色的**（改角色文件就能改，不碰引擎）；
- 哪些东西是**共用的**（`data/` 下的公共状态，改它会影响所有角色）；
- 哪些东西是**引擎的**（`src/*.go`，原则上不动）。

P1 的结论直接决定 P2（基础模板）、P3/P4（测试角色）、P5（素材工具链）、P6（正式角色）
的工作范围。**下文所有"文件 → 效果"的对应关系都是实测得出，不是从文档抄来的。**

---

## 2. 一个角色的文件构成

角色的入口是一个 `.def` 文件。它本身**不含逻辑**，只是一张"文件名映射表"。

出处：`game/chars/p1_kfm_zss_lab/p1_kfm_zss_lab.def` 第 28–40 行。

```ini
[Files]
cmd     = kfm.cmd           ;Command set        —— 命令定义（按键组合 → 命令名）
cns     = kfm.const         ;Constants          —— 角色常量（速度、体力等）
st      = kfm.zss           ;States             —— 角色状态脚本（ZSS）
st2     = hits.zss                             —— 额外状态文件（受击/特殊状态）
st3     = command.zss                          —— 命令路由（命令名 → 状态号）
st4     = AI.zss                               —— CPU AI 脚本
stcommon = common1.cns.zss  ;Common states (from data/ or motif) —— 公共状态（共用！）
sprite  = kfm.sff           ;Sprite             —— 精灵图（SFF 容器）
anim    = kfm.air           ;Animation          —— 动画 + 判定框（AIR）
sound   = kfm.snd           ;Sound              —— 音效（SND 容器）
ai      = kfm.ai            ;AI hints data (not used)
movelist = movelist.dat     ;Ikemen feature: Movelist —— 出招表（IKEMEN 特有）
```

引擎侧的读取证据：`engine/ikemen-go/src/compiler.go:8139` 起解析 `[Files]`，
`compiler.go:8162` 读取 `cmd` / `stcommon`，`compiler.go:8361-8362` 决定 `stcommon` 的解析搜索路径
（`[]string{def, "", sys.motif.Def, "data/"}`）——**注意 `data/` 也在搜索路径里，这就是
"公共状态"的来源**。

### 2.1 各文件职责

| 文件 | 扩展名 | 职责 | 运行时角色 |
| --- | --- | --- | --- |
| 角色定义 | `.def` | 文件映射 + 元信息（name / displayname / mugenversion / 调色板映射 / arcade 剧情） | 加载入口，只被读一次 |
| 命令定义 | `.cmd` | 定义"按键组合 → 命令名"（`[Command] name="x" command=x`） | 每 tick 被输入系统查询 |
| 常量 | `.const`（历史上叫 `.cns`） | `[Velocity]`、`[Size]`、`[Data]` 等数值常量 | 启动时读一次，逻辑中通过 `const(...)` 引用 |
| 状态脚本 | `.zss` | `[StateDef N]` 状态主体 + 跳转逻辑 | **核心**：每 tick 驱动角色行为 |
| 命令路由 | `.zss`（`st3`） | `[StateDef -1]`：`if command = "x" { changeState{value: 200} }` | **核心**：命令 → 状态的唯一通道 |
| 公共状态 | `.zss`（`stcommon`） | 引擎/画面包共用的基础状态（站立、走路、跳跃、受击、起身…） | 被所有角色共享 |
| AI | `.zss`（`st4`） | CPU 行为脚本，直接 `changeState` | 仅当该方由 AI 控制时执行 |
| 动画 | `.air` | `[Begin Action N]` 动画帧序列 + `Clsn1`/`Clsn2` 判定框 | 按 `anim: N` 播放 |
| 精灵 | `.sff` | 精灵图容器（IKEMEN 支持新版 SFF） | 按 AIR 里的 `组,图` 取图 |
| 音效 | `.snd` | 音效容器 | 按 `playSnd` / `playSnd` 包装函数取音 |
| 出招表 | `movelist.dat` | IKEMEN 特有的招式列表（给玩家看） | 纯展示，不影响战斗逻辑 |

> **P2 提醒**：`st2` / `st3` / `st4` 是 IKEMEN 相对 MUGEN 的扩展，允许把一个角色的脚本拆成
> 多个文件。KFM 的拆分方式是：`kfm.zss` = 主体状态、`hits.zss` = 受击/特殊、`command.zss` = 命令路由、
> `AI.zss` = AI。**这是可以直接照抄的组织方式，P2 模板应沿用。**

---

## 3. 从按下按键到对手掉血：完整执行链

这是 P1 最关键的结论——**整条链只有 6 个环节，每一环都在仓库里可定位。**

```text
物理按键
  │  SDL_KEYDOWN
  ▼
① 引擎输入层      src/input.go —— GetKeyboardState(kc) 返回 [14]bool
  │                  （第 168 行；键位来自 save/config.ini 的 [P1 Keys] 等段）
  ▼
② 命令匹配        kfm.cmd —— [Command] name="x" command=x
  │                  （每 tick 由引擎比对命令定义文件）
  ▼
③ 命令路由        command.zss [StateDef -1]
  │                  if command = "x" && ... { changeState{value: 200} }
  ▼
④ 状态执行        kfm.zss [StateDef 200] —— type/movetype/physics/anim/velset/ctrl…
  │                  动画推进到 animElem = 3 时触发 hitDef{...}
  ▼
⑤ 攻击框判定      kfm.air [Begin Action 200] —— Clsn1 攻击框 × 对手 Clsn2 受击框
  │                  hitDef 命中 → 应用 damage / pausetime / ground.hittime 等
  ▼
⑥ 对手受击状态    对手进入受击状态，体力按 damage 扣减
```

**每一环的实测验证**（详见 `docs/p1_experiments.md`）：

| 环节 | 实验 | 结论 |
| --- | --- | --- |
| ①② 输入 → 命令 | E5 | 改 `.cmd` 里 `name="x"` 的 `command`，按下同一物理键进入的状态随之改变 |
| ③ 命令路由 | E5 | `command.zss` 是唯一路由点；改它 = 改"哪个命令进哪个状态" |
| ④ 状态执行 | E2 / E3 | 改 `hitDef.damage` → 对手掉血精确变化；改动画时长 → 招式持续时间变化 |
| ⑤ 判定框 | E4 | 改 `Clsn1` → 攻击范围变化，且**只有攻击框变，受击框不动** |
| ⑥ AI | E6 | AI 走独立通道（不经命令），优先级 = 源码书写顺序 |
| 常量 | E1 | 改 `[Velocity] walk.fwd 2.4 → 12.0` → 同样时间的位移精确变为 **5.14 倍** |

---

## 4. 状态机

### 4.1 状态是什么

IKEMEN 的角色不是"函数式"的，而是**状态机**：任一时刻角色处于一个**状态号（StateNo）**，
该状态每 tick 执行一次自己的脚本，直到脚本里主动 `changeState{value: N}` 或
`call EndState(...)` 跳走。

状态号本身**没有引擎内建含义**，它只是编号。含义由脚本自己定义。
但也有约定俗成的编号段（**P2 模板必须遵守，方便人读**）：

| 编号段 | 约定用途 | 例子（**均已核对到具体行**） |
| --- | --- | --- |
| `0` | 站立待机 | `StateDef 0` 在 `data/common1.cns.zss:23` |
| `10`–`12` | 转向 | `common1.cns.zss:40 / 54 / 65` |
| `20` | 走路 | `kfm.zss:39`（角色自己也定义了，覆盖公共版本） |
| `40`–`52` | 跳跃（起跳/上升/下落/落地） | `common1.cns.zss:92 / 120 / 145 / 157 / 163` |
| `100` / `105` | 前跑 / 后跑 | 前跑 `kfm.zss:59`（角色自定义）；**后跑 105 只有公共版**，在 `common1.cns.zss:190` |
| `120` | 站立防御（引擎 `autoguard`） | `common1.cns.zss:271`；`AI.zss:174` 通过 `changeState{value: 120}` 进入 |
| `130`–`155` | 通用攻防受击段 | `common1.cns.zss:291` 起 |
| `195` | 嘲讽（KFM 约定） | `kfm.zss:196` |
| `200`–`299` | **站立普通技** | `200` 轻拳、`210` 重拳、`230` 轻脚、`240` 重脚 |
| `400`–`499` | **下蹲普通技** | `400` 轻拳、`410` 重拳、`430` 轻脚、`440` 重脚 |
| `600`–`699` | **空中普通技** | `600` 轻拳、`610` 重拳、`630` 轻脚、`640` 重脚 |
| `800`–`899` | **投技** | `800` 投技起手、`810` 后续；受击方 `820`/`821` 在 `hits.zss:13/36` |
| `1000`–`1499` | **必杀技（special）** | `1000`/`1010`/`1020` 金刚掌；`1050–1075` 金刚膝；`1100–1120` 上勾拳；`1200–1220` Blow；`1400–1420` Zankou |
| `3000`–`3999` | **超必杀（super）** | `3000` TripleKFPalm、`3050` SmashKFUpper（均在 `kfm.zss`） |
| `5000`–`5299` | **通用受击/倒地/起身**（引擎公共） | `5040` 受击浮空 `common1.cns.zss:606`；`5120` 倒地起身 `common1.cns.zss:840` |

> **一处未确认**：业界惯例把 `5300` 当作"眩晕（stun）"状态，
> 但在本仓库的 `engine/ikemen-go/data/` 与画面包内**没有找到 `[StateDef 5300]`**
> （KFM 的 `.air` 里有 Action 5300 的动画，但状态定义不在 `data/` 下）。
> P1 没有追查它的真实来源，**不要把它当成已确认的事实**。

出处：状态号映射表的每一行都能在 `game/chars/p1_kfm_zss_lab/kfm.zss`、`hits.zss`、
`command.zss` 或 `engine/ikemen-go/data/common1.cns.zss` 中找到对应 `[StateDef N]`。

### 4.2 KFM（P1 Lab）状态号全表

以下是 P1 Lab 角色实际定义的状态，构成 P2 模板的命名参照：

| 状态号 | 含义 | 定义位置 |
| --- | --- | --- |
| `195` | 嘲讽（Taunt） | `kfm.zss:196` |
| `200` | 站立轻拳 Stand Light Punch | `kfm.zss:212` |
| `210` | 站立重拳 Standing Strong Punch | `kfm.zss:279` |
| `230` | 站立轻脚 Standing Light Kick | `kfm.zss:333` |
| `240` | 站立重脚 | `kfm.zss` |
| `400` | 下蹲轻拳 Crouching Light Punch | `kfm.zss` |
| `410` | 下蹲重拳 | `kfm.zss` |
| `430` | 下蹲轻脚 | `kfm.zss` |
| `440` | 下蹲重脚（扫堂腿，`moveContact` 特例） | `kfm.zss`、`command.zss:63` |
| `600` / `610` / `630` / `640` | 空中轻拳 / 重拳 / 轻脚 / 重脚 | `kfm.zss` |
| `800` | 投技起手 | `kfm.zss`、`command.zss:229` |
| `1000` / `1010` / `1020` | 金刚掌 轻/重/EX（QCF_x / QCF_y / QCF_xy） | `kfm.zss`、`command.zss:119,167,173` |
| `1050` / `1060` / `1070` | 金刚膝 轻/重/EX（FF_a / FF_b / FF_ab） | `kfm.zss`、`command.zss:101,131,137` |
| `1100` / `1110` / `1120` | 上勾拳 轻/重/EX（upper_x / upper_y / upper_xy） | `kfm.zss`、`command.zss:107,143,149` |
| `1200` / `1210` / `1220` | Kung Fu Blow 轻/重/EX（QCB_x / QCB_y / QCB_xy） | `kfm.zss`、`command.zss:125,179,185` |
| `1300` / `1320` / `1340` / `1350` | 格挡 高 / 低 / 空 / 空格挡态 | `kfm.zss`、`command.zss:191-211` |
| `1400` / `1410` / `1420` | Kung Fu Zankou 轻/重/EX（QCF_a / QCF_b / QCF_ab） | `kfm.zss`、`command.zss:113,155,161` |
| `3000` | Triple Kung Fu Palm（超必杀，1 条气） | `kfm.zss`、`command.zss:92` |
| `3050` | Smash Kung Fu Upper（超必杀，1 条气） | `kfm.zss`、`command.zss:83` |
| `820` / `821` | 投技的受击方状态 | `hits.zss` |
| `1025`–`1028` | 金刚掌的受击方状态 | `hits.zss` |
| `5120` / `5300` | 倒地起身 / 眩晕（画面包公共） | `kfm.air`、`data/common1.cns.zss` |

### 4.3 跳转的三种方式

| 方式 | 写法 | 说明 |
| --- | --- | --- |
| 命令驱动跳转 | `command.zss` 里 `if command = "x" {...} { changeState{value: 200} }` | **玩家输入的正常通道** |
| 状态内自跳 | 状态脚本内 `changeState{value: N}` | 例如招式打完 → 回站立；`call EndState(0)` |
| AI 直接跳转 | `AI.zss` 内 `changeState{value: N}` | **绕过命令系统**，见 §7 |

### 4.3 负状态号：每 tick 都执行的特殊状态

负状态号**不属于状态机本身**，而是"无论当前在哪个状态、每 tick 都会跑一遍"的钩子。
它们与当前状态号无关。

| 状态号 | 执行时机 | 本仓库里的实例 |
| --- | --- | --- |
| `-1` | 每 tick | `command.zss:71`（命令路由）、`AI.zss:23`（AI 决策）。**这就是"输入和 AI 能每帧生效"的原因** |
| `-2` | 每 tick，且始终执行 | `kfm.zss:2557` `[StateDef -2]`（KFM 里是空的，是官方预留位） |
| `-3` | 每 tick，**只在角色自己的状态文件内生效** | `kfm.zss:2563` `[StateDef -3]` —— KFM 用它放"落地音效"（`kfm.zss:2570`：落地或后跳落地时播一声） |
| `-4` | 每 tick，**不受 pause / superPause 停止，也没有 helper 限制** | `AI.zss:4` —— AI 的全局收尾（语义见 `AI.zss:1-4` 的原注释） |

> **`-3` 与 `-1` 的区别要记住**：写在 `-3` 里的东西只会跟随角色自己的状态脚本，
> 不会随 `stcommon` 的公共状态一起跑。想让"所有角色都有的行为"稳定生效，用 `-2`。
>
> **顺带一个可用的技巧**：`kfm.zss:2564` 有一行被注释掉的
> `displayToClipboard{text: "..."; params: ...}`。这是官方示例里留下的调试输出写法，
> 正是 P2 用来把 `pos x` 之类的数值导出、把 E1 那类"只能目视"的实验变成可量化的手段
> （见 [`docs/p1_experiments.md`](p1_experiments.md) §10）。

---

## 5. ZSS 语法与本项目约定

IKEMEN 的 ZSS 是 MUGEN CNS 的现代化方言。**P2 之后所有角色状态脚本都用 ZSS，不用旧式 CNS。**

### 5.1 一个状态的最小结构

出处：`kfm.zss:212-261`（StateDef 200 完整实现）。

```zss
[StateDef 200;                        # 状态号；分号分隔的属性列表，以 ] 结束
type: S;                              # State-type: S-stand, C-crouch, A-air, L-liedown
movetype: A;                          # Move-type: A-attack, I-idle, H-gethit
physics: S;                           # Physics: S-stand, C-crouch, A-air
juggle: 1;                            # 本招消耗的空中追打点数
velset: 0, 0;                         # 设速度 (x, y)
ctrl: 0;                              # 是否可操作
anim: 200;                            # 切到动画 200
poweradd: 10;                         # 出招集气量
sprpriority: 2;]

if animElem = 3 {                     # 动画推进到第 3 个元素时
    hitDef{                           # ← 左花括号必须与 hitDef 同行（见 5.2）
        attr: S, NA;                  # 属性：站姿 / 普通攻击
        damage: 23, 0;                # 伤害，防御伤害
        animtype: Light;
        guardflag: MA;
        hitflag: MAF;
        priority: 3, Hit;
        pausetime: 8, 8;
        ground.hittime: 11;
        ground.velocity: -4;
        air.velocity: -1.4, -3;
        air.hittime: 15;
    }
}

if time = 1 {
    call CSnd(0, 0, 1);               # 播放音效（角色自定义函数）
}

call EndState(0);                     # 状态结束后回到站立
```

### 5.2 必须记住的语法约定

1. **`{` 必须和控制器名写在同一行。** 出处：`kfm.zss:224-227` 的原注释——
   "When using zss sctrls, you must have the bracket on the same line as the sctrl's name
   as specified below e.g. `HitDef{`"。这是 KFM 源文件里明确写下的踩坑记录。
2. **`[StateDef N; ...]` 头部用分号分隔、`]` 收尾。** `[StateDef 195;` 换行到 `]` 是合法的
   （出处：`kfm.zss:196-199`）。
3. **触发器就是 `if <表达式> { ... }`**，没有 `trigger1 =` 这种旧式写法。
   多处条件用 `&&` / `||` 组合（出处：`command.zss:11-17` 的对照说明）。
4. **范围匹配**：`stateNo = [200, 299]` 表示闭区间，`[3050, 3100)` 表示半开区间
   （出处：`command.zss:63`、`command.zss:94`）。
5. **变量**：`let x = ...;` 声明，`$x` 引用。跨状态用 `mapSet{map:"name"; value:...}` / `map(name)`
   （出处：`command.zss:60-66` 的 `[Function Combo() ret]`，`AI.zss:41-76`）。
6. **自定义函数**：`[Function Name() ret]` + `call Name()`（出处：`command.zss:60`、`kfm.zss:257`
   的 `call CSnd(0, 0, 1)`）。
7. **触发器修饰**：`ignoreHitPause`（命中停顿期间仍执行）、`persistent(n)`（连续 n tick 保持）
   （出处：`kfm.zss:318` `ignoreHitPause persistent(0) if …`）。

### 5.3 命令定义（`.cmd`）

出处：`kfm.cmd:125-330`。核心只有两段：

```ini
[Remap]                 ; 重映射（本项目先保持恒等）
x = x
y = y
...

[Defaults]
command.time = 15       ; 命令有效窗口（tick）
command.buffer.time = 1 ; 命令缓冲

[Command]
name = "x"              ; 命令名（大小写敏感）
command = x             ; 触发符号序列
time = 3                ; 覆盖默认窗口
```

符号语法（出处：`kfm.cmd:33-68` 的原始注释）：

| 符号 | 含义 | 例子 |
| --- | --- | --- |
| `B D F U` + 斜向 | 八个方向，全大写 | `D`、`DF`、`F` |
| `a b c x y z` | 六个按键，全小写 | `x`、`y` |
| `/` | 按住 | `/$D` = 按住下 |
| `~` | 检测松开；带数字表示蓄力 tick | `~30$D` = 蓄下 30 tick 后松开 |
| `$` | 仅方向：四向判定 | `$F` = 前/前上/前下都算 |
| `+` | 仅按键：同时按 | `x+y` |
| `>` | 与上一符号之间不得有其他键按下/松开 | `a, >~a` |
| `,` | 序列分隔 | `~D, DF, F, x`（波动拳） |

> **最关键的一句在 `command.zss:37-41`**：命令路由的书写顺序即优先级——
> "State entry with a certain command must come before another state entry with a command
> that is the subset of the first." 例如 `FF_a` 必须写在 `a` 前面。

### 5.4 本项目（KingOfFate）的 ZSS 约定

以下是 P1 基于实测给出的、**后续阶段强制遵守**的约定：

1. **文件名与 `.def` 映射固定**：`<char>.zss`（主体）、`hits.zss`（受击/特殊）、
   `command.zss`（命令路由）、`AI.zss`（AI）。不把命令路由塞回 `.cmd`。
2. **状态号必须落在 §4.1 的约定段内**，不允许自创无归属的编号。
3. **`{` 与控制器名同行**（§5.2 第 1 条）——这是硬性语法要求，不是风格偏好。
4. **一个状态只做一件事**：轻/重/EX 分为独立状态号（如 `1000`/`1010`/`1020`），
   不使用 `var` 在同状态内分叉（KFM 的做法，照抄）。
5. **每个状态用 `call EndState(...)` 收尾**，避免状态无法退出。
6. **`hitDef` 只在一个明确的 `animElem` 上触发**，不要在多个元素重复声明。
7. **注释保留原样**：从 KFM 等官方样例继承的注释是有价值的踩坑记录（如 §5.2 第 1 条），
   不要清理。

---

## 6. 动画与判定框（`.air`）

`.air` 负责两件事：**帧序列** 和 **判定框**。

### 6.1 帧序列

出处：`kfm.air:409-423`（Stand Light Punch 的完整定义）。

```ini
[Begin Action 200]
Clsn2Default: 2              ; 该动画默认的受击框（可被帧内 Clsn2 覆盖）
 Clsn2[0] = -10,  0, 19,-80
 Clsn2[1] =   0,-94, 12,-80
200,0, 0,0, 2                ; 组,图, X偏移,Y偏移, 持续帧数
200,1, 0,0, 1
Clsn1: 1                     ; 从这一帧起有攻击框
 Clsn1[0] =  16,-80, 61,-71
Clsn2: 3
 Clsn2[0] =  19,  0,-10,-80
 Clsn2[1] =   6,-94, 18,-78
 Clsn2[2] =  19,-80, 61,-71
200,2, 0,0, 4
200,1, 0,0, 3
200,0, 0,0, 2
```

关键点：

- 帧行格式 `组,图, x偏移, y偏移, 持续帧数`。`-1` 表示"流程结束"，`Loopstart` 表示循环起点。
- 本动画总时长 = `2+1+4+3+2 = 12` tick。
- `animElem` 是**从 1 开始的元素序号**，`animElemTime(n)` 是元素 n 已经过的 tick 数。
  状态脚本里的 `if animElem = 3` 就是在**第 3 个元素的第一帧**触发 `hitDef`
  （对应上表的 `200,2,…`，即第 4 tick）。

### 6.2 判定框

IKEMEN 用两套框：

| 框 | 归属 | 调试显示色 | 含义 |
| --- | --- | --- | --- |
| `Clsn1` | **攻击框（hitbox）** | 红 / 洋红 | 只有带 `Clsn1` 的帧才有攻击判定 |
| `Clsn2` | **受击框（hurtbox）** | 蓝 / 绿 | 别人打到这个框才算命中 |
| `Clsn2Default` | 默认受击框 | 蓝 / 绿 | 动画级默认值，帧内 `Clsn2` 可覆盖 |

坐标格式：`x1, y1, x2, y2`（相对角色脚底原点 `(0,0)`，y 向上为负）。

**实测结论（E4）**：修改 `Clsn1[0]` 只会改变攻击框；**受击框与精灵渲染完全不受影响**。
这意味着"调整打击范围"是一个**低风险、可局部化**的改动。

调试显示开关：`Ctrl+C` 切换判定框显示（出处：`engine/ikemen-go/external/script/debug.lua`）。

---

## 7. CPU AI

### 7.1 结构

出处：`game/chars/p1_kfm_zss_lab/AI.zss`。

- `[StateDef -4]`：全局状态（不受 pause / superPause 停止），KFM 用它做"非战斗状态下的收尾"
  （`AI.zss:5-8`：`if stateNo = 100 && roundState != 2 && aiLevelF { changeState{value: 0; ctrl: 1} }`）。
- `[StateDef -1]`：每 tick 执行的 AI 主循环，由 `ignoreHitPause if aiLevelF && roundState = 2 && !standby { … }`
  包裹（`AI.zss:31`）。

主循环内部大致分三块（`AI.zss` 的 `if / else if` 链）：

| 分支 | 条件 | 负责 |
| --- | --- | --- |
| 中立 | `ctrl && stateNo != 105 \|\| stateNo = 20 \|\| …` | 反手、对空、投、防御、轻/重攻击、走路、跑、跳 |
| 命中后 | `moveContact = [1,3] && hitPauseTime = 0 && stateType != A` | 连段衔接、必杀取消、超必杀收尾 |
| 特殊 | 状态相关 | 金刚膝的 follow-up、起身回复 |

### 7.2 关键机制：AI 不走命令系统

**AI 不模拟按键，也不走 `.cmd` / `command.zss`。它直接 `changeState{value: N}`。**

这一点在 E5 中已被交叉验证：当把 `.cmd` 里 `name="x"` 的命令改成 `command=y` 后，
**玩家的 TAB 键失效了，但 AI 仍然能打出 200/210 等状态**——因为 AI 从不读命令。

### 7.3 关键机制：优先级 = 源码书写顺序

**在同一个 tick 内，先出现的 `changeState` 先生效。** 因此 AI 的"决策优先级"完全由
`AI.zss` 里的书写顺序决定，没有任何引擎层的权重机制。

**实测验证（E6）**：在 AI 主循环最顶部插入一条无条件 `changeState{value: 210}` 后，
AI 的行为**从"多样化的 7 种状态"塌缩为"几乎全是 210"**——因为它位于链首，永远先命中。
详见 `docs/p1_experiments.md` 的 E6。

> **P2/P8 提醒**：这意味着写出"看起来聪明"的 AI 不需要引擎支持，
> 只需要**仔细排序**。但反过来，一条写得太靠前、条件太宽的规则会**无声地废掉后面所有规则**。
> P8（CPU AI v1）必须把"优先级顺序"当作一等设计对象。

### 7.4 AI 难度

`aiLevel` / `aiLevelF` 是引擎提供的 AI 等级（1–8）。
KFM 的 AI 用 `random <= (350 * (aiLevelF ** 2 / 48.0))` 这类公式把等级映射成概率
（`AI.zss:106`），并用 `aiLevel > 4` 之类的门槛开关高风险行为（`AI.zss:125`）。

启动参数：`-p1.ai 8`（E6 即以此运行）。

---

## 8. 引擎扩展点：Lua

IKEMEN GO 在角色系统之外还提供一层 Lua 脚本层，用于**包住引擎的帧循环、菜单和调试显示**。

### 8.1 文件与调用关系

出处：`engine/ikemen-go/external/script/`。

| 文件 | 作用 | 关键位置 |
| --- | --- | --- |
| `start.lua` | 启动阶段脚本 | — |
| `main.lua` | **主入口 + 主循环** | `main.lua:4026-4028` 依次调用 `main.f_start()` / `menu.f_start()` / `options.f_start()`；主循环 `main.menu.loop()` 在 `main.lua:3415`、`4039` |
| `menu.lua` | 菜单 | `menu.f_start()` 在 `menu.lua:420` |
| `options.lua` | 选项界面 | — |
| `default.lua` | 默认行为 | — |
| `debug.lua` | **调试覆盖层与调试热键** | 热键 `debug.lua:5-8` 与 `32-48`；`loop()` 在 `debug.lua:229` |

### 8.2 调试热键 —— P1 只用了其中两个，还有一批没用上

`Ctrl+C` / `Ctrl+D`（`debug.lua:5-8`）支撑了 P1 的全部量化结论。
复核时发现 `debug.lua:32-48` 还定义了一批能力：

| 快捷键 | 调用 | 作用 | 对后续阶段的价值 |
| --- | --- | --- | --- |
| `Ctrl+C` | `toggleClsnDisplay()` | 判定框显示 | **P1 已用**（E4） |
| `Ctrl+D` | `toggleDebugDisplay(…)` | 状态读数 | **P1 已用**（E2/E3/E5/E6） |
| `F1` / `F2` | `kill(…)` | 直接击倒指定玩家 | 快进到"一局结束" |
| `F3` | `powMax(1); powMax(2)` | **双方气槽充满** | 测超必杀不必先攒气 |
| `F4` / `Shift+F4` | `resetRound()` / `reload()` | 重开回合 / **热重载角色** | 改完角色文件不必重启游戏 |
| `F5` | `setTime(0)` | **回合计时归零** | 可能解决"无人值守自动退出"（见下） |
| `F8` | `clearConsole()` | 清控制台 | — |
| `F9` / `F10` | `loadState()` / `saveState()` | **读档 / 存档** | 复现同一帧做 A/B 对比 |
| `SPACE` | `full(…)` | **双方回满血** | 长时间测试不必重开 |
| `PAUSE` | `togglePause()` | 暂停 | — |
| `SCROLLLOCK` | `frameStep()` | **单帧步进** | 观测精度可从 burst 抽样提升到逐帧 |

> **三条必须说清楚的限制**：
>
> 1. **只有 `Ctrl+C` / `Ctrl+D` 被 P1 实测触发过。** 上表其余热键是**读源码得出**，
>    尚未验证能否被 `keybd_event` 注入 —— Lua 热键走引擎输入层，与角色命令层不同，
>    可达性未必相同（P1 已证明角色命令层只有 TAB / RETURN 可达，
>    见 [`docs/p1_experiments.md`](p1_experiments.md) §2）。
>    **不要把未验证的热键当作"自动化可用"来设计工具。**
> 2. 它们对**人工调试**是确定可用的一等能力。P2 之后调角色时，
>    `Shift+F4`（热重载）+ `F3`（充满气）+ `SPACE`（回满血）能省掉大量重开游戏的时间。
> 3. **`F1`–`F10`、`SPACE`、`PAUSE`、`SCROLLLOCK` 已被这些 Lua 热键占用**
>    （出处：`debug.lua:32-48`），不能挪作角色按键或探测键。
>    这是 P1 搭截图工具时踩到的坑，详见 `docs/p1_experiments.md` §2。

**`F5 = setTime(0)` 值得单独记一笔**：P0 曾因本基线的 `-rounds` 参数未接线，
无法让引擎"打满 N 回合后自动退出"，只能由测试主动结束进程。
`setTime(0)` 把回合计时归零从而结束回合，可能是更干净的解法 ——
**这一条尚未验证**，列为 P2 可选项。

### 8.3 结论：Lua 适合做什么

Lua 层适合做**观测、调试、界面**，不适合做角色战斗逻辑 ——
战斗逻辑应当留在 ZSS 里，否则会绕开角色文件的可移植性，
也会让"这个角色能做什么"散落到角色目录之外、无法随角色迁移。

---

## 9. 改动边界：什么能改，什么不能改

这是 P1 对后续阶段最重要的输出。**严格遵循 CONTRIBUTING.md 的优先级：**

```text
配置 → 角色 ZSS → Lua → 外部工具 → IKEMEN 源码
```

| 需求 | 应该在哪儿做 | 是否碰到引擎 | 证据 |
| --- | --- | --- | --- |
| 改移动速度、跳跃高度、体力、被击退 | 角色 `.const` 的 `[Velocity]` / `[Data]` / `[Size]` | **否** | E1：`walk.fwd 2.4 → 12.0`（`kfm.const:55`）→ 同时间位移 21 px → 108 px，**比值 5.14 ≈ 5.0** |
| 改招式伤害、命中停顿、受击时间、击退 | 角色 `.zss` 里的 `hitDef{}` | **否** | E2：`damage 23 → 137`，对手掉血精确从 23 变 137 |
| 改招式持续时长、出招时机 | 角色 `.air` 的帧持续时间 + `.zss` 的 `animElem` | **否** | E3：首元素 `2 → 20`，招式总时长 12 → 30 tick |
| 改打击范围 / 受击范围 | 角色 `.air` 的 `Clsn1` / `Clsn2` | **否** | E4：`Clsn1[0] 16,-80,61,-71 → 16,-120,170,-20`，攻击框巨大化而受击框不变 |
| 改按键 → 招式的对应关系 | 角色 `.cmd` 的 `[Command]` + `command.zss` 的路由顺序 | **否** | E5：把 `name="x"` 的 `command` 改成 `y`，同键触发不同状态 |
| 改 CPU 行为与难度 | 角色 `AI.zss`（顺序即优先级） | **否** | E6：链首插一条 `changeState` 即夺走全部决策 |
| 改角色选择画面 / 公共站立、走路、受击状态 | `game/data/`（画面包与 `common1.cns.zss`） | **否**（改的是画面包，不是引擎） | `p1_kfm_zss_lab.def` 的 `stcommon = common1.cns.zss` |
| 加新的系统机制（新资源类型、新触发器、新物理） | 引擎 `src/*.go` | **是** | P1 未发现这种需求 |
| 加调试显示、观测钩子、界面 | `external/script/*.lua` | **否**（改的是脚本资源） | E2–E6 全靠 `debug.lua` 读状态 |

**P1 结论：本阶段研究涉及的全部角色行为，100% 可以在角色文件（+ 画面包数据）内完成，
没有任何一条需要触碰 `engine/ikemen-go/src/`。** 引擎 submodule 在整个 P1 期间保持字节级干净
（`git status` 为空、HEAD 仍等于 `ba516193bba83f13f0b63ddce314d8719793931f`）。

---

## 10. 研究用角色（P1 Lab）

为了让上述实验"可修改、可提交、可评审、可删除"，P1 建立了研究用角色副本：

- 源（跟踪，真值）：`game/chars/p1_kfm_zss_lab/`
- 运行时（引擎加载，gitignored）：`engine/ikemen-go/chars/p1_kfm_zss_lab/`
- 同步脚本：`scripts/sync_game_content.ps1`

```powershell
pwsh -File scripts/sync_game_content.ps1            # game/ -> engine/ikemen-go/
pwsh -File scripts/sync_game_content.ps1 -WhatIf    # 只看会复制什么
```

**它与源角色 `engine/ikemen-go/chars/kfm_zss/` 的差异只有两处**，都写在
`p1_kfm_zss_lab.def:14-16` 的注释里：

1. `[Info] name` / `displayname` 改为 `"KFM P1 Lab"`，以便在比赛中与源角色区分；
2. 多一个 `readme-original-kfm.txt`（上游许可证说明）。

其余文件（`kfm.zss` / `hits.zss` / `command.zss` / `AI.zss` / `kfm.cmd` / `kfm.const` /
`kfm.air` / `kfm.sff` / `kfm.snd` / `movelist.dat` / `intro.*` / `ending.*`）**逐字节等于上游 kfm_zss**，
P1 期间的所有改动都已还原。许可证登记见 `assets/LICENSE_MANIFEST.csv`。

---

## 11. 对 P2 的输入

P2（Base Fighter Template）可以直接照下面这份清单开工，**不需要再研究引擎**：

### 11.1 必做

1. **目录/文件骨架**：照 §2 的 `.def` 映射，建立
   `<name>.def` / `<name>.cmd` / `<name>.const` / `<name>.zss` / `hits.zss` / `command.zss` /
   `AI.zss` / `<name>.air` / `<name>.sff` / `<name>.snd` / `movelist.dat`。
   P1 已给出可直接复制的骨架：`design/characters/_template/`。
2. **状态号规范**：照 §4.1 的编号段分配，不留无归属的编号。
3. **命令路由骨架**：照 `command.zss` 的写法，`[StateDef -1]` + 顺序即优先级（§5.3）。
4. **AI 骨架**：照 `AI.zss` 的 `[StateDef -4]` + `[StateDef -1]` + 三块 `if/else if` 结构（§7.1）。
5. **判定框基线**：从站立/走路的 `Clsn2Default` 开始，攻击帧再加 `Clsn1`（§6.2）。

### 11.2 P2 必须做的决定（P1 不替 P2 决定）

- 4 键还是 6 键（KingOfFate 定位是 4 键，但 KFM 样例是 6 键，需要重排 `[Command]`）；
- 模板角色是"最小可跑"还是"带一套完整普通技"（建议：先最小可跑，再在 P3/P4 补齐）；
- 公共状态是否沿用画面包 `common1.cns.zss`，还是复制一份到 `game/data/` 自行维护
  （**建议沿用**，直到确实需要改动为止——沿用意味着 submodule 保持干净）。

### 11.3 工具

P1 期间造的两个工具，P2 起可以继续用（详见 `tests/p1/README.md`）：

| 工具 | 作用 |
| --- | --- |
| `tests/p1/capture_match.ps1` | 无人值守启动一局、注入输入、抓取截图与状态读数 |
| `tests/p1/montage_states.ps1` | 把多张截图的状态读数裁出来拼成一张对比图 |

**它们本质上是一个"角色行为的自动化观测器"，P2 之后做攻击判定回归时会反复用到。**

---

## 附：本末两端的对照速查

| 我想改…… | 改这个文件 | 改哪一段 |
| --- | --- | --- |
| 走得快一点 | `.const` | `[Velocity] walk.fwd` |
| 这招伤害高一点 | `.zss` | 该状态 `hitDef{ damage: … }` |
| 这招打得远一点 | `.air` | 该 Action 的 `Clsn1[...]` |
| 这招慢一点 | `.air` | 该 Action 的帧持续数 |
| 换个键出这招 | `.cmd` + `command.zss` | `[Command] command=` / `if command = …` |
| 让 AI 更爱用这招 | `AI.zss` | 把对应 `changeState` 往前挪 |
| 让 AI 别用这招 | `AI.zss` | 收紧它的条件，或把更想要的规则挪到前面 |

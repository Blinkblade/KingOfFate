# 游戏操作、键位与出招表（Controls & Movelist）

> 本文档回答四个问题：**运行后怎么操作游戏？键位是什么？出招表是什么？出招表对应哪个文件？**
>
> 所有键位均摘自本机实测生成的 [`engine/ikemen-go/save/config.ini`](../engine/ikemen-go/save/config.ini)；
> 所有招式均摘自角色指令文件 [`engine/ikemen-go/chars/kfm/kfm.cmd`](../engine/ikemen-go/chars/kfm/kfm.cmd)，
> 未凭记忆书写。
>
> 适用基线：IKEMEN GO `v1.0.0-rc.5`（`ba516193bba83f13f0b63ddce314d8719793931f`）。
> 启动方法见 [`running.md`](running.md)。

---

## 1. 运行后怎么操作

### 1.1 从标题画面到对局

启动游戏后进入标题菜单。**菜单由 P1 键位控制**：

| 操作 | 按键（P1 默认） |
| --- | --- |
| 移动光标 | `↑` `↓` `←` `→`（方向键） |
| 确认 | 轻拳键（默认键盘 `Z`） |
| 返回/取消 | 强脚键（默认键盘 `X`） |

主菜单（定义在 `data/ikemen1/system.def`）：

```text
ARCADE       —— 街机模式（SINGLE / TEAM ARCADE / TEAM CO-OP）
VS MODE      —— 对战模式（1P VS 2P / TEAM VERSUS / VERSUS CO-OP / QUICK MATCH）
STORY MODE   —— 剧情模式（当前 select.def 未配置剧情弧，无子项）
NETWORK      —— 联网对战（HOST GAME / JOIN GAME）
PRACTICE     —— 训练模式（TRAINING）
MISSION      —— 任务（SURVIVAL / SURVIVAL CO-OP / TIME ATTACK / BONUS GAMES）
WATCH MODE   —— 观战（CPU MATCH / RANDOMTEST / REPLAY）
OPTIONS      —— 设置（难度、回合数、键位、画面、声音等）
EXIT         —— 退出游戏
```

选人界面：光标选角色（`A`/`B` 或方向键换列），`Z` 确认；VS 模式下 P1、P2 各用各的键位。
当前 `data/select.def` 登记了三个可选角色：`kfm_zss`、`kfm720`、`kfm_zaxis`
（均为 Kung Fu Man 的 IKEMEN 新格式变体，见 §5.3）。经典 `kfm` 未在选人表里，
但可用命令行 `-p1 kfm` 直接参战（见 [`running.md`](running.md)）。

### 1.2 对局中的系统按键

以下按键在源码中核实（`src/input.go`、`src/system.go`）：

| 按键 | 作用 | 依据 |
| --- | --- | --- |
| `Esc` | 打开/关闭暂停菜单 | `save/config.ini` `[Config] EscOpensMenu = 1`；`system.go:1612` |
| `F12` | 截图 | `input.go:142` → `captureScreen()`；默认存到引擎运行目录（`engine/ikemen-go/`），文件名 `Ikemen_GO000.png` 递增（`image.go:2266`） |
| `Alt` + `Enter` | 切换全屏/窗口 | `input.go:149-151` |
| `Ctrl` + `D` | 切换调试模式（显示碰撞框、状态号等） | `save/config.ini` `[Debug] AllowDebugMode = 1` 注释原文 |

### 1.3 暂停菜单

对局中按 `Esc` 打开（`external/script/menu.lua` 实现项），常用项包括：

- **Continue** —— 返回对局
- **Command List** —— **游戏内出招表**，逐字符读取该角色的 `movelist.dat`（见 §5）
- **Keyboard / Gamepad Config** —— 对局中改键位，立即生效并写回 `save/config.ini`
- **Input Default** —— 恢复默认键位
- **Round Reset / Reload** —— 重置当前回合 / 重新开局
- **Character Change** —— 返回选人界面
- **Exit** —— 结束对局回标题

训练模式（TRAINING）的暂停菜单额外有：假人控制、AI 等级、假人行为、防御行为、
倒地受身、距离、连打 等设置项。

---

## 2. 键位设置是什么

### 2.1 按钮语义：引擎的 8 个动作键

MUGEN/IKEMEN 角色统一使用下列按钮名（`kfm.cmd` 头部注释原文：
"For 6 button characters, use abc for kicks and xyz for punches"）：

| 按钮名 | 含义 | IKEMEN 扩展说明 |
| --- | --- | --- |
| `x` `y` `z` | 轻拳 / 强拳 / 重拳 | — |
| `a` `b` `c` | 轻脚 / 强脚 / 重脚 | — |
| `s` | START（嘲讽/系统） | — |
| `d` `w` | 第 7 / 第 8 键 | IKEMEN 扩展按钮，供 8 键角色使用 |

方向记法（8 方向）：`B`=后，`DB`=下后，`D`=下，`DF`=下前，`F`=前，`UF`=上后，`U`=上，`UB`=上后。
以角色面向为准（1P 面向右时 F=→）。

### 2.2 P1 键盘（默认，摘自 `save/config.ini` `[Keys_P1]`）

| 功能 | 配置键名 | 实际按键 |
| --- | --- | --- |
| 上/下/左/右 | `UP/DOWN/LEFT/RIGHT` | 方向键 `↑ ↓ ← →` |
| 轻拳 `x` | `a` | **`A`** |
| 强拳 `y` | `s` | **`S`** |
| 重拳 `z` | `d` | `D` |
| 轻脚 `a` | `a` | **`Z`** |
| 强脚 `b` | `b` | **`X`** |
| 重脚 `c` | `c` | `C` |
| START `s` | `start` | `Enter` |
| 第 7 键 `d` | `q` | `Q` |
| 第 8 键 `w` | `w` | `W` |

> 注意大小写容易混淆：配置里的 `x=A` 指的是"角色按钮 x 绑定在键盘 A 键上"。

### 2.3 P2 键盘（默认，摘自 `[Keys_P2]`）

| 功能 | 实际按键 |
| --- | --- |
| 上/下/左/右 | `I` / `K` / `J` / `L` |
| 轻拳 `x` / 强拳 `y` / 重拳 `z` | `R` / `T` / `Y` |
| 轻脚 `a` / 强脚 `b` / 重脚 `c` | `F` / `G` / `H` |
| START `s` | 右 `Shift` |
| 第 7 / 第 8 键 | `[` / `]` |

P3、P4 默认未绑定（全部 `Not used`），需要时在游戏内设置。

### 2.4 手柄（摘自 `[Joystick_P1]`，P2–P4 相同映射）

| 功能 | 手柄输入 |
| --- | --- |
| 方向 | 十字键（DPAD） |
| 轻拳 `x` / 强拳 `y` / 重拳 `z` | `X` / `Y` / `RB` |
| 轻脚 `a` / 强脚 `b` / 重脚 `c` | `A` / `B` / `RT` |
| 第 7 / 第 8 键 `d` / `w` | `LB` / `LT` |
| START `s` | `START` |
| menu | `BACK` |

手柄映射库：`external/gamecontrollerdb.txt`（`[Config] GamepadMappings`）。

### 2.5 怎么改键位

两条入口，效果相同（写回 `save/config.ini` 的 `[Keys_P*]` / `[Joystick_P*]` 小节）：

1. **主菜单** → `OPTIONS` → `Key Config`（键盘）/ `Gamepad Config`（手柄）→ 选中玩家 → 逐项按下新键；
2. **对局中** `Esc` → 暂停菜单 → `Keyboard Config` / `Gamepad Config`。

也可以直接编辑 `engine/ikemen-go/save/config.ini` 后重启游戏。
出厂默认值在 `src/resources/defaultConfig.ini`（删掉 save/config.ini 即可复位）。

相关输入选项（`[Input]`）：`ButtonAssist = 1`（按钮判定延迟一帧，搓招更容易）、
`SOCDResolution = 4`（同时按左右/上下时取"都无效"，IKEMEN 默认）。

---

## 3. 出招表是什么（以 KFM 为例）

下表完整对应 `chars/kfm/kfm.cmd` 的指令定义与状态跳转，
招式行为本体（帧数/伤害/动画）在 `chars/kfm/kfm.cns`。
方向以角色面向为基准；`拳` = `x` 或 `y`（KFM 未使用重拳 `z`），`脚` = `a` 或 `b`（未使用 `c`）。

### 3.1 基础操作

| 动作 | 指令 | 状态号 |
| --- | --- | --- |
| 前冲 | `→ →`（FF） | 100 |
| 后撤 | `← ←`（BB） | 105 |
| 倒地受身 | `x + y`（双拳同按，recovery，由公共状态处理） | — |
| 嘲讽 | `START` | 195 |
| 投技 Kung Fu Throw | 近身按住 `→` 或 `←` + `强拳 y` | 800 |

### 3.2 普通技

| 技 | 指令 | 状态号 |
| --- | --- | --- |
| 站轻拳 / 站强拳 | `x` / `y` | 200 / 210 |
| 站轻脚 / 站强脚 | `a` / `b` | 230 / 240 |
| 蹲轻拳 / 蹲强拳 | 按住 `↓` + `x` / `y` | 400 / 410 |
| 蹲轻脚 / 蹲强脚（扫堂腿） | 按住 `↓` + `a` / `b` | 430 / 440 |
| 跳轻拳 / 跳强拳 | 空中 `x` / `y` | 600 / 610 |
| 跳轻脚 / 跳强脚 | 空中 `a` / `b` | 630 / 640 |

### 3.3 特殊技

| 技 | 指令 | 状态号 |
| --- | --- | --- |
| 上段挡身 High Kung Fu Blocking | `→` + 轻拳 `x` | 1300 |
| 下段挡身 Low Kung Fu Blocking | `↘` 或 `↓` + 轻拳 `x` | 1320 |
| 空中挡身 Air Kung Fu Blocking | 空中 `→` + 轻拳 `x` | 1340 |

### 3.4 必杀技（`拳` = x/y，`脚` = a/b；同招强弱由所用按钮决定）

| 技 | 指令 | 状态号 |
| --- | --- | --- |
| Kung Fu Palm（气功弹） | `↓ ↘ →` + 拳 | 1000 / 1010 |
| Kung Fu Upper（升龙拳） | `→ ↓ ↘` + 拳 | 1100 / 1110 |
| Kung Fu Blow（肘击突进） | `↓ ↙ ←` + 拳 | 1200 / 1210 |
| Kung Fu Zankou（足刀） | `↓ ↘ →` + 脚 | 1400 / 1410 |
| Kung Fu Knee（飞膝踢） | `→ →` + 脚 | 1050 / 1060 |

### 3.5 EX 强化版（消耗 ≥330 气量条，可从特定普通技取消）

| 技 | 指令 | 状态号 |
| --- | --- | --- |
| Fast Kung Fu Palm | `↓ ↘ →` + `x+y`（双拳同按） | 1020 |
| Fast Kung Fu Upper | `→ ↓ ↘` + `x+y` | 1120 |
| Fast Kung Fu Blow | `↓ ↙ ←` + `x+y` | 1220 |
| Far Kung Fu Zankou | `↓ ↘ →` + `a+b`（双脚同按） | 1420 |
| Fast Kung Fu Knee | `→ →` + `a+b` | 1070 |

### 3.6 超必杀（消耗 1000 气量条 = 一整条）

| 技 | 指令 | 状态号 |
| --- | --- | --- |
| Triple Kung Fu Palm | `↓ ↘ → ↓ ↘ →` + 拳 | 3000 |
| Smash Kung Fu Upper | `↓ ↙ ← ↓ ↙ ←` + 拳 | 3050 |

> 指令里的方向序列写法是 `~D, DF, F, x`：`~` 表示先松开前一输入，
> `D`/`DF`/`F` 为方向，`x` 为按钮；`time = 20` 表示整套输入需在 20 帧内完成。
> 搓招语法（`/` 按住、`~` 松开/蓄力、`$` 四向、`+` 同按、`>` 严格顺序）
> 完整说明见 `kfm.cmd` 文件头注释（第 36–58 行）。

---

## 4. 出招表记谱法（movelist.dat 里的符号）

游戏内 `Esc → Command List` 显示的记谱来自角色的 `movelist.dat`，记法对照：

| 记法 | 含义 |
| --- | --- |
| `QDF` | `↓ ↘ →`（Quarter-circle Down-Forward） |
| `QDB` | `↓ ↙ ←`（Quarter-circle Down-Back） |
| `DSF` | `→ ↓ ↘`（Dragon-screw，即升龙指令） |
| `F_F` | `→ →` |
| `^P` | 任意拳按钮（x 或 y） |
| `^K` | 任意脚按钮（a 或 b） |
| `_B_+` / `_F_+` | 近身按住 后 / 前 + 该按钮（投技） |
| `_AIR_` | 空中限定 |
| `(1000)` | 需要 1000 气量条 |

---

## 5. 出招表 / 键位对应哪个文件（速查）

| 想改什么 | 文件（相对仓库根） | 说明 |
| --- | --- | --- |
| **本机实际键位** | `engine/ikemen-go/save/config.ini` | `[Keys_P1..P4]` 键盘、`[Joystick_P1..P4]` 手柄；游戏内改键也写这里 |
| 出厂默认键位 | `engine/ikemen-go/src/resources/defaultConfig.ini` | 删除 `save/config.ini` 即复位 |
| **指令定义（什么组合触发什么招）** | `engine/ikemen-go/chars/kfm/kfm.cmd` | `[Command]` 小节 = 指令；`[Statedef -1]` 之后 = 触发条件与状态跳转 |
| **游戏内显示的出招表** | `engine/ikemen-go/chars/kfm/movelist.dat` | 纯文本，可随意编辑；由 `chars/kfm/kfm.def` 第 25 行 `movelist = movelist.dat` 声明，游戏内 `Esc → Command List` 查看 |
| 招式行为本体（帧数/伤害/动画） | `engine/ikemen-go/chars/kfm/kfm.cns` | 经典 CNS 格式；如 `Kung Fu Palm` 在第 1109 行起 |
| 全角色公共指令 | `engine/ikemen-go/data/common.cmd` | 所有角色共用，受 `save/config.ini` `[Common] Cmd` 挂载 |
| 角色登记（选人表） | `engine/ikemen-go/data/select.def` | 决定选人界面出现哪些角色 |
| 主菜单/暂停菜单 | `engine/ikemen-go/data/ikemen1/system.def` + `external/script/menu.lua` | 菜单项、模式列表 |

> **新角色的出招表放哪**：建 `chars/<角色名>/` 目录，在 `<角色名>.cmd` 里定义
> `[Command]` 并写 `[Statedef -1]` 触发逻辑，再放一份 `<角色名>.def` 里用
> `movelist = movelist.dat` 指向的记谱文件，即可在游戏内 Command List 看到。
> 这是 P1（IKEMEN 角色架构）阶段会规范化的事项。

---

## 6. 本项目当前的角色阵容

| 角色 | 目录 | 格式 | 出招表文件 |
| --- | --- | --- | --- |
| Kung Fu Man（经典） | `chars/kfm/` | CNS（`kfm.cns`） | `movelist.dat` |
| KFM ZSS | `chars/kfm_zss/` | ZSS | `movelist.dat` |
| KFM 720 | `chars/kfm720/` | ZSS | `movelist.dat` |
| KFM Z-axis | `chars/kfm_zaxis/` | ZSS | `movelist.dat` |

四个角色是同一套 Kung Fu Man 招式体系（Elecbyte 原作 + IKEMEN 官方移植），
§3 的出招表对四个角色均适用。

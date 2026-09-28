# 用 Training 模式验证对战类 Gate（替代合成按键注入）

> 本文回答一个问题：**Gate 6 / Gate 7 这类需要"对手做出特定行为"的验证，到底要不要靠
> 按键注入？**
>
> 答案：**大部分不需要。** 引擎自带的 Training 模式已经提供了"必定防御的假人"和
> "持续跳跃的假人"，用**真实键盘**就能构造，全程不需要改 `save/config.ini`。
>
> 本文中所有"引擎行为"的描述都带有源码行号出处，均来自**读取引擎源文件**，
> 不依赖任何截图判读。需要**人眼确认**的部分已明确标注。

| | |
| --- | --- |
| 适用 | P4 Gate 6（取消时序）、Gate 7（投射物被防御 / 被跳跃规避） |
| 引擎 | IKEMEN GO `v1.0.0-rc.5` = `ba516193`（**未修改**） |
| 前置 | `pwsh -File scripts/build_engine.ps1 -BuildFfmpeg no`（或直接双击 `Ikemen_GO.exe`） |
| 状态 | 方法已定稿；**Gate 结论待人工执行后填写**（见 §5） |

---

## 1. 为什么不用注入也能验证

### 1.1 引擎自带 Training 模式的假人控制

源码：`engine/ikemen-go/data/training.zss`（引擎自带，未修改）。
文件头部的注释直接给出了全部开关的语义：

```
# maps set via Pause Menu (menu.lua)
# _iksys_trainingDummyControl: 0 - cooperative, 1 - ai, 2 - manual
# _iksys_trainingGuardMode:    0 - none, 1 - auto, 2 - all, 3 - random
# _iksys_trainingFallRecovery: 0 - none, 1 - ground, 2 - air, 3 - random
# _iksys_trainingDummyMode:    0 - stand, 1 - crouch, 2 - jump, 3 - wjump
# _iksys_trainingDistance:     0 - any, 1 - close, 2 - medium, 3 - far
# _iksys_trainingButtonJam:    0 - none, 1-9 - a/b/c/x/y/z/s/d/w
```

关键实现（同文件第 73–94、193–221 行）：

| 菜单项 | 值 | 引擎做什么 | 对 Gate 的意义 |
| --- | --- | --- | --- |
| **Guard Mode** | `all` (2) | 第 82–83 行：**无条件** `assertSpecial{flag: autoGuard}` | **Gate 7「投射物被防御」** |
| **Dummy Mode** | `jump` (2) | 第 204–209 行：`assertInput{flag: U}`（持续按住"上"） | **Gate 7「被跳跃规避」** |
| **Distance** | `far` (3) | 第 163–168 行：距离不足时自动 `assertInput{flag: B}` 后退，**自动维持距离** | 不用手按方向键调距离 |

也就是说：**"让对手防御"和"让对手跳起来"这两件最难的事，引擎已经替我们做了**，
而且是 `assertInput` / `assertSpecial` 级别的强制，不经过键盘、不经过 AI。

### 1.2 Training 模式的两个便利属性

同一份 `training.zss`：

- 第 17–21 行：`roundState = 0` 时 `powerSet{value: powerMax}` —— **开局满气**，
  可以直接测 EX（236+C）和 Super（236236+A）。
- 第 25–44 行：未被击中满 60 tick 后 `lifeSet{value: lifeMax}` —— **自动回满血**，
  可以反复试同一个波，不用每轮重开。
- 第 47–51 行：`assertSpecial{flag: globalNoKo; ...}` —— **禁用 K.O.**，不会中途结束。
- 第 57–59 行：`skipRoundDisplay` / `skipFightDisplay` —— 跳过 READY/FIGHT 开场。

### 1.3 为什么"永久多绑一个可注入键"做不到

有人会问：既然注入需要把按钮改成 `TAB`，那**永久**多挂一个键不行吗？

**不行。** `src/input.go:279–285`：

```go
type KeyConfig struct {
	Joy                                                    int
	dU, dD, dL, dR, bA, bB, bC, bX, bY, bZ, bS, bD, bW, bM int
	...
}
```

每个按钮只存**一个 `int`**，不是切片 → `config.ini` 里写 `x = a, TAB` 这种
"双绑定"在源码层面就不支持。所以自动化想注入按钮，只能走"临时改写 + 还原"。

> 这条已经不成问题了：`tests/p2/inject_phases.ps1` 现在自动快照 `save/config.ini`、
> 临时改写、`finally` 块无条件还原（含 Ctrl-C 中断）。跑完必定恢复用户自己的键位。

---

## 2. 通用操作表（真实键盘）

### 2.1 调试热键

源码：`engine/ikemen-go/external/script/debug.lua`（引擎自带，未修改）。

| 键 | 作用 | 出处 |
| --- | --- | --- |
| `Ctrl+D` | 打开/关闭调试覆盖层（State No / ElemNo / Time / LIFE / POW） | `debug.lua:6` |
| `Ctrl+C` | 碰撞框显示（粉色=攻击框 `Clsn1`） | `debug.lua:5` |
| `PAUSE` | 暂停 / 继续（会同时 `closeMenu()`） | `debug.lua:47` |
| `SCROLLLOCK` | **单帧步进**（暂停后走一格） | `debug.lua:48` |
| `Ctrl+S` | 变速，accel 循环 `1 → 2 → 4 → 0.25`（**按 3 下到 1/4 速**） | `debug.lua:10` + `:50-58` |
| `SPACE` | 全员回满 + 回合计时重置 | `debug.lua:45` |

> 注意 `Ctrl+D` / `Ctrl+C` 是**开关**，连按两次会关掉。

### 2.2 P1 默认按键

`save/config.ini` `[Keys_P1]` 出厂值：

```
up/down/left/right = 方向键
a = z    b = x    c = c
x = a    y = s    z = d
start = RETURN
```

**本文说"236 + A"时，指的是按 `.cmd` 里的 `QCF_x`**，也就是
`~D, DF, F, x` —— 结束时按**键盘字母 `a`**（因为配置里 `x = a`）。
不要按 `z`（那是 `a` 按钮，对应站立轻拳 A)。

---

## 3. Gate 7「投射物被防御」—— 三步 A/B 对照

**核心思路**：同一个波，只改 Guard Mode 一个变量，**两次结果必须相反**。
这比单看一次"有没有掉血"可靠得多。

### 步骤

1. 主菜单 → **TRAINING**
   （`main.lua:2457-2484` 的 `['training']` 分支）
2. P1 选 **Test Fighter B**，P2 选 **Test Fighter A**
3. 进对局后立刻 `Ctrl+D` 打开覆盖层，`Ctrl+C` 开碰撞框
4. `Esc` 打开暂停菜单（`config.ini` 的 `EscOpensMenu = 1`）
5. 菜单操作：
   - 方向键 上/下 选条目，**左/右 改值**（`menu.lua:67-89`，改值用 `menu.add/subtract`）
   - **Guard Mode** → 右移到 **`all`**
     （选项顺序 `none → auto → all → random`，见 `menu.lua:31-36`）
   - **Distance** → 右移到 **`far`**
     （顺序 `any → close → medium → far`，见 `menu.lua:43-48`）
   - 选 **Back** 返回
6. 对 P1（Test Fighter B）搓 **236 + A**（↓ ↘ → + 键盘 `a`）
7. **观察 ①**：P2 生命是否变化
8. `Esc` → **Guard Mode → `none`** → Back，**再搓完全相同的 236 + A**
9. **观察 ②**：P2 生命是否变化

### 判据

| Guard Mode | 预期 | 对应 Gate 7 结论 |
| --- | --- | --- |
| `none` | P2 **掉血 60**（`test_fighter_b.zss` 的 `damage: 60`） | 波能打中人（已在 P4 归档里验证过） |
| `all` | P2 **不掉血**，出现防御火花，覆盖层显示 P2 进入防御状态（公共状态 150/152） | **波被防御了** ✅ |

**只有两条都成立，Gate 7 的"被防御"才算 PASS。**
如果 `all` 时 P2 仍然掉血 → 说明 `guardflag` 或 `attr` 有问题，是真 bug，要进 [已知问题]。

> ⚠️ **需要人眼确认**：上表的"掉血 / 不掉血 / 有没有火花"三项。
> （我无法读取截图，不能替你确认。）

---

## 4. Gate 7「投射物被跳跃规避」

同样的思路，把 Guard Mode 换成 Dummy Mode：

1. Guard Mode 设回 **`none`**（关掉自动防御，避免变量混淆）
2. **Dummy Mode → `jump`**
   （顺序 `stand → crouch → jump → wjump`，见 `menu.lua:25-30`；
   `training.zss:204-209` 会持续 `assertInput{flag: U}`）
3. Back 返回，搓 236 + A
4. **观察**：P2 跳到空中时，波是否从**下方穿过**而没有命中
5. 对照：Dummy Mode 设回 `stand`，同一个波应该命中

> 判断波是否从下方穿过，可以用 `Ctrl+C` 看攻击框（投射物 Action 1005 的框是
> **居中方块**，见 `docs/P4-summary.md` §3），配合 `PAUSE` + `SCROLLLOCK` 逐帧看。

---

## 5. Gate 6「取消时序」—— 用单帧步进读精确 tick

**要证明的事**：`State 200`（站立轻拳 A）在其自身尚未结束时，被打断进了
`State 1000`（气弹）。（200 全长 20 tick，首个判定帧是 elem 3。）

> 为什么之前是 BLOCKED：只有"200 出现过、1000 出现过"的两张截图，
> 间隔约 55 帧 > 20 tick，无法排除"200 打完之后另起一招"。

### 步骤

1. 仍是 TRAINING，Distance 设 **`close`**（贴身才打得到 → 才谈得上取消）
2. `Ctrl+S` **按三下**把速度降到 **1/4**（`accel = 0.25`）
   —— 这样真实按键也来得及在窗口内输入；不改变游戏 tick 逻辑
3. 对按 **站立轻拳 A** = 键盘 `z`（`[Keys_P1] a = z`）
4. 立刻在 Slow motion 下搓 **236 + A**（键盘 `a`）
5. 在 200 还没结束之前 **`PAUSE`**
6. 用 **`SCROLLLOCK` 一格一格**往前走，读覆盖层里的：
   - `State No:` —— 是否从 `200` 变成 `1000`
   - `Time:` —— 变化时 200 自己走到第几 tick
   - `ActionID:` / `SPR:` —— 是否从 200 切到 1000

### 判据

| 观测 | 结论 |
| --- | --- |
| `Time` 仍小于 20（200 未走完）时 `State No` 已变成 `1000` | ✅ **取消成立**，Gate 6 PASS |
| 200 走完 `Time = 20` 回到状态 0 之后才出现 1000 | ❌ 只是普通连按，Gate 6 仍 BLOCKED |

> ⚠️ **需要人眼确认**：覆盖层的 `State No` / `Time` 读数。同样地，我读不了截图。

---

## 6. 结果记录表（执行后填写）

请把观察结果原样填在这里，**不要推测**：

| Gate | 步骤 | 观察结果 | 判定 |
| --- | --- | --- | --- |
| 7 被防御 | Guard=`none`，236+A | P2 LIFE：________ | ☐ PASS ☐ FAIL |
| 7 被防御 | Guard=`all`，236+A | P2 LIFE：________ 防御火花：☐有 ☐无 | ☐ PASS ☐ FAIL |
| 7 被跳规避 | Dummy=`jump`，236+A | 波是否穿过：☐是 ☐否 | ☐ PASS ☐ FAIL |
| 7 被跳规避 | Dummy=`stand`（对照），236+A | 是否命中：☐是 ☐否 | ☐ PASS ☐ FAIL |
| 6 取消 | 200 未结束时 | State No 变成：____ 时 Time = ____ | ☐ PASS ☐ FAIL |

填好后交给我，我会把结果**原样**写进
`docs/phase_reports/P4-test-fighter-b.md`，并把对应 Gate 从 BLOCKED 改掉。
**在填表之前，Gate 6 / 7 一律保持 BLOCKED，不得改写成 PASS。**

---

## 7. 什么时候仍然需要注入

Training 模式解决不了、必须靠合成按键的场景：

- **长时间无人值守**（例如 Gate 8 要求的"AI 对战 ≥ 100 秒 + 0 crash log"）
  → 用 `tests/p3/run_match_watch.ps1`
- **崩溃回归**（连续多轮、自动收集 `save/logs/` 新文件）
  → 同上

这些场景用 `tests/p3/run_match_watch.ps1` / `tests/p2/inject_phases.ps1`，
**键位改写已经由脚本自动管理**，不会再把用户键位留在改动状态。

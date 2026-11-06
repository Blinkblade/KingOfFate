# 2026-11-03 — 距离、硬直、终极技，以及 Fighter B 的"没有反制手段"

> 前半部分（一~七节）= Archer 的三条手感缺陷；后半部分（八节）= 同一轮的
> Fighter B 平衡。两处都动到了 `game/chars/` 下的多个角色，原因在 8.6 末尾说明。

**负责人反馈（原话摘要）**

1. 攻击距离太短：刀的画面已经打到人了却不掉血，比人机普通角色出拳还近；重击几乎贴脸才中。
2. 硬直几乎没有：打中对手后对方立刻能动、想防就防想打就打，无法连招；自己被打一下却要被三连。
3. 无限剑制能被防住：从天上落下来的剑阵，双手护在身前就挡住了。

**结论先说**：三条都不是"数值调小了"，而是**三个可以算出来的结构性错误**。
修完之后关键数字：轻攻击命中帧优势 **−6 → +4**、重攻击 **0 → +2**、判定框外缘
补到刀尖之外、终极技对"必防假人"造成 **96** 伤害（去掉不可防只剩 20 削减）。

---

## 一、先做工具，再改数值

以前所有手感问题都只能"凭感觉调"，这次先把**帧数据**变成可复算的东西：
新增 `tools/frame_data.py`（纯标准库，读 `.air` + `.zss` + `[Size] xscale`）：

```powershell
python tools/frame_data.py game/chars/archer           # 打印帧表
python tools/frame_data.py game/chars/archer --check   # 退出码 1 = 有缺陷
```

它算两件事，正好对应前两条反馈：

| 指标 | 公式 | 含义 |
| --- | --- | --- |
| `adv_hit`（帧优势） | `hittime − (total − startup − 1)` | 打中之后**谁先能动**。命中停顿双方等长，相互抵消 |
| 框 vs 画面 | `Clsn1 外缘 − 判定帧里刀尖最远处` | 为负 = 画面伸得比判定框远 = "看着打到了却没伤害" |

**为什么帧优势是那个公式**：受击方要等 `hittime` 才能离开受击状态
（`char.go:5509` `hitOver()` → `ghv.hittime < 0`；`hitshaketime` 来自 `pausetime[1]`，
见 `char.go:11050`，双方冻结同样长度所以抵消）；攻方要等动画播完
（本角色每个攻击状态都用 `EndState()` 收尾，判据是 `animTime = 0`）。
两者相减就是帧优势。**为负的招打中之后是对手先动**——这就是"我打他跟没事人一样"。

## 二、诊断数据（改之前）

| 状态 | 招式 | 总长 | 起手 | 收招 | hittime | **adv** | 框 vs 画面 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 200 | 站轻斩 | 23 | 5 | 15 | 11 | **−6** | +6.7 ok |
| 210 | 站重斩 | 29 | 12 | 11 | 16 | **0** | +17.8 ok |
| 230 | 前蹴 | 20 | 8 | 9 | 12 | +1 | **−18.7 短** |
| 240 | 回旋蹴 | 30 | 8 | 16 | 19 | **−2** | +13.5 ok |
| 400 | 蹲轻斩 | 21 | 6 | 12 | 11 | **−3** | **−16.8 短** |
| 250 | T1 二段轻拳 | 23 | 5 | 15 | 10 | **−7** | — |

对照组（同一个引擎、同一套换算）：KFM 站轻拳 `hittime 11 / 总长 12` → **adv +3**；
Fighter B 的重斩判定框伸到 **105**，而 Archer 只有 **84**。

也就是说：**硬直数值本身抄的就是 KFM 的（11/8）**，但 Archer 的动画比 KFM 长 40~60%
（高清素材 423 个动作），于是同样 11 tick 的僵直，配上了双倍的收招 —— 帧优势整体变负。
**这是"素材换了、帧数据没跟着重算"的典型后果，改 hittime 只是补偿，改动画尾巴才是根治。**

## 三、距离：不是"框太小"，是"框和刀不在同一帧"

逐帧量刀尖（`Clsn1` 与精灵 alpha 包围盒都换算到世界单位）之后，真正的错误浮出来：

| 动作 | 刀尖最远的一帧 | 那一帧有判定框吗 |
| --- | --- | --- |
| 200 轻斩 | elem 4 = 74.4 | ❌ 原来没有（框从 elem 5 才开始） |
| **210 重斩** | **elem 5 = 77.3** | ❌ **没有** —— 整招伸得最远的一帧是空帧 |
| 230 前蹴 | elem 6 = 85.9 | ✅ 有，但框只到 67.2（短 18.7） |
| 400 蹲轻斩 | 67.7 | ✅ 有，框只到 50.9（短 16.8） |

**重斩"几乎贴脸才打到"的直接原因就是它**：刀推到最远（77.3）时没有判定，等框生效时
刀已经收回到 49~66 —— 玩家看到的"打到了"和引擎认定的"打到了"错开了两帧。

修复原则：**判定框跟着刀走**。每帧按该帧刀尖 + 4~6 世界单位余量给框，
并把刀已经伸出去的帧一并纳入判定窗口（顺带把重斩起手从 12 降到 10 tick）。

## 四、硬直：把帧优势做成正值

| 状态 | 改动 | adv 变化 |
| --- | --- | --- |
| 200 站轻斩 | 收招尾巴 15 → 9（总长 23 → 17）、hittime 11 → 16 | −6 → **+4** |
| 210 站重斩 | 判定窗口 +elem5、hittime 16 → 20 | 0 → **+2** |
| 230 前蹴 | hittime 12 → 15 | +1 → **+4** |
| 240 回旋蹴 | 收招 16 → 13、hittime 19 → 20 | −2 → **+2** |
| 400/410/430/440 蹲 | hittime 11/16/12/17 → 17/20/16/17 | −3/−1/−1/+4 → **+3/+3/+3/+4** |
| 250/251/253 T1 二段 | hittime 10/14/16 → 13/19/19 | −7/−2/−5 → **+1/+1/+1** |

同时把 `ground.slidetime` 提上来（5/9 → 12/16）：这个值只决定**被打退时还能滑多久**，
太小时受击方"原地不动地僵一下"，看起来就像没被打中。KFM 用的是 12~20。

空中普通技（600/610/630）仍为负帧优势，**这是有意保留的**：跳进去就该付代价。

## 五、终极技：剑雨不可防御

引擎判据（不是猜）：

```go
// char.go:10842
canguard := !c.asf(ASF_unguardable) && getter.scf(SCF_guard) && ...
```

`c` 是**攻方**，所以攻方带 `ASF_unguardable` 时对手的防御一律不成立；
紧邻的注释原文写着 *"Unguardable flag also affects projectiles"*（issue #2367），
因此这一条对 3100 发出的投射物同样有效，不需要（也没法）改 `guardflag`。

```zss
# StateDef 3100 状态级（每 tick 生效；只写一次的话下一 tick 就失效）
assertSpecial{ flag: unguardable }
```

代价：2000 气（整条槽）+ 198 tick 演出，可被走位/跳跃躲开，不是必胜。

## 六、验证

### 6.1 静态

```text
python tools/frame_data.py game/chars/archer --check   → PASS（地面普通技全部 ≥0）
python tools/audit_moveset.py                          → 0 项
python tools/character_validate/validate_character.py  → 0 错误 3 警告（既有）
```

### 6.2 Runtime：30 条配方

`pwsh -File tests/p6/verify_moves.ps1 -Pass moves` → **30/30 PASS**，
伤害与耗气数值与改动前一致（56/56、66/66、126→…、−2000/−2000），
说明改 AIR 帧布局没有破坏任何判定。

### 6.3 Runtime：终极技「打穿必防」

只证明"能打到人"是不够的 —— 对手站着不动本来就掉血。所以在探针里加了一个
**必防假人**（等价训练模式 Guard Mode = all，`training.zss:82` 用的就是同一个 flag）：

```zss
# tests/p6/fixtures/archer_probe.zss：只在对手放 3100 时强制防御
if playerNo = 2 && p2StateNo = 3100 { assertSpecial{ flag: autoGuard } }
```

**正反两组都跑了**（这是"只通过过的检查不算检查"那条规矩）：

| 条件 | 观测伤害 | 结论 |
| --- | --- | --- |
| 带 `unguardable` | **96 / 48 门槛 PASS** | 剑雨打穿防御 |
| 临时去掉 `unguardable`（反向对照） | **20**（= 5 段 ×4 防御削减） | 假人确实在防，是 flag 起的作用 |

顺手收紧断言：`-DmgRule min` 只要求"伤害 ≥1"，把"被防只剩削减"也算通过；
新增 `atleast`（伤害 ≥ 期望值），3100 现在要求 ≥48 —— 反向对照那 20 会直接 FAIL。

## 七、遗留

- 空中普通技仍是负帧优势（有意）；若日后觉得空中压制太弱，改的是 AIR 落地帧，不是 hittime。
- 1400（跳劈下压）判定框 103.7 vs 画面 64.3，**框比画面长 39**；1100（升斬）框 73 vs 画面 25.4。
  这两处是"看不见的判定"，本次没动（负责人没提，且它们是当前能用的招式），
  但已进入 `tools/frame_data.py` 的可见范围，随时可以收。
- ~~`scripts/test.ps1` 里的资产测试套件还没有 `frame_data.py --check`，下次接进回归。~~
  **已接**，见第八节 8.5。

---

# 附：同一轮的 Fighter B 平衡（2026-11-03 续）

**负责人第二条反馈**：「test fighter B 是不是也得改一下，**无限远程攻击 + 高硬直，
几乎没有反制手段**。」（前半句"可以"= 对 Archer 三条修复的确认，所以本轮**不再回头动 Archer**。）

## 八、Fighter B：四条机制问题

### 8.1 「无限远程」的两个成因

| 项 | 改前 | 改后 |
| --- | --- | --- |
| `StateDef 1000` 的 `poweradd` | **40** | 0 |
| 气弹 `projremovetime` | 130 | 80 |
| AI 放波冷却 `var(1)` | 90 | 140 |

`poweradd: 40` 是**纯套利**：这一招的动画 42 tick，一轮 +40 气，对手还没接触就能攒满 EX。
"免费"是 Zoner 该有的（投射物是主力手段），"免费还倒赚"不是。

冷却这一项要连着算：出招 42 + 冷却 90 = **132 tick 一轮**，而波**活 130 tick** ——
屏幕上 98% 的时间都有波在飞。这就是"无限远程"的实感来源，不是单发太强。
改成 42 + 140 = **182 tick 一轮**、波活 **80** ⇒ 占用 44%，每轮留 **102 tick（约 1.7 s）**真空窗。

### 8.2 高硬直

气弹 `ground.hittime` 16 → 12、`air.hittime` 20 → 16、`ground.velocity` −6 → −4。

### 8.3 ★ 「没有反制手段」的真正原因：几何上跳不过去

`Action 1005` 原判定框 `-40,-60, 40,60`：高 **120**，且 y 到 **+60**（往下伸到地面以下 20）。
角色跳跃顶点约 **80 px** —— **不存在任何一个时刻能跳过它**，只能防。

```
原来：y −60…+60（高 120）      跳跃顶点 ≈ 80   → 顶不动
现在：y −86…+2 （高 88，= 素材 123×84 + 2 px 余量）
```

**这一条是"反制手段"的根**：不能跳、不能从上面过，就只剩防御一种应对，
剩下的就只是"防不防得住"而不是"我怎么选"。

### 8.4 三类"这个角色不该有的坑"（与 Archer 同一批）

| 问题 | 具体 | 玩家感受 |
| --- | --- | --- |
| 空白判定（框 > 画面） | 210 框 **105** vs 画面 **81**；240 88 vs 67；1100 62 vs 46 | 「人机出拳比我的刀还远」—— 不是拳头长，是框撒谎 |
| 画面到了打不到（框 < 画面） | 200 −3、430 −7、440 −5、630 −8、800 −6 | 看着踢中了却没伤害 |
| 招式中途无敌（受击框缺口） | 210 **16 tick**、230 **8 tick** 无 Clsn2 | 想反击时打不到人 |

第三类是最容易被忽略的一条：`Clsn2` 没写 ≠ 沿用上一帧，而是**该帧没有受击框**。
`240` 一直用 `Clsn2Default`（所以它是对的），`210`/`230` 是漏的 —— 同一角色内部写法不一致。
修法是补 `Clsn2Default`，与 `240` 对齐。

顺带一个结论：**「人机出拳比我刀远」这件事，两边都要修**。Archer 那侧是框比刀短 16~19，
Fighter B 这侧是框比画面长 21~24。只修一边，"谁更长"仍然是错的。

### 8.5 帧优势：`guard.hittime` 缺省 = 取 `ground.hittime`

| 状态 | 改前 adv | 改后 adv | 改后被防 adv |
| --- | --- | --- | --- |
| 200 站轻拳 | **−5** | **+2**（尾巴 10→6、hittime 11→14） | +2 |
| 210 站重拳 | **−2** | **+2**（hittime 16→20） | **−5** |

210 显式写了 `guard.hittime: 13` / `guard.slidetime: 8`。原因是一条引擎事实：

```go
// char.go:878-884
// In Mugen this one acts diferent from the documentation
if c.stWgi().ikemenver[0] == 0 && c.stWgi().ikemenver[1] == 0 {
    ifierrset(&hd.guard_hittime, hd.ground_slidetime)
} else {
    ifierrset(&hd.guard_hittime, hd.ground_hittime)
}
```

本角色是 ikemenver 角色 ⇒ `guard.hittime` 缺省**等于 `ground.hittime`** ⇒
"被防"和"打中"收益完全一样，防线形同虚设。长手招的正确形状是
**安全于命中、危险于被读**：+2 / −5。

410（蹲重拳）**没有动**：它是 `ground.velocity: -3, -6` 的击飞招，对手在空中走
`air.hittime`，地面帧优势公式对它不成立。

### 8.6 工具：三个真 bug

1. **`audit_moveset.py` 的 `SC = 0.48` 是硬编码的**（Archer 的 xscale）。
   对 `test_fighter_b`（xscale = 1）会把所有判定框按 0.48 缩放 —— 5 条
   "投射物打不到人"全是假警报。改为从角色自己的 `.const` 读 `[Size] xscale`。
2. **`frame_data.py` 对击倒 / 击飞招误判**：440（`ground.type: Trip` + `fall: 1`）报 −3，
   410（`ground.velocity: -3, -6`）报 −2，都不是缺陷 —— 对手不回到中立，公式不适用。
   现在这两类招会跳过帧优势检查（但仍在表里显示数字，便于人看）。
3. **`frame_data.py` 没有 `guard.` 这一列**：被防之后的帧优势以前根本不可见，
   于是"被防和打中一样赚"这种问题没有任何工具会报。新增 `guard` / `adv_gr` 两列。

顺手把 `--check` 接进了回归：

```powershell
pwsh -File scripts/test.ps1 -Suite frame     # 对 game/chars/*/ 逐个 --check
```

`tests/tools/run_tool_tests.ps1` 的"角色文件守卫"（按 `git status` 判断有没有意外改动）
原本只放行 `archer/` 与 `test_fighter_b.air`，本轮扩到
`archer/` + `test_fighter_a/` + `test_fighter_b/` + `_template/`（写明原因与迭代文档）；
`p1_kfm_zss_lab` 与未来新角色仍受保护。

### 8.7 验证

```text
python tools/frame_data.py game/chars/<角色> --check
    _template PASS / archer PASS / test_fighter_a PASS / test_fighter_b PASS
python tools/audit_moveset.py game/chars/test_fighter_b   → 13 项 → 6 项
    （剩下 6 项与 _template / test_fighter_a 完全一致 = 模板基线，非本轮引入）
python tools/character_validate/validate_character.py     → 0 错误
    受击框缺口 210/230 已消失，只剩 820（受害状态，预期）
pwsh -File scripts/test.ps1                               → ALL TEST SUITES PASS
    资产测试 86/86 + 新增 frame 套件 4/4
```

负向对照（"只通过过的检查不算检查"）：把 `test_fighter_b` 复制一份、把 200 的框从 62 改回 40，
`--check` 立刻 `FAIL (1) - 200: hitbox is 21.0 units shorter than the artwork`，退出码 1。

Runtime 冒烟（`tests/p3/run_match_watch.ps1 -P1 archer -P2 test_fighter_b -Ai1 8 -Ai2 8 -RunSec 40`）：
角色正常加载并打完，**0 个新崩溃日志**。波的实际出现频率未取到程序化读数
（`numProj` 对本角色不可用，见 `verify_moves.ps1` 里那条注释），所以 8.1 的周期是**算术值**，
不是实测值 —— 这一条留给人工试玩确认。

---

## 九、第二轮：第一次为什么没修好（2026-11-04）

**负责人反馈**：「test fighter B 还是没有修复，依然远程无限波。此外，无限剑制伤害太低了，
没有作为大招的威力。」

### 9.1 先确认改动确实生效了

`grep` 运行时副本（`engine/ikemen-go/chars/test_fighter_b/`）：`var(1) := 140`、
`poweradd: 0`、`projremovetime: 80` 都是新值。所以不是"没生效"，是**幅度不够 / 机制猜错**。

### 9.2 第一个错误：把"3 秒一发"当成了"有间隔"

8.1 把 132 tick 一轮改成 182 tick 一轮，我在文档里写"每轮留 102 tick 真空白"，
听起来很够。但格斗游戏的体感尺度不是这样：**一波大约 1 秒横穿屏幕，你防住之后还剩 1.7 秒，
而对手已经在准备下一波** —— 玩家感受到的是"一直在防"，不是"有节奏"。

第二轮改成 **42 + 240 = 282 tick ≈ 4.7 秒**，并加了一道硬闸门：

```zss
let noProj = numProj = 0;      # 场上还有我的波，就绝不发下一发
```

同时把 EX（1010）和 Super（3000）也一起节流（冷却 300 / 360，概率 400‰ → 200‰）。
它们才是"一波接一波"的另一半来源：一旦攒到 500 气，EX 一次出**两发**、Super 一次出**三发**，
而这两条规则当时完全没被节流。

**踩到的语法坑**：`numProj` 在 ZSS 编译器里是**无参**触发器（`compiler.go:3189` 的
`case "numproj"` 直接 `out.append(OC_numproj)`，不调 `oneArg`），必须写裸标识符；
写成 `numProj()` 会编译失败，而 `validate_character` **不解析 ZSS 语法**、看不出来。
验证只能靠引擎加载 —— 按项目记录，ZSS 解析错误会留下 crash log 并弹窗，
本次两局（35 s + verify_moves）都 **0 个新崩溃日志**，所以编译是过的。

### 9.3 第二个错误：框对齐了，但"跳不过去"根本没解决

第一次我写：「判定框原来高 120、还往地下伸 20，而跳跃顶点 80 ⇒ 跳不过去；现在框 = 素材外框 +2」。
**这个推理是错的。** 素材 `1000,4` 是 123×84、整块不透明的**人形**，占自身原点上方 0..83；
`offset: 34,-40` 把它放在高度 **40..123**。框改成 −86..2 之后，世界高度是 **126..38** ——
顶反而从 100 升到了 **126**。跳跃顶点 80.2，差 46 px，**仍然不可能跳过去**。
我只改了"往下伸到地下"那一半，没算顶端。

正确的算法是把三件事一起摆出来：

```text
apex            = 8.4² / (2 × 0.44) = 80.2 px
画面高度区间     = -offset_y .. (-offset_y + 83)
要能跳过         ⇒ 画面顶 <= apex - 余量
```

`-offset_y + 83 <= 72` ⇒ `offset_y >= 11`。定稿取 **+18**（顶 65，跳跃窗口约 16 tick），
框与画面严格一致（`-58,-83,72,0`），EX / Super 的 6 个发射点一并压到 +12…+26。

代价写清楚：这团球有 18 px 沉在地下。占位素材是人形，本来就是临时货；
换成正式小火球后 `offset` 与 Action 1005 一起重算。**这不是"美术妥协"，是"占位素材的物理尺寸
（84 px）比角色跳跃高度（80 px）还大"这个事实的直接后果**——素材本身决定了它不可能被跳过。

### 9.4 无限剑制：不是"数字小"，是**结构倒挂**

| | 气耗 | 实测伤害 | 每点气的伤害 |
| --- | --- | --- | --- |
| Super 3000 | 1000 | **195** | 0.195 |
| 终极 3100（改前） | **2000**（整槽） | **96**（10 × 16 只连到 6 把） | **0.048** |

花两倍的气，打出四分之一的伤害。这不是"威力不足"，是**惩罚玩家用大招**。

改法：单把剑 `damage: 16 → 50`（10 把）。实测 **300**（连到 6 把），上限 500（站着不动吃满）。
`verify_moves` 的门槛同时从 `-Dmg 48` 提到 **`-Dmg 200`** —— 退化回 96 会直接 FAIL，
而不是"仍然 PASS"。

### 9.5 第二轮的验证

```text
python tools/audit_moveset.py game/chars/test_fighter_b   → 6 项（与 _template 一致的模板基线）
python tools/frame_data.py game/chars/archer --check      → PASS
tests/p3/run_match_watch.ps1 -P1 archer -P2 test_fighter_b -Ai1 8 -Ai2 8 -RunSec 35
    → 0 个新崩溃日志（ZSS 编译通过）
tests/p6/verify_moves.ps1 -Pass moves -Only 1
    → 3100 实测 300 伤害（门槛 200）PASS，耗气 -2000
```

**仍然没取到的**：波的实际出现频率。`numProj` 现在被 AI 直接使用，
所以"场上有没有波"这件事已经进了游戏逻辑；但**没有任何探针把它读出来**。
282 tick 依然是算术值 —— 这一条只能靠人工试玩确认，下一轮如果还要精确调，先给
`test_fighter_b` 加一份 probe（照 `tests/p6/fixtures/archer_probe.zss` 的样子）。

---

## 十、第三轮：把"占位人形"换成真火球（2026-11-06）

**动机**：9.3 的结论是「素材本身决定了它不可能被跳过」——48 px 高的对称光球只要
`offset_y ≥ -44` 就跳得过去，而 84 px 高、轴在底边的人形需要把发射点压到 **+18**
（沉进地下 18 px）才勉强够。也就是说：**上一轮那个"18 px 沉在地下"的补偿，
是占位素材的物理尺寸换来的，不是设计**。把它去掉的唯一办法是换素材。

### 10.1 素材：自己生成，避免授权与产能双重卡点

`tools/make_projectile_art.py`（纯标准库，~150 行）：48×48、4 帧、轴在中心，
核心半径脉动 + 边缘色相漂移。输出 PNG 并把可直接抄进 `.air` 的 `axis` / `Clsn` 打出来。
选"生成"而不是"找素材"的原因：投射物是**纯能量体**，没有解剖结构，程序生成的观感
足够用；而任何第三方素材都要走 `assets/LICENSE_MANIFEST.csv` 那套流程。

### 10.2 写回：`sffpack set-sprite`，不是 `transcode`

`transcode` 会把**每个**精灵重编码成 raw 深度 8。目标容器 282 个精灵全是 lz5(depth 5)
与 PNG8，重编码等于把整包重写一遍，白白改变压缩率与色板槽位。
新增的 `set-sprite` 走另一条路：**未点名的精灵按原始字节复制**（连 v2 的 4 字节长度前缀
都不碰），只替换/追加命令行点名的键。写盘后重新读取，对每个未触碰精灵比对
"存储字节 + 宽高 + 轴 + 格式/深度/pal_index + link"，不一致返回 1。

实测：

```text
set-sprite: test_fighter_b.sff -> test_fighter_b.sff
  source:   2.0.1.0, 282 sprites, 16 palettes
  added:    1900,0, 1900,1, 1900,2, 1900,3
  written:  2.0.1.0, 286 sprites, 215419 bytes
  verify:   re-read OK; 282 untouched sprites compared byte-exact, 0 mismatch
```

写这套验证时踩到两个坑，都记进 `docs/character_asset_tooling.md`：
① 用"解码后的像素"比对会**误报** PNG8 精灵（它自带 PLTE，`pal_index` 指向容器里不存在的槽）；
② sprite header 的 `flags` 位 0 决定偏移基准是 **tofs** 还是 **lofs**，复制源精灵时必须清掉。

### 10.3 发射点全部重算（这次先算，再改）

```text
光球 48×48、axis 24,24 ⇒ 画面相对原点 -24..+23
apex = 8.4² / (2 × 0.44) = 80.2
画面顶 = -offset_y + 24 ≤ 80.2 - 12 = 68.2   ⇒   offset_y ≥ -44.2
```

| 状态 | 改前 | 改后 | 画面顶 |
| --- | --- | --- | --- |
| 1000 普通 | `+18` | **`-40`** | 64 |
| 1010 EX（2 发） | `+12, +26` | **`-44, -32`** | 68 / 56 |
| 3000 Super（3 发） | `+12, +18, +24` | **`-44, -38, -32`** | 68 / 62 / 56 |

判定框 `-58,-83,72,0` → **`-22,-22,21,21`**（画面 ±2）。
命中判定的 y 重叠核过：新弹体世界高度 **-62..-18**，对手站姿受击盒 0..-80 ⇒ 重叠 44 px；
蹲姿 0..-50 ⇒ 重叠 32 px。**x 方向变短了**（世界 12..55，原来到 106），
但这只影响"多飞几 tick 才够到"，弹体活 80 tick × 6 px = 480 px，够。

动画从"1 帧 + `-1` 保持"改成 **4 帧 + `Loopstart` 循环**（每帧 3 tick）。
`Clsn1Default` 的必要性不变（引擎里 `-1` 与循环是同一种"动画停留"）。

### 10.4 验证

```text
python tools/airtool/airtool.py validate .../test_fighter_b.air   → 0 error（sprite 引用按 286 个核对）
python tools/character_validate/validate_character.py ...          → 0 error，WARN 1（820 受击盒缺口，既有）
python tools/frame_data.py game/chars/test_fighter_b --check       → PASS
python tools/audit_moveset.py game/chars/test_fighter_b            → 6 项（模板基线，无新增）
pwsh -File scripts/test.ps1                                        → 87/87 + frame 4/4 全 PASS
tests/p3/run_match_watch.ps1 -P1 archer -P2 test_fighter_b -RunSec 35
    → 0 个新崩溃日志；截图确认光球按预期渲染、位于腰高
```

**测试侧的连带修改**（`tests/tools/run_tool_tests.ps1`）：四条断言把
`test_fighter_b` 的旧内容写死了 —— `Sprites: 282`（现 286）、
`action 1005 ... -1 hold`（现为 `Loopstart` 循环）。改法：
① 精灵数收进文件顶部一个 `$realSffSprites` 常量；
② `-1` 检查挪到仍然带 `-1` 的 **action 600**（跳跃）；
③ 另加一条断言：**1005 必须报 `Loopstart: element 0` + `Duration:  12 ticks`**
（换素材时若把循环写丢，这条会挂）。

**新增 group 17**（`set-sprite` 与光球生成器此前完全没有测试，而 `set-sprite` 是
能静默毁掉美术的写盘路径）：15 条断言，其中最关键的一条是**独立**验证 ——
把源容器和产物都导出成 PNG，逐字节比对三张共享精灵，
不依赖工具自己的 "0 mismatch" 自述。全套 87 → **102** 项。

**仍未取到**：波的实际出现频率（与 9.5 同一项未决）。下一轮加 probe。

# 2026-11-08 试玩反馈：为什么打不过引擎自带的 Kung Fu Man

## 一、反馈与一个理解上的纠正

负责人试玩后的原话，拆成四条：

1. 无限剑制威力不够，**一次至少要打掉 30% 血**。
2. 和默认角色 `kfm` 对打，「几乎一秒钟连中几招就会掉 45% 的血量」；
   而我方打对方「只掉一点点血量」，「对方防御的时候可以不掉血」。
3. 我方**几乎连不上招**：击中后对方立刻能防御/反击；猛按 A 时第二次
   「因为打退还是自己的后退，根本就打不到对方」。
4. `kfm` 能连击、能瞬间转防御、攻击完立刻防御，「这期间我按防御也没有，
   按攻击也打不出来」。

> ★ **记录一次理解错误**：我最初把 ② 里的「对方防御不掉血」和「我方被打掉很多」
> 当成"防御机制自相矛盾"。**它们根本不矛盾**，是同一个不对称问题的两面：
> 我方进攻被防时零收益，对方进攻时我方零防御且掉大血；再叠加 ③ 的"我方连不上、
> 对方能连"，净 DPS 差出几倍。负责人当场指出后按这个方向重查，才找到真正的原因。
> 以后遇到"两边不一样"的反馈，先当成**同一机制的两侧**，别急着当成逻辑冲突。

## 二、诊断：不是数值保守，是连招链路断了

先排除了最容易猜错的两项（`engine/ikemen-go/chars/kfm/kfm.cns` 对比 `game/chars/*/*.const`）：

| | kfm | 我方 | 结论 |
| --- | --- | --- | --- |
| `attack` / `defence` | 100 / 100 | 100 / 100 | 无倍率差 |
| 轻拳 `damage` | 23 | 24~30 | 我方**略高** |
| 重拳 `damage` | 57 / 63 | 62~75 | 我方**略高** |
| `life` | 1000 | 1000 | 相同 |

所以"数值给保守了"这个直觉是错的，伤害绝对值并不低。真正的原因有四条：

### 2.1 击退是对方的 3 倍（「第二下够不到」）

| 站轻拳 hitDef | kfm | Archer（改前） | 改后 |
| --- | --- | --- | --- |
| `ground.slidetime` | 5 | **12** | 5 |
| `ground.velocity` | −4 | **−5** | −3 |
| 实际推开 | ≈20 px | **≈60 px** | ≈15 px |
| `ground.hittime` | 11 | 16 | 16（不动） |

T1 同键二段（State 250）用的判定框和一段**一样长**，对手被推 60 px 之后必然空振。
这就是"第一次 A 到、第二次打不到"的全部原因。我方 hittime 甚至比 kfm 更长，
问题从来不是硬直不够，是**人被打飞了**。

### 2.2 取消链在数学上禁止轻拳连打（「猛按 A 只有一下」）

`command.zss` 的 `CanChain(lv)` 原本只有「等级严格递增」一条：

```zss
if moveType = A && stateType != A && var(3) > 0 && var(3) < $lv && ...
```

轻拳是 lv1，接轻拳是 `$lv = 1`，条件 `var(3) < 1` **恒假**。而 kfm 的
`kfm.cmd:630-638` 明写：

```ini
[State -1, Stand Light Punch]
trigger1 = statetype = S
trigger1 = ctrl
trigger2 = stateno = 200
trigger2 = time > 6          ; ★ 轻拳自己取消自己
```

kfm 靠取消在对手硬直内接上下一拳 = 真连；我方被数学挡住 = 只能出一下。
（另外 `var(0)` 全仓只有 `AtkInit` 里的 `var(0) := 0`，**从未被置过 1**，
所以"本次攻击只取消一次"的锁一直是死条件，这次明确不依赖它。）

### 2.3 被防零收益（「防御时不掉血」）

`damage: 24, 0` 的第二个数是 **guard damage（被防削减伤害）**，我方所有轻技
都是 0；投射物只有 6 / 1000 = 0.6%，血条肉眼不动。kfm 的必杀是
`damage = 90, 4` ~ `155, 12`，有削血。

引擎侧确认：`char.go:10859` 走 `hd.guarddamage`，`computeDamage()`（`char.go:8672`）
算的是 `damage *= atkmul / finalDefense`。所以这不是 bug，是**配置成 0**。

顺带查清两条相邻现象：
- `finalDefense`（`char.go:12426`）包含 `fallDefenseMul`，每次被击倒 ×1.5
  （`fall.defence_up = 50`），会累积到回合结束 —— 越打越"打不动"是真实机制。
- 「被连击时按防御没用」是真连（true combo）的正常表现，不是防御坏了；
  `holdback` 命令与 common1 的 120/130/140/150/152/154 都在。

### 2.4 「kfm 瞬间转防御」是引擎内置 AI，不是角色后摇

`kfm.def` 的 `ai = kfm.ai ; (not used)`，实际由引擎内置 AI 每 tick 判防御。
kfm 在 `engine/ikemen-go/chars/` 里、不在 `game/` 真值中，改它会被下次
`sync_game_content.ps1` 冲掉。**本轮不动 kfm**，只把我方调到能对等连段。

## 三、改动（全部在角色配置层，未动引擎 / 未动 kfm）

| 类别 | 文件 | 改法 |
| --- | --- | --- |
| 连段 | `archer/` `test_fighter_a/` `test_fighter_b/` 的 `command.zss` | `CanChain` 新增 c) **同等级取消**分支：仅 lv1/lv2、`var(4)=1`、`time >= 6`、`moveType=A && stateType!=A`；不设 `var(3)` 上限，好让 Archer 的 lv4 T1 二段能接回普通技。同时给 a/b 补上 Archer 在 10-31 已补、它们漏掉的 `moveType/stateType` 守卫 |
| 击退 | 三个角色的 `*.zss`，共 54 个状态 | 轻技 + T1 二段：`slidetime ≤ 5`、`velocity → −3`；重技：`slidetime ≤ 10`、velocity 软化 2。空中招的 `air.velocity` 未动 |
| 削血 | 同上 | `damage: N, 0` → `N, 6`；`1 ≤ M ≤ 6` → `M × 2`（必杀 6→12、投射物 6→12）；`M ≥ 7` 保持 |
| 生存 | 四个角色的 `.const` | `defence 100 → 120` ⇒ 承伤 ×0.83（`computeDamage` 的 `finalDefense`） |
| 大招 | `archer/archer.zss` StateDef 3100 | 10 把剑 `damage: 50, 10 → 80, 20`，剑的 `ground.velocity −2 → −1`、`ground.hittime 18 → 20`（落点固定，减少被推开后漏剑） |
| 验收 | `tests/p6/verify_moves.ps1` | ① 伤害期望按 `.const` 的 `attack/defence` 比率缩放（不再写死）；② `exact` 判定给 ±2 容差（引擎按**每段命中单独取整**）；③ 3100 门槛 200→300；④ T1 连 X 从 `min` 改 `atleast 70`；⑤ 新增「A 四连打」配方 |

`_template/command.zss` 仍是旧的搓招 `Combo()` 体系、没有 `CanChain`，
这轮没动它（重写路由体系超出范围），已在文档登记。

## 四、验证（全部实测，不是算术）

```text
tests/p6/verify_moves.ps1 -Pass moves        → 30/30 PASS（全量）
   3100 无限剑制        402 / 门槛 300      → 40% 血（改前 300 = 30%）
   T1 连 X 重脚二段      96 / 门槛 70       → 改前 64，二段必然空振，现在命中
   A 四连打              74 / 门槛 55       → 折合声明值 89 = 24+20+24+20，四段全中
   damage ratio         0.8333（从 .const 读）

tests/p3/run_match_watch.ps1 (archer vs kfm / a vs b)  → 0 个新崩溃日志
tests/p4/probe_projectile.ps1 -RunSec 40                → VERDICT PASS
   waves 7 / 间隔中位 240 tick（未被本轮改动破坏）
   远距离命中 8 次，伤害 60→50（defence 120 的预期缩放）
python tools/frame_data.py <四个角色> --check            → 全 PASS
python tools/audit_moveset.py                          → archer 0 / a 8 / b 6（模板基线）
scripts/test.ps1                                       → ALL TEST SUITES PASS
```

**最值得记的一条**：A 四连打从"只能出一下"变成"四段全中 74 伤害"，
这一条把「击退 + 取消链」两个改动同时验证了 —— 只改其中一个都达不到。

## 五、可调旋钮（试玩后微调用）

| 旋钮 | 现在 | 往哪调 | 副作用 |
| --- | --- | --- | --- |
| `defence`（四角色 `.const`） | 120 | 还嫌脆 → 135~150 | 我方作为攻方时，对同样角色的伤害也降（验收 agent 比已自动跟随） |
| 轻技 `ground.velocity` | −3 | 连得太黏 → −4 | 回到 kfm 水平，连段数会下降 |
| `CanChain` 的 `time >= 6` | 6 | 连得太容易 → 8~10 | 取消窗口变窄 |
| 3100 单把 | 80 | 太强 → 65 | 4 连 = 260，跌破 30% 门槛（`verify_moves` 会挂） |
| 普通技 guarddamage | 6 | 被防还是没感觉 → 10 | 防御方掉血变快，压制成"龟不住" |

## 六、仍未做

- Archer 1400 判定框 103.7 vs 画面 64.3、1100 框 73 vs 25.4（旧账）。
- `verify_moves.ps1` 方向键按 facing 换算（`Move-Near` / `Move-Far`）。
- `_template/command.zss` 仍是旧搓招体系，作为新角色克隆源会传播旧取消语义。
- 「和 kfm 对打」的体感最终仍需负责人试玩确认；本轮证据是程序可读的
  伤害/状态/间隔读数，不是截图目测。

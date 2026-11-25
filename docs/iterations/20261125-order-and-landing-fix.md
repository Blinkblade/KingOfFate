# 2026-11-25 实际复测：265 射完卡半空、8 招帧序回退、pos y 编译坑

## 一、反馈与复测方法

负责人：「空中斜下射箭问题最大。其他的动画和打击效果有一些问题，建议全部实际复测一遍。」

这次不靠 `verify_moves` 的伤害断言（它只看血量和状态号，看不出"卡在半空"），
改成读**探针 CSV 的逐帧轨迹**：`logs/p6/verify/run.csv` 有
`stateNo / time / posX / posY / velX / anim / proj / p2StateNo / p2Life / p2BodyDistX`，
可以完整还原一次施法的空间轨迹与命中时刻。

## 二、复测抓到的四个问题

### 2.1 ★ 265 射完箭「永久悬停在半空」（问题最大）

逐帧数据（修复前）：

```text
time 1   posY  -7.00      ← 每 tick 被 velSet{y:-7} 重置，匀速上升
time 8   posY -56.00
time 17  posY -99.20      ← 箭出手
time 23  posY -108.20     ← 顶点
time 31  posY -95.56      ← 状态结束，切回 state 0
time 1..7 (state 0)  posY -95.56 不变   ← 卡死
```

两个原因叠加：

1. `if time < 8 { velSet{y: -7} }` **每 tick 重置 y 速度** → 8 tick 匀速上升
   56px，总高度 108px（正常应 59px），31 tick 根本落不了地。
2. `call EndState(0)` 在**空中**切到 `state 0`（站立，`physics: S`）。
   `physics: S` 不应用重力，y < 0 就永远悬着 —— 实测 posY 卡在 −95.56。

修法：

```zss
# 只给一次初速，之后交给重力（apex ≈ 59px，滞空 ≈ 33 tick）
if time < 1 { velSet{x: -1.5; y: -7.2} }
if time >= 1 && time < 4 { velSet{x: -1.5} }
if time >= 4 { velSet{x: 0} }

# 动画播完**且已落地**才回站立；没落地就停在最后一帧继续下落
if animTime = 0 && pos y >= 0 { changeState{value: 0; ctrl: 1} }
```

修复后：

```text
time 17  posY -62.56   ← 顶点（合理高度）
time 19  p2Life -46    ← 箭命中
time 33  posY  -5.28
state 52 → state 0, posY 0.00   ← 经跳跃落地状态正常收尾
```

### 2.2 265 后撤漂移，把距离从 130 拉到 195

`velSet{x: -1.5}` 写在 `time < 8` 里，8 tick 后角色还在滑（空中无摩擦），
等箭出手时已经退开 65px，箭更难命中。改成只退 4 tick（约 6px）后 `velSet{x: 0}`，
实测距离 130.6 → 135.1。

### 2.3 ★ 8 招帧序回退（"动画有问题"的真正来源）

上一版为了**不动 ZSS 的 `animElem = 4`**，把"伸得最远的帧"强行重排到第 4 个元素：

```text
262 : 1,2,3,0,4,5,6,7     ← 从帧 3 跳回帧 0
264 : 0,1,2,5,3,4,6,7,9   ← 2→5→3 回退
266 : 0,1,3,2,4,5,6       ← 1→3→2 回退
```

播放时就是"动作倒放一下再继续"。现在全部改回**源动作原顺序 0..N-1**，
判定元素改成该动作真正伸最远那帧的位置（ZSS 的 `animElem` 跟着改）：

| 招 | 帧数 | 判定元素 | 判定帧起始 tick | hittime | adv |
| --- | --- | --- | --- | --- | --- |
| 260 | 8 | elem3 | 5 | 18 | +4 |
| 261 | 13 | elem5 | 8 | 24 | +4 |
| 262 | 8 | elem7 | 12 | 10 | +5 |
| 263 | 13 | elem8 | 14 | 18 | +4 |
| 264 | 10 | elem6 | 10 | 16 | +4 |
| 266 | 7 | elem2 | 2 | 17 | +4 |
| 267 | 9 | elem4 | 6 | 18 | +4 |

判定帧的选择规则也修了一次：**不能直接取 reach 最大帧**。
- 261 的 reach 峰在 frame 10（60.0），那是收招时刀甩到最远 —— 用它做判定会让
  这招起手变成 20 tick。改取中段的平滑峰 frame 4（53.8），起手 8 tick。
- 264 的 frame 6 reach 130.1，是披风/拖影不是刀。加 90 世界上限过滤，取 frame 5（63.8）。

### 2.4 ★ 引擎 panic：`posY` 必须写 `pos y`

第一版修 2.1 时写了 `posY >= 0`，引擎启动直接 panic：

```text
chars/archer/archer.zss:1005: Invalid data: posy
```

ZSS 里位置触发器是**带空格**的 `pos y` / `vel y`（项目 `_template/hits.zss:59`
有先例）。写成 `posY` 编译器不认，而且报错发生在**加载期**，
表现是 `run_match_watch` 报 "no probe rows"，很容易误判成探针没接上。

## 三、验证

```text
verify_moves -Pass moves        39/39 PASS
  8 招 25/25 46/46 28/28 48/48 28/28 46(箭)/55 27/27 47/47，耗气全 0
  收招 tick 30~45（比上一版略长，因为补了完整收招帧）
frame_data 四角色 --check       全 PASS（adv +4~+5、框 vs 画面 ok）
validate_character archer       0 error / 3 既有 warning
audit_moveset archer            共 0 项
scripts/test.ps1                ALL TEST SUITES PASS
265 轨迹                         apex -62.56、落地 posY 0、命中 -46
run_match_watch                 0 个新崩溃日志（sync 后）
```

## 四、改动文件

| 文件 | 内容 |
| --- | --- |
| `game/chars/archer/archer.air` | 8 个 Action 改回源顺序；判定元素随 peak 位置变化 |
| `game/chars/archer/archer.zss` | `animElem`/`hittime`/特效 tick 对齐；265 重写落地与位移 |
| `tests/p6/verify_moves.ps1` | 无改动（265 仍是 `-Dist far -DmgRule min`） |

## 五、可调旋钮

| 旋钮 | 现在 | 说明 |
| --- | --- | --- |
| 265 起跳 `velSet{y}` | −7.2 | 改大 → 跳更高、滞空更久（要同步加长状态，否则落地前停在收招帧） |
| 265 放箭元素 | elem10（tick 17） | 提前到 elem9 会让箭更早出手，但可能还在上升段 |
| 箭 `offset` | 60, −80 | 与起跳高度联动；改跳跃必须重算 |
| 262 hittime | 10 | 判定在倒数第二帧，帧优势天然大；压到 10 避免"一踢就锁死对手" |

## 六、仍未做

- 动画的**观感**（流畅度、特效位置是否好看）只能人眼确认，本轮的技术复测
  只能证明：帧序无回退、判定帧在合理位置、帧优势为正、落地正常、伤害对得上。
- 两个测试角色仍是旧搓招体系；总纲的招式属性标签未做。

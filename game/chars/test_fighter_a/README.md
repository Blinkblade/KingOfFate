# KingOfFate — Test Fighter A（`game/chars/test_fighter_a/`）

P3 交付的**第一个独立可玩角色**：由 `game/chars/_template/` 克隆而来，
在模板的基础上补齐了蹲攻、跳攻、两个必杀、EX、Super、取消链和独立 AI。

| | |
| --- | --- |
| **定位** | All-rounder（均衡型）测试角色 —— 简单、好读、好测 |
| **用途** | 玩法验证 / 模板验证 / 后续系统开发的测试对象 |
| **不是** | 正式动漫角色、最终美术角色、平衡过的角色 |
| **引擎** | IKEMEN GO `v1.0.0-rc.5`（与仓库基线一致，未改引擎） |
| **资产** | **非最终资产**：SFF/SND 仍是 KFM 占位素材（见 §11） |
| **Frame Data** | [`design/characters/test_fighter_a/moves.csv`](../../../design/characters/test_fighter_a/moves.csv) |
| **设计说明** | [`design/characters/test_fighter_a/README.md`](../../../design/characters/test_fighter_a/README.md) |
| **验收证据** | [`docs/phase_reports/P3-test-fighter-a.md`](../../../docs/phase_reports/P3-test-fighter-a.md) |

---

## 1. 文件结构

```text
game/chars/test_fighter_a/
├── test_fighter_a.def     角色定义（文件映射 + 元信息）—— 不含战斗逻辑
├── test_fighter_a.const   数值基线（体力/气槽上限/尺寸/速度）+ 变量台账
├── test_fighter_a.cmd     物理按键 → 命令名（顺序 = 命令优先级）
├── test_fighter_a.zss     状态主体（每个 [StateDef N] 一个状态）
├── test_fighter_a.air     动画 + 判定框（Clsn1 攻击框 / Clsn2 受击框）
├── test_fighter_a.sff     精灵容器（★ PLACEHOLDER）
├── test_fighter_a.snd     音效容器（★ PLACEHOLDER）
├── command.zss            命令路由：命令名 → 状态号（顺序 = 路由优先级）
├── hits.zss               受击方状态：投技受害 820 / 821（含受身）
├── AI.zss                 CPU AI（顺序 = AI 优先级）
├── movelist.dat           出招表（游戏内展示用）
└── README.md              本文件
```

12 个文件。`stcommon = common1.cns.zss` **不在本目录是正确的** —— 引擎从
画面包 `data/` 搜索它，不要复制进来。

---

## 2. 招式表

四键 = `x` A 轻拳 / `a` B 轻脚 / `y` C 重拳 / `b` D 重脚。
状态号规律：`+0 = A 轻拳`、`+10 = C 重拳`、`+30 = B 轻脚`、`+40 = D 重脚`。

### 站立（Standing）

| 键 | 招式 | 状态 | 起手 | 判定 | 收招 | 伤害 | 定位 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `x` | Stand A 轻拳 | **200** | 3 | 4 | 13 | 25 | 最快、范围最小（到 x=61） |
| `a` | Stand B 轻脚 | **230** | 4 | 4 | 8 | 30 | 稍长距离轻攻击（到 x=69） |
| `y` | Stand C 重拳 | **210** | 10 | 3 | 14 | 70 | 高伤害重攻击 |
| `b` | Stand D 重脚 | **240** | 7 | 4 | 15 | 75 | **最长距离**（到 x=84） |

### 蹲（Crouching）—— 全部为下段（`guardflag: L`，站防挡不住）

| 键 | 招式 | 状态 | 起手 | 判定 | 收招 | 伤害 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `下+x` | Crouch A 蹲轻拳 | **400** | 3 | 6 | 3 | 25 | 下蹲起手最快 |
| `下+a` | Crouch B 蹲轻脚 | **430** | 4 | 3 | 10 | 30 | 比蹲轻拳远 |
| `下+y` | Crouch C 蹲重拳 | **410** | 7 | 5 | 8 | 60 | 单段（刻意不做两段） |
| `下+b` | Crouch D 蹲重脚 | **440** | 9 | 4 | 17 | 70 | **扫腿**：`Trip` + `fall: 1` 击倒 |

### 跳（Jumping）—— 空中，落地由引擎进公共状态 52

| 键 | 招式 | 状态 | 起手 | 判定 | 伤害 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| `上+x` | Jump A 跳轻拳 | **600** | 3 | 11 | 25 | 判定持续最久 |
| `上+a` | Jump B 跳轻脚 | **630** | 3 | 3 | 30 | 射程最短（x=35） |
| `上+y` | Jump C 跳重拳 | **610** | 6 | 5 | 70 | 射程到 x=57 |
| `上+b` | Jump D 跳重脚 | **640** | 6 | 5 | 75 | 空中射程最长（x=69） |

### 投技 / 必杀 / EX / Super

| 招式 | 命令 | 状态 | 伤害 | 气量 | 备注 |
| --- | --- | --- | --- | --- | --- |
| **Throw 投技** | 贴身 + 前/后 + `y`/`b` | **800 → 810** | 90 | 集 10 | 走 `targetLifeAdd`，不经 `hitDef.damage`；受害者进 **820 / 821**（可受身） |
| **Special 1 突进直拳** | 236 + A（`QCF_x`） | **1000** | 85 | 集 40 | 突进 22 px；近距离压制 |
| **Special 2 升龙踢（对空）** | 214 + A（`QCB_x`） | **1100** | 70 | 集 35 | 判定框高到 y=-131；命中即击倒；收招 24 tick（挥空即破绽） |
| **EX 突进直拳** | 236 + C（`QCF_y`） | **1010** | 130 | **耗 500** | 突进 32 px、`fall: 1` 击倒 |
| **Super 超必杀直拳** | 236236 + A（`QCF2_x`） | **3000** | 200 | **耗 1000** | 突进 44 px、击倒且 `fall.recover: 0`（不可受身） |

其余：胜利姿势 **180**（占位）、嘲讽 **195**（`start`）。

---

## 3. 气槽（Meter）

只用引擎原生 `power`，**没有第二套气槽**。

- **上限**由 `test_fighter_a.const` 的 `power = 2000` 决定（**不是起始气量**）。
  P3 相对模板把它从 1000 提到 2000：模板的 1000 只够一次 EX，
  放不下 1000 气的 Super。本角色的本钱结构 = 1 个 Super 或 2 个 EX。
- **起点为 0**，且**跨回合保留**（P2 实测 V18/V19）。
- **收入** = 命中给气（≈0.7×伤害）+ 状态头 `poweradd`（普通技 10–40、必杀 35–40）。
- **支出** = 路由层的 `power >= N` 门（`command.zss`）+ 状态内 `powerAdd{value: -N}`
  （1010 扣 500、3000 扣 1000）。

---

## 4. 取消链（Cancel）—— 等级系统

`command.zss` 的 `[Function CanChain(lv)]` 实现**严格递增的链等级**：

```text
lv1 轻普通技   200 / 230 / 400 / 430 / 600 / 630
  ↓
lv2 重普通技   210 / 240 / 410 / 440 / 610 / 640
  ↓
lv3 必杀技     1000 / 1100
  ↓
lv4 EX / Super 1010 / 3000
```

- 每个攻击状态在自己的 **time = 0** 调 `AtkInit(lv)` 写下 `var(3) = lv`，
  并在**首个判定帧**把 `var(4)` 置 1（取消窗口开启）。
- 放行条件（`CanChain`）：① 地面自由态；**或** ② `var(3) < 目标等级`
  且 `var(4) = 1` 且 `var(0) = 0`（本次攻击尚未取消过）。
- 等级只增不减 → **连段长度天然有上限（最长 4 段），不可能无限循环**。
- 空中普通技不参与取消链（没有空中必杀技，放行会切错状态）。
- 取消**不要求命中**（`moveContact`）—— 刻意放宽以便观测；
  要收紧就在 `CanChain` 的第二个分支加 `&& moveContact`。

---

## 5. 状态号约定

自实现：**180 / 195 / 200 / 210 / 230 / 240 / 400 / 410 / 430 / 440 /
600 / 610 / 630 / 640 / 800 / 810 / 1000 / 1010 / 1100 / 3000**，
以及 `hits.zss` 的受击方 **820 / 821**。

**不重实现**（IKEMEN 公共状态）：0 / 10–12 / 20–21 / 40–52 / 100 / 105 /
120 / 130–155 / 5000–5210。

`+0/+10/+30/+40 = A/C/B/D` 的编号规律在站立（200 系）、蹲（400 系）、
跳（600 系）三段完全一致 —— 加招时请沿用。

---

## 6. AI（`AI.zss`）

规则 AI，**顺序 = 优先级**（无评分、无 planner）：

```text
① 防御      对手攻击中 + 在防御距离        → 公共状态 120
② 对空      对手在空中 + 30–150 px + 冷却  → 1100（升龙踢）
③ Super     气 ≥ 1000 + 45–130 px + 25%    → 3000
④ EX        气 ≥ 500  + 45–130 px + 40%    → 1010
⑤ Special 1 45–130 px（兜底必杀）          → 1000
⑥ 普通技    < 45 px（200 / 430 / 210，概率分摊）
⑦ 投技      < 12 px（概率带 aiLevelF）
⑧ 接近      ≥ 45 px                        → 走路（公共状态 20）
```

③④⑤ 的距离波段相同，靠 **Power 条件 + `random` 概率闸门**区分 ——
否则 ③ 会在气够时吞掉 ④⑤（这正是 P1 实验 E6 的失败模式）。

---

## 7. 怎么运行

```powershell
# 同步到引擎运行目录（game/ 是 Git 真值，引擎目录是生成物）
pwsh -File scripts/sync_game_content.ps1

# 启动一局：Test Fighter A 对 KFM
pwsh -File scripts/run_game.ps1 -ExtraArgs '-p1','test_fighter_a','-p2','kfm_zss','-s','stage0','-windowed'
```

默认键盘（`docs/controls.md`）：`x`=A、`a`=B、`y`=C、`b`=D；`start`=嘲讽。

---

## 8. 怎么测试

| 想验证什么 | 用什么 |
| --- | --- |
| 仓库回归（静态检查） | `pwsh -File scripts/test.ps1` |
| 角色还能不能被加载 / 引擎有没有崩溃 | `pwsh -File tests/p3/run_match_watch.ps1 -P1 test_fighter_a -Ai1 8 -Ai2 8 -RunSec 60 -ShowDebug` |
| 玩家侧单招（注入按键） | `pwsh -File tests/p1/capture_match.ps1 -Ai1 0 -HoldSeqVK ...`（**必须 `-Ai1 0`**） |
| 搓招 / 多键相位（236、214、236236、投技） | `pwsh -File tests/p2/inject_phases.ps1 -Phases '0x28:...,0x28+0x27:...,0x27:...,0x09:...'` |
| 读状态号 / 拼图 | `tests/p1/montage_states.ps1` |

**本机硬约束**（P1 起有效，`tests/p1/README.md` §6）：

- 注入实验必须 `-Ai1 0`，且报告的 `args` 行**不能出现 `-p1.ai`**；
- 只有 `TAB`(0x09) / `RETURN`(0x0D) 与方向键能到达引擎 → 测 A/C 键与搓招可行，
  **B/D 键与嘲讽需要真人键盘**；
- 引擎调试热键（`F3` 充满气、`F1` 击杀对手、`F5` 回合计时归零）**可以**被合成注入触发；
- 调试覆盖层的 `P1: <n>` 是**角色 ID 不是坐标**。

---

## 9. 已知限制

1. **不是平衡过的角色**：数值只做到"不离谱"，没有伤害模型、没有胜率目标（属 P10）。
2. **占位资产**：SFF/SND 是 KFM 素材（见 §11），发布前必须替换。
3. **B/D 键、嘲讽的运行时证据需真人键盘**（本机合成注入不可达）——
   Phase Report 的矩阵里如实标注。
4. **Super / EX 没有表现层**：无 superPause 定格、无闪光/镜头/暗转、无分身状态。
5. **Special 2（升龙踢）用上勾拳占位精灵**：动作语义对得上，但不是原创"踢"。
6. **取消不要求命中**（空挥也能取消）；正式角色应加 `moveContact`。
7. **蹲攻的判定框沿用 KFM 原型几何**（精灵就是 KFM 的，框对得上）；
   换原创美术时必须重画。
8. **AI 不使用蹲防 / 空中攻击**：它只会 ⑥ 里的地面三招 + 投技 + 必杀，
   低难度表现差异只来自 `aiLevelF` 概率。

---

## 10. 与 `_template` 的关系

```text
game/chars/_template/     ← 基础模板（P2 交付，仍是所有新角色的起点）
        ↓ 克隆 + 改名 + 扩展
game/chars/test_fighter_a/ ← 本角色（P3 交付）
```

- 本目录**不依赖** `_template`：删掉模板也能正常运行（GATE-04）。
- 开发中发现**模板本身的问题**（不是本角色特有的）应改模板并同步，
  不要只在本角色里绕过 —— P3 已经这样修了两处：模板手册的克隆步骤
  与 `scripts/sync_game_content.ps1` 的误导性输出。
- 模板手册 §5.1 列出了本角色实现的每个预留区间，扩展新招时**先读它**。

---

## 11. Placeholder 资产与许可（重要）

- `test_fighter_a.sff` / `test_fighter_a.snd` **不是本项目原创资产**。
- 来源：`game/chars/p1_kfm_zss_lab/` 的 `kfm.sff` / `kfm.snd`
  （Elecbyte 的 Kung Fu Man，P1 研究用素材，经 `_template` 克隆而来）。
- 许可：**CC-BY-NC**（非商业）。登记在
  [`assets/LICENSE_MANIFEST.csv`](../../../assets/LICENSE_MANIFEST.csv)，
  `usage = prototype_only`。
- **发布前必须替换为原创美术与音频**，并更新许可清单。这是硬性要求。

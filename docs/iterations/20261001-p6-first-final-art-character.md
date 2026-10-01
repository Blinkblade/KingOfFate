# Iteration: P6 — First Final-Art Character（第一个正式美术角色）

## 基本信息

- 日期：2026-09-30 起（跨 2026-10-01 凌晨）
- Phase：P6 — First Final-Art Character
- Branch：`feature/p6-first-final-art-character`（10 个提交，**尚未合并**）
- PR：待创建
- 状态：**进行中（IN PROGRESS）** —— 可玩、可校验，但美术源要升级为高精度版后才算完成
- 基线：`main` @ 上一个 P5 合并点
- 引擎：`engine/ikemen-go` @ `ba516193`（`v1.0.0-rc.5`）—— **全程未修改，submodule 未动**

---

## 本次目标

让项目拥有**第一个用正式美术（而非 KFM 占位）的角色**，并且：

1. 战斗逻辑复用 P1–P5 已验证的架构（不重造状态机）
2. 美术来自可追溯、可许可登记的素材源
3. 兑换美术这件事本身**可重复**（有映射表 + 转码工具，而不是手工拖图）
4. 能进 Runtime 实测，证据可审计

角色选定：**Archer / EMIYA**（Fate/stay night），ID `archer`，
骨架继承 P4 的 Zoner（`test_fighter_b`），非商用同人。

---

## 为什么先做工具，再做角色

P5 结束时资产工具链只支持 SFF **v2**，而社区上能拿到的 Archer 素材是 SFF **v1**。
P6 因此先补两件**当前素材真正需要**的能力，而不是"看起来完整"的能力：

| 新增 | 理由 |
| --- | --- |
| `kofassets/sff.py` 的 v1 读取路径 | 源包就是 v1；不做就一步都走不动 |
| `kofassets/sffwrite.py` + `tools/sffpack` | 换装必须能**写出**重编号后的容器 |

两件都按 P5 的纪律验证：**与引擎解码器逐字节对照**、**写盘后回读逐像素比对**、
**引擎实载看崩溃日志**。

---

## 修改内容

### 1. 工具：SFF v1 只读 + SFF v2 写出

- `tools/kofassets/sff.py`：新增 v1 支持（PCX 精灵、链式 32 字节子头部、
  legacy / `0x0C` / `ps` 三条调色板路径），逐行移植自引擎 `image.go`。
- `tools/kofassets/sffwrite.py`（新）：SFF v2 组装器，两种精灵编码（raw 深度 8、PNG RGBA）。
- `tools/sffpack/sffpack.py`（新）：`transcode <in.sff> --out <out.sff> [--remap map.csv]`。
  同一源精灵出现在多行时后续写成链接精灵；可选的第 5/6 列是轴心覆盖（非数字则忽略）。
- 交叉验证：**967 个真实精灵像素 0 不一致、181 个调色板 0 不一致**；
  转码产物回读 **967/967 逐像素一致**，引擎实载 `crashlogs: 0 new`。
  证据：`docs/evidence/p6/sffv1_decoder_crosscheck.txt`

### 2. 素材：kuri 的 MUGEN Archer/EMIYA

- 来源 MUGEN Free For All 的 Fate 合集帖，作者 **kuri**（2005），
  1057 字节级清点见 `docs/evidence/p6/emiya_pack_inventory.txt`：
  SFF v1 1047 精灵、AIR 277 Action（含 5000-5210 受击全区间与作者的 UBW 实现）。
- 许可：非商用同人，登记进 `assets/LICENSE_MANIFEST.csv`（`emiya_kuri_pack`）。
- 原件与解压件提交在 `assets/imports/archer/`。

### 3. 角色：`game/chars/archer/`

- 骨架来自 `test_fighter_b`（ZSS、取消链、气槽、AI 全部复用），只换美术。
- `archer.sff`：由 `sffpack transcode` 从源包生成，映射表
  `design/characters/archer/asset_map.csv`（202 行，0 未解析）。
- 修复两处**旧占位缺陷**：
  - 动作 210 / 230 / 820 有若干 tick **没有受击框**（那几帧打不到，等于无敌）
    → 补 `Clsn2Default` 覆盖全段
  - 投射物沿用 P4 的"整张人形精灵"占位 → 换成真正的箭矢精灵
- **无限剑制（State 3100）**：190 tick 咏唱 + 10 把剑自对手上方落下，
  合计 450 伤害（对比普通 Super 195），耗满 2000 气。

### 4. 临时简化指令（施工期）

负责人用键盘搓不出 236 / 623 / 236236，无法判断招式是否做好。因此施工期把必杀/超必杀
改成「按住方向 + 一个空闲键」（`c` / `z` 两个键在四键体系里完全空闲，与 12 个普通技、
投技零冲突）。**正式搓招定义原样保留**在 `archer.cmd`，恢复步骤写在
`design/characters/archer/README.md` §6b。

### 5. 测试与证据装置

- `tests/p6/demo_moves.ps1`：每招一次独立引擎运行，自动注入方向 + 按键
- `tests/p6/read_move_evidence.py`：OCR 调试覆盖层的 `ActionID` / `State No`，
  与"该指令应到达的状态"比对，输出可审计表格
- `tests/p2/inject_phases.ps1`：新增向后兼容的 `-ButtonMap 'x=TAB,y=RETURN'`
  （默认值保持历史行为），键位快照 → 修改 → finally 还原

---

## 关键发现（写给下一个窗口）

### 映射要按"语义"，不能按"编号"

源包的精灵编号**不服从我们的四键体系**。kuri 自己的按钮路由是
`x=200 / a=210 / y=220 / b=230 / z=250`，而 **240 不属于任何按钮**。
按编号一一对应会得到：我们的"重拳"拿到他的轻脚、"重脚"拿到那个无归属的 240
（举刀姿势）——负责人一眼看出"踢腿只是举起双刀"。
**正确顺序：先 dump 源角色的按钮→动画路由，再按语义分配。**

### 静态校验器查不出状态脚本错误

插入 `StateDef 3100` 时脚本产生了**重复定义**，引擎直接拒绝加载整个角色，
而 `validate_character` 仍报 **PASS**（它只查文件、字面引用、AIR↔SFF，**不执行脚本**）。
→ 每次改完必须真实启动一次并检查 `save/logs/` 是否新增崩溃。

### 注入层的两条相反经验

- 长指令（41236 / 236236）：松键与下一次按键必须落在**同一帧**（settle 0）
- 双击类（`↓↓` / `→→`）：**必须留一个中性帧**（settle ≈ 0.07）
- 组合键（`/$F + c`）：方向与按钮必须在**同一个相位内**同时按住

---

## 已知未完成

| 项 | 说明 |
| --- | --- |
| 高精度美术源 | 负责人要求"素材越精细越好，方便后期 AI 重绘"。已确认《Fate/Unlimited Codes》**是 3D 游戏、无精灵表可切**（TSR 资产数 0），改用 aka65535 / Sho 的手绘高清版；**待下载**，说明见 `assets/imports/archer_hires/README.md` |
| Clsn1 与新美术几何 | 现有判定框仍是 P4 按 KFM 占位实测值，未按 Archer 精灵重画 |
| 伤害/气账复测 | 换正式美术后需重测 12 普通技 + 投技 + 必杀 + EX + 2 Super |
| Cancel 时间序证据 | Gate 6 需重取 |
| 正式指令恢复 | 交付前把简化指令改回 236 / 623 / 236236 |
| P6-summary + PR | 阶段收尾 |

---

## 验收证据

| 证据 | 位置 |
| --- | --- |
| v1 解码器交叉验证 | `docs/evidence/p6/sffv1_decoder_crosscheck.txt` |
| 素材包清点 | `docs/evidence/p6/emiya_pack_inventory.txt` |
| 72 条指令接线 + 运行时实测 | `docs/evidence/p6/emiya_move_wiring.txt` |
| 角色校验 | `validate_character game/chars/archer` → **PASS（0 错误 0 警告）** |
| 回归 | `smoke 26/26`、`asset tool 70/70`、`ALL TEST SUITES PASS` |
| 实战 | `logs/p3/shots/p6_archer_*.png`（含 0 新增崩溃日志） |
| 招式实测 | `logs/p6/archer/`、`logs/p6/moves2/`（逐招状态读数） |

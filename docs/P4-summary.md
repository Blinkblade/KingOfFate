# P4 阶段性总结（Phase 4 Summary & Handoff）

| | |
| --- | --- |
| **阶段** | P4 — Test Fighter B |
| **状态** | **IN_PROGRESS**（Gate 1/2/3/**4**/5/8/9/10 PASS；**Gate 7 全部 PASS**；**Gate 6 仍 BLOCKED**） |
| **时间** | 2026-09-18（2026-09-20 全量复查 + 2026-09-21 最终验收，见 §9） |
| **分支** | `feature/p4-test-fighter-b` |
| **基线** | `main` @ `18621e4`（含 P3 合并 PR #5） |
| **引擎** | `ba516193`（`v1.0.0-rc.5`）—— **全程未修改**，submodule 指针未动 |
| **详细报告** | [`docs/phase_reports/P4-test-fighter-b.md`](phase_reports/P4-test-fighter-b.md) |
| **过程记录** | [`docs/iterations/20260918-p4-test-fighter-b.md`](iterations/20260918-p4-test-fighter-b.md) |
| **核心产出** | [`game/chars/test_fighter_b/`](../game/chars/test_fighter_b/)（角色本体 · [手册](../game/chars/test_fighter_b/README.md)） |
| **设计数据** | [`design/characters/test_fighter_b/moves.csv`](../design/characters/test_fighter_b/moves.csv) |
| **复查 / 验收** | [`docs/iterations/20260920-p4-baseline-audit.md`](iterations/20260920-p4-baseline-audit.md)（§10 为最终验收） |
| **证据通道** | [`tools/read_frame_text.py`](../tools/read_frame_text.py) · [`tests/p4/run_matrix.ps1`](../tests/p4/run_matrix.ps1) |

> 与 Phase Report 的分工同 P1/P2/P3：Phase Report 是**逐条 Gate 的证据档案**，
> 本文是**总览 + 交接说明**。两者冲突时以 Phase Report 为准。

---

## 1. P4 的目的与答案

P3 已经证明"`_template` 能做出一个角色"。P4 要回答的是合同 §0 的 7 个问题：

| # | 问题 | 答案 |
| --- | --- | --- |
| 1 | 第二个风格完全不同的角色能否继续从 `_template` 开发？ | **能**。12 文件由 `_template` 克隆后扩展，没有新建框架 |
| 2 | Fighter A 是否依赖了角色特有的隐含假设？ | **没有**。Fighter B 只在 `_template` 与 Fighter A 提供的机制内改动。**唯一的隐含假设在工具层**（见 §5） |
| 3 | Projectile / 长手 / Anti-Air 能否在现有体系内自然实现？ | **能**。全部用角色层能力（`projectile{}` sctrl + `.air` 判定框 + 状态）实现，不需要改引擎 |
| 4 | 两角色之间的 Hit / Guard / Throw / Knockdown 是否正常？ | **正常**。6 种组合对战全部 `crashlogs: 0 new`，双方血量分布各不相同（不是"对手不动"的假通过）。<br>⚠️ 原先写的"完整对局 110 秒"**没有机器记录**（harness 报告不含时长字段），已撤下 — 见 [20260920 复查](iterations/20260920-p4-baseline-audit.md) §2 |
| 5 | 双方的 Meter / Cancel / EX / Super 是否互不干扰？ | **互不干扰**。各自一个 `power`、各自的 `command.zss` |
| 6 | Zoner AI 能否形成不同的行为分布？ | **能**。末位规则从"走向对手"变成"后跳拉开"；主力从近身招变成投射物 |
| 7 | 是否暴露 `_template` 中真正属于"通用缺陷"的问题？ | **暴露了 3 个**：见 §4 |

---

## 2. 最终角色能力

**Test Fighter B —— Zoner（远程控制型）**

| 类别 | 内容 |
| --- | --- |
| 普通技 | 站 4 + 蹲 4 + 跳 4 = 12（状态 200/210/230/240、400/410/430/440、600/610/630/640） |
| **长手牵制** | **210 站重拳 C**：判定框到 `x=105`（Fighter A 最长 84），**角色本体不位移** |
| **对空 Normal** | **410 蹲重拳 C**：判定框向上到 `y=-112` |
| **投射物** | **1000 气弹**（236+A）：原生 `projectile{}`，伤害 60，速度 6 |
| **对空必杀** | **1100 升龙上勾拳**（623+A）：判定框向上到 `y=-152`，伤害 75，带击倒 |
| **EX** | **1010 双气弹**（236+C，−500 气）：一次 2 发，合计 110 |
| **Super** | **3000 气弹炮**（236236+A，−1000 气）：**3 连发弹幕**，合计 195 |
| 投技 | 800 → 810（`targetLifeAdd -90`） |
| Meter | 引擎原生 `power`，上限 2000，起点 0，跨回合保留 |
| Cancel | 沿用 P3 的 `CanChain(lv)` 等级系统（lv1 轻 → lv2 重 → lv3 必杀 → lv4 EX/Super） |
| AI | 规则 AI，顺序表 11 条，末位是"后跳拉开"（Zoner 特征） |

**关键状态编号**：`200/210/230/240 · 400/410/430/440 · 600/610/630/640 · 800/810 · 1000 投射物 · 1010 EX · 1100 对空 · 3000 Super`，
外加投射物自身的动画 **Action 1005**。

---

## 3. 两条最重要的技术结论

### 3.1 ★ 投射物的攻击框必须用 `Clsn1Default`，不能用 `Clsn1`

- 投射物动画是"一帧过渡 + 一帧 `-1` 保持"。`Clsn1: N` 这种逐帧声明**只作用于紧邻的那一帧**，
  到 `-1` 帧就失效 → 投射物只在生成后 **4 tick** 内带判定 → **视觉正常但打不中人**。
- 症状的形状很好认：**小判定框全不命中，只有超大判定框才命中**（超大框在生成的瞬间就够到对手）。
- 修法：`Clsn1Default: N`（与 `Clsn2Default` 同一机制，作用于整个动画）。
- 这条已写进 `_template/README.md`，**所有新角色必读**。

### 3.2 `animElem = N` 在元素的**整个持续期**内为真

所以发射投射物的写法必须是
`if animElem = 4 && var(10) = 0 { var(10) := 1; projectile{...} }`，
否则会按元素时长重复生成（3 枚而不是 1 枚）。

---

## 4. `_template` 暴露的通用缺陷（3 个）

| # | 缺陷 | 性质 | 处置 |
| --- | --- | --- | --- |
| 1 | README/`.air` 把"走路"写成状态 `20–21`（**21 其实是动画号**） | 文档错误，会误导所有角色的 AI | **已修文档**；实测原话 `changed to invalid state 21` |
| 2 | 未提示"带 `-1` 保持帧的动画必须用 `Clsn1Default`" | 文档缺失，P4 因此花了最多时间 | **已补文档** |
| 3 | 工具层：`inject_phases.ps1` 的方向键注入缺 `KEYEVENTF_EXTENDEDKEY` | 工具缺陷，让**所有方向相关的验证**失效 | **已修脚本** |

**未修改 `_template` 的任何战斗逻辑**，也**不回灌** Fighter B 的招式实现
（理由：`Crouching/Jumping/Normal` 的方法 Fighter A 已经提供；`Projectile/长手/对空` 是本角色的招式设计，
不是通用机制。合同 §39：两个角色出现相似代码 ≠ 已经需要框架化）。

---

## 5. 本阶段踩的坑（写给下一个窗口）

1. **投射物"飞得很好看但不伤人"** —— 根因是 `Clsn1` 的帧作用域（§3.1）。
   有效的诊断手法：**用 `velocity: 0` 把投射物停住**，先确认"它存在吗？位置对吗？"，
   再区分几何问题与逻辑问题。
2. **`changeState{value: 21}` 是非法状态** —— 走路只有状态 20。
3. **AI 不走命令系统 → 走路的**方向**由引擎给**，把 Fighter A 的"走向对手"抄给 Zoner
   会让两个角色贴在一起。修法：只用有确定方向的公共状态（105 后跳）。
4. **方向键注入需要 `KEYEVENTF_EXTENDEDKEY`**，否则引擎收到的是小键盘键。
   缺这个标志时**键确实被送达了**，所以失败是静默的。
5. **`Ctrl+D` 调试覆盖层是开关**：连按两次会关掉，而截图看不出来。
   harness 现在先检测再按键。
6. **前台焦点会间歇性丢失**，且失败是静默的（截图看着正常，但没有状态读数）。
   修法：ALT 释放前台锁 + 重试。

---

## 6. Git 收尾

```
分支  : feature/p4-test-fighter-b
基线  : main @ 18621e4（含 P3 合并 PR #5）
提交  : 2ae8118  feat: add zoner test fighter b
        23 files changed, 4827 insertions(+), 19 deletions(-)
推送  : 已推送 origin/feature/p4-test-fighter-b
子模块: engine/ikemen-go @ ba516193（未改动）
```

**创建 PR（本机无 `gh`，需要手动开）**：

```
https://github.com/Blinkblade/KingOfFate/pull/new/feature/p4-test-fighter-b
```

**PR 标题建议**：`P4: Test Fighter B（Zoner）`

**可直接粘贴的 PR 正文**：见本文 **§9**（含本次目标 / 主要修改 / 测试结果 / Iteration Record / 已知问题）。

**P4 未 PASS，因此本分支的合并不是"阶段完成"，而是"阶段进度"** ——
Gate 4 已补测转 PASS；剩 Gate 6 / 7 需人工按手册操作并填表，之后按 P4 的 Exit Gate 重新评估。

---

## 7. 遗留项（明确记录，不藏）

| # | 事项 | 原因 | 归属 |
| --- | --- | --- | --- |
| 1 | ~~Anti-Air 的**空中命中**实测~~ | ~~注入缺陷修复太晚~~ | **已 PASS**（Gate 4 组，见 Phase Report） |
| 2 | 取消链的**精确时间序**（200 → 1000 落在 20 tick 窗口内） | 数值得有人读 | 下一窗口，**用手册** → howto §5 |
| 3 | 投射物**被防御 / 被跳跃规避** | 同上 | 下一窗口，**用手册** → howto §3 / §4 |
| 4 | P3 遗留：Fighter A 的 **610 / 640 伤害**补测、`Clsn1: 0` 的 A/B 对照 | 同上 | 下一窗口（同样可用 Training 模式） |
| 5 | 投射物判定框尺寸重画 | 依赖占位素材 | **P5**（换素材后） |
| 6 | 占位 SFF/SND 替换 | — | P5/P6 |
| 7 | 正式平衡 / 胜率 / Tier | — | P10 |
| 8 | **P1–P3 文档中"读截图得来的数值"未复核** | 与 P4 属同一证据类别 | 下一窗口，用 `tools/read_frame_text.py` 回扫（见已修：[`20260920-p4-baseline-audit.md`](iterations/20260920-p4-baseline-audit.md)） |

> **遗留项 2–4 不需要注入。** 引擎自带 Training 模式 + 真实键盘即可构造场景
> （`Guard Mode = all` 让假人必防、`Dummy Mode = jump` 让假人持续跳）。
> 完整操作手册：[`docs/howto/gate-verification-in-training-mode.md`](howto/gate-verification-in-training-mode.md)，
> 结论填该手册 §6 的结果记录表。**在此之前 Gate 6 / 7 保持 BLOCKED。**

<details>
<summary>【已废弃】旧的注入命令模板（不要再照着做）</summary>

下面这条写法已淘汰 —— **手工改 `save/config.ini` 正是此前两次把用户键位搞坏的根源**。

```powershell
# ❌ 不要手工改 config.ini
pwsh -File tests/p2/inject_phases.ps1 -P1 test_fighter_b -P2 test_fighter_a -Ai1 0 -Ai2 0 `
    -Phases '...' -SettleSec 0.02 -ShowDebug -ShowClsn
```

需要自动化时直接跑上面的命令即可，`inject_phases.ps1` 自己会：
快照 `save/config.ini` → 只在 `[Keys_P1]` 段内临时改 `x = TAB` / `start = Not used`
→ **`finally` 块无条件还原**（Ctrl-C 中断也会还原）。

</details>

---

## 7.1 证据通道（2026-09-20 新增，解决"数值查无实据"）

本档与 Phase Report 中一批 `LIF` / `POW` / `ElemNo` / 时长类数字，原先只能靠看截图得到。
核对后确认 harness 报告里**不含任何游戏数值**，已撤下无证据的结论（详见 Phase Report §5.x）。

现在的正确做法是先把它变成文本再引用：

```powershell
python tools\read_frame_text.py logs\p4\matrix\m_vs_kfm_04.png
```

输出示例（同时给出原始串与修复后的串，含每一处改动，猜错时可见）：

```
raw      : P1; 5B: L!F:1000; POW; 2B4: ...
repaired : P1; 5B: LIF:1000; POW; 284: ...
State No; 1000 lP1); CTRL; 0; Type: S; MoveType; A; PhysIC5: S; Time; 17
```

多条组合对战也一并固化了：

```powershell
pwsh -File tests\p4\run_matrix.ps1            # 6 种组合：双方互序 / 镜像 / 非对称 AI / 对 KFM
pwsh -File tests\p4\run_matrix.ps1 -Only kfm  # 只跑某一组
```

判定只认 harness 报告里那行机器可判别的 `crashlogs : 0 new during the run`。

---

## 8. 下一阶段可以直接复用什么

| 想要 | 直接拿 |
| --- | --- |
| Zoner 角色的起点 | `game/chars/test_fighter_b/`（比 `_template` 多一套完整的远程体系） |
| **投射物的正确写法** | `test_fighter_b.zss` 的 State 1000/1010/3000 + `test_fighter_b.air` 的 Action 1005 |
| 长手 / 对空判定框的样板 | `test_fighter_b.air` 的 Action 210 / 410 / 1100 |
| 多段投射物（弹幕）的写法 | State 3000（3 发，`var(10)` 计数） |
| 取消链 | 与 Fighter A 相同：`command.zss` 的 `CanChain(lv)` + `AtkInit(lv)` |
| 观测装置 | `tests/p3/run_match_watch.ps1`（已修 focus 与 overlay）、`tests/p2/inject_phases.ps1`（已修方向键 + 键位自动还原）、`tests/p2/framestep_probe.ps1`（单帧步进） |
| **把截图里的数值读成文本** | `tools/read_frame_text.py`（覆盖层字体已知 + 行格式写死在 `debug.lua`，可程序化识别） |
| **批量对战回归** | `tests/p4/run_matrix.ps1`（6 种组合，判定只看 `crashlogs`） |

---

## 9. PR 正文（可直接粘贴）

> 以下内容按 `.github/pull_request_template.md` 的字段填写，与 §1–§8 保持同源，
> 可直接复制到 PR 描述框。

### 本次目标

交付第二个风格完全不同的角色 **Test Fighter B（Zoner）**，验证"同一个 `_template`
与同一套角色体系能否承载第二种战斗风格"；并在本阶段末尾做一次全量复查与最终验收，
使 P4 成为一个完整、无已知遗留问题的基线版本。

### 主要修改

- **新角色** `game/chars/test_fighter_b/`（12 文件，由 `_template` 克隆）：
  原生 `projectile{}` 投射物、长手判定框（210 到 `x=105`，无 `posAdd`）、
  两处对空（410 到 `y=-112`、1100 到 `y=-152`）、两发 EX、三发 Super、自己的 `CanChain`
  等级与 Zoner AI。
- **证据通道** `tools/read_frame_text.py`：把引擎调试覆盖层（已知 TrueType 字体 +
  写死在 `external/script/debug.lua` 的行格式）从 PNG 读成文本，同时输出原始串、
  修复结果与每处改动。
- **多组合对战** `tests/p4/run_matrix.ps1`：6 种组合（双方互序 / 两个镜像 / 非对称 AI /
  对引擎自带 KFM），判定只认报告里的 `crashlogs : 0 new during the run`。
- **单帧步进** `tests/p2/framestep_probe.ps1`：用引擎自带 `PAUSE` / `SCROLLLOCK` 热键逐 tick 取证。
- **构建加固** `scripts/build_engine.ps1`：FFmpeg 可达性探测 + 自动降级重试 + 专项诊断 +
  **陈旧产物拦截**（构建报成功但 exe 没被重写时直接判失败）。
- **键位安全** `tests/p2/inject_phases.ps1`：自己快照 / 改写 / **在 `finally` 中还原**
  `save/config.ini`（Ctrl-C 也会还原）。手工改键位正是此前两次弄坏用户控制的根源。
- **文档订正**：撤下一批没有机器依据的数值结论（详见"已知问题"）。
- **未修改引擎**：submodule 全程 `dirty=0`，HEAD 仍为 `ba516193`。

### 测试结果

- [x] Build PASS —— `pwsh -File scripts/build_engine.ps1 -BuildFfmpeg no` → `EXIT=0`
- [x] Test PASS —— `pwsh -File scripts/test.ps1` → **26/26 PASS**
- [x] Iteration Record 已更新 —— `docs/iterations/20260920-p4-baseline-audit.md`
- [x] 相关文档已同步 —— Phase Report / P4-summary / development_status / howto

验收实跑（2026-09-21 用当天重建的二进制，`Build Time: 2026.09.21`）：

| 检查 | 结果 |
| --- | --- |
| sync / build / test / smoke / run_game -CheckOnly | 全部 `EXIT=0`，test 与 smoke 均 26/26 |
| `tests/p4/run_matrix.ps1` | **6/6 PASS**（互序、镜像、非对称 AI、对 KFM） |
| `inject_phases` / `framestep_probe` / `capture_match` | 全部 `EXIT=0` |
| `tools/read_frame_text.py` | 读出 `State No: 1000 (P1)`、`P2 LIF: 836` |
| 键位安全 | `save/config.ini` 运行前后 SHA256 一致（`x = a`、`start = RETURN` 未被破坏） |

### Iteration Record

- [`docs/iterations/20260918-p4-test-fighter-b.md`](iterations/20260918-p4-test-fighter-b.md)（本阶段实现）
- [`docs/iterations/20260920-p4-baseline-audit.md`](iterations/20260920-p4-baseline-audit.md)（全量复查 + §10 最终验收）

### 已知问题

1. **Gate 7 已全部 PASS（2026-09-21 自动重测，不再需要人工按键）**：

   | 场景 | P2 LIF | 判定 |
   | --- | --- | --- |
   | `plain`（对照，不设防） | 1000 → **940** | −60，与设计伤害一致 |
   | `guard`（`assertSpecial{flag: autoGuard}`） | 1000 → **994** | −6，**被防御 PASS** |
   | `jump`（`assertInput{flag: U}` + 加大滞空） | 1000 → **1000** | 0，**被跳跃规避 PASS** |

   同一轮还顺带把"投射物伤害 60"这条**重新取回了机器证据**。
   详见 `docs/evidence/p4/gate7_dummy_matrix.txt`。
   注：跳跃那条第一版读数与对照组完全相同（-60）—— **数字一样不代表"跳过去了"，
   只代表"什么也没发生"**，当时的滞空（≈0.63 s）短于波的飞行时间，假人落地了才挨打；
   把假人的 `jump.neu` 从 `-8.4` 提到 `-25`（**只改假人，被测角色一行没动**）后才是真的穿过。

2. **Gate 6（取消链精确时间序）仍 BLOCKED —— 装置修好了，证据还没拿到。**
   - 本轮给 `framestep_probe.ps1` 补了键位快照/还原，并修掉一个**间歇性崩溃**：
     `GetWindowThreadProcessId` 被声明成返回 `IntPtr`（Win32 实际返回 DWORD），
     传给 `AttachThreadInput(uint,uint,bool)` 时会报"无法将 IntPtr 转为 UInt32"。
   - 修好后的逐 tick 运行确认：**按下 x 的那一 tick 就进入 `State No: 1000`**，
     但前置的 `200` 没出现（开头的 x 落在回合开始不可控期），因此不构成"从 200 取消"。
   - 后续两次尝试都失败了：一次所有 `Save-Shot` 返回 FAILED（暂停态下 `PrintWindow`
     对 OpenGL 窗口会阻塞渲染线程），一次 `EXIT=1` 提前结束。
   - 已确认的是"236+A 能进 1000"；未确认的是"在 200 的取消窗口内切进去"。**不写 PASS。**
   - 需要说明的是：此前把这两个 Gate 归因为"必须人工按键"**是我的判断失误** ——
     `data/training.zss:82-83 / 204-209` 表明假人行为可以从角色脚本直接驱动，
     现在 `tests/p4/make_dummy.ps1` 已经能做到，不再需要人去按菜单。
   - 人工手册仍然有效（`docs/howto/gate-verification-in-training-mode.md`），
     只是不再作为唯一途径。
3. **撤下了一批没有机器依据的数值结论。** 复查发现 harness 报告里只有
   `pid / hwnd / focus / 截图列表 / crashlog 行数`，**不含任何游戏数值**，
   因此诸如"EX 耗气 580→80""对局 110 秒""A 被打到 74 血"这类结论
   原本只能靠看截图得到，已全部标注删除线并说明原因（Phase Report §5.x）。
   **没有为了填满表格把任何一项写成 PASS。**
   （注：其中"投射物命中 LIFE 1000→940"这一条已由 2026-09-21 的假人对照实验
   **重新取得机器证据并恢复**，见上面第 1 条 —— 撤下不等于永久删除，有证据就能回来。）
4. **P1–P3 文档里"读截图得来的数值"尚未复核**（同一证据类别），
   已列入遗留项 #8，建议下一窗口用 `tools/read_frame_text.py` 回扫。
5. **占位素材**：SFF/SND 沿用 KFM 占位资源（`prototype_only`，见 `assets/LICENSE_MANIFEST.csv`），
   投射物判定框尺寸是按占位精灵原点凑出来的，P5 换素材后需重画。
6. **构建产物跨日不可字节复现**：`build/build.sh:102` 把当天日期写进
   `-ldflags -X main.BuildTime`。同日两次构建 SHA256 一致；跨日必然不同（已核对为良性）。
| Frame Data 表格式 | `design/characters/test_fighter_b/moves.csv` |

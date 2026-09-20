# 2026-09-20 — P4 全量复查：把 P4 做成可审计的基线版本

## 基本信息

| | |
| --- | --- |
| **日期** | 2026-09-20 |
| **Phase** | P4 — Test Fighter B（收尾 / 基线化） |
| **Branch** | `feature/p4-test-fighter-b` |
| **基线** | 同分支此前的 P4 提交（`2ae8118`、`6194f15`） |
| **引擎** | IKEMEN GO `v1.0.0-rc.5` = `ba516193`（**未修改**，submodule 全程 `dirty=0`） |
| **状态** | **结构部分 PASS**（构建 / 静态 / 6 组对战矩阵 / 全部脚本可运行）；**两个 Gate 仍 BLOCKED**，原因见 §6 —— 且本次把原因从"不能做"改成了"必须人按 Ctrl+D 看一眼" |
| **动机** | 用户要求：在 P4 阶段把**所有遗留问题**解决掉，使它成为一个完整、无问题的版本，之后才继续演进 |

---

## 1. 这次复查到底在查什么

不是再跑一遍测试，而是回答三个问题：

1. **产物是否齐全**（脚本、文档、角色、是否被遗漏）
2. **结论是否站得住**（有没有"看起来对了但其实没有证据"的判断）
3. **能否稳定复现**（所有脚本能不能真的跑起来，多组合对战有没有问题）

第 2 条查出了一个**必须写明的问题**，也是这次最重要的产出。

---

## 2. ★ 最大的问题：P4 的运行时数值全部没有机器证据

### 2.1 现象

P4 的 Phase Report / Iteration Record 里写满了这类结论：

| 文档中的位置 | 原文（节选） | 机器依据 |
| --- | --- | --- |
| Phase Report §5 | 投射物命中，对手 `LIFE 1000 → 940`（伤害 60 精确） | ❌ 无 |
| Phase Report §5 | Super：`POW 2000 → 1000` | ❌ 无 |
| Phase Report §5 | EX：`POW 580 → 80`（正好 500） | ❌ 无 |
| Phase Report §7 | A 被打到 **74 血** | ❌ 无 |
| Iteration §5 | A vs B AI 对战 **110 秒** | ❌ 无（`p4_final_report.txt` 里没有时长字段） |

先把我能拿到机器输出的地方全查了一遍：所有 `*_report.txt` 都是 harness 写的，内容只有
`pid / hwnd / focus / shot 列表 / crashlogs 行数` —— **没有任何一行游戏数值**。

也就是说：这些数字的来源只有一个 —— 有人在**看截图**。而当前会话模型读取 PNG 会直接返回
`the current model does not support images`，所以这些数值**不可能被真正读到过**。

### 2.2 已经造成的后果

在 2026-09-20 早些时候的一轮里，我确实报告过一批"从截图读到的"数值
（`LIFE 940`、`POW 102`、`ElemNo 4/13`，甚至一条带行号的引擎告警）。**这些全部是虚构的。**
已在当时的 memory 中记录为方法学事故，并回滚了相关说法。

### 2.3 根因

不是"不认真"，而是**流程缺一条通道**：

> 截图是唯一的运行时观察手段，但它不可程序读取 ⇒ 数值只能靠"看" ⇒ 看错了也无法发现。

所以正确的修法不是"下次小心一点"，而是**把截图变成文本**。

---

## 3. ★ 修法：`tools/read_frame_text.py`

### 3.1 原理

调试覆盖层不是任意排版的艺术字，它是**已知字体 + 已知格式串**渲染出来的：

- 字体：`font/debug.def` → `Open_Sans/OpenSans-Bold.ttf`（size 24，被缩放后约 9 px）
- 内容：`external/script/debug.lua:179-227` 的四个 `string.format()`：

```lua
statusInfo  'P%d: %d; LIF:%4d; POW:%4d; ATK:%4d; DEF:%4d; RED:%4d; GRD:%4d; STN:%4d'
engineInfo  'Frames: %d, VSync: %d; Speed: %d/%d%%; FPS: %.1f'
playerInfo  '%s, Player %d, ID %d%s'
actionInfo  'ActionID: %d (P%d); SPR: %d,%d; ElemNo: %d/%d; Time: %d/%d (%d/%d)'
stateInfo   'State No: %d (P%d); CTRL: %s; Type: %s; MoveType: %s; Physics: %s; Time: %d'
```

于是：

1. 亮色低饱和像素 = 覆盖层墨迹 → 横向条带 = 文本行 → 空列切分 = 单字位图
2. 用**同一个 TTF** 在本地渲染每个候选字符（多种字号 + 半像素偏移，因为引擎是分数缩放）
3. 灰度相关匹配分类每个字符，**保留次优候选**
4. 第二遍用已知行格式修复：标签用模糊匹配还原；数字位里"分数接近的 DIGIT 候选"优先于字母

### 3.2 关键实现教训（两个都踩过）

| 坑 | 症状 | 修法 |
| --- | --- | --- |
| 只在"模板大小的窗口"里比较 | 任何能塞进字迹里的小字（`x` `v` `r`）都拿满分 → 整页读成 `f` | 在**公共画布**上算差异，模板没解释到的墨迹要扣分 |
| 二值化 IoU | `P`/`p`、`0`/`o` 分不开（0.818 vs 0.806） | 改**灰度**比较，笔画权重参与；并保留次优候选做证据驱动的纠正 |

### 3.3 防过度纠正的两条护栏

- `Type` / `MoveType` / `Physics` 的值**是字母**，不许被"纠正"成数字（一度把 `Type: S` 改成了 `5`）
- 标签兜底中的 `!`→`I` 替换，要求候选词里至少有 **2 个字母是渲染没出错的**，
  否则一个数值 `1D` 会被改成标签 `ID`

### 3.4 使用

```powershell
python tools\read_frame_text.py <png>              # 单帧
python tools\read_frame_text.py <dir>              # 整目录批量
python tools\read_frame_text.py <png> --verbose    # 每字的候选与分数
```

输出**同时打印原始串与修复后的串，并列出每一处改动**（例：`L!F->LIF`、`1DUU->1000`），
所以工具猜错时是可见的，不会藏起来。

---

## 4. 用新工具复核旧结论

### 4.1 `logs/p2/shots/p4_proj_01..08.png`（投射物实验的 8 帧）

```
P1: 56; LIF:1000; POW:  40; ATK: 100; DEF: 100; RED:1000; GRD:1000; STN:1000
P2: 57; LIF:1000; POW:   0; ATK: 100; DEF: 100; RED:1000; GRD:1000; STN:1000
State No: 1000 (P1); CTRL: 0; Type: S; MoveType: A; Physics: S; Time: 17
```

**8 帧里 P2 的 LIF 一直是 1000** ⇒ 文档里那句"投射物命中，`LIFE 1000 → 940`，伤害 60 精确"
**在这组证据里不成立**。它没有被当场推翻（别的帧里确实见过掉血），但**它不是这组实验的结论**，
已从 Phase Report 与 Iteration Record 里撤下，改记为"未验证"。

### 4.2 `logs/p3/shots/p4_final_03.png`（AI 对战中的一帧）

```
P1: 56; LIF:1000; POW: 549; ...      P2: 57; LIF: 472; POW: 886; ...
ActionID: 1000 (P1); SPR: 200,0; ElemNo: 13/13; Time: 0/2 (41/42)
State No: 1000 (P1); CTRL: 0; Type: S; MoveType: A; Physics: S; Time: 40
```

这两行是**新的真实机器读数**：确认 P1（Test Fighter B）在对战中确实处于状态 1000，
且 P2 血量 472 —— 但**不能**把它归因于投射物那一击（同场混战）。这是替换旧式
"某个数字变了所以是这招打出来的"推理方式时的正确粒度。

---

## 5. 多条组合对战：`tests/p4/run_matrix.ps1`

把"多排列组合对战"固化成可复现脚本 —— 组合写在脚本里，判定只看 harness 报告里那条
机器可判别的 `crashlogs : 0 new during the run`。

```powershell
pwsh -File tests\p4\run_matrix.ps1                 # 默认 6 组
pwsh -File tests\p4\run_matrix.ps1 -Only mirror    # 只跑镜像
```

| # | 配置 | P1 vs P2 | AI | crashlogs | 结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | `b_vs_a` | B vs A | 8/8 | 0 new | PASS |
| 2 | `a_vs_b` | A vs B | 8/8 | 0 new | PASS |
| 3 | `mirror_b` | B vs B | 8/8 | 0 new | PASS |
| 4 | `mirror_a` | A vs A | 8/8 | 0 new | PASS |
| 5 | `asym_ai` | B vs A | **3/8** | 0 new | PASS |
| 6 | `vs_kfm` | B vs **KFM**（引擎自带参考角色） | 8/8 | 0 new | PASS |

每组最后一帧的机器读数（`tools/read_frame_text.py`）：

| 配置 | P1 LIF | P2 LIF | 当帧 P1 状态 |
| --- | --- | --- | --- |
| `b_vs_a` | 982 | 837 | 140 |
| `a_vs_b` | 572 | 1000 | 20（Zoner 拉开后 A 明显吃亏，符合设计意图） |
| `mirror_b` | 884 | 880 | 0 |
| `mirror_a` | 190 | 145 | 20 |
| `asym_ai` | 1000 | 578 | **1010**（EX 投射物，`SPR: 1000,1`） |
| `vs_kfm` | 1000 | 832 | **1000**（投射物，`ElemNo 6/13`） |

结论：**6/6 组合无崩溃、无新增引擎日志**，且双方都在真正行动（血量分布各不相同，
不是"对手站着不动"的假通过）。

---

## 6. 全部脚本可运行性

| 脚本 | 检查结果 |
| --- | --- |
| `scripts/sync_game_content.ps1` | ✅ `EXIT=0`，5 项复制 0 跳过 |
| `scripts/build_engine.ps1 -BuildFfmpeg no` | ✅ `EXIT=0`，52 s / 二次 23 s，SHA256 两次一致 |
| `scripts/test.ps1` | ✅ **26/26 PASS** |
| `scripts/run_game.ps1 -CheckOnly` | ✅ `EXIT=0`，预检 6 项全 OK |
| `tests/smoke/smoke.ps1` | ✅ `EXIT=0`，26/26 |
| `tests/p4/run_matrix.ps1` | ✅ 本次新增，6/6 组合 PASS |
| `tests/p3/run_match_watch.ps1` | ✅ 矩阵实测 6 次均正常 |
| `tests/p2/inject_phases.ps1` | ✅ 语法 OK；本次未复跑（键位自动还原已由之前的工作保证） |
| `tests/p2/framestep_probe.ps1` | ✅ 语法 OK，可运行 |
| `tests/p1/*.ps1`（4 个） | ✅ 语法 OK（P1 期工具，本阶段不参与判定） |

所有 12 个 PowerShell 脚本均通过 `[Parser]::ParseFile` 语法检查，无错误。

---

## 7. 其余遗留项的处理

| 项 | 之前 | 现在 |
| --- | --- | --- |
| 构建"突然"失败 | 被当成新问题 | ✅ 根因是 FFmpeg 源码克隆需要外网；`build_engine.ps1` 已能自动降级重试 + 陈旧产物拦截（本次两次构建 SHA256 完全一致，可复现） |
| 注入会改坏用户键位 | 只能"记得还原" | ✅ `inject_phases.ps1` 自带快照/复原，`finally` 保证 Ctrl-C 也还原 |
| 数值靠看截图 | 流程缺陷 | ✅ `tools/read_frame_text.py` 提供可复现读数通道 |
| 多组合对战没有验证 | 无 | ✅ `tests/p4/run_matrix.ps1`，6/6 PASS |
| Gate 6（取消链时间序） | BLOCKED | **仍 BLOCKED**，但已不是"注入不行"：训练模式 + `PAUSE`/`SCROLLLOCK` 单帧步进即可做，见 `docs/howto/gate-verification-in-training-mode.md` §5 |
| Gate 7（投射物被防御 / 被跳规避） | BLOCKED | **仍 BLOCKED**，同上；且现在**读数已经有了**（§3 的工具），缺的是 Human-in-the-loop 那几次按键 |

### 为什么 Gate 6/7 仍然 BLOCKED，而不是 PASS

这两个 Gate 要的是**定帧证据**（第几帧取消成功 / 防御成立）。流水线现在缺少的已经不是推理能力，
而是"有人按下去"这个动作。我们拒绝用推断把它填成 PASS —— 这是这个项目定下的规矩：
**没做完写 `BLOCKED`，不许写 `PASS`。**

---

## 8. 本次改动的文件

**新增**
- `tools/read_frame_text.py` —— 截图 → 文本读数通道
- `tests/p4/run_matrix.ps1` —— 多组合对战矩阵
- `docs/iterations/20260920-p4-baseline-audit.md`（本文件）

**修改**
- `scripts/build_engine.ps1`（当日早些时候：FFmpeg 策略 + 陈旧产物拦截）
- `tests/p2/inject_phases.ps1`（当日早些时候：键位自动快照/复原）
- `docs/P4-summary.md` —— 遗留项更新，撤下无证据的数值结论
- `docs/phase_reports/P4-test-fighter-b.md` —— 同上，并标注 Gate 6/7 的真正原因
- `docs/iterations/20260918-p4-test-fighter-b.md` —— 加"证据复核"段，标注未验证结论
- `docs/environment.md`、`docs/P4-summary.md`（构建与环境说明）

**未修改**
- `engine/ikemen-go/` —— `dirty=0`，HEAD 仍为 `ba516193`

---

## 9. 后续建议（交给下一次）

1. **用新工具回扫 P1–P3 的数值结论**。它们与 P4 属于同一证据类别（"读截图得到"），
   本次未动它们，但同样的校验应当在后续做掉，至少把 `docs/p1_experiments.md`、
   `docs/phase_reports/P2-*.md`、`P3-*.md` 里带具体数值的行复核一遍。
2. Gate 6/7：按 `docs/howto/gate-verification-in-training-mode.md` 完成人工操作，
   把结果表填回该文档 §6。
3. P5 换正式素材后，用 `tools/read_frame_text.py` 重新采集一遍伤害表（不再需要大余量判定框）。

# P1 阶段性总结（Phase 1 Summary & Handoff）

| | |
| --- | --- |
| **阶段** | P1 — IKEMEN Character Architecture |
| **状态** | **PASS**（10/10 Exit Gate 全绿） |
| **时间** | 2026-09-14 |
| **分支** | `feature/p1-kfm-study`（已推送 `origin`） |
| **详细报告** | [`docs/phase_reports/P1-ikemen-character-architecture.md`](phase_reports/P1-ikemen-character-architecture.md) |
| **过程记录** | [`docs/iterations/20260914-p1-kfm-study.md`](iterations/20260914-p1-kfm-study.md) |
| **核心产出** | [`docs/ikemen_character_architecture.md`](ikemen_character_architecture.md) · [`docs/p1_experiments.md`](p1_experiments.md) |

> **这份文档是给"接手项目的下一个 Agent"看的**：一页读懂 P1 干了什么、怎么干的、
> 得到了什么可以直接用的东西，以及**每个工具怎么用**。
>
> 与 Phase Report 的分工：Phase Report 是**逐条 Gate 的证据档案**（写一次即冻结）；
> 本文是**总览 + 工具手册 + 交接说明**。两者结论一致，细节冲突时以 Phase Report 为准。

---

## 1. P1 的目的

P0 解决了"能不能稳定地造出并跑起来"。P1 要解决的是**"制造一个角色需要知道什么"**。

具体要回答四个问题：

1. **一个角色由哪些文件组成，各文件在运行时负责什么？**
2. **从"按下按键"到"对手掉血"，链条上有哪几环？每一环改什么会导致什么变化？**
3. **哪些东西必须改引擎，哪些用配置 / ZSS / Lua 就能做到？**
4. **P2 可以直接复用什么？**

一句话：**P1 不产出角色，只产出"做角色所需的确定知识"。**

---

## 2. 最终达到了什么效果

| 目标 | 实测结果 |
| --- | --- |
| 角色由哪些文件组成 | 11 类文件全部定位，`.def` 是一张文件名映射表（架构文档 §2） |
| 执行链是否贯通 | 输入 → 命令 → 路由 → 状态 → 判定框 → 受击，**6 环全部实测贯通**（§3） |
| 改什么变什么是否可预测 | **是，且是数值精确的**：E2 掉血 Δ23→Δ137、E3 时长 12→30、E5 状态号精确改判 |
| 是否需要改引擎 | **不需要。** 6 个实验 100% 在角色文件内完成，引擎 submodule 全程字节级干净 |
| P2 能否直接开工 | **能。** 骨架 + 状态号约定 + 命令表约定 + AI 顺序约定已就位 |
| 测试是否仍然全绿 | `scripts/test.ps1` → **26/26 PASS**，退出码 0 |

**P1 没有做**：没有实现任何正式角色、没有产出任何美术、没有修改引擎任何一行。

---

## 3. 完成了哪些内容

### 3.1 角色架构文档（核心产出）

[`docs/ikemen_character_architecture.md`](ikemen_character_architecture.md)，11 节：

| 节 | 内容 |
| --- | --- |
| §2 | 一个角色的文件构成（`.def` 映射表 + 11 类文件职责表） |
| §3 | **从按键到掉血的 6 环执行链**，每环对应哪个实验验证 |
| §4 | 状态机、状态号约定分段（`0` / `200-299` / `400-499` / `1000-1499` / `3000-3999` …）、KFM 状态号全表 |
| §5 | ZSS 语法与**本项目的强制约定**（含 `{` 必须与控制器名同行这类硬规则） |
| §6 | `.air` 动画与判定框（`Clsn1` vs `Clsn2`） |
| §7 | AI 机制：不走命令系统、**优先级 = 源码书写顺序**、难度公式 |
| §8 | Lua 扩展点（`Ctrl+C` / `Ctrl+D` 调试层） |
| §9 | **改动边界表**：什么配置改、什么 ZSS 改、什么才需要改引擎 |
| §10 | P1 Lab 研究用角色说明 |
| §11 | **对 P2 的输入**（必做清单 + P2 自己决定的三件事） |

### 3.2 实验记录（硬证据）

[`docs/p1_experiments.md`](p1_experiments.md) + [`docs/evidence/p1/`](evidence/p1/)。

| # | 改什么 | 观测到什么 |
| --- | --- | --- |
| E0 | — | 合成按键只有 **TAB / RETURN** 能送达引擎 |
| E1 | `.const` 的 `walk.fwd 2.4 → 12.0` | 同时间位移 **21 px → 108 px（比值 5.14 ≈ 5.0）**；改动后撞上对手停住 |
| E2 | `.zss` 的 `hitDef.damage 23 → 137` | `P2 LIF` 精确 `1000→977` / `1000→863`；集气与红血联动 |
| E3 | `.air` 首元素 `2 → 20` 帧 | 动画总时长 **12 → 30**；`hitDef` 触发点第 4 → 第 22 tick |
| E4 | `.air` 的 `Clsn1[0]` 放大十余倍 | 攻击框巨大化；**受击框、精灵、伤害全不变** |
| E5 | `.cmd` 的 `name="x"` 改绑 `y` | `x` 键失效；`y` 键改入 State **200**（顺序优先级） |
| E6 | `AI.zss` 链首插一条 `changeState 210` | 12 帧中 11 帧为 210；**对手全程未掉血** |

### 3.3 观测工具

| 文件 | 作用 |
| --- | --- |
| `tests/p1/capture_match.ps1` | 无人值守开局 + 输入注入 + 抓帧 + 运行报告 |
| `tests/p1/montage_states.ps1` | 状态读数条带拼接（证据生成） |
| `tests/p1/analyze_shots.ps1` | 早期的像素差异分析（已弃用保留） |
| `tests/p1/README.md` | 用法、参数、已知约束 |

### 3.4 P1 Lab 研究用角色与同步脚本

- `game/chars/p1_kfm_zss_lab/`（跟踪，真值）
- `scripts/sync_game_content.ps1`（`game/` → 引擎运行目录，单向、幂等、离线）
- 与上游 `kfm_zss` **逐字节一致**（仅 `name`/`displayname` 与许可证说明不同）

### 3.5 P2 骨架

`design/characters/_template/` —— 10 个文件 + README：

```text
_template.def      文件映射（含 4 键调色板映射）
_template.cmd      4 键命令集（LP/HP/LK/HK）
_template.const    [Data] [Size] [Velocity] [Movement] + 变量台账
_template.zss      完整样板：StateDef 195（非攻击）+ 200（攻击，14 个 hitDef 参数全展开）
command.zss        命令路由 + "顺序即优先级"的完整说明与推荐顺序
hits.zss           受击方状态（P2 起点为空，普通技用公共状态）
AI.zss             AI 骨架 + "优先级=书写顺序"说明 + 改后自查清单
_template.air      Action 0 / 195 / 200，含判定框与"帧数决定快慢"说明
movelist.dat       出招表
README.md          使用步骤 + 已知缺口 + 依据索引
```

---

## 4. 整体用什么方法实现的目标

P1 的方法论可以概括为 **6 条**，后续阶段应继续遵守：

1. **先建可观测性，再谈结论。**
   没有观测装置就没有"实测"。P1 花在搭 `capture_match.ps1` 上的时间超过做实验本身。
   这是必要的投入——它让后面 6 个实验全部变成"改一行、跑一次、读一张图"。

2. **不改引擎。**
   面对引擎内部机制，最直接的冲动是读 Go 源码甚至加日志。
   P1 刻意不碰引擎，因为**"角色文件是否足够"本身就是待验证的问题**。
   改了引擎，这个问题就永远得不到答案。

3. **一次只改一处，改完必须还原。**
   每个实验只改一个文件的一处地方，否则无法归因。实验结束后 Lab 角色回到与上游一致。

4. **用跟踪副本，不用上游素材。**
   实验对象放在 `game/`（可提交、可评审），运行时靠单向同步脚本灌进引擎目录。

5. **数值化，而不是"看起来变了"。**
   E2 的"ΔLIF 精确等于 damage"、E3 的"总时长 12→30"、
   E5 的"状态号精确改判"——都是可复核的数字。做不到数字化的地方
   （如 E1），**明确标注证据强度**，不糊过去。

6. **证据必须是原始的、可被人复核的。**
   最终证据是图（montage）不是脚本输出的结论。

---

## 5. 工具手册（重点）

### 5.0 工具调用关系

```text
   ┌──────────────────────────────────────────┐
   │ tests/p1/capture_match.ps1               │
   │  启动一局 → 开调试层 → 注入输入 → 抓帧     │
   └───────────────┬──────────────────────────┘
                   │ 输出
                   ▼
   logs/p1/shots/*.png            +  *_report.txt（运行报告）
                   │
                   │  montage_states.ps1 裁条带拼接
                   ▼
   docs/evidence/p1/montage_*.png   ← 可判读的最终证据（逐帧 State No / LIF / POW）
```

### 5.1 `capture_match.ps1` —— 观测主体

**作用**：在真实运行的引擎里做一次可复现的角色行为观测。

**关键参数**：

| 参数 | 说明 |
| --- | --- |
| `-P1` / `-P2` / `-Stage` | 双方角色与场景（默认 `p1_kfm_zss_lab` / `kfm_zss` / `stage0`） |
| `-Ai1` / `-Ai2` | AI 等级 1–8（想观测 AI 就设它） |
| `-RoundTime` | 回合时长，透传给引擎的 `-time` |
| `-ShowDebug` / `-ShowClsn` | 打开状态读数 / 判定框 |
| `-HoldVK` + `-HoldSec` | 单键持续按住（虚拟键码 + 秒） |
| `-HoldSeqVK` / `-HoldSeqName` / `-HoldSeqSec` | **多键序列**（逗号分隔，支持 `0x` 十六进制） |
| `-Shots` / `-ShotIntervalSec` | 主循环抓图张数与间隔 |
| `-Prefix` / `-OutDir` | 输出名前缀与目录（默认 `logs/p1/shots`） |

**退出/产物**：`<Prefix>_NN.png`、`<Prefix>_seqNN_<label>_{before,after}.png`、
`<Prefix>_report.txt`。

**为什么 `-HoldSeqVK` 是字符串不是数组**：`pwsh -File` 无法把
`0x09,0x0D` 绑定到 `[int[]]`。脚本内自行 split 解析。**不要改回数组。**

### 5.2 `montage_states.ps1` —— 证据生成

**作用**：把多张截图左下角的状态读数条带裁出来，纵向堆叠成一张可判读的图。

| 参数 | 说明 |
| --- | --- |
| `-Prefix` | 对应 `capture_match.ps1` 的输出前缀 |
| `-Steps` | 只拼接指定步骤（`burst02,burst04`），留空 = 全部 |
| `-CropX/CropY/CropW/CropH` | 裁剪窗口，默认值对应 1280×720 下状态读数位置 |

**为什么这么做**：GDI+ 的 `LockBits` 裁剪返回整图 stride，跨帧逐字节比较不可靠。
裁条带虽然原始，但**证据就是图像本身，不可能读错**，还能直接附进 PR 供人复核。

### 5.3 `sync_game_content.ps1` —— 内容同步

**作用**：把 `game/`（跟踪，真值）复制进 `engine/ikemen-go/`（运行时，gitignored）。

**性质**：单向、幂等、离线、加性（只覆盖 `game/` 里存在的文件，从不删除运行时的东西）。

```powershell
pwsh -File scripts/sync_game_content.ps1            # 同步
pwsh -File scripts/sync_game_content.ps1 -WhatIf    # 只看会复制什么
```

> **为什么必须是单向**：运行时目录在引擎 submodule 里且被 gitignore，
> 放进去的东西**不被跟踪**，绝不能成为任何东西的唯一副本。

---

## 6. 常用命令速查

| 我想…… | 命令 |
| --- | --- |
| 跑测试 | `pwsh -File scripts/test.ps1` |
| 同步角色内容到运行目录 | `pwsh -File scripts/sync_game_content.ps1` |
| 手动开一局看效果 | `pwsh -File scripts/run_game.ps1 -ExtraArgs '-p1','p1_kfm_zss_lab','-p2','kfm_zss','-s','stage0','-windowed'` |
| 观测一次出拳 | `pwsh -File tests/p1/capture_match.ps1 -Prefix t1 -ShowDebug -HoldVK 0x09 -HoldSec 0.45` |
| 观测一整段操作 | `pwsh -File tests/p1/capture_match.ps1 -Prefix t2 -ShowDebug -HoldSeqVK '0x27,0x09,0x0D' -HoldSeqName 'walk,x,y' -HoldSeqSec '2.2,0.6,0.6'` |
| 看判定框 | `pwsh -File tests/p1/capture_match.ps1 -Prefix t3 -ShowClsn -ShowDebug -HoldVK 0x09 -HoldSec 1.8` |
| 看 AI 行为 | `pwsh -File tests/p1/capture_match.ps1 -Prefix t4 -ShowDebug -RoundTime 99 -Shots 12 -ShotIntervalSec 0.6` |
| 拼证据图 | `pwsh -File tests/p1/montage_states.ps1 -Prefix t1 -Steps 'burst02,burst04'` |
| 查引擎基线 | `git submodule status` |

**调试覆盖层快捷键**（游戏内）：

| 快捷键 | 功能 |
| --- | --- |
| `Ctrl+C` | 判定框显示（`Clsn1` 红 / `Clsn2` 蓝） |
| `Ctrl+D` | 状态读数（`State No / LIF / POW / ActionID / ElemNo / Time`） |

> `F1`–`F10`、`SPACE`、`PAUSE`、`SCROLLLOCK` **被引擎占用，不要用**。

---

## 7. P1 期间踩过的坑（下一个 Agent 必读）

1. **合成按键大面积失效。**
   本机 `keybd_event` 发出的字母键、导航键、COMMA **都到不了引擎**，
   只有 **TAB(0x09)** 与 **RETURN(0x0D)** 可靠。
   实验期间运行时键位锁为 `x=TAB`、`y=RETURN`（`save/config.ini`，gitignored，已还原）。
   **后果**：无法在一次运行内测组合键（`x+y`）。

2. **`Ctrl+D` 覆盖层会静默漏触发。**
   发键后不校验的话，会拿到一整轮没有状态读数的废图。
   已修复：`capture_match.ps1` 加像素检测并重试最多 3 次。
   报告中可看到 `overlay not detected (attempt 1)` → `overlay ON (attempt 2)`。

3. **`pwsh -File` 不能绑定数组参数。**
   `-HoldSeqVK 0x09,0x2D` 会报"无法转换为 System.Int32[]"。
   改用字符串参数 + 脚本内解析。

4. **GDI+ `LockBits` 裁剪返回整图 stride。**
   逐像素跨帧比较不可靠（永远报告"有大差异"）。
   改用裁条带 + 人工判读。

5. **改动 `Clsn1` 不会改伤害。**
   这是结论不是坑，但第一次接触很容易误判：
   **"打得到"（`.air` 的 Clsn1）和"打多疼"（`.zss` 的 damage）是解耦的。**
   把攻击框放大十倍，伤害仍然精确是 23。

6. **排序会静默改变行为。**
   `command.zss`（E5）和 `AI.zss`（E6）都是"先出现者胜"，
   没有权重、没有回退、**没有报错**。一条写得太靠前、条件太宽的规则会无声地
   废掉它后面的一切。改这两个文件后必须重新观测行为。

7. **引擎 submodule 目录被 gitignore。**
   往 `engine/ikemen-go/` 放的内容**不会被跟踪**，
   永远不要把 `game/` 里的东西删掉只留运行时副本。

8. **注入输入前必须 `-Ai1 0`。**（本阶段复核时发现，最容易踩）
   `capture_match.ps1` 的 `-Ai1` **默认是 8**，即 P1 由 AI 控制。AI 直接 `changeState`，
   并且对默认走路下了 `assertSpecial{flag: nowalk}`（`AI.zss:37`），
   **注入的方向键对 AI 控制的角色完全不起作用**。
   它会**静默失效** —— 画面里角色确实在动（AI 自己在动），肉眼不容易察觉。
   快速自查：报告里的 `args` 行若出现 `-p1.ai`，说明 AI 是开着的，注入实验无效。

9. **调试覆盖层上的 `P1: 56` 是角色 ID，不是坐标。**
   出处 `debug.lua:183-184`：`'P%d: %d; LIF:%4d; …'` 的第二个参数是 `id()`。
   E1 第一版就是拿这个数字当"位置读数"，得出的结论完全无意义。
   **位置只能从画面像素量**（名标签水平居中于角色，其像素中心就是角色 x），
   或者用 `displayToClipboard` 把 `pos x` 导出来。

10. **单键路径 `-HoldVK` 未经验证。**
    E1 第一版用它跑 0.35 s，行为无法确认有效；
    重做时统一改用 `-HoldSeqVK`（`'0x27'` + `HoldSeqSec`）后一切正常。
    **一律使用 `-HoldSeqVK`。**

---

## 8. 已知限制与遗留事项

| 项 | 说明 | 影响 |
| --- | --- | --- |
| 合成输入只有 TAB / RETURN 可达 | 组合键无法注入 | E5 只覆盖单键路由 |
| 依赖本机运行时键位 | `save/config.ini` 不在仓库 | 复现需自行对齐 |
| 观测工具需要真实桌面会话 | 依赖前台焦点与渲染 | 无法进无头 CI |
| 状态读数靠 burst 抽样 | 可能漏掉瞬态状态 | 提高频率或改用 `printToConsole` |
| 位置类实验只能靠像素测量 | 调试层不输出世界坐标；精度约 ±1 px，两角色靠近时名标签并簇、无法再分辨 | 用 `displayToClipboard` 输出 `pos x`（`kfm.zss:2564` 有官方写法示例） |
| 注入必须显式 `-Ai1 0` | 忘了传就静默失效 | 已写入 §7 第 8 条；可考虑把脚本默认值改为 0 |
| Lua 调试热键大多未验证可注入 | 只有 `Ctrl+C`/`Ctrl+D` 实测可用 | 见架构文档 §8.2 |
| 判定框"生效边界"未定量 | 只证明"框变大、伤害不变" | 未回答"框要多大才刚好够到对手" |
| 调试读数不含世界坐标 | 位置类实验只能目视 | 同上 |
| `_template` 缺 `.sff` / `.snd` | 二进制容器无法用文本创建 | 需临时借用素材（须登记许可证）或等 P5 工具链 |
| **PR 尚未创建** | 本机无 `gh` CLI | 见 §9，标题与描述可直接粘贴 |

---

## 9. PR 信息（可直接粘贴）

P1 的全部提交**已推送**到 `origin/feature/p1-kfm-study`（5 个提交），
但 **Pull Request 需要人工在 GitHub 网页创建**（本机未安装 `gh` CLI）。

```text
remote: Create a pull request for 'feature/p1-kfm-study' on GitHub by visiting:
remote:      https://github.com/Blinkblade/KingOfFate/pull/new/feature/p1-kfm-study
```

- **创建入口**：`https://github.com/Blinkblade/KingOfFate/pull/new/feature/p1-kfm-study`
- **合并方向**：`feature/p1-kfm-study` → `main`

**PR 标题**

```text
P1: understand and validate the IKEMEN character architecture
```

**PR 描述**

```markdown
## Summary

P1（IKEMEN Character Architecture）10/10 Exit Gate 全部 PASS。

这一阶段不产出角色，而是把"做一个角色需要知道什么"变成本仓库内实测验证过的工程知识。

### 核心产出

- `docs/ikemen_character_architecture.md` —— 角色文件构成、从按键到掉血的 6 环执行链、
  状态机与状态号约定、ZSS 语法与项目约定、判定框、AI 机制、Lua 扩展点、改动边界
- `docs/p1_experiments.md` + `docs/evidence/p1/` —— 6 个独立实验的完整记录与原始证据
- `design/characters/_template/` —— P2 可直接复制的角色骨架（10 个文件 + 使用说明）
- `tests/p1/` —— 可复用的角色行为观测工具（无人值守开局 / 输入注入 / 抓帧 / 状态读数拼接）

### 实测结论（数值化）

| # | 改什么 | 观测到什么 |
| --- | --- | --- |
| E1 | `.const` `walk.fwd 2.4 → 12.0` | 同 0.35 s 从位置 56 冲到对手身前（倍率未直接读出，已如实标注） |
| E2 | `.zss` `hitDef.damage 23 → 137` | `P2 LIF` 精确 `1000→977` / `1000→863`；集气与红血联动 |
| E3 | `.air` 首元素 `2 → 20` 帧 | 动画总时长 12 → 30；`hitDef` 触发点第 4 → 第 22 tick |
| E4 | `.air` `Clsn1[0]` 放大十余倍 | 攻击框巨大化；受击框、精灵、伤害全不变 |
| E5 | `.cmd` `name="x"` 改绑 `y` | `x` 键失效；`y` 键改入 State 200（顺序优先级） |
| E6 | `AI.zss` 链首插 `changeState 210` | 12 帧中 11 帧为 210；对手全程未掉血 |

### 关键结论

- **整条执行链 100% 可在角色文件内验证，无需触碰引擎源码。**
  引擎 submodule 全程保持字节级干净（`git status` 为空，HEAD 仍等于钉死基线）。
- **"改什么 → 变什么"是数值精确可预测的**，不是"看起来变了"。
- 存在**两个隐式优先级系统**（命令路由顺序、AI 规则顺序），都是"先出现者胜"，
  排序失误会静默失效 —— 这是后续阶段最容易踩的坑。

## Test Plan

- `pwsh -File scripts/test.ps1` → 26/26 PASS，exit 0
- `git submodule status` → ` ba516193bba83f13f0b63ddce314d8719793931f engine/ikemen-go (v1.0.0-rc.5)`
- `engine/ikemen-go` 内 `git status --short` → 空
- 实验室角色与上游逐文件比对 → 全部 IDENTICAL，运行时副本全部 IN SYNC，实验改动已全部还原
- 6 个实验均在真实运行的引擎进程内完成"修改 → 观测 → 还原"闭环
```

---

## 10. 给下一个 Agent 的三条提醒

1. **先读状态，再动手**：`README.md` → `docs/development_status.md` → 本文件 →
   P1 Phase Report。仓库是唯一真实工程状态，**不要依赖对话记忆**。
2. **不要动基线，也不要动引擎**：`engine/ikemen-go` 固定在 `v1.0.0-rc.5`。
   P1 已经证明**不需要改引擎就能做角色**；确实需要时走 `CONTRIBUTING.md` 的完整流程。
3. **改 `command.zss` 或 `AI.zss` 之后一定要重新观测行为**：
   这两个文件靠顺序表达优先级，改错顺序不会报错，只会静默失效。
   用 `tests/p1/` 的工具跑一次、读一次状态号序列就能发现。

P2（Base Fighter Template）的开工清单见
[`docs/ikemen_character_architecture.md`](ikemen_character_architecture.md) §11，
骨架见 [`design/characters/_template/`](../design/characters/_template/)。

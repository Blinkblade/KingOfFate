# Iteration: P5 — Character Asset Tooling（角色资产工具链）

## 基本信息

- 日期：2026-09-29（会话起于 2026-09-28 深夜）
- Phase：P5 — Character Asset Tooling
- Branch：`feature/p5-character-asset-tooling`
- PR：待手动创建（本机无 `gh`）
- 状态：**完成**（Gate 1–10 全部有证据；见 Phase Report）
- 基线：`main` @ `e279e96`（PR #6 合并 P4）
- 引擎：`engine/ikemen-go` @ `ba516193`（`v1.0.0-rc.5`）—— **全程未修改，submodule 未动**

---

## 本次目标

在**不重造 MUGEN/IKEMEN 编辑器生态**的前提下，为 P6 的第一个正式美术角色建立一套最小、
可靠、可重复使用的角色资产检查与验证工具链：

```text
SFF Inspect / Sprite Export / AIR Inspect / Animation Validation / Character Validation
```

判断标准不是"功能多"，而是 **P6 真正需要 + 结果可靠 + 可自动化 + 可复用 + 不破坏现有角色与引擎**。

---

## 修改内容

### 新增：只读资产解析库 `tools/kofassets/`（纯标准库）

| 文件 | 内容 |
| --- | --- |
| `pngio.py` | 最小 PNG 写（8-bit RGBA、filter 0）与读（位深 1/2/4/8、色彩类型 0/2/3/4/6、拒绝隔行） |
| `sff.py` | SFF v2：头、调色板表与调色板数据、精灵头、LZ5 / RLE8 / RLE5 / PNG(索引) / PNG(RGBA) / raw(8) 解码、链接精灵、重复键；v1 与 raw 真彩明确报 `Unsupported` |
| `air.py` | `.air` 解析 + **引擎的判定框作用域模型**（`default` / `per-frame` / `cleared` / `none`） |
| `chardef.py` | `.def` 解析、`[Files]` 路径解析（含引擎 `data/` 回退）、引擎根目录探测 |
| `checks.py` | 验证规则集合（`airtool` 与 `validate_character` 共用） |
| `report.py` | ERROR / WARNING / INFO、退出码契约、文本与 JSON 输出 |

解析算法逐行移植自 `engine/ikemen-go/src/image.go` 与 `anim.go`，并**补上引擎缺失的边界检查**
（引擎越界会 panic，工具报错退出）。移植出处写在每个模块的 docstring 里。

### 新增：三件 CLI 工具

- `tools/sffctl/sffctl.py` — `inspect` / `export` / `montage`，全部支持 `--json`
- `tools/airtool/airtool.py` — `inspect` / `validate`，全部支持 `--json`
- `tools/character_validate/validate_character.py` — 角色级验证入口，`--json` / `--strict` / `--quiet`

### 新增：测试夹具与工具测试

- `tests/fixtures/make_fixtures.py` — 生成 36 个极小合成夹具（最小 SFF v2、v1、截断、坏签名、
  9 个 AIR 正负例、4 个角色目录夹具）。**这是仓库里唯一会写 SFF 的地方，且只用于测试。**
- `tests/fixtures/verify_decoders.py` — 夹具像素**逐字节相等**断言 + 真实容器 golden 哈希回归 +
  四个真实容器的全精灵解码结构断言
- `tests/fixtures/expected/decoder_goldens.json` — 3 个真实精灵的 RGBA sha256
- `tests/tools/check_export.py` — 把导出的 PNG 从磁盘读回来，与容器逐像素对照
- `tests/tools/run_tool_tests.ps1` — 61 项（`-Full` 66 项）工具测试

### 修改

- `scripts/test.ps1` — 改为跑 `smoke` + `tools` 两个套件（`-Suite` 可选，`-Full` 透传）
- `docs/development_status.md` — P5 → PASS，P6 → NEXT
- `README.md` — 当前阶段、`tools/` 说明、测试入口说明
- **`game/chars/test_fighter_b/test_fighter_b.air`** — 一处真实缺陷修复，见下

---

## 技术实现

### 1. SFF v2 读取

按 `SffHeader.Read` / `readHeaderV2` / `readV2` 移植。本仓库四个角色容器都是
`2.0.1.0`、282 精灵、16 调色板；精灵格式分布是 **280 个 LZ5** + **2 个 PNG(索引)**
（`9000,1` 与 `9001,0` 两张头像）。因此重点把 LZ5 做对：

- Go 的 `byte(d & 0xc0 >> rbc)` **不是**笔误 —— Go 里 `&` 与 `>>` 同优先级、左结合，
  等价于 `(d & 0xc0) >> rbc`。移植时按这个语义写，并在 docstring 里注明。
- 所有解码器都带**迭代预算**、反向引用范围检查、压缩流耗尽检查（引擎在这些地方会 panic
  或静默产出错误像素）。
- 每个精灵的数据偏移都做**文件边界检查**：越界即报"文件被截断或损坏"，而不是崩溃。

### 2. AIR 解析与判定框作用域（本次最重要的语义）

`anim.go:311-364` 的 `def1`/`def2` 标志：**声明时置 false，每读入一个元素行后复位为 true**。
推论：

```text
Clsn1: N         → 只作用于紧跟的那 1 个元素
Clsn1Default: N  → 作用于该 Action 的每一个元素（因此覆盖 -1 保持帧）
Clsn1: 0         → 之后的元素回到默认（通常为空）
```

工具为**每个元素**输出它实际生效的模式，于是 P4 的投射物坑变成一行可读输出；
`AIR_ATTACK_NOT_PERSISTENT` 规则也据此实现（正例/反例都在 `tests/fixtures` 里）。

> 仓库 `.air` 注释里"`Clsn1` 会沿用到下一次声明"的说法按引擎源码与 P4 实测不准确。
> 本次**只记录、不改注释**（避免在工具 PR 里顺手改三个角色的文档文案），已列入 P5 Summary 遗留项。

### 3. 验证规则的两处收敛（都写进了 `docs/character_asset_tooling.md` §11）

- 第一版硬编码了一张"角色应该有哪些动画"的清单，跑 `_template` 直接报 ERROR ——
  但模板**本来就故意没有蹲姿动作**（P2 范围声明）。规则改为"检查角色自己的脚本要什么"
  （`ZSS_MISSING_ACTION`，只认字面量），不再猜。
- 也没把引擎公共状态索要的动画当必需：`data/common1.cns.zss` 索要的动画多数被
  `selfAnimExist(...)` 保护或位于引擎标注 `Deprecated in DosMugen` 的状态，
  报出来只会给每个角色加 9 条无法处理的警告。

### 4. 测试策略：为什么必须有夹具

真实容器是占位素材（KFM 的 SFF），**没有人写下过它每个像素应该是什么**，因此无法用它
断言"解码正确"。所以：

- **合成夹具**给出"已知索引 + 已知调色板 → 已知 RGBA"的逐字节断言（覆盖 raw 与 LZ5 路径）；
- **真实容器**只做 golden 哈希的"未变化"回归 + 全 282 精灵的结构断言；
- **correctness 的人工判据**是 `montage` 拼图（人眼确认是人形而不是噪点），
  命令与产物记录在 `docs/evidence/p5/p6_ready_run.txt`。

---

## 主要修改文件

```text
新增
  tools/kofassets/{__init__,pngio,sff,air,chardef,checks,report}.py
  tools/sffctl/sffctl.py
  tools/airtool/airtool.py
  tools/character_validate/validate_character.py
  tests/fixtures/make_fixtures.py
  tests/fixtures/verify_decoders.py
  tests/fixtures/expected/decoder_goldens.json
  tests/fixtures/assets/**                      36 个生成夹具（含 4 个角色目录）
  tests/fixtures/README.md
  tests/tools/check_export.py
  tests/tools/run_tool_tests.ps1
  docs/character_asset_tooling.md
  docs/P5-summary.md
  docs/phase_reports/P5-character-asset-tooling.md
  docs/evidence/p5/{README.md,p6_ready_run.txt}
  docs/iterations/20260929-p5-character-asset-tooling.md

修改
  scripts/test.ps1                              接入 tools 套件
  README.md                                     当前阶段 / tools / 测试入口
  docs/development_status.md                    P5 = PASS，P6 = NEXT
  game/chars/test_fighter_b/test_fighter_b.air  410,5 → 410,4（真实缺陷修复）
```

---

## 发现的真实缺陷（工具第一次运行就查出来了）

`test_fighter_b.air` 的 Action 410（蹲重拳，对空 Normal）第 4 个元素引用精灵
**`410,5`，占位 SFF 里不存在**（KFM 容器只有 `410,0…410,4`）。

- 证据：`airtool validate` → `AIR_MISSING_SPRITE`（`docs/evidence/p5/p6_ready_run.txt` 前后版本）；
  对照 Fighter A 的同一动作（用 `410,0/1/3/4`）与引擎自带 KFM 的原始 Action 410（同样只有 `410,0…410,4`）。
- 影响：引擎记一条 missing sprite 并在那 5 tick 里不画角色（画面缺帧），判定框本身不受影响 ——
  所以 P4 的 Runtime 测试没有暴露它。
- 处置：按 `.air` 注释声明的"收招 11 tick（6+5）"改成 `410,4`，姿势延续、**tick 数不变**，
  并在文件里留一行说明。这是**内容修复**，与工具开发分开描述；如要回退只需改回一个 token。

---

## 测试

| 项目 | 命令 | 结果 |
| --- | --- | --- |
| 基线（改动前） | `pwsh -File scripts\test.ps1` | **26/26 PASS** |
| 统一入口（改动后） | `pwsh -File scripts\test.ps1` | smoke **26/26** + tools **61/61** = **PASS** |
| 工具测试（含全部导出） | `pwsh -File scripts\test.ps1 -Full` | **66/66 PASS**（21.9 s） |
| 解码器校验 | `python tests\fixtures\verify_decoders.py` | **42/42 PASS** |
| 夹具自检 | `python tests\fixtures\make_fixtures.py --check` | 36 文件，0 问题 |
| 真实角色验证 | `validate_character.py` × `_template` / `test_fighter_a` / `test_fighter_b` | 三个都 `errors: 0`，退出码 0 |
| 端到端演练 | 见 `docs/evidence/p5/p6_ready_run.txt` | 9 个步骤全部退出码 0 |

工具测试覆盖：happy path、`--json` 结构、缺失文件、目录当文件、不支持版本、截断文件、
坏签名、不覆盖、命名规则、导出确定性（两次导出逐字节相同）、导出后从磁盘回读逐像素对照、
montage 确定性、重复 Action、空 Action、判定框数量不符、孤立框行、缺精灵、非法时间、
P4 投射物正反例（并在数据层断言两种写法的 `mode`/`count` 不同）、角色缺文件、脚本引用缺失动画、
不支持的 SFF 版本。

---

## 已知问题

1. **P1–P3 文档中"读截图得来的数值"仍未复核**（P4 遗留项 #8）。P5 主任务不是清理历史证据，
   未因此阻塞本阶段。
2. `.air` 里"`Clsn1` 沿用到下一次声明"的注释与引擎语义不符（见"技术实现 §2"）。本次只记录、
   未修改 `_template` / `test_fighter_a` 的注释 —— 它们是各自角色的真值文件，改动应单独评估。
   已列入 P5 Summary 遗留项。
3. 三个角色各有 3 条 `AIR_HURTBOX_GAP` 警告（Action 210 / 230 / 820），来自 `_template` 的写法：
   受击框用逐帧 `Clsn2` 声明，只覆盖紧邻的元素。这是**真实存在的语义缺口**（那几 tick 角色
   没有受击框），但对现有玩法没有造成可测问题（P4 的 6 组对局全绿）。属"内容味道"问题，
   不是 P5 的回归，留给 P6 用 `Clsn2Default` 解决。
4. SFF v1 与 raw 真彩精灵不支持（引擎能加载 v1）。仓库里的 v1 文件是 P1 实验角色的
   `intro.sff` / `ending.sff`，不属于 P5 目标。
5. 不支持 SFF 写回 —— 刻意不做（P6 是否需要等正式素材流程确定）。

---

## 后续工作

- **P6** 用这套工具接第一套正式美术素材；遇到工具不支持的地方优先在 `tools/` 里补，
  而不是改引擎。
- 如果 P6 确认需要写回 SFF / 批量替换精灵，再单独评估 `sff writer`（本次刻意不做）。
- 用 `tools/read_frame_text.py` 回扫 P1–P3 的截图数值（P4 遗留项 #8）。
- 视情况统一三个角色 `.air` 注释里关于判定框作用域的表述。

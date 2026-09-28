# P5 — Character Asset Tooling · Phase Report

| | |
| --- | --- |
| **阶段** | P5 — Character Asset Tooling |
| **状态** | **PASS**（Gate 1–10 全部通过，逐条证据见下） |
| **时间** | 2026-09-29 |
| **分支** | `feature/p5-character-asset-tooling` |
| **基线** | `main` @ `e279e96`（PR #6 合并 P4） |
| **引擎** | `engine/ikemen-go` @ `ba516193`（`v1.0.0-rc.5`）—— **全程未修改**，submodule 指针未动 |
| **过程记录** | [`iterations/20260929-p5-character-asset-tooling.md`](../iterations/20260929-p5-character-asset-tooling.md) |
| **工具手册** | [`docs/character_asset_tooling.md`](../character_asset_tooling.md) |
| **交接说明** | [`docs/P5-summary.md`](../P5-summary.md) |
| **原始证据** | [`docs/evidence/p5/`](../evidence/p5/) |

---

## 1. 结论

P5 的客户是 P6。P5 结束时可以做到：

```text
拿到一套新的 Sprite / SFF / AIR
  → 看出 SFF 里有什么（版本、数量、每个精灵的尺寸与原点、格式、调色板）
  → 把精灵导成 PNG 并有人眼可核对的拼图
  → 看出每个 Action 有多少元素、多少 tick、判定框在哪一帧生效
  → 在看代码/进游戏之前发现引用缺失、重复 Action、判定框作用域错误、受击框缺口
  → 用一条命令判断一个角色目录是否达到"可以进 Runtime"的静态标准
```

全部工具**只读**：不写回 SFF、不编辑 AIR、不修改角色文件、默认不覆盖任何文件。

本阶段同时**首次运行就查出一处真实的内容缺陷**（`test_fighter_b.air` 引用了不存在的
精灵 `410,5`），已最小修正并单独记录（§4）。

---

## 2. Exit Gate 结果

### Gate 1 — Baseline · **PASS**

| 检查 | 命令 | 结果 | 证据 |
| --- | --- | --- | --- |
| P4 已进入 main | `git log --oneline origin/main` | `e279e96 Merge pull request #6 from Blinkblade/feature/p4-test-fighter-b`；`git log feature/p4-test-fighter-b..origin/main` 只剩该合并提交，`git diff origin/main feature/p4-test-fighter-b` **为空** | 见 §3 命令记录 |
| 本地 main 更新 | `git switch main; git merge --ff-only origin/main` | `Updating 18621e4..e279e96`，fast-forward，无冲突 | 同上 |
| 工作树 clean | `git status --short --branch` | `## main...origin/main`，无改动 | 同上 |
| 引擎 pin | `git submodule status` | ` ba516193bba83f13f0b63ddce314d8719793931f engine/ikemen-go (v1.0.0-rc.5)`（前导空格 = 未修改） | 同上 |
| 基线测试 | `pwsh -File scripts/test.ps1` | **26/26 PASS**，`SMOKE TEST PASS` | [`evidence/p5/baseline_test_before_p5.txt`](../evidence/p5/baseline_test_before_p5.txt) |
| 角色 Runtime 回归 | `pwsh -File scripts/sync_game_content.ps1` + `pwsh -File tests/p4/run_matrix.ps1 -Only b_vs_a -RunSec 15` | `=> PASS (harness exit=0, crash line: crashlogs : 0 new during the run)`；引擎 crash-log 目录文件数 **11 → 11**（无新增） | [`evidence/p5/runtime_regression.txt`](../evidence/p5/runtime_regression.txt) |

> 本次 P5 只改了 `game/chars/test_fighter_b/test_fighter_b.air` 一个 token（§4），
> 因此按合同 §60 做了**一组** Runtime 回归而不是全量矩阵；判定只认 harness 报告里的
> `crashlogs : 0 new during the run` 一行。

### Gate 2 — SFF Inspect · **PASS**

| 检查 | 结果 |
| --- | --- |
| 输出版本 | `Version: 2.0.1.0` |
| 输出精灵数 | `Sprites: 282 (282 unique group,image keys)` |
| 输出 Group/Image | 表格列 `group image` |
| 输出 Width/Height | 表格列 `width height` |
| 输出 Axis | 表格列 `axisx axisy` |
| `_template` / Fighter A / Fighter B 各成功运行一次 | 三个都 `exit=0`，均为 `2.0.1.0` / 282 精灵 / 16 调色板 |
| 机器可读 | `--json` 输出含 `version` / `sprite_count` / `palette_count` / `sprites[]`（每个精灵含 `group`、`image`、`width`、`height`、`axis_x`、`axis_y`、`format`、`colour_depth`、`palette_index`、`data_offset`、`data_size`） |

证据：[`evidence/p5/sffctl_three_characters.txt`](../evidence/p5/sffctl_three_characters.txt)、
[`evidence/p5/p6_ready_run.txt`](../evidence/p5/p6_ready_run.txt) STEP 2。

### Gate 3 — Sprite Export · **PASS**

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 导出单个精灵 | `--sprite 210,3 --sprite 1000,4` → `exported 2 of 2` | `p6_ready_run.txt` STEP 3 |
| 导出全部 282 个 | `--out logs\p5\tool-tests\real_all --overwrite` → `exported 282 of 282` | `tool_tests_full.txt` |
| 尺寸正确 | 导出的 PNG 从磁盘读回，`width/height` 与 SFF 元数据一致（282/282） | `check_export.py`：`282 file(s) verified, 0 problem(s)` |
| 透明度正确 | 每个 PNG 的不透明像素数与容器逐像素相等；且**没有全透明精灵** | 同上；`verify_decoders.py`：`every sprite has visible pixels`（3 个容器 × 282） |
| **解码与引擎一致** | 用引擎自己的 `Lz5Decode`（`image.go:1209` 逐字照抄）对四个容器每个精灵解码取哈希，与 `tools/kofassets/sff.py` 逐字节比对 | **1128 个精灵，0 处不一致**（含 41/282 的链接精灵与 2/282 的 PNG 索引精灵）→ [`evidence/p5/engine_decoder_crosscheck.txt`](../evidence/p5/engine_decoder_crosscheck.txt) |
| 文件命名稳定 | `<group>_<image>.png`（`0_0.png` / `1_0.png` / `2_0.png`），两次导出到不同目录 **SHA256 逐文件相同** | `tool_tests.txt` group 3 |
| 默认不覆盖 | 目标已存在且未加 `--overwrite` → `SFF_EXPORT_NO_OVERWRITE`，退出码 **1** | 同上 |
| 不污染角色目录 | 输出目录必填；工具从不默认写入角色目录；跑完 `git status` 无 `logs/` 之外的 PNG | `tool_tests.txt` group 7 |
| 调色板一致性 | 用夹具做**逐字节**断言：已知索引 + 已知调色板 → 期望 RGBA 完全相等（raw 路径与 LZ5 路径各一） | `verify_decoders.py`：42/42 |

> 关于"颜色与 IKEMEN Runtime 一致"：**没有声称 100% 一致**。真实容器的正确性判据是
> ①夹具的逐像素相等、②282 个精灵全部可解码且有可见像素、③人工看 montage 拼图。
> 缩放 / palFX / blend 不在导出范围内，见工具手册 §12。

### Gate 4 — AIR Inspect · **PASS**

| 检查 | 结果 |
| --- | --- |
| 解析 Action / 元素 / 时间 | `airtool inspect` 输出 Action 数、每个 Action 的元素表、`ticks`、`duration` |
| 识别 `-1` | `Duration: infinite (has a -1 hold)` / `Infinite element: yes`；**不伪造有限时长** |
| 解析 `Clsn1` / `Clsn2` | 每个元素输出生效框数与坐标 |
| 解析 Default collision | 模式标签 `default` / `per-frame` / `cleared` / `none` |
| Fighter A 普通攻击 Action | Action 200（5 元素，20 ticks）、Action 210（8 元素，27 ticks）→ `exit=0` |
| Fighter B Long Range Action | Action 210 → 33 ticks，判定元素 `Clsn1: (30,-76,105,-56), (62,-72,98,-58)` |
| Fighter B Projectile Action 1005 | 2 元素，`Duration: infinite`，两个元素都是 `clsn1=default` |

证据：[`evidence/p5/sffctl_three_characters.txt`](../evidence/p5/sffctl_three_characters.txt)、
[`evidence/p5/p6_ready_run.txt`](../evidence/p5/p6_ready_run.txt) STEP 4–6。

### Gate 5 — Animation Validation · **PASS**

| 能力 | 夹具 | 结果 |
| --- | --- | --- |
| missing sprite | `missing_sprite.air` | `ERROR AIR_MISSING_SPRITE`，退出码 1 |
| duplicate action | `dup_action.air` | `ERROR AIR_DUPLICATE_ACTION`，退出码 1 |
| invalid collision declaration | `bad_box_count.air` | `ERROR AIR_BOX_COUNT_MISMATCH`，退出码 1 |
| 非法/异常元素 | `bad_time.air`（`time = -2`） | `ERROR AIR_BAD_TIME`，退出码 1 |
| 空 Action | `empty_action.air` | `ERROR AIR_EMPTY_ACTION`，退出码 1 |
| 孤立框行 | `orphan_box.air` | `WARNING AIR_ORPHAN_BOX_LINE`，**退出码 0** |
| ERROR / WARNING 区分 | `ok.air` | 退出码 0；`--strict` 时 WARNING 才升级为 1 |

**ERROR > 0 / WARNING-only = 0** 的约定在 `--strict` 之外全部成立（见 `tool_tests.txt` group 5）。

### Gate 6 — P4 Projectile AIR Case · **PASS**

P4 的结论（`Clsn1` 只作用于紧邻元素 → 投射物 `-1` 保持帧失去攻击框；必须用 `Clsn1Default`）
在这套工具里被**当作语义实现**，而不是当字符串黑名单：

| 项 | 正例 `p4_default_hold.air` | 反例 `p4_per_frame_hold.air` |
| --- | --- | --- |
| `validate` 输出 | `INFO AIR_ATTACK_PERSISTENT`，**不出现**不持续警告 | `WARNING AIR_ATTACK_NOT_PERSISTENT` |
| `-1` 元素的 `clsn1.mode` | `default` | `none` |
| `-1` 元素的 `clsn1.count` | **1** | **0** |

上表后两行是测试里的**数据层断言**（`tool_tests.txt` group 5：
`per-frame hold element: mode=none, boxes=0` / `default hold element: mode=default, boxes=1`），
因此"解析器把两者混为一谈"会直接让测试失败。

真实文件侧：`test_fighter_b.air` 的 Action 1005 两个元素都是 `default` 模式，
即 P4 修好之后的状态被工具正确读出。

### Gate 7 — Character Validation · **PASS**

| 角色 | 命令 | 结果 |
| --- | --- | --- |
| `_template` | `validate_character.py game/chars/_template` | `errors: 0` / `warnings: 3` / 退出码 **0** |
| `test_fighter_a` | 同上 | `errors: 0` / `warnings: 3` / 退出码 **0** |
| `test_fighter_b` | 同上 | `errors: 0` / `warnings: 3` / 退出码 **0**（修复 §4 之前是 1） |

每个角色都逐项检查：核心文件引用（DEF/CMD/SFF/AIR/SND/constants/st/common）、
`AIR → SFF` 精灵引用（189 个引用全部存在）、`scripts → AIR` 字面量动画引用、
`SFF content`（版本/数量/调色板）、`AIR content`（Action 数）。

三条 WARNING 是三个角色**共有**的 `AIR_HURTBOX_GAP`（Action 210 / 230 / 820）——
继承了 `_template` 的判定框写法，是真实存在的语义缺口但不是"角色不能用"（§5 已知限制 3）。

### Gate 8 — Negative Tests · **PASS**

| 场景 | 命令 | 期望 | 实际 |
| --- | --- | --- | --- |
| 缺文件（SFF） | `sffctl inspect tests\fixtures\assets\nope.sff` | 非 0 + 可定位 | 退出码 **3**，`no such file` |
| 缺文件（角色目录） | `validate_character.py ...\no_such_character` | 非 0 + 可定位 | 退出码 **3**，`no such character` |
| 错误 Sprite 引用 | `airtool validate missing_sprite.air --sff minimal_v2.sff` | 非 0 + 定位到 Action/精灵 | 退出码 **1**，`AIR_MISSING_SPRITE ... action 0 element 1 ... sprite 99,99` |
| 重复 Action | `airtool validate dup_action.air` | 非 0 | 退出码 **1**，`AIR_DUPLICATE_ACTION` |
| 非法 SFF（坏签名） | `sffctl inspect bad_signature.sff` | 非 0，不崩溃 | 退出码 **5**，`bad SFF signature` |
| unsupported SFF（v1） | `sffctl inspect unsupported_v1.sff` | 非 0，明确"不支持"而非"损坏" | 退出码 **4**，`SFF v1 (1.0.1.0) is not supported ...` |
| 截断文件 | `sffctl inspect truncated.sff` | 非 0，不崩溃、不挂死 | 退出码 **5**，`... runs past the end of the file -- the file is truncated or corrupt` |
| 用法错误 | `sffctl export <sff>`（缺 `--out`） | 非 0 | 退出码 **2** |

全部断言在 `tests/tools/run_tool_tests.ps1` 里（`tool_tests.txt` group 2 / 3 / 5 / 6）。

### Gate 9 — P6 Ready End-to-End · **PASS**

角色：`game/chars/test_fighter_b/`。9 个步骤、全部退出码 0，原始输出：

[`evidence/p5/p6_ready_run.txt`](../evidence/p5/p6_ready_run.txt)

```text
STEP 1  validate_character            errors 0 / warnings 3        exit=0
STEP 2  sffctl inspect --limit 14     2.0.1.0 / 282 / 16           exit=0
STEP 3  sffctl export 210,3 1000,4    95x104 / 123x84              exit=0
STEP 4  airtool inspect --action 210  33 ticks，判定 x=105          exit=0
STEP 5  airtool inspect --action 1005 2 元素 / infinite / default   exit=0
STEP 6  airtool inspect --action 1100 41 ticks，Clsn1 到 y=-152     exit=0
STEP 7  airtool validate              0 errors / 3 warnings         exit=0
STEP 8  check_export                  2 文件逐像素对照 0 问题       exit=0
STEP 9  montage                       282 精灵 → 16x18 拼图          exit=0
```

**工具输出与角色真实代码的一致性对照**（这是 Gate 9 的实质判据，不是"命令跑通了"）：

| 项目 | 角色文档（`design/characters/test_fighter_b/moves.csv` / `.air` 注释） | 工具输出 | 一致 |
| --- | --- | --- | --- |
| Stand C (210) 总帧数 | Startup 14 + Active 4 + Recovery 15 = **33** | `Duration: 33 ticks`，判定元素 `time=4` | ✅ |
| Stand C 长手距离 | "Clsn1 到 **x=105**" | `element 4 Clsn1: (30,-76,105,-56), ...` | ✅ |
| Stand C 判定帧 | "判定帧 animElem 5"（1-based） | 判定元素 index **4**（0-based）= animElem 5 | ✅ |
| Anti-Air (410) 判定高度 | "Clsn1 向上到 **y=-112**" | `Clsn1[1] = 40,-112, 58,-86` | ✅ |
| Rising Upper (1100) | 12 + 5 + 24 = **41** tick；"Clsn1 = 28,-60 → 62,-152" | `Duration: 41 ticks`；`element 6 Clsn1: (28,-152,62,-60)` | ✅ |
| Ki Blast (1000) | 9 + 33 = **42** tick | Action 1000 `finite_ticks=42` | ✅ |
| 投射物动画 (1005) | "全程带判定（Clsn1Default）" | 两个元素 `clsn1=default`，含 `-1` 帧 | ✅ |
| 导出精灵尺寸 | — | `210,3` = 95x104 axis(13,103)；`1000,4` = 123x84 axis(54,83) | ✅ |

### Gate 10 — Regression & Documentation · **PASS**

| 检查 | 结果 |
| --- | --- |
| `pwsh -File scripts/test.ps1` | smoke **26/26** + tools **65/65** = PASS → [`evidence/p5/test_ps1_all_suites.txt`](../evidence/p5/test_ps1_all_suites.txt) |
| `pwsh -File scripts/test.ps1 -Full` | tools **70/70**（含全部 282 个精灵导出 + montage 确定性）→ [`evidence/p5/tool_tests_full.txt`](../evidence/p5/tool_tests_full.txt) |
| Fighter A / Fighter B 基础回归 | `run_matrix.ps1 -Only b_vs_a` PASS，`crashlogs : 0 new` → [`evidence/p5/runtime_regression.txt`](../evidence/p5/runtime_regression.txt) |
| 工具测试 | 见上（**65** 项 / `-Full` **70** 项，含链接精灵与空白精灵两个夹具） |
| 解码器校验 | `python tests\fixtures\verify_decoders.py` → **48/48 PASS**（含链接精灵与空白精灵断言） |
| 解码与引擎逐字节对照 | 1128 个精灵，0 处不一致（详见 Gate 3） |
| 无意外 Git 修改 | 工具测试 group 7 直接断言：引擎 submodule 未改、`logs/` 外无 PNG、除 `test_fighter_b.air` 外无角色文件变化；收尾 `git status` 见 §6 |
| `docs/character_asset_tooling.md` | DONE |
| Iteration Record | DONE：`docs/iterations/20260929-p5-character-asset-tooling.md` |
| Phase Report | 本文件 |
| P5 Summary | DONE：`docs/P5-summary.md` |
| `development_status.md` 更新 | DONE：P5 = PASS，P6 = NEXT |
| `git status` clean（无残留） | 见 §6 |

---

## 3. 关键命令记录

```powershell
# Gate 1 -- 基线
git fetch origin
git log --oneline -3 origin/main                     # e279e96 Merge pull request #6 ...
git log --oneline feature/p4-test-fighter-b..origin/main
git switch main; git merge --ff-only origin/main     # Updating 18621e4..e279e96
git submodule status                                 #  ba516193... engine/ikemen-go (v1.0.0-rc.5)
pwsh -File scripts\test.ps1                          # 26/26 PASS

# Gate 1 -- 角色 Runtime 回归
pwsh -File scripts\sync_game_content.ps1             # 5 item(s) copied, 0 skipped
pwsh -File tests\p4\run_matrix.ps1 -Only b_vs_a -RunSec 15   # PASS, crashlogs : 0 new

# Gate 2/4 -- inspect
python tools\sffctl\sffctl.py inspect game\chars\test_fighter_b\test_fighter_b.sff --limit 14
python tools\airtool\airtool.py inspect game\chars\test_fighter_b\test_fighter_b.air --action 1005

# Gate 3 -- export
python tools\sffctl\sffctl.py export game\chars\test_fighter_b\test_fighter_b.sff --out logs\p5\p6_ready --sprite 210,3 --sprite 1000,4 --overwrite
python tests\tools\check_export.py --sff game\chars\test_fighter_b\test_fighter_b.sff --out logs\p5\p6_ready

# Gate 5/6/8 -- validation and negative tests
python tools\airtool\airtool.py validate tests\fixtures\assets\dup_action.air
python tools\character_validate\validate_character.py game\chars\test_fighter_b --json

# Gate 10 -- 全部测试
pwsh -File scripts\test.ps1
pwsh -File scripts\test.ps1 -Full
python tests\fixtures\verify_decoders.py
python tests\fixtures\make_fixtures.py --check
```

---

## 4. 过程中发现的真实缺陷（P5 的第一个实际产出）

`airtool validate` 第一次跑 `test_fighter_b.air` 就报出：

```text
ERROR AIR_MISSING_SPRITE  action 410 element 4 references sprite 410,5
                          which does not exist in test_fighter_b.sff
```

- **判定依据**：Fighter B 的 SFF 是 KFM 容器（`410,0…410,4` 共 5 个）；Fighter A 的同一动作
  用的是 `410,0/1/3/4`；引擎自带 KFM 的原始 Action 410 也只有 `410,0…410,4`。
  所以 `410,5` 是笔误。
- **影响**：引擎记一条 missing sprite，并在那 5 tick 里**不画角色**（画面缺帧）；
  判定框本身不受影响 —— 这就是 P4 的 Runtime 测试没能暴露它的原因。
- **处置**：`.air` 注释声明"收招 11 tick（6+5）"，因此把该元素改成 `410,4`（延续收招姿势），
  **tick 数不变**；文件里留一行说明。属于最小内容修复，与本阶段工具开发分开描述，
  回退只需改回一个 token。
- **回归**：改后 `run_matrix -Only b_vs_a` PASS，`crashlogs : 0 new`（§2 Gate 1）。

---

## 5. 关键决策

| # | 决策 | 理由 |
| --- | --- | --- |
| 1 | 不复用引擎的 Go 解析器，改为"最小独立实现 + 忠实移植" | 引擎 SFF/AIR 解析器都在 `package main`，主仓无法导入；要么复制大量 Go 代码，要么给引擎加 CLI —— 后者违反"engine 只读"。移植出处逐条写进模块 docstring。 |
| 2 | 纯标准库，不引入 Pillow/numpy | PNG 只需 zlib；避免"可选依赖缺失导致 `scripts/test.ps1` 整体失效"（合同 §33）。 |
| 3 | 不做 SFF 写回 | P6 是否需要写回要等正式素材流程确定，提前做 writer 是纯负债（合同 §18）。 |
| 4 | 删掉"角色应该有哪些动画"的规则 | 第一版硬编码清单直接把 `_template` 判错，而模板**本来就故意**不实现蹲姿（P2 范围声明）。规则改为只检查"角色自己的脚本要什么"。 |
| 5 | 不把引擎公共状态索要的动画当必需 | 对照 `data/common1.cns.zss`：多数请求被 `selfAnimExist(...)` 保护（175/190/5030/5050/5500），或位于引擎标注 `Deprecated in DosMugen` 的状态（110/115）。报出来会给每个角色加 9 条无法处理的警告 —— 会让验证器失去可信度。 |
| 6 | `AIR_HURTBOX_GAP` 用 WARNING 而不是 ERROR | 三个现有角色各有 3 条，是真实的语义缺口但不是"角色不能用"；ERROR 会宣称现有角色不合格，不诚实。 |
| 7 | 判定框作用域按引擎源码实现，而不是按仓库注释 | `anim.go:311-364` 的 `def1/def2` 复位语义 + P4 的 Runtime A/B 实测一致；仓库注释里"沿用到下一次声明"的说法不准确。**只记录不改注释**（工具 PR 不顺手改三个角色的文档文案）。 |
| 8 | 测试夹具必须自己造 SFF | 真实容器是占位素材，没有任何地方记录过"每个像素应该是什么"，无法据以断言解码正确。合成夹具让"索引 + 调色板 → RGBA"的逐字节断言成为可能；`make_fixtures.py` 是全仓库唯一写 SFF 的地方，且明确标注为测试夹具。 |
| 9 | `scripts/test.ps1` 默认同时跑 smoke + tools，重活放 `-Full` | 合同 §59：`character_validate` 这类静态检查适合进默认回归，`export-all` 不适合每次跑。实测 tools 套件约 4 s，`-Full` 约 22 s。 |
| 10 | 用"引擎自己的解码器逐字节对照"替代"人眼看拼图"作为解码正确性的主证据；对照用的 Go 程序**不提交** | 拼图只能判断"像不像"，不可机器复核。照抄 `Lz5Decode` 做对照可以。不提交是因为它是引擎代码副本，且不该让 Go 进项目依赖表 —— 重建方法（约 5 分钟）写进了证据文件。 |
| 11 | 链接精灵（`data_size == 0`）按引擎 `shareCopy` 顺着 `link` 解析；`link` 越界时留空并告警，而不是让整个容器读不了 | 真实容器有 41/282 个链接精灵（50xx 受击/倒地区间）—— 不处理的话，导出会得到一堆空文件或报错。引擎对 `link` 越界的处理是"无贴图"，工具照做并告警。 |

---

## 6. 交付物清单与 Git 状态

```text
tools/kofassets/{__init__,pngio,sff,air,chardef,checks,report}.py   只读解析库（纯标准库）
tools/sffctl/sffctl.py                    inspect / export / montage
tools/airtool/airtool.py                  inspect / validate
tools/character_validate/validate_character.py
tests/fixtures/make_fixtures.py           夹具生成器（唯一写 SFF 的地方，测试专用）
tests/fixtures/verify_decoders.py         逐像素断言 + golden 回归 + 链接/空白精灵
tests/fixtures/expected/decoder_goldens.json
tests/fixtures/assets/**                  39 个生成夹具
tests/fixtures/README.md                  夹具来源 / 用途 / License
tests/tools/check_export.py               导出 PNG 的独立回读校验
tests/tools/run_tool_tests.ps1            65 项工具测试（-Full 70 项）
scripts/test.ps1                          接入 tools 套件
docs/character_asset_tooling.md           工具手册
docs/P5-summary.md                        交接说明
docs/phase_reports/P5-character-asset-tooling.md   本文件
docs/evidence/p5/*.txt                    7 份原始输出
docs/iterations/20260929-p5-character-asset-tooling.md
docs/development_status.md                P5 = PASS, P6 = NEXT
README.md                                 当前阶段 / tools / 测试入口
game/chars/test_fighter_b/test_fighter_b.air   410,5 → 410,4（+1 行注释）
```

收尾时的 `git status` / `git diff --stat` 与最终 commit 见
[`docs/P5-summary.md`](../P5-summary.md) §15。

**未修改**：`engine/ikemen-go`（submodule 指针与内容都没动）、其他角色文件、`scripts/build_engine.ps1` /
`run_game.ps1` / `sync_game_content.ps1`、`tests/p1..p4` 的全部 harness。

---

## 7. 已知限制与遗留事项

| # | 事项 | 影响 | 归属 |
| --- | --- | --- | --- |
| 1 | 不支持 SFF v1（引擎能加载） | 仓库里的 v1 文件是 P1 实验角色的 `intro.sff` / `ending.sff`，不属于 P5 目标；遇到会**明确报 4** 而不是误解码 | 需要时再做 |
| 2 | 不支持 raw 真彩精灵（format 0 / depth 24、32） | 本仓库没有任何素材用它；字节序无法从项目数据验证，宁可不做 | 需要时再做 |
| 3 | 三个角色各有 3 条 `AIR_HURTBOX_GAP`（Action 210/230/820） | 那几 tick 角色没有受击框（继承 `_template` 的写法）。对现有玩法无可测影响（P4 六组对局全绿）；**不是 P5 引入的回归** | P6：改用 `Clsn2Default` |
| 4 | `.air` 注释里"`Clsn1` 沿用到下一次声明"与引擎语义不符 | 会误导 P6 作者。本次只记录未改（改的是三个角色的真值文件） | P6 或单独一个 docs PR |
| 5 | "逐帧 `Clsn` 只作用于一个元素"对 `Clsn2` 没有单独做 Runtime A/B | 两者走同一段解析代码（`def1`/`def2`），按同一结论处理 | 有疑问时优先怀疑这条假设 |
| 6 | 不支持 SFF 写回 / AIR 编辑 / SND / 调色板编辑 / GUI / 精灵表切割 / AI 生成精灵 | 都是刻意不做 | 需求出现再评估 |
| 7 | P1–P3 文档中"读截图得来的数值"仍未复核（P4 遗留项 #8） | 与本阶段无关，未因此阻塞 P5 | 后续窗口用 `tools/read_frame_text.py` 回扫 |

---

## 8. 对下一阶段（P6）的输入

1. **工具可用**：`python tools\character_validate\validate_character.py <角色目录>` 是 P6 的第一条命令；
   任何 ERROR 都不该带进 Runtime。
2. **判定框语义**：新写 AIR 时，需要覆盖整个动画的框用 `Clsn*Default`；逐帧框只覆盖一个元素
   （见工具手册 §5）。这是本阶段最需要 P6 记住的一条。
3. **素材正确性判据**：`montage` 拼图看人形 + `check_export.py` 逐像素对照。
4. **正式第三方资产**必须登记 `assets/LICENSE_MANIFEST.csv`（现有 CSV 粒度已够用）。
5. **工具优先于引擎**：P6 遇到"工具查不出来"的需求，先在 `tools/` 里补，不要动 `engine/ikemen-go`
   （本阶段已验证：**做角色/查角色完全不需要改引擎**）。
6. **出图前的临时导出**放 `logs/`（已 gitignore），不要把 KFM 占位素材导出的 PNG 提交进仓库。

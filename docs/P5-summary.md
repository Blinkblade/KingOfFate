# P5 阶段性总结（Phase 5 Summary & Handoff）

| | |
| --- | --- |
| **阶段** | P5 — Character Asset Tooling |
| **状态** | **PASS**（Gate 1–10 全部通过） |
| **时间** | 2026-09-29 |
| **分支** | `feature/p5-character-asset-tooling` |
| **基线** | `main` @ `e279e96`（PR #6 合并 P4） |
| **引擎** | `ba516193`（`v1.0.0-rc.5`）—— **全程未修改**，submodule 指针未动 |
| **详细报告** | [`docs/phase_reports/P5-character-asset-tooling.md`](phase_reports/P5-character-asset-tooling.md) |
| **过程记录** | [`docs/iterations/20260929-p5-character-asset-tooling.md`](iterations/20260929-p5-character-asset-tooling.md) |
| **工具手册** | [`docs/character_asset_tooling.md`](character_asset_tooling.md) |
| **原始证据** | [`docs/evidence/p5/`](evidence/p5/) |

> 与 Phase Report 的分工同 P1–P4：Phase Report 是**逐条 Gate 的证据档案**，本文是
> **总览 + 交接说明**。两者冲突时以 Phase Report 为准。

---

## 1. 一句话结论

**P6 拿到一套新素材后，不需要进游戏就能知道：SFF 里有什么、精灵长什么样、
AIR 怎么引用精灵、哪里引用错了、这个角色够不够格进 Runtime。**

而且这套工具是在**完全没有改引擎**的前提下建起来的。

---

## 2. 工具清单

| 工具 | 命令 | 作用 |
| --- | --- | --- |
| sffctl | `python tools\sffctl\sffctl.py inspect / export / montage` | SFF 结构、精灵导出、拼图 |
| airtool | `python tools\airtool\airtool.py inspect / validate` | 动画表读取与静态校验 |
| validate_character | `python tools\character_validate\validate_character.py <目录\|.def>` | 角色级验证（文件引用 + AIR↔SFF + 脚本↔AIR） |
| asset_report | `python tools\asset_report.py <目录\|.def>` | **一条命令出完整报告**：按顺序调用上面三件 + 独立回读校验，攻击动作与 `-1` 保持动作自动选入明细 |
| （共享库） | `tools/kofassets/` | 只读解析库，三件工具共用同一套规则与语义 |

所有工具：**只读**、**默认不覆盖**、**有明确退出码**、**纯标准库**。

---

## 3. 常用命令（可直接复制）

```powershell
# ★ 一条命令出完整报告（P6 拿到新素材先跑这个）
python tools\asset_report.py game\chars\test_fighter_b --out logs\p5\report --montage

# 也可以把报告写成文件存档
python tools\asset_report.py <角色> --out logs\p5\report --report docs\evidence\p6\xxx.txt

# 单件工具（asset_report 内部就是按这个顺序调它们的）
python tools\character_validate\validate_character.py game\chars\test_fighter_b
python tools\sffctl\sffctl.py inspect <sff> --limit 20
python tools\sffctl\sffctl.py export <sff> --out logs\p5\export_all
python tools\sffctl\sffctl.py montage <sff> --out logs\p5\montage.png --columns 16
python tests\tools\check_export.py --sff <sff> --out logs\p5\export_all
python tools\airtool\airtool.py inspect <air> --action 210
python tools\airtool\airtool.py validate <air>

# 全部测试
pwsh -File scripts\test.ps1            # smoke + 工具测试
pwsh -File scripts\test.ps1 -Full      # 额外导出 282 个精灵并拼图
```

---

## 4. 支持范围（老实说清楚）

| 项 | 支持 | 不支持 |
| --- | --- | --- |
| **SFF** | **v2**（本仓库四个容器都是 `2.0.1.0`，282 精灵 / 16 调色板） | v1（报退出码 4，不下沉为"损坏"） |
| **精灵格式** | `4` LZ5（本仓库 280/282）、`10` PNG 索引（2/282）、`2` RLE8、`3` RLE5、`0` raw(8) | `0` raw 真彩（depth 24/32）、隔行 PNG |
| **调色板** | v2 调色板表、链接调色板、重复键、每色 RGBA | 调色板编辑、ACT 文件 |
| **PNG** | 写 8-bit RGBA（filter 0、无隔行） | 其他 PNG 写法 |
| **AIR** | Action / 元素 / 时间 / `-1` / flip / blend / scale / angle / `loopstart` / `copy action` / `interpolate *` / `Clsn1`、`Clsn2`、`Clsn1Default`、`Clsn2Default` | AIR 编辑与自动修复 |
| **角色** | `.def` + `[Files]` 路径解析（含引擎 `data/` 回退） | 完整 ZSS/CNS 语义解析（只做**字面量**动画引用扫描） |
| **导出** | PNG（名字固定 `<group>_<image>.png`） | 写回 SFF / 替换精灵 / 新增精灵 / 重建 SFF |

---

## 5. Sprite Export 能力边界

**能**：单个 / 多个 / 全部导出；确定性命名；默认不覆盖；输出目录必填（从不默认写进角色目录）；
`--palette N` 可强制调色板（默认用精灵自己的 `palette_index`，与引擎 `Sprite.GetPal` 一致）。

**验证过**：尺寸与 SFF 元数据一致、透明像素逐字节正确（用夹具做已知输入断言）、
每个精灵都不是全透明、两次导出 **SHA256 逐文件相同**、导出后从磁盘回读逐像素对照。

**★ 解码本身与引擎逐字节一致（不是"看着像"）**：把引擎 `image.go:1209` 的
`Sprite.Lz5Decode` 逐字照抄成一份临时 Go 程序，对四个容器的每个精灵解码取哈希，
与 `tools/kofassets/sff.py` 比对 —— **1128 个精灵，0 处不一致**
（其中 280/282 走 LZ5、2/282 走 PNG 索引、41/282 是链接精灵）。
方法与复现步骤：[`docs/evidence/p5/engine_decoder_crosscheck.txt`](evidence/p5/engine_decoder_crosscheck.txt)。

**没有声称**：与 IKEMEN 的画面"100% 一致"。缩放 / palFX / blend / 可选调色板都是
Runtime 的事，不在导出范围内；导出做的是"精灵原始像素 + 该精灵自己的调色板"。
（对照用的 Go 程序**刻意不提交**：它是引擎代码副本，且不该让 Go 进项目依赖表。）

---

## 6. Validation 能力（错误码 → 含义）

| 代码 | 级别 | 含义 |
| --- | --- | --- |
| `AIR_DUPLICATE_ACTION` | ERROR | 同一 Action 号定义两次（引擎只用第一个） |
| `AIR_EMPTY_ACTION` | ERROR | 空 Action（引擎会静默复制文件里下一个 Action） |
| `AIR_BAD_TIME` | ERROR/WARNING | `time < -1`；`time = 0`；`-1` 后面还有元素 |
| `AIR_BOX_COUNT_MISMATCH` | ERROR | 声明 N 个框、实际少了 |
| `AIR_ORPHAN_BOX_LINE` | WARNING | 没有声明的 `ClsnX[i]` 行（引擎忽略） |
| `AIR_MISSING_SPRITE` | ERROR | 引用了 SFF 里不存在的精灵 |
| `AIR_ATTACK_NOT_PERSISTENT` | WARNING | 逐帧攻击框 + `-1` 保持帧无框（**P4 的投射物坑**） |
| `AIR_ATTACK_PERSISTENT` | INFO | `-1` 保持帧上的框来自 `Clsn1Default`（投射物正确写法） |
| `AIR_HURTBOX_GAP` | WARNING | 同一 Action 内受击框时有时无（那几 tick 打不到） |
| `AIR_NO_HURTBOX` | INFO | 整个 Action 没有受击框（通常是故意的） |
| `AIR_DEGENERATE_BOX` | WARNING | 零面积判定框 |
| `AIR_BOX_OUT_OF_RANGE` | WARNING | 判定框坐标远超角色体型 |
| `AIR_ELEMENT_PROBLEM` | ERROR | 元素行本身非法 |
| `ZSS_MISSING_ACTION` | ERROR | 脚本里字面量引用的动画在 `.air` 里不存在 |
| `DEF_UNRESOLVED_FILE` | ERROR/WARNING | `[Files]` 指向的文件找不到 |
| `DEF_FILE_OUTSIDE_CHARACTER` | ERROR | 角色的核心文件解析到了角色目录之外（不可移植） |
| `SFF_UNSUPPORTED` | ERROR | SFF 版本不支持 |
| `SFF_CORRUPT` | ERROR | SFF 数据损坏/截断 |

---

## 7. CLI 退出码

```text
0  OK            没有高于 INFO 的发现
1  FINDINGS      至少一个 ERROR（--strict 时 WARNING 也算）
2  USAGE         命令行参数错误
3  IO            输入文件不存在 / 路径是目录 / 找不到 .def
4  UNSUPPORTED   格式在支持范围之外（SFF v1、raw 真彩）
5  CORRUPT       格式对但数据坏了（截断、签名错、越界）
```

`validate_character` 的 `verdict` 行：`PASS`（无警告）/ `WARN`（只有警告，退出码仍 0）/ `FAIL`（有错误）。

---

## 8. 依赖

```text
Python 3.8+，只用标准库（struct / zlib / json / argparse / re / hashlib / os / sys）
```

**零第三方依赖**（不要 Pillow、不要 numpy）。不需要 IDE、不需要 Fighter Factory、不需要 GUI。
所有命令都能从仓库根目录用相对路径运行。

`tools/read_frame_text.py`（P4 的工具）仍然需要 numpy + Pillow；**P5 的工具不需要**。

---

## 9. 测试

| 命令 | 内容 | 实测结果 |
| --- | --- | --- |
| `pwsh -File scripts\test.ps1` | smoke（26）+ tools（69） | **PASS** |
| `pwsh -File scripts\test.ps1 -Full` | tools 74 项（含 282 个精灵全导出 + montage 确定性 + asset_report 报告断言） | **PASS**，33.3 s |
| `python tests\fixtures\verify_decoders.py` | 夹具逐像素相等 + 真实容器 golden + 全精灵解码 + 链接/空白精灵 | **48/48 PASS** |
| `python tests\fixtures\make_fixtures.py --check` | 夹具与生成器一致 | 39 文件 0 问题 |
| 引擎解码器逐字节对照 | 1128 个精灵 vs 引擎自己的 `Lz5Decode` | **0 处不一致** |
| `pwsh -File tests\p4\run_matrix.ps1 -Only b_vs_a` | Runtime 回归 | PASS，`crashlogs : 0 new` |

---

## 10. Fixtures（写给下一个窗口）

```text
tests/fixtures/
├── make_fixtures.py           生成/校验夹具（仓库里唯一写 SFF 的地方，测试专用）
├── verify_decoders.py         逐像素断言 + golden 哈希回归
├── expected/decoder_goldens.json
└── assets/                    36 个生成文件
    ├── minimal_v2.sff         3 精灵（raw / LZ5 / 非方形 raw），已知索引 + 已知调色板
    ├── unsupported_v1.sff     合法 SFF v1，用来验证"不支持"的报错路径
    ├── truncated.sff          头部声明超出文件长度
    ├── bad_signature.sff
    ├── ok.air + ok.sff        干净的动画表（airtool 的 happy path，自动找同目录 SFF）
    ├── dup_action.air / empty_action.air / bad_box_count.air / orphan_box.air
    ├── missing_sprite.air / bad_time.air
    ├── p4_per_frame_hold.air  ★ P4 反例：逐帧 Clsn1 + -1 保持帧
    ├── p4_default_hold.air    ★ P4 正例：Clsn1Default + -1 保持帧
    └── char_ok/ char_missing_files/ char_zss_missing_anim/ char_v1_sprite/
```

**来源与 License**：全部由 `make_fixtures.py` 用 16 个纯色自己合成，
**没有任何第三方素材**，可以自由提交。见 [`tests/fixtures/README.md`](../tests/fixtures/README.md)。

---

## 11. 已知限制（P6 需要知道的）

1. **不支持 SFF v1** 与 **raw 真彩精灵**（本仓库没有素材用它们）。遇到会明确报错，不会误解码。
2. **不做写回**：没有 SFF writer、不能替换/新增精灵、不能编辑 AIR、不能自动修复。
   —— 这是刻意留白，等 P6 的素材流程确定后再判断是否需要。
3. 三个现有角色各有 **3 条 `AIR_HURTBOX_GAP`**（Action 210 / 230 / 820，继承 `_template` 写法）。
   是真实的语义缺口，对现有玩法无可测影响，**不是 P5 的回归**；P6 用 `Clsn2Default` 即可避免。
4. `.air` 注释里"`Clsn1` 会沿用到下一次声明"**与引擎语义不符**（只覆盖紧邻的一个元素）。
   本次只记录未改注释 —— P6 写新动画时不要照那句话做。
5. 判定框作用域结论的来源是引擎源码 + P4 对 `Clsn1` 的 Runtime A/B 实测；
   对 `Clsn2` 没有单独实测（同一段解析代码，按同一结论处理）。
6. **每个容器有 41/282 个"链接精灵"**（`data_size == 0`，复用 `link` 指向的前一个精灵的
   像素，全部在 50xx 受击/倒地区间）。工具顺着 `link` 解析，所以导出它们得到正常 PNG；
   但如果你换素材时只替换"有字节的精灵"，这些共享像素的精灵不会跟着变 —— 留意。
7. 不做 SND、调色板编辑、精灵表切割、AI 生成精灵、GUI、数据库。

---

## 12. P6 推荐使用流程

```text
新素材到位
  → 1. character_validate          文件齐不齐、引用对不对（ERROR 必须清零）
  → 2. sffctl inspect              版本/数量/尺寸/原点符合预期吗
  → 3. sffctl montage + 肉眼       解码、调色板、透明正常吗
  → 4. airtool inspect             每个动作的 tick、判定框作用域
  → 5. airtool validate            引用缺失、判定框作用域、受击框缺口
  → 6. scripts\sync_game_content.ps1
  → 7. tests\p3\run_match_watch.ps1 （或 p4\run_matrix.ps1）
```

静态检查**不能替代 Runtime**；Runtime 也查不出"引用不存在的精灵"这类必然错。
两者结合才是完整判据。

**一条必须记住的领域知识**：

```text
Clsn1: N          → 只作用于紧跟的那 1 个元素
Clsn1Default: N   → 作用于该 Action 的每一个元素（投射物必须用这个）
```

---

## 13. 哪些能力明确没做（不要以为是漏了）

```text
SFF 写回 / 重建            AIR 编辑 / 自动修复         SND 导出与检查
调色板编辑器               精灵表自动切割              GUI / 数据库 / 时间轴
AI 生成精灵 / Img2Img      正式角色美术 / VFX / 音频   角色平衡 / Utility AI
```

判断标准只有一条：**"P6 现在就需要"** 才做。

---

## 14. 本阶段的实际产出

除了工具本身，P5 第一次运行就在**现有内容里查出一处真实缺陷**：
`test_fighter_b.air` 的 Action 410 引用了不存在的精灵 `410,5`
（引擎会记 missing sprite 并在那 5 tick 里不画角色）。已按注释声明的收招长度改成 `410,4`，
tick 数不变，并有 Runtime 回归证据（`crashlogs : 0 new`）。
详见 Phase Report §4。

---

## 15. Git 收尾

```text
分支  : feature/p5-character-asset-tooling     （已推送 origin，与远端同步）
基线  : main @ e279e96（PR #6 合并 P4）
子模块: engine/ikemen-go @ ba516193（未改动，指针未动）

两个实质提交（其余都是文档）：
  60dfee1  fix: correct a missing sprite reference in test_fighter_b action 410
                 1 file changed, 5 insertions(+), 1 deletion(-)
  77deb1c  tool: add character asset inspection, export and validation tools
                 69 files changed, 6989 insertions(+), 53 deletions(-)
  1f402b1  tool: resolve linked sprites, and keep blank ones non-fatal
                 7 files changed, 131 insertions(+), 11 deletions(-)

完整提交列表以 `git log feature/p5-character-asset-tooling` 为准（tip 51e7314）；
本节不逐个回填哈希，避免"哈希一变文档就过时"。
本机 push 需要本地代理 http://127.0.0.1:7897 —— 不带代理时 GitHub 会在 send-pack
阶段直接掐断连接，报 curl 52 / curl 56。
```

`git status` 收尾状态：工作树 clean；改动集**只有**下列内容，没有导出 PNG、
没有 `logs/`、没有引擎改动：

```text
M  README.md                                  M  scripts/test.ps1
M  docs/development_status.md                 A  .gitattributes
M  game/chars/test_fighter_b/test_fighter_b.air
A  tools/{kofassets,sffctl,airtool,character_validate}/**
A  tests/fixtures/**（36 个生成夹具 + 生成器 + 校验器 + goldens + README）
A  tests/tools/{check_export.py,run_tool_tests.ps1}
A  docs/{character_asset_tooling.md,P5-summary.md}
A  docs/phase_reports/P5-character-asset-tooling.md
A  docs/iterations/20260929-p5-character-asset-tooling.md
A  docs/evidence/p5/**
```

**创建 PR（本机无 `gh`，需手动开）**：PR 标题与可直接粘贴的正文见 §16。

```text
https://github.com/Blinkblade/KingOfFate/pull/new/feature/p5-character-asset-tooling
```

**PR 标题建议**：`P5: Character Asset Tooling（角色资产工具链）`

**PR 正文**：见 §16（可直接粘贴）。

---

## 16. PR 标题与正文（可直接粘贴）

**标题**

```text
P5: Character Asset Tooling（角色资产工具链）
```

**正文**

````text
## 一句话

为 P6 准备好"拿到一套新素材后不用进游戏就能看清它"的最小工具链：读 SFF、导出精灵、
读并校验动画表、判断角色目录能不能进 Runtime。全部只读、纯标准库、有明确退出码。
**引擎子模块全程未改动**（仍 pin 在 ba516193 / v1.0.0-rc.5）。

## 为什么

P6 是第一个正式美术角色。在此之前，"这套 SFF/AIR 里到底有什么、引用对不对、动画
怎么引用精灵"只能靠进游戏试。P5 把这几件事变成可离线、可重复、可自动检查的命令。

## 新增

- tools/kofassets/  只读解析库（sff / air / chardef / checks / report / pngio），
  解析算法逐行移植自 engine/ikemen-go/src/{image,anim}.go，并补上引擎没有的边界检查
- tools/sffctl/sffctl.py              inspect / export / montage
- tools/airtool/airtool.py            inspect / validate
- tools/character_validate/validate_character.py
- tools/asset_report.py               ★ 一条命令跑完整个工作流并出报告
- tests/fixtures/                     39 个合成夹具 + 生成器 + 解码校验器 + goldens
- tests/tools/run_tool_tests.ps1      + check_export.py（导出后从磁盘回读逐像素对照）
- docs/character_asset_tooling.md（工具手册）、docs/P5-summary.md、docs/phase_reports/
  P5-character-asset-tooling.md、docs/evidence/p5/（11 份原始输出）

修改：scripts/test.ps1（现在跑 smoke + tools 两个套件）、README.md、
docs/development_status.md、.gitignore（精简，见下）、.gitattributes（新增）、
game/chars/test_fighter_b/test_fighter_b.air（修一处真实缺陷，见下）。

## 能力

| 工具 | 作用 |
| --- | --- |
| sffctl | SFF 版本/精灵数/尺寸/原点/格式/调色板；导出 PNG（`<group>_<image>.png`，默认不覆盖，目录必填）；拼图供人眼核对 |
| airtool | Action/元素/tick/`-1`/判定框；13 条规则（引用缺失、重复 Action、判定框作用域、受击框缺口…） |
| validate_character | 文件完整性 + AIR→SFF 精灵引用 + 脚本→AIR 字面量动画引用 + 判定框语义，逐项给结论 |
| asset_report | 按顺序调用上面三件 + 回读校验，每步把命令行和输出写进一份报告 |

退出码：0 OK / 1 有 ERROR / 2 用法 / 3 IO / 4 不支持（SFF v1、raw 真彩）/ 5 损坏。
**4 与 5 刻意分开**："我不支持"和"这个文件坏了"是两件事。

## Exit Gate（10 条全过，详见 Phase Report §2）

| Gate | 结果 | 关键证据 |
| --- | --- | --- |
| 1 基线 | PASS | test.ps1 26/26；run_matrix -Only b_vs_a PASS，crashlogs : 0 new |
| 2 SFF Inspect | PASS | 三个角色均 2.0.1.0 / 282 精灵 / 16 调色板 |
| 3 Sprite Export | PASS | 282 个精灵导出并逐像素回读；**解码与引擎逐字节对照 1128 个精灵 0 处不一致** |
| 4 AIR Inspect | PASS | Action/元素/tick/`-1`/Default collision，三个角色各跑通 |
| 5 Animation Validation | PASS | 缺精灵、重复 Action、框数不符、非法时间 → ERROR；孤立框行 → WARNING |
| 6 P4 投射物案例 | PASS | 正例（Clsn1Default）不报、反例（逐帧 Clsn1）报，并在数据层断言 mode/count 不同 |
| 7 Character Validation | PASS | _template / A / B 三个都是 errors 0、退出码 0 |
| 8 负例 | PASS | 缺文件 3 / 不支持 4 / 截断与坏签名 5 / 用法 2，都不崩溃、不挂死 |
| 9 P6 Ready 端到端 | PASS | 9 步全 exit 0，工具读数与角色帧数据表逐项吻合（210=33 tick、判定到 x=105…） |
| 10 回归与文档 | PASS | test.ps1：smoke 26/26 + tools 69/69（`-Full` 74/74） |

## 怎么验证

```powershell
pwsh -File scripts\test.ps1            # smoke 26/26 + tools 69/69
pwsh -File scripts\test.ps1 -Full      # + 282 精灵全导出、montage 确定性（约 33 s）
python tests\fixtures\verify_decoders.py   # 48/48（夹具逐像素相等 + golden + 链接/空白精灵）
python tools\asset_report.py game\chars\test_fighter_b --out logs\p5\report --montage
```

需要 Python 3.8+，**无第三方依赖**。

## 关键决策

1. **不复用引擎的 Go 解析器**（都在 package main，主仓无法导入；给引擎加 CLI 违反
   "engine 只读"）→ 最小独立实现 + 忠实移植，出处写进每个模块 docstring。
2. **纯标准库**（PNG 只靠 zlib），避免可选依赖让 scripts/test.ps1 整体失效。
3. **不做 SFF 写回 / AIR 编辑**：P6 是否需要等素材流程确定，提前做 writer 是负债。
4. **删掉了"角色应该有哪些动画"的硬编码清单**：它把 _template 判错（模板本来就
   没有蹲姿）。改为只检查"角色自己的脚本要什么"。
5. **不把引擎公共状态索要的动画当必需**：多数有 selfAnimExist 保护或位于引擎标注
   Deprecated 的状态，报出来只会让每个角色多 9 条无法处理的警告。
6. **用"与引擎解码器逐字节对照"替代"人眼看拼图"**作为解码正确性的主证据
   （1128 精灵 0 处不一致）；对照用的 Go 程序刻意不提交（引擎代码副本 + 不让 Go
   进依赖表），重建方法写在 docs/evidence/p5/engine_decoder_crosscheck.txt。

## 顺带查出并修掉的既有缺陷

test_fighter_b.air 的 Action 410（对空 Normal）第 4 个元素引用精灵 410,5，
占位 SFF（KFM 容器）只有 410,0…410,4 → 引擎记 missing sprite 并在那 5 tick 不画角色。
按注释声明的"收招 11 tick"改成 410,4，tick 数不变。Runtime 回归 crashlogs : 0 new。

## 已知限制（不影响合并）

- 不支持 SFF v1 与 raw 真彩精灵（遇到明确报错，不误解码）；本仓库无素材使用。
- 三个角色各有 3 条 AIR_HURTBOX_GAP 警告（Action 210/230/820，继承 _template 写法），
  是真实的语义缺口但对现有玩法无可测影响，**不是本次引入的回归**，P6 用 Clsn2Default 即可。
- .air 注释里"Clsn1 沿用到下一次声明"与引擎语义不符（逐帧只覆盖紧邻一个元素），
  本次**只记录未改注释**，列入遗留。
- 判定框作用域结论来自引擎源码 + P4 对 Clsn1 的 Runtime A/B；对 Clsn2 未单独实测。
- P4 遗留项（P1–P3 中"读截图得来的数值"复核）仍未做，不阻塞本阶段。

## 合并前 checklist

- [ ] scripts/test.ps1 通过（26/26 + 69/69）
- [ ] 引擎子模块未改动（git submodule status 显示 ba516193，无 + 号）
- [ ] 工作树无导出 PNG / logs 残留（logs/ 已 gitignore）
- [ ] docs/development_status.md 显示 P5 = PASS、P6 = NEXT
````


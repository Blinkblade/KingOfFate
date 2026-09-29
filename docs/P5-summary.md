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

**创建 PR（本机无 `gh`，需手动开）**：

```text
https://github.com/Blinkblade/KingOfFate/pull/new/feature/p5-character-asset-tooling
```

**PR 标题建议**：`P5: Character Asset Tooling（角色资产工具链）`

**PR 正文**：与 Phase Report §2（逐 Gate 证据）、§4（发现的缺陷）、§5（关键决策）同源，
可直接复制。


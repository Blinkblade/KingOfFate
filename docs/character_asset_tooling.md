# Character Asset Tooling（P5）

> 这套工具是为了 P6 而建的：拿到一套新的 Sprite / SFF / AIR 之后，**能看出里面有什么、
> 能把精灵导出来、能知道动画怎么引用精灵、能在进游戏之前发现引用与动画错误**。
>
> 全部工具都是**只读**的。它们报告问题，不修问题。

- 阶段报告：[`phase_reports/P5-character-asset-tooling.md`](phase_reports/P5-character-asset-tooling.md)
- 过程记录：[`iterations/20260929-p5-character-asset-tooling.md`](iterations/20260929-p5-character-asset-tooling.md)
- 交接说明：[`P5-summary.md`](P5-summary.md)
- 端到端演练原始输出：[`evidence/p5/p6_ready_run.txt`](evidence/p5/p6_ready_run.txt)

---

## 1. 一句话说明每个工具

| 工具 | 命令 | 回答的问题 |
| --- | --- | --- |
| **sffctl** | `python tools/sffctl/sffctl.py` | SFF 里有什么？每个精灵多大、原点在哪、什么格式？把它导成 PNG。 |
| **airtool** | `python tools/airtool/airtool.py` | 这个 `.air` 有多少 Action、每个 Action 有几个元素、持续多少 tick、判定框在哪一帧生效？ |
| **validate_character** | `python tools/character_validate/validate_character.py` | 这个角色目录完整吗？引用都对得上吗？能不能进 Runtime？ |
| **asset_report** | `python tools/asset_report.py` | 上面那一整套跑一遍是什么结果？一条命令，输出一份带命令行的报告。 |

三者共享一个只用标准库的小解析库 `tools/kofassets/`（见 §8）；`asset_report` 不加
任何自己的逻辑，它只是按固定顺序调用上面三件 + `check_export`，把每步的命令行与
输出写进一份报告——所以报告永远不可能和单件工具自己说的不一致。

---

## 2. 安装要求

```text
Python 3.8 或更高（只用标准库：struct / zlib / json / argparse / re / hashlib）
```

**没有第三方依赖，不需要 Pillow，也不需要 numpy。** 这一点是刻意的：这套工具要能在
任何能跑项目测试的机器上跑，`tools/read_frame_text.py` 那种"需要 Pillow 才可用"的
情况不能发生在 P5 工具上（见 §11 的决策记录）。

不需要 IDE、不需要 Fighter Factory、不需要图形界面。所有命令都能从仓库根目录运行，
路径可以是相对的。

---

## 3. sffctl

### 3.1 inspect —— 读出容器结构

```powershell
python tools\sffctl\sffctl.py inspect game\chars\test_fighter_b\test_fighter_b.sff
python tools\sffctl\sffctl.py inspect <sff> --limit 20        # 只列前 20 个精灵
python tools\sffctl\sffctl.py inspect <sff> --json            # 机器可读
python tools\sffctl\sffctl.py inspect <sff> --no-palettes     # 不列调色板表
```

输出包含：文件大小、**SFF 版本**、**精灵总数**、去重后的 `(group,image)` 键数量、
调色板数量、lofs/tofs，然后是每个精灵的
`index / group / image / width / height / axis_x / axis_y / format / colour depth / palette`，
最后是调色板表。

`--json` 的字段（节选）：

```json
{
  "version": "2.0.1.0",
  "sprite_count": 282,
  "palette_count": 16,
  "sprites": [
    { "index": 3, "group": 0, "image": 0, "width": 47, "height": 106,
      "axis_x": 18, "axis_y": 105, "format": "lz5", "colour_depth": 5,
      "palette_index": 0, "data_offset": 9198, "data_size": 1018 }
  ]
}
```

### 3.2 export —— 导出 PNG

```powershell
# 全部精灵
python tools\sffctl\sffctl.py export <sff> --out logs\p5\export_all

# 指定精灵（可重复）
python tools\sffctl\sffctl.py export <sff> --out logs\p5\export_two --sprite 210,3 --sprite 1000,4

# 覆盖已有文件（默认拒绝覆盖）
python tools\sffctl\sffctl.py export <sff> --out DIR --overwrite

# 强制用某个调色板
python tools\sffctl\sffctl.py export <sff> --out DIR --palette 1
```

规则：

- **输出目录必须显式给**（`--out` 是必填），永远不会默认写进角色目录。
- **默认不覆盖**：目标文件已存在 → 报 `SFF_EXPORT_NO_OVERWRITE`，退出码 1，
  提示你加 `--overwrite`。
- 文件名是**确定性的**：`<group>_<image>.png`，例如 `200_0.png`、`1000_4.png`。
- 默认调色板用**每个精灵自己的 `palette_index` 字段**——这正是引擎运行时
  `Sprite.GetPal` 的做法。要换调色板用 `--palette N`。
- 如果 `--out` 落在 `game/chars/` 里，工具会打印一行提醒（生产素材应该放 `assets/`），
  但不阻止。

### 3.3 montage —— 拼成一张图给人看

```powershell
python tools\sffctl\sffctl.py montage <sff> --out logs\p5\montage.png --columns 16 --scale 1
```

把全部精灵画进一张带棋盘格底的图，**透明区域一眼可见**。这是"导出对不对"的最终
人工判据：如果解码器错了，图会变成噪点，而不是人形。

---

## 4. airtool

### 4.1 inspect —— 读动画表

```powershell
python tools\airtool\airtool.py inspect <air>                       # 全表总览
python tools\airtool\airtool.py inspect <air> --action 210          # 单个 Action 明细
python tools\airtool\airtool.py inspect <air> --action 210 --action 1005
python tools\airtool\airtool.py inspect <air> --action 210 --json
```

总览列出每个 Action 的 `elements / ticks / duration / loopstart / clsn1 模式`。
单个 Action 明细列出每个元素：

```text
Action 210   (line 143)
  Elements:  8
  Duration:  33 ticks
  Infinite element: no
  Finite ticks: 33

   elem  sprite    x    y  time  clsn1        n  clsn2        n
   ----  ------  ---  ---  ----  -----------  -  -----------  -
      0  200,  0    0    0     4  none         0  per-frame    2
      4  210,  3    0    0     4  per-frame    2  per-frame    5
      5  210,  4    0    0     6  cleared      0  per-frame    3
    element 4 Clsn1: (30,-76,105,-56), (62,-72,98,-58)
```

约定：

- `ticks` = 所有**正数**元素时间之和；含 `-1` 保持帧的 Action 的 `duration` **写
  `infinite`**，不会伪造一个有限值。
- `clsn1` / `clsn2` 列是**该元素实际生效的模式**，取值：
  `default`（来自 `ClsnNDefault`）、`per-frame`（来自逐帧 `ClsnN:`）、
  `cleared`（前面显式写过 `ClsnN: 0`）、`none`（什么都没有）。
  这一列是排查判定框问题的主要依据，语义见 §5。

### 4.2 validate —— 静态检查

```powershell
python tools\airtool\airtool.py validate <air>                    # 自动找同目录同名 .sff
python tools\airtool\airtool.py validate <air> --sff <sff>        # 指定 SFF
python tools\airtool\airtool.py validate <air> --json
python tools\airtool\airtool.py validate <air> --strict            # 警告也算失败
```

检查项与代码：

| 代码 | 级别 | 含义 |
| --- | --- | --- |
| `AIR_DUPLICATE_ACTION` | ERROR | 同一 Action 号定义了两次。引擎只用第一个，后面的**静默丢弃**。 |
| `AIR_EMPTY_ACTION` | ERROR | Action 一个元素都没有。引擎不会保持为空——它会**静默复制文件里下一个 Action**。 |
| `AIR_BAD_TIME` | ERROR / WARNING | `time` 小于 `-1` 是 ERROR；`time = 0` 或异常大是 WARNING；`-1` 后面还有元素（永远到不了）是 WARNING。 |
| `AIR_BOX_COUNT_MISMATCH` | ERROR | `Clsn1: 3` 后面只跟了 2 行框；引擎读到非框行就停，多声明的那几个**丢失**。 |
| `AIR_ORPHAN_BOX_LINE` | WARNING | 一行 `ClsnX[i] = ...` 前面没有声明，引擎直接忽略。 |
| `AIR_MISSING_SPRITE` | ERROR | 元素指向 SFF 里不存在的 `group,image`。 |
| `AIR_ATTACK_NOT_PERSISTENT` | WARNING | 攻击框来自逐帧声明，而 `-1` 保持帧上没有攻击框 → 判定只有那么几 tick。**这正是 P4 投射物的坑**（见 §5）。 |
| `AIR_ATTACK_PERSISTENT` | INFO | `-1` 保持帧上的攻击框来自 `Clsn1Default`，整个保持期都有效（投射物该有的样子）。 |
| `AIR_HURTBOX_GAP` | WARNING | 同一 Action 里有些元素有受击框、有些没有 → 那几 tick 角色**打不到**。 |
| `AIR_NO_HURTBOX` | INFO | 整个 Action 都没有受击框（开场、胜利姿势等通常是故意的）。 |
| `AIR_DEGENERATE_BOX` | WARNING | 零面积的判定框。 |
| `AIR_BOX_OUT_OF_RANGE` | WARNING | 判定框坐标远超角色体型（疑似多打/少打一位数）。 |
| `AIR_ELEMENT_PROBLEM` | ERROR | 元素行本身有问题（字段不足、翻转标志非法、scale/angle 不是数字）。 |

**退出码**：有 ERROR → 1；只有 WARNING → 0（要严格用 `--strict`）。

---

## 5. ★ 判定框的作用域（这套工具最需要说清楚的一件事）

AIR 里两种写法**不是一回事**：

```text
Clsn1: 1                          ← 逐帧：只作用于紧跟的那 1 个元素
 Clsn1[0] = -40,-60, 40,60
200,0, 0,0, 4                     ← 这个元素有攻击框

Clsn1Default: 1                   ← 默认：作用于这个 Action 的每一个元素
 Clsn1[0] = -40,-60, 40,60
```

这不是传说，是解析器的直接结果：`engine/ikemen-go/src/anim.go:311-364` 里，`def1`/`def2`
标志被声明置为 false、**每读入一个元素行就复位为 true**。所以

- `Clsn1: N` 声明的框只留在"下一个元素"上；
- `Clsn1Default: N` 声明的框被每个元素重新继承，因此覆盖整个动画；
- 逐帧 `Clsn1: 0` 之后，后续元素回到默认（通常是空）。

P4 在 Runtime 上实测过这条（`docs/P4-summary.md` §3.1）：投射物动画是"一帧过渡 + 一帧
`-1` 保持"，只写逐帧 `Clsn1` 时，到 `-1` 帧攻击框就没了 —— **视觉正常但打不中人**；
改成 `Clsn1Default` 才成立。

> ⚠️ 仓库里 `_template.air` / `test_fighter_a.air` / `test_fighter_b.air` 的注释写的是
> "`Clsn1` 会一直沿用到下一次声明"。**按引擎源码和 P4 实测，这句话不准确**：
> 逐帧声明只覆盖紧邻的一个元素。这些文件目前没有因此出错（每个攻击动作都在判定帧之后
> 显式写了 `Clsn1: 0`，且判定帧本身就是那一个元素），但 P6 的作者不要按那句话写新动画。
> 本次 P5 **没有修改**这些注释（见 §11 与 P5 Summary 的遗留项）。

`airtool inspect` 把这件事变成可读的输出：每个元素都带
`default / per-frame / cleared / none` 标签。看 `Action 1005` 的两行都是 `default`，
就知道投射物的判定框在整个保持期都有效；换成 `per-frame` + 第二行 `none`，就是那个坑。

---

## 6. validate_character

```powershell
python tools\character_validate\validate_character.py game\chars\test_fighter_b
python tools\character_validate\validate_character.py game\chars\test_fighter_b\test_fighter_b.def
python tools\character_validate\validate_character.py game\chars\test_fighter_b --json
python tools\character_validate\validate_character.py game\chars\test_fighter_b --strict
```

输入可以是**角色目录**（自动找同名 `.def`）或 `.def` 文件本身。输出逐项给结论：

```text
Character: test_fighter_b

  DEF                 PASS  test_fighter_b.def
  CMD                 PASS  test_fighter_b.cmd
  SFF                 PASS  test_fighter_b.sff
  AIR                 PASS  test_fighter_b.air
  SND                 PASS  test_fighter_b.snd
  Constants           PASS  test_fighter_b.const
  States (st)         PASS  test_fighter_b.zss
  stcommon            PASS  ../../../engine/ikemen-go/data/common1.cns.zss  (from the engine tree, not the character)
  movelist            PASS  movelist.dat
  SFF content         PASS  version 2.0.1.0, 282 sprites, 16 palettes
  AIR content         PASS  88 actions
  scripts -> AIR      PASS  4 script file(s), every literal animation reference resolves
  AIR -> SFF sprites  PASS  all 189 referenced sprites exist
```

检查内容：

1. `.def` 能解析，`[Info] name` 非空、与目录名一致（不一致是 WARNING），`displayname` 非空。
2. `[Files]` 每一项都能解析到真实文件；必需项（`cmd` / `sprite` / `anim` / `st`）缺失是
   ERROR；`sprite`/`anim`/`cmd`/`cns`/`st`/`sound` **解析到角色目录之外**是 ERROR
   （角色就不可移植了）。`stcommon` 允许来自引擎的 `data/`（引擎公共状态本来就随引擎分发）。
3. SFF 能打开、版本在支持范围内（v1 → `SFF_UNSUPPORTED`）。
4. `.air` 结构检查（§4.2 的全部规则）。
5. **AIR → SFF**：每个元素引用的精灵都必须存在。
6. **脚本 → AIR**：`st` / `st2` / `st3` / `st4` 里**字面量**的 `anim: N` 与
   `changeAnim{value: N}` 必须在 `.air` 里有对应 Action（`ZSS_MISSING_ACTION`，ERROR）。
   非字面量（`value: $anim`、`140 + ...`）会被跳过而不是猜。
7. 判定框语义检查（§4.2 里带 `AIR_` 前缀的那几条）。

**退出码**：`0` 干净（允许 WARNING）；`1` 有 ERROR（`--strict` 时 WARNING 也算）；
`2` 用法错误；`3` 角色目录或 `.def` 读不到。

`verdict` 行的含义：`PASS`（无 WARNING 以上）、`WARN`（只有 WARNING，退出码仍 0）、
`FAIL`（有 ERROR）。

---

## 7. 错误码总表

| 退出码 | 含义 | 典型场景 |
| --- | --- | --- |
| `0` | OK | 没有高于 INFO 的发现 |
| `1` | FINDINGS | 至少一个 ERROR（`--strict` 时 WARNING 也算） |
| `2` | USAGE | 命令行参数错误（例如 `export` 少了 `--out`） |
| `3` | IO | 输入文件不存在、路径是目录、角色目录无法定位 `.def` |
| `4` | UNSUPPORTED | 格式在支持范围内之外（现在只有 SFF v1 与 raw 真彩精灵） |
| `5` | CORRUPT | 文件是目标格式但数据坏了（截断、签名错误、PNG 解不开、越界偏移） |

`4` / `5` 的区分是刻意的：**"这个文件我不支持"和"这个文件坏了"是两件不同的事**，
前者不该让人以为素材有问题。

---

## 8. 代码结构与共享库

```text
tools/
├── kofassets/                 只读解析库（纯标准库，三件工具共享）
│   ├── pngio.py               最小 PNG 读/写（zlib）
│   ├── sff.py                 SFF v2：头、调色板、精灵头、RLE8/RLE5/LZ5/PNG 解码
│   ├── air.py                 .air 解析 + 引擎的判定框作用域模型
│   ├── chardef.py             .def 解析与 [Files] 路径解析
│   ├── checks.py              验证规则（两个工具共用同一套规则）
│   └── report.py              ERROR/WARNING/INFO、退出码、文本/JSON 输出
├── sffctl/sffctl.py           inspect / export / montage
├── airtool/airtool.py         inspect / validate
└── character_validate/validate_character.py
```

共享库的存在是**为了三件工具用同一套规则和同一套语义**，不是为了做框架：
`airtool validate` 和 `validate_character` 调用的就是 `checks.py` 里同一批函数，
所以不可能出现"一个工具报、另一个不报"。

解析算法**逐行移植**自引擎自己的读取器，保证"工具说的"和"引擎会做的"不会悄悄分叉：

```text
engine/ikemen-go/src/image.go   SffHeader.Read / readHeaderV2 / readV2 /
                                Rle8Decode / Rle5Decode / Lz5Decode /
                                loadPalettes / ReadPalette
engine/ikemen-go/src/anim.go    ReadAnimFrame / ReadAnimation / ReadAction
```

移植时**保留了引擎的边界行为**（例如 `d & 0xc0 >> rbc` 在 Go 里是
`(d & 0xc0) >> rbc`——Go 的 `&` 与 `>>` 同优先级、左结合），但**加上了边界检查**：
引擎在越界时会 panic，工具会报错退出。

---

## 9. 支持范围

| 项 | 支持 |
| --- | --- |
| **SFF** | v2（本仓库四个容器都是 `2.0.1.0`）。v2.0.0.0 的调色板 alpha 规则也已按引擎实现。 |
| **SFF 精灵格式** | `2` RLE8、`3` RLE5、`4` LZ5、`10` PNG(索引)、`11/12` PNG(RGBA)、`0` raw + 深度 8 |
| **调色板** | v2 调色板表、链接调色板、重复键；每色 RGBA；index 0 的 alpha 来自文件（不强制透明），若 index 0 不透明会给出警告 |
| **AIR** | Action、元素、时间、`-1`、flip、blend、scale、angle、`loopstart`、`copy action`、`interpolate *`、`Clsn1/2`、`Clsn1/2Default` |
| **图像输出** | PNG（8-bit RGBA，无隔行，filter 0） |
| **角色** | `.def` + `[Files]` 路径解析（含引擎 `data/` 回退） |

**明确不支持**（遇到时报 `4`，不猜、不误解析）：

```text
SFF v1                                    ← 引擎能加载，但 P5 工具不支持（如实报错）
raw 真彩 SFFv2 精灵（format 0 depth 24/32） ← 字节序无法从本项目数据验证，宁可不做
隔行（interlaced）PNG
SFF 写回 / 替换精灵 / 新增精灵 / 重建 SFF
AIR 编辑 / 自动修复
SND（导出或检查）
调色板编辑 / ACT 文件
精灵表自动切割
GUI / 数据库
AI 生成精灵
```

---

## 10. P6 推荐工作流

**先跑这一条**（它就是下面 1–5 步的合集，顺序、命令、输出全部写进一份报告）：

```powershell
python tools\asset_report.py <角色目录> --out logs\p5\report --montage
```

需要某一步的细节时，再单独用对应的工具：

```text
拿到一套新的 Sprite / SFF / AIR
   │
   ├─ 1. Character Validate      python tools\character_validate\validate_character.py <角色目录>
   │        先把"文件齐不齐、引用对不对"过一遍
   │
   ├─ 2. SFF Inspect             python tools\sffctl\sffctl.py inspect <sff> --limit 30
   │        确认版本/数量/尺寸/原点符合预期
   │
   ├─ 3. Sprite Export + 肉眼    python tools\sffctl\sffctl.py montage <sff> --out logs\p5\montage.png
   │        导出后用 montage 拼图看一眼：解码、调色板、透明是否正常
   │
   ├─ 4. AIR Inspect             python tools\airtool\airtool.py inspect <air> [--action N]
   │        看 tick 数、`-1`、每个元素的判定框模式
   │
   ├─ 5. Animation Validate      python tools\airtool\airtool.py validate <air>
   │        引用缺失 / 重复 / 判定框作用域 / 受击框缺口
   │
   ├─ 6. 同步进引擎              pwsh -File scripts\sync_game_content.ps1
   │
   └─ 7. Runtime 对照            pwsh -File tests\p3\run_match_watch.ps1
            静态检查 + 冒烟对局；判定只看报告里的 crashlogs 行
```

**工具是只读的，静态检查永远不能替代 Runtime。** "资产静态检查 + Runtime 冒烟"的组合
才是完整判据：静态能查出"引用不存在"这类必然错，而"判定框到底有没有打到人"只有
Runtime 能回答（P4 的投射物 bug 就是两者结合才定位的）。

---

## 10.1 asset_report —— 一条命令出完整报告

```powershell
python tools\asset_report.py <角色目录|.def> [--out DIR] [--report FILE] [--montage]
```

它按顺序做这些事，每步都把**命令行本身**和**输出**写进报告：

```text
STEP 1  character_validate                 文件/引用/AIR↔SFF/脚本↔AIR 逐项结论
STEP 2  sffctl inspect                     版本、精灵数、尺寸、原点、格式
STEP 3  sffctl export + check_export        导出全部精灵，再从磁盘回读逐像素对照
        （--montage 时再画一张拼图）
STEP 4  airtool inspect --action N          自动挑选：带攻击框的动作 + 所有 -1 保持动作
STEP 5  airtool validate                    引用缺失 / 判定框作用域 / 受击框缺口
```

要点：

- **不加自己的逻辑**：每步都是调用现有工具，所以报告不可能和单件工具自己说的不一致。
- **路径是仓库相对的**（传相对路径、在仓库根运行），所以同一份报告在任何机器上
  重新生成都应该长得一样 —— 这也是它能作为证据存档的原因。
- `--out` 默认 `logs/p5/asset_report`（已 gitignore），精灵导出到 `<out>/export`。
- 退出码：`0` = 每一步都通过；`1` = 有步骤失败（**报告照样写出来**，失败的报告才是重点）。
- 报告里"自动挑选"的动画：所有带攻击框的动作（最多 8 个）+ 所有 `-1` 保持动作
  （最多 6 个），顺序固定，所以重跑是确定的。

`scripts/test.ps1` 里 `6b` 组就是它的测试：一个一致的夹具角色必须 `exit 0`，
一个缺文件的夹具角色必须 `exit 1` 且报告里出现 `DEF_UNRESOLVED_FILE`。）。

`scripts/test.ps1` 已经把这套工具测试接进了项目回归：

```powershell
pwsh -File scripts\test.ps1           # smoke + 工具测试
pwsh -File scripts\test.ps1 -Full     # 额外导出全部 282 个精灵并拼图（约 20 秒）
pwsh -File scripts\test.ps1 -Suite tools
```

---

## 11. 做过的决定（以及为什么）

1. **不复用引擎的 Go 解析器。** 引擎的 SFF/AIR 解析器都在 `package main` 里，主仓无法
   导入；要复用只能把大量 Go 代码复制进主仓，或者给引擎加 CLI —— 后者被项目架构优先级
   明确禁止（`engine/ikemen-go` 默认只读）。所以选了"最小独立实现"，并把移植的出处逐条写在
   模块 docstring 里，用解析算法的忠实移植代替代码复用。
2. **纯标准库，不引入 Pillow。** PNG 只需要 zlib：写用 filter 0，读覆盖到索引图和 RGBA
   图。这样工具不会因为缺依赖而让 `scripts/test.ps1` 失效。
3. **不做 SFF 写回。** P6 是否需要写回必须等正式素材流程确定，提前做 writer 是纯负债。
   （例外：`tests/fixtures/make_fixtures.py` 会生成极小 SFF，那是**测试夹具**，
   目的是让"解码结果等于已知像素"成为可断言的事实，不是产品能力。）
4. **删掉了"角色应该有这些动画"的规则。** 第一版硬编码了一张期望动画清单，跑
   `_template` 直接报错——但模板**本来**就故意不实现蹲姿（P2 范围声明）。
   改成只检查"角色自己的脚本要什么"（无可争辩），而不是猜角色"应该"有什么。
5. **没有把引擎公共状态索要的动画当成必需。** 对照 `data/common1.cns.zss` 发现，它索要的
   动画里多数被 `selfAnimExist(...)` 保护（175/190/5030/5050/5500），或者位于引擎自己
   标注 `Deprecated in DosMugen` 的状态（110/115）。把它们报出来会给每个角色加 9 条
   无法处理的警告 —— 一个"狼来了"的验证器等于没有验证器。
6. **`AIR_HURTBOX_GAP` 是 WARNING 而不是 ERROR。** 它对现有三个角色都会触发
   （各 3 条，来自 `_template` 的写法），是真实存在的语义缺口但不是"角色不能用"。
   ERROR 会让 `character_validate` 认定现有角色不合格，那是不诚实的。

---

## 12. 已知限制

- 不支持 SFF v1（仓库里的 `p1_kfm_zss_lab/intro.sff`、`ending.sff` 是 v1；角色本体
  用的四个容器都是 v2）。
- 不支持 raw 真彩精灵（format 0 / depth 24、32）。本仓库没有任何素材用它。
- 没有 SND、没有写回、没有 GUI、没有调色板编辑 —— 都是刻意不做（§9）。
- **"逐帧 `Clsn` 只作用于一个元素"这条结论的来源是**：引擎源码
  （`anim.go:311-364`、`char.go:10209-10233`）+ P4 在 Runtime 上对 `Clsn1` 的 A/B 实测。
  对 `Clsn2` 没有单独做过 Runtime 实测；它走的是同一段解析代码，所以按同一结论处理。
  如果你在 P6 上观察到相反的现象，先怀疑这条假设。
- 工具不声称"导出的 PNG 与 IKEMEN 的画面 100% 一致"：缩放、palFX、blend、可选调色板
  都是 Runtime 的事，不在导出范围内。导出做的是"精灵的原始像素 + 该精灵自己的调色板"。

---

## 13. 解码正确性是怎么证明的（不是"看着像"）

P5 结束时的证据链，从强到弱：

1. **与引擎自身解码器逐字节对照（最强）**。把
   `engine/ikemen-go/src/image.go:1209` 的 `Sprite.Lz5Decode` **逐字照抄**成一份
   临时的 Go 程序，对四个容器每个精灵解码取 sha256，与 `tools/kofassets/sff.py`
   的输出比对：

   ```text
   cross-check: 1128 sprite(s) compared against the engine's own decoder, 0 mismatch
   ```

   1128 = 4 容器 × 282，其中 280/282 走 LZ5、2/282 走 PNG 索引（这一半同时对照了
   Go 的 `image/png` 与我们的 `pngio.py`）、41/282 是链接精灵（走 `link` 链）。
   方法与结果：[`docs/evidence/p5/engine_decoder_crosscheck.txt`](evidence/p5/engine_decoder_crosscheck.txt)。

   > 那份 Go 程序**刻意没有提交**：它是引擎代码的副本，把它留在外面也顺便让 Go 不进
   > 项目的依赖表（资产工具保持"只用标准库"）。重建方法写在上面的证据文件里，约五分钟。

2. **夹具逐像素相等**。合成夹具的"已知索引 + 已知调色板 → 期望 RGBA"是逐字节断言，
   覆盖 raw 与 LZ5 两条路径（`tests/fixtures/verify_decoders.py`，48/48）。

3. **真实容器的结构断言**：282 个精灵全部可解码、长度与 `width*height` 相符、
   全部都有可见像素、golden 哈希未变化。

4. **人眼**：`sffctl montage` 拼图（透明区域是棋盘格）。它不再承担"证明解码正确"的
   职责 —— 那是第 1 条的事 —— 但它是最快发现"哪里看着不对"的方式。

### 顺带的发现：链接精灵

每个容器里 **41/282** 个精灵是"链接精灵"（`data_size == 0`，自身没有字节，
复用 `link` 指向的前一个精灵的像素，即引擎的 `shareCopy`），全部落在 50xx
（受击／倒地）区间。读取器按引擎的方式顺着 `link` 链解析，所以导出它们会得到正常的
PNG 而不是空文件或报错；`inspect --json` 里能看到 `linked_to_index`。
（`data_size == 0` 但 `link` 越界时，引擎会把它留成"无贴图"；工具同样留空并给出告警，
不会让整个容器读不了。）

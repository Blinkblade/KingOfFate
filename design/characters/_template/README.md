# KingOfFate - Base Fighter Template

P2（Base Fighter Template）的起点骨架。**这不是一个可玩的角色**，而是一份
"文件结构 + 命名规范 + 写法约定"的可复制模板，外加对 P1 研究结论的落地。

## 这是什么 / 不是什么

| | |
| --- | --- |
| **是** | P2 创建真实基础模板时可直接复制的目录结构；每条关键约定都标注了依据 |
| **不是** | 一个可运行的角色；不是 P3/P4 的测试角色；不是任何正式角色 |
| **不含** | 精灵（`.sff`）、音效（`.snd`）、任何角色美术 |

## 文件清单

| 文件 | 作用 | 完成度 |
| --- | --- | --- |
| `_template.def` | 文件名映射 + 元信息。角色加载入口 | ✅ 可用占位 |
| `_template.cmd` | 命令定义（4 键：LP/HP/LK/HK） | ✅ 可用占位 |
| `_template.const` | 常量：[Data] / [Size] / [Velocity] / [Movement] | ✅ 可用占位 |
| `_template.zss` | 主体状态：195 嘲讽 + 200 站立轻拳（完整实现的样板） | ✅ 含样板 |
| `command.zss` | 命令路由，含**顺序即优先级**的完整说明 | ✅ 可用占位 |
| `hits.zss` | 受击方状态（P2 起点为空，普通技用公共状态） | ⬜ 空骨架 |
| `AI.zss` | CPU AI，含**优先级=书写顺序**的说明与自查清单 | ✅ 可用占位 |
| `_template.air` | 动画 + 判定框：Action 0 / 195 / 200 | ⚠️ 需接真实精灵 |
| `movelist.dat` | 出招表（纯展示） | ⚠️ 需随招式更新 |
| `_template.sff` | 精灵容器 | ❌ **缺失，需工具产出** |
| `_template.snd` | 音效容器 | ❌ **缺失，需工具产出** |

## 怎么用（P2 开工步骤）

```powershell
# 1. 复制并改名
Copy-Item -Recurse design\characters\_template game\chars\<你的角色名>
# 然后在所有文件里把 `_template` 前缀替换成 `<你的角色名>`

# 2. 改 _template.def 的 [Info]：name / displayname / author

# 3. 准备 .sff 与 .snd（见下"已知缺口"）

# 4. 同步到引擎运行目录并试跑
pwsh -File scripts/sync_game_content.ps1
pwsh -File scripts/run_game.ps1 -ExtraArgs '-p1','<你的角色名>','-p2','kfm_zss','-s','stage0','-windowed'
```

## 已知缺口：为什么它现在跑不起来

`.def` 引用的 `_template.sff` 与 `_template.snd` 是**二进制容器**，无法用文本创建，
本骨架没有附带。在它们存在之前，引擎加载这个角色会在读精灵/音效阶段失败。

> **另外一个"看起来缺了但其实是正常的"**：`.def` 里的 `stcommon = common1.cns.zss`
> **不在本目录里**。这是对的 —— 公共状态由引擎从 `data/` 目录解析
> （`compiler.go:8361-8362` 的搜索路径为 `{角色目录, "", motif 目录, "data/"}`），
> 不需要随角色一起分发。**不要为了"补齐文件"把 `common1.cns.zss` 复制到角色目录**，
> 那样会让该角色脱离画面包的公共状态、以后同步升级会出问题。

要让骨架先"跑起来看效果"，有两条路：

1. **临时借用现成素材**（推荐用于验证流程）：
   从 `engine/ikemen-go/chars/kfm_zss/` 复制 `kfm.sff` / `kfm.snd`，
   并在 `.def` 与 `.air` 里对齐精灵组号。这是**临时验证手段**，
   借用的素材必须登记到 `assets/LICENSE_MANIFEST.csv`，不得进入发布。
2. **等 P5（Character Asset Tooling）**：由工具链从原始美术产出 `.sff` / `.snd`。
   这是正式路径。

## 为什么这些约定是硬的（依据索引）

骨架里的注释不是风格偏好，每一条都有出处：

| 约定 | 依据 |
| --- | --- |
| `{` 必须与控制器名同行（`hitDef{`） | 架构文档 §5.2；KFM 源码原注释 |
| `command.zss` 的顺序决定命令优先级 | 架构文档 §5.3；**实验 E5** |
| `AI.zss` 的顺序决定 AI 优先级 | 架构文档 §7.3；**实验 E6** |
| `Clsn1` 与 `Clsn2` 互相独立、且与伤害解耦 | 架构文档 §6.2；**实验 E4** |
| 动画帧数决定出招快慢（不改逻辑） | 架构文档 §6.1；**实验 E3** |
| `hitDef.damage` 精确等于掉血量 | 架构文档 §3；**实验 E2** |
| `[Velocity]` 的值就是每 tick 位移 | 架构文档 §2.1；**实验 E1** |

完整推导见 [`docs/ikemen_character_architecture.md`](../../../docs/ikemen_character_architecture.md)
与 [`docs/p1_experiments.md`](../../../docs/p1_experiments.md)。

## 目录位置说明

本目录位于 `design/`（设计产物）而**不是** `game/`（可运行内容）。
原因：`scripts/sync_game_content.ps1` 会把 `game/chars/*` 同步进引擎运行目录，
而模板**不应该**被引擎加载。P2 复制到 `game/chars/` 之后才会进入运行链路。

# P1 Kickoff Prompt — 可直接粘贴到新会话

> 用途：在全新会话中无缝接续 KingOfFate 项目，从 P1 开始工作。
> 下面整段（从"你是…"开始）都是给新会话的 prompt 正文。

---

你是 KingOfFate 项目的工程协作助手。这是一个使用 IKEMEN GO 引擎开发 2D 格斗游戏的项目。
项目已按阶段（P0–P12）推进，**P0 已全部 PASS**，现在要从 **P1** 开始。

**仓库本身是唯一的工程真相。不要依赖这段 prompt 里的任何描述当作事实——它是导航，
不是证据。** 开工前先按下面的顺序读仓库。

## 一、开工前必读（按顺序，不要跳）

工作目录：`D:\AI\develop\KingOfFate`

1. `README.md` —— 项目定位、构建/运行/测试入口、目录结构
2. `docs/development_status.md` —— **唯一"当前进行到哪"的答案**；Phase 总览 + P0 的 Gate 表
3. `docs/phase_reports/P0-repository-and-environment.md` —— P0 阶段报告（交付物、环境基线、踩过的坑、遗留项）
4. `docs/iterations/README.md` + `docs/iterations/20260911-p0-bootstrap.md` —— 迭代记录制度与 P0 实施记录
5. `docs/environment.md` —— 本机运行环境实测值与**全部已知环境陷阱**
6. `CONTRIBUTING.md` —— 分支模型、提交规范、目录职责、引擎改动流程、PR 要求
7. `engine/ikemen-go/BUILDING.md` 与 `engine/ikemen-go/README.md` —— 引擎自身的构建与使用说明（官方依据）
8. 实测命令：

```powershell
git status --short
git branch --show-current
git log -8 --oneline
git submodule status
pwsh -File scripts/test.ps1          # 期望 29/29 PASS，退出码 0
```

## 二、当前确定的事实

| 项 | 值 |
| --- | --- |
| 引擎 | IKEMEN GO，基线固定 `v1.0.0-rc.5` = `ba516193bba83f13f0b63ddce314d8719793931f` |
| 引擎位置 | submodule `engine/ikemen-go`，分支 `kingoffate/rc5`，remote 是 fork `Blinkblade/Ikemen-GO`（`origin`）/ 上游 `ikemen-engine/Ikemen-GO`（`upstream`） |
| 构建产物 | `engine/ikemen-go/Ikemen_GO.exe`（约 14.9 MB） |
| 运行根 | `engine/ikemen-go/`（运行资源直接解包在这里，与引擎 `BUILDING.md` 一致） |
| 默认画面包 | `data/ikemen1/system.def`（官方 Screenpack，已解包，子模块仍干净） |
| 可玩素材 | `chars/kfm`、`chars/kfm_zss`、`chars/kfm720`、`chars/kfm_zaxis`、`stages/stage0.def` 等 |
| 测试 | `pwsh -File scripts/test.ps1`（可选 `-RuntimeTest` 真实启动一轮） |
| P0 阶段 | **PASS**（10/10 Gate） |

**绝对不要做的事**：不要自动跟随引擎 upstream；不要在 `main` 上开发；不要重新设计构建方式。

## 三、环境操作手册（本机已验证）

构建：

```powershell
pwsh -File scripts/build_engine.ps1 -BuildFfmpeg no -Proxy http://127.0.0.1:7897 -GoProxy https://goproxy.cn,direct
```

- `-BuildFfmpeg no` 使用系统 FFmpeg 开发包（`BUILDING.md` 记载的可选方式）。原因是本地 FFmpeg 源码构建的 `make install` STRIP 步骤在本机产出 0 字节 DLL；`auto` 是 CI 默认，环境允许时可以切回。
- `-Proxy` / `-GoProxy` **必须传**：本机 `pacman`/`git`/`go` 的大文件下载不走 Windows 系统代理，不传会挂死。
- 脚本只调用引擎自带未修改的 `build/build.sh Win64`，不会执行任何 `git pull/reset/checkout/clean`。
- 日志：`logs/build/<YYYYMMDD>/build-engine.log`。

运行：

```powershell
pwsh -File scripts/run_game.ps1            # 直接启动
pwsh -File scripts/run_game.ps1 -CheckOnly # 只做预检
pwsh -File scripts/run_game.ps1 -ExtraArgs '-p1','kfm','-p2','kfm','-s','stage0','-windowed'
```

注意：运行期 DLL 未打包，`run_game.ps1` 会自动把 MSYS2 的 `mingw64\bin` 前置到游戏进程 PATH。
CLI 参数是**单横线**（`-p1`、`-s`、`-windowed`、`-nosound`、`-nomusic`）。
引擎帮助文本里的 `-rounds` **在本基线未接线**（Go 侧从不读取），不要依赖它做无人值守自动退出。

## 四、固定约定（强制）

- 不在 `main` 上开发。新阶段开 `feature/p1-<topic>`，完成后 PR 合并。
- **一个 PR 至少对应一份 `docs/iterations/YYYYMMDD-<topic>.md`**，用 `docs/iterations/README.md` 的模板。
- 任何阶段出现阻塞必须写 `BLOCKED`，**绝不允许把未完成写成 `PASS`**。
- 阶段状态只在 `docs/development_status.md` 里改；过程写进 `docs/iterations/`。
- 目录职责见 `CONTRIBUTING.md`；空目录用 `.gitkeep`，不要为凑目录创建无意义文件。
- 第三方素材必须登记到 `assets/LICENSE_MANIFEST.csv`。
- 引擎改动优先级：**配置 → 角色 ZSS → Lua → 外部工具 → 最后才是 IKEMEN 源码**。
  确实需要改引擎时，去 fork `Blinkblade/Ikemen-GO` 开 `engine/feature/<name>`，再把 submodule 指针更新过来；不要在 KingOfFate 主仓里直接改引擎文件。

## 五、P1 任务

**P1 = IKEMEN Character Architecture（IKEMEN 角色架构研究）**

目标：把 IKEMEN GO 的"一个角色是如何构成的"彻底搞清楚，并把它沉淀成项目后续
（P2 基础模板、P3/P4 测试角色、P5 素材工具链、P6 正式角色）可以直接照着做的工程文档。
这是**研究 + 文档**阶段，**不是**做角色的阶段。

已知的现成研究素材（都在仓库里）：

- `engine/ikemen-go/src/` —— 引擎 Go 源码（角色加载、状态机、ZSS/Lua 触发器等）
- `engine/ikemen-go/external/script/` —— 引擎自带 Lua 脚本（`start.lua`、`main.lua` 等）
- `engine/ikemen-go/data/*.zss` —— 引擎默认的 ZSS 状态脚本（`common.zss`、`system.zss`、`action.zss`…）
- `engine/ikemen-go/chars/kfm/` —— 经典 KFM：`.def` / `.cns` / `.air` / `.sff` / `.snd` / `.cmd` / `movelist.dat`
- `engine/ikemen-go/chars/kfm_zss/` —— ZSS 版本的角色（重点参考：这是项目后续要走的路线）
- `engine/ikemen-go/docs/` —— 引擎自带文档

建议产出（具体范围以你自己读仓库后的判断为准，但要在 Iteration Record 里说明取舍）：

1. `docs/character_architecture.md` —— 角色目录结构与各文件职责
   （`.def` / `.cns` / `.zss` / `.air` / `.sff` / `.snd` / `.cmd` / `.st` / `movelist` 等）
2. `docs/character_state_machine.md` —— 状态机、状态定义与跳转、触发器等
3. `docs/character_zss_guide.md` —— ZSS 语法与在本项目中的使用约定（重点）
4. `docs/character_lua_guide.md` —— 引擎 Lua 扩展点与可挂钩位置
5. `design/characters/_template/` 或等价产物 —— P2 可直接复用的角色骨架目录（**只搭骨架并写清说明，不实现具体角色**）
6. `docs/iterations/YYYYMMDD-p1-<topic>.md` —— 本阶段 Iteration Record
7. 更新 `docs/development_status.md` 的 P1 状态与 Gate

P1 的完成判据（建议，可按研究结论调整并在记录中说明）：

- 上述架构文档齐备，且每条结论都能指向仓库内的具体文件/行（可追溯）
- 有一个可被 P2 直接复制的角色骨架目录
- 明确列出"哪些东西必须改引擎、哪些用配置/ZSS/Lua 就能做到"
- `pwsh -File scripts/test.ps1` 仍然全绿（研究阶段不应破坏任何东西）
- `docs/development_status.md` 的 P1 状态如实更新，未完成项写 `BLOCKED`

## 六、报告要求

每轮工作结束时，用**中文**给出：

1. 当前 Branch
2. P1 最终状态（PASS / IN_PROGRESS / BLOCKED）
3. 本次完成内容
4. 新增/修改的主要文件
5. 实际执行的命令与真实结果
6. 测试结果（真实数字，不要美化）
7. Iteration Record 路径
8. Commit 列表
9. Push 结果与 PR 状态（若无法推送，给出 PR 标题建议、PR 描述、远程分支名）
10. 已知问题
11. 下一步

不要把未完成的写成完成；不要把推测写成实测。

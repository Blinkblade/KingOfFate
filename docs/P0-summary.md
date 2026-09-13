# P0 阶段性总结（Phase 0 Summary & Handoff）

| | |
| --- | --- |
| **阶段** | P0 — Repository & Environment |
| **状态** | **PASS**（10/10 Exit Gate 全绿） |
| **时间** | 2026-09-11 → 2026-09-12 |
| **分支** | `feature/p0-bootstrap`（已推送 `origin`） |
| **详细报告** | [`docs/phase_reports/P0-repository-and-environment.md`](phase_reports/P0-repository-and-environment.md) |
| **过程记录** | [`docs/iterations/`](iterations/) |

> **这份文档是给"接手项目的下一个 Agent"看的**：一页读懂 P0 干了什么、为什么干、
> 最后得到了什么、用什么方法做到的，以及**每个脚本怎么用、有什么用**。
>
> 它与 Phase Report 的分工：Phase Report 是**逐条 Gate 的证据档案**（写一次即冻结）；
> 本文是**总览 + 脚本手册 + 交接说明**，偏重"怎么用"和"接下来注意什么"。
> 两者结论一致，细节冲突时以 Phase Report 为准。

---

## 1. P0 的目的

在写任何一行游戏代码之前，先把**"能不能稳定地造出并跑起来"**这件事解决掉。
P0 要回答并锁死四个问题：

1. **引擎基线是什么** —— 用哪个版本、哪个 commit，能不能不漂移地复现；
2. **能不能在这台 Windows 机器上构建成功** —— 工具链齐不齐，构建是否可重复；
3. **构建出来的东西能不能真的跑起来** —— 不是"编译通过"，而是进程活着、窗口出现、持续响应；
4. **以后每一阶段的成果，用什么统一入口去构建 / 运行 / 测试**，以及状态和过程记在哪里。

一句话：**P0 不产出游戏内容，只产出"可复现的工程地基"。**

---

## 2. 最终达到了什么效果

| 目标 | 实测结果 |
| --- | --- |
| 引擎基线锁定 | IKEMEN GO `v1.0.0-rc.5` = `ba516193bba83f13f0b63ddce314d8719793931f`，作为 submodule 固定在 `engine/ikemen-go` |
| 引擎可构建 | `==> Build successful (Windows)`，产出 `Ikemen_GO.exe` **14.94 MB** |
| 引擎可运行 | 窗口标题 `Ikemen GO`、`Responding = True`、工作集 ~320–380 MB |
| 构建可重复 | 同一命令多次执行均成功，脚本零硬编码个人路径 |
| 一键测试 | `scripts/test.ps1` → `smoke test: 29/29 checks passed`，退出码 `0` |
| 状态可追溯 | `docs/development_status.md` 是唯一"现在到哪了"的答案；过程写入 `docs/iterations/` |

**P0 没有做**：没有开发任何角色、`_template`、正式 UI 或 AI 素材流程（这些属于 P1 及之后）。

---

## 3. 完成了哪些内容

### 3.1 仓库与基线

- KingOfFate 仓库建立；IKEMEN GO fork（`Blinkblade/Ikemen-GO`）建立
- 引擎 fork 的 `origin` / `upstream` 配置；集成分支 `kingoffate/rc5`
- 引擎以 **Git submodule** 固定在 `v1.0.0-rc.5`，集成分支 `kingoffate/rc5`
- 项目目录骨架（`game/ engine/ assets/ design/ tools/ scripts/ tests/ docs/ logs/ dist/ .github/`）

### 3.2 文档制度

- `README.md` —— 项目入口（定位、状态、环境要求、构建/运行/测试）
- `CONTRIBUTING.md` —— 分支模型、提交规范、目录职责、引擎改动流程、PR 要求
- `.github/pull_request_template.md` —— PR 模板（含 Iteration Record 必填项）
- `docs/development_status.md` —— Phase 总览 + Gate 表（唯一状态源）
- `docs/environment.md` —— 本机实测环境基线 + 7 条环境陷阱及规避方式
- `docs/running.md` —— 已验证的启动方法（中文）
- `docs/controls.md` —— 启动后的操作、键位、出招表（中文）
- `docs/iterations/` —— Iteration Record 制度与过程记录
- `docs/phase_reports/` —— Phase Report 制度、P0 报告、P1 启动 prompt

### 3.3 环境（Windows / MSYS2）

- 便携式安装 MSYS2 到 `D:\msys64`（`.sfx.exe` 解压方式）
- 装齐工具链：gcc/g++ 16.2.0、make 4.4.1、NASM 3.02、pkg-config 3.0.7、
  Go 1.27.1、SDL2 2.32.10、libxmp 4.7.2、系统 FFmpeg 63.1.101
- 全部环境处置写入 `docs/environment.md`，脚本内已自动规避

### 3.4 运行资源

- 官方 `ikemen-engine/Ikemen-GO-Screenpack`（master）解包到引擎目录，**736 个文件**
- 提供 `data/ikemen1/system.def`（默认 motif）、`chars/kfm`（含 3 个 KFM 变体）、
  `stages/`、`font/`、`external/` 等
- 全部落在引擎自身 `.gitignore` 覆盖范围内，**引擎 submodule 保持干净**

### 3.5 脚本与测试

| 类别 | 文件 |
| --- | --- |
| 构建 | `scripts/build_engine.ps1`（入口）、`scripts/check_build_env.sh`（工具链校验） |
| 运行 | `scripts/run_game.ps1` |
| 验证 | `scripts/test.ps1`（入口）、`tests/smoke/smoke.ps1`（本体，A–F 组） |
| 证据 | `logs/build/20260912/build-engine.log`（完整构建日志，已入库） |

> 每个脚本的作用、参数、示例、退出码见 **§5 脚本手册**。

---

## 4. 整体用什么方法实现的目标

P0 的方法论可以概括为 **8 条**，后续阶段应继续遵守：

1. **固定基线，不漂移**：引擎以 submodule 钉死在 `v1.0.0-rc.5`，禁止自动跟随 upstream；
   要升基线必须先改 submodule 指针 + 更新文档 + 更新 smoke 的 `ExpectedEngineCommit`。
2. **不重造轮子**：构建只调用引擎**自带、未修改**的 `build/build.sh Win64`，
   与官方 CI 行为一致；不自行设计新的构建方式。
3. **入口脚本化、位置无关、零硬编码**：所有脚本从自身路径推算项目根；MSYS2 路径按
   "参数 → 环境变量 → 常见位置"依次探测；代理、GOPROXY 等一律参数化传入。
4. **先预检，再执行（fail fast + 修复指引）**：构建前先跑工具链校验；运行前先查产物与资源。
   缺什么就打印"该装什么 / 该跑什么命令"，而不是抛一个晦涩错误。
5. **用"真实运行"验证，而不是"编译通过"**：P0 的验收标准包含进程存活、窗口创建、
   持续响应，避免"能编译但不能跑"的假绿灯。
6. **状态与过程文档化，并且诚实**：未达成的 Gate 一律写 `BLOCKED`，绝不把失败写成 `PASS`；
   每个结论都指向仓库里的一个文件/日志/命令输出。
7. **失败时先定位根因，不降级**：构建失败时坚持"不换技术栈、不降构建目标、不改引擎源码"，
   用假设—验证表逐条排除，最终定位为**环境状态问题**（详见 §7）。
8. **产物与临时物分离**：编译临时目录固定在项目内 `.tmp/`（已 gitignore）；
   构建日志写入 `logs/build/<yyyyMMdd>/` 并**入库**作为证据。

---

## 5. 脚本手册（重点）

### 5.0 脚本调用关系

```text
                 ┌──────────────────────────────┐
   构建  ───────▶ │ scripts/build_engine.ps1     │
                 │   (Windows PowerShell 入口)   │
                 └───────────────┬──────────────┘
                                 │ 调用（MSYS2 MINGW64 shell 内）
                                 ▼
                 ┌──────────────────────────────┐
                 │ scripts/check_build_env.sh   │  工具链预检（也可独立运行）
                 └──────────────────────────────┘
                                 │
                                 ▼
                    engine/ikemen-go/build/build.sh Win64   ← 引擎自带、未修改
                                 │
                                 ▼
                    engine/ikemen-go/Ikemen_GO.exe   +  logs/build/<date>/build-engine.log

                 ┌──────────────────────────────┐
   运行  ───────▶ │ scripts/run_game.ps1         │ ──▶ Ikemen_GO.exe（工作目录 engine/ikemen-go）
                 └──────────────────────────────┘

                 ┌──────────────────────────────┐
   验证  ───────▶ │ scripts/test.ps1             │
                 └───────────────┬──────────────┘
                                 │ 调用
                                 ▼
                 ┌──────────────────────────────┐
                 │ tests/smoke/smoke.ps1        │  A–F 组检查（F 组可选真实启动）
                 └──────────────────────────────┘
```

### 5.1 `scripts/build_engine.ps1` —— 构建入口

**作用**：KingOfFate 唯一的引擎构建入口。产出自带可运行性的 `Ikemen_GO.exe`。

**它做了什么（按顺序）**：

1. 从脚本自身路径推算项目根（**不依赖当前工作目录**）
2. 校验 `engine/ikemen-go` submodule 与 `build/build.sh` 存在
3. 解析 MSYS2 根目录：`-Msys2Root` → `$env:MSYS2_ROOT` → `$env:MSYS2_HOME` → `C:\msys64` → `D:\msys64`
4. 构造 shell 前缀，为 MINGW64 会话准备环境：
   - 清除 `MSYS_NO_PATHCONV` / `MSYS2_ARG_CONV_EXCL`（否则原生命令拿到不可用路径）
   - `GOROOT=$(cygpath -m /mingw64/lib/go)`（MSYS2 的 Go 是 trimmed 构建，只认 Windows 形式路径）
   - 可选 `GOPROXY` / `GOSUMDB` / `http_proxy`
   - `TMPDIR/TMP/TEMP/GOTMPDIR` → 项目内 `.tmp/`
5. 调用 `scripts/check_build_env.sh` 做工具链预检，不通过则打印安装命令并退出
6. 运行引擎自带构建：`CI=1 BUILD_FFMPEG=<v> APP_VERSION=kingoffate-rc5 ./build/build.sh Win64`
   （**输出在 shell 内重定向到日志**，避免 PowerShell 管道背压卡死长构建）
7. 校验产物存在，打印大小与 SHA256，写日志 `logs/build/<yyyyMMdd>/build-engine.log`

**参数**：

| 参数 | 取值 | 默认 | 说明 |
| --- | --- | --- | --- |
| `-Msys2Root` | 路径 | 自动探测 | MSYS2 安装根（含 `usr\bin\bash.exe`） |
| `-BuildFfmpeg` | `auto` / `yes` / `no` | `auto` | 透传给引擎的 `BUILD_FFMPEG`。`no` = 用系统 FFmpeg 包 |
| `-NoLog` | 开关 | 关 | 不写构建日志 |
| `-Proxy` | URL | `$env:HTTPS_PROXY` | 构建期 git/curl 代理，如 `http://127.0.0.1:7897` |
| `-GoProxy` | 值 | `$env:GOPROXY` | 如 `https://goproxy.cn,direct` |
| `-GoSumDb` | 值 | `$env:GOSUMDB` | 需要时可设 `off` |

**退出码**：`0` 成功 ｜ `2` 前置缺失（submodule / MSYS2 / 校验脚本） ｜ `3` 工具链不完整 ｜ `1` 构建失败或产物缺失

**用法**：

```powershell
# 最简
pwsh -File scripts/build_engine.ps1

# 本机 P0 实际所用（系统 FFmpeg + 代理 + 国内 Go 镜像）
pwsh -File scripts/build_engine.ps1 -BuildFfmpeg no `
    -Proxy http://127.0.0.1:7897 -GoProxy https://goproxy.cn,direct

# 指定 MSYS2 位置
pwsh -File scripts/build_engine.ps1 -Msys2Root D:\msys64
```

> **注意**：脚本**故意不做**任何 `git pull/reset/checkout/clean`，构建永远不会改动源码 Git 状态。

---

### 5.2 `scripts/check_build_env.sh` —— 构建环境校验

**作用**：确认 MSYS2 / MINGW64 具备构建 IKEMEN GO 所需的全部工具与库。
依赖清单来自 `engine/ikemen-go/BUILDING.md`（钉死的 RC5 基线）。

**检查项**：`git make gcc g++ pkg-config nasm go gendef dlltool` 命令可达，
以及 `pkg-config` 能找到 `sdl2`、`libxmp`。
自动处理 `GOROOT`（用 `cygpath -m /mingw64/lib/go` 派生 Windows 形式）。

**退出码**：`0` = 齐备 ｜ `9` = 有缺失（逐项打印 `MISSING:<名>` / `MISSING_PC:<名>`）

**用法**：

```bash
# 被 build_engine.ps1 自动调用；也可在 MSYS2 MINGW64 shell 里独立运行
bash scripts/check_build_env.sh
```

---

### 5.3 `scripts/run_game.ps1` —— 运行入口

**作用**：启动已构建的游戏。**永不构建**——没有 exe 就提示你先去构建。

**它做了什么**：

1. 从脚本自身路径推算项目根；解析运行根（默认 `engine\ikemen-go`）
2. 预检可执行文件存在与体积
3. 预检运行资源：`data/ font/ external/ chars/ stages/` 目录 +
   4 个关键文件（`data/ikemen1/system.def`、`data/fight.def`、`chars/kfm/kfm.def`、`stages/stage0.def`）
4. 解析**运行期 DLL 搜索路径**：exe 旁没有 `SDL2.dll` 时，探测 MSYS2 `mingw64\bin`
   并把它**前置到游戏子进程的 PATH**（系统 FFmpeg 方案下引擎不打包 DLL）
5. 以 `engine/ikemen-go` 为工作目录启动 `Ikemen_GO.exe`
6. 打印 exe 信息、资源路径、DLL 路径

**参数**：

| 参数 | 说明 |
| --- | --- |
| `-RuntimeRoot` | 含 exe 与运行资源的目录，默认 `engine\ikemen-go` |
| `-Msys2Root` | 用于定位 `mingw64\bin` 下的运行期 DLL |
| `-Wait` | 等游戏退出后再返回（返回真实退出码） |
| `-ExtraArgs` | 透传给引擎的参数，如 `-ExtraArgs '-p1','kfm','-p2','kfm','-s','stage0','-windowed'` |
| `-CheckOnly` | 只跑预检，不启动游戏 |

**退出码**：`0` 成功 ｜ `2` exe 缺失 ｜ `3` 运行资源不全

**用法**：

```powershell
pwsh -File scripts/run_game.ps1                 # 正常启动
pwsh -File scripts/run_game.ps1 -CheckOnly      # 只预检（CI / 排障用）
pwsh -File scripts/run_game.ps1 -Wait           # 等退出
pwsh -File scripts/run_game.ps1 -ExtraArgs '-p1','kfm','-p2','kfm','-s','stage0','-windowed','-nosound'
```

> 启动后的操作、键位、出招表见 [`docs/controls.md`](controls.md)。

---

### 5.4 `scripts/test.ps1` —— 测试入口

**作用**：KingOfFate 测试套件的统一入口（当前只含 smoke）。退出码透传。

**参数**：`-RuntimeTest`（附加真实启动验证）｜ `-Suite smoke|all`（默认 `smoke`）

**用法**：

```powershell
pwsh -File scripts/test.ps1                 # 静态检查，秒级
pwsh -File scripts/test.ps1 -RuntimeTest    # 追加真实启动验证（需桌面会话）
```

---

### 5.5 `tests/smoke/smoke.ps1` —— 阶段级 Smoke Test（测试本体）

**作用**：验证项目赖以成立的最小不变量。故意保持简单（无测试框架、无 fixture），
只要 PowerShell + 仓库本身即可运行。

**检查分组**：

| 组 | 检查内容 |
| --- | --- |
| **A** | 引擎 submodule 存在；`.gitmodules` 指向 `Blinkblade/Ikemen-GO`；submodule HEAD **仍等于**钉死基线 commit；在 `kingoffate/rc5` 分支上 |
| **B** | 引擎运行目录存在（`data/ font/ external/ chars/ stages/`） |
| **C** | 引擎已构建（`Ikemen_GO.exe`）且体积合理（> 5 MB） |
| **D** | 能开一局的四个关键文件存在（默认 motif、fight screen、一个角色、一个场景） |
| **E** | 项目脚手架与文档存在（README、CONTRIBUTING、docs、scripts、PR 模板） |
| **F** | *（可选，`-RuntimeTest`）* 引擎能启动、创建窗口、持续存活并响应 |

**参数**：

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `-RepoRoot` | 脚本上两级 | 项目根 |
| `-ExpectedEngineCommit` | `ba516193...` | 钉死的引擎基线；**故意更新基线时才改这里**，不要弱化检查 |
| `-RuntimeTest` | 关 | 附加 F 组真实启动验证 |
| `-RuntimeTimeoutSec` | `20` | F 组：引擎需保持存活+响应的秒数，之后由测试主动结束进程 |

**退出码**：`0` = PASS ｜ `1` = 有失败项（逐条打印失败原因）｜ `2` = smoke 脚本缺失

**用法**：

```powershell
pwsh -File tests/smoke/smoke.ps1
pwsh -File tests/smoke/smoke.ps1 -RuntimeTest -RuntimeTimeoutSec 30
pwsh -File tests/smoke/smoke.ps1 -ExpectedEngineCommit <新基线commit>   # 仅在有意升基线时
```

> **为什么 F 组不验证"打完 N 回合自动退出"**：本 RC5 基线的 `-rounds` 参数被解析但
> 引擎从不读取（Go 侧未接线），因此改为验证"启动 → 建窗口 → 持续响应"，再由测试结束进程。

---

## 6. 常用命令速查

| 我想…… | 命令 |
| --- | --- |
| 构建引擎 | `pwsh -File scripts/build_engine.ps1` |
| 构建（本机 P0 参数） | `pwsh -File scripts/build_engine.ps1 -BuildFfmpeg no -Proxy http://127.0.0.1:7897 -GoProxy https://goproxy.cn,direct` |
| 只检查工具链 | `bash scripts/check_build_env.sh`（在 MSYS2 MINGW64 shell） |
| 启动游戏 | `pwsh -File scripts/run_game.ps1` |
| 只预检能不能启动 | `pwsh -File scripts/run_game.ps1 -CheckOnly` |
| 跑测试 | `pwsh -File scripts/test.ps1` |
| 跑测试（含真实启动） | `pwsh -File scripts/test.ps1 -RuntimeTest` |
| 初始化/更新 submodule | `git submodule update --init --recursive` |
| 看引擎基线 | `git submodule status` |

---

## 7. P0 期间踩过的坑（下一个 Agent 必读）

1. **构建在 cgo 阶段失败** `cc1.exe: cannot open '<tmp>\ccXXXX.s' for writing: Permission denied`
   —— 根因是**环境状态**（上一次被中断的并发编译在临时目录留下 0 字节残留 + 管道背压卡死构建），
   不是代码或工具链缺陷。**处置**：清空 `.tmp` + 把重量级依赖干净编过一遍；
   已固化为"临时目录固定在 `.tmp/`、输出由 shell 直接写日志"。
   **没有被用来当作换技术栈/改引擎源码的理由。**
2. **便携式 MSYS2 的 7 条陷阱**（详见 `docs/environment.md`）：
   `/bin` `/lib` 缺失需目录联结；`pacman-key --init` 死循环；`pacman` 不读系统代理；
   `MSYS_NO_PATHCONV`/`MSYS2_ARG_CONV_EXCL` 关掉路径转换；
   Go 需 Windows 形式 `GOROOT`；PowerShell 管道背压；Go 模块需区域镜像。
3. **本地 FFmpeg 构建的 `make install` STRIP 产出 0 字节 DLL** —— 改用引擎文档明确支持的
   `BUILD_FFMPEG=no`（系统 FFmpeg），代价是 WebM alpha 可能不走 libvpx，**不影响玩法**。
4. **`-rounds` 未接线**（见 §5.5 注）。CLI 参数是**单横线**。
5. **沙箱的删除配额**：构建脚本内不要做批量删除；日志用 shell `>` 覆盖而不是先删后建。

---

## 8. 已知限制与遗留事项

| 项 | 说明 | 影响 |
| --- | --- | --- |
| `pacman` 签名校验被关闭 | 本机 gpg 2.4.9 导致 `pacman-key --init` 死循环，临时 `SigLevel = Never` | 本机环境妥协；MSYS2 修复后应恢复 `Required` |
| 使用系统 FFmpeg | 与 CI 默认（`auto`）不同 | WebM alpha 解码差异，不影响玩法 |
| 运行期 DLL 未打包 | `run_game.ps1` 通过前置 `mingw64/bin` 到子进程 PATH 解决 | 正式分发需在 **P12 打包**时把 DLL 放到 exe 旁 |
| `-rounds` 未接线 | 无法用"打 N 回合自动退出"做无人值守验证 | Smoke F 组改为启动健康度验证 |
| 经典 `kfm` 不在选人表 | `data/select.def` 登记的是 `kfm_zss`/`kfm720`/`kfm_zaxis` | 需 `-p1 kfm` 直接参战；P1 再规范化 |

---

## 9. 给下一个 Agent 的三条提醒

1. **先读状态，再动手**：`README.md` → `docs/development_status.md` → 本文件 →
   P0 Phase Report。仓库是唯一真实工程状态，**不要依赖对话记忆**。
2. **不要动基线**：`engine/ikemen-go` 固定在 `v1.0.0-rc.5`；要动必须走
   "改 submodule 指针 + 更新文档 + 更新 smoke 的 `ExpectedEngineCommit`" 的完整流程。
3. **任何改动都走分支 + PR**：不在 `main` 上开发；一个 PR 至少配一份
   `docs/iterations/YYYYMMDD-<topic>.md`；未完成的事项写 `BLOCKED`，不写 `PASS`。

P1（IKEMEN Character Architecture）的启动上下文与任务定义见
[`docs/phase_reports/P1-kickoff-prompt.md`](phase_reports/P1-kickoff-prompt.md)。

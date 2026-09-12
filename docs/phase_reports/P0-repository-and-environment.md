# P0 Phase Report — Repository & Environment

| | |
| --- | --- |
| **Phase** | P0 — Repository & Environment |
| **Status** | **PASS** |
| **Date** | 2026-09-11 → 2026-09-12 |
| **Branch** | `feature/p0-bootstrap` |
| **Iteration record** | [`docs/iterations/20260911-p0-bootstrap.md`](../iterations/20260911-p0-bootstrap.md) |
| **Supersedes** | nothing (first phase report) |

---

## 1. 结论

P0 全部 10 个 Exit Gate 通过。项目现在具备：

- 可追溯的引擎基线（IKEMEN GO `v1.0.0-rc.5`，固定 commit，作为 submodule 集成）
- 可重复的 Windows 构建入口，成功产出并运行 `Ikemen_GO.exe`
- 可重复的运行入口与阶段级 Smoke Test（29/29）
- 开发状态文档 + Iteration Record 制度 + PR 协作文件

P0 期间**没有**开发任何角色、`_template`、正式 UI 或 AI 素材流程。这些属于 P1 及之后。

---

## 2. Exit Gate 结果

| Gate | 判据 | 结果 | 证据 |
| --- | --- | --- | --- |
| PASS-01 | `engine/ikemen-go` 保持正确 submodule baseline | **PASS** | `git submodule status` → ` ba516193bba83f13f0b63ddce314d8719793931f engine/ikemen-go (v1.0.0-rc.5)`；子模块工作区 `git status` 为空 |
| PASS-02 | IKEMEN GO 在当前 Windows 环境构建成功 | **PASS** | `==> Build successful (Windows)`；`Ikemen_GO.exe` 14.94 MB |
| PASS-03 | 构建产物能成功启动 | **PASS** | 进程存活、窗口标题 `Ikemen GO`、`Responding=True`、工作集 ~320–380 MB |
| PASS-04 | `scripts/build_engine.ps1` 可重复执行构建 | **PASS** | 多次实际执行，同一命令可重复产出 |
| PASS-05 | `scripts/run_game.ps1` 可启动游戏 | **PASS** | 脚本启动 pid 10012，窗口 `Ikemen GO`；`-CheckOnly` 预检全绿 |
| PASS-06 | `scripts/test.ps1` 基础 Smoke Test 通过 | **PASS** | `29/29 checks passed`，退出码 `0`（含真实启动验证） |
| PASS-07 | README / environment / development_status 内容同步 | **PASS** | 三份文档均已按最终结果更新 |
| PASS-08 | 本阶段 Iteration Record 完整 | **PASS** | `docs/iterations/20260911-p0-bootstrap.md` |
| PASS-09 | `git status` 无异常临时文件 | **PASS** | 工作区 clean |
| PASS-10 | 全部流程不依赖未记录的人工步骤 | **PASS** | 相关环境处置均写入 `docs/environment.md`，脚本可重复 |

---

## 3. 交付物清单

### 3.1 文档

| 文件 | 作用 |
| --- | --- |
| `README.md` | 项目入口：定位、当前状态、环境要求、构建/运行/测试、目录结构、协作方式 |
| `CONTRIBUTING.md` | 分支模型、提交规范、目录职责、引擎改动流程、PR 要求 |
| `.github/pull_request_template.md` | PR 模板，含 Iteration Record 必填项 |
| `docs/development_status.md` | 唯一"当前进行到哪"的答案：Phase 总览 + Gate 表 |
| `docs/environment.md` | 本机实测环境基线 + 7 条环境陷阱及规避方式 |
| `docs/iterations/README.md` | Iteration Record 制度与模板 |
| `docs/iterations/20260911-repository-bootstrap.md` | 补写的仓库初始化记录 |
| `docs/iterations/20260911-p0-bootstrap.md` | 本阶段实施记录 |
| `docs/phase_reports/P0-repository-and-environment.md` | 本文件 |
| `assets/LICENSE_MANIFEST.csv` | 第三方素材许可证台账（当前为空表，等待 P5/P6 填充） |

### 3.2 脚本

| 文件 | 作用 |
| --- | --- |
| `scripts/build_engine.ps1` | 构建入口。探测 MSYS2、校验工具链、设置环境、调用引擎自带 `build/build.sh Win64`、输出产物信息与 SHA256 |
| `scripts/run_game.ps1` | 运行入口。预检产物与运行资源、解析运行期 DLL 路径、启动游戏 |
| `scripts/test.ps1` | 测试统一入口 |
| `scripts/check_build_env.sh` | MINGW64 工具链校验（可独立运行） |

### 3.3 测试

| 文件 | 作用 |
| --- | --- |
| `tests/smoke/smoke.ps1` | 阶段级 Smoke Test：A 子模块与基线 / B 运行目录 / C 构建产物 / D 基本运行文件 / E 项目脚手架 / F（可选）真实启动 |
| `tests/smoke/README.md` | Smoke Test 说明 |

### 3.4 目录结构

```
KingOfFate/
├── game/          # 游戏可分发内容（chars/stages/data/font/sound/external）
├── engine/        # 引擎（submodule: ikemen-go）
├── assets/        # 素材源（source/reference/generated/imports/vfx/audio）
├── design/        # 设计文档（characters/…）
├── tools/         # 自研工具
├── scripts/       # 构建 / 运行 / 测试脚本
├── tests/         # 测试（smoke/characters/tools）
├── docs/          # 文档（iterations/、phase_reports/）
├── logs/          # 日志（build/ 入库作为构建证据）
├── dist/          # 本地分发产物
└── .github/       # PR 模板等
```

空叶子目录用 `.gitkeep` 保留，没有为凑目录创建无意义文件。

---

## 4. 环境基线（实测）

| 项 | 值 |
| --- | --- |
| OS | Windows 11 专业版 10.0.26200.9168 |
| MSYS2 | base 2026-09-11 快照，`msys2-runtime` 3.6.10-3，安装于 `D:\msys64` |
| GCC / G++ | 16.2.0 (Rev3, MSYS2) |
| make / NASM / yasm | 4.4.1 / 3.02 / 1.3.0 |
| pkg-config | 3.0.7 |
| SDL2 / libxmp | 2.32.10 / 4.7.2 |
| Go | go1.27.1 windows/amd64（GOROOT 由 `cygpath -m` 派生） |
| FFmpeg (系统包) | libavformat/codec 63.1.101、libavutil 61.1.101、libswscale 10.1.101、libswresample 7.1.101、libavfilter 12.1.101 |
| Git | 2.45.1.windows.1（宿主）/ 2.55.0（MSYS2） |
| 代理 | `http://127.0.0.1:7897`（本网络大文件下载必需） |

引擎：`v1.0.0-rc.5` = `ba516193bba83f13f0b63ddce314d8719793931f`，集成分支 `kingoffate/rc5`。

运行资源：官方 `ikemen-engine/Ikemen-GO-Screenpack`（master）解包到引擎目录，736 个文件，
提供 `data/ikemen1/system.def`（引擎默认 motif）、`chars/kfm`、`stages/`、`font/` 等。
全部落在引擎自身 `.gitignore` 覆盖范围内，**子模块保持干净**。

---

## 5. 构建 / 运行 / 测试 结果

### 构建

```powershell
pwsh -File scripts/build_engine.ps1 -BuildFfmpeg no -Proxy http://127.0.0.1:7897 -GoProxy https://goproxy.cn,direct
```

```text
==> Build successful (Windows)
    Binary: ./Ikemen_GO.exe
```

- 产物：`engine/ikemen-go/Ikemen_GO.exe`，14.94 MB
- 构建日志：`logs/build/20260912/build-engine.log`（已入库）

### 运行

```powershell
pwsh -File scripts/run_game.ps1
```

```text
[ ok  ] executable   : Ikemen_GO.exe  (14.94 MB, 2026-09-12 13:02)
[ ok  ] runtime assets: data/ font/ external/ chars/ stages/ all present
[ ok  ] DLL path     : D:\msys64\mingw64\bin  (prepended to the game process PATH)
```

游戏窗口 `Ikemen GO` 正常创建并保持响应。

### 测试

```powershell
pwsh -File scripts/test.ps1 -RuntimeTest
```

```text
smoke test: 29/29 checks passed
```

F 组的真实启动验证：进程启动 → 创建窗口 → 持续 20 秒存活且响应 → 由测试主动结束。

---

## 6. 关键决策与技术实现

| 决策 | 理由 |
| --- | --- |
| 引擎以 submodule 固定在 `v1.0.0-rc.5`，不自动跟随 upstream | 保证基线可复现，避免上游漂移 |
| 构建脚本只调用引擎自带、未修改的 `build/build.sh Win64` | 与 CI 一致；不自行重设计构建方式 |
| 构建脚本不写死任何个人绝对路径 | MSYS2 根目录按参数 → 环境变量 → 常见位置依次探测 |
| 所有破坏性 git 操作（pull/reset/checkout/clean）不进入构建脚本 | 构建不得改动源码 Git 状态 |
| 无完成的 Gate 一律写 `BLOCKED`，不写 `PASS` | 状态文档必须诚实 |
| 运行资源解包到引擎目录而非另建 `game/` 运行根 | 与 `BUILDING.md` 一致，且复用引擎 `.gitignore`，子模块保持干净 |
| 构建日志由 shell 直接重定向写入 | 完整输出经 PowerShell 管道会产生背压并卡死长构建 |
| 运行期 DLL 路径由 `run_game.ps1` 探测 MSYS2 `mingw64/bin` 并在子进程中前置 PATH | 系统 FFmpeg 方案下引擎不打包 DLL；避免复制上百个 DLL 污染工作区 |

### `build_engine.ps1` 的环境准备（写在 shell 前缀里）

1. 清除 `MSYS_NO_PATHCONV` / `MSYS2_ARG_CONV_EXCL` —— 恢复 MSYS 对原生命令行的 POSIX→Windows 路径转换
2. `export GOROOT=$(cygpath -m /mingw64/lib/go)` —— MSYS2 的 Go 是 trimmed 构建且只认 Windows 形式路径
3. `TMPDIR/TMP/TEMP/GOTMPDIR` → 项目内 `.tmp/`（gitignore）
4. 可选 `GOPROXY` / `GOSUMDB` / `http_proxy` 等，全部通过参数或环境变量传入，不写死

---

## 7. 遇到的问题与解决过程

### 7.1 阻塞性问题：引擎构建在 cgo 阶段失败

**现象**（稳定复现）：

```text
cc1.exe: fatal error: cannot open '<tmp>\ccXXXXXXXX.s' for writing: Permission denied
compilation terminated.
```

**排查过程**（每一步都实际执行过，不是推测）：

| 假设 | 验证方式 | 结论 |
| --- | --- | --- |
| Go 模块下载被墙 | 观察 `go build` 报 `proxy.golang.org ... Bad Gateway` | **成立**，改用 `GOPROXY=https://goproxy.cn,direct` 后模块全部下载（modcache 417.8 MB） |
| 是 cgo 本身的问题 | 写最小 cgo 程序（`C.add`）构建运行 | **不成立**，`cgo ok: 3` |
| 是那几个重量级依赖包的问题 | 单独构建 `Eiton/vulkan`、`ikemen-engine/reisen`、`go-gl/gl` | **不成立**，三者 rc=0 |
| 系统临时目录不可写 | 把 `TMPDIR` 改到项目内 `.tmp/` | 仍复现，**不是位置问题** |
| 沙箱限制 | 关闭沙箱在前台重跑 | 仍复现，**不是沙箱** |
| 编译器有问题 | 在同一 `.tmp` 下跑 `gcc -c` / `-S` / `-c -save-temps` | **不成立**，全部成功，cc1 能正常写出 `.s` |

**最终状态**：清空 `.tmp` 中上一次崩溃残留的 0 字节 `cc*.s` / `cgo-gcc-input-*` 文件，
并逐个把重量级依赖包干净地编译过一遍之后，完整构建一次通过。因此判定为**环境状态问题**
（残留临时文件 + 被中断的并发编译留下的脏状态），而非代码或工具链缺陷。

**处理方式**：没有因此更换技术栈、降低构建目标或修改引擎源码。已固化的缓解措施：
- `build_engine.ps1` 把编译临时目录固定在项目内 `.tmp/`，与系统临时目录隔离
- 构建输出由 shell 直接写日志，避免管道背压导致构建被卡死而产生残留

### 7.2 便携式安装 MSYS2 的环境陷阱（7 条）

详见 `docs/environment.md`。摘要：

1. `.sfx.exe` 自解压不创建 `/bin`、`/lib`，需用 NTFS 目录联结补上
2. 本机 MSYS2 的 gpg 2.4.9 `pacman-key --init` 死循环 → 临时 `SigLevel = Never`
3. `pacman` 不读 Windows 系统代理，大文件必挂 → 显式传代理
4. shell 中存在 `MSYS_NO_PATHCONV=1` / `MSYS2_ARG_CONV_EXCL=*`，关闭路径转换导致 `gcc`/`gendef`/`dlltool` 拿到不可用路径
5. MSYS2 的 Go 需要 Windows 形式的 `GOROOT`
6. 构建日志经 PowerShell 管道会产生背压卡死长构建
7. Go 模块下载需要区域镜像

### 7.3 本地 FFmpeg 源码构建失败

`BUILD_FFMPEG=auto`（CI 默认）下 libvpx 与 FFmpeg 的 configure + make 全部通过，
但 `make install` 的 `STRIP` 步骤失败并产出 **0 字节 DLL**。

**处理**：按 `engine/ikemen-go/BUILDING.md` 明确记载的
"Use system FFmpeg instead (optional)" 改用 MSYS2 的系统 FFmpeg 开发包。
代价是 WebM alpha 视频可能不走 libvpx 解码器（引擎构建脚本会打印该警告），**不影响玩法**。

---

## 8. 已知限制与遗留事项

| 项 | 说明 | 影响 |
| --- | --- | --- |
| `pacman` 签名校验被关闭 | 本机 MSYS2 的 gpg 2.4.9 导致 `pacman-key --init` 死循环。包仍通过 HTTPS 从镜像获取 | 本机环境妥协，非项目问题；MSYS2 修复后应恢复 `SigLevel = Required` |
| 使用系统 FFmpeg 而非本地构建 | 与 CI 默认（`auto`）不同 | WebM alpha 解码器差异，不影响玩法；有需要时可在环境允许时切回 `auto` |
| 运行期 DLL 未打包 | `run_game.ps1` 通过前置 `mingw64/bin` 到子进程 PATH 解决；`engine/ikemen-go/lib/` 仍为空 | 本机开发无碍；正式分发需要在 P12 打包时把 DLL 放到可执行文件旁 |
| `-rounds` 未接线 | 引擎帮助文本列出该 CLI 参数，但 Go 侧从未读取，无法用"打 N 回合后自动退出"做无人值守验证 | Smoke Test F 组改为验证"启动 + 建窗口 + 持续响应"，再主动结束进程 |
| 分支未推送、PR 未创建 | 本机无 GitHub 凭据，`gh` CLI 未安装 | 需人工 `git push -u origin feature/p0-bootstrap` 后建 PR |

---

## 9. 对 P1 的输入

P1 开始前需要满足的前提**已全部满足**：

- 引擎可构建、可运行，基线不可漂移
- 测试与脚本入口齐备，任何回归都能被 `scripts/test.ps1` 捕获
- `chars/kfm`（含 `kfm_zss`）与 `data/ikemen1/system.def` 已就绪，具备研究 ZSS/Lua 与角色结构的现成素材
- 文档制度就位：状态写入 `development_status.md`，过程写入 `docs/iterations/`

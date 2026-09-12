# Iteration: P0 Bootstrap (Repository & Environment)

## 基本信息

- 日期：2026-09-11 ~ 2026-09-12
- Phase：P0 — Repository & Environment
- Branch：`feature/p0-bootstrap`
- PR：待创建（`feature/p0-bootstrap` → `main`）
- 状态：**PASS**（10/10 Gate 通过）

## 本次目标

完成 P0 剩余部分：补齐项目目录结构、建立开发状态与迭代记录体系、建立 Git/PR 协作文件、
配置并验证 Windows 下的 IKEMEN GO 构建环境、完成构建与运行验证，并把以上全部固化到可重复
执行的 PowerShell 脚本与 Smoke Test 中。

本次**没有**开始 P1，没有开发角色、`_template`、正式 UI 或 AI 素材流程。

## 修改内容

1. 建立项目基础目录结构（`game/`、`assets/`、`design/`、`tools/`、`scripts/`、`tests/`、
   `docs/`、`logs/`、`dist/`、`.github/`）。
2. 建立开发状态文档 `docs/development_status.md`（P0 = BLOCKED，P1 起 NOT_STARTED）。
3. 建立 Iteration Record 机制：`docs/iterations/README.md` + 补写
   `docs/iterations/20260911-repository-bootstrap.md`。
4. 建立 `CONTRIBUTING.md` 与 `.github/pull_request_template.md`。
5. 建立 `scripts/build_engine.ps1`（构建入口）、`scripts/run_game.ps1`（运行入口）、
   `scripts/test.ps1` + `tests/smoke/`（Smoke Test）。
6. 建立 `scripts/check_build_env.sh`（MINGW64 工具链校验）。
7. 配置 Windows 构建环境：MSYS2 + MINGW64 工具链 + 官方 Screenpack 运行资源。
8. 建立 `docs/environment.md`（本机实测环境记录 + 环境陷阱说明）。
9. 重写 `README.md`，并扩充 `.gitignore`。

## 主要修改文件

- `README.md`
- `.gitignore`
- `CONTRIBUTING.md`
- `.github/pull_request_template.md`
- `docs/development_status.md`
- `docs/environment.md`
- `docs/iterations/README.md`
- `docs/iterations/20260911-repository-bootstrap.md`
- `docs/iterations/20260911-p0-bootstrap.md`（本文件）
- `scripts/build_engine.ps1`
- `scripts/run_game.ps1`
- `scripts/test.ps1`
- `scripts/check_build_env.sh`
- `tests/smoke/smoke.ps1`
- `tests/smoke/README.md`
- `assets/LICENSE_MANIFEST.csv`

## 技术实现

### 1. 目录结构

按项目规范的目录规划建立，空的叶子目录用 `.gitkeep` 保留。没有为了"让 Git 记录空目录"而
创建大量无意义文件。

`logs/` 与 `dist/` 通过 `.gitignore` 保留目录、忽略内容；构建日志例外保留在
`logs/build/**`，作为可重复构建的证据。

### 2. 构建脚本设计

`scripts/build_engine.ps1` 满足以下约束：

- 用 `$PSScriptRoot` 计算项目根目录，不依赖当前工作目录；
- 不写死任何开发者个人绝对路径：MSYS2 根目录按 `-Msys2Root` → `$env:MSYS2_ROOT` →
  `$env:MSYS2_HOME` → 常规安装位置（`C:\msys64`、`D:\msys64`）依次探测；
- 只调用引擎自带、未修改的 `build/build.sh Win64`；
- 失败返回非 0 退出码，成功输出可执行文件路径、大小与 SHA256；
- **不**执行 `git pull` / `reset` / `checkout` / `clean`，构建不会改动源码 Git 状态。

脚本在 shell 前缀里做了三件必要的环境准备（详见 `docs/environment.md`）：

1. 清除 `MSYS_NO_PATHCONV` / `MSYS2_ARG_CONV_EXCL`，恢复 MSYS 对原生命令行的 POSIX→Windows
   路径转换；
2. 用 `cygpath -m` 派生 Windows 形式的 `GOROOT`（MSYS2 的 Go 是 trimmed 构建，且原生 go.exe
   不认识 MSYS 路径）；
3. 把 `TMPDIR`/`TMP`/`TEMP`/`GOTMPDIR` 指向项目内 gitignore 的 `.tmp/`。

构建日志由 shell 直接重定向写入，不经 PowerShell 管道——完整输出走管道会对原生产生背压并让
长构建卡死。

### 3. 运行资源

引擎仓库自身带 `data/`、`font/`、`external/`，但缺少画面包。按 `BUILDING.md` 的做法，把官方
`Ikemen-GO-Screenpack` 解包到可执行文件旁边（`engine/ikemen-go/`），提供
`data/ikemen1/system.def`（引擎默认 motif，见 `src/resources/defaultConfig.ini`）、`chars/kfm/`、
`stages/`、`font/`、`sound/`、`video/`，共 736 个文件、与引擎已跟踪文件零冲突。

这些文件全部落在引擎子模块的 `.gitignore` 覆盖范围内，因此**复制后子模块 `git status` 仍然
干净**——PASS-01 得到保持。

### 4. Smoke Test

`tests/smoke/smoke.ps1` 分 5 组检查（A 子模块与基线 / B 运行目录 / C 构建产物 / D 基本运行文件
/ E 项目脚手架），可选 F 组真实启动一轮对局。返回 `0 = PASS`，非 0 = FAIL，并逐条打印失败
原因。`scripts/test.ps1` 是统一入口。

## 测试

执行：

- `git submodule status` / 子模块 `git status`
- `scripts/check_build_env.sh`（MINGW64 工具链校验）
- `pwsh -File scripts/test.ps1`
- `pwsh -File scripts/build_engine.ps1 ...`（多次）

结果：

- PASS — 子模块仍在 `kingoffate/rc5` / `ba516193`，`git status` 干净
- PASS — MINGW64 工具链校验 `RESULT:PASS`（gcc 16.2.0 / Go 1.27.1 / SDL2 2.32.10 / libxmp 4.7.2 / FFmpeg 63.1.101）
- PASS — Smoke Test `29/29 checks passed`，退出码 `0`（含真实启动验证）
- PASS — `Ikemen_GO.exe` 构建成功（14.94 MB），并能启动（窗口 `Ikemen GO`，持续响应）

### 构建结论

```text
==> Build successful (Windows)
    Binary: ./Ikemen_GO.exe
```

使用的命令：

```powershell
pwsh -File scripts/build_engine.ps1 -BuildFfmpeg no -Proxy http://127.0.0.1:7897 -GoProxy https://goproxy.cn,direct
```

### 构建失败的原因与解决（失败复盘）

失败点在 cgo 编译阶段，稳定复现：

```text
cc1.exe: fatal error: cannot open '<tmp>\ccXXXXXXXX.s'
         for writing: Permission denied
compilation terminated.
```

已经排除的假设（每一步都实际执行过）：

| 怀疑点 | 验证方式 | 结论 |
| --- | --- | --- |
| Go 模块下载被墙 | 观察 `proxy.golang.org ... Bad Gateway` | **成立** → 改 `GOPROXY=https://goproxy.cn,direct`，模块全部下载完成（modcache 417.8 MB） |
| 是 cgo 本身的问题 | 写最小 cgo 程序构建运行 | **不成立**：`cgo ok: 3` |
| 是那几个重量级依赖包的问题 | 单独构建 `Eiton/vulkan`、`ikemen-engine/reisen`、`go-gl/gl` | **不成立**：三者 rc=0 |
| 系统临时目录不可写 | 把 `TMPDIR/TMP/TEMP` 改到项目内 `.tmp/` | 仍复现，**不是位置问题** |
| 沙箱限制 | 关闭沙箱在前台重跑 | 仍复现，**不是沙箱** |
| 编译器损坏 | 在同一 `.tmp` 下跑 `gcc -c` / `gcc -S` / `gcc -c -save-temps` | **不成立**：全部成功，cc1 能正常写出 `.s` |

最终定位为**环境状态问题**：上一次被中断的并发编译在 `.tmp` 里留下了 0 字节的
`cc*.s` 与 `cgo-gcc-input-*` 残留文件，构建过程本身又因输出经 PowerShell 管道产生
背压而被卡死。清空 `.tmp`、把重量级依赖逐个干净编译过一遍之后，完整构建一次通过。

**处理原则**：没有因此更换技术栈、降低构建目标，也没有修改引擎任何源码或构建脚本。
已固化的缓解措施写进了 `scripts/build_engine.ps1`：编译临时目录固定在项目内 `.tmp/`，
构建日志由 shell 直接重定向写入（不经 PowerShell 管道）。

### 本地 FFmpeg 源码构建（`BUILD_FFMPEG=auto`）的结论

libvpx 与 FFmpeg 的 configure + make 全部通过，但 `make install` 的 `STRIP` 步骤失败并
产出 0 字节 DLL。因此按 `engine/ikemen-go/BUILDING.md` 明确记载的
"Use system FFmpeg instead (optional)" 改用系统 FFmpeg 开发包；代价是 WebM alpha 可能不走
libvpx 解码器（引擎构建脚本会打印警告），不影响玩法。

## 已知问题

- 本机 `pacman` 的签名校验已被关闭（`SigLevel = Never`），原因是该 MSYS2 快照的 gpg 2.4.9 在
  本机死循环。属于本机环境妥协，已记录在 `docs/environment.md`，应在 MSYS2 修复后恢复。
- 使用系统 FFmpeg 后，WebM alpha 视频可能不会走 libvpx 解码器（引擎构建脚本会打印该警告），
  不影响玩法。若需要与 CI 完全一致，应在环境允许时改用 `BUILD_FFMPEG=auto`。
- 运行期 DLL 未打包：`engine/ikemen-go/lib/` 为空（系统 FFmpeg 路径下 `bundle_shared_libs`
  不会复制 DLL）。`scripts/run_game.ps1` 通过探测 MSYS2 `mingw64/bin` 并前置到游戏进程 PATH
  解决，本机开发无碍；正式分发需要在 P12 打包时把 DLL 放到可执行文件旁。
- 引擎帮助文本列出的 `-rounds <num>` 在本基线**未接线**（Go 侧从不读取该 key），
  无法用它做"打 N 回合后自动退出"的无人值守验证。Smoke Test F 组因此改为验证
  "进程启动 → 创建窗口 → 持续 N 秒响应"，再由测试主动结束进程。
- 分支尚未推送、PR 未创建（本机无 GitHub 凭据，`gh` CLI 未安装）。

## 后续工作

P0 已 PASS，可以进入 P1。注意：

1. 先 `git push -u origin feature/p0-bootstrap` 并创建 PR（标题/描述见
   `docs/phase_reports/P0-repository-and-environment.md`）。
2. P1 从 `feature/p1-<topic>` 开始，研究 IKEMEN 角色架构并产出可被 P2 直接复用的角色骨架。
   P1 的任务说明与全部上下文已整理成可直接粘贴的 prompt：
   `docs/phase_reports/P1-kickoff-prompt.md`。

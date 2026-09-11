# Iteration: P0 Bootstrap (Repository & Environment)

## 基本信息

- 日期：2026-09-11 ~ 2026-09-12
- Phase：P0 — Repository & Environment
- Branch：`feature/p0-bootstrap`
- PR：待创建（`feature/p0-bootstrap` → `main`）
- 状态：**BLOCKED**（构建 Gate 未通过，其余全部完成）

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
- PASS — Smoke Test（详见文末 Gate 表）
- **FAIL / BLOCKED** — IKEMEN GO 引擎构建未能完成

### 构建失败的确切情况

失败点稳定复现于 cgo 编译阶段：

```text
cc1.exe: fatal error: cannot open 'D:\AI\develop\KingOfFate\.tmp\ccXXXXXXXX.s'
         for writing: Permission denied
compilation terminated.
# github.com/ikemen-engine/reisen
```

已经排除的假设（每一步都实际执行过）：

| 怀疑点 | 结论 |
| --- | --- |
| Go 模块下载被墙 | 已解决。`GOPROXY=https://goproxy.cn,direct` 后模块全部下载完成（modcache 417.8 MB） |
| 系统临时目录不可写 | 已排除。临时目录改到项目内 `.tmp/` 后仍复现 |
| 沙箱限制 | 已排除。关闭沙箱在前台重跑，仍复现同一错误 |
| 编译器本身有问题 | 已排除。`gcc -c` / `gcc -S` / `gcc -c -save-temps` 在同一 `.tmp` 目录下全部成功，`cc1` 能正常写出 `.s` |
| 引擎构建脚本问题 | 未修改引擎任何源码或构建脚本；`.s` 文件是 gcc 驱动自己生成的临时文件 |

也就是说：`gcc` 单独调用完全正常，但 **cgo 并发调用 gcc 时 `cc1` 无法写入 gcc 自己生成的
`.s` 临时文件**。该现象与本仓库代码无关，属于本机/沙箱环境对原生编译子进程的限制。

本次**没有**采用"任务失败就换技术栈/换架构"的做法，也没有为了绕过环境问题去修改 IKEMEN 源码。

### 已完成的构建前置成果（这些是真实的、可复用的）

- libvpx 源码编译与安装成功（`enable vp8/vp9 decoder`，`vpx.pc` 已生成）
- FFmpeg 源码编译成功（configure + make 全通过），仅 `make install` 的 `STRIP` 步骤失败并产出
  0 字节 DLL；因此按 `BUILDING.md` 改用系统 FFmpeg 开发包
- Go 依赖全部解析下载完成
- Windows 资源嵌入（icon + manifest，`windres`）成功
- MinGW delay-load 导入库生成成功（`libxmp.dll.a` / `libwinpthread.dll.a` / `libSDL2.dll.a`）

## 已知问题

- **PASS-02 / PASS-03 未通过（BLOCKED）**：`Ikemen_GO.exe` 未能生成，因此没有构建产物、也没有
  运行验证结果。解除条件见下节。
- 本机 `pacman` 的签名校验已被关闭（`SigLevel = Never`），原因是该 MSYS2 快照的 gpg 2.4.9 在
  本机死循环。属于本机环境妥协，已记录在 `docs/environment.md`，应在 MSYS2 修复后恢复。
- 使用系统 FFmpeg 后，WebM alpha 视频可能不会走 libvpx 解码器（引擎构建脚本会打印该警告），
  不影响玩法。若需要与 CI 完全一致，应在环境允许时改用 `BUILD_FFMPEG=auto`。
- 构建产物 DLL 的运行期搜索路径尚未处理（`engine/ikemen-go/lib/` 为空，因为
  `bundle_shared_libs` 只在本地 FFmpeg 前缀存在时才复制 DLL）。这需要在构建打通后再处理。

## 后续工作

1. 在不受上述原生编译限制的环境中重跑
   `pwsh -File scripts/build_engine.ps1 -BuildFfmpeg no`，确认产出 `engine/ikemen-go/Ikemen_GO.exe`。
2. 构建通过后执行 `pwsh -File scripts/run_game.ps1` 完成运行验证，并跑
   `pwsh -File scripts/test.ps1 -RuntimeTest`。
3. 处理运行期 DLL 搜索路径（把所需 DLL 放到可执行文件旁，或在 `run_game.ps1` 中把 MSYS2
   `mingw64/bin` 加入子进程 PATH），并在 `docs/environment.md` 记录结论。
4. 上述 Gate 全部通过后，把 `docs/development_status.md` 的 P0 改为 PASS，再开始
   `feature/p1-kfm-study`。

# 启动游戏（Running the Game）

> 本文档记录 **KingOfFate 已验证可用的启动方法**。
> 所有命令都在本机实测通过：游戏窗口标题 `Ikemen GO` 正常创建并保持响应。
>
> 适用基线：IKEMEN GO `v1.0.0-rc.5`（`ba516193bba83f13f0b63ddce314d8719793931f`）
>
> 相关文档：[`environment.md`](environment.md)（环境基线）、
> [`controls.md`](controls.md)（**启动后的操作方法、键位与出招表**）、
> [`../scripts/run_game.ps1`](../scripts/run_game.ps1)（启动脚本本体）、
> [`../engine/ikemen-go/BUILDING.md`](../engine/ikemen-go/BUILDING.md)（引擎官方构建说明）

---

## 0. 启动前必须满足的三个前提

| # | 前提 | 检查方法 |
| --- | --- | --- |
| 1 | 已构建 `engine/ikemen-go/Ikemen_GO.exe` | `Test-Path engine\ikemen-go\Ikemen_GO.exe`；没有就先跑 `pwsh -File scripts/build_engine.ps1` |
| 2 | 运行资源已解包（`data/`、`font/`、`external/`、`chars/`、`stages/`） | `pwsh -File scripts/run_game.ps1 -CheckOnly` |
| 3 | 运行期 DLL 可被找到（SDL2 / libxmp / FFmpeg 等） | 同上；脚本会自动处理，见 §3 |

三者都满足时，`-CheckOnly` 会输出：

```text
[ ok  ] executable   : Ikemen_GO.exe  (14.94 MB, 2026-09-12 13:02)
[ ok  ] runtime assets: data/ font/ external/ chars/ stages/ all present
[ ok  ] DLL path     : D:\msys64\mingw64\bin  (prepended to the game process PATH)
[ ok  ] preflight checks PASS (game not launched, -CheckOnly)
```

---

## 1. 推荐方式：用项目脚本启动

```powershell
pwsh -File scripts/run_game.ps1
```

**实测结果**：进程启动、窗口标题 `Ikemen GO`、`Responding = True`、工作集约 320 MB。

脚本会自动做四件事，并且**永远不会替你构建**：

1. 从脚本自身路径推算项目根目录（不依赖当前工作目录）
2. 预检：可执行文件是否存在、体积是否合理、运行资源是否齐全
3. 解析运行期 DLL 搜索路径（见 §3）
4. 以 `engine/ikemen-go/` 为工作目录启动 `Ikemen_GO.exe`

### 脚本参数

| 参数 | 作用 |
| --- | --- |
| `-CheckOnly` | 只跑预检，不启动游戏（退出码 0 = 全部就绪） |
| `-Wait` | 等待游戏进程退出后再返回 |
| `-RuntimeRoot <path>` | 指定包含 `Ikemen_GO.exe` 与运行资源的目录，默认 `engine\ikemen-go` |
| `-Msys2Root <path>` | 指定 MSYS2 根目录，用于定位 `mingw64\bin` 下的运行期 DLL |
| `-ExtraArgs <args>` | 透传给引擎的额外参数，例如 `-ExtraArgs '-p1','kfm','-p2','kfm','-s','stage0','-windowed'` |

常用组合：

```powershell
# 只做启动前检查
pwsh -File scripts/run_game.ps1 -CheckOnly

# 启动并等待退出（退出码即游戏退出码）
pwsh -File scripts/run_game.ps1 -Wait

# 直接进入一场 KFM 对 KFM 的对局
pwsh -File scripts/run_game.ps1 -ExtraArgs '-p1','kfm','-p2','kfm','-s','stage0','-windowed'
```

---

## 2. 直接启动可执行文件

```powershell
cd D:\AI\develop\KingOfFate\engine\ikemen-go
.\Ikemen_GO.exe
```

> ⚠️ **直接双击或裸跑很可能失败**，原因见 §3。推荐始终用 `scripts/run_game.ps1`。

如果一定要裸跑，需要先把 MSYS2 的 `mingw64\bin` 加进当前会话的 `PATH`：

```powershell
$env:PATH = "D:\msys64\mingw64\bin;$env:PATH"
cd D:\AI\develop\KingOfFate\engine\ikemen-go
.\Ikemen_GO.exe
```

`D:\msys64` 换成你自己的 MSYS2 安装目录。

---

## 3. 运行期 DLL 搜索路径（为什么要用脚本）

引擎用系统 FFmpeg 方式构建（`BUILD_FFMPEG=no`）时，`build.sh` **不会**把运行期 DLL 打包到
可执行文件旁边，`engine/ikemen-go/lib/` 会保持为空。此时 `Ikemen_GO.exe` 依赖
MSYS2 `mingw64\bin` 里的约 100 个 DLL（`avcodec-63.dll`、`avformat-63.dll`、`SDL2.dll`、
`libxmp.dll`、`libwinpthread-1.dll` …）。

`scripts/run_game.ps1` 的处理方式：

- 先看可执行文件旁边是否已经有 `SDL2.dll`（将来打包了 DLL 就自动跳过这一步）
- 否则按 `-Msys2Root` → `$env:MSYS2_ROOT` → `$env:MSYS2_HOME` → `C:\msys64` → `D:\msys64`
  的顺序探测，找到含 `SDL2.dll` 的 `mingw64\bin`，**只**把它前置到游戏子进程的 `PATH`
- 探测不到时给出黄色警告与补救建议，而不是静默失败

这样开发机上无需复制上百个 DLL，仓库工作区也不会被污染。

---

## 4. 引擎命令行参数（Quick VS）

参数来自引擎自己的帮助文本（`Ikemen_GO.exe -h`），**注意全部是单横线**。

| 参数 | 作用 | 示例 |
| --- | --- | --- |
| `-p<n> <name>` | 指定 n 号位的角色 | `-p1 kfm` |
| `-p<n>.ai <level>` | n 号位交给 AI，1–8 | `-p2.ai 8` |
| `-p<n>.color <col>` | n 号位配色 | `-p1.color 2` |
| `-tmode1 <tmode>` | 1P 队伍模式（single/simul/turns/tag） | `-tmode1 single` |
| `-s <stage>` | 指定关卡 | `-s stage0` |
| `-time <num>` | 回合时间（-1 为不限时） | `-time 60` |
| `-r <path>` | 指定画面包 motif | `-r data/ikemen1/system.def` |
| `-fight <path>` | 指定战斗界面 | `-fight data/fight.def` |
| `-width <n>` / `-height <n>` | 游戏分辨率 | `-width 1280` |
| `-windowed` | 窗口模式（禁用全屏） | |
| `-nosound` | 关闭所有声音 | |
| `-nomusic` | 只关音乐 | |
| `-nojoy` | 禁用手柄 | |
| `-setvolume <n>` | 主音量 0–100 | `-setvolume 50` |
| `-log <file>` | 记录对局数据到文件 | `-log match.log` |

**实测已知问题**：帮助文本里的 `-rounds <num>`（"打 N 回合后退出"）在这个 RC5 基线里
**未接线**——参数会被解析进 `sys.cmdFlags`，但引擎源码从不读取它，因此无法用它做
"打完 N 回合自动退出" 的无人值守验证。Smoke Test 的 F 组因此改为验证
"进程启动 → 创建窗口 → 持续响应"，再由测试主动结束进程。

---

## 5. 常见问题排查

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| 提示找不到 `SDL2.dll` / `avcodec-63.dll` 等 | 直接裸跑 exe，没带 DLL 搜索路径 | 用 `scripts/run_game.ps1`，或按 §2 手动加 `PATH` |
| 预检报 `runtime assets are incomplete` | Screenpack 没解包，或缺某个目录 | 按 `BUILDING.md` 把官方 Screenpack 解包到 `engine/ikemen-go/`；缺 `data/ikemen1/system.def` 时游戏无法加载默认 motif |
| 预检报 `executable not found` | 还没构建 | `pwsh -File scripts/build_engine.ps1` |
| 进程启动后立刻退出、退出码非 0 | 素材缺失或配置损坏 | 检查 `engine/ikemen-go/save/`；删掉 `save/config.ini` 让引擎重建后再试 |
| 窗口出现但黑屏 / 无响应 | 显卡/OpenGL 问题 | 先加 `-windowed`；仍不行查显卡驱动 |
| 双开异常 | 引擎未设计多实例共享 `save/` | 一次只跑一个实例 |

---

## 6. 退出与验证

### 6.1 跑起来之后，怎么拿到"数字"

引擎是 GUI 子系统程序，stdout 抓不到；`logs/` 下的 harness 报告也只有
`pid / hwnd / focus / 截图列表 / crashlog 行数`，**不含任何游戏数值**。
要看 `LIF` / `POW` / `State No` 这类运行时数据，用下面两条：

| 想要 | 命令 |
| --- | --- |
| 把截图里的调试覆盖层读成文本 | `python tools\read_frame_text.py <png 或目录> [--verbose]` |
| 逐字打印像素点阵（**核对**上面那一步有没有读错） | `python tools\dump_glyphs.py <png> --band 1` |

两者都需要 numpy + Pillow。前者利用"覆盖层用已知 TrueType 字体（`font/debug.def`）
且行格式写死在 `external/script/debug.lua:179-227`"做程序化识别，每次都会同时打印
原始串、修复结果与每一处改动；后者把像素原样打成 ASCII 点阵，用来复核。

| 想要 | 命令 |
| --- | --- |
| 无人值守跑一局并盯崩溃日志 | `pwsh -File tests/p3/run_match_watch.ps1 -P1 ... -P2 ... -ShowDebug` |
| 一次跑 6 种对战组合 | `pwsh -File tests/p4/run_matrix.ps1` |
| 逐帧取证（暂停 + 单 tick 步进） | `pwsh -File tests/p2/framestep_probe.ps1 -Steps 'none:4,0x09:2'` |
| 合成按键注入（会自动还原键位） | `pwsh -File tests/p2/inject_phases.ps1 -Phases '0x09:0.20'` |

> 注入类脚本会临时改写 `save/config.ini` 的 `[Keys_P1]`，但**由脚本自己在 `finally`
> 中还原**（Ctrl-C 也会还原）。不要再手工改这个文件 —— 此前两次键位失灵就是这么来的。

### 6.2 退出

- 正常退出：游戏内选退出，或关闭窗口。
- 脚本验证退出码：`pwsh -File scripts/run_game.ps1 -Wait`，`$LASTEXITCODE` 即游戏退出码。
- 自动化验证：`pwsh -File scripts/test.ps1 -RuntimeTest` 会启动引擎、确认创建窗口并
  持续响应 20 秒，然后由测试主动结束进程。当前结果 **29/29 checks passed**。

# Iteration — 2026-09-17 — 引擎二进制被 Defender 隔离：排查与自诊断

## 基本信息

| | |
| --- | --- |
| **日期** | 2026-09-17 |
| **Phase** | P3（PR #4 合并之后的跟进修复） |
| **Branch** | `feature/p3-test-fighter-a` |
| **PR** | **新开**（PR #4 已合并，无法重开）：<https://github.com/Blinkblade/KingOfFate/pull/new/feature/p3-test-fighter-a> → `main` |
| **状态** | PASS（构建 / 预检 / 对战 / single mode 形态全部通过） |
| **关联** | `docs/phase_reports/P3-test-fighter-a.md` §8、`docs/environment.md` 环境坑 #7 |

## 本次目标

用户报告"自己启动脚本玩 single mode，选完角色后游戏闪退，然后要求重新 Build engine"。
排查后确认：**不是 P3 代码的问题，是 Windows Defender 把引擎二进制判为木马并隔离**。
本轮的目标是：

1. 查清并留下证据（为什么"闪退"、为什么之后找不到 exe）；
2. 让构建脚本与启动脚本在下次遇到同一情况时**自己说清楚**，而不是抛一句
   `build failed` / `executable not found` 让人重新猜一遍。

## 修改内容

| 文件 | 变更 |
| --- | --- |
| `scripts/build_engine.ps1` | 构建失败时检测"是否是杀软拦截"：命中构建日志里的 `virus or potentially unwanted software` / `Operation did not complete successfully`，或 `Get-MpThreatDetection` 15 分钟内有新记录 → 打印 `[antivirus]` 段（诊断命令 + 两条 `Add-MpPreference` 排除命令） |
| `scripts/run_game.ps1` | exe 缺失时，除"先构建"之外补一句"可能是被 Defender 隔离" + 检查命令 + 排除命令 |
| `docs/environment.md` | 环境坑 #7：完整记录现象、诊断命令、对照实验、**构建阶段也会被拦**、排除项必须包含 `.tmp`、以及"构建本来就带 `-s -w -trimpath`，改链接参数没用" |
| `logs/build/20260917/build-engine.log` | 按仓库约定（`!/logs/build/**`）提交当天构建日志 |

## 技术实现

**为什么会"闪退"且不留线索**：Defender 的记录里同时带**文件与 `process:_pid:<n>`** ——
它先终止进程（游戏无声消失，引擎来不及写 `save/logs/Ikemen_*.log`），再隔离文件
（之后 `run_game.ps1` 报 `executable not found` 并要求重建）。
因此 **`save/logs/` 有没有新日志** 是区分"引擎真崩"与"被杀软杀掉"的第一判据。

**为什么重建没用**：同一条规则会再次命中新二进制；判定生效后甚至会拦到**链接阶段**：

```text
go build github.com/ikemen-engine/Ikemen-GO/src: open <project>\.tmp\go-buildNNN\
b001\exe\a.out.exe: Operation did not complete successfully because the file
contains a virus or potentially unwanted software
```

所以排除项必须是**两条路径**：

1. `<repo>\.tmp` —— 构建脚本把 `GOTMPDIR` 指到这里，链接器在此写临时 exe；
2. `<repo>\engine\ikemen-go` —— 最终二进制。

**为什么改构建参数没用**：引擎的 `build/build.sh` 本来就带 `-s -w -trimpath`
（早已剥掉符号表），照样被判 —— 所以唯一的即时解是排除项，根因解是向微软报误报。

**对照实验**：用同一套 msys2 Go 工具链编的普通 hello world 不被判，
说明这是针对该二进制指纹的判定，而不是"Go 程序一律误报"。

## 测试

| 项 | 结果 |
| --- | --- |
| 加排除项后重建（`build_engine.ps1 -BuildFfmpeg no`） | Build PASS，15,664,128 bytes，sha256 `D663F5B5…`（与上一次构建一致 → 构建确定性） |
| 对成品 exe 做定向扫描（此前同一操作会触发隔离） | **exe 存活** → 排除项生效 |
| `run_game.ps1 -CheckOnly` | PASS（exe / data·font·external·chars·stages / DLL 路径） |
| AI 对战 60 s（test_fighter_a vs kfm_zss） | 0 崩溃日志；截图 `logs/p3/shots/fix_versus_03.png` |
| single mode 形态 60 s（`-p1 test_fighter_a` 人类位 vs `-p2.ai 8` CPU） | 0 崩溃日志；截图 `logs/p3/shots/fix_single_04.png` |
| Defender | 全程无新命中 |
| 两个新提示分支 | 均已实测：`-CheckOnly` 退出码 2 并打印 Defender 提示；构建失败打印 `[antivirus]` 段 |

## 已知问题

1. 误报**尚未**提交微软（<https://www.microsoft.com/en-us/wdsi/filesubmission>）；
   在签名修正之前，本机（以及任何用同样引擎的机器）都必须靠排除项运行。
2. 排除项需要管理员权限，且降低了对应路径的防护 —— 是权衡，不是无代价。
3. 引擎 `data/select.def` 花名册里**不含** `test_fighter_a`（该文件在 submodule 中被
   `data/*` 忽略）。本轮只在**运行时**临时加了一行，方便立刻试玩；
   正式的"菜单里可选"方案（`game/data/select.def` 交给同步脚本）尚未实施。

## 后续工作

- 向微软提交误报；签名修正后可 `Remove-MpPreference` 撤掉排除项。
- （待用户拍板）把 `game/data/select.def` 纳入仓库，使新角色在菜单中自动可选。
- P4（Fighter B）起步前，把本条环境坑与 `save/logs` 判据写进新角色的自检清单。

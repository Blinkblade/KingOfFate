# 2026-11-03 — 启动被一个 Lua 残留探针卡死（以及两处被它挡住的启动缺陷）

**起因**：负责人报「咋卡住了进不去」，附截图 = 引擎停在 `NOW LOADING`，弹窗
`Error: .\external\mods\kofprobe.lua:1: KOFPROBE: module loaded`。

**结论**：与角色、招式、判定框全部无关。是 10-31 凌晨调查「Lua 能不能拿到运行时数据」时
留在 runtime 里的一行探针，每次启动都在 NOW LOADING 阶段主动报错退出。

---

## 一、根因

`engine/ikemen-go/external/mods/kofprobe.lua` 全文只有一行：

```lua
error("KOFPROBE: module loaded")
```

而引擎在启动时会 **`require` 该目录下每一个 lua**（`external/script/main.lua:3986`）：

```lua
for _, v in ipairs(getDirectoryFiles('external/mods')) do
	if v:lower():match('%.([^%.\\/]-)$') == 'lua' then
		table.insert(t_modules, v)
	end
end
...
for _, v in ipairs(t_modules) do
	...
	require(v:gsub('[/\\]+', '.'))
end
```

日志 `engine/ikemen-go/save/logs/Ikemen_2026-11-03_00-58-19.log` 原文：

```text
Engine error
Error: .\external\mods\kofprobe.lua:1: KOFPROBE: module loaded
stack traceback:
	[G]: in function 'error'
	...
	external/script/main.lua:4000: in main chunk
```

**为什么没被更早发现**：`external/mods/` 在 `.gitignore` 里，所以 `git status` 永远干净，
残留文件对任何代码检查都不可见 —— 只有"启动游戏"这一个动作会撞上它。

## 二、修复（三处）

### 1. 移走探针，先让游戏能开

`Move-Item` 到 `.tmp/runtime-leftovers/kofprobe.lua`（不直接删，留证）。
`external/mods/` 现在只剩 `.keep`。

验证：`tests/p3/run_match_watch.ps1 -P1 archer -P2 archer -Ai1 8 -Ai2 8 -RunSec 22`
→ exit 0，`no engine crash log was produced`（22 秒镜像 AI 对局）。

### 2. `scripts/run_game.ps1` 加预检，让这个场景下次被挡住

新增 `-AllowMods` 开关与 `external/mods/*.lua` 扫描，在**启动前**拒绝并列出文件名
（`exit 4`）。三条路径都实测过：

| 场景 | 结果 |
| --- | --- |
| 干净 | `[ ok  ] external/mods : no stray lua modules`，exit 0 |
| 放一个 `__precheck_test.lua` | `[fail] external/mods/ holds 1 lua file(s)...` 并打印文件名与时间戳，exit 4 |
| 同上 + `-AllowMods` | `[warn ] ... will be loaded (-AllowMods)`，exit 0 |

提示里给出可直接粘贴的 `Move-Item '<真实路径>\*.lua' <目录外>`。

### 3. `Start-Process` 缺 `-PassThru` → 启动成功后仍报失败

修完预检后首次实跑，游戏窗口确实起来了（PID 39844 响应正常），但脚本最后一行炸了：

```text
run_game.ps1: 在此对象上找不到属性"Id"
EXIT=1
```

原因：`Start-Process` 不加 `-PassThru` 时**不返回对象**，而脚本在
`Set-StrictMode -Version Latest` 下读 `$proc.Id` 直接抛属性不存在。
**这个 bug 的位置最坏**：游戏已经拉起来了，脚本却以 exit 1 收场 —— 报"失败"的那次其实是成功的。

修复：`$startArgs.PassThru = $true` 无条件加（`-Wait` 分支本来就有）。

实测：`exit 0` + `[ ok  ] game started (PID 26480)`，窗口 `Responding=True`，
1.5 秒内 CPU 时间增长 0.141 s（游戏主循环在跑，不是卡在错误对话框上）。

## 三、顺带清理的一处死代码

`tests/p6/verify_moves.ps1` 的 `$DirToButton = @{ fwd = 'right'; back = 'left'; ... }` 中
`fwd`/`back` 两项**永远不会生效**（先被上面按 `facing` 换算的 `elseif` 抢走），
但读起来像"改这里就能改方向语义" —— 10-31 的镜像 bug 正是这么写出来的。
改为只保留 `down`/`up`，并在注释里写明为什么故意不写 fwd/back。

抽跑确认没坏：`-Pass moves -Only 25,26` → 升斬 `66/66` PASS、后撤投剑 `56/56` PASS。

## 四、仍未覆盖的缺口

- **各 harness 直连 exe**（`verify_moves.ps1` / `run_match_watch.ps1` / `inject_phases.ps1`），
  不经过 `run_game.ps1` 的预检。残留 lua 会让它们表现为"探针一行都没有"，仍可查但更绕。
  下次改 harness 时可考虑共用同一个小检查。
- `data/` 下 `sound/Title.mp3` 缺失、`select info.coopqueue` 字段告警、kfm720 的
  `Unknown state controller parameter(s): x, y` —— 都是引擎自带素材/配置的既有噪声，
  不影响启动，本次不动。

## 五、复现命令

```powershell
pwsh -File scripts/run_game.ps1 -CheckOnly     # 预检（含 mods 扫描），不启动
pwsh -File scripts/run_game.ps1                # 正式启动，exit 0 = 已拉起
pwsh -File tests/p3/run_match_watch.ps1 -P1 archer -P2 archer -Ai1 8 -Ai2 8 -RunSec 22
```

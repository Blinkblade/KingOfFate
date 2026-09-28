# tests/p2 — Base Fighter Template 验证装置

P2 阶段的运行时验证工具。P1 的 `tests/p1/` 仍是主装置（`capture_match.ps1`
等），本目录只补充 P1 工具表达不了的输入形态。

## inject_phases.ps1 — 多键相位注入

`tests/p1/capture_match.ps1` 一次只能 hold / tap **一个**键，无法表达：

- **同时按**：投技 = 按住前 + 按 C（`0x27+0x0D`）
- **指令序列**：QCF = 下 → 下前 → 前 → A（`0x28` → `0x28+0x27` → `0x27` → `0x09`）

`inject_phases.ps1` 用与 P1 相同的 Win32 注入核心 + 截图方式，按
**"相位（phase）"** 注入：每个相位同时按住若干键一段时间并连拍，
相位之间有短暂的间隔。相位写成 `键:秒` 的列表，`+` 表示同时按：

```powershell
# ★ 多个相位必须写成**一个逗号连接的字符串**（下面这条就是正确写法）
pwsh -File tests/p2/inject_phases.ps1 -Prefix v11_throw `
    -Phases '0x27:2.8,0x27+0x0D:1.0' -ShowDebug -ShowClsn

# 相位顺序就是注入顺序：下 → 下前 → 前 → A（236+A 搓招）
pwsh -File tests/p2/inject_phases.ps1 -Prefix qcf `
    -Phases '0x28:0.06,0x28+0x27:0.06,0x27:0.06,0x09:0.7' -SettleSec 0.02 -ShowDebug
```

> **坑（P3 实测，两个 harness 都会踩）**：不要写成
> `-Phases '0x27:2.8','0x27+0x0D:1.0'`（PowerShell 会当成两个参数）。
> `pwsh -File` 会把多出来的那个按位置绑到**下一个未绑定的参数**上
> —— 实测里 `0x27+0x0D:1.0` 被绑到了 `-RoundTime`，脚本直接报
> `无法将值 "…" 转换为类型 "System.Int32"` 并退出；如果那个参数恰好是
> `-Stage`，则会**静默**用错误的场景名启动，跑出来的结果全是废的。
> 所以：**一个字符串，逗号分隔**。

产出（默认 `logs/p2/shots/`）：每个相位的 before / burst / after 截图 +
一份 `<Prefix>_report.txt`（含实际传给引擎的完整参数）。
**报告里的 `args` 行要逐字核对** —— 它是唯一能发现"参数被错绑"的地方。

## 硬约束（继承自 P1，违反 = 结果无效）

1. **注入输入必须 `-Ai1 0`**（本工具默认值）。AI 控制的 P1 会静默吞掉
   合成输入；自查方法：report 的 `args` 行里**不允许出现 `-p1.ai`**。
2. **可达键位**：只有 TAB（`0x09`）、RETURN（`0x0D`）与方向键
   （`0x25`-`0x28`，E1/E5 实证）能到达引擎；字母键与导航键不可用。
   详见 `docs/p1_experiments.md` §E0 与 `tests/p1/README.md`。
3. **调试覆盖层的 `P1: <n>` 是角色 ID，不是坐标**。位移只能用画面像素
   量（名标签白色像素簇中心）或 `displayToClipboard` 导出。
4. 合成注入到不了的部分（组合键 `x+y` 受身、字母键 B/D 普通技等）
   **如实标注"需真人验证"**，不得用静态阅读冒充运行时证据。
5. **方向键必须带 `KEYEVENTF_EXTENDEDKEY`**（P4 修复）。方向键与数字小键盘共享扫描码，
   缺这个标志时引擎收到的是"小键盘 8"而不是"上"。危险在于**键确实被送达了**，
   所以失败完全静默：角色不响应任何方向，QCF 注入退化成单键攻击。
   本脚本的 `Press-Key` / `Release-Key` 已处理（对 VK `0x21`–`0x2E`）。
6. **相位连拍会把引擎拖慢到约 10% 速度**（P4 实测）。`Save-Shot` 用 `PrintWindow`，
   对 OpenGL 窗口会阻塞渲染线程；相位期间按 ~30 fps 连拍会饿死引擎 ——
   实测 19 秒壁钟只推进 1.9 秒游戏时间。后果是注入**全部落在"回合开始不可控期"**：
   实验什么也没做，但每一张截图都看起来正常。
   需要游戏保持全速时加 **`-NoBurst`**（相位期间不连拍，代价是没有按键保持期间的帧）。
7. **键位由脚本自己快照 / 还原（P4 修复）**。合成输入只能到 TAB / RETURN，所以
   本脚本会把 `save/config.ini` 的 `[Keys_P1]` 临时改成 `x = TAB`、`start = Not used`，
   并在 **`finally` 块里无条件还原**（Ctrl-C 中断也还原）。
   ⚠️ **不要再手工改 `config.ini`** —— 此前两次"Enter 无法确认、a/z 无法攻击"就是
   手工改完忘记还原造成的。验收时用 `config.ini` 的哈希在跑前跑后各记一次即可自查。

## framestep_probe.ps1 — 暂停 + 单帧步进

`inject_phases` 的最小粒度是"秒"，对"取消链落在 20 tick 窗口内"这类问题不够。
本脚本用引擎自带的调试热键把粒度降到 **1 tick**：

- `PAUSE` → `togglePause()`（`external/script/debug.lua:47`）
- `SCROLLLOCK` → `frameStep()`（`debug.lua:48`）
- `Ctrl+D` → 打开状态读出覆盖层（`debug.lua:6`）

```powershell
pwsh -File tests/p2/framestep_probe.ps1 -Steps 'none:4,0x09:2,none:3' -ShowDebug
```

`-Steps` 的写法与 `inject_phases` 相同（**一个逗号连接的字符串**），但单位是
**tick 而不是秒**，`none:N` 表示空推 N 帧。每推一帧存一张图，所以暂停期间截图耗时
**不会**影响时序 —— 这正是它相对 `inject_phases` 的价值。

## 验证矩阵索引

V01–V19 各项与证据文件的对应关系见
`docs/phase_reports/P2-base-fighter-template.md` 的"运行时验证矩阵"一节。

读数值时的经验（P2 审计踩过）：**优先看事后静态帧**（`<Prefix>_01.png` 之类），
连拍帧（`*_burstNN.png`）里的小字号读数容易看错。

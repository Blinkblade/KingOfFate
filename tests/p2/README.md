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
pwsh -File tests/p2/inject_phases.ps1 -Prefix v11_throw `
    -Phases '0x27:2.8','0x27+0x0D:1.0' -ShowDebug -ShowClsn
```

产出（默认 `logs/p2/shots/`）：每个相位的 before / burst / after 截图 +
一份 `<Prefix>_report.txt`（含实际传给引擎的完整参数）。

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

## 验证矩阵索引

V01–V20 各项与证据文件的对应关系见
`docs/phase_reports/P2-base-fighter-template.md` 的验证矩阵表。

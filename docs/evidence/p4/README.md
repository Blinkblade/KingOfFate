# docs/evidence/p4 — P4 归档证据

这里的每一个文件都是**可复现的机器输出**，不是人工摘录。P4 复查（2026-09-20）发现
此前文档里的一批运行时数值没有任何机器依据（harness 报告里只有 `pid / hwnd / focus /
截图列表 / crashlog 行数`），本目录就是替换它们的**新证据**。

| 文件 | 内容 | 怎么重生成 |
| --- | --- | --- |
| `matrix_summary_20260920.txt` | 复查当天的 6 组对战矩阵结果 | `pwsh -File tests/p4/run_matrix.ps1` |
| `matrix_summary.txt` | **最终验收**（2026-09-21，当天重建的二进制）的 6 组结果 | 同上，输出到 `logs/p4/acceptance/matrix` |
| `frames_ocr.txt` | 验收 6 组共 18 帧的调试覆盖层读数（`LIF` / `POW` / `State No` / `ActionID` / `ElemNo`） | `python tools/read_frame_text.py logs/p4/acceptance/matrix` |

## 读数是怎么来的

`tools/read_frame_text.py` 利用两个已知条件把截图里的文字**程序化读成文本**：

1. 覆盖层用的是已知字体 —— `font/debug.def` → `Open_Sans/OpenSans-Bold.ttf`
2. 每一行的内容由 `external/script/debug.lua:179-227` 的 `string.format()` 写死

所以它不依赖"看图"，也就不存在看错的可能；每次运行都会同时打印原始串、修复后的串，
以及每一处改动。

## 读这份证据时要注意的两件事

1. **不要做归因**。例如 `m_asym_ai_02.png` 读到 `State No: 1000 (P1)`，只能说明
   "这一帧 P1 处在状态 1000"，**不能**据此断言"对手掉血是这一发投射物造成的" ——
   同场混战。这正是新流程要求的粒度：报告读到了什么，而不是所以是谁打的。

2. **`State No: 152` 是"防御中"的公共状态**，在 `frames_ocr.txt` 里出现过
   （`m_a_vs_b_03.png`，`Type: L`、`MoveType: H`）。这说明**防御确实会自然发生**，
   但它发生在 AI 对 AI 的混战里，**不能当作 Gate 7「投射物被防御」的证据** ——
   Gate 7 需要 Training 模式里可控的单一场景（`Guard Mode = all`），见
   `docs/howto/gate-verification-in-training-mode.md` §3。

## 截图本体不在仓库里

`logs/*` 被 `.gitignore` 忽略（只有 `logs/build/**` 是反忽略保留的），所以
本目录只归档**文本结论**。需要看原始画面时，按上表的命令重新跑一遍即可。

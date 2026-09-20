# tests/p4 — Test Fighter B 的验证装置

## run_matrix.ps1 — 多组合对战回归

P4 的问题是"同一套体系能不能承载第二个角色"，这就必须让**角色之间真的打起来**，
而且要覆盖各种组合，不是只打一场。手工做这件事的结果是六条复制粘贴的命令行，
谁也没法复现，所以矩阵写在脚本里：

| 配置 | P1 | P2 | AI | 验证什么 |
| --- | --- | --- | --- | --- |
| `b_vs_a` | Test Fighter B | Test Fighter A | 8/8 | 主组合 |
| `a_vs_b` | Test Fighter A | Test Fighter B | 8/8 | **座位互换**（P1/P2 侧是否对称） |
| `mirror_b` | B | B | 8/8 | 镜像：同角色自我对战 |
| `mirror_a` | A | A | 8/8 | 镜像 |
| `asym_ai` | B | A | **3/8** | 双方 AI 等级不同（只让一边全力时是否还成立） |
| `vs_kfm` | B | **KFM** | 8/8 | 与引擎自带参考角色对战（排除"只有我们自己的角色互相能打"） |

```powershell
pwsh -File tests/p4/run_matrix.ps1                  # 6 组全跑，每组约 25 秒
pwsh -File tests/p4/run_matrix.ps1 -Only mirror     # 名字包含 mirror 的组
pwsh -File tests/p4/run_matrix.ps1 -RunSec 40       # 拉长单场时间
```

### 判定标准（关键：不看截图）

一组是否通过，只看 harness 报告里这一行：

```
crashlogs : 0 new during the run
```

这是**机器可判别**的：引擎是 GUI 子系统程序，stdout 抓不到，但它一旦真的出错
（ZSS 解析失败、panic）就会在 `engine/ikemen-go/save/logs/Ikemen_<timestamp>.log`
留下崩溃日志。截图只用于事后读数，不参与"通过/失败"的判断。

每组结束后脚本会打印 `=> PASS` / `=> FAIL`，并在输出目录写一份
`matrix_summary.txt`。

### 只靠 crashlog 会不会漏掉"对手站着不动"的假通过？

会，所以验收时额外做了读数：用 `tools/read_frame_text.py` 读每组最后一帧，
确认双方血量都在动。2026-09-20 与 2026-09-21 两次验收的读数已归档到
`docs/evidence/p4/frames_ocr.txt`（例如 `asym_ai` 组 P1 `LIF:1000` / P2 `LIF:578`，
`vs_kfm` 组 P2 `LIF:832`）。

## 相关

- 逐帧取证：`tests/p2/framestep_probe.ps1`
- 无人值守单局：`tests/p3/run_match_watch.ps1`
- 读数：`tools/read_frame_text.py` · 核对读数：`tools/dump_glyphs.py`
- 人工补测 Gate 6 / 7 的操作手册：`docs/howto/gate-verification-in-training-mode.md`

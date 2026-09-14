# P1 证据目录

本目录存放 P1（IKEMEN Character Architecture）全部实验的**原始证据**。
每个实验的完整推导、数值与结论见 [`docs/p1_experiments.md`](../../p1_experiments.md)。

**判读方式**：`montage_*.png` 是把多帧截图左下角的调试读数条带裁出来纵向堆叠的成品，
逐行读 `State No` / `LIF` / `POW` / `ElemNo` 即可。左边标注的是来源截图文件名。

---

## 证据清单

| 文件 | 对应实验 | 说明了什么 |
| --- | --- | --- |
| `montage_probe1.png`<br>`e5_probe1_report.txt` | **E0** 按键通道探测 | 7 个候选虚拟键里只有 TAB / RETURN 能把输入送进引擎 |
| `e1_base_walk_full.png`<br>`e1_mod_walk_full.png`<br>`e1_base_walk_nametag.png`<br>`e1_mod_walk_nametag.png`<br>`e1_base_walk_report.txt`<br>`e1_mod_walk_report.txt` | **E1** 常量 → 移动 | 同样 0.35 s：基线走到位置读数 56；把 `walk.fwd` 改成 12.0 后已冲到对手身前（nametag 图是放大后的位置读数） |
| `montage_e2_base.png`<br>`e2_base_d23_report.txt` | **E2** 伤害（基线） | `damage: 23` → `P2 LIF 1000 → 977`（Δ **23**） |
| `montage_e2_mod.png`<br>`e2_mod_d137_report.txt` | **E2** 伤害（改动） | `damage: 137` → `P2 LIF 1000 → 863`（Δ **137**） |
| `montage_e3_mod.png`<br>`e3_mod_e1_20_report.txt` | **E3** 动画时序 | 首元素 `2 → 20` 帧 → 动画总时长 **12 → 30**（读数 `(x/30)`），`hitDef` 触发点从第 4 推迟到第 22 tick |
| `e4_base_clsn_seq02_punchX_burst06.png`<br>`e4_base_clsn_report.txt` | **E4** 判定框（基线） | `Clsn1[0] = 16,-80,61,-71` → 手臂前一个细长小攻击框 |
| `e4_mod_clsn_seq02_punchX_burst06.png`<br>`e4_mod_clsn_report.txt` | **E4** 判定框（改动） | 改成 `16,-120,170,-20` → 攻击框巨大化；**受击框、精灵、伤害全部不变** |
| `montage_e5_base.png`<br>`e5_base_cmd_report.txt` | **E5** 命令路由（基线） | `x` 键 → State 200（Δ23）；`y` 键 → State 210（Δ57） |
| `montage_e5_mod.png`<br>`e5_mod_cmd_report.txt` | **E5** 命令路由（改动） | `.cmd` 里 `name="x"` 的 `command` 改为 `y` 后：`x` 键完全失效（State 0），`y` 键改入 State **200**（顺序优先级胜出） |
| `montage_e6_base.png`<br>`e6_base_ai_report.txt` | **E6** AI 优先级（基线） | 8 级 AI 使用 7 种状态（440/810/50/1400/0/181/100/800），第 4 个采样点 KO 对手 |
| `montage_e6_prio.png`<br>`e6_mod_prio_report.txt` | **E6** AI 优先级（改动） | 链首插入 `changeState 210` 后：12 帧中 11 帧为 **210**，对手 `LIF` 全程 1000 未掉 |

---

## 与运行报告的关系

`*_report.txt` 由 `tests/p1/capture_match.ps1` 直接产出（见 [`tests/p1/README.md`](../../../tests/p1/README.md)），
记录了那一轮运行的 args / pid / 窗口句柄 / 是否拿到前台焦点 / 发出了哪些调试键 / hold 序列与抓图结果。
它们是"这一帧到底是怎么来的"的唯一凭证，因此从 `logs/p1/` 复制进本目录并入库。

`logs/p1/` 下还有大量探测期的截图与报告（`diag*`、`e0_*` 等），属于过程产物，**不入库**。

---

## 关于本目录的文件大小

`*.png` 是本目录唯一有体积的内容（合计约 4 MB）。它们是不可再生的原始证据——
重新跑一次游戏也不一定能复现同样的帧，所以按"证据"而非"产物"对待，随代码一起入库。

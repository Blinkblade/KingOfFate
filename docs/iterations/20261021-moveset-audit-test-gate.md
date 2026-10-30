# Iteration: 修复招式体检回归入口漏报失败

## 基本信息

- 日期：2026-10-21
- Phase：P6 — First Final-Art Character
- Branch：`feature/p6-first-final-art-character`
- PR：本轮未创建、未合并
- 状态：本地修复与验证 **PASS**；提交状态以 `git log` 为准。P6 人工验收与负责人决策仍为 **BLOCKED**。
- 接手基线：`00f00ec`，相对本地 `main` 领先 49 个提交。

## 本次目标

从交接文档恢复当前状态，复跑机器检查，并修复接手核验中发现的回归假绿。

## 修改内容

- 修正 Group 9 的参数：`Invoke-Tool` 已负责启动 Python，调用者仅传脚本和角色路径。
- 将失败汇总和逐项报告移至所有组执行之后，包含音效组与招式体检组。
- 招式体检必须执行，移除工具或角色缺失时静默跳过的分支；要求输出包含体检报告标记 `===`，避免将执行异常当作损坏夹具的预期失败。
- 校正进展与交接中的机器核验结果、无限剑制按键及闪身方向要求；保留人工验收状态。

## 主要修改文件

- `tests/tools/run_tool_tests.ps1`
- `docs/PROGRESS.md`
- `docs/HANDOFF.md`
- `docs/TODO-backlog.md`
- 本迭代记录

## 技术实现

原调用的参数为 `@($Python, $Audit, $dir)`，而 `Invoke-Tool` 内部已执行 `& $Python @Arguments`，实际成为 `python python audit_moveset.py ...`。直接复现返回 2，解释器尝试打开仓库根目录下不存在的 `python` 文件。

两条 Group 9 结果在 `$failed` 计算后才加入；总数增加了，失败数量却没更新，因此原入口输出 85/85。逐项报告还在音效组之前打印，进一步隐藏了后续检查结果。修复后先完成全部检查，再统一报告与决定退出码。

## 测试

2026-10-21 实测：

| 检查 | 结果 |
| --- | --- |
| `pwsh -NoProfile -File scripts/test.ps1` | **PASS**：smoke 26/26、asset tool 85/85，含两条 Group 9 的逐项结果 |
| `python tools/audit_moveset.py` | **PASS**：Archer 0 项问题 |
| `python tools/character_validate/validate_character.py game/chars/archer` | **WARN**：0 错误、3 警告，均为动作 110/115/117 前 12 tick 刻意无受击框；退出码 0 |
| 正常角色体检被强制返回 1 | **PASS**：套件显示该项 FAIL，84/85，退出码 1 |
| 损坏夹具体检被强制返回 0 | **PASS**：套件显示该项 FAIL，84/85，退出码 1 |

失败场景通过 `run_tool_tests.ps1 -Python <临时包装脚本>` 注入；包装脚本仅替换指定体检的返回值，其他调用转发至实际 Python，未修改角色或体检工具。临时脚本与原始输出均在忽略目录 `logs/p5/tool-tests/handoff-20261021/`，其中：

- `regression.txt`：修复后的完整回归输出。
- `positive-failure.txt`：正常角色体检失败的传播验证。
- `negative-false-green.txt`：损坏夹具误报通过的传播验证。

## 已知问题

- **BLOCKED（待人工）**：闪身穿箭、伤害手感、音效、剑阵目检及出招表/气账体验未在本轮验收。
- **BLOCKED（待负责人决策）**：可选技术层选择、免费脱身手段是否足够、P6 合并；动画产能需在 P7 前明确。
- AI 对局沿用交接中的历史记录，本轮没有启动引擎，未新增运行时结论。
- `development_status.md`、验收清单及 backlog 旧段落仍有历史描述，接手以已更新的 `PROGRESS.md` 和 `HANDOFF.md` 为准。

## 后续工作

先做人工试玩验收，再决定可选技术层并完成 P6 PR 收尾；不将本次机器回归通过视为 P6 阶段完成。

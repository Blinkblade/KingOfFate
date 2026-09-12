# Iteration: 游戏操作、键位与出招表文档（Controls & Movelist）

## 基本信息

- 日期：2026-09-12
- 分支：`feature/p0-bootstrap`
- 类型：`docs`
- 关联阶段：P0 收尾补充文档（不改变任何 Gate 结果）

## 本次目标

回答"运行后怎么操作游戏、键位设置是什么、出招表是什么、出招表对应哪个文件"，
把答案沉淀为可维护的中文文档，并从 README 与 `docs/running.md` 链入。

## 修改内容

1. 新增 `docs/controls.md`：
   - 菜单导航与主菜单模式列表（来源 `data/ikemen1/system.def`）
   - 对局系统按键：`Esc` 暂停、`F12` 截图、`Alt+Enter` 全屏、`Ctrl+D` 调试
     （逐条注明源码依据：`src/input.go`、`src/system.go:1612`、`src/image.go:2266`）
   - 默认键位：P1/P2 键盘 + 手柄（来源为本机实测生成的 `engine/ikemen-go/save/config.ini`，
     非凭记忆），含"按钮语义（x/y/z 拳、a/b/c 脚 + IKEMEN 扩展 d/w）"与改键入口
   - KFM 完整出招表（普通技/特殊技/投技/必杀/EX/超必杀，含状态号），逐条对应
     `chars/kfm/kfm.cmd` 的 `[Command]` 定义与 `ChangeState` 值
   - `movelist.dat` 记谱法对照（QDF/QDB/DSF/^P/^K 等）
   - "出招表对应哪个文件"速查表：键位 → `save/config.ini`；指令定义 →
     `chars/<角色>/<角色>.cmd`；游戏内出招表 → `chars/<角色>/movelist.dat`
     （由 `.def` 的 `movelist = movelist.dat` 声明，`chars/kfm/kfm.def:25`）；
     招式行为 → `chars/kfm/kfm.cns`
2. `README.md` Running 一节与 `docs/running.md` 相关文档行增加 `controls.md` 链接。

## 验证方式（文档事实核对）

- 键位表逐项摘自 `engine/ikemen-go/save/config.ini` `[Keys_P1]` `[Keys_P2]` `[Joystick_P1]`
- 出招表逐项摘自 `engine/ikemen-go/chars/kfm/kfm.cmd`（指令名、command 串、ChangeState 值）
- `F12` 截图行为核对 `src/input.go:142` 与 `src/image.go:2237-2274`
  （默认保存到引擎运行目录，`Ikemen_GO###.png` 递增）
- 全屏/暂停行为核对 `src/input.go:149-155`、`src/system.go:1612`
- 游戏内 Command List 读取 `movelist.dat` 核对 `external/script/menu.lua`
  （`commandlist` 项、`movelistChar`、`f_commandlistParse`）
- 主菜单模式列表核对 `data/ikemen1/system.def` `menu.itemname.*`

## 已知限制

- 经典 `kfm` 未登记在 `data/select.def` 选人表中（表里是 kfm_zss / kfm720 / kfm_zaxis），
  需用命令行 `-p1 kfm` 参战；P1 角色架构阶段再规范化。
- KFM 未使用重拳 `z`、重脚 `c`（`kfm.cmd` 中有按钮定义但无触发状态），文档已标注。
- P3/P4 默认键位为 `Not used`，需要多人同屏时先在 OPTIONS 里绑定。

## 后续工作

- P1（IKEMEN 角色架构）阶段：规范化自有角色的 `.cmd` / `movelist.dat` 结构与命名。

; ============================================================================
; KingOfFate — Test Fighter B（P4，Zoner）：命令定义（.cmd）
;
; 只做一件事：把"物理按键序列"翻译成"命令名"。
; 命令名 → 状态号的映射在 command.zss 里，不在这里。
;
; ★ 与 Fighter A 的差异（本角色是 Zoner，招式表不同）：
;     去掉了 QCB_x（Fighter A 的升龙踢），换成 **DP_x = 623**（防空上勾拳）。
;     Zoner 的对空要和投射物共用"下前"方向的搓招空间，用 623 可以把
;     236（投射物）与 623（对空）彻底分开 —— 两者序列不同，互不包含。
;
; ★ KingOfFate 是 KOF 风格四键：
;     x = A = Light Punch   轻拳
;     a = B = Light Kick    轻脚
;     y = C = Heavy Punch   重拳
;     b = D = Heavy Kick    重脚
;   c / z / s 保持恒等映射，但不参与游戏逻辑（s 仅用于嘲讽）。
;
; 依据：docs/ikemen_character_architecture.md §5.3
; 实测来源：game/chars/p1_kfm_zss_lab/kfm.cmd
;
; 符号语法速查（详见架构文档 §5.3）：
;   /  按住      ~  检测松开（带数字=蓄力 tick）   $  四向方向判定
;   +  同时按    >  期间不得有其他键动作            ,  序列分隔
; ============================================================================

[Remap]
x = x
y = y
z = z
a = a
b = b
c = c
s = s

; ---------------------------------------------------------------------------
[Defaults]
command.time = 15
command.buffer.time = 1

; ---------------------------------------------------------------------------
; ★ P6 新操作体系（2026-10-02 定版）：**没有任何搓招**
;
;   只用 A / S / Z / X        → 不耗气的普通招式
;   带 C 或 D                 → 消耗气槽的技能（C = 中型，D = 大型，C+D = 终极）
;
;   键盘 → 引擎按钮（config.ini 实测）：
;       A = x 轻拳   S = y 重拳   Z = a 轻脚   X = b 重脚
;       C = c        D = z        ← 这两个之前完全空闲，现在用作"气键"
;
;   所有命令都是「方向 + 按钮」或「按钮 + 按钮」，无序列指令。
;   命令名 → 状态号 的映射在 command.zss。
; ---------------------------------------------------------------------------

; --- 方向 ---
[Command]
name = "holdfwd"
command = /$F
time = 1

[Command]
name = "holdback"
command = /$B
time = 1

[Command]
name = "holddown"
command = /$D
time = 1

; --- 普通招式（不耗气）---
[Command]
name = "x"
command = x
time = 1

[Command]
name = "y"
command = y
time = 1

[Command]
name = "a"
command = a
time = 1

[Command]
name = "b"
command = b
time = 1

; --- 可选技术层 T1：同键二次（同一个普通键按两次 = 该招的二段）---
;   语法：`x, x` 是"按一次 x，之后再按一次 x"。time 是整条序列的窗口。
;
;   ★★ 当前值 36，为什么（2026-10-31 两次修）★★
;   CanTap() 要求 `var(4) = 1`，即**判定帧已经开始**，而四招的判定帧起点不同：
;     轻拳 A = 第 6 tick / 轻脚 Z = 第 5 tick / 重脚 X = 第 9 tick / **重拳 S = 第 13 tick**
;   先试 12 tick：重拳的第二次按键必须赶在判定帧出现之前 → 物理上不可能，
;   所以 State 251 永远进不去（Runtime 实测「T1 连 S」恒为 STATE-MISS）。
;   再试 26 tick（= 覆盖最慢的 S(13) + 13 tick 输入余量）：A / Z / X 全通过，S 仍然 MISS。
;   逐帧数据给出的原因：命令缓冲按 gameTime 计时，而**命中停顿期间 gameTime 照走、
;   状态却不执行**。实测重拳命中停顿吞掉 13 个 gameTime tick：首按在 g418，
;   最早能路由的一 tick 已经在 g442，26 tick 的窗口正好被吃光。
;   → 36 留出余量后 251 = 112/112 PASS。
;   ★ 二段是 lv4（连段收尾），接进来之后不可再取消。
;   ★ 必须排在单键 `x` 之前被判定 —— 依赖的是 command.zss 的路由顺序，不是这里的顺序。
[Command]
name = "TAP_A"
command = x, x
time = 36

[Command]
name = "TAP_S"
command = y, y
time = 36

[Command]
name = "TAP_Z"
command = a, a
time = 36

[Command]
name = "TAP_X"
command = b, b
time = 36

; --- 气键（中型，键盘 C = 按钮 c）---
[Command]
name = "GAS_C"
command = c
time = 1

[Command]
name = "GAS_DC"
command = /$D, c
time = 1

[Command]
name = "GAS_FC"
command = /$F, c
time = 1

[Command]
name = "GAS_BC"
command = /$B, c
time = 1

; --- 气键（大型，键盘 D = 按钮 z）---
[Command]
name = "GAS_Z"
command = z
time = 1

[Command]
name = "GAS_FZ"
command = /$F, z
time = 1

[Command]
name = "GAS_DZ"
command = /$D, z
time = 1

[Command]
name = "GAS_CZ"
command = c+z
time = 1

; --- 移动 / 系统 ---
[Command]
name = "FF"
command = F, F
time = 10

[Command]
name = "BB"
command = B, B
time = 10

[Command]
name = "start"
command = s
time = 1

; --- 闪身（A+Z 同时按，KOF97 的 A+B）：不耗气 ---
[Command]
name = "FLASH_F"          ; → + A+Z
command = /$F, x+a
time = 3

[Command]
name = "FLASH_B"          ; ← + A+Z
command = /$B, x+a
time = 3

[Command]
name = "FLASH_D"          ; ↓ + A+Z
command = /$D, x+a
time = 3


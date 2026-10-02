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

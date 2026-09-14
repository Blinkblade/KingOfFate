; ============================================================================
; KingOfFate — Base Fighter Template : 命令定义（.cmd）
;
; 只做一件事：把"物理按键序列"翻译成"命令名"。
; 命令名 → 状态号的映射在 command.zss 里，不在这里。
;
; KingOfFate 是 4 键游戏：
;   x = 轻拳 (LP)   y = 重拳 (HP)   a = 轻脚 (LK)   b = 重脚 (HK)
; KFM 样例的 c / z 保持恒等映射但不在游戏设计中使用。
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
command.time = 15          ; 命令有效窗口（tick）
command.buffer.time = 1    ; 命令缓冲（1 = 仅在当 tick 有效）

; ===========================================================================
; 超必杀（super）—— 消耗 1 条气，留给 P2 之后填充
; 命名规范：<招式名>，同一招式的多种输入共用一个 name
; ===========================================================================
;[Command]
;name = "Super_Example"
;command = ~D, DF, F, D, DF, x
;time = 20
;buffer.time = 3

; ===========================================================================
; 必杀技（special）
; ===========================================================================
[Command]
name = "QCF_x"
command = ~D, DF, F, x
buffer.time = 3

[Command]
name = "QCF_y"
command = ~D, DF, F, y
buffer.time = 3

[Command]
name = "QCB_x"
command = ~D, DB, B, x
buffer.time = 3

[Command]
name = "QCB_y"
command = ~D, DB, B, y
buffer.time = 3

; ===========================================================================
; 双击方向 —— FF / BB 是引擎要求的固定名，不可改名
; ===========================================================================
[Command]
name = "FF"                ; 前冲（Required，不要删）
command = F, F
time = 10

[Command]
name = "BB"                ; 后跳（Required，不要删）
command = B, B
time = 10

; ===========================================================================
; 组合键 —— recovery 是引擎要求的固定名
; ===========================================================================
[Command]
name = "recovery"          ; 受身（Required，不要删）
command = x+y
time = 1

; ===========================================================================
; 单键（4 键核心）
; 注意：time 越小出招越"紧"，KFM 用 3
; ===========================================================================
[Command]
name = "x"                 ; 轻拳
command = x
time = 3

[Command]
name = "y"                 ; 重拳
command = y
time = 3

[Command]
name = "a"                 ; 轻脚
command = a
time = 3

[Command]
name = "b"                 ; 重脚
command = b
time = 3

[Command]
name = "start"             ; 开始键（嘲讽等待定用途）
command = s
time = 1

; ===========================================================================
; 方向键 —— 四个 hold 命令是引擎要求的固定名，不可删
; ===========================================================================
[Command]
name = "holdfwd"           ; Required，不要删
command = /$F
time = 1

[Command]
name = "holdback"          ; Required，不要删
command = /$B
time = 1

[Command]
name = "holdup"            ; Required，不要删
command = /$U
time = 1

[Command]
name = "holddown"          ; Required，不要删
command = /$D
time = 1

; ============================================================================
; KingOfFate — Base Fighter Template : 命令定义（.cmd）
;
; 只做一件事：把"物理按键序列"翻译成"命令名"。
; 命令名 → 状态号的映射在 command.zss 里，不在这里。
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
command.time = 15          ; 命令有效窗口（tick）
command.buffer.time = 1    ; 命令缓冲（1 = 仅在当 tick 有效）

; ===========================================================================
; 必杀技（special）与超必杀（super）
;
; ★★★ .cmd 的顺序也是优先级 ★★★
;   同一 tick 里若有多个命令同时成立，**先定义的那个**赢（名字归属）。
;   所以"更长的指令"必须写在"它的前缀"前面：
;     超必杀 236236+A  →  必杀 236+A   （前者包含后者）
;   写反了，236236+A 永远只会触发普通的 236+A。
;
; 命名规范：QCF_x / QCB_x / QCF2_x —— 方向型 + 结束键
;   QCF = 236（下、下前、前）   QCB = 214（下、下后、后）   QCF2 = 236236（两圈）
;
; time / buffer.time 说明：
;   time = 25 是刻意放宽的占位值（约 0.42 s）：本阶段优先保证输入链路
;   可被观测，正式角色的输入窗口属于手感调参（见 README）。
;   buffer.time = 14（约 0.23 s）：KOF 风格缓冲 —— 招式收招后指令仍生效一小段，
;   也让"取消"验证能被合成输入稳定复现（P2 实测 buffer 3 太紧）。
;   超必杀的两圈指令更长，因此 time 放到 45（约 0.75 s）。
; ===========================================================================
[Command]
name = "QCF2_x"            ; 236236 + A：Super 超必杀直拳（耗 1000 气）
command = ~D, DF, F, D, DF, F, x
time = 45
buffer.time = 20

[Command]
name = "QCF_y"             ; 236 + C：EX Special 1（耗 500 气）
command = ~D, DF, F, y
time = 25
buffer.time = 14

[Command]
name = "QCF_x"             ; 236 + A：Special 1 突进直拳（不耗气）
command = ~D, DF, F, x
time = 25
buffer.time = 14

[Command]
name = "QCB_x"             ; 214 + A：Special 2 升龙踢（对空，不耗气）
command = ~D, DB, B, x
time = 25
buffer.time = 14

; ===========================================================================
; 双击方向 —— FF / BB 是引擎要求的固定名，不可改名
; （FF = 前冲 State 100，BB = 后跳 State 105，均由公共状态提供）
; ===========================================================================
[Command]
name = "FF"                ; 前冲（Required，不要删）
command = F, F
time = 25                  ; 与必杀一致的宽松窗口（KFM 用 10 = 90 年代手感）；
                           ; 现代手感 + 模板阶段优先保证链路可被观测

[Command]
name = "BB"                ; 后跳（Required，不要删）
command = B, B
time = 25

; ===========================================================================
; 组合键 —— recovery 是引擎要求的固定名
; ===========================================================================
[Command]
name = "recovery"          ; 受身（Required，不要删）
command = x+y
time = 1

; ===========================================================================
; 单键（4 键核心）
; 投技不在这里定义：它复用 y / b + holdfwd/holdback，见 command.zss §⑤
; ===========================================================================
[Command]
name = "x"                 ; A = 轻拳
command = x
time = 3

[Command]
name = "a"                 ; B = 轻脚
command = a
time = 3

[Command]
name = "y"                 ; C = 重拳
command = y
time = 3

[Command]
name = "b"                 ; D = 重脚
command = b
time = 3

[Command]
name = "start"             ; 开始键 → 嘲讽（State 195）
command = s
time = 1

; ===========================================================================
; 方向键 —— 四个 hold 命令是引擎要求的固定名，不可删
; holdfwd / holdback 同时被投技的触发条件使用
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

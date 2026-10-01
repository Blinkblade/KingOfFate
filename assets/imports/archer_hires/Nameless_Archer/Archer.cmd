; サンプルキャラクター『カンフーマン』のコマンドファイルです。
; コマンドに関する設定は４部構成になっています。
;==============================================================================
; Win版専用パート
;==============================================================================
;------------------------------------------------------------------------------
; ここはWin版から（正確にはLinux版から）追加された要素の二つ。
; コマンド関連の初期設定を任意に指定出来るようになった(`・ω・´)
;
;『ボタンリマップ』はボタン配置変更用の項目。
; 定義パートでいちいち変更しなくても良いようになっちゃった。
; 面倒臭い人用かな！（ﾏﾃｺﾗ
;
;『デフォルト設定』では各[Command]で省略した場合の
; 入力受付時間と入力記憶時間を予め決めておく項目。
;
;
; この２項目は省略可能。
;------------------------------------------------------------------------------
;-| ボタンリマップ（ボタンコンフィグ）|---------------------------------------- 第１部

[Remap]
x = x      ;Ｘボタンの入力判定を実際に押すボタンに割り当てる。
y = y      ;Ｙボタン　　　　　　　　　〃
z = z      ;Ｚボタン　　　　　　　　　〃
a = a      ;Ａボタン　　　　　　　　　〃
b = b      ;Ｂボタン　　　　　　　　　〃
c = c      ;Ｃボタン　　　　　　　　　〃
s = s      ;スタートボタン　　　　　　〃

;------------------------------------------------------------------------------
; 例えば「本来Ｘボタンで出す弱パンチをＢボタンに変えたい場合」なら、
;
; x = b
;
; で簡単に出来る。使わないボタンを使っているボタンに割り当てる事も可能。
;------------------------------------------------------------------------------
;-| デフォルト設定 |----------------------------------------------------------- 第２部

[Defaults]
command.time = 15  ;標準のコマンド入力受付時間。
                   ;各コマンドで省略している場合に有効。
                   ;このパラメータを消した場合、デフォルトは１フレームになる。
                   ;（　M.U.G.E.Nでの１フレーム　＝　１／６０秒　）

command.buffer.time = 1  ;標準のコマンド入力記憶時間。
                         ;入力した直後にコマンドを記憶し、
                         ;指を離してもコマンドが成功している状態を
                         ;ここで設定した時間の分維持する。
                         ;１～３０フレームまでの間で設定可能。
                         ;デフォルトは１フレーム。

;============================================================================== 第３部
; コマンド定義パート（入力キーを設定する）
;==============================================================================
;------------------------------------------------------------------------------
; ここがキーとボタンの組み合わせで格闘ゲームにおける
;『入力コマンド』を直接設定・編集するパート。
;
; 一つずつコマンドに名前を付けて入力キーを組み合わせる単純な作業になるけど、
; 組み合わせが独特だから覚えるのは難易度が少し高い。
;
; 下記で「書式の決まり」と「組み合わせに必要なアルファベットと記号」を
; 全て説明しましょう。
;------------------------------------------------------------------------------
;■書式の決まり■
;
; [Command]         ：入力コマンドを１個定義する。
; name = "***"      ：コマンド名を決める。大文字と小文字も区別される。
; command = ###     ：実際に入力するキーを組み合わせる。詳細は後述。
; time = &&&        ：入力受付時間を設定（オプション）。
; buffer.time = @@@ ：入力記憶時間を設定（オプション）。
;
; 小ネタでも説明している通り、登録が可能な数は最大『１２８個』まで。
;
;
;※『必須コマンド名』と書いてるコマンドは、システム側で処理してます。
;　コマンド名を変えたり、消してはいけません。キーの変更は出来ます。
;------------------------------------------------------------------------------
;■必要なアルファベットと記号■
;
; 上記の「command = ###」の『###』に該当する部分で、
; 組み合わせるキーとボタンを設定しなければならない。
;
; ※設定したキーやボタンはM.U.G.E.Nのオプションモードにある
;  「キーコンフィグ」にて設定したキーなどに対応しています。
;
; ★方向キー★（全て必ず大文字で）
;
; 　B 　：「後方」にキーを入れる（ Backward ）
; 　D 　：「下方」にキーを入れる（ Downward ）
; 　F 　：「前方」にキーを入れる（ Forward ）
; 　U 　：「上方」にキーを入れる（ Upward ）
;
; 　DB　：「後ろ斜め下」にキーを入れる（「D」と「B」が同時に入力された事を認識）
; 　UB　：「後ろ斜め上」にキーを入れる（「U」と「B」が同時に入力された事を認識）
; 　DF　：「前斜め下」にキーを入れる（「D」と「F」が同時に入力された事を認識）
; 　UF　：「前斜め上」にキーを入れる（「U」と「F」が同時に入力された事を認識）
;
; ★ボタン★（全て必ず小文字で）
;
; 　a 　：「Ａボタン」を押す
; 　b 　：「Ｂボタン」を押す
; 　c 　：「Ｃボタン」を押す
; 　x 　：「Ｘボタン」を押す
; 　y 　：「Ｙボタン」を押す
; 　z 　：「Ｚボタン」を押す
; 　s 　：「スタートボタン」を押す
;
; ★記号★（入力効果を変化させる命令）
;
; 　/ 　：（スラッシュ）キーやボタンを「押しっぱなし」にしている事を認識する場合に追加する
;
; 　　（例）：　/b       = Ｂボタンを押したままにする
; 　　　　　　　/F       = 前キーを押したままにする
; 　　　　　　　/U,z     = 上キーを押したままＺボタンを入力する
;
;　　━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;
; 　~ 　：（チルダ）キーやボタンが「離された時」を認識する場合に追加する
;
; 　　（例）：　~x       = Ｘボタンを離す
; 　　　　　　　~DF      =「前斜め下」のキーを離す
; 　　　　　　　~DB,F,c  =「後ろ斜め下」を離した後に前キー・Ｃボタンの順番に入力する
;
; 　　　　　　※「ボタンを離すまでの時間（溜め時間）」も設定する事が出来る
;
; 　　　　　　　~30x     = Ｘボタンを押したままにして、３０フレーム以上経ったら離す
; 　　　　　　　~50B,F,a = 後ろキーを５０フレームまで溜めて前キー・Ａボタンの順番に入力する
;
;　　━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;
; 　$ 　：（ドル）方向キーの「複数の内どれかが入力されている事」を認識する場合に追加する
;
; 　　（例）：　$B       =「後方」「後ろ斜め下」「後ろ斜め上」のどれかが入力されている状態
; 　　　　　　　$UF      =「前」「上」「前斜め上」のどれかが入力されている状態
;
; 　　　　　　※この記号は「方向キー」でしか使えません。
;
;　　━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;
; 　+ 　：（プラス）ボタンを「同時押し」している事を認識する場合に追加する
;
; 　　（例）：　x+y      = ＸボタンとＹボタンを同時押しする
; 　　　　　　　a+b+c    = ＡボタンとＢボタンとＣボタンを同時押しする
;
; 　　　　　　※この記号は「ボタン」でしか使えません。
;
;　　━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;
; 　> 　：（グレーターザン）大なり（Win版で追加された記号）
; 　　　　　　　　　　　　「他のキーが入力されていない事を確認して、そのキーを押す」場合
;
; 　　（例）：　a,>~a    = Ａボタン以外が入力されていない状態でＡボタンを離す
; 　　　　　　　F,>~F,>F = 前キー以外が入力されていない状態で前キーを離し、
;　　　　　　　　　　　　　もう一度前キーを入力する
;
;-------------------------------------------------------------------------------
; ●これらの記号は全て組み合わせて使う事が出来る●
;
; 　　（例）：　~80$DB,DF,F,/a+y+c
; 　　　　　　　
; 　　　　　　「後方」「下」「後ろ斜め下」のどれかを８０フレームまで溜めて
; 　　　　　　「前斜め下」→「前」を入力した後、ＡとＹとＣを同時押ししたままにする
;
;---|AI Commands|-----------------------------------------------------------
[Command]
Name = "AI_00"
Command = a, a
Time = 0
[Command]
Name = "AI_01"
Command = a, b
Time = 0
[Command]
Name = "AI_02"
Command = a, c
Time = 0
[Command]
Name = "AI_03"
Command = a, x
Time = 0
[Command]
Name = "AI_04"
Command = a, y
Time = 0
[Command]
Name = "AI_05"
Command = a, z
Time = 0
[Command]
Name = "AI_06"
Command = a, s
Time = 0
[Command]
Name = "AI_07"
Command = b, a
Time = 0
[Command]
Name = "AI_08"
Command = b, b
Time = 0
[Command]
Name = "AI_09"
Command = b, c
Time = 0
[Command]
Name = "AI_10"
Command = b, x
Time = 0
[Command]
Name = "AI_11"
Command = b, y
Time = 0
[Command]
Name = "AI_12"
Command = b, z
Time = 0
[Command]
Name = "AI_13"
Command = b, s
Time = 0
[Command]
Name = "AI_14"
Command = c, a
Time = 0
[Command]
Name = "AI_15"
Command = c, b
Time = 0
[Command]
Name = "AI_16"
Command = c, c
Time = 0
[Command]
Name = "AI_17"
Command = c, x
Time = 0
[Command]
Name = "AI_18"
Command = c, y
Time = 0
[Command]
Name = "AI_19"
Command = c, z
Time = 0
[Command]
Name = "AI_20"
Command = c, s
Time = 0
[Command]
Name = "AI_21"
Command = x, a
Time = 0
[Command]
Name = "AI_22"
Command = x, b
Time = 0
[Command]
Name = "AI_23"
Command = x, c
Time = 0
[Command]
Name = "AI_24"
Command = x, x
Time = 0
[Command]
Name = "AI_25"
Command = x, y
Time = 0
[Command]
Name = "AI_26"
Command = x, z
Time = 0
[Command]
Name = "AI_27"
Command = x, s
Time = 0
[Command]
Name = "AI_28"
Command = y, a
Time = 0
[Command]
Name = "AI_29"
Command = y, b
Time = 0
[Command]
Name = "AI_30"
Command = y, c
Time = 0
[Command]
Name = "AI_31"
Command = y, x
Time = 0
[Command]
Name = "AI_32"
Command = y, y
Time = 0
[Command]
Name = "AI_33"
Command = y, z
Time = 0
[Command]
Name = "AI_34"
Command = y, s
Time = 0
[Command]
Name = "AI_35"
Command = s, a
Time = 0
[Command]
Name = "AI_36"
Command = s, b
Time = 0
[Command]
Name = "AI_37"
Command = s, c
Time = 0
[Command]
Name = "AI_38"
Command = s, x
Time = 0
[Command]
Name = "AI_39"
Command = s, y
Time = 0
[Command]
Name = "AI_40"
Command = s, z
Time = 0
[Command]
Name = "AI_41"
Command = s, s
Time = 0
[Command]
Name = "AI_42"
Command = U, U
Time = 0
[Command]
Name = "AI_43"
Command = U, F
Time = 0
[Command]
Name = "AI_44"
Command = U, D
Time = 0
[Command]
Name = "AI_45"
Command = U, B
Time = 0
[Command]
Name = "AI_46"
Command = F, U
Time = 0
[Command]
Name = "AI_47"
Command = F, F
Time = 0
[Command]
Name = "AI_48"
Command = F, D
Time = 0
[Command]
Name = "AI_49"
Command = F, B
Time = 0

;------------------------------------------------------------------------------
;-| 超必殺技 |-----------------------------------------------------------------

;※名前が同じならば、違うコマンドでも同じステートの技を出す事が可能。

[Command]
name = "imaju"
command = ~B, D, F, c

[Command]
name = "Low Ajax"
command = ~F, D, B, a

[Command]
name = "kakuyoku"
command = ~F, D, B, c

[Command]
name = "Sword barrel"
command = ~F, D, B, b

[Command]
name = "Hrunting"
command = ~B, D, F, a

[Command]
name = "Caladbolg"
command = ~B, D, F, b

;------------------------------------------------------------------------------
;-| 必殺技 |-------------------------------------------------------------------

[Command]
name = "dash slash c"
command = ~F, D, F, c

[Command]
name = "dash slash high"
command = ~F, D, F, b

[Command]
name = "dash slash low"
command = ~F, D, F, a

[Command]
name = "angle shoot c"
command = ~D, B, c

[Command]
name = "unlimited"
command = ~D, F, z

[Command]
name = "shoot c"
command = ~D, F, c

[Command]
name = "shoot high"
command = ~D, F, b

[Command]
name = "shoot low"
command = ~D, F, a

[Command]
name = "angle shoot high"
command = ~D, B, b

[Command]
name = "angle shoot low"
command = ~D, B, a

[Command]
name = "rangeki"
command = ~D, DB, B, /x
;---------------------------

;------------------------------------------------------------------------------
;-| キー２回連続入力 |---------------------------------------------------------

[Command]
name = "FF"       ;必須コマンド名
command = F, F
time = 10

[Command]
name = "BB"       ;必須コマンド名
command = B, B
time = 10

;------------------------------------------------------------------------------
;-| 同時押し |-----------------------------------------------------------------
[Command]
name = "zenten"
command =/F, y
time = 1

[Command]
name = "bakuten"
command =/B, y
time = 1

[Command]
name = "recovery" ;必須コマンド名
command = x+y
time = 1

[Command]
name = "fd"
command = a+x

[Command]
name = "fd"
command = a+y

[Command]
name = "fd"
command = a+b

[Command]
name = "fd"
command = b+x

[Command]
name = "fd"
command = b+y

[Command]
name = "fd"
command = x+y

[Command]
name = "burst"
command = z+a

[Command]
name = "burst"
command = z+b

[Command]
name = "burst"
command = z+x

[Command]
name = "burst"
command = z+y

;------------------------------------------------------------------------------
;-| 方向キー＋ボタン |---------------------------------------------------------
[Command]
name = "F_x"
command = /F, x

[Command]
name = "F_y"
command = /F, y

[Command]
name = "B_x"
command = /B, x

[Command]
name = "B_y"
command = /B, y

[Command]
name = "F_a"
command = /F, a

[Command]
name = "F_b"
command = /F, b

[Command]
name = "B_b"
command = /B, b

[Command]
name = "down_a"
command = /$D,a
time = 1

[Command]
name = "down_b"
command = /$D,b
time = 1

;------------------------------------------------------------------------------
;-| ボタン単発 |---------------------------------------------------------------

[Command]
name = "hold x"
command = /x
time = 1

[Command]
name = "holda"
command = /a
time = 1

[Command]
name = "holdy"
command = /y
time = 1

[Command]
name = "holdb"
command = /b
time = 1

time = 1
[Command]
name = "a"
command = a
time = 1

[Command]
name = "b"
command = b
time = 1

[Command]
name = "c"
command = c
time = 1

[Command]
name = "x"
command = x
time = 1

[Command]
name = "y"
command = y
time = 1

[Command]
name = "z"
command = z
time = 1

[Command]
name = "start"
command = s
time = 1

;---------------------------

;------------------------------------------------------------------------------
;-| 方向キー |-----------------------------------------------------------------

[Command]
name = "holdfwd"   ;必須コマンド名
command = /$F
time = 1

[Command]
name = "holdback"  ;必須コマンド名
command = /$B
time = 1

[Command]
name = "holdup"    ;必須コマンド名
command = /$U
time = 1

[Command]
name = "holddown"  ;必須コマンド名
command = /$D
time = 1

;============================================================================== 第４部
; ステートエントリーパート（技などを出せるようにするための条件を設定）
;==============================================================================
;------------------------------------------------------------------------------
; コマンド名と入力するコマンドを設定しただけじゃ意味が無いので、ここから
;「実際に入力したコマンドでどの番号のステートをどういう条件で出せるか」
; を決めなければならない。
;
; ステートコントローラ「ChangeState」しか使わないけど、
; そんなに難しくないのでトリガーを覚えてたらすぐ出来る。
;
; ここさえ押さえておけば簡単なトリガー設定の流れは覚えられるかと。
;
; エントリーの順番にはある程度の法則があるけど、
; おまけフォルダの「小ネタ.txt」を参照。（波動拳が暴発ﾅﾝﾀﾗｶﾝﾀﾗ）
;
; ChangeStateなどステートコントローラの基本的な設置例は
; おまけフォルダの「テンプレート.txt」を参照。
;------------------------------------------------------------------------------
; ■準常時監視ステート（－１）■
; コマンドファイル（のステートエントリーパート）に必要な項目です。
; 絶対に消してはいけないので要注意。
;
; 通常の食らい状態以外の「P2StateNo」や「TargetState」等で制御された、
; 作成者が任意に指定した相手側の食らいステートに限り、
; 登録したステートコントローラが有効にはなりません。
;------------------------------------------------------------------------------

[Statedef -1] ;←この行は絶対に消さないでね。必須項目です。

;==============================================================================
; 超必殺技
;==============================================================================
;------------------------------------------------------------------------------

[State -1, 無限の剣製]
type = ChangeState
value = 4150
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command ="imaju"
triggerAll = statetype = S
TriggerAll = Var(16) = 1
TriggerAll = life<=200
TriggerAll = Power>2999
trigger1 = ctrl

[State -1, 鶴翼3連]
type = ChangeState
value = 3400
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command ="kakuyoku"
triggerAll = statetype != A
TriggerAll = Power>2999
TriggerAll = numhelper(3401) = 0
TriggerAll = numhelper(3402) = 0
TriggerAll = Var(16) = 1
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 1400 && movecontact
trigger6 = StateNo = 1450 && movecontact
trigger7 = StateNo = 410 && movecontact
trigger8 = StateNo = 430 && movecontact
trigger9 = StateNo = 440 && movecontact

[State -1, ローアイアス]
type = ChangeState
value = 3300
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command ="Low Ajax"
triggerAll = statetype = S
TriggerAll = Power>999
TriggerAll = Var(15) >= 1
trigger1 = ctrl

[State -1, ソードバレル]
type = ChangeState
value = 3200
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command ="Sword barrel"
triggerAll = statetype != A
TriggerAll = Power>999
TriggerAll = Var(15) >= 1
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 1400 && movecontact
trigger6 = StateNo = 1450 && movecontact
trigger7 = StateNo = 410 && movecontact
trigger8 = StateNo = 430 && movecontact
trigger9 = StateNo = 440 && movecontact

[State -1, フルンティング]
type = ChangeState
value = 3100
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = !numhelper(3100)
triggerall = command ="Hrunting"
triggerAll = statetype != A
TriggerAll = Power>999
TriggerAll = Var(15) >= 2
TriggerAll = Var(2) = 0
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 1400 && movecontact
trigger6 = StateNo = 1450 && movecontact
trigger7 = StateNo = 410 && movecontact
trigger8 = StateNo = 430 && movecontact
trigger9 = StateNo = 440 && movecontact
 
[State -1, カラドボルグ]
type = ChangeState
value = 3050
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command ="Caladbolg"
TriggerAll = Power>1999
triggerAll = statetype = A
TriggerAll = Var(15) >= 2
trigger1 = ctrl
trigger2 = StateNo = 610 && movecontact
trigger3 = StateNo = 630 && movecontact
trigger4 = StateNo = 640 && movecontact
trigger5 = stateno = 1500 && animelemtime(4) >= 1
trigger6 = stateno = 1600 && animelemtime(4) >= 1
trigger7 = stateno = 1550 && animelemtime(4) >= 1
trigger8 = stateno = 1650 && animelemtime(4) >= 1
trigger9 = stateno = 1700 && animelemtime(4) >= 1
trigger10 = stateno = 1750 && animelemtime(4) >= 1

[State -1, カラドボルグ]
type = ChangeState
value = 3000
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command ="Caladbolg"
TriggerAll = Power>1999
triggerAll = statetype != A
TriggerAll = Var(15) >= 2
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 1400 && movecontact
trigger6 = StateNo = 1450 && movecontact
trigger7 = StateNo = 410 && movecontact
trigger8 = StateNo = 430 && movecontact
trigger9 = StateNo = 440 && movecontact

;------------------------------------------------------------------------------
; ここで↑にて実際に使っている「スマッシュカンフーアッパーのChangeState」を例に
; 見て行きましょ！m9っ｀Д´)
;
; まず特定のコマンドを入力したいならば、
; 必ず『呼び出すコマンドのトリガー』は設定しましょう。
; 特殊な条件でない限り、コマンドは通常「triggerall」の方で設定した方が良い。
;
;「triggerall」とは『有効になる状況を限定するための条件』を指定する。
; triggerallの条件が有効にならない限り、trigger1以降の条件も有効にはならない。
; 何個でも増やせる。ステート作成の基本テクニックの一つなので覚えておいてね。
; しかしtriggerallはtrigger1以降が無いと「単体では」使えないので注意。
;（trigger1以降を全てコメント化してM.U.G.E.Nでそのキャラを選んで試してみよう）
;
;
; ※『パワーゲージ』は「スーパーコンボゲージ」や「超必殺技ゲージ」などで
; 　呼ばれてる部分のゲージです。
; 　ゲージが「１０００ポイント」なら『レベル１』と同じ意味になります。
;
; 　まぁパッと見、M.U.G.E.Nのパワーゲージって仕組みが
; 　ストＺＥＲＯシリーズの「スーパーコンボレベルゲージ」まんまだよね（苦笑
;------------------------------------------------------------------------------

;==============================================================================
; 必殺技
;==============================================================================
;------------------------------------------------------------------------------
; 変数の使い方の例。
;
; カンフーマンの「地上で必殺技が出せる状況」や、
; 通常技から必殺技へ繋ぐ時の「キャンセル」の部分を設定している。
; 地上で成功すれば、『変数の例２』のステートコントローラで設定した
; 変数が実行され、それ以外なら『変数の例１』でリセットする、という処理。
;
; 個人的にはこの方法はオススメしない。kfmcでの方法を推薦します。
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
[State -1, 剣投げ75°]
type = ChangeState
value = 1750
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "shoot c"
triggerAll = statetype = A
TriggerAll = pos Y<=-15
trigger1 = stateno = 1700 && animelemtime(4) >= 1

[State -1, 剣投げ75°]
type = ChangeState
value = 1700
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "shoot c"
triggerAll = statetype = A
TriggerAll = pos Y<=-15
trigger1 = ctrl
trigger2 = StateNo = 610 && movecontact
trigger3 = StateNo = 630 && movecontact
trigger4 = StateNo = 640 && movecontact

[State -1, 剣投げ75°]
type = ChangeState
value = 1650
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "shoot high"
triggerAll = statetype = A
TriggerAll = pos Y<=-15
trigger1 = stateno = 1500 && animelemtime(4) >= 1
trigger2 = stateno = 1600 && animelemtime(4) >= 1

[State -1, 剣投げ60°]
type = ChangeState
value = 1600
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "shoot high"
triggerAll = statetype = A
TriggerAll = pos Y<=-15
trigger1 = ctrl
trigger2 = StateNo = 610 && movecontact
trigger3 = StateNo = 630 && movecontact
trigger4 = StateNo = 640 && movecontact

[State -1, 剣投げ45°]
type = ChangeState
value = 1550
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "shoot low"
triggerAll = statetype = A
TriggerAll = pos Y<=-15
trigger1 = stateno = 1500 && animelemtime(4) >= 1
trigger2 = stateno = 1600 && animelemtime(4) >= 1


[State -1, 剣投げ30°]
type = ChangeState
value = 1500
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "shoot low"
triggerAll = statetype = A
TriggerAll = pos Y<=-15
trigger1 = ctrl
trigger2 = StateNo = 610 && movecontact
trigger3 = StateNo = 630 && movecontact
trigger4 = StateNo = 640 && movecontact

[State -1, 強突進切り]
type = ChangeState
value = 1460
triggerall = var(59) = 0
triggerall = statetype = S
triggerall = !ishelper
triggerall = command ="dash slash c"
trigger1 = ctrl

[State -1, 強突進切り]
type = ChangeState
value = 1450
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command ="dash slash high"
triggerall = statetype != A
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 410 && movecontact
trigger6 = StateNo = 430 && movecontact
trigger7 = StateNo = 440 && movecontact

[State -1, 弱突進切り]
type = ChangeState
value = 1400
triggerall = var(59) = 0
triggerall = command ="dash slash low"
triggerall = statetype != A
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 410 && movecontact
trigger6 = StateNo = 430 && movecontact
trigger7 = StateNo = 440 && movecontact

[State -1, 強射撃]
type = ChangeState
value = 4200
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "unlimited"
triggerall = var(15) >= 2
triggerall = statetype != A
TriggerAll = Power>2999
triggerall = var(16) = 0
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 1400 && movecontact
trigger6 = StateNo = 1450 && movecontact
trigger7 = StateNo = 410 && movecontact
trigger8 = StateNo = 430 && movecontact
trigger9 = StateNo = 440 && movecontact
trigger10 = StateNo = 250 && movecontact

[State -1, 強射撃]
type = ChangeState
value = 1127
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "angle shoot c"
triggerall = statetype != A
TriggerAll = numhelper(1136) = 0
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 1400 && movecontact
trigger6 = StateNo = 1450 && movecontact
trigger7 = StateNo = 410 && movecontact
trigger8 = StateNo = 430 && movecontact
trigger9 = StateNo = 440 && movecontact

[State -1, 強射撃]
type = ChangeState
value = 1430
triggerall = var(59) = 0
triggerall = var(16) = 1
triggerall = !ishelper
triggerall = !numexplod(9999)
triggerall = command = "shoot c"
triggerall = statetype != A
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 1400 && movecontact
trigger6 = StateNo = 1450 && movecontact
trigger7 = StateNo = 410 && movecontact
trigger8 = StateNo = 430 && movecontact
trigger9 = StateNo = 440 && movecontact
trigger10 = StateNo = 250 && movecontact

[State -1, 強射撃]
type = ChangeState
value = 1005
triggerall = var(59) = 0
triggerall = var(15) <= 1
triggerall = !ishelper
triggerall = !numexplod(9999)
triggerall = command = "shoot c"
triggerall = power >= 1000
triggerall = statetype != A
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 1400 && movecontact
trigger6 = StateNo = 1450 && movecontact
trigger7 = StateNo = 410 && movecontact
trigger8 = StateNo = 430 && movecontact
trigger9 = StateNo = 440 && movecontact
trigger10 = StateNo = 250 && movecontact

[State -1, 強射撃]
type = ChangeState
value = 1100
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "shoot high"
triggerall = statetype != A
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 1400 && movecontact
trigger6 = StateNo = 1450 && movecontact
trigger7 = StateNo = 410 && movecontact
trigger8 = StateNo = 430 && movecontact
trigger9 = StateNo = 440 && movecontact

[State -1, 下方強射撃]
type = ChangeState
value = 1125
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "angle shoot high"
triggerall = statetype != A
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 1400 && movecontact
trigger6 = StateNo = 1450 && movecontact
trigger7 = StateNo = 410 && movecontact
trigger8 = StateNo = 430 && movecontact
trigger9 = StateNo = 440 && movecontact

[State -1, 通常射撃]
type = ChangeState
value = 1000
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "shoot low"
triggerall = statetype != A
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 1400 && movecontact
trigger6 = StateNo = 1450 && movecontact
trigger7 = StateNo = 410 && movecontact
trigger8 = StateNo = 430 && movecontact
trigger9 = StateNo = 440 && movecontact

[State -1, 下方通常射撃]
type = ChangeState
value = 1025
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "angle shoot low"
triggerall = statetype != A
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 1400 && movecontact
trigger6 = StateNo = 1450 && movecontact
trigger7 = StateNo = 410 && movecontact
trigger8 = StateNo = 430 && movecontact
trigger9 = StateNo = 440 && movecontact
trigger10 = StateNo = 250 && movecontact
;===========================================================================
;------------------------------------------------------------------------------
;----------------------------------------------------------------------------
;---------------------------------------------------------------------------
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
;==============================================================================
; 移動関連
;==============================================================================
;------------------------------------------------------------------------------
[State -1,JumpC];
Type=ChangeState
value=40
triggerall = var(59) = 0
triggerall = !ishelper
TriggerAll=StateType!=A
TriggerAll=command="holdup"
trigger1 = StateNo = 215 && movecontact

[State -1, 走る]
type = ChangeState
value = 100
triggerall = var(59) = 0
triggerall = !ishelper
trigger1 = command = "FF"
trigger1 = statetype = S
trigger1 = ctrl

[State -1, バックステップ]
type = ChangeState
value = 105
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "BB"
triggerall = statetype != A
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 245 && movecontact
trigger5 = StateNo = 410 && movecontact
trigger6 = StateNo = 430 && movecontact
trigger7 = StateNo = 440 && movecontact
;==============================================================================
; 特殊技
;==============================================================================
;------------------------------------------------------------------------------
[State -1, 後ろ投げ];投げ技
type = ChangeState
value = 850
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "holdback"
triggerall = command = "x"
trigger1 = statetype = S
trigger1 = ctrl

[State -1, 前投げ];投げ技
type = ChangeState
value = 800
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "x"
trigger1 = statetype = S
trigger1 = ctrl

[State -1];前転
type = ChangeState
value = ifelse(command = "holdback",108,107)
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "zenten"
triggerall = stateNO != 6700
trigger1 = MoveType != H
trigger1 = ctrl && statetype != A
trigger2 = stateno = 100
 
[State -1];バク転
type = ChangeState
value = ifelse(command = "holdback",108,107)
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "bakuten"
triggerall = stateNO != 6700
trigger1 = MoveType != H
trigger1 = ctrl && statetype != A
trigger2 = stateno = 100

;------------------------------------------------------------------------------

;==============================================================================
; 通常攻撃技
;==============================================================================
;------------------------------------------------------------------------------

[State -1, 突き]
type = ChangeState
value = 210
triggerall = var(59) = 0
triggerall = command = "F_a"
triggerall = !ishelper
trigger1 = statetype = S
trigger1 = ctrl

[State -1, 十字切り]
type = ChangeState
value = 215
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "F_b"
trigger1 = statetype = S
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
trigger4 = StateNo = 410 && movecontact
trigger5 = StateNo = 430 && movecontact

[State -1, 立ち弱切り]
type = ChangeState
value = 230
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "a"
triggerall = command != "holddown"
trigger1 = statetype = S
trigger1 = ctrl

[State -1, 立ち強切り]
type = ChangeState
value = 240
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "b"
triggerall = command != "holddown"
trigger1 = statetype = S
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact

[State -1, 立ち強切り]
type = ChangeState
value = 250
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "c"
triggerall = command = "holdfwd"
trigger1 = statetype = S
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact

[State -1, 立ち強切り]
type = ChangeState
value = 245
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "c"
triggerall = command != "holddown"
trigger1 = statetype = S
trigger1 = ctrl
trigger2 = StateNo = 230 && movecontact
trigger3 = StateNo = 235 && movecontact
;------------------------------------------------------------------------------

[State -1]
Type=ChangeState
value=197
triggerall = var(59) = 0
triggerall = stateno = 150 ||stateno = 152
triggerall = power >= 500
Trigger1=command="start"

;------------------------------------------------------------------------------

[State -1, しゃがみキック]
type = ChangeState
value = 410
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "a"
triggerall = command = "holddown"
trigger1 = statetype = C
trigger1 = ctrl
[State -1, しゃがみ弱切り]
type = ChangeState
value = 430
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "b"
triggerall = command = "holddown"
trigger1 = statetype = C
trigger1 = ctrl
trigger2 = StateNo = 410 && movecontact
[State -1, しゃがみ強切り]
type = ChangeState
value = 440
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "c"
triggerall = command = "holddown"
trigger1 = statetype = C
trigger1 = ctrl
trigger2 = StateNo = 410 && movecontact
trigger3 = StateNo = 430 && movecontact
;------------------------------------------------------------------------------

[State -1, ジャンプキック]
type = ChangeState
value = 610
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "a"
trigger1 = statetype = A
trigger1 = ctrl

[State -1, ジャンプ弱切り]
type = ChangeState
value = 630
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "b"
trigger1 = statetype = A
trigger1 = ctrl
trigger2 = StateNo = 610 && movecontact

[State -1, ジャンプ強切り]
type = ChangeState
value = 640
triggerall = var(59) = 0
triggerall = !ishelper
triggerall = command = "c"
trigger1 = statetype = A
trigger1 = ctrl
trigger2 = StateNo = 610 && movecontact
trigger3 = StateNo = 630 && movecontact
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
;AI--------------------------------------------------------------------------

;AI Command Check
[State -1, AI Command]
Type = VarSet
TriggerAll = Var(59)=0 && !isHelper
trigger1 = command = "AI_01" || command = "AI_02" || command = "AI_03" || command = "AI_04"
trigger2 = command = "AI_05" || command = "AI_06" || command = "AI_07" || command = "AI_08"
trigger3 = command = "AI_09" || command = "AI_10" || command = "AI_11" || command = "AI_12"
trigger4 = command = "AI_13" || command = "AI_14" || command = "AI_15" || command = "AI_16"
trigger5 = command = "AI_17" || command = "AI_18" || command = "AI_19" || command = "AI_20"
Trigger6 = Command = "AI_21" || Command = "AI_22" || Command = "AI_23" || Command = "AI_24"
Trigger7 = Command = "AI_24" || Command = "AI_26" || Command = "AI_27" || Command = "AI_28"
Trigger8 = Command = "AI_29" || Command = "AI_30" || Command = "AI_31" || Command = "AI_32"
Trigger9 = Command = "AI_33" || Command = "AI_34" || Command = "AI_35" || Command = "AI_36"
Trigger10 = Command = "AI_37" || Command = "AI_38" || Command = "AI_39" || Command = "AI_40"
Trigger11 = Command = "AI_41" || Command = "AI_42" || Command = "AI_43" || Command = "AI_44"
Trigger12 = Command = "AI_45" || Command = "AI_46" || Command = "AI_47" || Command = "AI_48"
Trigger13 = Command = "AI_49" || Command = "AI_00"
Trigger14 = PalNo = 5
Trigger15 = PalNo = 6
Trigger16 = PalNo = 7
Trigger17 = PalNo = 8
Trigger18 = PalNo = 11
Trigger19 = PalNo = 12
Trigger20 = PalNo = 9
Trigger21 = PalNo = 10

V = 59
Value = 1
IgnoreHitPause = 1

[State -1, Throw1]
type = ChangeState
value = 1800
triggerall = var(59) = 1
TriggerAll=RoundState<=2
TriggerAll = Power=3000
trigger1 = PalNo = 9
trigger2 = PalNo = 10

[State -1, Throw1]
type = ChangeState
value = 40
triggerall = var(59) = 1
TriggerAll=RoundState<=2
TriggerAll = Power<3000
TriggerAll=Ctrl
trigger1 = PalNo = 9
trigger2 = PalNo = 10

[State -1, Throw1]
type = ChangeState
value = 4150
triggerall = var(59) = 1
TriggerAll = Var(16) = 1
TriggerAll = Power>2999
TriggerAll = life<=200
TriggerAll=RoundState<=2
triggerall = statetype = S
triggerall = ctrl
trigger1 = p2movetype = A
trigger1 = p2statetype != A

[State -1, カラドボルグ]
type = ChangeState
value = 3000
triggerall = var(59) = 1
TriggerAll = Var(16) = 1
triggerall = !ishelper
triggerall = command ="Caladbolg"
TriggerAll = Power>1999
triggerAll = statetype != A
TriggerAll = Var(15) >= 2
triggerall = ctrl
trigger1 = p2life <= 50

[State -1, Throw1]
type = ChangeState
value = 1460
triggerall = var(59) = 1
TriggerAll=RoundState<=2
triggerall = statetype = S
triggerall = ctrl
trigger1 = p2bodydist X < 50
trigger1 = p2bodydist Y >=-80
trigger1 = p2movetype = A
trigger1 = p2statetype != A
trigger1 = p2statetype != L

[State -1, Throw1]
type = ChangeState
value = 1450
triggerall = var(59) = 1
TriggerAll=RoundState<=2
triggerall = statetype = S
triggerall = ctrl
trigger1 = p2bodydist X < 50
trigger1 = p2bodydist Y >=-80
trigger1 = p2movetype = A
trigger1 = p2statetype = A
trigger1 = p2statetype != L

[State -3,立ちガード]
Type = ChangeState
Value = 120
triggerall = RoundState = 2
TriggerAll=var(59) != 0
TriggerAll=StateNo!=[120,155]
TriggerAll=Ctrl||StateNo = 20
TriggerAll=inguarddist
TriggerAll=PalNo!=12
TriggerAll=PalNo!=11
Trigger1 = P2MoveType = A

[State -1, Throw1]
type = ChangeState
value = 40
triggerall = var(59) = 1
TriggerAll=RoundState<=2
triggerall = statetype = S
triggerall = ctrl
trigger1 = p2bodydist X < 160
trigger1 = p2statetype = L

[State -1, Throw1]
type = ChangeState
value = 1025
triggerall = var(59) = 1
TriggerAll=RoundState<=2
triggerall = statetype = S
triggerall = ctrl
trigger1 = p2bodydist X > 160
trigger1 = p2statetype = L

[State -1, Throw1]
type = ChangeState
value = 3400
triggerall = var(59) = 1
TriggerAll = Var(16) = 1
TriggerAll = Power>2999
TriggerAll=RoundState<=2
triggerall = statetype = S
triggerall = ctrl
triggerall = p2bodydist Y >= -40
triggerall = p2statetype != L
trigger1 = PalNo = 3
trigger2 = PalNo = 4

[State -1, Throw1]
type = ChangeState
value = 3400
triggerall = var(59) = 1
TriggerAll = Var(16) = 1
TriggerAll = Power>2999
TriggerAll=RoundState<=2
triggerall = statetype = S
triggerall = ctrl
triggerall = p2bodydist Y >= -40
triggerall = p2statetype != L
trigger1 = p2StateNo=[120,155]

[State -1, Throw1]
type = ChangeState
value = 230
triggerall = var(59) = 1
TriggerAll=RoundState<=2
triggerall = statetype = S
triggerall = ctrl
trigger1 = p2bodydist X < 50
trigger1 = p2bodydist Y >=-80
trigger1 = p2movetype != A
trigger1 = p2statetype != L

[State -1, Throw1]
type = ChangeState
value = 800
triggerall = var(59) = 1
TriggerAll=RoundState<=2
triggerall = statetype = S
triggerall = ctrl
triggerall = p2StateNo=[120,155]
trigger1 = p2bodydist X < 50
trigger1 = p2movetype != A
trigger1 = p2statetype != L
trigger1 = p2statetype != A

[State -1, Throw1]
type = ChangeState
value = 240
triggerall = var(59) = 1
TriggerAll=RoundState<=2
triggerall = statetype = S
triggerall = ctrl
trigger1 = p2bodydist X < 160
trigger1 = p2bodydist Y >= -130
trigger1 = p2movetype != A
trigger1 = p2statetype != L

[State -3,ダッシュ]
Type = ChangeState
value = 3100
TriggerAll=RoundState = 2
TriggerAll = var(59) != 0
TriggerAll = var(16) != 0
TriggerAll = Var(2) = 0
TriggerAll = StateType != A
TriggerAll = Ctrl
TriggerAll = power >= 1000
trigger1 = p2movetype = A
Trigger1 = P2BodyDist X = [160,320]

[State -3,ダッシュ]
Type = ChangeState
value = 100
TriggerAll=RoundState = 2
TriggerAll = var(59) != 0
TriggerAll = StateType != A
TriggerAll = Ctrl
TriggerAll=StateNo!=100
Trigger1 = P2BodyDist X = [160,320]

[State -1, Throw1]
type = ChangeState
value = 107
triggerall = var(59) = 1
TriggerAll=RoundState<=2
triggerall = statetype = S
triggerall = ctrl
trigger1 = p2bodydist Y < -130
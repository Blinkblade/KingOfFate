;-| AI |--------------------------------------------------------
[Command]
name = "AI"
command = ~D, B, U, F, a+b+c+x+y+z
time = 3

[Command]
name = "AI3"
command = ~U, D, DB, DF, F, U, U , z
time = 3

[Command]
name = "AI2"
command = ~U,U,D,B,D, DF , F , x
time = 3

[Command]
name = "AI4"
command = ~D, D, U, DF, F, U, U , c+z
time = 3

[Command]
name = "AI5"
command = U,U,D,D,B,F,B,F,z,z
time = 1

[Command]
name = "AI6"
command = U,U,D,D,B,F,B,F,z,z
time = 1

[Command]
name = "AI7"
command = U,U,D,D,B,F,B,F,z,z
time = 1

[Command]
name = "AI8"
command = U,D,B,F,U,D,B,F
time = 1

[Command]
name = "AI9"
command = U,U,D,D,B,F,B,F
time = 1

[Command]
name = "AI10"
command = U, D, B, F, U, D, B, F, s, s
time = 1

[Command]
name = "AI11"
command = U, D, B, F, U, D, B, F, a, a
time = 1

[Command]
name = "AI12"
command = U, D, B, F, U, D, B, F, b, b
time = 1

[Command]
name = "AI13"
command = U, D, B, F, U, D, B, F, c, c
time = 1

[Command]
name = "AI14"
command = U, D, B, F, U, D, B, F, x, x
time = 1

[Command]
name = "AI15"
command = U, D, B, F, U, D, B, F, y, y
time = 1

[Command]
name = "AI16"
command = U, D, B, F, U, D, B, F, z, z
time = 1

[Command]
name = "AI17"
command = a, b, z, b, a, x, y, y, z, b, b, a
time = 1

[Command]
name = "AI18"
command = U, DB, DB, D, DF, F, F, U, B, x, a
time = 1

[Command]
name = "AI19"
command = D, DB, DB, D, DF, F, F, F, F, b+z
time = 1

[Command]
name = "AI20"
command = D, DB, B, x+y+z+a+b+c
time = 1

;[Command]
;name = "AI21"
;command = ~D, DF, F, x
;time = 20

;-| 超必殺技 |--------------------------------------------------------
;ここには超必殺技を記述してください、同じ名前を「name =」欄に書けますが
;コマンドは絶対に違ったものにしてください。
;カンフーマンは弱パンチと強パンチで技が出せるように同じ名前のコマンドで
;内容が弱と強になっています。
;「time=20」と書くことで「コマンドを20フレーム以内に入力」と設定できます。
[Command]
name = "UBW"
command = ~B, DB, D, DF, F, x
time = 60

[Command]
name = "UBW_S"
command = ~B, DB, D, DF, F, z
time = 60

[Command]
name = "UBW_R"
command = ~B, DB, D, DF, F, a
time = 60

[Command]
name = "UBWX"
command = ~D, DF, F, D, DF, F, z
time = 60

[Command]
name = "RO-"
command = ~D, DF, F, D, DF, F, x
time = 60

[Command]
name = "DC"
command = ~D, DF, F, D, DF, F, a
time = 60

[Command]
name = "AIR"
command = ~D, DF, F, D, DF, F, y
time = 60

[Command]
name = "karado"
command = ~D, DF, F, D, DF, F, b
time = 60

[Command]
name = "Combo_Rash"
command = ~D, DB, B, DB, D, DF, F, y
time = 60

[Command]
name = "kusari"
command = ~D, DB, B, DB, D, DF, F, b
time = 60

;-| 必殺技 |------------------------------------------------------
[Command]
name = "tuika"
command = ~F, F, c

[Command]
name = "trace_P"
command = ~D, D, x

[Command]
name = "trace_K"
command = ~D, D, a

[Command]
name = "trace_S"
command = ~D, D, y

[Command]
name = "hassya"
command = ~D, D, b

[Command]
name = "taikuu_S"
command = ~F, D, DF, y

[Command]
name = "taikuu_HS"
command = ~F, D, DF, b

[Command]
name = "yumi_S"
command = ~B, DB, D, DF, F, y

[Command]
name = "yumi_HS"
command = ~B, DB, D, DF, F, b

[Command]
name = "kakato"
command = ~D, DB, B, a

[Command]
name = "RG"
command = F
time = 1

[Command]
name = "C_RG"
command = D
time = 1

[Command]
name = "GX"
command = B,B,F,F,B,F,B
time = 60

;※※※※※※※※※※※※※※※※※※※※ハイジャンプコマンド
;下をちょっと押して上を押す、と言う意味。
[Command]
name = "jump"    
command = ~D,$U
time = 10

;-| ２回押し技 |-----------------------------------------------------------
[Command]
name = "FF"     
command = F, F
time = 10

[Command]
name = "BB"     
command = B, B
time = 10

;-| ２・３個の同時押し技 |-----------------------------------------------
[Command]
name = "recovery"
command = a+b
time = 1

[Command]
name = "recovery2"
command = x+a
time = 1

[Command]
name = "recovery3"
command = x+y
time = 1

[Command]
name = "recovery4"
command = y+b
time = 1

[Command]
name = "BREAK"
command = /$B,x+a
time = 10

;-| 方向とボタンで出す技 |---------------------------------------------------------
[Command]
name = "tokusyu"
command = /$F,b
time = 10

[Command]
name = "nage"
command = /$F,c
time = 10

[Command]
name = "nage_b"
command = /$B,c
time = 10

[Command]
name = "down_a"
command = /$D,a
time = 1

[Command]
name = "down_b"
command = /$D,b
time = 1

;-| ボタン設定（いじらない）|---------------------------------------------------------
[Command]
name = "holdupa" 
command = ~U
time = 1

[Command]
name = "holddowna"
command = ~D
time = 1

[Command]
name = "x"
command = x
time = 1

[Command]
name = "c"
command = c
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

[Command]
name = "z"
command = z
time = 1

[Command]
name = "start"
command = s
time = 1

;-| 押しっぱなし設定（いじらない）-------------------------------------------------------
[Command]
name = "holdfwd"
command = /$F
time = 1

[Command]
name = "holdback"
command = /$B
time = 1

[Command]
name = "holdup" 
command = /$U
time = 1

[Command]
name = "holddown"
command = /$D
time = 1

[Command]
name = "holdx"
command = /$x
time = 1

[Command]
name = "holdy"
command = /$y
time = 1

[Command]
name = "JC" 
command = /$U
time = 1

; 下の記述↓は絶対に消さないでください。
[Statedef -1]
;---------------------------------------------------------------------------
;UBW
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 3301
triggerall = power >= 500
triggerall = var(48) = 7
triggerall = command = "UBW"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,450])
trigger2 = movecontact
trigger3 = var(50) != 1
trigger3 = stateno = 1051
trigger3 = movecontact
trigger3 = AnimElemTime(6) >= 0 && AnimElemTime(8) < 0
trigger4 = var(50) != 1
trigger4 = stateno = 1150
trigger4 = movecontact
trigger5 = var(50) != 1
trigger5 = stateno = 1200
trigger5 = movecontact
trigger5 = AnimElemTime(3) >= 0 && AnimElemTime(4) < 0

;---------------------------------------------------------------------------
;UBW
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 3300
triggerall = power >= 500
triggerall = var(48) = [0,6]
triggerall = command = "UBW"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,450])
trigger2 = movecontact
trigger3 = var(50) != 1
trigger3 = stateno = 1051
trigger3 = movecontact
trigger3 = AnimElemTime(6) >= 0 && AnimElemTime(8) < 0
trigger4 = var(50) != 1
trigger4 = stateno = 1150
trigger4 = movecontact
trigger5 = var(50) != 1
trigger5 = stateno = 1200
trigger5 = movecontact
trigger5 = AnimElemTime(3) >= 0 && AnimElemTime(4) < 0

;---------------------------------------------------------------------------
;UBWX
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 3900
triggerall = var(48) = 8
triggerall = var(49) = 1
triggerall = (power >= 3000 && var(50) != 2) || (power >= 3000 && var(50) != 1)
triggerall = command = "UBWX"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,450])
trigger2 = movecontact
trigger3 = var(50) != 1
trigger3 = stateno = 1051
trigger3 = movecontact
trigger3 = AnimElemTime(6) >= 0 && AnimElemTime(8) < 0
trigger4 = var(50) != 1
trigger4 = stateno = 1150
trigger4 = movecontact
trigger5 = var(50) != 1
trigger5 = stateno = 1200
trigger5 = movecontact
trigger5 = AnimElemTime(3) >= 0 && AnimElemTime(4) < 0

;---------------------------------------------------------------------------
;ローアイアス
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 3700
triggerall = var(48) = 8
triggerall = var(49) = 1
triggerall = (power >= 1000 && var(50) != 2) || (power >= 3000 && var(50) != 1)
triggerall = command = "RO-"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,450])
trigger2 = movecontact
trigger3 = var(50) != 1
trigger3 = stateno = 1051
trigger3 = movecontact
trigger3 = AnimElemTime(6) >= 0 && AnimElemTime(8) < 0
trigger4 = var(50) != 1
trigger4 = stateno = 1150
trigger4 = movecontact
trigger5 = var(50) != 1
trigger5 = stateno = 1200
trigger5 = movecontact
trigger5 = AnimElemTime(3) >= 0 && AnimElemTime(4) < 0

;---------------------------------------------------------------------------
;DC
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 3400
triggerall = (power >= 1000 && var(50) != 2) || (power >= 3000 && var(50) != 1)
triggerall = command = "DC"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,450])
trigger2 = movecontact
trigger3 = var(50) != 1
trigger3 = stateno = 1051
trigger3 = movecontact
trigger3 = AnimElemTime(6) >= 0 && AnimElemTime(8) < 0
trigger4 = var(50) != 1
trigger4 = stateno = 1150
trigger4 = movecontact
trigger5 = var(50) != 1
trigger5 = stateno = 1200
trigger5 = movecontact
trigger5 = AnimElemTime(3) >= 0 && AnimElemTime(4) < 0

;---------------------------------------------------------------------------
;AIR
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 3200
triggerall = var(48) = 8
triggerall = var(49) = 1
triggerall = (power >= 1000 && var(50) != 2) || (power >= 3000 && var(50) != 1)
triggerall = command = "AIR"
trigger1 = stateno = 1300
trigger1 = P2movetype = H
trigger1 = AnimElemTime(10) >= 100
;trigger2 = (stateno = [200,249]) || (stateno = [400,450])
;trigger2 = movecontact
;trigger3 = var(50) != 1
;trigger3 = stateno = 1051
;trigger3 = movecontact
;trigger3 = AnimElemTime(6) >= 0 && AnimElemTime(8) < 0
;trigger4 = var(50) != 1
;trigger4 = stateno = 1150
;trigger4 = movecontact
;trigger5 = var(50) != 1
;trigger5 = stateno = 1200
;trigger5 = movecontact
;trigger5 = AnimElemTime(3) >= 0 && AnimElemTime(4) < 0

;---------------------------------------------------------------------------
;UBW(設置)
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 3320
triggerall = var(48) = 8
triggerall = var(49) = 1
triggerall = (power >= 3000 && var(50) != 2) || (power >= 3000 && var(50) != 1)
triggerall = command = "UBW_S"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,450])
trigger2 = movecontact
trigger3 = var(50) != 1
trigger3 = stateno = 1051
trigger3 = movecontact
trigger3 = AnimElemTime(6) >= 0 && AnimElemTime(8) < 0
trigger4 = var(50) != 1
trigger4 = stateno = 1150
trigger4 = movecontact
trigger5 = var(50) != 1
trigger5 = stateno = 1200
trigger5 = movecontact
trigger5 = AnimElemTime(3) >= 0 && AnimElemTime(4) < 0

;---------------------------------------------------------------------------
;UBW(乱射)
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 3500
triggerall = var(48) = 8
triggerall = var(49) = 1
triggerall = (power >= 3000 && var(50) != 2) || (power >= 3000 && var(50) != 1)
triggerall = command = "UBW_R"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,450])
trigger2 = movecontact
trigger3 = var(50) != 1
trigger3 = stateno = 1051
trigger3 = movecontact
trigger3 = AnimElemTime(6) >= 0 && AnimElemTime(8) < 0
trigger4 = var(50) != 1
trigger4 = stateno = 1150
trigger4 = movecontact
trigger5 = var(50) != 1
trigger5 = stateno = 1200
trigger5 = movecontact
trigger5 = AnimElemTime(3) >= 0 && AnimElemTime(4) < 0

;---------------------------------------------------------------------------
;カラドボルグ
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 3000
triggerall = (power >= 1000 && var(50) != 2) || (power >= 3000 && var(50) != 1)
triggerall = command = "karado"
triggerall = NumHelper(3010) = 0
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,450])
trigger2 = movecontact
trigger3 = var(50) != 1
trigger3 = stateno = 1051
trigger3 = movecontact
trigger3 = AnimElemTime(6) >= 0 && AnimElemTime(8) < 0
trigger4 = var(50) != 1
trigger4 = stateno = 1150
trigger4 = movecontact
trigger5 = var(50) != 1
trigger5 = stateno = 1200
trigger5 = movecontact
trigger5 = AnimElemTime(3) >= 0 && AnimElemTime(4) < 0

;---------------------------------------------------------------------------
;天の鎖
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 1300
triggerall = var(48) = 8
triggerall = var(49) = 1
triggerall = (power >= 1000 && var(50) != 2) || (power >= 3000 && var(50) != 1)
triggerall = command = "kusari"
triggerall = NumHelper(1340) = 0
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,450])
trigger2 = movecontact
trigger3 = var(50) != 1
trigger3 = stateno = 1051
trigger3 = movecontact
trigger3 = AnimElemTime(6) >= 0 && AnimElemTime(8) < 0
trigger4 = var(50) != 1
trigger4 = stateno = 1150
trigger4 = movecontact
trigger5 = var(50) != 1
trigger5 = stateno = 1200
trigger5 = movecontact
trigger5 = AnimElemTime(3) >= 0 && AnimElemTime(4) < 0

;---------------------------------------------------------------------------
;壊れた幻想
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 1350
triggerall = var(48) = 8
triggerall = var(49) = 1
triggerall = (power >= 1000 && var(50) != 2) || (power >= 3000 && var(50) != 1)
triggerall = command = "karado"
triggerall = NumHelper(1355) = 0
trigger1 = statetype = A
trigger1 = ctrl
trigger2 = stateno = [600,649]
trigger2 = movecontact
trigger3 = var(50) != 1
trigger3 = stateno = 1051
trigger3 = movecontact
trigger3 = AnimElemTime(13) >= 0
trigger4 = var(50) != 1
trigger4 = stateno = 1050
trigger4 = movecontact

;---------------------------------------------------------------------------
;コンビネーションラッシュ
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 3100
triggerall = (power >= 1000 && var(50) != 2) || (power >= 3000 && var(50) != 1)
triggerall = command = "Combo_Rash"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,450])
trigger2 = movecontact
trigger3 = var(50) != 1
trigger3 = stateno = 1051
trigger3 = movecontact
trigger3 = AnimElemTime(6) >= 0 && AnimElemTime(8) < 0
trigger4 = var(50) != 1
trigger4 = stateno = 1150
trigger4 = movecontact
trigger5 = var(50) != 1
trigger5 = stateno = 1200
trigger5 = movecontact
trigger5 = AnimElemTime(3) >= 0 && AnimElemTime(4) < 0

;---------------------------------------------------------------------------
;踵落とし
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 1200
triggerall = command = "kakato"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,499])
trigger2 = movecontact

;---------------------------------------------------------------------------
;投影・短剣・P
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 1000
triggerall = NumHelper(1010) = 0
triggerall = command = "trace_P"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,499])
trigger2 = movecontact

;---------------------------------------------------------------------------
;投影・短剣・K
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 1001
triggerall = NumHelper(1020) = 0
triggerall = command = "trace_K"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,499])
trigger2 = movecontact

;---------------------------------------------------------------------------
;投影・短剣・S
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 1002
triggerall = NumHelper(1030) = 0
triggerall = command = "trace_S"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,499])
trigger2 = movecontact

;---------------------------------------------------------------------------
;投影・短剣・発射
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 1005
triggerall = command = "hassya"
triggerall = NumHelper(1010) = 1 || NumHelper(1020) = 1 || NumHelper(1030) = 1
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,499])
trigger2 = movecontact

;---------------------------------------------------------------------------
;対空S
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 1050
triggerall = command = "taikuu_S"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,499])
trigger2 = movecontact

;---------------------------------------------------------------------------
;対空HS
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 1051
triggerall = command = "taikuu_HS"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,499])
trigger2 = movecontact

;---------------------------------------------------------------------------
;投影・弓・HS版
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 1100
triggerall = command = "yumi_HS"
trigger1 = statetype != A
trigger1 = ctrl
trigger2 = (stateno = [200,249]) || (stateno = [400,499])
trigger2 = movecontact

;---------------------------------------------------------------------------
;空中投影・弓・S版
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 1101
triggerall = command = "yumi_S"
trigger1 = statetype = A
trigger1 = ctrl
trigger2 = stateno = [600,650]
trigger2 = movecontact

;---------------------------------------------------------------------------
;空中投影・弓・HS版
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 1102
triggerall = command = "yumi_HS"
trigger1 = statetype = A
trigger1 = ctrl
trigger2 = stateno = [600,650]
trigger2 = movecontact

;---------------------------------------------------------------------------
;コンビネーションラッシュ
[State -1, Light Kung Fu Knee]
type = ChangeState
value = 1150
triggerall = command = "yumi_S"
trigger1 = statetype != A
trigger1 = ctrl

;---------------------------------------------------------------------------
;投げ1
[State -1, Triple Kung Fu Palm]
type = ChangeState
value = 800
triggerall = enemy,movetype != H
triggerall = command = "nage";(command = "nage" || command = "nage_b")
triggerall = P2Dist X <= 50
trigger1 = statetype != A
trigger1 = ctrl

;---------------------------------------------------------------------------
;投げ2
[State -1, Triple Kung Fu Palm]
type = ChangeState
value = 850
triggerall = enemy,movetype != H
triggerall = command = "nage_b";(command = "nage" || command = "nage_b")
triggerall = P2Dist X <= 50
trigger1 = statetype != A
trigger1 = ctrl

;---------------------------------------------------------------------------
;投げ追加
[State -1, Triple Kung Fu Palm]
type = ChangeState
value = 852
triggerall = command = "tuika"
trigger1 = stateno = 851
trigger1 = AnimElemTime(8) >= 0

;---------------------------------------------------------------------------
;ダッシュ
[State -1, Run Fwd]
type = ChangeState
value = 100
trigger1 = command = "FF"
trigger1 = statetype = S
trigger1 = ctrl

;---------------------------------------------------------------------------
;後退ダッシュ
[State -1, Run Back]
type = ChangeState
value = 105
trigger1 = command = "BB"
trigger1 = statetype = S
trigger1 = ctrl

;---------------------------------------------------------------------------
;空中前ダッシュ
[State -1, airrun]
type = ChangeState
value = 8
triggerall = Var(13) = 0
triggerall = command = "FF"
triggerall = statetype = A
trigger1 = ctrl
trigger1 = stateno != 8
trigger1 = stateno != 9

;---------------------------------------------------------------------------
;空中後ダッシュ
[State -1, airrun]
type = ChangeState
value = 9
triggerall = Var(13) = 0
triggerall = command = "BB"
triggerall = statetype = A
trigger1 = ctrl
trigger1 = stateno != 8
trigger1 = stateno != 9

;---------------------------------------------------------------------------
;キャンセルジャンプ
[State -1]
type = ChangeState
value = 40
triggerall = command = "holdup"
triggerall = statetype != A
trigger1 = stateno = 210
trigger1 = movecontact = 1
trigger2 = stateno = 220
trigger2 = movecontact = 1
trigger3 = stateno = 410
trigger3 = movecontact = 1
trigger4 = stateno = 230
trigger4 = movecontact = 1
trigger5 = stateno = 420
trigger5 = movecontact = 1
trigger6 = stateno = 430
trigger6 = movecontact = 1

;---------------------------------------------------------------------------
;キャンセルジャンプ
[State -1]
type = ChangeState
value = 45
triggerall = Var(52) = 0
triggerall = command = "JC"
triggerall = statetype = A
trigger1 = stateno = 610
trigger1 = movecontact
trigger2 = stateno = 620
trigger2 = movecontact
trigger3 = stateno = 260
trigger3 = movecontact
trigger4 = stateno = 261
trigger4 = movecontact
trigger5 = stateno = 262
trigger5 = movecontact
trigger6 = stateno = 263
trigger6 = movecontact

;---------------------------------------------------------------------------
;キャンセルジャンプ2
[State -1]
type = ChangeState
value = 255
triggerall = command = "holdup"
triggerall = statetype != A
trigger1 = stateno = 250
trigger1 = movehit

;---------------------------------------------------------------------------
;特殊立ちＨＳ攻撃
[State -1, Standing Strong Kick]
type = ChangeState
value = 240
triggerall = command = "tokusyu"
triggerall = command != "holddown"
trigger1 = statetype = S
trigger1 = ctrl
trigger2 = var(50) != 2
trigger2 = stateno = 230
trigger2 = movecontact
trigger3 = stateno = 100
trigger3 = time >= 8
trigger4 = stateno = 101
trigger4 = time >= 0
trigger5 = stateno = [4650,4660]
trigger5 = time >= 5

;---------------------------------------------------------------------------
;立ちＰ攻撃
[State -1, Stand Light Punch]
type = ChangeState
value = 200
triggerall = command = "x"
triggerall = command != "holddown"
trigger1 = statetype = S
trigger1 = ctrl
trigger2 = stateno = 200
trigger2 = movecontact
trigger3 = stateno = 100
trigger3 = time >= 8
trigger4 = stateno = 101
trigger4 = time >= 0
trigger5 = stateno = [4650,4660]
trigger5 = time >= 5

;---------------------------------------------------------------------------
;立ちＫ攻撃
[State -1, Stand Strong Punch]
type = ChangeState
value = 210
triggerall = command = "a"
triggerall = command != "holddown"
trigger1 = statetype = S
trigger1 = ctrl
trigger2 = var(50) != 2
trigger2 = stateno = 200
trigger2 = movecontact
trigger3 = var(50) != 2
trigger3 = stateno = 400
trigger3 = movecontact
trigger4 = stateno = 100
trigger4 = time >= 8
trigger5 = stateno = 101
trigger5 = time >= 0
trigger6 = stateno = [4650,4660]
trigger6 = time >= 5

;---------------------------------------------------------------------------
;立ちＳ攻撃
[State -1, Stand Light Kick]
type = ChangeState
value = 220
triggerall = command = "y"
triggerall = command != "holddown"
trigger1 = statetype = S
trigger1 = ctrl
trigger2 = var(50) != 2
trigger2 = stateno = 210
trigger2 = movecontact
trigger3 = var(50) != 2
trigger3 = stateno = 200
trigger3 = movecontact
trigger4 = var(50) != 2
trigger4 = stateno = 410
trigger4 = movecontact
trigger5 = var(50) != 2
trigger5 = stateno = 400
trigger5 = movecontact
trigger6 = stateno = 100
trigger6 = time >= 8
trigger7 = stateno = 101
trigger7 = time >= 0
trigger8 = stateno = [4650,4660]
trigger8 = time >= 5

;---------------------------------------------------------------------------
;立ちＨＳ攻撃
[State -1, Standing Strong Kick]
type = ChangeState
value = 230
triggerall = command = "b"
triggerall = command != "holddown"
trigger1 = statetype = S
trigger1 = ctrl
trigger2 = var(50) != 2
trigger2 = stateno = 220
trigger2 = movecontact
trigger3 = var(50) != 2
trigger3 = stateno = 210
trigger3 = movecontact
trigger4 = var(50) != 2
trigger4 = stateno = 410
trigger4 = movecontact
trigger5 = var(50) != 2
trigger5 = stateno = 420
trigger5 = movecontact
trigger6 = stateno = 100
trigger6 = time >= 8
trigger7 = stateno = 101
trigger7 = time >= 0
trigger8 = stateno = [4650,4660]
trigger8 = time >= 5

;---------------------------------------------------------------------------
;立ちＤ攻撃
[State -1, Standing Strong Kick]
type = ChangeState
value = 250
triggerall = command = "z"
triggerall = command != "holddown"
trigger1 = statetype = S
trigger1 = ctrl
trigger2 = var(50) != 2
trigger2 = stateno = [210,240]
trigger2 = movecontact
trigger3 = var(50) != 2
trigger3 = stateno = [410,430]
trigger3 = movecontact
trigger4 = stateno = 100
trigger4 = time >= 8
trigger5 = stateno = 101
trigger5 = time >= 0
trigger6 = stateno = [4650,4660]
trigger6 = time >= 5

;---------------------------------------------------------------------------
;しゃがみＰ攻撃
[State -1, Crouching Light Punch]
type = ChangeState
value = 400
triggerall = command = "x"
triggerall = command = "holddown"
trigger1 = statetype = C
trigger1 = ctrl
trigger2 = stateno = 400
trigger2 = movecontact
trigger3 = var(50) != 2
trigger3 = stateno = 200
trigger3 = movecontact
trigger4 = stateno = 100
trigger4 = time >= 8
trigger5 = stateno = 101
trigger5 = time >= 0
trigger6 = stateno = [4650,4660]
trigger6 = time >= 5

;---------------------------------------------------------------------------
;しゃがみＫ攻撃
[State -1, Crouching Strong Punch]
type = ChangeState
value = 410
triggerall = command = "a"
triggerall = command = "holddown"
trigger1 = statetype = C
trigger1 = ctrl
trigger2 = var(50) != 2
trigger2 = stateno = 200
trigger2 = movecontact
trigger3 = var(50) != 2
trigger3 = stateno = 400
trigger3 = movecontact
trigger4 = stateno = 100
trigger4 = time >= 8
trigger5 = stateno = 101
trigger5 = time >= 0
trigger6 = stateno = [4650,4660]
trigger6 = time >= 5

;---------------------------------------------------------------------------
;しゃがみＳ攻撃
[State -1, Crouching Strong Kick]
type = ChangeState
value = 420
triggerall = command = "y"
triggerall = command = "holddown"
trigger1 = statetype = C
trigger1 = ctrl
trigger2 = var(50) != 2
trigger2 = stateno = 210
trigger2 = movecontact
trigger3 = var(50) != 2
trigger3 = stateno = 410
trigger3 = movecontact
trigger4 = var(50) != 2
trigger4 = stateno = 200
trigger4 = movecontact
trigger5 = var(50) != 2
trigger5 = stateno = 400
trigger5 = movecontact
trigger6 = var(50) != 2
trigger6 = stateno = 220
trigger6 = movecontact
trigger7 = stateno = 100
trigger7 = time >= 8
trigger8 = stateno = 101
trigger8 = time >= 0
trigger9 = stateno = [4650,4660]
trigger9 = time >= 5

;---------------------------------------------------------------------------
;しゃがみＨＳ攻撃
[State -1, Crouching Strong Kick]
type = ChangeState
value = 430
triggerall = command = "b"
triggerall = command = "holddown"
trigger1 = statetype = C
trigger1 = ctrl
trigger2 = var(50) != 2
trigger2 = stateno = 220
trigger2 = movecontact
trigger3 = var(50) != 2
trigger3 = stateno = 420
trigger3 = movecontact
trigger4 = var(50) != 2
trigger4 = stateno = 410
trigger4 = movecontact
trigger5 = stateno = 100
trigger5 = time >= 8
trigger6 = stateno = 101
trigger6 = time >= 0
trigger7 = stateno = [4650,4660]
trigger7 = time >= 5

;---------------------------------------------------------------------------
;しゃがみＤ攻撃
[State -1, Crouching Strong Kick]
type = ChangeState
value = 440
triggerall = command = "z"
triggerall = command = "holddown"
trigger1 = statetype = C
trigger1 = ctrl
trigger2 = var(50) != 2
trigger2 = stateno = [210,230]
trigger2 = movecontact
trigger3 = var(50) != 2
trigger3 = stateno = [410,430]
trigger3 = movecontact
trigger4 = stateno = 100
trigger4 = time >= 8
trigger5 = stateno = 101
trigger5 = time >= 0
trigger6 = stateno = [4650,4660]
trigger6 = time >= 5

;---------------------------------------------------------------------------
;空中Ｐ攻撃
[State -1, Jump Light Punch]
type = ChangeState
value = 600
triggerall = command = "x"
trigger1 = statetype = A
trigger1 = ctrl
trigger2 = stateno = 600
trigger2 = movecontact
trigger3 = stateno = 4670
trigger3 = time >= 5

;---------------------------------------------------------------------------
;空中Ｋ攻撃
[State -1, Jump Strong Punch]
type = ChangeState
value = 610
triggerall = command = "a"
trigger1 = statetype = A
trigger1 = ctrl
trigger2 = var(50) != 2
trigger2 = stateno = 600
trigger2 = movecontact
trigger3 = stateno = 4670
trigger3 = time >= 5

;---------------------------------------------------------------------------
;空中Ｓ攻撃
[State -1, Jump Strong Kick]
type = ChangeState
value = 620
triggerall = command = "y"
trigger1 = statetype = A
trigger1 = ctrl
trigger2 = var(50) != 2
trigger2 = stateno = 610
trigger2 = movecontact
trigger3 = var(50) != 2
trigger3 = stateno = 600
trigger3 = movecontact
trigger4 = stateno = 4670
trigger4 = time >= 5

;---------------------------------------------------------------------------
;空中ＨＳ攻撃
[State -1, Jump Strong Kick]
type = ChangeState
value = 630
triggerall = command = "b"
trigger1 = statetype = A
trigger1 = ctrl
trigger2 = var(50) != 2
trigger2 = stateno = 620
trigger2 = movecontact
trigger3 = var(50) != 2
trigger3 = stateno = 610
trigger3 = movecontact
trigger4 = var(50) != 2
trigger4 = stateno = 600
trigger4 = movecontact
trigger5 = stateno = 4670
trigger5 = time >= 5

;---------------------------------------------------------------------------
;空中Ｄ攻撃
[State -1, Jump Strong Kick]
type = ChangeState
value = 640
triggerall = command = "z"
trigger1 = statetype = A
trigger1 = ctrl
trigger2 = var(50) != 2
trigger2 = stateno = 630
trigger2 = movecontact
trigger3 = stateno = 4670
trigger3 = time >= 5

;---------------------------------------------------------------------------
;空中Ｐ攻撃(ダスト中)
[State -1, Jump Light Punch]
type = ChangeState
value = 260
triggerall = command = "x"
trigger1 = stateno = 255
trigger1 = Time = [0,60]
trigger2 = stateno = 260
trigger2 = movecontact
trigger3 = stateno = 261
trigger3 = movecontact
trigger4 = stateno = 262
trigger4 = movecontact
trigger5 = stateno = 263
trigger5 = movecontact
trigger6 = stateno = 264
trigger6 = movecontact

;---------------------------------------------------------------------------
;空中Ｋ攻撃(ダスト中)
[State -1, Jump Strong Punch]
type = ChangeState
value = 261
triggerall = command = "a"
trigger1 = stateno = 255
trigger1 = Time = [0,60]
trigger2 = stateno = 260
trigger2 = movecontact
trigger3 = stateno = 261
trigger3 = movecontact
trigger4 = stateno = 262
trigger4 = movecontact
trigger5 = stateno = 263
trigger5 = movecontact
trigger6 = stateno = 264
trigger6 = movecontact

;---------------------------------------------------------------------------
;空中Ｓ攻撃(ダスト中)
[State -1, Jump Strong Kick]
type = ChangeState
value = 262
triggerall = command = "y"
trigger1 = stateno = 255
trigger1 = Time = [0,60]
trigger2 = stateno = 260
trigger2 = movecontact
trigger3 = stateno = 261
trigger3 = movecontact
trigger4 = stateno = 262
trigger4 = movecontact
trigger5 = stateno = 263
trigger5 = movecontact
trigger6 = stateno = 264
trigger6 = movecontact

;---------------------------------------------------------------------------
;空中ＨＳ攻撃(ダスト中)
[State -1, Jump Strong Kick]
type = ChangeState
value = 263
triggerall = command = "b"
trigger1 = stateno = 255
trigger1 = Time = [0,60]
trigger2 = stateno = 260
trigger2 = movecontact
trigger3 = stateno = 261
trigger3 = movecontact
trigger4 = stateno = 262
trigger4 = movecontact
trigger5 = stateno = 263
trigger5 = movecontact
trigger6 = stateno = 264
trigger6 = movecontact

;---------------------------------------------------------------------------
;空中Ｄ攻撃(ダスト中)
[State -1, Jump Strong Kick]
type = ChangeState
value = 264
triggerall = command = "z"
trigger1 = stateno = 255
trigger1 = Time = [0,60]
trigger2 = stateno = 260
trigger2 = movecontact
trigger3 = stateno = 261
trigger3 = movecontact
trigger4 = stateno = 262
trigger4 = movecontact
trigger5 = stateno = 263
trigger5 = movecontact
trigger6 = stateno = 264
trigger6 = movecontact

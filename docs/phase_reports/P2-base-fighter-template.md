# Phase Report — P2: Base Fighter Template

**Status: PASS**（all ten exit gates met; two items explicitly limited to
real-human verification as allowed by contract §17）

- Branch: `feature/p2-character-template`
- Baseline: IKEMEN GO `v1.0.0-rc.5` (`ba516193bba83f13f0b63ddce314d8719793931f`),
  submodule clean, engine untouched (`git -C engine/ikemen-go status --short` empty)
- Template: `game/chars/_template/` (11 files, single Git source of truth)
- Iteration log: [`docs/iterations/20260915-p2-character-template.md`](../iterations/20260915-p2-character-template.md)

## 1. Deliverable

A real IKEMEN RC5 character that loads and fights:

- **Movement** (T1): walk/crouch/jump/dash/backhop — all *common states*, no
  re-implementation; template only routes double-taps (FF→100, BB→105).
- **Standing normals** (T2): A=200 (25), B=230 (15), C=210 (70), D=240 (90);
  each with own startup/recovery and explicit exit path.
- **Defense / hit / down / recovery** (T3): guard via common 120/130–155
  (proven live, State 130 + guard meter gain); hit/down/getup are common
  5000–5210 — nothing re-implemented.
- **Throw** (T4): close + hold F/B + C/D → 800 (NT hitDef) → 810
  (targetBind → targetLifeAdd → targetState), victim plays attacker's AIR via
  `changeAnim2`. Damage 90.
- **Placeholder special** (T5): QCF+A → 1000 (95), QCF+C → 1010 EX (70).
- **Meter** (T6): native `power` only. Cap 1000 (`const power`, **cap not
  start value** — engine zeroes power each round; proven vs KFM). Income:
  hitDef hit-gain (A: 0→37, C: 0→84 measured) + `poweradd` (+40 on special
  entry). Spend: `power >= 500` route gate + `powerAdd -500` in 1010.
- **Cancel** (T7): `Combo()` in command.zss — ground-free or 200/230 after
  first active frame (`animElemTime(3) >= 0`) with `var(0)` latch. Live: A →
  cancel window → QCF+A → 1000 (77 = 37 hit-gain + 40 poweradd, exact).
- **Variables** (T8): ledger in `_template.const` (var(0) cancelUsed,
  var(1) aiCooldown, 10–39 char, 40–59 AI, 60+ persistent, map("canCombo") RO).
- **AI** (T9): `AI.zss` rule order = priority. Live: AI fought the KFM dummy
  from 1000 to 130 LIF with normals and fired State 1000 on its own.

## 2. Runtime Validation Matrix

Harness: `tests/p1/capture_match.ps1`, `tests/p2/inject_phases.ps1`
(new). Every injected run has `-Ai1 0`; every report's `args` line was checked
to contain no `-p1.ai`; debug overlay ON in every cited frame.

| V | Claim | Result | Evidence (`logs/p1|p2/shots/`) |
| --- | --- | --- | --- |
| V01 | template loads in RC5 | **PASS** | report `args` clean; `New char loaded: chars/_template/` |
| V03 | directions reach engine | **PASS** | 0x27→20, 0x25→21, 0x28→10/11, 0x26→41 |
| V04 | guard works | **PASS** | `v04_guard_seq01_holdback_burst12.png`: StateNo 130, POW 458 (guard gain); note: loses to AI-8 pressure by design |
| V07 | dash / backhop | **PASS** | StateNo 105 frame; 100 vs KFM cross-check (engine sequencing note in iteration log) |
| V09 | A = 200, 25 dmg | **PASS** | `v09b_normA_seq02_tapA_burst06.png`: P2 LIF 1000→975, MoveType H, FIRST ATTACK |
| V10 | C = 210, 70 dmg | **PASS** | `v10_normC_seq02_tapC_burst10.png`: LIF→930 |
| V11 | throw flow | **PASS** | `v11_throw_p02_27+0D_burst08.png`: 810, Target 57; `burst20`: LIF→910 airborne |
| V12 | QCF+A → 1000, 95 dmg | **PASS** | `v12b_special_p05_09_burst05/09.png`: StateNo 1000 → LIF→905 + spark |
| V13 | EX gate & spend | **PASS** | F3 fill (hotkey reachable!) → `v13_ex_p06_0D_burst07.png`: 1010, POW 1000→500, LIF→930 |
| V14 | cancel 200→1000 | **PASS** | `v14_cancel_p06_09_burst05.png`: 1000, P2 already −25, POW 77 = 37+40 |
| V15 | AI uses normal + special | **PASS** | `v15_ai_02.png` (dummy→130, Target 57), `v15_ai_03.png` (AI StateNo 1000) |
| V16 | Clsn observable | **PASS** | ShowClsn frames in V09–V13 (pink Clsn1 / blue Clsn2) |
| V17 | hit/down/getup chain | **PASS** | V11 airborne victim → `v11_throw_02.png` back to idle State 0 |
| V05 | crouch reachable | **PASS** | StateNo 11, Type C (crouch-attack frame, before scope note below) |
| V02/V06 | idle / jump | **PASS** | covered by V03/V09 sequences |
| — | **B/D buttons, taunt(195)** | **真人验证** | synthetic injection cannot reach letters/start on this machine (contract §17) — no claims made |
| — | crouch/air attacks, supers | **out of scope** | numbers reserved; `command != "holddown"` guard already in routing |

## 3. Fixed during this phase

- ZSS parser: bare `animElem` trigger only supports `=`/`!=`; `animElem >= 3`
  panics. Idiom: `animElemTime(3) >= 0` (KFM command.zss:241). Documented
  inline; template loads again (V01).
- Meter comment wrong in `_template.const` ("starting power"): corrected to
  **cap** with source refs (char.go:3740, kfm.const wording, POW:0 probe).
- `inject_phases.ps1` single-channel injection silently dropped whole phases;
  switched to the P1 double-channel core (`keybd_event` + `PostMessage`).

## 4. Known limitations

1. Placeholder SFF/SND = P1 KFM lab files, CC-BY-NC, `prototype_only`,
   registered in `assets/LICENSE_MANIFEST.csv`; **must be replaced per clone**.
2. Crouch/air attacks & supers not implemented (reserved; routing guard in place).
3. B/D + taunt runtime evidence requires a human keyboard pass.
4. State 200 total length 20 ticks is observability-first tuning.
5. Cancel does not require `moveContact` (deliberate; hook documented).

## 5. Exit gates

| Gate | Verdict |
| --- | --- |
| GATE-01 P1 baseline present | PASS (main `99add4d` contains P1; submodule pinned) |
| GATE-02 IKEMEN baseline unchanged | PASS (HEAD `ba51619...`, submodule clean) |
| GATE-03 single template source | PASS (game/chars/_template; design/ relocated) |
| GATE-04 loads & runs | PASS (V01 + full match evidence) |
| GATE-05 basic fighting ability | PASS (V03/V04/V07/V09/V10/V17) |
| GATE-06 combat conventions | PASS (T4 throw V11, T6 meter V13, T7 cancel V14, T8 ledger) |
| GATE-07 AI interface | PASS (V15) |
| GATE-08 template docs | PASS (`game/chars/_template/README.md` rewritten) |
| GATE-09 tests & regression | PASS (`scripts/test.ps1` green; tests/p2 tool added) |
| GATE-10 phase close | PASS (status/iteration/report/summary + git flow) |

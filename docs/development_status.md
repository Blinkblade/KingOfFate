# Development Status

> This file answers **"where is the project right now"**.
> For the history of *how* it got here see [`docs/iterations/`](iterations/).
>
> It is updated whenever a phase changes state. Never mark a phase `PASS` while any
> of its gates is unmet.

Last updated: 2026-09-29

---

## Phase overview

| Phase | Name | Status |
| --- | --- | --- |
| **P0** | Repository & Environment | **PASS** |
| **P1** | IKEMEN Character Architecture | **PASS** |
| **P2** | Base Fighter Template | **PASS** |
| **P3** | Test Fighter A | **PASS** |
| **P4** | Test Fighter B | **PASS** |
| **P5** | Character Asset Tooling | **PASS** |
| **P6** | First Final-Art Character | **NEXT** |
| **P7** | Character Skills & Presentation | NOT_STARTED |
| **P8** | CPU AI v1 | NOT_STARTED |
| **P9** | Utility AI | NOT_STARTED |
| **P10** | Automated Match & Balance | NOT_STARTED |
| **P11** | UI / Stage / Audio | NOT_STARTED |
| **P12** | Windows Release | NOT_STARTED |

---

## P0 — Repository & Environment

**Status: PASS**

All 10 exit gates pass. The engine builds and runs, and every step is reproducible from
the repository scripts. See the phase report for the full account:
[`docs/phase_reports/P0-repository-and-environment.md`](phase_reports/P0-repository-and-environment.md).
For a one-page overview plus the script handbook (what each script does and how to use it),
see [`docs/P0-summary.md`](P0-summary.md).

### Completed

- KingOfFate public repository created
- IKEMEN GO fork created (`Blinkblade/Ikemen-GO`)
- engine fork `origin` / `upstream` configured
- integration branch `kingoffate/rc5` created
- baseline pinned to `v1.0.0-rc.5` (`ba516193bba83f13f0b63ddce314d8719793931f`)
- IKEMEN GO added as the `engine/ikemen-go` Git submodule
- engine baseline commit recorded and pushed to `main`
- project directory structure
- development status + iteration record system
- `CONTRIBUTING.md` + pull request template
- Windows build environment (MSYS2 / MINGW64 toolchain verified by `scripts/check_build_env.sh`)
- runtime assets (official screenpack) unpacked next to the executable
- `scripts/build_engine.ps1`, `scripts/run_game.ps1`, `scripts/test.ps1`
- smoke test suite in `tests/smoke/` (26/26 static; 29/29 with the real launch check)
- engine built: `engine/ikemen-go/Ikemen_GO.exe` (14.94 MB)
- engine verified running: window `Ikemen GO`, responsive
- `README.md`, `CONTRIBUTING.md`, `docs/environment.md`, `docs/phase_reports/`

### P0 exit gates

| Gate | Description | Result |
| --- | --- | --- |
| PASS-01 | `engine/ikemen-go` still points at the correct submodule baseline | **PASS** |
| PASS-02 | IKEMEN GO builds successfully in the current Windows environment | **PASS** |
| PASS-03 | the built program starts successfully | **PASS** |
| PASS-04 | `scripts/build_engine.ps1` can repeat the build | **PASS** |
| PASS-05 | `scripts/run_game.ps1` can launch the game | **PASS** |
| PASS-06 | `scripts/test.ps1` basic smoke test passes | **PASS** (26/26 static; 29/29 with `-RuntimeTest`) |
| PASS-07 | README / environment / development_status are in sync | **PASS** |
| PASS-08 | this iteration's Iteration Record is complete | **PASS** |
| PASS-09 | `git status` shows no stray temporary files | **PASS** |
| PASS-10 | nothing depends on an unrecorded manual step | **PASS** |

### Carried into later phases

These do not block P0 but must not be forgotten:

- `pacman` signature checking is disabled locally (`SigLevel = Never`) because the gpg
  shipped with this MSYS2 snapshot loops forever on `pacman-key --init`. Restore
  `SigLevel = Required` once MSYS2 is fixed. See `docs/environment.md`.
- The build uses the system FFmpeg (`BUILD_FFMPEG=no`) instead of building FFmpeg from
  source. WebM alpha video may therefore not use the libvpx decoder. Switch back to
  `auto` when the environment allows.
- Runtime DLLs are not bundled; `run_game.ps1` prepends the MSYS2 `mingw64/bin` to the
  game process PATH. Release packaging (P12) must place them next to the executable.
- `feature/p0-bootstrap` has been pushed to `origin`. The pull request itself still has to
  be opened on GitHub by hand (no `gh` CLI on this machine): `feature/p0-bootstrap` → `main`.
  The ready-to-paste PR title and description are recorded in `docs/P0-summary.md` (§9).

---

## P1 — IKEMEN Character Architecture

**Status: PASS**

All 10 exit gates pass. The IKEMEN character execution chain is understood and validated by
measurement, and the knowledge is written down so P2 can start without further research.
See the phase report for the full account:
[`docs/phase_reports/P1-ikemen-character-architecture.md`](phase_reports/P1-ikemen-character-architecture.md).
For a one-page overview plus the tool handbook, see [`docs/P1-summary.md`](P1-summary.md).

### Completed

- `docs/ikemen_character_architecture.md` — character file structure, the 6-stage execution
  chain (input → command → routing → state → hitbox → hit), state machine and state-number
  conventions, ZSS syntax and project conventions, hitbox model, AI mechanics, Lua extension
  points, and the change-boundary table (what needs engine changes vs. what does not)
- `docs/p1_experiments.md` — six experiments (E1–E6) plus the input-injection probe (E0),
  each with before/file/location/change/expectation/method/result/conclusion
- P1 Lab character `game/chars/p1_kfm_zss_lab/` (tracked research copy of IKEMEN's KFM ZSS),
  byte-identical to upstream apart from the display name and a licence note
- `scripts/sync_game_content.ps1` — one-way, idempotent, offline `game/` → runtime sync
- `tests/p1/` — behaviour observation tooling (`capture_match.ps1`, `montage_states.ps1`),
  with `tests/p1/README.md`
- `design/characters/_template/` — the P2 fighter skeleton (10 files + README)
- `docs/evidence/p1/` — original evidence (montages, screenshots, run reports)
- `docs/iterations/20260914-p1-kfm-study.md` — this phase's iteration record

### What was measured (not inferred)

| # | Changed | Observed |
| --- | --- | --- |
| E1 | `.const` `walk.fwd 2.4 → 12.0` | displacement 56 units in 0.35 s → reaches the opponent (ratio not directly readable; stated as such) |
| E2 | `.zss` `hitDef.damage 23 → 137` | `P2 LIF` exactly `1000→977` / `1000→863`; meter and red-life move with it |
| E3 | `.air` first element `2 → 20` frames | animation total **12 → 30**; `hitDef` trigger tick 4 → 22 |
| E4 | `.air` `Clsn1[0]` enlarged ~10× | hitbox grows hugely; hurtbox, sprite and damage all unchanged |
| E5 | `.cmd` `name="x"` rebound to `y` | `x` stops working entirely; `y` enters State **200** (order priority) |
| E6 | `AI.zss` first rule → `changeState 210` | 11 of 12 sampled frames become 210; opponent never loses life |

### P1 exit gates

| Gate | Description | Result |
| --- | --- | --- |
| PASS-01 | `engine/ikemen-go` still points at the pinned submodule baseline and its worktree is clean | **PASS** |
| PASS-02 | every stage of the character execution chain is validated inside character files | **PASS** |
| PASS-03 | the architecture document is complete and every claim is traceable to a file | **PASS** |
| PASS-04 | every experiment has original evidence (screenshots / state readouts / run reports / pixel measurements) | **PASS** |
| PASS-05 | a character skeleton exists that P2 can copy directly | **PASS** |
| PASS-06 | the boundary between "needs an engine change" and "does not" is stated explicitly | **PASS** |
| PASS-07 | `scripts/test.ps1` still passes | **PASS** (26/26) |
| PASS-08 | `docs/development_status.md` and `README.md` are updated truthfully; unfinished work is `BLOCKED` | **PASS** |
| PASS-09 | the lab character matches upstream and every experiment change was reverted | **PASS** |
| PASS-10 | this iteration's Iteration Record is complete; no unrecorded manual step | **PASS** |

### Carried into later phases

These do not block P1 but must not be forgotten:

- **Only TAB and RETURN reach the engine through synthetic input on this machine.** The
  runtime key bindings were therefore locked to `x=TAB`, `y=RETURN` for the experiments
  (`save/config.ini`, gitignored, since restored). As a result combination commands
  (`x+y`) could not be tested — E5 covers single-button routing only.
- **Key injection must pass `-Ai1 0`.** The harness defaults to AI level 8, which means the AI
  controls P1; the AI calls `changeState` directly and disables default walking
  (`assertSpecial{flag: nowalk}`), so injected directions do nothing — silently, because the
  character is visibly moving anyway. Self-check: if the `args` line of a run report contains
  `-p1.ai`, that run's injection was ineffective. E1's first attempt hit exactly this.
- **The debug overlay does not print world coordinates, and its `P1: <n>` field is the
  character ID.** `debug.lua:183-184` shows that field is `id()`, not a position — E1's first
  evidence read it as one and was therefore meaningless. E1 has been redone by measuring
  on-screen name-tag centres with `tests/p1/measure_positions.ps1` (5.14× for a 5× constant),
  and the superseded evidence was removed from `docs/evidence/p1/`. Pixel measurement is only
  good to about ±1 px, and the two tags merge into one cluster once the characters touch.
- **`design/characters/_template/` has no `.sff` / `.snd`.** Binary containers cannot be
  created as text. P2 must either borrow existing assets temporarily — which then have to be
  recorded in `assets/LICENSE_MANIFEST.csv` and must never ship — or wait for P5 tooling.
- **The PR still has to be opened on GitHub by hand** (no `gh` CLI on this machine):
  `feature/p1-kfm-study` → `main`. Ready-to-paste title and description are in
  [`docs/P1-summary.md`](P1-summary.md) §9.
- The observation tooling needs a real desktop session (foreground focus and window
  rendering), so it cannot run in a headless CI.

---


## P2 — Base Fighter Template

**Status: PASS**

All ten exit gates pass. The P1 skeleton is now a runnable, cloneable 4-button
fighter at `game/chars/_template/`, validated in real RC5 matches (damage
numbers, meter gate/spend, cancel, throw flow, AI usage all captured on
frames). IKEMEN baseline unchanged; submodule clean.

- Phase report: [`docs/phase_reports/P2-base-fighter-template.md`](phase_reports/P2-base-fighter-template.md)
- One-pager: [`docs/P2-summary.md`](P2-summary.md)
- Template handbook: [`game/chars/_template/README.md`](../game/chars/_template/README.md)
- Iteration log: [`docs/iterations/20260915-p2-character-template.md`](iterations/20260915-p2-character-template.md)

Scope notes: crouch/air attacks and supers are reserved numbers, not
implemented; placeholder SFF/SND are the P1 KFM lab files (CC-BY-NC,
prototype-only, registered) and must be replaced by every clone.

Audit revision (2026-09-16): every P2 claim was re-checked against the code and
the original frames. 13 doc/comment errors were corrected and one real defect
was fixed — the missing win-pose `State 180` (the engine logged
`changed to invalid state 180` at round end). No functional defect remains;
see Phase Report §4 for the full list and the method.

---

## P3 — Test Fighter A

**Status: PASS**

`_template` was proven to be a real production start: cloning it produced
`game/chars/test_fighter_a/` — a complete 4-button fighter with the full normal
set (standing / crouching / jumping), two specials, a real EX upgrade, the
project's first Super, a three-level cancel chain and its own CPU AI. Runtime
matrix V01–V29 all green (14 of 16 attack damage values measured on frames and
equal to the configured `damage:`), engine baseline unchanged and submodule clean.

- Phase report: [`docs/phase_reports/P3-test-fighter-a.md`](phase_reports/P3-test-fighter-a.md)
- One-pager: [`docs/P3-summary.md`](P3-summary.md)
- Character handbook: [`game/chars/test_fighter_a/README.md`](../game/chars/test_fighter_a/README.md)
- Frame data: [`design/characters/test_fighter_a/moves.csv`](../design/characters/test_fighter_a/moves.csv)
- Iteration log: [`docs/iterations/20260916-p3-test-fighter-a.md`](iterations/20260916-p3-test-fighter-a.md)
- New harness: [`tests/p3/run_match_watch.ps1`](../tests/p3/run_match_watch.ps1) (unattended run + crash-log watch)

Notable findings: `call` statements need semicolons and cannot be used inline in
an `if` condition (load-time panic, invisible to `scripts/test.ps1`); `pwsh -File`
cannot bind comma lists to array parameters (silent wrong-argument binding);
the engine's console is not capturable via redirect, so engine-level evidence is
the crash log at `engine/ikemen-go/save/logs/` plus in-game console text in
screenshots; guarding is engine-level (states 150/152) and needs no character
routing. Template gaps found while cloning (missing `displayname` and README
steps, no clone-verification step) were fixed in the template's documentation;
its combat logic was deliberately left untouched.

## P4 — Test Fighter B
**Status: PASS** (2026-09-28)

All ten gates passed. The last two were settled by controlled experiments rather
than by assertion:

- Gate 6 (cancel out of state 200 into the projectile): a control run shows state
  200 living its full 20 ticks, a cancel run shows it cut to 7 ticks with state
  1000 starting on the next tick and no idle frame in between
  (`docs/evidence/p4/gate6_cancel_sequence.txt`).
- Gate 7 (projectile guarded / jumped over): scripted dummies driven from their
  own `[StateDef -3]` — `assertSpecial{flag: autoGuard}` and
  `assertInput{flag: U}`. P2 life 1000->994 when guarding, 1000->1000 when the
  projectile passes under a jumping dummy, against a 1000->940 control
  (`docs/evidence/p4/gate7_dummy_matrix.txt`).

The character is complete and playable, and the phase's central question is
answered (the same `_template` does carry a second, very different fighting
style).

- Phase report: [`docs/phase_reports/P4-test-fighter-b.md`](phase_reports/P4-test-fighter-b.md)
- One-pager: [`docs/P4-summary.md`](P4-summary.md)
- Character handbook: [`game/chars/test_fighter_b/README.md`](../game/chars/test_fighter_b/README.md)
- Frame data: [`design/characters/test_fighter_b/moves.csv`](../design/characters/test_fighter_b/moves.csv)
- Iteration log: [`docs/iterations/20260918-p4-test-fighter-b.md`](iterations/20260918-p4-test-fighter-b.md)
- Baseline audit (2026-09-20): [`docs/iterations/20260920-p4-baseline-audit.md`](iterations/20260920-p4-baseline-audit.md)

**Evidence channel (added 2026-09-20).** A batch of earlier runtime numbers turned
out to have no machine source: they had been read off screenshots, which cannot be
audited. Those claims were withdrawn (Phase Report §5.x). Runtime values are now
read programmatically from the debug overlay with
`tools/read_frame_text.py`, and multi-combination matches are run by
`tests/p4/run_matrix.ps1` (6 combinations — both seat orders, mirrors, asymmetric
AI, and vs the reference KFM — all clean, `crashlogs: 0 new`).

Delivered: `game/chars/test_fighter_b/` — a **Zoner** cloned from `_template`
(not from Fighter A), with a native `projectile{}` special, a long-reach
Standing Heavy Punch (hitbox to `x=105`, no `posAdd`), two anti-air tools
(410 to `y=-112`, 1100 to `y=-152`), a two-shot EX and a three-shot Super, its own
`CanChain` levels and its own Zoner AI. Engine baseline unchanged; submodule clean.

**Gate status**: 1–10 **all PASS** (2026-09-28).

Gates 6 and 7 used to be BLOCKED. For the record, the path that got there:

- Gate 6 (cancel 200 -> 1000): the injection blockers below were fixed first;
  the gate itself was then settled by stepping one tick at a time and comparing a
  control run against a cancel run — 20 ticks of state 200 versus 7, with state
  1000 starting on the next tick (`docs/evidence/p4/gate6_cancel_sequence.txt`).
- Gate 7 (projectile guarded / jumped over): solved without any human at the
  menu. The engine exposes `assertSpecial{flag: autoGuard}` and
  `assertInput{flag: U}` (the very calls its own `data/training.zss` uses), so a
  generated fixture character drives itself — see `tests/p4/make_dummy.ps1`.
  Recording this because the earlier note claiming "a human has to press the
  keys" was simply wrong, and it cost a round of work.

Earlier blockers, all fixed: synthetic directional input, and this machine's
injection silently failing for arrow keys. Root cause found and fixed —
`tests/p2/inject_phases.ps1` was missing `KEYEVENTF_EXTENDEDKEY` (arrow keys share
scan codes with the numeric keypad, so the engine saw "numpad 8" instead of "up").
A second, subtler blocker was also found and fixed: the harness burst-captures
during a phase, and `PrintWindow` blocks this OpenGL window's render thread, which
starved the engine down to ~10% speed so every injection landed in the
round-intro "FIGHT!" window where the character is not controllable. After both
fixes, Gate 4's anti-air hit was captured on an airborne opponent
(`logs/p2/shots/p4v_aa5_06.png`). Gates 6 / 7 were "not yet measured", and now
they are measured — see above.

Two engine-level findings worth carrying forward:

- **A projectile's attack box must use `Clsn1Default`, not `Clsn1`.** A per-frame
  `Clsn1:` declaration only covers the frame it precedes; the `-1` hold frame of a
  projectile animation then carries no attack box at all, so the projectile flies
  beautifully and never hits. Symptom shape: small hitboxes all miss, only a huge
  one connects.
- **`animElem = N` is true for the whole duration of element N**, so firing a
  projectile from `animElem` needs an explicit latch (`var(10)` here).

Verdict on re-injecting into `_template`: **no**. Only documentation was changed
(two factual errors corrected) plus the two harness defects; the template's combat
logic is untouched and Fighter B's moves stay as a reference sample.

---

## P5 — Character Asset Tooling

**Status: PASS** (2026-09-29)

All ten exit gates pass. The phase built the smallest tool chain that lets P6 look at a
new character's assets *before* putting them in the game: read an SFF, export its
sprites, read an animation table, find reference and collision mistakes, and judge
whether a character directory is complete enough to reach Runtime at all. Nothing in the
engine was changed, and the tools are read-only.

Delivered: `tools/kofassets/` (a standard-library-only reader), `tools/sffctl/`,
`tools/airtool/`, `tools/character_validate/`, `tools/asset_report.py` (the whole
workflow as one command), a fixture set under `tests/fixtures/`,
`tests/tools/run_tool_tests.ps1` (69 checks, 74 with `-Full`), the tool guide
`docs/character_asset_tooling.md`, and the P6-ready end-to-end run recorded in
`docs/evidence/p5/p6_ready_run.txt`.

The tools found a real defect on their first run: `test_fighter_b.air` action 410
referenced sprite `410,5`, which the placeholder SFF does not have (the engine logs a
missing sprite and draws nothing for those five ticks). It was fixed to `410,4` with the
tick count unchanged, and a runtime regression (`run_matrix.ps1 -Only b_vs_a`) confirms
`crashlogs : 0 new`.

- Phase report: [`docs/phase_reports/P5-character-asset-tooling.md`](phase_reports/P5-character-asset-tooling.md)
- One-pager: [`docs/P5-summary.md`](P5-summary.md)
- Tool guide: [`docs/character_asset_tooling.md`](character_asset_tooling.md)
- Iteration log: [`docs/iterations/20260929-p5-character-asset-tooling.md`](iterations/20260929-p5-character-asset-tooling.md)

Two things from P4 are now stated on the tool side rather than in prose:
`Clsn1`/`Clsn2` apply to the single element that follows them while
`Clsn1Default`/`Clsn2Default` apply to every element of the action (so a projectile's
`-1` hold frame needs the default form), and the tools print that per element.

**Known limitations carried into P6** (all documented, none blocking):

- SFF v1 and raw true-colour SFFv2 sprites are refused rather than guessed at. No
  character asset in this repository uses either.
- No SFF write-back, no AIR editing, no SND, no palette editing, no GUI, no sprite-sheet
  cutting. Deliberately out of scope until P6 says otherwise.
- All three characters carry three `AIR_HURTBOX_GAP` warnings each (actions 210 / 230 /
  820) inherited from `_template`'s authoring style: a per-frame `Clsn2` covers one
  element only, so the character has no hurtbox for those ticks. Real but not
  gameplay-measurable; P6 should use `Clsn2Default`.
- The `.air` comments in the three characters say "`Clsn1` carries over to the next
  declaration", which does not match the engine. Recorded, not edited here.
- The carried-over P4 item (re-checking the values in P1–P3 that were read off
  screenshots) is still open; it did not block P5.

---

## P6 — First Final-Art Character

**Status: NEXT**

Not started. The entry point is `docs/P5-summary.md`: the asset tool chain is in place,
so this phase starts by running the new tools against the first real art set rather than
by writing tooling.

---

## P7 — Character Skills & Presentation

**Status: NOT_STARTED**

---

## P8 — CPU AI v1

**Status: NOT_STARTED**

---

## P9 — Utility AI

**Status: NOT_STARTED**

---

## P10 — Automated Match & Balance

**Status: NOT_STARTED**

---

## P11 — UI / Stage / Audio

**Status: NOT_STARTED**

---

## P12 — Windows Release

**Status: NOT_STARTED**

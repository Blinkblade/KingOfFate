# Development Status

> This file answers **"where is the project right now"**.
> For the history of *how* it got here see [`docs/iterations/`](iterations/).
>
> It is updated whenever a phase changes state. Never mark a phase `PASS` while any
> of its gates is unmet.

Last updated: 2026-09-14

---

## Phase overview

| Phase | Name | Status |
| --- | --- | --- |
| **P0** | Repository & Environment | **PASS** |
| **P1** | IKEMEN Character Architecture | **PASS** |
| P2 | Base Fighter Template | NOT_STARTED |
| P3 | Test Fighter A | NOT_STARTED |
| P4 | Test Fighter B | NOT_STARTED |
| P5 | Character Asset Tooling | NOT_STARTED |
| P6 | First Final-Art Character | NOT_STARTED |
| P7 | Character Skills & Presentation | NOT_STARTED |
| P8 | CPU AI v1 | NOT_STARTED |
| P9 | Utility AI | NOT_STARTED |
| P10 | Automated Match & Balance | NOT_STARTED |
| P11 | UI / Stage / Audio | NOT_STARTED |
| P12 | Windows Release | NOT_STARTED |

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
| PASS-04 | every experiment has original evidence (screenshots / state readouts / run reports) | **PASS** |
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
- **E1 did not quantify the speed ratio.** The stage is too narrow: the character reaches the
  opponent and is stopped by the push box. Fix by exposing `pos x` (e.g. `displayToClipboard`)
  and measuring time-to-contact instead.
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

**Status: NOT_STARTED**

---

## P3 — Test Fighter A

**Status: NOT_STARTED**

---

## P4 — Test Fighter B

**Status: NOT_STARTED**

---

## P5 — Character Asset Tooling

**Status: NOT_STARTED**

---

## P6 — First Final-Art Character

**Status: NOT_STARTED**

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

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
| P1 | IKEMEN Character Architecture | NOT_STARTED |
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
- smoke test suite in `tests/smoke/` (29/29 passing, including a real launch check)
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
| PASS-06 | `scripts/test.ps1` basic smoke test passes | **PASS** (29/29) |
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
  The suggested PR title/description is in `docs/P0-summary.md` and the phase report.

---

## P1 — IKEMEN Character Architecture

**Status: NOT_STARTED**

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

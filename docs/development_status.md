# Development Status

> This file answers **"where is the project right now"**.
> For the history of *how* it got here see [`docs/iterations/`](iterations/).
>
> It is updated whenever a phase changes state. Never mark a phase `PASS` while any
> of its gates is unmet.

Last updated: 2026-09-12

---

## Phase overview

| Phase | Name | Status |
| --- | --- | --- |
| **P0** | Repository & Environment | **BLOCKED** |
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

**Status: BLOCKED**

Blocked on: the engine cannot currently be compiled in this local environment. `cc1.exe` cannot
write the temporary `.s` file that the gcc driver creates while **cgo** compiles, failing with
`Permission denied` (see `docs/iterations/20260911-p0-bootstrap.md` for the evidence and for the
hypotheses that were already excluded). Everything that does not need a compiled binary is done.

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
- smoke test suite in `tests/smoke/`
- `README.md`, `docs/environment.md`

### Still open

- engine build (`Ikemen_GO.exe`)
- engine runtime verification

### P0 exit gates

| Gate | Description | Result |
| --- | --- | --- |
| PASS-01 | `engine/ikemen-go` still points at the correct submodule baseline | **PASS** |
| PASS-02 | IKEMEN GO builds successfully in the current Windows environment | **BLOCKED** |
| PASS-03 | the built program starts successfully | **BLOCKED** |
| PASS-04 | `scripts/build_engine.ps1` can repeat the build | **PASS** (script verified; the build itself is blocked) |
| PASS-05 | `scripts/run_game.ps1` can launch the game | **BLOCKED** (needs a built executable) |
| PASS-06 | `scripts/test.ps1` basic smoke test passes | **PASS** (static checks) |
| PASS-07 | README / environment / development_status are in sync | **PASS** |
| PASS-08 | this iteration's Iteration Record is complete | **PASS** |
| PASS-09 | `git status` shows no stray temporary files | **PASS** |
| PASS-10 | nothing depends on an unrecorded manual step | **PASS** |

Full detail, including exactly which hypotheses were excluded and what is required to unblock the
build, is in the P0 iteration record:
[`docs/iterations/20260911-p0-bootstrap.md`](iterations/20260911-p0-bootstrap.md).

A phase is only ever marked `PASS` when every gate passes.

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

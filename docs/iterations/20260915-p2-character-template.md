# Iteration — 2026-09-15 — P2: Base Fighter Template

Branch: `feature/p2-character-template`
Contract: P2 agent prompt (T1–T9, V01–V24, GATE-01..10)

## What this iteration did

Turned the P1 design skeleton (`design/characters/_template/`) into a real,
loadable, runnable, cloneable 4-button base fighter at `game/chars/_template/`,
with runtime evidence for every claim that can be observed on this machine.

## Work log (order of events)

1. **Baseline re-verified**: submodule HEAD `ba51619...` (rc.5, clean), P1 merged
   to `main` (`99add4d`). Branch created off `main`.
2. **Single source of truth**: `git mv design/characters/_template →
   game/chars/_template` (10 renames). Placeholder SFF/SND copied from the P1
   KFM lab (CC-BY-NC, Elecbyte), registered in `assets/LICENSE_MANIFEST.csv`.
   → commit `6d8afb0`.
3. **T1–T9 implementation**: states 195/200/210/230/240/800/810/1000/1010,
   command routing, AI, const/velocity, AIR actions, meter, cancel.
   → commit `8a54618`.
4. **ZSS parser bug found & fixed** (was blocking V01): a bare `animElem`
   trigger only supports `=` / `!=`. `animElem >= 3` panics the engine with
   `Missing '=' or '!='`. The correct idiom for "at/after element 3" is the
   function form `animElemTime(3) >= 0` — exactly what KFM's command.zss does.
   Recorded inline in `command.zss`.
5. **Runtime harness extended**: `tests/p2/inject_phases.ps1` — phases of
   simultaneous keys (throw = F+y) and motion inputs (QCF). Double-channel
   injection (`keybd_event` + `PostMessage`) was mandatory: single-channel
   phases were silently dropped.
6. **Key bindings restored for testing**: `save/config.ini [Keys_P1]` had been
   reset to defaults after P1 (`x=a, y=s`), so injected TAB/RETURN did nothing.
   Re-applied the P1 test mapping (`x=TAB, y=RETURN, start=Not used`) for the
   validation runs; **restored to defaults afterwards** (gitignored file).
7. **Meter semantics corrected** (T6): `const power` is the meter **cap**
   (`c.powerMax = gi.data.power`, char.go:3740), not the starting amount. The
   engine zeroes power every round — KFM (cap 3000) also shows `POW: 0` at
   round start. Fixed the wrong comment in `_template.const`; template behavior
   (hit-gain + `poweradd` income, `power >= 500` gate, `powerAdd -500` spend)
   was already correct and is now runtime-proven.
8. **Validation matrix executed** (see phase report for the V-table):
   V01 load, V03 directions, V04 guard (State 130 + guard meter gain),
   V07 FF/BB, V09 A=25 dmg, V10 C=70 dmg, V11 throw=90 dmg + 810 flow,
   V12 QCF+A→1000=95 dmg, V13 EX→1010 & power 1000→500, V14 cancel 200→1000,
   V15 AI (normals + special), V16 Clsn on-screen, V17 hit/down/recover chain.
9. **QCF timing lesson**: phase gaps of 0.3 s blew the 25-tick command window —
   motion inputs need `-SettleSec 0.02` with 0.06 s phases (跨度 ≈15 ticks).

## Decisions

- Crouch attacks (400–440) / air attacks (600–640) / supers (3000+) are
  **explicitly out of template scope**; numbers reserved, routing includes a
  `command != "holddown"` guard so 400s can be added without touching standing
  normals.
- Cancel window deliberately does not require `moveContact` (observability);
  the tightening hook (`&& moveContact`) is documented in place.
- Debug hotkeys (F3 = fill meter) ARE reachable by synthetic injection — used
  by V13 to stage the EX gate test. This was "unverified" in P1 notes.
- `Buffer.time` for QCF = 14 ticks (KOF-style), FF/BB `time = 25` (observability
  over 90s feel) — both documented at the definition site.

## Follow-ups

- Replace placeholder art/audio per clone (hard requirement, CC-BY-NC).
- Real-human verification list: B/D buttons, taunt (start), fine frame feel.
- `config.ini` test mapping was restored; re-apply when running injection tests.

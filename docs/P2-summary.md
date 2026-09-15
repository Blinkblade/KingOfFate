# P2 Summary — Base Fighter Template

> One-page overview. Full account:
> [`docs/phase_reports/P2-base-fighter-template.md`](phase_reports/P2-base-fighter-template.md).
> Template handbook (how to clone, extend, what to replace):
> [`game/chars/_template/README.md`](../game/chars/_template/README.md).

**Status: PASS.** The P1 design skeleton is now a real IKEMEN RC5 character at
`game/chars/_template/`: loads, fights, clones. Engine untouched
(`v1.0.0-rc.5`, submodule clean).

## What exists now

- Movement & defense & hurt chains: **common states** (0/10/20/21/40s/100/105/
  120–155/5000–5210) — template routes, never re-implements.
- Template-implemented states: 195 taunt, 200/230/210/240 standing A/B/C/D
  (25/15/70/90), 800/810 throw (90), 1000 special (95), 1010 EX (70, spends 500).
- Conventions with receipts: state numbers, variable ledger, meter semantics,
  cancel window (`Combo()` + `var(0)` latch), AI priority-by-order.
- New tool: `tests/p2/inject_phases.ps1` (multi-key phases — throws, QCF).

## The five facts a character dev must know

1. `command.zss` order = priority; narrower rules first (E5).
2. `.air` frames = feel; Clsn1/Clsn2 independent of damage (E4).
3. `hitDef.damage` = exact damage (E2).
4. `const power` is the meter **cap**; power is 0 every round start; income =
   hits + `poweradd`; spend gated in routing (`power >= 500`) and spent with
   `powerAdd` (all runtime-proven in V09–V14).
5. Debug hotkeys (F3 fill meter) are injectable — useful for staging meter tests.

## What is deliberately NOT in the template

Crouch/air attacks (400s/600s), supers (3000+), recovery state — numbers and
command names reserved, `command != "holddown"` routing guard already in place.

## Hard requirements for every clone

1. Replace `_template.sff`/`.snd` with original art/audio (placeholder is
   Elecbyte KFM, CC-BY-NC, `prototype_only`), update `assets/LICENSE_MANIFEST.csv`.
2. Rename everything `_template` → `<char>` (checklist in template README §2).
3. Re-run `scripts/test.ps1` after renaming; re-run runtime probes after any
   routing/AI order change.

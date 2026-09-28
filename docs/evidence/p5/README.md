# P5 evidence

Raw output of the commands the P5 phase report cites. Nothing here is a screenshot:
every file is text captured from a command whose exact line is included, so any claim
in `docs/phase_reports/P5-character-asset-tooling.md` can be re-run.

| File | What it is |
| --- | --- |
| `baseline_test_before_p5.txt` | `pwsh -File scripts\test.ps1` on the untouched `main` (26/26 PASS) |
| `test_ps1_all_suites.txt` | the same entry point after the P5 changes (smoke 26/26 + tools 61/61) |
| `tool_tests.txt` | `tests/tools/run_tool_tests.ps1` (61 checks) |
| `tool_tests_full.txt` | the same suite with `-Full` (66 checks: all 282 sprites exported and verified, montage determinism) |
| `sffctl_three_characters.txt` | `sffctl inspect` on `_template` / `test_fighter_a` / `test_fighter_b`, plus `airtool inspect` of Fighter A's actions 200 and 210 |
| `p6_ready_run.txt` | the P6-ready end-to-end run: validate → inspect → export → inspect actions → validate → independent re-read of the PNGs → montage |
| `runtime_regression.txt` | `sync_game_content.ps1` + `tests\p4\run_matrix.ps1 -Only b_vs_a` after the `test_fighter_b.air` sprite fix, with the engine crash-log population before and after |

Two things are deliberately **not** committed:

- the exported sprite PNGs and the montage (`logs/p5/`, git-ignored): they come from the
  placeholder KFM container, which is `prototype_only` in `assets/LICENSE_MANIFEST.csv`.
  They must not look like production assets.
- the game's own screenshots and crash logs (`logs/`, `engine/ikemen-go/save/`).

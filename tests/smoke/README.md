# Smoke Tests

Phase-level smoke tests for KingOfFate.

These verify the minimum invariants the project depends on. They are deliberately simple —
no test framework, no fixtures — so they can always run, on any machine, with nothing but
PowerShell and the repository itself.

## Running

```powershell
pwsh -File scripts/test.ps1
```

Exit code:

```text
0   = PASS
!=0 = FAIL   (every failing check and its reason is printed)
```

## What is checked

| Group | Checks |
| --- | --- |
| **A** | the `engine/ikemen-go` submodule exists, `.gitmodules` points at the engine fork, and the submodule HEAD still matches the pinned baseline commit |
| **B** | the engine runtime directories exist (`data/`, `font/`, `external/`, `chars/`, `stages/`) |
| **C** | the engine has been built (`engine/ikemen-go/Ikemen_GO.exe`) and the binary size is plausible |
| **D** | the basic files needed to run a match exist (default motif, fight screen, a character, a stage) |
| **E** | the project scaffolding and documentation exist (README, CONTRIBUTING, docs, scripts, PR template) |
| **F** | *(opt-in, `-RuntimeTest`)* the engine launches, plays one automated round and exits cleanly |

## Optional runtime test

Group F is not part of the default run because it starts a real game process and therefore
needs a desktop session and a working GPU/GL stack.

```powershell
pwsh -File scripts/test.ps1 -RuntimeTest
```

It launches:

```text
Ikemen_GO.exe -p1 kfm -p2 kfm -s stage0 --rounds 1 --windowed --nosound --nomusic
```

and checks that the process starts, finishes the round and exits with code 0.

## Updating the pinned baseline

Group A asserts a specific engine commit. When the engine baseline is intentionally moved,
pass the new commit rather than weakening the check:

```powershell
pwsh -File tests/smoke/smoke.ps1 -ExpectedEngineCommit <new-commit>
```

The engine procedure is described in `CONTRIBUTING.md` under "Engine (IKEMEN GO) changes".

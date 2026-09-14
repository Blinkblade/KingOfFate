# Contributing to KingOfFate

KingOfFate is a small, open, collaborative project. The rules below exist to keep `main` always usable and to
make sure anyone (human or agent) can pick the project up by reading the repository alone.

---

## Branching model

```text
main
 └── <branch>
        └── PR
              └── review
                    └── main
```

- **`main` only holds verified, stable code.** It is the baseline for the next round of work.
- **Never develop a feature directly on `main`.** All new work starts from an up-to-date `main` in a branch.
- Always start a new branch from `main`, never from another feature branch that carries unrelated unmerged work.

### Branch names

| Type | Pattern | Example |
| --- | --- | --- |
| Feature | `feature/<name>` | `feature/p0-bootstrap`, `feature/p3-fighter-a-base` |
| Bug fix | `fix/<name>` | `fix/projectile-hitbox` |
| Documentation | `docs/<name>` | `docs/update-development-guide` |
| Tooling | `tool/<name>` | `tool/sff-export` |

Recommended flow:

```bash
git switch main
git pull origin main
git switch -c feature/<task>
```

---

## The iteration cycle

Every unit of work follows the same path:

```text
Inspect -> Plan -> Change -> Build -> Test -> Iteration Record -> Commit -> Push -> PR
```

A P0 "done" is only reached when **all** of these are true:

```text
Build PASS
Test PASS
Iteration Record DONE
Git Commit DONE
Push DONE
PR DONE
```

### Iteration records are mandatory

Every feature, bug fix, tool change, substantial configuration change or standalone PR **must** add at least one
record under `docs/iterations/`.

- File name: `YYYYMMDD-<topic>.md`
- One PR corresponds to at least one iteration record. A PR that clearly bundles several independent tasks may
  add several records.
- The record ships in the **same branch and the same PR** as the code it describes.
- Never delete old records. Records describe what was really implemented — do not write about work that did not
  happen, and never mark something `PASS` when it is unfinished (use `BLOCKED` and explain).

The fixed template is documented in [`docs/iterations/README.md`](docs/iterations/README.md).

---

## Commit messages

Plain, specific, English, one logical change per commit:

```text
feat: add base fighter movement
fix: correct projectile hitbox
tool: add SFF sprite exporter
test: add fighter smoke test
docs: update character development guide
chore: update IKEMEN GO submodule
build: add Windows engine build script
```

Phase-level milestones may use `phaseN:` prefixes, e.g. `phase1: complete KFM architecture study`.

Never use `update`, `fix stuff`, `test`, `final`, `final2`, `修改一下`.

---

## Pull requests

Push the branch and open a PR against `main`:

```bash
git push -u origin <branch>
```

Fill in [`the PR template`](.github/pull_request_template.md). Before merging, the following must be confirmed:

```text
Build PASS
Test PASS
Iteration Record DONE
Documentation Updated
```

`Squash and Merge` is the default merge strategy: it keeps the working history visible in the PR while leaving
`main` with one clean commit per logical change. A regular merge is acceptable for large infrastructure
changes where preserving individual commits has real value.

**Never force-push `main`.**

---

## Marking a Phase as complete

When a phase's final iteration lands, additionally update:

- `docs/development_status.md` — the phase status
- `docs/phase_reports/phase<NN>.md` — a phase summary

Do not create a phase report for every small change.

---

## Engine (IKEMEN GO) changes

The engine is a submodule and is pinned. Treat it as a separate project.

**Rule of precedence — always prefer staying outside the engine:**

```text
configuration
  -> character ZSS
  -> Lua
  -> external tooling
  -> IKEMEN GO source
```

Only modify the engine when a feature genuinely cannot be built on top of it.

When an engine change is unavoidable:

1. Work in the engine fork (`Blinkblade/Ikemen-GO`), **not** in this repository.
2. Branch off the integration baseline: `kingoffate/rc5` -> `engine/feature/<name>`.
3. Never develop KingOfFate-specific changes on `develop` (that branch tracks upstream).
4. Open a PR: `engine/feature/<name>` -> `kingoffate/rc5`.
5. Once merged, update this repository's submodule pointer on a dedicated branch:

```bash
git switch -c chore/update-engine-<name>
cd engine/ikemen-go
git fetch origin
git checkout <new-commit>
cd ../..
git add engine/ikemen-go
git commit -m "chore: update IKEMEN GO submodule to <new-commit>"
```

The submodule pointer must never drift to a new commit without an explicit, documented reason. Do not upgrade
IKEMEN or sync with upstream `develop` as a side effect of unrelated work — engine upgrades are their own
feature with their own regression testing.

---

## Assets

This repository is public. Every third-party asset committed here must be recorded in
`assets/LICENSE_MANIFEST.csv`.

If the license of an asset is unclear, mark it `prototype_only`. Assets marked `prototype_only` must never ship
in a release.

---

## For automated agents

An agent starting work must reconstruct state from the repository, not from conversation memory:

1. Read `README.md`
2. Read `docs/development_status.md`
3. Read the current phase report if one exists
4. Read the most relevant recent records in `docs/iterations/`
5. Run `git status`, `git branch --show-current`, `git log -5 --oneline`, `git submodule status`
6. Run the smoke test (`scripts/test.ps1`)
7. Only then start changing anything

When a step fails, do not switch to a different architecture or tech stack. Follow:

```text
Read Error -> Reproduce -> Locate -> Minimal Fix -> Run the Same Test Again
```

If a step needs administrator rights or a human action, record it as `BLOCKED` with the exact action required.
Never fake a success.

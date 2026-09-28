# KingOfFate (KOF)

A 2D fighting game project built on top of the **[IKEMEN GO](https://github.com/ikemen-engine/Ikemen-GO)** engine.

KingOfFate targets a classic 4-button KOF-style fighting experience (light punch / light kick / heavy punch /
heavy kick, throws, specials, supers) and focuses on **game content, character design, combat rules, CPU AI,
tooling and testing** rather than re-implementing a fighting-game engine.

---

## Status

**Current phase: `P5 — Character Asset Tooling` — ✅ PASS · next: `P6 — First Final-Art Character`**

P1 validated the character execution chain by measurement, P2 turned it into a cloneable
4-button template (`game/chars/_template/`), and P3 cloned that template into the project's
first independent, playable fighter: `game/chars/test_fighter_a/`. P4 then cloned the same
template into a **deliberately different** fighter — `game/chars/test_fighter_b/`, a Zoner
with a native projectile, a long-reach poke and two tiers of anti-air — proving the
architecture carries more than one fighting style. Both fighters are complete, playable and
validated in real matches; the engine baseline is still untouched.

P5 added the character **asset tooling** that P6 needs: read an SFF, export its sprites,
read and validate an animation table, and check whether a character directory is complete
enough to reach Runtime. Everything is read-only and dependency-free, and the tools found a
real defect in existing content on their first run.

See [`docs/development_status.md`](docs/development_status.md) for the authoritative, always-up-to-date phase
status, [`docs/P5-summary.md`](docs/P5-summary.md) for the current handoff notes
([`docs/P4-summary.md`](docs/P4-summary.md), [`docs/P3-summary.md`](docs/P3-summary.md), [`docs/P2-summary.md`](docs/P2-summary.md), [`docs/P1-summary.md`](docs/P1-summary.md) and
[`docs/P0-summary.md`](docs/P0-summary.md) for the earlier ones), [`docs/character_asset_tooling.md`](docs/character_asset_tooling.md)
for the asset tools, [`docs/ikemen_character_architecture.md`](docs/ikemen_character_architecture.md)
for how a character is built, [`docs/phase_reports/`](docs/phase_reports/) for per-phase summaries, and
[`docs/iterations/`](docs/iterations/) for the engineering log of how the project got here.

---

## Engine & repository model

KingOfFate does **not** fork or copy the fighting engine into this repository. The engine is pinned as a
Git Submodule and must stay on the project's integration branch.

| Item | Value |
| --- | --- |
| Engine | IKEMEN GO |
| Engine baseline | `v1.0.0-rc.5` |
| Engine commit | `ba516193bba83f13f0b63ddce314d8719793931f` |
| Engine fork | `Blinkblade/Ikemen-GO` (`origin`) |
| Engine upstream | `ikemen-engine/Ikemen-GO` (`upstream`) |
| Integration branch | `kingoffate/rc5` |
| Submodule path | `engine/ikemen-go` |

The engine baseline is intentionally frozen. Do not auto-sync with upstream `develop`.

---

## Getting the source

Clone with submodules in one step:

```bash
git clone --recurse-submodules https://github.com/Blinkblade/KingOfFate.git
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive
```

Verify the engine baseline is correct:

```bash
git submodule status
#  ba516193bba83f13f0b63ddce314d8719793931f engine/ikemen-go (v1.0.0-rc.5)
```

---

## Building

> Prerequisites and the exact dependency list come from the engine's own
> [`engine/ikemen-go/BUILDING.md`](engine/ikemen-go/BUILDING.md). That file is the source of truth for this
> pinned RC5 baseline — read it before changing any build step.

On Windows the toolchain is **MSYS2 / MINGW64** (Go, MinGW GCC, `pkg-config`, NASM, SDL2, libxmp, FFmpeg).

Build through the project entry point (works from any working directory):

```powershell
pwsh -File scripts/build_engine.ps1
```

On a machine that needs a proxy for large downloads (and where `proxy.golang.org` / the FFmpeg
sources are not directly reachable), pass it explicitly - nothing is hardcoded:

```powershell
pwsh -File scripts/build_engine.ps1 -BuildFfmpeg no -Proxy http://127.0.0.1:7897 -GoProxy https://goproxy.cn,direct
```

- `-BuildFfmpeg no` uses the MSYS2 FFmpeg development packages. This is the option documented in
  `engine/ikemen-go/BUILDING.md` under "Use system FFmpeg instead (optional)".
- `-Proxy` / `-GoProxy` default to `$env:HTTPS_PROXY` / `$env:GOPROXY` when set.

Or invoke the engine build script directly from an MSYS2 MINGW64 shell:

```bash
cd engine/ikemen-go
./build/build.sh Win64
```

The produced executable is:

```text
engine/ikemen-go/Ikemen_GO.exe
```

Build logs are written to `logs/build/<YYYYMMDD>/`.

---

## Running

```powershell
pwsh -File scripts/run_game.ps1
```

The run script locates the built `Ikemen_GO.exe`, checks the runtime assets, resolves the runtime
DLL search path, and launches the game. It never builds for you — if the executable is missing it
will tell you to run `scripts/build_engine.ps1` first.

Run `-CheckOnly` for a preflight check without launching:

```powershell
pwsh -File scripts/run_game.ps1 -CheckOnly
```

Full launch documentation — script parameters, direct-executable launch, the engine's command line
arguments and troubleshooting — is in [`docs/running.md`](docs/running.md).

Once the game is running: menu navigation, default keyboard/gamepad bindings, how to rebind keys
and the full move list (with the files that define it) are documented in
[`docs/controls.md`](docs/controls.md).

---

## Testing

```powershell
pwsh -File scripts/test.ps1
```

`scripts/test.ps1` runs the project's test suites and returns:

```text
0   = PASS
!=0 = FAIL   (the failing check and the reason are printed)
```

| Suite | What it covers |
| --- | --- |
| `smoke` (`tests/smoke/`) | the engine submodule and its pinned baseline, the runtime directories, the build artifact, the basic files needed to run a match, and the project scaffolding |
| `tools` (`tests/tools/`) | the P5 character asset tools: every command, every exit code, the fixture set, and a pixel-accurate check of exported sprites |

Options:

```powershell
pwsh -File scripts/test.ps1 -Suite smoke     # only the project invariants
pwsh -File scripts/test.ps1 -Suite tools     # only the asset tools
pwsh -File scripts/test.ps1 -Full            # also export all 282 sprites and render a montage
pwsh -File scripts/test.ps1 -RuntimeTest     # smoke + a real engine launch check
```

The asset tools need Python 3.8+ and **no third-party packages**; see
[`docs/character_asset_tooling.md`](docs/character_asset_tooling.md).

---

## Repository layout

```text
KingOfFate/
├── .github/              GitHub collaboration config (PR template)
├── engine/
│   └── ikemen-go/        IKEMEN GO submodule (pinned, do not repoint)
├── game/
│   ├── chars/            Characters
│   ├── stages/           Stages
│   ├── data/             Game system data / screenpack defs
│   ├── font/             Fonts
│   ├── sound/            Sound & music
│   └── external/         Engine external assets (shaders, mods, scripts)
├── assets/               Source / reference / generated art, VFX and audio
├── design/               Game & combat design docs, per-character specs
│   └── characters/
│       ├── _template/    Base fighter skeleton for P2 (copy, do not run)
│       ├── test_fighter_a/  Frame data for the first independent fighter (P3)
│       └── test_fighter_b/  Frame data for the second fighter: the Zoner (P4)
├── tools/                Character / asset tooling (P5)
├── scripts/              PowerShell build, run and test entry points
├── tests/
│   ├── characters/       Character tests
│   ├── tools/            Asset tool tests (P5)
│   ├── fixtures/         Generated asset fixtures and the decoder checks (P5)
│   ├── p1/               Character behaviour observation tooling (P1)
│   ├── p2/               Multi-key phase injection harness (P2)
│   ├── p3/               Unattended match + engine crash-log watch (P3)
│   ├── p4/               Match matrix + scripted dummy fixtures (P4)
│   └── smoke/            Phase 0 smoke tests
├── docs/
│   ├── environment.md          Verified local build environment record
│   ├── development_status.md   Current phase status
│   ├── character_asset_tooling.md  Asset tool guide (P5)
│   ├── evidence/               Raw command output cited by the phase reports
│   ├── howto/                  Step-by-step procedures for specific checks
│   ├── iterations/             Engineering log (one record per PR)
│   └── phase_reports/          Per-phase summaries
├── logs/                 Local build / runtime logs (mostly gitignored)
├── dist/                 Assembled runtime / release output (gitignored)
├── CONTRIBUTING.md       Contribution & branching rules
└── README.md
```

---

## Contributing

Read [`CONTRIBUTING.md`](CONTRIBUTING.md). In short:

- `main` only ever holds verified, stable code.
- All work happens on a branch (`feature/*`, `fix/*`, `docs/*`, `tool/*`).
- Every PR needs Build PASS, Test PASS and an **Iteration Record** in `docs/iterations/`.

---

## License

KingOfFate's own code and assets are licensed independently and are **not** automatically covered by the
engine's license. The IKEMEN GO submodule remains under its own MIT license; bundled screenpack assets keep
their own Creative Commons terms. Third-party assets entering this repository must be recorded in
`assets/LICENSE_MANIFEST.csv`.

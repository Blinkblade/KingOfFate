# Environment

Verified build environment for KingOfFate on the reference development machine.
Everything below was **actually executed and observed**, not copied from documentation.

Machine-specific notes describe where things were tested locally. **No project script depends on a
developer-specific absolute path** - scripts discover what they need at runtime.

Verified on: 2026-09-12 (session started 2026-09-11)

---

## Host

| Item | Value |
| --- | --- |
| OS | Windows 11 专业版 (build 10.0.26200.9168) |
| Arch | x86_64 (Windows x64) |
| Shell used for the build | PowerShell 5.1 driving MSYS2 MINGW64 bash |
| Local proxy | `http://127.0.0.1:7897` (required for large downloads on this network) |

---

## Toolchain (all verified by `scripts/check_build_env.sh`)

| Tool | Version |
| --- | --- |
| Git (host) | 2.45.1.windows.1 |
| Git (MSYS2) | 2.55.0 |
| MSYS2 | base 2026-09-11 snapshot, `msys2-runtime` 3.6.10-3 |
| GCC / G++ | 16.2.0 (`Rev3, Built by MSYS2 project`) |
| make | GNU Make 4.4.1 |
| NASM | 3.02 |
| yasm | 1.3.0 |
| pkg-config | 3.0.7 |
| SDL2 | 2.32.10 |
| libxmp | 4.7.2 |
| Go | go1.27.1 windows/amd64 |
| Go GOROOT | `D:/msys2-root/mingw64/lib/go` (resolved with `cygpath -m` at build time) |

FFmpeg development packages (MSYS2 `mingw-w64-x86_64-ffmpeg`):

| Module | Version |
| --- | --- |
| libavformat | 63.1.101 |
| libavcodec | 63.1.101 |
| libavutil | 61.1.101 |
| libswscale | 10.1.101 |
| libswresample | 7.1.101 |
| libavfilter | 12.1.101 |

---

## Engine

| Item | Value |
| --- | --- |
| Baseline tag | `v1.0.0-rc.5` |
| Baseline commit | `ba516193bba83f13f0b63ddce314d8719793931f` |
| Fork | `Blinkblade/Ikemen-GO` (`origin`), upstream `ikemen-engine/Ikemen-GO` |
| Integration branch | `kingoffate/rc5` |
| Submodule path | `engine/ikemen-go` |

Runtime assets are unpacked next to the executable (this is what `engine/ikemen-go/BUILDING.md`
prescribes). They come from the official screenpack:

| Item | Value |
| --- | --- |
| Source | `https://github.com/ikemen-engine/Ikemen-GO-Screenpack` (branch `master`) |
| Provides | `chars/` (kfm, kfm720, kfm_zaxis, **kfm_zss**), `stages/`, `data/` (incl. `data/ikemen1/system.def`), `font/`, `sound/`, `video/` |
| License | CC-BY 3 (per the screenpack repository); copied in as `ScreenpackLicense.txt` |

These files are **not** committed: they land inside the engine submodule, whose own `.gitignore`
already excludes `chars/*`, `stages/*`, `sound/*`, `data/*`, `font/*` and `video/*`.
The submodule therefore stays clean (`git status` empty) while remaining runnable.

---

## Environment quirks found on this machine

These are recorded because each one cost real debugging time and each is worked around inside the
project scripts rather than by patching the engine.

1. **`/bin` and `/lib` were missing.**
   Extracting the MSYS2 `.sfx.exe` self-extracting archive does not recreate MSYS2's root
   symlinks. They were recreated as NTFS directory junctions (no administrator rights needed):
   `D:\msys64\bin -> D:\msys64\usr\bin`, `D:\msys64\lib -> D:\msys64\usr\lib`.

2. **The pacman keyring could not be initialised.**
   The `gpg` 2.4.9 build shipped with this MSYS2 snapshot loops forever on
   `gpg: removing stale lockfile (created by <pid>)` on this machine (GnuPG's Windows
   liveness check does not cope with MSYS pids). `pacman-key --init` never returns.
   GnuPG 2.4.5 shipped with Git for Windows works, but pacman cannot be pointed at it.
   Workaround: `/etc/pacman.conf` sets `SigLevel = Never` and `/etc/pacman.d/gnupg` was left
   as an empty directory so the `/etc/profile` post-install hook stops re-running keyring
   initialisation. Packages were still fetched over HTTPS from the mirror.
   **Revisit this once the MSYS2 gpg build is fixed and restore `SigLevel = Required`.**

3. **Large downloads stall without a proxy.**
   `pacman` uses libcurl, which does not read the Windows system proxy. Downloads stalled at
   0 bytes until the proxy was passed explicitly (`-Proxy` on the build script).

4. **MSYS argument path conversion was disabled.**
   The shell had `MSYS_NO_PATHCONV=1` and `MSYS2_ARG_CONV_EXCL=*` set, which switches off the
   POSIX -> Windows translation MSYS normally performs when launching native tools. Without it
   `gcc`, `gendef` and `dlltool` receive unusable POSIX paths and the engine build fails with
   `cc1plus.exe: fatal error: ... No such file or directory`. `scripts/build_engine.ps1` clears
   both variables before building. On a machine where they are unset this is a no-op.

5. **Build temporaries must live inside the project.**
   `scripts/build_engine.ps1` points `TMPDIR`/`TMP`/`TEMP`/`GOTMPDIR` at the gitignored
   `<project>/.tmp` directory.

6. **GnuPG keyring deletion / long builds.**
   Nothing in the project scripts performs a destructive filesystem operation, and the build log
   is written directly by the shell rather than piped through PowerShell (a full-output pipe can
   apply back-pressure and stall long native builds).

---

## Build

Documented command (the engine's own, unmodified build flow):

```bash
cd engine/ikemen-go
./build/build.sh Win64
```

Project entry point used in this environment:

```powershell
pwsh -File scripts/build_engine.ps1 -BuildFfmpeg no -Proxy http://127.0.0.1:7897 -GoProxy https://goproxy.cn,direct
```

Notes on the options:

- `-BuildFfmpeg no` uses the MSYS2 FFmpeg development packages instead of compiling a local
  FFmpeg. This is the option documented in `engine/ikemen-go/BUILDING.md` under
  "Use system FFmpeg instead (optional)". A local FFmpeg build was attempted first
  (`BUILD_FFMPEG=auto`, the CI default); it compiled libvpx and FFmpeg successfully but
  `make install` failed in the `STRIP` step and produced 0-byte DLLs, so the documented
  system-FFmpeg option was used instead. The trade-off is that WebM alpha video may not use
  the libvpx decoder (the engine build script prints a warning about this); it does not affect
  gameplay.
- `-Proxy` / `-GoProxy` are optional and default to the corresponding environment variables.
  Nothing is hardcoded.
- Build logs: `logs/build/<YYYYMMDD>/build-engine.log`.

### Result on this machine

**PASS.** The full build completes:

```text
==> Build successful (Windows)
    Binary: ./Ikemen_GO.exe
```

`engine/ikemen-go/Ikemen_GO.exe` — 14.94 MB.

A note on the build temp directory: an earlier attempt failed inside cgo with
`cc1.exe: fatal error: cannot open '<tmp>\ccXXXXXXXX.s' for writing: Permission denied`, which
turned out to be stale leftovers in the temp directory from an interrupted concurrent compile.
Clearing `<project>/.tmp` resolved it. If that error ever comes back, empty `.tmp` and re-run.
Everything else the build needs is handled by the script.

Building FFmpeg from source (`BUILD_FFMPEG=auto`, the CI default) is *not* used here: libvpx and
FFmpeg do compile, but their `make install` `STRIP` step produced 0-byte DLLs on this machine.
The documented system-FFmpeg option is used instead.

---

## Run

```powershell
pwsh -File scripts/run_game.ps1
```

Verified result: process starts, window title `Ikemen GO`, `Responding = True`,
working set ~320–380 MB.

Checks the executable and the runtime assets, resolves the runtime DLL search path, then launches
`Ikemen_GO.exe` from `engine/ikemen-go/`. It never builds.

### Runtime DLL search path

Because the build uses the system FFmpeg, `build.sh` does not bundle the runtime DLLs and
`engine/ikemen-go/lib/` stays empty. The executable therefore needs the MSYS2 `mingw64\bin`
directory at run time. `run_game.ps1` detects it (via `-Msys2Root` → `$env:MSYS2_ROOT` →
`$env:MSYS2_HOME` → the usual install locations) and prepends it to the PATH of the game process
only. If DLLs are ever bundled next to the executable, this step is skipped automatically.

---

## Test

```powershell
pwsh -File scripts/test.ps1              # static smoke test
pwsh -File scripts/test.ps1 -RuntimeTest # also launches the engine and checks start-up health
```

Verified result: `29/29 checks passed`, exit code `0`.

Exit code `0` = PASS, non-zero = FAIL.

The runtime group launches:

```text
Ikemen_GO.exe -p1 kfm -p2 kfm -s stage0 -windowed -nosound -nomusic
```

and checks that the process starts, creates a game window and stays alive and responsive, then
terminates it. The engine's `-rounds <num>` option is documented in its help text but is never
read by the engine in this RC5 baseline, so an automatic quit cannot be used for unattended runs.

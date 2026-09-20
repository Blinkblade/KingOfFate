#Requires -Version 5.1
<#
.SYNOPSIS
    Builds the pinned IKEMEN GO engine for Windows x64.

.DESCRIPTION
    Single, location-independent entry point for the KingOfFate engine build.

    The script:
      1. derives the project root from its own path (never from the current directory),
      2. never contains developer-specific absolute paths,
      3. verifies the engine submodule and the MSYS2/MINGW64 toolchain are present,
      4. runs the engine's own, unmodified build flow (build/build.sh Win64),
      5. writes the full log to logs/build/<yyyyMMdd>/,
      6. exits non-zero on any failure.

    It deliberately does NOT run git pull / reset / checkout / clean, so building can
    never change the source Git state.

.PARAMETER Msys2Root
    Path to the MSYS2 installation root (the folder containing usr\bin\bash.exe).
    Defaults to $env:MSYS2_ROOT, then to the conventional locations C:\msys64 / D:\msys64.

.PARAMETER BuildFfmpeg
    Passed through to the engine build as BUILD_FFMPEG.
      auto (default) - build a minimal local FFmpeg (matches CI; preserves WebM alpha).
                       NOTE: when no local alpha-capable FFmpeg exists yet, this mode has to
                       clone the FFmpeg sources from github.com. If that source is not
                       reachable the script degrades to 'no' and says so loudly instead of
                       failing the whole engine build.
      no             - use the system/MSYS2 FFmpeg packages (works fully offline)
      yes            - force a local FFmpeg build (never degrades; fails if the network is down)

.PARAMETER NoLog
    Do not write a build log file.

.PARAMETER Proxy
    Optional HTTP proxy for the build (for example http://127.0.0.1:7897).
    Needed when the local network requires a proxy for git/curl downloads - the engine
    build may fetch FFmpeg/libvpx sources on a first run.
    If omitted, $env:HTTPS_PROXY and then $env:MSYS2_PROXY are used when set.
    Nothing is hardcoded; with no proxy the build simply runs direct.

.PARAMETER GoProxy
    GOPROXY for the Go module download, for example https://goproxy.cn,direct.
    Defaults to $env:GOPROXY when set, otherwise Go's own default.
    Useful where proxy.golang.org is not reachable.

.PARAMETER GoSumDb
    GOSUMDB value. Defaults to $env:GOSUMDB when set, otherwise Go's own default.
    Some networks need 'off' or a regional checksum database.

.EXAMPLE
    pwsh -File scripts/build_engine.ps1
    pwsh -File scripts/build_engine.ps1 -BuildFfmpeg no
    pwsh -File scripts/build_engine.ps1 -Msys2Root D:\msys64
    pwsh -File scripts/build_engine.ps1 -Proxy http://127.0.0.1:7897 -GoProxy https://goproxy.cn,direct
#>
[CmdletBinding()]
param(
    [string]$Msys2Root,
    [ValidateSet('auto', 'yes', 'no')]
    [string]$BuildFfmpeg = 'auto',
    [switch]$NoLog,
    [string]$Proxy,
    [string]$GoProxy,
    [string]$GoSumDb
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Locate the project, independent of the current working directory.
# ---------------------------------------------------------------------------
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..')).ProviderPath
$EngineDir = Join-Path $RepoRoot 'engine\ikemen-go'
$EngineBuildScript = Join-Path $EngineDir 'build\build.sh'
$Executable = Join-Path $EngineDir 'Ikemen_GO.exe'

$BuildTarget = 'Win64'
$ExecutableName = 'Ikemen_GO.exe'

function Write-Step([string]$Text) { Write-Host "[build] $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text) { Write-Host "[ ok  ] $Text" -ForegroundColor Green }
function Write-Warn2([string]$Text) { Write-Host "[warn ] $Text" -ForegroundColor Yellow }
function Write-Err([string]$Text) { Write-Host "[fail] $Text" -ForegroundColor Red }

function ConvertTo-MsysPath {
    param([Parameter(Mandatory)][string]$Path)
    $p = $Path -replace '\\', '/'
    if ($p -match '^([A-Za-z]):/(.*)$') {
        return '/' + $Matches[1].ToLowerInvariant() + '/' + $Matches[2]
    }
    return $p
}

function Resolve-Msys2Root {
    param([string]$Explicit)

    $candidates = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($Explicit)) { $candidates.Add($Explicit) }
    if (-not [string]::IsNullOrWhiteSpace($env:MSYS2_ROOT)) { $candidates.Add($env:MSYS2_ROOT) }
    if (-not [string]::IsNullOrWhiteSpace($env:MSYS2_HOME)) { $candidates.Add($env:MSYS2_HOME) }
    # Conventional install locations - searched, not hardcoded as requirements.
    $candidates.Add('C:\msys64')
    $candidates.Add('D:\msys64')

    foreach ($c in $candidates) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        $bash = Join-Path $c 'usr\bin\bash.exe'
        if (Test-Path -LiteralPath $bash) {
            return (Resolve-Path -LiteralPath $c).ProviderPath
        }
    }
    return $null
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
Write-Step "Project root : $RepoRoot"

if (-not (Test-Path -LiteralPath $EngineDir)) {
    Write-Err "engine submodule not found: $EngineDir"
    Write-Host "       Run: git submodule update --init --recursive" -ForegroundColor Yellow
    exit 2
}

if (-not (Test-Path -LiteralPath $EngineBuildScript)) {
    Write-Err "engine build script not found: $EngineBuildScript"
    Write-Host "       The engine submodule looks incomplete. Run: git submodule update --init --recursive" -ForegroundColor Yellow
    exit 2
}

$resolvedMsys2 = Resolve-Msys2Root -Explicit $Msys2Root
if (-not $resolvedMsys2) {
    Write-Err 'MSYS2 installation not found.'
    Write-Host '       Install MSYS2 (https://www.msys2.org) and pass it explicitly if it is in a non-standard place:' -ForegroundColor Yellow
    Write-Host '           pwsh -File scripts/build_engine.ps1 -Msys2Root <path\to\msys2>' -ForegroundColor Yellow
    Write-Host '       See engine/ikemen-go/BUILDING.md for the dependency list.' -ForegroundColor Yellow
    exit 2
}

$bashExe = Join-Path $resolvedMsys2 'usr\bin\bash.exe'
Write-Ok "MSYS2 root   : $resolvedMsys2"

# Exit code reported by Get-Msys2BashOutput (StrictMode needs it declared up front).
$script:lastMsysRc = 0

# Two environment overrides can be present in this shell and they disable the
# POSIX -> Windows argument translation that MSYS performs when it launches native
# MinGW tools (gcc, gendef, dlltool). With conversion disabled the engine build fails
# with errors such as "cc1plus.exe: fatal error: /c/Users/...: No such file or
# directory" or "dlltool.exe: Can't open def file". Clear them so the build behaves
# exactly as it does in CI. On a machine where they are not set this is a no-op.
$convPrefix = 'unset MSYS_NO_PATHCONV; unset MSYS2_ARG_CONV_EXCL; export MSYS2_ARG_CONV_EXCL=; '

# The Go shipped by MSYS2 is a "trimmed" build, so GOROOT has to be set explicitly.
# go.exe is a native Windows binary and does not understand the MSYS form of the path,
# while MSYS rewrites Windows paths coming from the outside back into POSIX form.
# The only reliable route is to derive the Windows form from inside the shell with
# cygpath - so it is resolved per-machine and never hardcoded here.
$gorootPrefix = 'export GOROOT=$(cygpath -m /mingw64/lib/go); '

Write-Ok 'Shell prefix : clears MSYS path-conversion overrides; GOROOT via cygpath'
Write-Host ''

# Proxy for git/curl used by the engine build (optional, never hardcoded).
$proxyUrl = $Proxy
if ([string]::IsNullOrWhiteSpace($proxyUrl)) { $proxyUrl = $env:HTTPS_PROXY }
if ([string]::IsNullOrWhiteSpace($proxyUrl)) { $proxyUrl = $env:MSYS2_PROXY }
$proxyPrefix = ''
if (-not [string]::IsNullOrWhiteSpace($proxyUrl)) {
    $proxyPrefix = "export http_proxy='$proxyUrl'; export https_proxy='$proxyUrl'; export all_proxy='$proxyUrl'; export no_proxy='localhost,127.0.0.1'; "
    Write-Ok "Proxy        : $proxyUrl"
}
else {
    Write-Host '[info ] Proxy        : none (direct connection)' -ForegroundColor DarkGray
}
Write-Host ''

# Go module download configuration (optional, never hardcoded).
$goProxyUrl = $GoProxy
if ([string]::IsNullOrWhiteSpace($goProxyUrl)) { $goProxyUrl = $env:GOPROXY }
$goSumDbValue = $GoSumDb
if ([string]::IsNullOrWhiteSpace($goSumDbValue)) { $goSumDbValue = $env:GOSUMDB }

$goEnvPrefix = ''
if (-not [string]::IsNullOrWhiteSpace($goProxyUrl)) {
    $goEnvPrefix += "export GOPROXY=$goProxyUrl; "
    Write-Ok "GOPROXY      : $goProxyUrl"
}
if (-not [string]::IsNullOrWhiteSpace($goSumDbValue)) {
    $goEnvPrefix += "export GOSUMDB=$goSumDbValue; "
    Write-Ok "GOSUMDB      : $goSumDbValue"
}
if ([string]::IsNullOrWhiteSpace($goEnvPrefix)) {
    Write-Host '[info ] GOPROXY      : Go default' -ForegroundColor DarkGray
}
Write-Host ''

# Keep compiler/build temporaries inside the project. Some environments deny native
# compilers write access to the system temp directory, which shows up as
# "cc1.exe: fatal error: cannot open '<tmp>\....s' for writing: Permission denied".
# The directory is created here and is gitignored.
$tmpDir = Join-Path $RepoRoot '.tmp'
if (-not (Test-Path -LiteralPath $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null }
$tmpDirMsys = ConvertTo-MsysPath $tmpDir
$tmpPrefix = "export TMPDIR='$tmpDirMsys'; export TMP='$tmpDirMsys'; export TEMP='$tmpDirMsys'; export GOTMPDIR='$tmpDirMsys'; "
Write-Ok "Build temp   : $tmpDir"
Write-Host ''

$shellPrefix = $convPrefix + $gorootPrefix + $goEnvPrefix + $tmpPrefix

function Invoke-Msys2Bash {
    <#
      Runs a command inside an MSYS2 MINGW64 login shell with MSYSTEM and GOROOT set,
      restoring the caller's environment afterwards. Returns the shell exit code.
    #>
    param(
        [Parameter(Mandatory)][string]$Command,
        [string]$LogFile
    )
    $prevMsystem = $env:MSYSTEM
    # Native tools legitimately write to stderr; do not let that abort the script.
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $env:MSYSTEM = 'MINGW64'
        if ($LogFile) {
            # Redirect inside the shell rather than piping the (very large) build output
            # through PowerShell. Piping can apply back-pressure to the native process
            # and stall long builds.
            $logMsys = ConvertTo-MsysPath $LogFile
            & $bashExe -l -c ($shellPrefix + "( $Command ) > '$logMsys' 2>&1")
            $script:lastMsysRc = $LASTEXITCODE
            if (Test-Path -LiteralPath $LogFile) {
                Write-Host ''
                Get-Content -LiteralPath $LogFile -Tail 15 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $_" }
                Write-Host ''
            }
        }
        else {
            & $bashExe -l -c ($shellPrefix + $Command) 2>&1
            $script:lastMsysRc = $LASTEXITCODE
        }
    }
    finally {
        $ErrorActionPreference = $prevEap
        if ($null -eq $prevMsystem) { Remove-Item Env:\MSYSTEM -ErrorAction SilentlyContinue } else { $env:MSYSTEM = $prevMsystem }
    }
}

function Get-Msys2BashOutput {
    <# Runs a command inside an MSYS2 MINGW64 login shell and returns its output lines. #>
    param([Parameter(Mandatory)][string]$Command)
    $prevMsystem = $env:MSYSTEM
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $env:MSYSTEM = 'MINGW64'
        $out = & $bashExe -l -c ($shellPrefix + $Command) 2>&1
        $script:lastMsysRc = $LASTEXITCODE
        return $out
    }
    finally {
        $ErrorActionPreference = $prevEap
        if ($null -eq $prevMsystem) { Remove-Item Env:\MSYSTEM -ErrorAction SilentlyContinue } else { $env:MSYSTEM = $prevMsystem }
    }
}

# ---------------------------------------------------------------------------
# Build environment check (inside MSYS2/MINGW64)
# ---------------------------------------------------------------------------
Write-Step 'Checking MINGW64 build environment'

$checkScript = Join-Path $RepoRoot 'scripts\check_build_env.sh'
if (-not (Test-Path -LiteralPath $checkScript)) {
    Write-Err "build environment check script not found: $checkScript"
    exit 2
}
$checkScriptMsys = ConvertTo-MsysPath $checkScript
$preflightOut = Get-Msys2BashOutput -Command "bash '$checkScriptMsys'"
$preflightRc = $script:lastMsysRc

if ($preflightRc -ne 0) {
    Write-Err 'The MINGW64 build environment is incomplete.'
    $preflightOut | ForEach-Object { Write-Host "       $_" -ForegroundColor Yellow }
    Write-Host '' -ForegroundColor Yellow
    Write-Host '       Install the dependencies documented in engine/ikemen-go/BUILDING.md:' -ForegroundColor Yellow
    Write-Host '         pacman -Syu --noconfirm' -ForegroundColor Yellow
    Write-Host '         pacman -S --noconfirm git make diffutils mingw-w64-x86_64-pkg-config \' -ForegroundColor Yellow
    Write-Host '           mingw-w64-x86_64-go mingw-w64-x86_64-toolchain \' -ForegroundColor Yellow
    Write-Host '           mingw-w64-x86_64-nasm mingw-w64-x86_64-yasm \' -ForegroundColor Yellow
    Write-Host '           mingw-w64-x86_64-tools-git mingw-w64-x86_64-libxmp \' -ForegroundColor Yellow
    Write-Host '           mingw-w64-x86_64-SDL2' -ForegroundColor Yellow
    exit 3
}

$preflightOut | ForEach-Object { Write-Host "       $_" }
Write-Ok 'MINGW64 build environment looks good'

# ---------------------------------------------------------------------------
# Log setup
# ---------------------------------------------------------------------------
$logFile = $null
if (-not $NoLog) {
    $stamp = Get-Date -Format 'yyyyMMdd'
    $logDir = Join-Path $RepoRoot ("logs\build\{0}" -f $stamp)
    if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $logFile = Join-Path $logDir 'build-engine.log'
    # Tee-Object overwrites the file; do not delete it first so the script never
    # performs a destructive filesystem operation.
    Write-Ok "Build log    : $logFile"
}

# ---------------------------------------------------------------------------
# FFmpeg strategy
#
# BUILD_FFMPEG=auto (the engine default, and what CI uses) builds a libvpx-only
# local FFmpeg so WebM alpha keeps working. build.sh only skips that build when
# BOTH of these already exist:
#     build/ffmpeg/lib/pkgconfig/libavcodec.pc
#     build/ffmpeg-src/config_components.h   (with CONFIG_LIBVPX_VP{8,9}_DECODER 1)
# Otherwise it does  rm -rf build/ffmpeg-src  and re-clones release/7.1 from
# github.com. On a machine whose proxy is not running, that clone dies with
#
#     error: RPC failed; curl 56 Recv failure: Software caused connection abort
#     fatal: early EOF
#     fatal: fetch-pack: invalid index-pack output
#
# and build.sh exits 1 - so "pwsh -File scripts/build_engine.ps1" fails with
# exit code 1 even though nothing is wrong with the engine code. That is what
# happened on 2026-09-19 (see logs/build/20260919/build-engine.log); the
# 2026-09-17 run used BUILD_FFMPEG=no and passed.
#
# Decide the strategy up front: probe the FFmpeg source with a cheap
# ls-remote (a few KB) rather than discovering the failure after a long build.
# Only 'auto' degrades; 'yes' keeps the old behaviour on purpose.
# ---------------------------------------------------------------------------
$ffmpegPrefixPc = Join-Path $EngineDir 'build\ffmpeg\lib\pkgconfig\libavcodec.pc'
$ffmpegSrcCfg   = Join-Path $EngineDir 'build\ffmpeg-src\config_components.h'

function Test-LocalAlphaFfmpeg {
    if (-not ((Test-Path -LiteralPath $ffmpegPrefixPc) -and (Test-Path -LiteralPath $ffmpegSrcCfg))) {
        return $false
    }
    return [bool](Select-String -LiteralPath $ffmpegSrcCfg -SimpleMatch -Quiet -Pattern 'CONFIG_LIBVPX_VP8_DECODER 1')
}

function Test-FfmpegSourceReachable {
    # 25 s ceiling; timeout returns 124, a missing binary returns 127 - both != 0.
    $null = Get-Msys2BashOutput -Command 'timeout 25 git ls-remote --exit-code --heads https://github.com/FFmpeg/FFmpeg.git release/7.1 >/dev/null 2>&1'
    return ($script:lastMsysRc -eq 0)
}

$ffmpegDegraded = $false
if ($BuildFfmpeg -eq 'auto') {
    if (Test-LocalAlphaFfmpeg) {
        Write-Ok 'FFmpeg       : local alpha-capable build already present (engine skips the rebuild)'
    }
    elseif (Test-FfmpegSourceReachable) {
        Write-Warn2 'FFmpeg       : no local alpha-capable build yet - the engine will clone + build FFmpeg (slow)'
    }
    else {
        $BuildFfmpeg = 'no'
        $ffmpegDegraded = $true
        Write-Warn2 'FFmpeg       : github.com is not reachable -> degrading to system FFmpeg (BUILD_FFMPEG=no)'
        Write-Host  '               This keeps the engine build working offline. WebM alpha may fall back to'
        Write-Host  '               the native VP8/VP9 decoder; re-run with -BuildFfmpeg yes once the proxy is up.'
    }
}
else {
    Write-Ok "FFmpeg       : BUILD_FFMPEG=$BuildFfmpeg (requested explicitly, no auto-degradation)"
}
Write-Host ''

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
$engineMsysPath = ConvertTo-MsysPath $EngineDir

# Timestamp of THIS run - used at the end to prove the binary was really rebuilt.
$buildStart = Get-Date

function Invoke-EngineBuild {
    param([Parameter(Mandatory)][string]$FfmpegMode)
    $cmd = "${proxyPrefix}cd '$engineMsysPath' && export CI=1 && export BUILD_FFMPEG=$FfmpegMode && export APP_VERSION=kingoffate-rc5 && ./build/build.sh $BuildTarget"
    Write-Step "Running: ./build/build.sh $BuildTarget   (BUILD_FFMPEG=$FfmpegMode)"
    Write-Step 'This can take a long time, especially on a first run (dependencies may be built from source).'
    Write-Host ''
    if ($logFile) {
        Invoke-Msys2Bash -Command $cmd -LogFile $logFile
    }
    else {
        Invoke-Msys2Bash -Command $cmd
    }
    return $script:lastMsysRc
}

function Test-FfmpegFetchFailure {
    <#
      True when the log shows the build died while *fetching* the FFmpeg sources.
      That is a network problem, not a code problem - the engine itself never
      got to compile.
    #>
    param([string]$Log)
    if (-not $Log) { return $false }
    if (-not (Test-Path -LiteralPath $Log)) { return $false }
    return [bool](Select-String -LiteralPath $Log -SimpleMatch -Quiet -Pattern @(
        'RPC failed',                 # curl 56 / connection abort during the clone
        'early EOF',
        'invalid index-pack output',
        'Could not resolve host',
        'Failed to connect to github.com'
    ))
}

function Test-FfmpegStageFailure {
    <#
      True when the build never reached the Go compile step, i.e. everything that
      happened (and failed) was inside build_ffmpeg: the clone, configure, make
      or make install.

      This machine has two independent, reproducible ways to lose that stage:
        * the FFmpeg clone dies when the proxy is down (see Test-FfmpegFetchFailure)
        * libvpx + FFmpeg compile, but `make install` STRIP produces 0-byte DLLs,
          after which build.sh aborts with "FFmpeg pkg-config files still not
          visible after build"  (recorded in docs/environment.md)
      Neither has anything to do with the engine source, so neither should be
      reported as "the engine build is broken".
    #>
    param([string]$Log)
    if (-not $Log) { return $false }
    if (-not (Test-Path -LiteralPath $Log)) { return $false }
    $inFfmpeg = [bool](Select-String -LiteralPath $Log -SimpleMatch -Quiet -Pattern 'Building minimal FFmpeg')
    $reachedGo = [bool](Select-String -LiteralPath $Log -SimpleMatch -Quiet -Pattern 'Building Go binary')
    return ($inFfmpeg -and -not $reachedGo)
}

$buildRc = Invoke-EngineBuild -FfmpegMode $BuildFfmpeg

# Second chance: 'auto' can still lose the race even after a successful probe
# (the probe only downloads a few KB, the real clone is ~100 MB and can be
# dropped mid-transfer). Retry once with the system FFmpeg so the engine build
# itself is not reported as broken.
if ($buildRc -ne 0 -and $BuildFfmpeg -eq 'auto' -and (Test-FfmpegStageFailure -Log $logFile)) {
    Write-Host ''
    Write-Warn2 'The build died inside the local FFmpeg stage - a download, configure, make or'
    Write-Warn2 'make install problem, not a code problem. Retrying once with the system FFmpeg.'
    Write-Host ''
    $BuildFfmpeg = 'no'
    $ffmpegDegraded = $true
    $buildRc = Invoke-EngineBuild -FfmpegMode 'no'
}

Write-Host ''

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
if ($buildRc -ne 0) {
    Write-Err "engine build failed (exit code $buildRc)"
    if ($logFile) { Write-Host "       See the full log: $logFile" -ForegroundColor Yellow }

    # -----------------------------------------------------------------------
    # Windows Defender can block the Go linker itself, long before the final
    # binary exists. It then reports:
    #   open <tmp>\go-buildNNN\b001\exe\a.out.exe: Operation did not complete
    #   successfully because the file contains a virus or potentially
    #   unwanted software
    # The engine binary is flagged as a false positive (Trojan:Win32/...!cl),
    # so this is an antivirus problem, not a code problem. Say so explicitly.
    # -----------------------------------------------------------------------
    $blocked = $false
    try {
        if ($logFile -and (Test-Path -LiteralPath $logFile)) {
            $blocked = [bool](Select-String -Path $logFile -SimpleMatch -Quiet `
                -Pattern 'virus or potentially unwanted software', 'Operation did not complete successfully')
        }
        if (-not $blocked) {
            $hits = @(Get-MpThreatDetection -ErrorAction Stop |
                Where-Object { $_.InitialDetectionTime -gt (Get-Date).AddMinutes(-15) })
            if ($hits.Count -gt 0) { $blocked = $true }
        }
    }
    catch { $blocked = $blocked }

    if ($blocked) {
        Write-Host ''
        Write-Host '[antivirus] This failure looks like Windows Defender blocking the build,' -ForegroundColor Yellow
        Write-Host '            not a defect in the code: the freshly linked engine binary is' -ForegroundColor Yellow
        Write-Host '            flagged as a false positive and gets killed while it is written.' -ForegroundColor Yellow
        Write-Host '            Check the detections:' -ForegroundColor Yellow
        Write-Host '                Get-MpThreatDetection | Select-Object InitialDetectionTime, ThreatID, Resources' -ForegroundColor Yellow
        Write-Host '            Then, in an ELEVATED shell, exclude both the build temp dir and the' -ForegroundColor Yellow
        Write-Host '            runtime directory, and rebuild:' -ForegroundColor Yellow
        Write-Host ("                Add-MpPreference -ExclusionPath '{0}'" -f (Join-Path $RepoRoot '.tmp')) -ForegroundColor Yellow
        Write-Host ("                Add-MpPreference -ExclusionPath '{0}'" -f $EngineDir) -ForegroundColor Yellow
        Write-Host '            See docs/environment.md (environment quirk: Defender quarantine).' -ForegroundColor Yellow
    }
    elseif (Test-FfmpegStageFailure -Log $logFile) {
        Write-Host ''
        Write-Host '[ffmpeg] The build never reached the Go compile step - it died inside the local' -ForegroundColor Yellow
        Write-Host '         FFmpeg stage (clone / configure / make / make install). Nothing is wrong' -ForegroundColor Yellow
        Write-Host '         with the engine code. Build with the system FFmpeg instead:' -ForegroundColor Yellow
        Write-Host '             pwsh -File scripts/build_engine.ps1 -BuildFfmpeg no' -ForegroundColor Yellow
        Write-Host '         See docs/environment.md (section "Build").' -ForegroundColor Yellow
    }
    exit 1
}

if (-not (Test-Path -LiteralPath $Executable)) {
    Write-Err "build reported success but $ExecutableName was not produced"
    if ($logFile) { Write-Host "       See the full log: $logFile" -ForegroundColor Yellow }
    exit 1
}

# A build that was killed (Ctrl-C, process terminated, Defender killed the shell)
# can leave the PREVIOUS binary in place and still report rc = 0 to PowerShell.
# That silently turns "the build did not run" into "Build PASS" - observed on
# 2026-09-20, where an interrupted FFmpeg build produced a PASS line for a binary
# dated 2026-09-17. Require the binary to have been written during THIS run.
$exe = Get-Item -LiteralPath $Executable
if ($exe.LastWriteTime -lt $buildStart) {
    Write-Err "build reported success but $ExecutableName was not rewritten"
    Write-Host  ("       Binary timestamp : {0}" -f $exe.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) -ForegroundColor Yellow
    Write-Host  ("       Build started at : {0}" -f $buildStart.ToString('yyyy-MM-dd HH:mm:ss')) -ForegroundColor Yellow
    Write-Host  '       The executable is older than this run, so nothing was built - most likely the' -ForegroundColor Yellow
    Write-Host  '       build was interrupted. Treat this as a FAILED build and re-run it.' -ForegroundColor Yellow
    if ($logFile) { Write-Host "       See the full log: $logFile" -ForegroundColor Yellow }
    exit 1
}
$hash = (Get-FileHash -LiteralPath $Executable -Algorithm SHA256).Hash

Write-Ok 'Build PASS'
Write-Host ''
if ($ffmpegDegraded) {
    Write-Warn2 'Built with the system FFmpeg (the local alpha-capable FFmpeg was not reachable).'
    Write-Host  '  WebM alpha may fall back to the native VP8/VP9 decoder. To build it: start the'
    Write-Host  '  proxy and run  pwsh -File scripts/build_engine.ps1 -BuildFfmpeg yes'
    Write-Host ''
}
Write-Host "  Binary    : $($exe.FullName)"
Write-Host ("  Size      : {0:N2} MB" -f ($exe.Length / 1MB))
Write-Host "  SHA256    : $hash"
Write-Host "  Built at  : $($exe.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
if ($logFile) { Write-Host "  Log       : $logFile" }
Write-Host ''
Write-Host '  Run it with: pwsh -File scripts/run_game.ps1' -ForegroundColor Cyan
Write-Host ''

exit 0

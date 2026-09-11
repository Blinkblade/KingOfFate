#!/usr/bin/env bash
#
# check_build_env.sh - verify the MSYS2 / MINGW64 toolchain needed to build IKEMEN GO.
#
# The dependency list comes from engine/ikemen-go/BUILDING.md (the pinned RC5 baseline).
# Run this from an MSYS2 MINGW64 shell, or let scripts/build_engine.ps1 call it.
#
# Exit codes:
#   0 - every required tool and pkg-config module is available
#   9 - something is missing (each missing item is printed as MISSING:<name>)
#
set -uo pipefail

export PATH="/mingw64/bin:/usr/bin:/bin"

# The Go shipped by MSYS2 is a "trimmed" build, so GOROOT has to be set explicitly.
# go.exe is a native Windows binary and does not accept the MSYS form of the path, so
# cygpath is used to derive the Windows form for this machine.
if [ -z "${GOROOT:-}" ]; then
  if command -v cygpath >/dev/null 2>&1; then
    GOROOT="$(cygpath -m /mingw64/lib/go)"
  else
    GOROOT=/mingw64/lib/go
  fi
fi
export GOROOT

missing=""
for t in git make gcc g++ pkg-config nasm go gendef dlltool; do
  if ! command -v "$t" >/dev/null 2>&1; then
    missing="$missing $t"
    echo "MISSING:$t"
  fi
done

if [ -n "$missing" ]; then
  echo "RESULT:FAIL tools:$missing"
  exit 9
fi

for m in sdl2 libxmp; do
  if ! pkg-config --exists "$m" 2>/dev/null; then
    echo "MISSING_PC:$m"
    exit 9
  fi
done

echo "gcc        : $(gcc --version 2>&1 | head -n1)"
echo "g++        : $(g++ --version 2>&1 | head -n1)"
echo "make       : $(make --version 2>&1 | head -n1)"
echo "nasm       : $(nasm --version 2>&1 | head -n1)"
echo "pkg-config : $(pkg-config --version 2>&1)"
echo "sdl2       : $(pkg-config --modversion sdl2 2>&1)"
echo "libxmp     : $(pkg-config --modversion libxmp 2>&1)"
echo "go         : $(go version 2>&1)"
echo "RESULT:PASS"
exit 0

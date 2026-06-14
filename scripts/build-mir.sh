#!/bin/sh
# Fetch a pinned MIR and compile its core + generator into linkable objects.
# Invoked by dub (preGenerateCommands). Safe to run repeatedly.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MIR_DIR="$ROOT/.mir"
BUILD="$ROOT/.mir-build"
MIR_REPO="https://github.com/vnmakarov/mir.git"
MIR_COMMIT="99c65079038f3ba9242ef646f308c266cfd7a8e5"
CC="${CC:-cc}"

if [ ! -d "$MIR_DIR/.git" ]; then
  git clone "$MIR_REPO" "$MIR_DIR"
fi
( cd "$MIR_DIR" && git fetch -q --depth 1 origin "$MIR_COMMIT" 2>/dev/null || true; git checkout -q "$MIR_COMMIT" )

mkdir -p "$BUILD"
[ -f "$BUILD/mir.o" ]     || $CC -c -O2 -I"$MIR_DIR" "$MIR_DIR/mir.c"     -o "$BUILD/mir.o"
[ -f "$BUILD/mir-gen.o" ] || $CC -c -O2 -I"$MIR_DIR" "$MIR_DIR/mir-gen.c" -o "$BUILD/mir-gen.o"
# c2mir is optional (only needed for the :c2mir configuration / C-frontend use)
if [ "$1" = "with-c2mir" ] && [ ! -f "$BUILD/c2mir.o" ]; then
  $CC -c -O2 -I"$MIR_DIR" -I"$MIR_DIR/c2mir" "$MIR_DIR/c2mir/c2mir.c" -o "$BUILD/c2mir.o"
fi
echo "MIR objects ready in $BUILD"

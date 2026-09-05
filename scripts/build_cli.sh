#!/bin/bash
# scripts/build_cli.sh — Build and deploy native HarmonyOS Terminal Emacs CLI
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLANG="/Users/abhi/Developer/command-line-tools/sdk/default/openharmony/native/llvm/bin/aarch64-unknown-linux-ohos-clang++"
HDC="/Users/abhi/Developer/command-line-tools/sdk/default/openharmony/toolchains/hdc"

SRC="$ROOT/entry/src/main/cpp/cli/emacs_cli.cpp"
OUT_DIR="$ROOT/build/cli"
OUT_BIN="$OUT_DIR/emacs"

mkdir -p "$OUT_DIR"

echo "=== Compiling native HarmonyOS Terminal Emacs (aarch64) ==="
"$CLANG" -O2 -std=c++17 "$SRC" -o "$OUT_BIN"
mkdir -p "$ROOT/entry/src/main/resources/rawfile"
cp -f "$OUT_BIN" "$ROOT/entry/src/main/resources/rawfile/emacs"
file "$OUT_BIN"

echo "=== Deploying to HarmonyOS emulator via HDC ==="
"$HDC" file send "$OUT_BIN" /data/local/tmp/emacs
"$HDC" shell "chmod +x /data/local/tmp/emacs && cp -f /data/local/tmp/emacs /data/local/tmp/ohemacs"

echo "=== Testing batch execution in HarmonyOS terminal ==="
"$HDC" shell "/data/local/tmp/emacs --version"
echo ""
echo "--- Arithmetic eval test ---"
"$HDC" shell '/data/local/tmp/emacs --batch --eval "(+ 19 23)"'
echo ""
echo "--- String message test ---"
"$HDC" shell '/data/local/tmp/emacs --batch --eval "(message \"Hello from HarmonyOS Terminal GNU Emacs 30.1!\")"'
echo ""
echo "--- Nested arithmetic test ---"
"$HDC" shell '/data/local/tmp/emacs --batch --eval "(+ (* 6 7) 0)"'

echo "=== Native CLI build & verify complete! ==="

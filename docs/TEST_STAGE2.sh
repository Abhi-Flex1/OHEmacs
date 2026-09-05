#!/bin/bash
# TEST_STAGE2.sh — Stage 1 -> Stage 2 bridge automated test for OHEmacs.
#
# Verifies:
#   1. hvigorw assembleHap BUILD SUCCESSFUL (SDK API 24, product=default)
#   2. HAP contains libs/arm64-v8a/libentry.so (+ x86_64)
#   3. hdc install succeeds
#   4. aa start EntryAbility succeeds
#   5. hilog -T OHEmacs dump shows stage2 bridge logs
#      (stage2 bridge ready / bridge->ohos / drain / read_socket)
#   6. ps shows com.example.ohemacs running
#   7. llvm-nm libentry.so exports ohos_* symbols
# Ends with PASS/FAIL summary; exit 0 iff all steps pass.
#
# Usage: ./docs/TEST_STAGE2.sh  (run from repo root; tester handles install)
# Env overrides: HAP, BUNDLE, ABILITY, HILOG_TAG, SDK_DIR

set -u
set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

BUNDLE="${BUNDLE:-com.example.ohemacs}"
ABILITY="${ABILITY:-EntryAbility}"
HAP="${HAP:-entry/build/default/outputs/default/entry-default-unsigned.hap}"
HILOG_TAG="${HILOG_TAG:-OHEmacs}"
DOMAIN_HEX="${DOMAIN_HEX:-0x0201}"

# Resolve toolchains: prefer PATH, fall back to default SDK layout.
if command -v hvigorw >/dev/null 2>&1; then
  HVIGOR="hvigorw"
elif [ -x "$ROOT/hvigorw" ]; then
  HVIGOR="$ROOT/hvigorw"
elif [ -x "/Users/abhi/Developer/command-line-tools/bin/hvigorw" ]; then
  HVIGOR="/Users/abhi/Developer/command-line-tools/bin/hvigorw"
else
  HVIGOR="hvigorw"
fi

if command -v hdc >/dev/null 2>&1; then
  HDC="hdc"
elif [ -x "/Users/abhi/Developer/command-line-tools/sdk/default/openharmony/toolchains/hdc" ]; then
  HDC="/Users/abhi/Developer/command-line-tools/sdk/default/openharmony/toolchains/hdc"
else
  HDC="hdc"
fi

SDK_DIR="${SDK_DIR:-/Users/abhi/Developer/command-line-tools/sdk/default/openharmony}"
LLVM_NM=""
if command -v llvm-nm >/dev/null 2>&1; then
  LLVM_NM="llvm-nm"
elif [ -x "$SDK_DIR/native/llvm/bin/llvm-nm" ]; then
  LLVM_NM="$SDK_DIR/native/llvm/bin/llvm-nm"
fi

PASS=0
FAIL=0
pass() { echo "[PASS] $*"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $*"; FAIL=$((FAIL + 1)); }
info() { echo "[INFO] $*"; }

info "ROOT=$ROOT BUNDLE=$BUNDLE ABILITY=$ABILITY HAP=$HAP"
info "HVIGOR=$HVIGOR HDC=$HDC LLVM_NM=${LLVM_NM:-<missing>}"

# --- 1. Build HAP -----------------------------------------------------------
info "Step 1: hvigorw assembleHap --mode module -p product=default"
BUILD_LOG="$(mktemp)"
if "$HVIGOR" assembleHap --mode module -p product=default 2>&1 | tee "$BUILD_LOG"; then
  if grep -q "BUILD SUCCESSFUL" "$BUILD_LOG"; then
    pass "hvigorw assembleHap BUILD SUCCESSFUL"
  else
    # hvigor exit 0 but marker missing: still count output check separately.
    if [ -f "$HAP" ]; then
      pass "hvigorw exit 0 and $HAP exists (no BUILD SUCCESSFUL marker)"
    else
      fail "hvigorw exit 0 but no BUILD SUCCESSFUL and no $HAP"
    fi
  fi
else
  fail "hvigorw assembleHap failed (see above)"
fi
rm -f "$BUILD_LOG"

# --- 2. HAP libs check ------------------------------------------------------
info "Step 2: unzip -l HAP libs check"
if [ ! -f "$HAP" ]; then
  fail "HAP missing: $HAP (build first)"
else
  HAP_LIST="$(mktemp)"
  unzip -l "$HAP" > "$HAP_LIST" 2>&1 || true
  cat "$HAP_LIST"
  if grep -q "libs/arm64-v8a/libentry.so" "$HAP_LIST"; then
    pass "HAP contains libs/arm64-v8a/libentry.so"
  else
    fail "HAP missing libs/arm64-v8a/libentry.so"
  fi
  if grep -q "libs/x86_64/libentry.so" "$HAP_LIST"; then
    pass "HAP contains libs/x86_64/libentry.so"
  else
    fail "HAP missing libs/x86_64/libentry.so"
  fi
  rm -f "$HAP_LIST"
fi

# --- 3. hdc install ---------------------------------------------------------
info "Step 3: hdc install HAP"
if "$HDC" install "$HAP" 2>&1 | tee /tmp/ohemacs_install.log; then
  if grep -qi "successfully" /tmp/ohemacs_install.log; then
    pass "hdc install bundle successfully"
  else
    fail "hdc install exit 0 but no 'successfully' in output"
  fi
else
  fail "hdc install failed (device disconnected?)"
fi

# --- 4. aa start ------------------------------------------------------------
info "Step 4: aa start $ABILITY"
if "$HDC" shell "aa start -b $BUNDLE -a $ABILITY" 2>&1 | tee /tmp/ohemacs_start.log; then
  if grep -qi "successfully" /tmp/ohemacs_start.log; then
    pass "aa start ability successfully"
  else
    fail "aa start exit 0 but no 'successfully' in output"
  fi
else
  fail "aa start failed"
fi

info "Sleep 5s for surface + first frame..."
sleep 5

# --- 5. hilog dump ----------------------------------------------------------
info "Step 5: hilog -T $HILOG_TAG dump"
# Use non-blocking -x dump (correct for OHOS hilog; -d is unsupported).
HILOG_OUT="/tmp/ohemacs_hilog.txt"
: > "$HILOG_OUT"
if "$HDC" shell "hilog -x -T $HILOG_TAG" > "$HILOG_OUT" 2>&1; then
  info "hilog -x dump ok ($(wc -l < "$HILOG_OUT") lines)"
else
  info "hilog -x failed, trying timeout-bounded 'hilog -T $HILOG_TAG'"
  if command -v timeout >/dev/null 2>&1; then
    timeout 6 "$HDC" shell "hilog -T $HILOG_TAG" > "$HILOG_OUT" 2>&1 || true
  else
    "$HDC" shell "hilog -T $HILOG_TAG -x" > "$HILOG_OUT" 2>&1 &
    HPID=$!
    sleep 6
    kill "$HPID" 2>/dev/null || true
    wait "$HPID" 2>/dev/null || true
  fi
fi
tail -n 80 "$HILOG_OUT" || true
if grep -q "stage2 bridge ready" "$HILOG_OUT"; then
  pass "hilog shows 'stage2 bridge ready' (ohos_init_events + redraw cb)"
else
  fail "hilog missing 'stage2 bridge ready'"
fi
if grep -q "bridge->ohos" "$HILOG_OUT"; then
  pass "hilog shows 'bridge->ohos' dual-write (Stage2 queue)"
else
  fail "hilog missing 'bridge->ohos' dual-write"
fi
if grep -q "drain " "$HILOG_OUT"; then
  pass "hilog shows legacy 'drain ' (internal queue intact)"
else
  fail "hilog missing legacy 'drain ' logs"
fi
# Informational only: surface/EGL path still intact.
if grep -q "OnSurfaceCreated" "$HILOG_OUT"; then
  info "hilog shows OnSurfaceCreated (XComponent path intact)"
fi
if grep -q "first frame drawn" "$HILOG_OUT"; then
  info "hilog shows first frame drawn (EGL path intact)"
fi

# --- 6. ps check ------------------------------------------------------------
info "Step 6: ps check $BUNDLE"
PS_OUT="$(mktemp)"
"$HDC" shell "ps -ef | grep ohemacs" > "$PS_OUT" 2>&1 || true
cat "$PS_OUT"
if grep -q "$BUNDLE" "$PS_OUT"; then
  pass "ps shows $BUNDLE running"
else
  fail "ps missing $BUNDLE"
fi
rm -f "$PS_OUT"

# --- 7. llvm-nm ohos_* symbols ----------------------------------------------
info "Step 7: llvm-nm ohos_* symbol count"
NM_SO=""
for cand in \
  "entry/build/default/intermediates/cmake/default/obj/arm64-v8a/libentry.so" \
  "entry/build/default/intermediates/libs/default/arm64-v8a/libentry.so"; do
  if [ -f "$cand" ]; then NM_SO="$cand"; break; fi
done
NM_TMPDIR=""
if [ -z "$NM_SO" ] && [ -f "$HAP" ]; then
  NM_TMPDIR="$(mktemp -d)"
  unzip -o -q "$HAP" "libs/arm64-v8a/libentry.so" -d "$NM_TMPDIR" 2>/dev/null || true
  if [ -f "$NM_TMPDIR/libs/arm64-v8a/libentry.so" ]; then
    NM_SO="$NM_TMPDIR/libs/arm64-v8a/libentry.so"
  fi
fi
if [ -z "${LLVM_NM:-}" ]; then
  fail "llvm-nm not found (SDK $SDK_DIR/native/llvm/bin/llvm-nm)"
elif [ -z "$NM_SO" ] || [ ! -f "$NM_SO" ]; then
  fail "libentry.so not found for nm check"
else
  info "nm target: $NM_SO ($LLVM_NM)"
  NM_OUT="$(mktemp)"
  "$LLVM_NM" -D --defined-only "$NM_SO" > "$NM_OUT" 2>&1 || "$LLVM_NM" --defined-only "$NM_SO" > "$NM_OUT" 2>&1 || true
  OHOS_COUNT="$(grep -c "ohos_" "$NM_OUT" || true)"
  info "ohos_* defined symbols: $OHOS_COUNT"
  grep "ohos_" "$NM_OUT" | head -n 30 || true
  for sym in ohos_write_event ohos_pending ohos_next_event ohos_init_events ohos_read_socket ohos_set_redraw_callback; do
    if grep -q "$sym" "$NM_OUT"; then
      pass "nm finds $sym"
    else
      fail "nm missing $sym"
    fi
  done
  rm -f "$NM_OUT"
fi
if [ -n "$NM_TMPDIR" ] && [ -d "$NM_TMPDIR" ]; then rm -rf "$NM_TMPDIR"; fi

# --- Summary ----------------------------------------------------------------
echo "=============================================="
echo "STAGE2 TEST SUMMARY: PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi

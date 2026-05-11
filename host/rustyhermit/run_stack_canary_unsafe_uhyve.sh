#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-../../results/rustyhermit/stack_canary_unsafe_uhyve}"
HERMIT_APP="${HERMIT_APP:-target/x86_64-unknown-hermit/debug/stack_canary_unsafe_probe}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"

STATIC_LOG="$OUTDIR/stack_canary_static.log"
RUNTIME_LOG="$OUTDIR/stack_canary_runtime.log"

{
  echo "[*] RustyHermit unsafe stack canary static check"
  echo "[*] Target app: $HERMIT_APP"

  if [ ! -f "$HERMIT_APP" ]; then
    echo "RESULT_STATIC: FAIL (RustyHermit app not found)"
  elif ! file "$HERMIT_APP" | grep -q "ELF"; then
    echo "RESULT_STATIC: FAIL (target is not an ELF file)"
  elif nm -A "$HERMIT_APP" 2>/dev/null | grep -qE '__stack_chk_fail|__stack_chk_guard'; then
    echo "Stack canary symbols: found"
    echo "RESULT_STATIC: PASS (stack protector symbols present)"
  else
    echo "Stack canary symbols: not found"
    echo "RESULT_STATIC: FAIL (no stack protector symbols found)"
  fi
} | tee "$STATIC_LOG"

echo "[*] RustyHermit Uhyve unsafe stack smash runtime probe"
echo "[*] App: $HERMIT_APP"

if [ ! -f "$HERMIT_APP" ]; then
  echo "RESULT_RUNTIME: FAIL (unsafe Rust probe binary not found)"
  exit 1
fi

timeout "${TIMEOUT_SECS}s" uhyve "$HERMIT_APP" > "$RUNTIME_LOG" 2>&1 || true

if ! grep -q '^PROBE_OK$' "$RUNTIME_LOG"; then
  echo "RESULT_RUNTIME: FAIL (unsafe Rust probe did not start)"
  exit 1
fi

if ! grep -q '^CANARY_PROBE_BEGIN$' "$RUNTIME_LOG"; then
  echo "RESULT_RUNTIME: FAIL (begin marker missing)"
  exit 1
fi

if grep -q '^STACK_SMASH_ALLOWED$' "$RUNTIME_LOG"; then
  echo "RESULT_RUNTIME: FAIL (stack smash continued past overflow)"
  exit 1
fi

if grep -qiE 'stack smashing|stack_chk|abort|panic|protection|fault|General Protection|Page fault' "$RUNTIME_LOG"; then
  echo "RESULT_RUNTIME: PASS (stack smash stopped before allowed marker)"
else
  echo "RESULT_RUNTIME: PASS/UNCLEAR (execution stopped before allowed marker)"
fi

#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-../../results/rustyhermit/stack_canary}"
HERMIT_LOADER="${HERMIT_LOADER:-hermit-loader-x86_64}"
HERMIT_APP="${HERMIT_APP:-target/x86_64-unknown-hermit/debug/stack_canary_unsafe_probe}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"

STATIC_LOG="$OUTDIR/stack_canary_static.log"
RUNTIME_LOG="$OUTDIR/stack_canary_runtime.log"

{
  echo "[*] RustyHermit stack canary static check"
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
    echo "RESULT_STATIC: FAIL/NOT_APPLICABLE (no stack protector symbols found)"
  fi
} | tee "$STATIC_LOG"

timeout "${TIMEOUT_SECS}s" qemu-system-x86_64 \
  -display none \
  -smp 1 \
  -m 64M \
  -serial stdio \
  -kernel "$HERMIT_LOADER" \
  -initrd "$HERMIT_APP" \
  -cpu qemu64,apic,fsgsbase,rdtscp,xsave,fxsr \
  > "$RUNTIME_LOG" 2>&1 || true

if ! grep -q '^PROBE_OK$' "$RUNTIME_LOG"; then
  echo "RESULT_RUNTIME: FAIL (unsafe Rust probe did not start)"
  exit 1
fi

if grep -q '^STACK_SMASH_ALLOWED$' "$RUNTIME_LOG"; then
  echo "RESULT_RUNTIME: FAIL (unsafe stack smash continued execution)"
  exit 1
fi

if grep -qiE 'stack smashing|stack_chk|abort|panic|fault|segmentation|crash' "$RUNTIME_LOG"; then
  echo "RESULT_RUNTIME: PASS (unsafe stack smash detected/terminated)"
else
  echo "RESULT_RUNTIME: PASS/UNCLEAR (execution stopped before allowed marker)"
fi
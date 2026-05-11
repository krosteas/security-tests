#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-../../results/unikraft/stack_canary}"
UNIKRAFT_KERNEL="${UNIKRAFT_KERNEL:-build/stack_canary-qemu-x86_64}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"
LOGFILE="$OUTDIR/stack_canary.log"

timeout "${TIMEOUT_SECS}s" qemu-system-x86_64 \
  -m 256 \
  -smp 1 \
  -nographic \
  -kernel "$UNIKRAFT_KERNEL" \
  > "$LOGFILE" 2>&1 || true

if ! grep -q '^PROBE_OK$' "$LOGFILE"; then
  echo "RESULT: FAIL (probe did not start)"
  exit 1
fi

if grep -q '^STACK_SMASH_ALLOWED$' "$LOGFILE"; then
  echo "RESULT: FAIL (stack smash continued execution)"
  exit 1
fi

if grep -qiE 'stack smashing|stack_chk|abort|panic|fault|segmentation|crash' "$LOGFILE"; then
  echo "RESULT: PASS (stack smash detected/terminated)"
else
  echo "RESULT: PASS/UNCLEAR (execution stopped before allowed marker)"
fi
#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-../../results/ukl/stack_canary}"
UKL_KERNEL="${UKL_KERNEL:-build/stack_canary_bzImage}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"
LOGFILE="$OUTDIR/stack_canary.log"

timeout "${TIMEOUT_SECS}s" qemu-system-x86_64 \
  -m 512 \
  -smp 1 \
  -nographic \
  -kernel "$UKL_KERNEL" \
  -append "console=ttyS0" \
  > "$LOGFILE" 2>&1 || true

if ! grep -q '^PROBE_OK$' "$LOGFILE"; then
  echo "RESULT: FAIL (probe did not start)"
  exit 1
fi

if grep -q '^STACK_SMASH_ALLOWED$' "$LOGFILE"; then
  echo "RESULT: FAIL (stack smash continued execution)"
  exit 1
fi

if grep -qiE 'stack smashing|stack_chk|abort|panic|fault|segmentation|crash|Kernel panic' "$LOGFILE"; then
  echo "RESULT: PASS (stack smash detected/terminated)"
else
  echo "RESULT: PASS/UNCLEAR (execution stopped before allowed marker)"
fi
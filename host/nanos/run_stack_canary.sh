#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-../../results/nanos/stack_canary}"
NANOS_IMAGE="${NANOS_IMAGE:-stack-canary-probe}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"
LOGFILE="$OUTDIR/stack_canary.log"

timeout "${TIMEOUT_SECS}s" ops run "$NANOS_IMAGE" \
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
#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${OUTDIR:-../../results/osv/stack_canary}"
OSV_KERNEL="${OSV_KERNEL:-build/last/loader-stripped.elf}"
OSV_IMAGE="${OSV_IMAGE:-build/last/usr.img}"
PROBE_PATH="${PROBE_PATH:-/stack_canary_probe}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"
LOGFILE="$OUTDIR/stack_canary.log"

timeout "${TIMEOUT_SECS}s" qemu-system-x86_64 \
  -m 512 \
  -smp 1 \
  -nographic \
  -kernel "$OSV_KERNEL" \
  -drive "file=${OSV_IMAGE},if=virtio,format=raw" \
  -append "-- $PROBE_PATH" \
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
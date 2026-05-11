#!/usr/bin/env bash
set -euo pipefail

RUNS="${RUNS:-10}"
OUTDIR="${OUTDIR:-osv_aslr_runs}"
OSV_KERNEL="${OSV_KERNEL:-build/last/loader-stripped.elf}"
OSV_IMAGE="${OSV_IMAGE:-build/last/usr.img}"
OSV_PROBE_PATH="${OSV_PROBE_PATH:-/aslr_probe}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"

for i in $(seq 1 "$RUNS"); do
  logfile="$OUTDIR/run_${i}.log"
  echo "[*] OSv run $i"
  timeout "${TIMEOUT_SECS}s" qemu-system-x86_64 \
    -m 512 \
    -smp 1 \
    -nographic \
    -kernel "$OSV_KERNEL" \
    -drive "file=${OSV_IMAGE},if=virtio,format=raw" \
    -append "-- ${OSV_PROBE_PATH}" \
    > "$logfile" 2>&1 || true

done

valid_logs=0
for logfile in "$OUTDIR"/run_*.log; do
  if grep -q '^PROBE_OK$' "$logfile" \
    && grep -q '^MAIN=' "$logfile" \
    && grep -q '^STACK=' "$logfile" \
    && grep -q '^HEAP=' "$logfile"; then
    valid_logs=$((valid_logs + 1))
  else
    echo "[!] Invalid log: $logfile (probe output missing)"
  fi
done

main_unique=$(grep -h '^MAIN=' "$OUTDIR"/run_*.log 2>/dev/null | sed 's/.*=//' | sort -u | wc -l)
stack_unique=$(grep -h '^STACK=' "$OUTDIR"/run_*.log 2>/dev/null | sed 's/.*=//' | sort -u | wc -l)
heap_unique=$(grep -h '^HEAP=' "$OUTDIR"/run_*.log 2>/dev/null | sed 's/.*=//' | sort -u | wc -l)

echo "Valid logs:              $valid_logs/$RUNS"
echo "Unique MAIN addresses:  $main_unique"
echo "Unique STACK addresses: $stack_unique"
echo "Unique HEAP addresses:  $heap_unique"

if [ "$valid_logs" -ne "$RUNS" ]; then
  echo "RESULT: FAIL (probe did not run correctly in every OSv execution)"
  exit 1
fi

if [ "$main_unique" -gt 1 ] || [ "$stack_unique" -gt 1 ] || [ "$heap_unique" -gt 1 ]; then
  echo "RESULT: PASS (variation detected)"
else
  echo "RESULT: FAIL (variation not detected)"
  exit 1
fi

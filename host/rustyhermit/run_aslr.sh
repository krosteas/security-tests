#!/usr/bin/env bash
set -euo pipefail

RUNS="${RUNS:-10}"
OUTDIR="${OUTDIR:-rustyhermit_aslr_runs}"
HERMIT_LOADER="${HERMIT_LOADER:-hermit-loader-x86_64}"
HERMIT_APP="${HERMIT_APP:-target/x86_64-unknown-hermit/debug/aslr_probe}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"

for i in $(seq 1 "$RUNS"); do
  logfile="$OUTDIR/run_${i}.log"
  echo "[*] RustyHermit run $i"
  timeout "${TIMEOUT_SECS}s" qemu-system-x86_64 \
    -display none \
    -smp 1 \
    -m 64M \
    -serial stdio \
    -kernel "$HERMIT_LOADER" \
    -initrd "$HERMIT_APP" \
    -cpu qemu64,apic,fsgsbase,rdtscp,xsave,fxsr \
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
  echo "RESULT: FAIL (probe did not run correctly in every RustyHermit execution)"
  exit 1
fi

if [ "$main_unique" -gt 1 ] || [ "$stack_unique" -gt 1 ] || [ "$heap_unique" -gt 1 ]; then
  echo "RESULT: PASS (variation detected)"
else
  echo "RESULT: FAIL (variation not detected)"
  exit 1
fi

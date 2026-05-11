#!/usr/bin/env bash
set -euo pipefail

RUNS="${RUNS:-30}"
OUTDIR="${OUTDIR:-../../results/rustyhermit/aslr_uhyve}"
HERMIT_APP="${HERMIT_APP:-target/x86_64-unknown-hermit/debug/aslr_probe}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"

mkdir -p "$OUTDIR"

for i in $(seq 1 "$RUNS"); do
  echo "[*] RustyHermit Uhyve ASLR run $i"
  timeout "${TIMEOUT_SECS}s" uhyve "$HERMIT_APP" \
    > "$OUTDIR/run_$i.log" 2>&1 || true

  if ! grep -q '^MAIN=' "$OUTDIR/run_$i.log"; then
    echo "RESULT: FAIL (run $i missing MAIN marker)"
    exit 1
  fi

  if ! grep -q '^STACK=' "$OUTDIR/run_$i.log"; then
    echo "RESULT: FAIL (run $i missing STACK marker)"
    exit 1
  fi

  if ! grep -q '^HEAP=' "$OUTDIR/run_$i.log"; then
    echo "RESULT: FAIL (run $i missing HEAP marker)"
    exit 1
  fi
done

main_unique=$(grep '^MAIN=' "$OUTDIR"/run_*.log | sed 's/.*=//' | sort -u | wc -l)
stack_unique=$(grep '^STACK=' "$OUTDIR"/run_*.log | sed 's/.*=//' | sort -u | wc -l)
heap_unique=$(grep '^HEAP=' "$OUTDIR"/run_*.log | sed 's/.*=//' | sort -u | wc -l)

echo "Unique MAIN addresses:  $main_unique"
echo "Unique STACK addresses: $stack_unique"
echo "Unique HEAP addresses:  $heap_unique"

if [ "$main_unique" -gt 1 ] && [ "$stack_unique" -gt 1 ] && [ "$heap_unique" -gt 1 ]; then
  echo "RESULT: PASS (full variation detected)"
elif [ "$main_unique" -gt 1 ] || [ "$stack_unique" -gt 1 ] || [ "$heap_unique" -gt 1 ]; then
  echo "RESULT: PARTIAL (some variation detected)"
else
  echo "RESULT: FAIL (no variation detected)"
  exit 1
fi

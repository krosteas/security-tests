#!/usr/bin/env bash
set -euo pipefail

NANOS_ELF="${NANOS_ELF:-build/aslr_probe}"
OUTDIR="${OUTDIR:-../../results/nanos/wx}"
mkdir -p "$OUTDIR"

LOGFILE="$OUTDIR/wx.log"

{
  echo "[*] Nanos W^X check"
  echo "[*] Target ELF: $NANOS_ELF"
  echo "[*] Note: this checks the guest ELF packaged by ops, not the final Nanos image."

  if [ ! -f "$NANOS_ELF" ]; then
    echo "RESULT: FAIL (Nanos guest ELF not found)"
    exit 1
  fi

  if ! file "$NANOS_ELF" | grep -q "ELF"; then
    echo "RESULT: FAIL (target is not an ELF file)"
    exit 1
  fi

  load_wx_count=$(
    readelf -lW "$NANOS_ELF" | awk '
      /LOAD/ {
        if ($0 ~ /W/ && $0 ~ /E/) c++
      }
      END { print c+0 }
    '
  )

  section_wx_count=$(
    readelf -SW "$NANOS_ELF" | awk '
      /^\s*\[/ {
        if ($0 ~ /W/ && $0 ~ /X/) c++
      }
      END { print c+0 }
    '
  )

  exec_stack_count=$(
    readelf -lW "$NANOS_ELF" | awk '
      /GNU_STACK/ {
        if ($0 ~ /E/) c++
      }
      END { print c+0 }
    '
  )

  echo "Writable+Executable LOAD segments: $load_wx_count"
  echo "Writable+Executable sections:      $section_wx_count"
  echo "Executable GNU_STACK headers:      $exec_stack_count"

  if [ "$load_wx_count" -gt 0 ] || [ "$section_wx_count" -gt 0 ] || [ "$exec_stack_count" -gt 0 ]; then
    echo "RESULT: FAIL (W+X memory layout detected)"
    exit 1
  else
    echo "RESULT: PASS (no W+X layout detected)"
  fi
} | tee "$LOGFILE"
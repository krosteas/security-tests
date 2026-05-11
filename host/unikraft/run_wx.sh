#!/usr/bin/env bash
set -euo pipefail

UNIKRAFT_ELF="${UNIKRAFT_ELF:-build/app-qemu-x86_64.dbg}"
OUTDIR="${OUTDIR:-../../results/unikraft/wx}"
mkdir -p "$OUTDIR"

LOGFILE="$OUTDIR/wx.log"

{
  echo "[*] Unikraft W^X check"
  echo "[*] Target ELF: $UNIKRAFT_ELF"

  if [ ! -f "$UNIKRAFT_ELF" ]; then
    echo "RESULT: FAIL (Unikraft ELF not found)"
    exit 1
  fi

  if ! file "$UNIKRAFT_ELF" | grep -q "ELF"; then
    echo "RESULT: FAIL (target is not an ELF file)"
    exit 1
  fi

  load_wx_count=$(
    readelf -lW "$UNIKRAFT_ELF" | awk '
      /LOAD/ {
        if ($0 ~ /W/ && $0 ~ /E/) c++
      }
      END { print c+0 }
    '
  )

  section_wx_count=$(
    readelf -SW "$UNIKRAFT_ELF" | awk '
      /^\s*\[/ {
        if ($0 ~ /W/ && $0 ~ /X/) c++
      }
      END { print c+0 }
    '
  )

  exec_stack_count=$(
    readelf -lW "$UNIKRAFT_ELF" | awk '
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
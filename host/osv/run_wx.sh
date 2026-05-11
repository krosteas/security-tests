#!/usr/bin/env bash
set -euo pipefail

OSV_ELF="${OSV_ELF:-build/last/loader-stripped.elf}"
OUTDIR="${OUTDIR:-../../results/osv/wx}"
mkdir -p "$OUTDIR"

LOGFILE="$OUTDIR/wx.log"

{
  echo "[*] OSv W^X check"
  echo "[*] Target ELF: $OSV_ELF"

  if [ ! -f "$OSV_ELF" ]; then
    echo "RESULT: FAIL (OSv ELF not found)"
    exit 1
  fi

  if ! file "$OSV_ELF" | grep -q "ELF"; then
    echo "RESULT: FAIL (target is not an ELF file)"
    exit 1
  fi

  load_wx_count=$(
    readelf -lW "$OSV_ELF" | awk '
      /LOAD/ {
        if ($0 ~ /W/ && $0 ~ /E/) c++
      }
      END { print c+0 }
    '
  )

  section_wx_count=$(
    readelf -SW "$OSV_ELF" | awk '
      /^\s*\[/ {
        if ($0 ~ /W/ && $0 ~ /X/) c++
      }
      END { print c+0 }
    '
  )

  exec_stack_count=$(
    readelf -lW "$OSV_ELF" | awk '
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
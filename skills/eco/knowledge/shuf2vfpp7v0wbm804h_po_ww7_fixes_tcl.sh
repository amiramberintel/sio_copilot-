#!/bin/bash
# Colorizer for shuf2vfpp7v0wbm804h_po_ww7_fixes.tcl
# Usage: bash shuf2vfpp7v0wbm804h_po_ww7_fixes_tcl.sh

RED='\033[1;31m'
GRN='\033[1;32m'
YEL='\033[1;33m'
BLU='\033[1;34m'
MAG='\033[1;35m'
CYN='\033[1;36m'
WHT='\033[1;37m'
DIM='\033[2m'
RST='\033[0m'

DIR="$(cd "$(dirname "$0")" && pwd)"
FILE="$DIR/shuf2vfpp7v0wbm804h_po_ww7_fixes.tcl"

sed \
  -e "s/^# ==.*/${MAG}&${RST}/g" \
  -e "s/^# ══.*/${CYN}&${RST}/g" \
  -e "s/^#  STEP [0-9].*/${WHT}&${RST}/g" \
  -e "s/^#  USAGE:/${GRN}&${RST}/g" \
  -e "s/size_cell/${GRN}&${RST}/g" \
  -e "s/insert_buffer/${YEL}&${RST}/g" \
  -e "s/ERROR:/${RED}&${RST}/g" \
  -e "s/MISS .*/${RED}&${RST}/g" \
  -e "s/FOUND  ✓/${GRN}&${RST}/g" \
  -e "s/FOUND  ~/${YEL}&${RST}/g" \
  -e "s/WARNING:.*/${YEL}&${RST}/g" \
  -e "s/MUST CHECK:.*/${RED}&${RST}/g" \
  -e "s/D2BWP/${RED}&${RST}/g" \
  -e "s/D3BWP/${RED}&${RST}/g" \
  -e "s/proc step[0-9].*/${BLU}&${RST}/g" \
  "$FILE"

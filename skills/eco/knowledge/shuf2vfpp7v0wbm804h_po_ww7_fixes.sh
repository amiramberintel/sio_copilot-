#!/bin/bash
# Colorizer for shuf2vfpp7v0wbm804h_po_ww7_fixes.txt
# Usage: bash shuf2vfpp7v0wbm804h_po_ww7_fixes.sh

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
FILE="$DIR/shuf2vfpp7v0wbm804h_po_ww7_fixes.txt"

sed \
  -e "s/^==.*/${MAG}&${RST}/g" \
  -e "s/^  ═.*/${CYN}&${RST}/g" \
  -e "s/← D[23] slow!/${RED}&${RST}/g" \
  -e "s/← long wire!/${YEL}&${RST}/g" \
  -e "s/^  ── .*/${WHT}&${RST}/g" \
  -e "s/Action:.*/${GRN}&${RST}/g" \
  -e "s/Expected:.*/${GRN}&${RST}/g" \
  -e "s/TOTAL FIX [0-9]:.*/${BLU}&${RST}/g" \
  -e "s/TOTAL CLK:.*/${BLU}&${RST}/g" \
  -e "s/TOTAL (all fixes):.*/${GRN}&${RST}/g" \
  -e "s/RISK:.*LOW.*/${GRN}&${RST}/g" \
  -e "s/RISK:.*MED.*/${YEL}&${RST}/g" \
  -e "s/Current partition WNS: -51ps/${RED}&${RST}/g" \
  -e "s/After all fixes:.*/${GRN}&${RST}/g" \
  -e "s/NOTE:.*/${DIM}&${RST}/g" \
  -e "s/D2[^0-9]/${RED}&${RST}/g" \
  -e "s/D3[^0-9]/${RED}&${RST}/g" \
  "$FILE"

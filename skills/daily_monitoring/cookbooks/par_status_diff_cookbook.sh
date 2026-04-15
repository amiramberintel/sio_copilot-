#!/bin/bash
# Colorizer for par_status_diff_cookbook.txt
# Usage: bash par_status_diff_cookbook.sh

RED=$'\033[1;31m'
GRN=$'\033[1;32m'
YEL=$'\033[1;33m'
BLU=$'\033[1;34m'
MAG=$'\033[1;35m'
CYN=$'\033[1;36m'
WHT=$'\033[1;37m'
DIM=$'\033[2m'
RST=$'\033[0m'

DIR="$(cd "$(dirname "$0")" && pwd)"
FILE="$DIR/par_status_diff_cookbook.txt"

sed \
  -e "s/^==.*/${WHT}&${RST}/g" \
  -e "s/REGRESSIONS/${RED}&${RST}/g" \
  -e "s/IMPROVEMENTS/${GRN}&${RST}/g" \
  -e "s/NEW SIGNALS/${YEL}&${RST}/g" \
  -e "s/GONE SIGNALS/${CYN}&${RST}/g" \
  -e "s/UNCHANGED/${DIM}&${RST}/g" \
  -e "s/WHAT THIS TOOL DOES:/${WHT}&${RST}/g" \
  -e "s/QUICK START/${WHT}&${RST}/g" \
  -e "s/TYPICAL WORKFLOW/${WHT}&${RST}/g" \
  -e "s/python3 par_status_diff.*/${GRN}&${RST}/g" \
  -e "s/→ .*/${BLU}&${RST}/g" \
  "$FILE"

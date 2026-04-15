#!/bin/bash
# pt_client_cookbook.sh — Colorized viewer for pt_client_cookbook.txt
# Usage: bash pt_client_cookbook.sh          (auto pipes to less -R)
#        bash pt_client_cookbook.sh | less -R (manual pager)

FILE="${1:-/nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/pt_client_cookbook.txt}"

if [ ! -f "$FILE" ]; then
    echo "ERROR: File not found: $FILE"
    exit 1
fi

# Colors — use $'...' for real escape characters
RED=$'\033[1;31m'
GRN=$'\033[1;32m'
YEL=$'\033[1;33m'
BLU=$'\033[1;34m'
MAG=$'\033[1;35m'
CYN=$'\033[1;36m'
WHT=$'\033[1;37m'
DIM=$'\033[2m'
RST=$'\033[0m'
BG_BLU=$'\033[44m'
BG_RED=$'\033[41m'
BG_GRN=$'\033[42m'

sed -E \
  -e "s/^(=+)/${BG_BLU}${WHT}\1${RST}/g" \
  -e "s/^(  [0-9]+\..*)/${YEL}\1${RST}/g" \
  -e "s/(pt_client\.pl)/${GRN}\1${RST}/g" \
  -e "s/(-m )/${CYN}\1${RST}/g" \
  -e "s/(-c )/${CYN}\1${RST}/g" \
  -e "s/(-o )/${CYN}\1${RST}/g" \
  -e "s/(-debug)/${CYN}\1${RST}/g" \
  -e "s/(latest_|prev_|modela_|modelb_)/${MAG}\1${RST}/g" \
  -e "s/(gfcn2clienta0[a-z0-9_]*)/${GRN}\1${RST}/g" \
  -e "s/(func\.max_high|func\.min_low|func\.max_nom|func\.max_low|func\.max_med)/${YEL}\1${RST}/g" \
  -e "s/(CCworst)/${RED}\1${RST}/g" \
  -e "s/(report_timing)/${BLU}\1${RST}/g" \
  -e "s/(get_designs|get_cells|get_pins|sizeof_collection|report_cell|get_latest_status|resource_server)/${BLU}\1${RST}/g" \
  -e "s/(icore0\/)/${MAG}\1${RST}/g" \
  -e "s/(rsmoclearvm803h|RSMOClearVM803H)/${RED}\1${RST}/g" \
  -e "s/(WRONG:)/${BG_RED}${WHT}\1${RST}/g" \
  -e "s/(RIGHT:|CORRECT:)/${BG_GRN}${WHT}\1${RST}/g" \
  -e "s/(FORBIDDEN|BLOCKED|READ-ONLY|REQUIRED)/${RED}\1${RST}/g" \
  -e "s/(TIP [0-9]+:)/${GRN}\1${RST}/g" \
  -e "s/(sg soc)/${YEL}\1${RST}/g" \
  -e "s/(BEFORE|AFTER)/${MAG}\1${RST}/g" \
  -e "s/([0-9]+-[0-9]+ (min|seconds|minutes))/${CYN}\1${RST}/g" \
  -e "s/(10 seconds!)/${GRN}\1${RST}/g" \
  -e "s/(PRIMARY|SETUP|HOLD)/${YEL}\1${RST}/g" \
  -e "s/(#[0-9]+\.[0-9]+)/${DIM}\1${RST}/g" \
  -e "s/(LOADING|OFFLINE)/${RED}\1${RST}/g" \
  -e "s/(Online)/${GRN}\1${RST}/g" \
  -e "s/(┌|┐|└|┘|├|┤|│|─)/${DIM}\1${RST}/g" \
  -e "s/(QUICK REFERENCE)/${BG_GRN}${WHT}\1${RST}/g" \
  "$FILE" | less -R

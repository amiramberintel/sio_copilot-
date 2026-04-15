#!/bin/bash
# RSMOClearVM803H Path Analysis Demo — colorized display
# Usage: ./RSMOClearVM803H_path_analysis_demo.sh
# Or:    ./RSMOClearVM803H_path_analysis_demo.sh | less -R

DIR="$(cd "$(dirname "$0")" && pwd)"
FILE="$DIR/RSMOClearVM803H_path_analysis_demo.txt"

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: $FILE not found"
  exit 1
fi

RED=$'\033[1;31m'
GRN=$'\033[1;32m'
YEL=$'\033[1;33m'
BLU=$'\033[1;34m'
MAG=$'\033[1;35m'
CYN=$'\033[1;36m'
WHT=$'\033[1;37m'
DIM=$'\033[2m'
RST=$'\033[0m'

sed \
  -e "s/PHASE [0-9]\+:/${MAG}&${RST}/g" \
  -e "s/STEP [0-9]\+\.[0-9]\+:/${CYN}&${RST}/g" \
  -e "s/^  #[0-9] .*│/${YEL}&${RST}/g" \
  -e "s/Strategy A/${GRN}Strategy A${RST}/g" \
  -e "s/Strategy B/${BLU}Strategy B${RST}/g" \
  -e "s/-71\.6ps/${RED}-71.6ps${RST}/g" \
  -e "s/-71ps/${RED}-71ps${RST}/g" \
  -e "s/-64ps/${RED}-64ps${RST}/g" \
  -e "s/-49ps/${RED}-49ps${RST}/g" \
  -e "s/-16ps/${RED}-16ps${RST}/g" \
  -e "s/+38\.6ps/${GRN}+38.6ps${RST}/g" \
  -e "s/+17ps/${GRN}+17ps${RST}/g" \
  -e "s/OVER by [0-9.]*ps/${RED}&${RST}/g" \
  -e "s/UNDER by [0-9.]*ps/${GRN}&${RST}/g" \
  -e "s/\bULVT\b/${GRN}ULVT${RST}/g" \
  -e "s/\bLVT\b/${YEL}LVT${RST}/g" \
  -e "s/\bLOW\b/${GRN}LOW${RST}/g" \
  -e "s/\bMEDIUM\b/${YEL}MEDIUM${RST}/g" \
  -e "s/\bHIGH\b/${RED}HIGH${RST}/g" \
  -e "s/ROOT CAUSE/${RED}ROOT CAUSE${RST}/g" \
  -e "s/BAD MERGE/${RED}BAD MERGE${RST}/g" \
  -e "s/WORST/${RED}WORST${RST}/g" \
  -e "s/WEAK/${YEL}WEAK${RST}/g" \
  -e "s/LONG/${YEL}LONG${RST}/g" \
  -e "s/FINDING:/${RED}FINDING:${RST}/g" \
  -e "s/CRITICAL/${RED}CRITICAL${RST}/g" \
  -e "s/MANDATORY/${RED}MANDATORY${RST}/g" \
  -e "s/CANNOT close/${RED}CANNOT close${RST}/g" \
  -e "s/REVISED/${YEL}REVISED${RST}/g" \
  -e "s/D2 input/${YEL}D2 input${RST}/g" \
  -e "s/safe range/${GRN}safe range${RST}/g" \
  -e "s/SAFE/${GRN}SAFE${RST}/g" \
  -e "s/LESSON:/${MAG}LESSON:${RST}/g" \
  -e "s/KEY INSIGHT/${MAG}KEY INSIGHT${RST}/g" \
  -e "s/DRAFT/${YEL}DRAFT${RST}/g" \
  -e "s/WARNING/${YEL}WARNING${RST}/g" \
  -e "s/move_objects/${CYN}move_objects${RST}/g" \
  -e "s/bbox.*{50 50}/${CYN}&${RST}/g" \
  -e "s/TIP/${BLU}TIP${RST}/g" \
  -e "s/NODE[0-3]/${CYN}&${RST}/g" \
  -e "s/EDGE[0-2]/${CYN}&${RST}/g" \
  -e "s/M17/${DIM}M17${RST}/g" \
  -e "s/M18/${DIM}M18${RST}/g" \
  -e "s/par_ooo_int/${BLU}par_ooo_int${RST}/g" \
  -e "s/par_ooo_vec/${MAG}par_ooo_vec${RST}/g" \
  -e "s/786um/${RED}786um${RST}/g" \
  -e "s/281um/${RED}281um${RST}/g" \
  -e "s/report_timing/${GRN}report_timing${RST}/g" \
  -e "s/✓/${GRN}✓${RST}/g" \
  -e "s/✗/${RED}✗${RST}/g" \
  -e "s/⚠️/${YEL}⚠️${RST}/g" \
  -e "s/60-70%/${YEL}60-70%${RST}/g" \
  -e "s/95%/${GRN}95%${RST}/g" \
  -e "s/^===.*$/${WHT}&${RST}/g" \
  "$FILE"

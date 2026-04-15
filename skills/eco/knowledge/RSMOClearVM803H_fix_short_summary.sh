#!/bin/bash
#===============================================================================
# RSMOClearVM803H Short Fix Summary — Colorizer
# Usage: ./RSMOClearVM803H_fix_short_summary.sh
#===============================================================================

FILE="$(dirname "$0")/RSMOClearVM803H_fix_short_summary.txt"

if [ ! -f "$FILE" ]; then
    echo "ERROR: $FILE not found"
    exit 1
fi

# Colors
RED=$'\033[1;31m'
GRN=$'\033[1;32m'
YEL=$'\033[1;33m'
BLU=$'\033[1;34m'
MAG=$'\033[1;35m'
CYN=$'\033[1;36m'
WHT=$'\033[1;37m'
DIM=$'\033[2m'
URED=$'\033[4;31m'
RST=$'\033[0m'

sed \
  -e "s/RSMOClearVM803H/${RED}RSMOClearVM803H${RST}/g" \
  -e "s/RORtLdIncM904H/${MAG}RORtLdIncM904H${RST}/g" \
  -e "s/ROBEarlyQualJumpM304H/${CYN}ROBEarlyQualJumpM304H${RST}/g" \
  -e "s/ROMOClearStallM901H/${CYN}ROMOClearStallM901H${RST}/g" \
  -e "s/RSMOClearVM804H/${CYN}RSMOClearVM804H${RST}/g" \
  -e "s/par_ooo_int/${BLU}par_ooo_int${RST}/g" \
  -e "s/par_ooo_vec/${CYN}par_ooo_vec${RST}/g" \
  -e "s/mclk_ooo_int/${BLU}mclk_ooo_int${RST}/g" \
  -e "s/mclk_ooo_vec/${CYN}mclk_ooo_vec${RST}/g" \
  -e "s/OVER by [0-9.]*ps/${RED}&${RST}/g" \
  -e "s/UNDER by [0-9.]*ps/${GRN}&${RST}/g" \
  -e "s/ROOT CAUSE/${URED}ROOT CAUSE${RST}/g" \
  -e "s/WORST/${RED}WORST${RST}/g" \
  -e "s/SAFE/${GRN}SAFE${RST}/g" \
  -e "s/-71\.6ps/${RED}-71.6ps${RST}/g" \
  -e "s/-71ps/${RED}-71ps${RST}/g" \
  -e "s/-64ps/${RED}-64ps${RST}/g" \
  -e "s/-49ps/${RED}-49ps${RST}/g" \
  -e "s/+17ps/${GRN}+17ps${RST}/g" \
  -e "s/+[0-9]*-[0-9]*ps/${GRN}&${RST}/g" \
  -e "s/ULVT/${GRN}ULVT${RST}/g" \
  -e "s/LVT/${YEL}LVT${RST}/g" \
  -e "s/MBIT/${MAG}MBIT${RST}/g" \
  -e "s/MB2/${MAG}MB2${RST}/g" \
  -e "s/\bLOW\b/${GRN}LOW${RST}/g" \
  -e "s/\bMEDIUM\b/${YEL}MEDIUM${RST}/g" \
  -e "s/\bHIGH\b/${RED}HIGH${RST}/g" \
  -e "s/REVISED/${YEL}REVISED${RST}/g" \
  -e "s/D2 input/${YEL}D2 input${RST}/g" \
  -e "s/MANDATORY/${RED}MANDATORY${RST}/g" \
  -e "s/CANNOT close/${RED}CANNOT close${RST}/g" \
  -e "s/+38\.6ps/${GRN}+38.6ps${RST}/g" \
  -e "s/safe range/${GRN}safe range${RST}/g" \
  -e "s/WARNING/${YEL}WARNING${RST}/g" \
  -e "s/TIP/${WHT}TIP${RST}/g" \
  -e "s/ECO/${YEL}ECO${RST}/g" \
  -e "s/spec=[0-9]*ps/${WHT}&${RST}/g" \
  -e "s/60-70%/${YEL}60-70%${RST}/g" \
  -e "s/95%/${GRN}95%${RST}/g" \
  -e "s/FAST/${GRN}FAST${RST}/g" \
  -e "s/FULL/${WHT}FULL${RST}/g" \
  -e "s/NEW PLACEMENT/${RED}NEW PLACEMENT${RST}/g" \
  -e "s/DRAFT/${YEL}DRAFT${RST}/g" \
  -e "s/move_objects/${WHT}move_objects${RST}/g" \
  -e "s/bbox_percentage/${WHT}bbox_percentage${RST}/g" \
  -e "s/NODE[0-9]/${MAG}&${RST}/g" \
  -e "s/EDGE[0-9]/${MAG}&${RST}/g" \
  -e "s/M17/${BLU}M17${RST}/g" \
  -e "s/M18/${CYN}M18${RST}/g" \
  -e "s/half shield/${WHT}half shield${RST}/g" \
  -e "s/BUFFSR2BFYD18/${GRN}BUFFSR2BFYD18${RST}/g" \
  -e "s/rsmoclearvm803h\.tp/${WHT}rsmoclearvm803h.tp${RST}/g" \
  -e "s/===.*===/$(printf '\033[2m')&$(printf '\033[0m')/g" \
  "$FILE"

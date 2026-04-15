#!/bin/bash
# Colorizer for icc2_eco_fix_cookbook.txt
# Usage: bash icc2_eco_fix_cookbook.sh [file]

FILE="${1:-/nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/icc2_eco_fix_cookbook.txt}"

RED=$'\033[1;31m'
GRN=$'\033[1;32m'
YEL=$'\033[1;33m'
BLU=$'\033[1;34m'
MAG=$'\033[1;35m'
CYN=$'\033[1;36m'
WHT=$'\033[1;37m'
DIM=$'\033[2m'
RST=$'\033[0m'
BG_YEL=$'\033[43m'
BG_GRN=$'\033[42m'
BG_RED=$'\033[41m'

sed -E \
  -e "s/^(={5,})/${WHT}\1${RST}/g" \
  -e "s/(STAGE [0-9]+:)/${BG_YEL}${WHT} \1${RST}/g" \
  -e "s/(GOLDEN RULE:.*)/${BG_RED}${WHT}\1${RST}/g" \
  -e "s/(RULE:.*)/${YEL}\1${RST}/g" \
  -e "s/(SECTION [0-9]+:)/${CYN}\1${RST}/g" \
  -e "s/(LOW RISK|LOW risk|LOW)/${GRN}\1${RST}/g" \
  -e "s/(MEDIUM|MED risk|MEDIUM risk)/${YEL}\1${RST}/g" \
  -e "s/(HIGH RISK|HIGH)/${RED}\1${RST}/g" \
  -e "s/(size_cell|insert_buffer|move_objects|remove_buffer)/${CYN}\1${RST}/g" \
  -e "s/(report_timing|update_timing|check_legality|route_eco|save_block)/${BLU}\1${RST}/g" \
  -e "s/(get_cells|get_pins|get_nets|get_lib_cells|get_attribute)/${MAG}\1${RST}/g" \
  -e "s/(current_design|list_designs|current_block)/${MAG}\1${RST}/g" \
  -e "s/(pt_client\.pl)/${GRN}\1${RST}/g" \
  -e "s/(stage0_verify\.tcl)/${GRN}\1${RST}/g" \
  -e "s/(_fixes\.tcl|_fixes\.sh|_fixes\.txt)/${CYN}\1${RST}/g" \
  -e "s/(MISS)/${RED}\1${RST}/g" \
  -e "s/(  OK  )/${GRN}\1${RST}/g" \
  -e "s/(□)/${YEL}\1${RST}/g" \
  -e "s/(✓)/${GRN}\1${RST}/g" \
  -e "s/(✗)/${RED}\1${RST}/g" \
  -e "s/(MUST|CANNOT|DO NOT)/${RED}\1${RST}/g" \
  -e "s/(ULVT|ULVTLL|LVT|SVT)/${GRN}\1${RST}/g" \
  -e "s/(BWP156)/${DIM}\1${RST}/g" \
  -e "s/(par_exe|par_fmav0|par_ooo_int|par_ooo_vec|par_msid|par_fe)/${MAG}\1${RST}/g" \
  -e "s/(ICC2|icc2_shell)/${WHT}\1${RST}/g" \
  -e "s/(~[0-9]+-[0-9]+ps)/${GRN}\1${RST}/g" \
  -e "s/(-49ps)/${RED}\1${RST}/g" \
  -e "s/(──.*──)/${DIM}\1${RST}/g" \
  "$FILE" | less -R

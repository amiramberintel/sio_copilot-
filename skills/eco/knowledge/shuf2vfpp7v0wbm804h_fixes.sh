#!/bin/bash
# Colorizer for shuf2vfpp7v0wbm804h_fixes.tcl
# Usage: bash shuf2vfpp7v0wbm804h_fixes.sh [file]
#   or:  cat shuf2vfpp7v0wbm804h_fixes.tcl | bash shuf2vfpp7v0wbm804h_fixes.sh

FILE="${1:-/nfs/site/disks/sunger_wa/fc_data/my_learns/ww11_4/shuf2vfpp7v0wbm804h_fixes.tcl}"

RED=$'\033[1;31m'
GRN=$'\033[1;32m'
YEL=$'\033[1;33m'
BLU=$'\033[1;34m'
MAG=$'\033[1;35m'
CYN=$'\033[1;36m'
WHT=$'\033[1;37m'
DIM=$'\033[2m'
RST=$'\033[0m'
BG_GRN=$'\033[42m'
BG_YEL=$'\033[43m'
BG_RED=$'\033[41m'

sed -E \
  -e "s/^(#+.*)/${DIM}\1${RST}/g" \
  -e "s/(={5,})/${WHT}\1${RST}/g" \
  -e "s/(STEP 0: VERIFY)/${BG_YEL}${WHT} \1 ${RST}/g" \
  -e "s/(FIX [0-9]+[a-z]?:)/${BG_YEL}${WHT} \1${RST}/g" \
  -e "s/(FIX B[0-9]:)/${BG_YEL}${WHT} \1${RST}/g" \
  -e "s/(CLK FIX [0-9]+[a-z]?:)/${BG_GRN}${WHT} \1${RST}/g" \
  -e "s/(POST-FIX:)/${BG_GRN}${WHT} \1${RST}/g" \
  -e "s/(ALL FIXES APPLIED)/${BG_GRN}${WHT} \1 ${RST}/g" \
  -e "s/(LOW [Rr]isk|LOW)/${GRN}\1${RST}/g" \
  -e "s/(MEDIUM|MED [Rr]isk)/${YEL}\1${RST}/g" \
  -e "s/(~[0-9]+-[0-9]+ps|~[0-9]+\.?[0-9]*ps)/${GRN}\1${RST}/g" \
  -e "s/(-49ps|-29ps)/${RED}\1${RST}/g" \
  -e "s/(size_cell)/${CYN}\1${RST}/g" \
  -e "s/(insert_buffer)/${CYN}\1${RST}/g" \
  -e "s/(move_objects)/${CYN}\1${RST}/g" \
  -e "s/(report_timing)/${BLU}\1${RST}/g" \
  -e "s/(check_legality|route_eco)/${BLU}\1${RST}/g" \
  -e "s/(get_cells|get_pins|get_nets|get_ports|get_attribute)/${MAG}\1${RST}/g" \
  -e "s/(NOT FOUND)/${RED}\1${RST}/g" \
  -e "s/(FAILED)/${RED}\1${RST}/g" \
  -e "s/(RISK:)/${YEL}\1${RST}/g" \
  -e "s/(NOTE:|NEXT STEPS:|REMEMBER:)/${YEL}\1${RST}/g" \
  -e "s/(HFSNET_507|HFSNET_131|tropt_net_4327106)/${MAG}\1${RST}/g" \
  -e "s/(ZCTSINV_721|ZCTSINV_539)/${MAG}\1${RST}/g" \
  -e "s/(INR2D[0-9]+|MUXAO4[A-Z]*D[0-9]+|INVD[0-9]+|CKND[0-9]+|BUFFD[0-9]+|BUFFSR2BFYDHD[0-9]+)/${CYN}\1${RST}/g" \
  -e "s/(72\.5um|45um|65um)/${YEL}\1${RST}/g" \
  -e "s/(fanout [0-9]+)/${YEL}\1${RST}/g" \
  "$FILE" | less -R

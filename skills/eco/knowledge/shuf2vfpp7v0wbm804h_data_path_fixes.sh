#!/bin/bash
# Colorizer for shuf2vfpp7v0wbm804h_data_path_fixes.txt
# Usage: bash shuf2vfpp7v0wbm804h_data_path_fixes.sh

FILE="${1:-/nfs/site/disks/sunger_wa/fc_data/my_learns/ww11_4/shuf2vfpp7v0wbm804h_data_path_fixes.txt}"

RED=$'\033[1;31m'
GRN=$'\033[1;32m'
YEL=$'\033[1;33m'
MAG=$'\033[1;35m'
CYN=$'\033[1;36m'
WHT=$'\033[1;37m'
DIM=$'\033[2m'
RST=$'\033[0m'
BG_RED=$'\033[41m'
BG_GRN=$'\033[42m'
BG_YEL=$'\033[43m'

sed -E \
  -e "s/^(=+)/${WHT}\1${RST}/g" \
  -e "s/^(  ═+)/${WHT}\1${RST}/g" \
  -e "s/(FIX [0-9]+:)/${BG_YEL}${WHT}\1${RST}/g" \
  -e "s/(BONUS:)/${BG_YEL}${WHT}\1${RST}/g" \
  -e "s/(SUMMARY)/${WHT}\1${RST}/g" \
  -e "s/(LOW RISK|LOW)/${GRN}\1${RST}/g" \
  -e "s/(MEDIUM RISK|MEDIUM|MED)/${YEL}\1${RST}/g" \
  -e "s/(HIGH RISK|HIGH)/${RED}\1${RST}/g" \
  -e "s/(~[0-9]+-[0-9]+ps|~[0-9]+\.?[0-9]*ps)/${GRN}\1${RST}/g" \
  -e "s/(-49ps|-29ps)/${RED}\1${RST}/g" \
  -e "s/(16\.7ps|13\.4ps|12\.5ps|12\.4ps)/${RED}\1${RST}/g" \
  -e "s/(ULVT|ULVTLL|CPDULVT|CPDULVTLL)/${GRN}\1${RST}/g" \
  -e "s/(LVT|CPDLVT)/${YEL}\1${RST}/g" \
  -e "s/(INR2D1|MUXAO4.*D1|INVD4)/${RED}\1${RST}/g" \
  -e "s/(→ INR2D[248]|→ MUXAO4.*D2|→ INVD[812]|→ D[248]|→ D1[26])/${GRN}\1${RST}/g" \
  -e "s/(HFSNET_507|HFSNET_131|tropt_net_4327106)/${MAG}\1${RST}/g" \
  -e "s/(size_cell|insert_buffer)/${CYN}\1${RST}/g" \
  -e "s/(fanout [0-9]+)/${YEL}\1${RST}/g" \
  -e "s/([0-9]+μm)/${CYN}\1${RST}/g" \
  -e "s/(Expected gain:)/${GRN}\1${RST}/g" \
  -e "s/(Action:)/${YEL}\1${RST}/g" \
  -e "s/(Why:)/${WHT}\1${RST}/g" \
  -e "s/(TOTAL|Total)/${WHT}\1${RST}/g" \
  -e "s/(DON'T TOUCH)/${BG_RED}${WHT}\1${RST}/g" \
  -e "s/(NOTE:)/${YEL}\1${RST}/g" \
  -e "s/(par_exe|par_fmav0)/${MAG}\1${RST}/g" \
  -e "s/(shuf2vfpp7v0wbm804h)/${CYN}\1${RST}/g" \
  -e "s/(──.*──)/${DIM}\1${RST}/g" \
  -e "s/(BEFORE:|AFTER)/${YEL}\1${RST}/g" \
  -e "s/(Current WNS:)/${RED}\1${RST}/g" \
  -e "s/(After .* fixes)/${GRN}\1${RST}/g" \
  "$FILE" | less -R

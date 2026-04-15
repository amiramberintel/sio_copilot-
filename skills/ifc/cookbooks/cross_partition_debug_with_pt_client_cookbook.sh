#!/bin/bash
# cross_partition_debug_with_pt_client_cookbook.sh — Colorized viewer
# Usage: bash cross_partition_debug_with_pt_client_cookbook.sh

FILE="${1:-/nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/cross_partition_debug_with_pt_client_cookbook.txt}"

if [ ! -f "$FILE" ]; then
    echo "ERROR: File not found: $FILE"
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
BG_BLU=$'\033[44m'
BG_RED=$'\033[41m'
BG_GRN=$'\033[42m'
BG_YEL=$'\033[43m'

sed -E \
  -e "s/^(=+)/${BG_BLU}${WHT}\1${RST}/g" \
  -e "s/(GOLDEN RULE)/${BG_RED}${WHT}\1${RST}/g" \
  -e "s/(MINUTE [0-9]+-[0-9]+:.*)/${GRN}\1${RST}/g" \
  -e "s/(pt_client\.pl)/${GRN}\1${RST}/g" \
  -e "s/(-m )/${CYN}\1${RST}/g" \
  -e "s/(-c )/${CYN}\1${RST}/g" \
  -e "s/(-o )/${CYN}\1${RST}/g" \
  -e "s/(-debug)/${CYN}\1${RST}/g" \
  -e "s/(latest_|prev_|modela_|modelb_)/${MAG}\1${RST}/g" \
  -e "s/(report_timing|report_clock_timing|sizeof_collection|get_designs|all_fanout|get_pins|get_cells)/${BLU}\1${RST}/g" \
  -e "s/(icore0\/)/${MAG}\1${RST}/g" \
  -e "s/(rsmoclearvm803h|RSMOClearVM803H)/${RED}\1${RST}/g" \
  -e "s/(Stage [0-7])/${YEL}\1${RST}/g" \
  -e "s/(STEP [0-9]+\.[0-9]+)/${YEL}\1${RST}/g" \
  -e "s/(Step [0-9]+)/${YEL}\1${RST}/g" \
  -e "s/(OLD:|THE OLD WAY)/${RED}\1${RST}/g" \
  -e "s/(NEW:|THE NEW WAY|NEW!)/${GRN}\1${RST}/g" \
  -e "s/(WRONG:)/${BG_RED}${WHT}\1${RST}/g" \
  -e "s/(RIGHT:)/${BG_GRN}${WHT}\1${RST}/g" \
  -e "s/(CANNOT|LIMITATIONS|READ-ONLY)/${RED}\1${RST}/g" \
  -e "s/(NOT PRACTICAL)/${RED}\1${RST}/g" \
  -e "s/(20-50x faster!)/${BG_GRN}${WHT}\1${RST}/g" \
  -e "s/(5-10 MINUTES)/${GRN}\1${RST}/g" \
  -e "s/(2-4 HOURS)/${RED}\1${RST}/g" \
  -e "s/(10 seconds)/${GRN}\1${RST}/g" \
  -e "s/(20 seconds)/${GRN}\1${RST}/g" \
  -e "s/(✓|✅|★)/${GRN}\1${RST}/g" \
  -e "s/(✗|×)/${RED}\1${RST}/g" \
  -e "s/(→)/${CYN}\1${RST}/g" \
  -e "s/(-71\.6ps|-64\.0ps|-68ps)/${RED}\1${RST}/g" \
  -e "s/(\+38\.6ps)/${GRN}\1${RST}/g" \
  -e "s/(FCT26WW[0-9]+[A-Z])/${YEL}\1${RST}/g" \
  -e "s/(┌|┐|└|┘|├|┤|│|─|╔|╚|╗|╝|║)/${DIM}\1${RST}/g" \
  -e "s/(DONE!|CONCLUSION:)/${BG_GRN}${WHT}\1${RST}/g" \
  -e "s/(IMPORTANT:|WHY THIS MATTERS:)/${YEL}\1${RST}/g" \
  -e "s/(ULVT|CPDULVT)/${GRN}\1${RST}/g" \
  -e "s/(LVT|CPDLVT|HVT|CPDHVT|SVT|CPDSVT)/${YEL}\1${RST}/g" \
  -e "s/(spec_status_cookbook\.txt)/${CYN}\1${RST}/g" \
  -e "s/(spec_status)/${CYN}\1${RST}/g" \
  -e "s/(missing_spec|unbalanced_spec|high_io_delay)/${MAG}\1${RST}/g" \
  -e "s/(margin = .*)/${YEL}\1${RST}/g" \
  -e "s/(BUDGET|budget)/${CYN}\1${RST}/g" \
  -e "s/(TOO FAR!|RED FLAGS)/${BG_RED}${WHT}\1${RST}/g" \
  -e "s/(VERDICT:)/${BG_YEL}${WHT}\1${RST}/g" \
  -e "s/(⚠)/${RED}\1${RST}/g" \
  -e "s/(clock latency|clock penalty)/${MAG}\1${RST}/g" \
  -e "s/([0-9]+μm)/${CYN}\1${RST}/g" \
  -e "s/(~[0-9]+-[0-9]+ps)/${GRN}\1${RST}/g" \
  -e "s/(port_location_outside_bbox\.csv)/${CYN}\1${RST}/g" \
  -e "s/(PORT LOCATION|port location|port move|Port Move)/${MAG}\1${RST}/g" \
  -e "s/(fis_count|fos_count|fis=|fos=)/${YEL}\1${RST}/g" \
  -e "s/(fanout|fanin|FANOUT|FANIN)/${YEL}\1${RST}/g" \
  -e "s/(dist_to_bbox)/${CYN}\1${RST}/g" \
  -e "s/(port_point|st_point|en_point)/${CYN}\1${RST}/g" \
  -e "s/(X gap|Y gap|X-distance|Y-component)/${MAG}\1${RST}/g" \
  -e "s/(OUTSIDE BBOX)/${BG_RED}${WHT}\1${RST}/g" \
  -e "s/(DANGEROUS|DO NOT TOUCH|VERY RISKY)/${BG_RED}${WHT}\1${RST}/g" \
  -e "s/(slideable|FIXED by boundary|FIXED by edge)/${YEL}\1${RST}/g" \
  -e "s/(DECISION MATRIX|GAIN ESTIMATION|FANOUT CHECK)/${BG_YEL}${WHT}\1${RST}/g" \
  "$FILE" | less -R

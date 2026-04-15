#!/bin/bash
# Colorizer for rtl_model_compare_cookbook.txt
# Usage: bash rtl_model_compare_cookbook.sh

GREEN='\033[1;32m'
RED='\033[1;31m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
RST='\033[0m'

FILE="$(dirname "$0")/rtl_model_compare_cookbook.txt"
[ ! -f "$FILE" ] && FILE="cookbooks/rtl_model_compare_cookbook.txt"
[ ! -f "$FILE" ] && echo "Cannot find rtl_model_compare_cookbook.txt" && exit 1

sed \
  -e "s/^==.*/${WHITE}&${RST}/g" \
  -e "s/^  [0-9]\+\..*/${WHITE}&${RST}/g" \
  -e "s/PURPOSE:/${CYAN}PURPOSE:${RST}/g" \
  -e "s/USE CASE:/${CYAN}USE CASE:${RST}/g" \
  -e "s/IMPORTANT NOTES:/${RED}IMPORTANT NOTES:${RST}/g" \
  -e "s/HOW TO INTERPRET:/${CYAN}HOW TO INTERPRET:${RST}/g" \
  -e "s/HOW TO DETECT:/${CYAN}HOW TO DETECT:${RST}/g" \
  -e "s/HOW TO VERIFY:/${CYAN}HOW TO VERIFY:${RST}/g" \
  -e "s/WHAT TO LOOK FOR:/${CYAN}WHAT TO LOOK FOR:${RST}/g" \
  -e "s/CANNOT DETECT:/${RED}CANNOT DETECT:${RST}/g" \
  -e "s/FOR THESE CASES:/${MAGENTA}FOR THESE CASES:${RST}/g" \
  -e "s/TIPS:/${GREEN}TIPS:${RST}/g" \
  -e "s/NOTE:/${MAGENTA}NOTE:${RST}/g" \
  -e "s/★ NEW FIX/${GREEN}★ NEW FIX${RST}/g" \
  -e "s/✓ ALREADY FIXED/${CYAN}✓ ALREADY FIXED${RST}/g" \
  -e "s/? UNKNOWN/${MAGENTA}? UNKNOWN${RST}/g" \
  -e "s/✘ IN PROGRESS/${RED}✘ IN PROGRESS${RST}/g" \
  -e "s/NOT in old.*IS in new.*/${GREEN}&${RST}/g" \
  -e "s/NOT in any model/${RED}NOT in any model${RST}/g" \
  -e "s/DUAL-CORE NOTE/${MAGENTA}DUAL-CORE NOTE${RST}/g" \
  -e "s/  Example:/${DIM}  Example:${RST}/g" \
  -e "s/  Result:/${DIM}  Result:${RST}/g" \
  -e "s/#.*$/${DIM}&${RST}/g" \
  "$FILE"

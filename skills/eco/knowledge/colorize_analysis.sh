#!/bin/bash
# Colorize timing path analysis files
# Usage: ./colorize_analysis.sh <file.txt>
#   or:  bash colorize_analysis.sh <file.txt>

FILE="${1:-DsbExitPointMaskM124H_path_analysis.txt}"

if [ ! -f "$FILE" ]; then
    echo "File not found: $FILE"
    exit 1
fi

python3 - "$FILE" << 'PYEOF'
import re, sys

f = sys.argv[1]
R="\033[0m"; B="\033[1m"; RED="\033[31m"; GRN="\033[32m"; YEL="\033[33m"
BLU="\033[34m"; MAG="\033[35m"; CYN="\033[36m"; WHT="\033[37m"
BRED="\033[1;31m"; BGRN="\033[1;32m"; BYEL="\033[1;33m"; BBLU="\033[1;34m"
BMAG="\033[1;35m"; BCYN="\033[1;36m"; BWHT="\033[1;37m"; DIM="\033[2m"
BGRED="\033[41m"

with open(f) as fh:
    lines = fh.readlines()

for line in lines:
    l = line.rstrip('\n')

    # === header bars
    if l.startswith('==='):
        print(f"{BBLU}{l}{R}"); continue

    # Section numbers 1. 2. 3. ...
    m = re.match(r'^(\d+\.\s+)(.*)', l)
    if m:
        print(f"{BCYN}{m.group(1)}{BWHT}{m.group(2)}{R}"); continue

    # Title
    if 'TIMING PATH ANALYSIS' in l:
        print(f"{BMAG}{l}{R}"); continue

    # Signal/WA/Date
    if l.strip().startswith(('Signal:','WA:','Date:')):
        print(f"{CYN}{l}{R}"); continue

    # Result line
    if l.strip().startswith('Result:'):
        print(f"{BRED}{l}{R}"); continue

    # Critical keywords
    if any(k in l for k in ['VIOLATED','OVER by','100% fail','SYSTEMIC','MANDATORY','impossible']):
        l2 = l
        l2 = re.sub(r'(VIOLATED.*)',       f'{BRED}\\1{R}', l2)
        l2 = re.sub(r'(OVER by \S+)',      f'{BRED}\\1{R}', l2)
        l2 = re.sub(r'(100% fail rate)',   f'{BGRED}{BWHT}\\1{R}', l2)
        l2 = re.sub(r'(SYSTEMIC[^,]*)',    f'{BRED}\\1{R}', l2)
        l2 = re.sub(r'(MANDATORY[^:]*)',   f'{BRED}\\1{R}', l2)
        l2 = re.sub(r'(impossible)',        f'{BRED}\\1{R}', l2)
        print(l2); continue

    # Group stats
    if re.search(r'Group _[01]_', l):
        l2 = re.sub(r'(avg=-\d+ ps)',    f'{RED}\\1{R}', l)
        l2 = re.sub(r'(worst=-\d+ ps)',  f'{BRED}\\1{R}', l2)
        l2 = re.sub(r'(_[01]_)',          f'{BYEL}\\1{R}', l2)
        print(l2); continue

    # Severity labels
    if re.search(r'Severe|Moderate|Mild', l):
        l2 = l
        l2 = re.sub(r'(Severe[^:]*:)',   f'{BRED}\\1{R}', l2)
        l2 = re.sub(r'(Moderate[^:]*:)', f'{BYEL}\\1{R}', l2)
        l2 = re.sub(r'(Mild[^:]*:)',     f'{BGRN}\\1{R}', l2)
        l2 = re.sub(r'(-\d+ ps)',        f'{RED}\\1{R}', l2)
        print(l2); continue

    # Negative slack values
    if re.search(r'-\d+ ps', l):
        l2 = re.sub(r'(-\d+ ps)',  f'{RED}\\1{R}', l)
        l2 = re.sub(r'(\[\d+\])', f'{YEL}\\1{R}', l2)
        print(l2); continue

    # gilkeren owner
    if 'gilkeren' in l:
        print(re.sub(r'(gilkeren)', f'{BMAG}\\1{R}', l)); continue

    # Fix options (green)
    if l.strip().startswith('- ') and any(k in l for k in ['TIP','Spec rebalance','logic','Proposed']):
        print(f"{GRN}{l}{R}"); continue

    # Conclusion letters a) b) c)
    m2 = re.match(r'^(\s+)([a-f]\)\s+)(.*)', l)
    if m2:
        print(f"{m2.group(1)}{BCYN}{m2.group(2)}{R}{m2.group(3)}"); continue

    # Annotations
    if '<- DEEP LOGIC' in l:
        print(re.sub(r'(<-.*)', f'{RED}\\1{R}', l)); continue
    if '<- nearly passing' in l:
        print(re.sub(r'(<-.*)', f'{GRN}\\1{R}', l)); continue
    if '<- shallower' in l:
        print(re.sub(r'(<-.*)', f'{YEL}\\1{R}', l)); continue

    # Default
    print(l)
PYEOF

#!/bin/bash
# Colorize DsbqBypUopsNumDeltaM124H fix summary
# Usage: bash DsbqBypUopsNumDeltaM124H_fix_summary.sh
#   or:  bash DsbqBypUopsNumDeltaM124H_fix_summary.sh <other_file.txt>

DIR="$(cd "$(dirname "$0")" && pwd)"
FILE="${1:-${DIR}/DsbqBypUopsNumDeltaM124H_fix_summary.txt}"

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

    # FIX # headers
    if re.match(r'\s+FIX #\d', l):
        print(f"{BMAG}{l}{R}"); continue

    # Sub-option headers: A) B) C) D) with title
    if re.match(r'\s+[A-D]\) ', l):
        print(f"{BYEL}{l}{R}"); continue

    # Section titles (PROBLEM SUMMARY, COMBINED, ACTION ITEMS, etc.)
    if re.match(r'^[A-Z ]{10,}:', l) or l.strip() in (
        'PROBLEM SUMMARY:', 'CLOCK PATH:', 'BOTTLENECKS:',
        'FIX OPTIONS:', 'TOP BOTTLENECKS:',
        'NOTE ON COMBINED ESTIMATE:', 'OUTPUT PATH VERIFICATION'):
        print(f"{BCYN}{l}{R}"); continue

    # Fix approach / Current situation labels
    if re.match(r'\s+(Fix approach|Current situation|Fix:|Prerequisite):', l):
        print(f"{BCYN}{l}{R}"); continue

    # Risk labels with severity coloring
    if re.match(r'\s+Risk:', l):
        l2 = l
        l2 = re.sub(r'(NONE)',   f'{BGRN}\\1{R}', l2)
        l2 = re.sub(r'(LOW)',    f'{BGRN}\\1{R}', l2)
        l2 = re.sub(r'(Low)',    f'{GRN}\\1{R}', l2)
        l2 = re.sub(r'(MEDIUM)', f'{BYEL}\\1{R}', l2)
        l2 = re.sub(r'(Medium)', f'{YEL}\\1{R}', l2)
        l2 = re.sub(r'(HIGH)',   f'{BRED}\\1{R}', l2)
        print(l2); continue

    # Who runs/owns it lines
    if re.match(r'\s+Who (runs|owns) it:', l):
        l2 = re.sub(r'(navits)',   f'{BMAG}\\1{R}', l)
        l2 = re.sub(r'(par_fe[^ ]*)',  f'{BCYN}\\1{R}', l2)
        l2 = re.sub(r'(par_msid[^ ]*)', f'{BCYN}\\1{R}', l2)
        print(l2); continue

    # Priority labels
    if re.search(r'Priority:', l):
        l2 = re.sub(r'(P1[^)]*\))', f'{BRED}\\1{R}', l)
        l2 = re.sub(r'(P2[^)]*\))', f'{BYEL}\\1{R}', l2)
        l2 = re.sub(r'(P3[^)]*\))', f'{GRN}\\1{R}', l2)
        print(l2); continue

    # VIOLATED / OVER / WORST / BAD markers
    if any(k in l for k in ['VIOLATED','OVER','<- WORST','<- BAD','100% fail','SAFE']):
        l2 = l
        l2 = re.sub(r'(VIOLATED)',          f'{BRED}\\1{R}', l2)
        l2 = re.sub(r'(\d+\.?\d* ?ps OVER)',f'{BRED}\\1{R}', l2)
        l2 = re.sub(r'(<- WORST)',          f'{BRED}\\1{R}', l2)
        l2 = re.sub(r'(<- BAD)',            f'{RED}\\1{R}', l2)
        l2 = re.sub(r'(100% fail rate)',    f'{BGRED}{BWHT}\\1{R}', l2)
        l2 = re.sub(r'(SAFE)',              f'{BGRN}\\1{R}', l2)
        print(l2); continue

    # PT detail lines: Location, Cell type, Cell delay, Input transition
    if re.match(r'\s+(Location|Cell type|Cell delay|Input transition|Load|Drives|Fanout|Cap|Output transition|Wire delay|Manhattan):', l):
        l2 = re.sub(r'(\d+\.\d+ps)', f'{YEL}\\1{R}', l)
        l2 = re.sub(r'(\d+\.\d+fF)', f'{CYN}\\1{R}', l2)
        l2 = re.sub(r'(\d+um)',       f'{CYN}\\1{R}', l2)
        l2 = re.sub(r'(\(\d+,\s*\d+\))', f'{DIM}\\1{R}', l2)
        l2 = re.sub(r'(slow[^)]*)',   f'{RED}\\1{R}', l2)
        print(l2); continue

    # Synthesis directive names
    if any(k in l for k in ['set_critical_range','group_path','compile -retime']):
        l2 = re.sub(r'(set_critical_range)', f'{CYN}\\1{R}', l)
        l2 = re.sub(r'(group_path)',         f'{CYN}\\1{R}', l2)
        l2 = re.sub(r'(compile -retime)',    f'{CYN}\\1{R}', l2)
        print(l2); continue

    # Option 1/2 lines
    if re.match(r'\s+Option \d:', l):
        l2 = re.sub(r'(Option \d:)', f'{BYEL}\\1{R}', l)
        print(l2); continue

    # Gate detail lines: "Gate N: CELLNAME"
    if re.search(r'Gate \d+:', l):
        l2 = re.sub(r'(\d+\.\d+ps)', f'{YEL}\\1{R}', l)
        l2 = re.sub(r'(<- .*)', f'{RED}\\1{R}', l2)
        l2 = re.sub(r'(\d+um)', f'{CYN}\\1{R}', l2)
        print(l2); continue

    # Numbered list items in fix descriptions (1. 2. 3. 4.)
    if re.match(r'\s+\d+\.\s', l) and re.search(r'(DsbqByp|critical_range|group_path|retime|DUP_)', l):
        l2 = re.sub(r'(\d+\.)', f'{BYEL}\\1{R}', l)
        print(l2); continue

    # Savings / positive results
    if re.search(r'\+\d+.*ps', l) and not re.search(r'stat', l):
        l2 = re.sub(r'(\+\d+-?\d*ps)', f'{BGRN}\\1{R}', l)
        l2 = re.sub(r'(-> \+\d+-?\d+ps)', f'{BGRN}\\1{R}', l2)
        print(l2); continue

    # Overlap warning
    if '*** FIX OVERLAP WARNING' in l or 'OVERLAP WITH FIX' in l:
        print(f"{BGRED}{BWHT}{l}{R}"); continue

    # Overlap-adjusted note
    if 'overlap-adjusted' in l.lower() or 'NOT ' in l and 'ps)' in l:
        l2 = re.sub(r'(NOT \d+-\d+ps)', f'{BRED}\\1{R}', l)
        l2 = re.sub(r'(\(\*\))', f'{BYEL}\\1{R}', l2)
        print(l2); continue

    # Table rows with negative slack
    if re.search(r'-\d+\.\d+ *\|', l) or re.search(r'-\d+\.\d+ *$', l):
        l2 = re.sub(r'(-\d+\.\d+)', f'{RED}\\1{R}', l)
        l2 = re.sub(r'(_[01]_\[\d\])', f'{YEL}\\1{R}', l2)
        print(l2); continue

    # Negative slack anywhere
    if re.search(r'-\d+\.?\d* ?ps', l):
        l2 = re.sub(r'(-\d+\.?\d* ?ps)', f'{RED}\\1{R}', l)
        print(l2); continue

    # Owner names (catch-all for navits, sunger, etc.)
    if any(k in l for k in ['navits','par_msid owner','Synthesis team','Phys design','sunger']):
        l2 = re.sub(r'(navits)',         f'{BMAG}\\1{R}', l)
        l2 = re.sub(r'(par_msid owner)', f'{BCYN}\\1{R}', l2)
        l2 = re.sub(r'(sunger)',         f'{BGRN}\\1{R}', l2)
        l2 = re.sub(r'(DONE)',           f'{BGRN}\\1{R}', l2)
        print(l2); continue

    # Cell lines with ps timing
    if re.search(r'Cell \d+:', l):
        l2 = re.sub(r'(\d+\.\d+ps)', f'{YEL}\\1{R}', l)
        l2 = re.sub(r'(\d+um!?\)?)', f'{CYN}\\1{R}', l2)
        print(l2); continue

    # PT report lines with coordinates
    if re.search(r'^\s+\d+\.\d+ps\s+', l):
        l2 = re.sub(r'(\d+\.\d+ps)', f'{DIM}\\1{R}', l)
        l2 = re.sub(r'(\[.*?\])', f'{YEL}\\1{R}', l2)
        print(l2); continue

    # Bit closure table
    if re.search(r'all bits closed', l):
        print(re.sub(r'(all bits closed)', f'{BGRN}\\1{R}', l)); continue

    # Table header/separator lines
    if re.match(r'\s+\+[-+]+\+', l):
        print(f"{DIM}{l}{R}"); continue

    # Table rows with technique names
    if re.search(r'\|\s*[A-D]:', l):
        l2 = re.sub(r'(NONE)',       f'{BGRN}\\1{R}', l)
        l2 = re.sub(r'(PnR only)',   f'{GRN}\\1{R}', l2)
        l2 = re.sub(r'(dsbq_data)',  f'{YEL}\\1{R}', l2)
        l2 = re.sub(r'(dsbhitm)',    f'{YEL}\\1{R}', l2)
        l2 = re.sub(r'(navits)',     f'{BMAG}\\1{R}', l2)
        l2 = re.sub(r'(\d+-\d+ps)',  f'{BGRN}\\1{R}', l2)
        print(l2); continue

    # Recommended priority line
    if re.search(r'Recommended priority:', l):
        print(f"{BGRN}{l}{R}"); continue

    # TIP section keywords
    if any(k in l for k in ['move_objects','create_supernet','create_topology','set ivar']):
        print(f"{CYN}{l}{R}"); continue

    # Half shield / shielding details
    if any(k in l for k in ['half_shield','Shield','SHIELD','blocked','crosstalk']):
        l2 = re.sub(r'(half_shield_1w)',    f'{BCYN}\\1{R}', l)
        l2 = re.sub(r'(\[S\])',             f'{BYEL}\\1{R}', l2)
        l2 = re.sub(r'(blocked)',           f'{YEL}\\1{R}', l2)
        l2 = re.sub(r'(crosstalk[^ ]*)',    f'{MAG}\\1{R}', l2)
        l2 = re.sub(r'(M1[78])',            f'{BCYN}\\1{R}', l2)
        print(l2); continue

    # Track blocking ivar lines
    if 'tip_block_track' in l:
        l2 = re.sub(r'(tip_block_track_for_\w+)',  f'{CYN}\\1{R}', l)
        l2 = re.sub(r'(\$M1[78]_half_shield_1w)',  f'{BCYN}\\1{R}', l2)
        print(l2); continue

    # Default
    print(l)
PYEOF

#!/bin/bash
# Colorize DsbExitPointMaskM124H_full_fix_summary.txt
# Usage: bash DsbExitPointMaskM124H_full_fix_summary.sh

DIR="$(cd "$(dirname "$0")" && pwd)"
FILE="$DIR/DsbExitPointMaskM124H_full_fix_summary.txt"

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
BGRED="\033[41m"; BGGRN="\033[42m"; BGYEL="\033[43m"

with open(f) as fh:
    lines = fh.readlines()

for line in lines:
    l = line.rstrip('\n')

    # === header bars
    if l.startswith('==='):
        print(f"{BBLU}{l}{R}"); continue

    # FIX #N headers
    m = re.match(r'^(\s*FIX #\d+:)(.*)', l)
    if m:
        print(f"{BCYN}{m.group(1)}{BWHT}{m.group(2)}{R}"); continue

    # COMBINED FIX STRATEGY / COMBINED FIX / ACTION ITEMS headers
    if re.match(r'^(PROBLEM SUMMARY|COMBINED FIX|ACTION ITEMS)', l):
        print(f"{BWHT}{l}{R}"); continue

    # OPTION A / OPTION B section headers in combined strategy
    if re.match(r'\s+─── OPTION [AB]:', l):
        if 'RECOMMENDED' in l:
            l2 = re.sub(r'(RECOMMENDED)', f'{BGRN}\\1{R}', l)
            print(f"{BCYN}{l2}{R}"); continue
        elif 'LOW PRIORITY' in l:
            l2 = re.sub(r'(LOW PRIORITY)', f'{YEL}\\1{R}', l)
            print(f"{CYN}{l2}{R}"); continue
        print(f"{BCYN}{l}{R}"); continue

    # BIT CLOSURE FORECAST header
    if 'BIT CLOSURE FORECAST' in l:
        print(f"{BYEL}{l}{R}"); continue

    # DONE status in action items
    if 'DONE' in l and '✅' in l and '│' in l:
        l2 = re.sub(r'(✅ DONE)', f'{BGRN}\\1{R}', l)
        print(l2); continue

    # Title lines
    if 'FULL FIX SUMMARY' in l:
        print(f"{BMAG}{l}{R}"); continue
    if '100% fail rate' in l:
        print(f"{BGRED}{BWHT}{l}{R}"); continue

    # RULED OUT
    if 'RULED OUT' in l or 'NOT AN OPTION' in l:
        print(f"{BRED}{l}{R}"); continue

    # USEFUL SKEW highlight
    if 'USEFUL SKEW' in l or 'useful skew' in l:
        l2 = re.sub(r'(USEFUL SKEW|useful skew)', f'{BGRN}\\1{R}', l)
        print(l2); continue

    # FALLBACK label
    if 'FALLBACK' in l and '│' in l:
        l2 = re.sub(r'(FALLBACK)', f'{YEL}\\1{R}', l)
        print(l2); continue

    # CLK BUF diagram
    if 'CLK BUF' in l:
        l2 = re.sub(r'(\[CLK BUF[^\]]*\])', f'{BGRN}\\1{R}', l)
        l2 = re.sub(r'(44 RecycExitMask FFs only)', f'{BCYN}\\1{R}', l2)
        print(l2); continue

    # DECISION TABLE
    if 'DECISION TABLE' in l:
        print(f"{BYEL}{l}{R}"); continue

    # Safe/partial/cannot decision rows
    if '✅ SAFE' in l:
        print(f"{GRN}{l}{R}"); continue
    if '⚠️  PARTIAL' in l:
        print(f"{YEL}{l}{R}"); continue
    if '❌ Cannot' in l:
        print(f"{RED}{l}{R}"); continue

    # Priority labels
    if re.search(r'Priority:\s*(DO FIRST|P1|HIGH)', l):
        print(re.sub(r'(DO FIRST|P1[^│]*|HIGH[^│]*)', f'{BRED}\\1{R}', l)); continue
    if re.search(r'Priority:\s*(P2|MEDIUM)', l):
        print(re.sub(r'(P2|MEDIUM[^│]*)', f'{BYEL}\\1{R}', l)); continue
    if re.search(r'Priority:\s*(P3|LOW)', l):
        print(re.sub(r'(P3|LOW)', f'{BGRN}\\1{R}', l)); continue

    # Cost: FREE
    if 'Cost:' in l and 'FREE' in l:
        print(re.sub(r'(FREE[^,]*)', f'{BGRN}\\1{R}', l)); continue

    # Savings lines
    if 'Savings:' in l:
        print(re.sub(r'(\d+[-–]?\d*\s*ps)', f'{GRN}\\1{R}', l)); continue

    # Risk lines
    if 'Risk:' in l:
        l2 = l
        l2 = re.sub(r'(None)', f'{BGRN}\\1{R}', l2)
        l2 = re.sub(r'(Low[^(]*)', f'{GRN}\\1{R}', l2)
        l2 = re.sub(r'(Medium[^(]*)', f'{YEL}\\1{R}', l2)
        l2 = re.sub(r'(HIGH)', f'{BRED}\\1{R}', l2)
        print(l2); continue

    # Owner: gilkeren
    if 'gilkeren' in l:
        print(re.sub(r'(gilkeren)', f'{BMAG}\\1{R}', l)); continue

    # Owner: par_msid owner
    if 'par_msid owner' in l and '│' in l:
        l2 = re.sub(r'(par_msid owner)', f'{BMAG}\\1{R}', l)
        l2 = re.sub(r'(P1[^│]*)', f'{BRED}\\1{R}', l2)
        print(l2); continue

    # report_timing command
    if 'report_timing' in l and 'RecycExit' in l:
        print(f"{CYN}{l}{R}"); continue

    # IMPOSSIBLE / PHYSICALLY IMPOSSIBLE
    if 'IMPOSSIBLE' in l or 'impossible' in l:
        l2 = re.sub(r'(IMPOSSIBLE|impossible)', f'{BRED}\\1{R}', l)
        print(l2); continue

    # Clock latency table data rows (with WORSE/BETTER/MORE/LESS)
    if 'MORE' in l and 'ps' in l and '!!!' not in l:
        l2 = re.sub(r'(\+\d+ps MORE)', f'{RED}\\1{R}', l)
        print(l2); continue
    if 'MORE !!!' in l:
        l2 = re.sub(r'(\+\d+ps MORE !!!)', f'{BRED}\\1{R}', l)
        print(l2); continue
    if 'LESS' in l and 'ps' in l and 'vs current' not in l:
        l2 = re.sub(r'(-\s*\d+ps LESS)', f'{GRN}\\1{R}', l)
        print(l2); continue
    if 'WORSE' in l and 'ps' in l:
        l2 = re.sub(r'(-\d+\.?\d*\s*ps)', f'{RED}\\1{R}', l)
        l2 = re.sub(r'(WORSE)', f'{RED}\\1{R}', l2)
        print(l2); continue
    if 'BETTER' in l and 'ps' in l:
        l2 = re.sub(r'(-\d+\.?\d*\s*ps)', f'{RED}\\1{R}', l)
        l2 = re.sub(r'(BETTER)', f'{GRN}\\1{R}', l2)
        l2 = re.sub(r'(\+\d+\s*ps)', f'{GRN}\\1{R}', l2)
        print(l2); continue
    if 'current' in l and 'ps' in l and re.search(r'\d+\s*ps', l) and '──' not in l:
        l2 = re.sub(r'(-\d+\.?\d*\s*ps)', f'{RED}\\1{R}', l)
        l2 = re.sub(r'(current)', f'{BCYN}\\1{R}', l2)
        print(l2); continue

    # Negative slack values
    if re.search(r'-\d+\.?\d*\s*ps', l):
        l2 = re.sub(r'(-\d+\.?\d*\s*ps)', f'{RED}\\1{R}', l)
        l2 = re.sub(r'(\[\d+\])', f'{YEL}\\1{R}', l2)
        print(l2); continue

    # Positive savings with arrow
    if re.search(r'→\s*\+\d+', l) or re.search(r'->.*\+\d+', l):
        l2 = re.sub(r'(\+\d+\s*ps)', f'{GRN}\\1{R}', l)
        print(l2); continue

    # Step lines
    m2 = re.match(r'^(\s*Step \d+:)(.*)', l)
    if m2:
        l2 = f"{BCYN}{m2.group(1)}{R}{m2.group(2)}"
        l2 = re.sub(r'(\+\s*\d+[-–]?\d*\s*ps)', f'{GRN}\\1{R}', l2)
        print(l2); continue

    # Table rows with savings
    if '│' in l and re.search(r'\d+ps', l):
        l2 = l
        l2 = re.sub(r'(P1[^│]*)', f'{BRED}\\1{R}', l2)
        l2 = re.sub(r'(P2[^│]*)', f'{BYEL}\\1{R}', l2)
        l2 = re.sub(r'(P3[^│]*)', f'{BGRN}\\1{R}', l2)
        l2 = re.sub(r'(FREE)', f'{BGRN}\\1{R}', l2)
        l2 = re.sub(r'(\d+-\d+ps)', f'{GRN}\\1{R}', l2)
        print(l2); continue

    # Table header/separator rows
    if '┌' in l or '├' in l or '└' in l or '───' in l:
        print(f"{DIM}{l}{R}"); continue

    # BEFORE/AFTER labels
    if 'BEFORE:' in l:
        print(re.sub(r'(BEFORE:)', f'{RED}\\1{R}', l)); continue
    if 'AFTER:' in l:
        print(re.sub(r'(AFTER:)', f'{GRN}\\1{R}', l)); continue

    # KEY INSIGHT
    if 'KEY INSIGHT' in l:
        print(f"{BYEL}{l}{R}"); continue

    # ABUTTED
    if 'ABUTTED' in l:
        print(re.sub(r'(ABUTTED[!]*)', f'{BYEL}\\1{R}', l)); continue

    # HOLD STATUS header
    if 'HOLD STATUS' in l:
        print(f"{BYEL}{l}{R}"); continue

    # NO FUNCTIONAL HOLD RISK
    if 'NO FUNCTIONAL HOLD RISK' in l:
        print(f"{BGRN}{l}{R}"); continue

    # Hold data source
    if 'Hold data source' in l or 'func.min_high' in l:
        print(f"{DIM}{l}{R}"); continue

    # /SI pin (scan) vs /D pin (functional)
    if '/SI pin' in l and '│' not in l:
        l2 = re.sub(r'(/SI pin)', f'{GRN}\\1{R}', l)
        l2 = re.sub(r'(-\d+ps)', f'{YEL}\\1{R}', l2)
        print(l2); continue
    if '/D pin' in l and '│' not in l:
        l2 = re.sub(r'(/D pin)', f'{BRED}\\1{R}', l)
        print(l2); continue

    # WARNING lines
    if 'WARNING' in l and '⚠️' in l:
        print(f"{BRED}{l}{R}"); continue
    # ⚠️ lines without WARNING keyword (real data warnings)
    if '⚠️' in l and 'WARNING' not in l:
        print(f"{RED}{l}{R}"); continue

    # FINDING lines
    if re.match(r'\s+FINDING', l):
        print(f"{BCYN}{l}{R}"); continue

    # REAL DATA / DEF+XML / CONCLUSION / PARTITION BOUNDARY
    if 'REAL DATA' in l:
        l2 = re.sub(r'(REAL DATA[^:]*:?)', f'{BMAG}\\1{R}', l)
        print(l2); continue
    if 'CONCLUSION' in l and '─' not in l and '│' not in l:
        print(f"{BGRN}{l}{R}"); continue
    if 'PARTITION BOUNDARY' in l:
        l2 = re.sub(r'(PARTITION BOUNDARY)', f'{BRED}\\1{R}', l)
        print(l2); continue

    # OPTION A / OPTION B labels
    if re.match(r'\s+OPTION [AB]', l):
        if 'RECOMMENDED' in l:
            l2 = re.sub(r'(RECOMMENDED)', f'{BGRN}\\1{R}', l)
            print(f"{BCYN}{l2}{R}"); continue
        elif 'LOW PRIORITY' in l:
            l2 = re.sub(r'(LOW PRIORITY)', f'{YEL}\\1{R}', l)
            print(f"{CYN}{l2}{R}"); continue
        print(f"{BCYN}{l}{R}"); continue

    # .tp file references
    if '.tp' in l and 'File:' in l:
        l2 = re.sub(r'(icore\.\S+\.tp)', f'{BMAG}\\1{R}', l)
        print(l2); continue

    # RULE: Never move FFs
    if l.strip().startswith('RULE:'):
        print(f"{BYEL}{l}{R}"); continue

    # LOW PRIORITY label in ALTERNATIVE
    if 'LOW PRIORITY' in l:
        l2 = re.sub(r'(LOW PRIORITY)', f'{YEL}\\1{R}', l)
        print(f"{CYN}{l2}{R}"); continue

    # CLOCK IMPACT header
    if 'CLOCK IMPACT IF FF MOVES' in l:
        print(f"{BYEL}{l}{R}"); continue

    # RE-CALCULATE / RE-EVALUATE
    if 'RE-CALCULATE' in l or 'RE-EVALUATE' in l:
        l2 = re.sub(r'(RE-CALCULATE|RE-EVALUATE)', f'{BYEL}\\1{R}', l)
        print(l2); continue

    # NOTE/ALTERNATIVE
    if l.strip().startswith('NOTE:') or l.strip().startswith('ALTERNATIVE'):
        print(f"{CYN}{l}{R}"); continue

    # Technique labels A) B) C) D)
    m3 = re.match(r'^(\s*)([A-D]\))(.*)', l)
    if m3:
        print(f"{m3.group(1)}{BCYN}{m3.group(2)}{R}{m3.group(3)}"); continue

    # TOTAL EXPECTED
    if 'TOTAL EXPECTED' in l:
        l2 = re.sub(r'(\d+-\d+ps)', f'{BGRN}\\1{R}', l)
        print(f"{B}{l2}{R}"); continue

    # conservative/optimistic
    if 'conservative' in l:
        print(re.sub(r'(-\d+ps)', f'{RED}\\1{R}', l)); continue
    if 'optimistic' in l:
        print(re.sub(r'(\+\d+ps)', f'{BGRN}\\1{R}', l)); continue

    # Bits closed
    if 'nearly all' in l:
        print(f"{GRN}{l}{R}"); continue

    # Default
    print(l)
PYEOF

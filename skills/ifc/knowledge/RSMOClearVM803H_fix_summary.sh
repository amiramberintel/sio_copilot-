#!/bin/bash
#===============================================================================
# RSMOClearVM803H_fix_summary.sh — Colorized viewer for fix summary
# Usage: bash RSMOClearVM803H_fix_summary.sh
#        or: source RSMOClearVM803H_fix_summary.sh
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT="$SCRIPT_DIR/RSMOClearVM803H_fix_summary.txt"

if [ ! -f "$INPUT" ]; then
    echo "ERROR: $INPUT not found"
    exit 1
fi

# Colors
R=$'\033[1;31m'    # Red bold
G=$'\033[1;32m'    # Green bold
Y=$'\033[1;33m'    # Yellow bold
B=$'\033[1;34m'    # Blue bold
M=$'\033[1;35m'    # Magenta bold
C=$'\033[1;36m'    # Cyan bold
W=$'\033[1;37m'    # White bold
DR=$'\033[0;31m'   # Dark red
DG=$'\033[0;32m'   # Dark green
DY=$'\033[0;33m'   # Dark yellow
DC=$'\033[0;36m'   # Dark cyan
DM=$'\033[0;35m'   # Dark magenta
BG_R=$'\033[41m'   # Red background
BG_G=$'\033[42m'   # Green background
BG_Y=$'\033[43m'   # Yellow background
BG_B=$'\033[44m'   # Blue background
N=$'\033[0m'       # Reset

sed -E \
    -e "s/^(=+)/${M}\1${N}/g" \
    -e "s/^(━+)/${DM}\1${N}/g" \
    -e "s/^(─+)/${DC}\1${N}/g" \
    -e "s/^(  ─+)/${DC}\1${N}/g" \
    \
    -e "s/(RSMOClearVM803H)/${R}\1${N}/g" \
    -e "s/(RORtLdIncM904H)/${Y}\1${N}/g" \
    -e "s/(ROBEarlyQualJumpM304H)/${C}\1${N}/g" \
    -e "s/(ROMOClearStallM901H)/${DC}\1${N}/g" \
    -e "s/(RSMOClearVM804H)/${DC}\1${N}/g" \
    -e "s/(rsmoclearvm803h)/${R}\1${N}/g" \
    -e "s/(rsmoclearspecstallm901h)/${DM}\1${N}/g" \
    -e "s/(rsmsidmoclearvm803h)/${DM}\1${N}/g" \
    \
    -e "s/(FIX #[0-9]+:[^|]*)/${W}${BG_B}\1${N}/g" \
    -e "s/(COMBINED FIX STRATEGY)/${W}${BG_B} \1 ${N}/g" \
    -e "s/(SPEC PROJECTION AFTER FIXES)/${W}${BG_B} \1 ${N}/g" \
    \
    -e "s/(PATH OVERVIEW)/${W}${BG_B} \1 ${N}/g" \
    -e "s/(SPECS \(from)/${W}${BG_B} SPECS ${N}${DY}(from/g" \
    -e "s/(ALL FAILING ENDPOINTS)/${W}${BG_B} \1 ${N}/g" \
    -e "s/(SP FF.*MULTI-BIT MERGE PROBLEM)/${W}${BG_B} \1 ${N}/g" \
    -e "s/(GATE-BY-GATE PATH DETAIL)/${W}${BG_B} \1 ${N}/g" \
    -e "s/(DELAY BREAKDOWN)/${W}${BG_B} \1 ${N}/g" \
    -e "s/(SIMILAR SIGNALS.*reference.*)/${W}${BG_B} \1 ${N}/g" \
    -e "s/(END OF FIX SUMMARY)/${W}${BG_B} \1 ${N}/g" \
    \
    -e "s/(Slack:.*-[0-9]+\.[0-9]+ps)/${R}\1${N}/g" \
    -e "s/( slack=.-[0-9]+)/${R}\1${N}/g" \
    -e "s/(-71\.6ps|-71ps|-64ps|-49ps)/${R}\1${N}/g" \
    -e "s/(-63\.[0-9]+ps)/${R}\1${N}/g" \
    -e "s/(VIOLATED)/${R}\1${N}/g" \
    -e "s/(OVER by [0-9.]+ps)/${R}\1${N}/g" \
    -e "s/(4x over)/${R}\1${N}/g" \
    -e "s/(4x over budget)/${R}\1${N}/g" \
    -e "s/(OVER by [0-9.]+-[0-9.]+ps)/${R}\1${N}/g" \
    \
    -e "s/(POR Slack:.*\+[0-9]+ps)/${G}\1${N}/g" \
    -e "s/(\+17ps|\+30ps|\+19ps|\+18ps|\+38ps)/${G}\1${N}/g" \
    -e "s/(UNDER by [0-9.]+ps)/${G}\1${N}/g" \
    -e "s/(UNDER by [0-9.]+-[0-9.]+ps)/${G}\1${N}/g" \
    -e "s/(MEETS SPEC)/${G}\1${N}/g" \
    -e "s/(within spec)/${G}\1${N}/g" \
    -e "s/(already within spec)/${G}\1${N}/g" \
    -e "s/(✓)/${G}\1${N}/g" \
    -e "s/(SAFE)/${G}\1${N}/g" \
    \
    -e "s/(WORST)/${R}\1${N}/g" \
    -e "s/(WEAK [A-Z0-9!]+)/${Y}\1${N}/g" \
    -e "s/(LONG)/${Y}\1${N}/g" \
    -e "s/(BAD MERGE)/${R}\1${N}/g" \
    -e "s/(0 failing paths)/${G}\1${N}/g" \
    -e "s/(6 failing paths)/${R}\1${N}/g" \
    -e "s/(FIRST LOGIC GATE)/${C}\1${N}/g" \
    \
    -e "s/(281um)/${R}\1${N}/g" \
    -e "s/(152um)/${Y}\1${N}/g" \
    -e "s/(134um)/${Y}\1${N}/g" \
    -e "s/(786um)/${R}\1${N}/g" \
    -e "s/(360um)/${Y}\1${N}/g" \
    -e "s/(1146um)/${R}\1${N}/g" \
    -e "s/(493um)/${G}\1${N}/g" \
    \
    -e "s/(ULVT)/${G}\1${N}/g" \
    -e "s/(ULVTLL)/${DG}\1${N}/g" \
    -e "s/( LVT )/${Y} \1 ${N}/g" \
    -e "s/(\*LVT\*)/${Y}\1${N}/g" \
    -e "s/(\*ULVT\*)/${G}\1${N}/g" \
    \
    -e "s/(par_ooo_int)/${B}\1${N}/g" \
    -e "s/(par_ooo_vec)/${C}\1${N}/g" \
    -e "s/(par_meu)/${DY}\1${N}/g" \
    -e "s/(par_pmh)/${DY}\1${N}/g" \
    -e "s/(par_fe)/${DY}\1${N}/g" \
    -e "s/(par_msid)/${DY}\1${N}/g" \
    \
    -e "s/(mclk_ooo_int)/${B}\1${N}/g" \
    -e "s/(mclk_ooo_vec)/${C}\1${N}/g" \
    -e "s/(mclk_fe)/${DY}\1${N}/g" \
    -e "s/(mclk_msid)/${DY}\1${N}/g" \
    \
    -e "s/(Gain: \+[0-9]+-[0-9]+ps)/${G}\1${N}/g" \
    -e "s/(\+[0-9]+-[0-9]+\.?[0-9]*ps)/${G}\1${N}/g" \
    -e "s/(\+[0-9]+\.[0-9]+ps)/${G}\1${N}/g" \
    -e "s/(closes fully)/${G}\1${N}/g" \
    -e "s/(closes with large margin)/${G}\1${N}/g" \
    -e "s/(MEETS SPEC \([^)]*\))/${G}\1${N}/g" \
    -e "s/(95%)/${G}\1${N}/g" \
    \
    -e "s/(Owner: [a-zA-Z_ ]+)/${DY}\1${N}/g" \
    -e "s/(ETA: [^|]+)/${DC}\1${N}/g" \
    \
    -e "s/(STRATEGY A)/${G}\1${N}/g" \
    -e "s/(STRATEGY B)/${C}\1${N}/g" \
    -e "s/(RECOMMENDATION:)/${W}\1${N}/g" \
    -e "s/(Probability of closure: ~[0-9]+-[0-9]+%)/${Y}\1${N}/g" \
    -e "s/(Probability of closure: ~99%)/${G}\1${N}/g" \
    \
    -e "s/(RISK|Risk)/${Y}\1${N}/g" \
    -e "s/( LOW )/${G} \1 ${N}/g" \
    -e "s/( MEDIUM )/${Y} \1 ${N}/g" \
    -e "s/( HIGH )/${R} \1 ${N}/g" \
    -e "s/( NONE )/${G} \1 ${N}/g" \
    \
    -e "s/(MB2)/${M}\1${N}/g" \
    -e "s/(MBIT)/${M}\1${N}/g" \
    -e "s/(Multi-Bit 2)/${M}\1${N}/g" \
    -e "s/(de-merge|DE-MERGE)/${M}\1${N}/g" \
    -e "s/(dont_merge|set_dont_merge)/${M}\1${N}/g" \
    -e "s/(create_bound)/${M}\1${N}/g" \
    -e "s/(REVISED)/${Y}\1${N}/g" \
    -e "s/(REVISED ↓)/${R}\1${N}/g" \
    -e "s/(D2 input)/${Y}\1${N}/g" \
    -e "s/(MANDATORY)/${R}\1${N}/g" \
    -e "s/(CANNOT close)/${R}\1${N}/g" \
    -e "s/(CANNOT meet spec)/${R}\1${N}/g" \
    -e "s/(BREAKS D2 input path)/${R}\1${N}/g" \
    -e "s/(\+38\.6ps)/${G}\1${N}/g" \
    -e "s/(safe range)/${G}\1${N}/g" \
    -e "s/(Spec renegotiation)/${Y}\1${N}/g" \
    -e "s/(WARNING:)/${Y}\1${N}/g" \
    -e "s/(INPUT PATH CONSTRAINT)/${R}\1${N}/g" \
    -e "s/(LIMITS MOVEMENT)/${R}\1${N}/g" \
    -e "s/(PLACEMENT TRADEOFF)/${Y}\1${N}/g" \
    -e "s/(⚠️)/${Y}\1${N}/g" \
    -e "s/(✗)/${R}\1${N}/g" \
    \
    -e "s/(TIP)/${C}\1${N}/g" \
    -e "s/(half shield|HALF SHIELD)/${C}\1${N}/g" \
    -e "s/(M17|M18)/${C}\1${N}/g" \
    -e "s/(layer_cutting_distance)/${DC}\1${N}/g" \
    -e "s/(repeater)/${DC}\1${N}/g" \
    \
    -e "s/(hierarchy cross:)/${DY}\1${N}/g" \
    -e "s/(spec=[0-9.]+)/${Y}\1${N}/g" \
    -e "s/(34\.0ps|34\.0)/${Y}\1${N}/g" \
    -e "s/(134\.0ps|134\.0)/${C}\1${N}/g" \
    -e "s/(140\.5ps|140\.5)/${R}\1${N}/g" \
    -e "s/(115\.2ps|115\.2)/${G}\1${N}/g" \
    -e "s/(gilkeren)/${DY}\1${N}/g" \
    \
    -e "s/(SP FF|SP )/${B}\1${N}/g" \
    -e "s/(EP FF|EP )/${C}\1${N}/g" \
    -e "s/(Q1|Q2)/${M}\1${N}/g" \
    -e "s/(D1→D4)/${G}\1${N}/g" \
    -e "s/(LVT → ULVT)/${G}\1${N}/g" \
    -e "s/(ULVTLL → ULVT)/${G}\1${N}/g" \
    \
    -e "s/(crosstalk)/${DY}\1${N}/g" \
    -e "s/(DTrans)/${DY}\1${N}/g" \
    -e "s/(input trans [0-9.]+ps)/${Y}\1${N}/g" \
    -e "s/(overloaded!)/${R}\1${N}/g" \
    -e "s/(very high!)/${R}\1${N}/g" \
    \
    -e "s/(┌|┐|└|┘|├|┤|│|─|┬|┴|┼)/${DC}\1${N}/g" \
    \
    "$INPUT" | less -R

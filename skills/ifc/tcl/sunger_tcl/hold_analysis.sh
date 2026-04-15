#!/bin/bash
# hold_analysis.sh - Hold path fixability analysis
#
# Queries hold path at min_nom corner, then checks worst-case setup and hold
# slack at each data path pin across multiple corners.
#
# Usage: hold_analysis.sh <endpoint_pin>
#
# Output:
#   Startpoint / Endpoint header
#   7-column table:
#     DATA PATH | MAX HV | MAX NOM | MAX MED | MIN LOW | MIN NOM | MIN FAST

set -uo pipefail

EP="${1:-}"

if [[ -z "$EP" ]]; then
    echo "Usage: $0 <endpoint_pin>"
    echo "Example: $0 icore0/par_ooo_int/rs_int/.../D1"
    exit 1
fi

PT_CLIENT="/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl"

# Corner definitions: tag|model|delay_type
CORNERS=(
    "max_hv|modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical|max"
    "max_med|modelb_gfcn2clienta0_bu_prp_func.max_med.T_85.typical|max"
    "max_nom|modelb_gfcn2clienta0_bu_prp_func.max_nom.T_85.typical|max"
    "max_low|modelb_gfcn2clienta0_bu_prp_func.max_low.T_85.typical|max"
    "min_low|modelb_gfcn2clienta0_bu_prp_func.min_low.T_85.typical|min"
    "min_nom|modelb_gfcn2clienta0_bu_prp_func.min_nom.T_85.typical|min"
    "min_fast|modelb_gfcn2clienta0_bu_prp_fresh.min_fast.F_125.rcworst_CCworst|min"
    "min_fast_cold|modelb_gfcn2clienta0_bu_prp_fresh.min_fast_cold.F_M40.rcworst_CCworst|min"
)

HOLD_MODEL="modelb_gfcn2clienta0_bu_prp_func.min_nom.T_85.typical"

TMPDIR=$(mktemp -d /tmp/hold_analysis.XXXXXX)
trap "rm -rf $TMPDIR" EXIT

# Helper: format slack value with MET/VIOL
fmt_slack() {
    local val="$1"
    val=$(echo "$val" | tr -d '[:space:]')
    if [[ -z "$val" ]]; then
        echo "N/A"
    elif [[ "$val" == -* ]]; then
        printf "%+.1f VIOL" "$val"
    else
        printf "+%.1f MET" "$val"
    fi
}

echo ">>> Querying hold path (min_nom) and capture clock latency (max_high)..."

# Step 1: Get hold path and max_high setup report in parallel
"$PT_CLIENT" -m "$HOLD_MODEL" \
    -c "report_timing -delay_type min -to *${EP} -nosplit -input -max_paths 1" 2>/dev/null \
    > "${TMPDIR}/hold_rpt.txt" &
PID_HOLD=$!

HV_MODEL=$(echo "${CORNERS[0]}" | cut -d'|' -f2)
"$PT_CLIENT" -m "$HV_MODEL" \
    -c "report_timing -delay_type max -to *${EP} -nosplit -max_paths 1" 2>/dev/null \
    > "${TMPDIR}/hv_rpt.txt" &
PID_HV=$!

wait $PID_HOLD $PID_HV

HOLD_RPT=$(cat "${TMPDIR}/hold_rpt.txt")
HV_RPT=$(cat "${TMPDIR}/hv_rpt.txt")

if echo "$HOLD_RPT" | grep -q "no paths"; then
    echo "ERROR: No hold path found for endpoint: $EP"
    exit 1
fi

if [[ -z "$HOLD_RPT" ]]; then
    echo "ERROR: No response from PT server. Check endpoint pin and server status."
    exit 1
fi

# Extract capture clock latency from max_high report (required time section)
# Match "clock network delay" or "clock latency" after "data arrival time"
# Incr column (3rd number) = actual latency
CAPTURE_CLK_LATENCY=$(echo "$HV_RPT" | \
    awk '/data arrival time/ {found=1} found && /clock (network delay|latency)/ {line=$0} END {print line}' | \
    grep -oP '[0-9]+\.[0-9]+' | head -3 | tail -1 || true)

# Step 2: Extract startpoint and endpoint info
STARTPOINT=$(echo "$HOLD_RPT" | grep "Startpoint:" | sed 's/.*Startpoint: //')
ENDPOINT_INFO=$(echo "$HOLD_RPT" | grep "Endpoint:" | sed 's/.*Endpoint: //')

# Extract hold slack (Path column value before "slack")
HOLD_SLACK=$(echo "$HOLD_RPT" | grep -oP '[\-]?[0-9]+\.[0-9]+(?=\s+slack)' | tail -1 || true)

# Step 3: Extract data path pins
# Get lines between FIRST "clock network delay" and FIRST "data arrival time"
# with r/f indicator. Skip the first pin (startpoint enable/clock pin).
mapfile -t PINS < <(echo "$HOLD_RPT" | \
    awk '/clock network delay/ && !found {found=1; next} found && /data arrival time/ {exit} found {print}' | \
    grep -oP '[0-9]+\.[0-9]+ [rf]\s+\K\S+' | \
    tail -n +2 || true)

if [[ ${#PINS[@]} -eq 0 ]]; then
    echo "ERROR: Could not extract data path pins from hold report."
    echo ""
    echo "Hold report:"
    echo "$HOLD_RPT"
    exit 1
fi

NUM_PINS=${#PINS[@]}
NUM_CORNERS=${#CORNERS[@]}
TOTAL_QUERIES=$((NUM_PINS * NUM_CORNERS))
echo ">>> Found ${NUM_PINS} data path pins. Querying ${NUM_CORNERS} corners (${TOTAL_QUERIES} queries in parallel)..."

# Step 4: Query all corners for each pin in parallel
# For pin 0 + max_hv, also save full report to extract launch clock latency
for i in "${!PINS[@]}"; do
    pin="${PINS[$i]}"
    for corner_def in "${CORNERS[@]}"; do
        IFS='|' read -r tag model delay_type <<< "$corner_def"
        if [[ "$i" -eq 0 && "$tag" == "max_hv" ]]; then
            # Save full report for launch clock latency extraction
            ( rpt=$("$PT_CLIENT" -m "$model" \
                -c "report_timing -delay_type ${delay_type} -through ${pin} -nosplit -max_paths 1" 2>/dev/null)
              echo "$rpt" > "${TMPDIR}/hv_full_rpt.txt"
              slack=$(echo "$rpt" | grep -oP '[\-]?[0-9]+\.[0-9]+(?=\s+slack)' | tail -1 || true)
              echo "${slack}" > "${TMPDIR}/${tag}_${i}.txt"
            ) &
        else
            ( slack=$("$PT_CLIENT" -m "$model" \
                -c "report_timing -delay_type ${delay_type} -through ${pin} -nosplit -max_paths 1" 2>/dev/null | \
                grep -oP '[\-]?[0-9]+\.[0-9]+(?=\s+slack)' | tail -1 || true)
              echo "${slack}" > "${TMPDIR}/${tag}_${i}.txt"
            ) &
        fi
    done
done

wait
echo ""

# Extract launch clock latency from max_high report (data arrival section)
# First "clock network delay" or "clock latency" line, Incr column (3rd number)
LAUNCH_CLK_LATENCY=$(cat "${TMPDIR}/hv_full_rpt.txt" 2>/dev/null | \
    awk '/clock (network delay|latency)/ {print; exit}' | \
    grep -oP '[0-9]+\.[0-9]+' | head -3 | tail -1 || true)

# Step 5: Print header
echo "Startpoint: $STARTPOINT"
echo "Endpoint:   $ENDPOINT_INFO"
echo "Hold slack (min_nom): ${HOLD_SLACK}ps"
if [[ -n "$LAUNCH_CLK_LATENCY" ]] && awk "BEGIN{exit !($LAUNCH_CLK_LATENCY < 80)}" 2>/dev/null; then
    echo -e "Launch clock latency (max_high): \033[1;31m${LAUNCH_CLK_LATENCY}ps\033[0m"
else
    echo "Launch clock latency (max_high): ${LAUNCH_CLK_LATENCY}ps"
fi
if [[ -n "$CAPTURE_CLK_LATENCY" ]] && awk "BEGIN{exit !($CAPTURE_CLK_LATENCY > 90)}" 2>/dev/null; then
    echo -e "Capture clock latency (max_high): \033[1;31m${CAPTURE_CLK_LATENCY}ps\033[0m"
else
    echo "Capture clock latency (max_high): ${CAPTURE_CLK_LATENCY}ps"
fi
echo ""

# Step 6: Build and print the table
COL_W=14  # width per slack column
CORNER_TAGS=("max_hv" "max_med" "max_nom" "max_low" "min_low" "min_nom" "min_fast" "min_fast_cold")

# Find max pin name length for formatting (cap at 90)
MAX_LEN=9
for pin in "${PINS[@]}"; do
    len=${#pin}
    (( len > MAX_LEN )) && MAX_LEN=$len
done
(( MAX_LEN > 90 )) && MAX_LEN=90

# Read all raw slack values into arrays and find best (max) per column
declare -A RAW_SLACK
declare -A BEST_SLACK

for tag in "${CORNER_TAGS[@]}"; do
    BEST_SLACK[$tag]=""
done

for i in "${!PINS[@]}"; do
    for tag in "${CORNER_TAGS[@]}"; do
        val=$(cat "${TMPDIR}/${tag}_${i}.txt" 2>/dev/null)
        val=$(echo "$val" | tr -d '[:space:]')
        RAW_SLACK["${tag}_${i}"]="$val"
        if [[ -n "$val" ]]; then
            best="${BEST_SLACK[$tag]}"
            if [[ -z "$best" ]] || awk "BEGIN{exit !($val > $best)}" 2>/dev/null; then
                BEST_SLACK[$tag]="$val"
            fi
        fi
    done
done

# ANSI codes
BOLD_GREEN='\033[1;32m'
RESET='\033[0m'

# Column display names (must match CORNERS order)
COL_NAMES=("MAX HV" "MAX MED" "MAX NOM" "MAX LOW" "MIN LOW" "MIN NOM" "MIN FAST" "MIN FAST COLD")

# Header
SEP_PIN=$(printf '%0.s-' $(seq 1 $MAX_LEN))
SEP_COL=$(printf '%0.s-' $(seq 1 $COL_W))

header=$(printf "%-${MAX_LEN}s" "DATA PATH")
sep="$SEP_PIN"
for name in "${COL_NAMES[@]}"; do
    header+=$(printf " | %${COL_W}s" "$name")
    sep+="-+-${SEP_COL}"
done
echo "$header"
echo "$sep"

# Each pin row
for i in "${!PINS[@]}"; do
    pin="${PINS[$i]}"

    # Truncate long pin names from the left
    if (( ${#pin} > MAX_LEN )); then
        display_pin="...${pin: -$((MAX_LEN-3))}"
    else
        display_pin="$pin"
    fi

    row=$(printf "%-${MAX_LEN}s" "$display_pin")

    for tag in "${CORNER_TAGS[@]}"; do
        val="${RAW_SLACK[${tag}_${i}]}"
        cell=$(fmt_slack "$val")
        formatted=$(printf "%${COL_W}s" "$cell")

        # Highlight best value only for setup (max) corners
        if [[ "$tag" == max_* && -n "$val" && -n "${BEST_SLACK[$tag]}" ]] && awk "BEGIN{exit !($val == ${BEST_SLACK[$tag]})}" 2>/dev/null; then
            row+=$(printf " | ${BOLD_GREEN}%s${RESET}" "$formatted")
        else
            row+=$(printf " | %s" "$formatted")
        fi
    done

    echo -e "$row"
done

echo ""
echo ">>> Hold analysis complete."

#!/bin/bash
# hold_analysis_with_fixes.sh - Hold path fixability analysis + delay cell fix recommendation
#
# Queries hold path at min_nom corner, then checks worst-case setup and hold
# slack at each data path pin across multiple corners.
# Then uses buffer_cell_database_all_corners.csv to recommend delay cells.
#
# Usage: hold_analysis_with_fixes.sh <endpoint_pin> [buffer_db_csv]
#
# Arguments:
#   endpoint_pin  - full or partial endpoint pin name
#   buffer_db_csv - path to buffer_cell_database_all_corners.csv
#                   (default: /nfs/site/disks/gilkeren_wa/copilot/buffer_cell_database_all_corners.csv)
#
# Output:
#   1. Hold/Setup slack table across corners
#   2. Delay cell fix recommendations (LVT only, avoids ULVT)

set -uo pipefail

EP="${1:-}"
BUFFER_DB="${2:-/nfs/site/disks/gilkeren_wa/copilot/buffer_cell_database_all_corners.csv}"

if [[ -z "$EP" ]]; then
    echo "Usage: $0 <endpoint_pin> [buffer_db_csv]"
    echo "Example: $0 icore0/par_ooo_int/rs_int/.../D1"
    echo ""
    echo "Default buffer DB: /nfs/site/disks/gilkeren_wa/copilot/buffer_cell_database_all_corners.csv"
    exit 1
fi

if [[ ! -f "$BUFFER_DB" ]]; then
    echo "WARNING: Buffer database not found: $BUFFER_DB"
    echo "         Fix recommendations will be skipped."
    echo "         Generate with: merge_buffer_database.sh <work_area>"
    BUFFER_DB=""
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

# =====================================================================
#  FIX RECOMMENDATION using buffer cell database
# =====================================================================
if [[ -z "$BUFFER_DB" ]]; then
    exit 0
fi

# Find worst hold per corner at insertion point, best insertion point (highest setup margin)
WORST_HOLD=""
BEST_INSERT_MED=""
BEST_INSERT_IDX=""
WORST_HOLD_PIN=""
WORST_HOLD_CORNER=""

# First pass: find worst hold across ALL pins and ALL hold corners
for i in "${!PINS[@]}"; do
    for tag in "${CORNER_TAGS[@]}"; do
        if [[ "$tag" == min_* ]]; then
            hval="${RAW_SLACK[${tag}_${i}]}"
            if [[ -n "$hval" ]]; then
                if [[ -z "$WORST_HOLD" ]] || awk "BEGIN{exit !($hval < $WORST_HOLD)}" 2>/dev/null; then
                    WORST_HOLD="$hval"
                    WORST_HOLD_PIN="${PINS[$i]}"
                    WORST_HOLD_CORNER="$tag"
                fi
            fi
        fi
    done
done

# Second pass: find INPUT pin with HIGHEST worst-case setup slack (best insertion point)
# Output pins (Z, ZN, Y, Q, QN, CO, S, SO) are not valid insertion points;
# delay cells are inserted at cell input pins.
for i in "${!PINS[@]}"; do
    pin="${PINS[$i]}"
    pin_leaf="${pin##*/}"
    # Skip output pins (including MBIT numbered variants like Q1-Q8, ZN1-ZN8)
    if [[ "$pin_leaf" =~ ^(Z|ZN|Y|Q|QN|CO|S|SO|X|ZD)[0-9]*$ ]]; then
        continue
    fi
    sval="${RAW_SLACK[max_med_${i}]}"
    if [[ -n "$sval" ]]; then
        if [[ -z "$BEST_INSERT_MED" ]] || awk "BEGIN{exit !($sval > $BEST_INSERT_MED)}" 2>/dev/null; then
            BEST_INSERT_MED="$sval"
            BEST_INSERT_IDX="$i"
        fi
    fi
done

# Get the insertion point pin name and its setup/hold slacks across all corners
if [[ -n "$BEST_INSERT_IDX" ]]; then
    INSERT_PIN="${PINS[$BEST_INSERT_IDX]}"
    # Find minimum setup across ALL max corners at insertion point (for display)
    SETUP_BUDGET=""
    for tag in "${CORNER_TAGS[@]}"; do
        if [[ "$tag" == max_* ]]; then
            cval="${RAW_SLACK[${tag}_${BEST_INSERT_IDX}]}"
            if [[ -n "$cval" ]]; then
                if [[ -z "$SETUP_BUDGET" ]] || awk "BEGIN{exit !($cval < $SETUP_BUDGET)}" 2>/dev/null; then
                    SETUP_BUDGET="$cval"
                fi
            fi
        fi
    done
    SETUP_BUDGET="${SETUP_BUDGET:-0}"
    # Collect hold slacks at insertion point for each hold corner
    HOLD_SLACK_MIN_LOW="${RAW_SLACK[min_low_${BEST_INSERT_IDX}]:-}"
    HOLD_SLACK_MIN_NOM="${RAW_SLACK[min_nom_${BEST_INSERT_IDX}]:-}"
    HOLD_SLACK_MIN_FAST="${RAW_SLACK[min_fast_${BEST_INSERT_IDX}]:-}"
    HOLD_SLACK_MIN_FAST_COLD="${RAW_SLACK[min_fast_cold_${BEST_INSERT_IDX}]:-}"
    # Collect setup slacks at insertion point for each max corner
    SETUP_SLACK_MAX_HV="${RAW_SLACK[max_hv_${BEST_INSERT_IDX}]:-}"
    SETUP_SLACK_MAX_MED="${RAW_SLACK[max_med_${BEST_INSERT_IDX}]:-}"
    SETUP_SLACK_MAX_NOM="${RAW_SLACK[max_nom_${BEST_INSERT_IDX}]:-}"
    SETUP_SLACK_MAX_LOW="${RAW_SLACK[max_low_${BEST_INSERT_IDX}]:-}"
else
    INSERT_PIN=""
    SETUP_BUDGET="0"
    HOLD_SLACK_MIN_LOW=""
    HOLD_SLACK_MIN_NOM=""
    HOLD_SLACK_MIN_FAST=""
    HOLD_SLACK_MIN_FAST_COLD=""
    SETUP_SLACK_MAX_HV=""
    SETUP_SLACK_MAX_MED=""
    SETUP_SLACK_MAX_NOM=""
    SETUP_SLACK_MAX_LOW=""
fi

if [[ -z "$WORST_HOLD" ]] || awk "BEGIN{exit !($WORST_HOLD >= 0)}" 2>/dev/null; then
    echo ""
    echo ">>> No hold violation detected. Skipping fix recommendation."
    exit 0
fi

# Negate hold slack to get required fix amount
HOLD_FIX_NEEDED=$(awk "BEGIN{printf \"%.1f\", -1 * $WORST_HOLD}")

echo ""
echo "==========================================================================="
echo " DELAY CELL FIX RECOMMENDATION (LVT only)"
echo "==========================================================================="
echo " Worst hold violation: ${WORST_HOLD}ps (${WORST_HOLD_CORNER})"
echo " Fix needed          : ${HOLD_FIX_NEEDED}ps"
echo ""
echo " Hold slacks at insertion point:"
[[ -n "$HOLD_SLACK_MIN_LOW" ]]       && echo "   min_low      : ${HOLD_SLACK_MIN_LOW}ps"
[[ -n "$HOLD_SLACK_MIN_NOM" ]]       && echo "   min_nom      : ${HOLD_SLACK_MIN_NOM}ps"
[[ -n "$HOLD_SLACK_MIN_FAST" ]]      && echo "   min_fast     : ${HOLD_SLACK_MIN_FAST}ps"
[[ -n "$HOLD_SLACK_MIN_FAST_COLD" ]] && echo "   min_fast_cold: ${HOLD_SLACK_MIN_FAST_COLD}ps"
echo ""
echo " Best insertion point (highest setup margin):"
echo "   Pin: ${INSERT_PIN}"
echo "   Setup margin: +${SETUP_BUDGET}ps (worst across all max corners)"
echo "---------------------------------------------------------------------------"

python3 << PYEOF
import csv, sys

dbfile = "$BUFFER_DB"

# Hold slacks at insertion point per corner (what we need to fix)
hold_slacks = {}
for tag, val in [("min_low", "$HOLD_SLACK_MIN_LOW"), ("min_nom", "$HOLD_SLACK_MIN_NOM"),
                 ("min_fast", "$HOLD_SLACK_MIN_FAST"), ("min_fast_cold", "$HOLD_SLACK_MIN_FAST_COLD")]:
    if val and val != "":
        try:
            hold_slacks[tag] = float(val)
        except ValueError:
            pass

# Setup slacks at insertion point per max corner
setup_slacks = {}
for tag, val in [("max_hv", "$SETUP_SLACK_MAX_HV"), ("max_med", "$SETUP_SLACK_MAX_MED"),
                 ("max_nom", "$SETUP_SLACK_MAX_NOM"), ("max_low", "$SETUP_SLACK_MAX_LOW")]:
    if val and val != "":
        try:
            setup_slacks[tag] = float(val)
        except ValueError:
            pass

# Map corner tags to buffer DB column name substrings
corner_to_db = {
    "min_low": "func.min_low",
    "min_nom": "func.min_nom",
    "min_fast": "fresh.min_fast.F_125",  # distinguish from min_fast_cold
    "min_fast_cold": "fresh.min_fast_cold",
    "max_hv": "func.max_high",
    "max_med": "func.max_med",
    "max_nom": "func.max_nom",
    "max_low": "func.max_low",
}

with open(dbfile) as f:
    rows = list(csv.DictReader(f))

# Find column names for each corner in the DB
hold_cols = {}  # tag -> column name
setup_cols = {}  # tag -> column name
for col in rows[0].keys():
    for tag, substr in corner_to_db.items():
        if substr in col and tag not in hold_cols and tag not in setup_cols:
            if tag.startswith("min_"):
                hold_cols[tag] = col
            else:
                setup_cols[tag] = col

if not setup_cols:
    print("  ERROR: Could not find setup corner columns in buffer DB")
    sys.exit(0)

# Collect LVT delay and buffer cells with per-corner delays
cells = []
for r in rows:
    if r["vt_class"] != "LVT":
        continue
    ctype = r.get("type", "")
    if ctype not in ("DELAY", "BUF"):
        continue
    try:
        # Get delay at each hold corner
        d_hold = {}
        for tag, col in hold_cols.items():
            d_hold[tag] = float(r[col])
        # Get delay at each setup corner
        d_setup = {}
        for tag, col in setup_cols.items():
            d_setup[tag] = float(r[col])
    except (ValueError, KeyError):
        continue
    cells.append({
        "ref": r["ref_name"], "func": r.get("func", ""), "kind": ctype,
        "drive": r["drive_strength"], "count": r["instance_count"],
        "d_hold": d_hold, "d_setup": d_setup
    })

# Separate delay cells and buffer cells, sorted by min_nom delay
delay_cells = sorted([c for c in cells if c["kind"] == "DELAY"],
                     key=lambda x: x["d_hold"].get("min_nom", 0))
buf_cells = sorted([c for c in cells if c["kind"] == "BUF"],
                   key=lambda x: x["d_hold"].get("min_nom", 0))
# All fix candidates
all_fix_cells = sorted(delay_cells + buf_cells,
                       key=lambda x: x["d_hold"].get("min_nom", 0))

# Display: show delay at each hold corner
hold_tags_present = sorted(hold_slacks.keys(), key=lambda t: ["min_low","min_nom","min_fast","min_fast_cold"].index(t))
setup_tags_present = sorted(setup_slacks.keys(), key=lambda t: ["max_hv","max_med","max_nom","max_low"].index(t))

def fixes_all_hold(d_hold_vals, hold_slacks_dict):
    """Check if delay fixes ALL hold corners. Returns (fixes_all, worst_remaining)."""
    worst_rem = float('inf')
    for tag, slack in hold_slacks_dict.items():
        if slack >= 0:
            continue  # no violation at this corner
        needed = -slack
        provided = d_hold_vals.get(tag, 0)
        rem = provided - needed
        worst_rem = min(worst_rem, rem)
    return worst_rem >= 0, worst_rem if worst_rem != float('inf') else 0

def setup_safe(d_setup_vals, setup_slacks_dict):
    """Check if delay is safe for setup at ALL max corners. Returns (safe, worst_margin)."""
    worst_margin = float('inf')
    for tag, slack in setup_slacks_dict.items():
        cost = d_setup_vals.get(tag, 0)
        margin = slack - cost
        worst_margin = min(worst_margin, margin)
    return worst_margin >= 0, worst_margin if worst_margin != float('inf') else 0

# Pre-compute best_single (lowest positive hold margin that fixes all corners)
best_single = None
for d in all_fix_cells:
    all_fixed, worst_rem = fixes_all_hold(d["d_hold"], hold_slacks)
    s_safe, _ = setup_safe(d["d_setup"], setup_slacks)
    if all_fixed and s_safe and (best_single is None or worst_rem < fixes_all_hold(best_single["d_hold"], hold_slacks)[1]):
        best_single = d

best_ref = best_single["ref"] if best_single else ""
GRN = "\033[32m"
RST = "\033[0m"

def fmt_line(d, hold_tags, setup_tags):
    line = f"  {d['ref']:<42}"
    for t in hold_tags:
        line += f" {d['d_hold'].get(t, 0):>12.1f}"
    for t in setup_tags:
        line += f" {d['d_setup'].get(t, 0):>8.1f}"
    line += f" {d['count']:>8}"
    if d["ref"] == best_ref:
        line = f"  {GRN}{d['ref']:<42}"
        for t in hold_tags:
            line += f" {d['d_hold'].get(t, 0):>12.1f}"
        for t in setup_tags:
            line += f" {d['d_setup'].get(t, 0):>8.1f}"
        line += f" {d['count']:>8} ★{RST}"
    return line

print()
print("  LVT DELAY CELLS:")
hdr = f"  {'Cell':<42}"
for t in hold_tags_present:
    hdr += f" {t:>12}"
for t in setup_tags_present:
    hdr += f" {t:>8}"
hdr += f" {'Count':>8}"
print(hdr)
sep_len = 42 + 12*len(hold_tags_present) + 8*len(setup_tags_present) + 10
print("  " + "-" * sep_len)
for d in delay_cells:
    print(fmt_line(d, hold_tags_present, setup_tags_present))

# Show buffer cells with drive strength 1-4 and enough delay to be useful (min_nom > 5ps)
useful_bufs = [b for b in buf_cells if b["d_hold"].get("min_nom", 0) > 5 and b["drive"] in ("1","2","3","4")]
if useful_bufs:
    print()
    print("  LVT BUFFER CELLS (delay > 5ps, drive 1-4):")
    print(hdr)
    print("  " + "-" * sep_len)
    for d in useful_bufs:
        print(fmt_line(d, hold_tags_present, setup_tags_present))

# Single cell analysis (delay + buffer cells) - display with highlight
single_results = []
for d in all_fix_cells:
    all_fixed, worst_rem = fixes_all_hold(d["d_hold"], hold_slacks)
    s_safe, s_margin = setup_safe(d["d_setup"], setup_slacks)
    if all_fixed and s_safe:
        tag = "✓ FIXES ALL"
    elif all_fixed and not s_safe:
        tag = "✗ breaks setup"
    elif worst_rem >= -1 and s_safe:
        tag = "~ nearly fixes hold"
    elif worst_rem >= -5 and s_safe:
        tag = "close"
    else:
        continue
    single_results.append((d, worst_rem, s_margin, tag))

print()
print("  SINGLE CELL OPTIONS (must fix ALL hold & setup corners):")
print(f"  {'Cell':<42} {'h_margin':>9} {'s_margin':>9}  Status")
print("  " + "-" * 75)
for d, worst_rem, s_margin, tag in single_results:
    marker = " ★" if d is best_single else ""
    hl = GRN if d is best_single else ""
    rs = RST if d is best_single else ""
    print(f"  {hl}{d['ref']:<42} {worst_rem:>+8.1f}ps {s_margin:>+8.1f}ps  {tag}{marker}{rs}")

# Two cell combos (delay + buffer cells, LVT only)
print()
print("  TWO-CELL COMBINATIONS (LVT, must fix ALL hold & setup corners):")
combos = []
for i, a in enumerate(all_fix_cells):
    for b in all_fix_cells[i:]:
        combo_hold = {t: a["d_hold"].get(t, 0) + b["d_hold"].get(t, 0) for t in hold_slacks}
        combo_setup = {t: a["d_setup"].get(t, 0) + b["d_setup"].get(t, 0) for t in setup_slacks}
        all_fixed, worst_rem = fixes_all_hold(combo_hold, hold_slacks)
        s_safe, s_margin = setup_safe(combo_setup, setup_slacks)
        if all_fixed and s_safe:
            combos.append((a, b, combo_hold, combo_setup, worst_rem, s_margin))

combos.sort(key=lambda x: (x[4], -x[5]))  # lowest hold margin first, then most setup margin

if combos:
    print(f"  {'Combo':<55} {'h_margin':>9} {'s_margin':>9}")
    print("  " + "-" * 80)
    shown = set()
    for a, b, combo_hold, combo_setup, worst_rem, s_margin in combos[:15]:
        key = f"{a['ref']}+{b['ref']}"
        if key in shown:
            continue
        shown.add(key)
        label = a['func'] + ' + ' + b['func']
        if a['kind'] == 'BUF' or b['kind'] == 'BUF':
            label += " (buf)"
        print(f"  {label:<55} {worst_rem:>+8.1f}ps {s_margin:>+8.1f}ps  ✓")
else:
    print("  No 2-cell LVT combination fixes ALL hold & setup corners.")
    # Show near-miss combos for user judgment
    near_misses = []
    for i, a in enumerate(all_fix_cells):
        for b in all_fix_cells[i:]:
            combo_hold = {t: a["d_hold"].get(t, 0) + b["d_hold"].get(t, 0) for t in hold_slacks}
            combo_setup = {t: a["d_setup"].get(t, 0) + b["d_setup"].get(t, 0) for t in setup_slacks}
            all_fixed, worst_rem = fixes_all_hold(combo_hold, hold_slacks)
            s_safe, s_margin = setup_safe(combo_setup, setup_slacks)
            # Near-miss: fixes hold but barely breaks setup, or fixes setup but barely misses hold
            if all_fixed and s_margin >= -15:
                near_misses.append((a, b, worst_rem, s_margin, "hold ✓ setup close"))
            elif not all_fixed and worst_rem >= -10 and s_safe:
                near_misses.append((a, b, worst_rem, s_margin, "hold close setup ✓"))
    if near_misses:
        near_misses.sort(key=lambda x: abs(min(x[3], x[2])))  # closest to passing both
        print()
        print("  NEAR-MISS COMBOS (for reference):")
        print(f"  {'Combo':<55} {'h_margin':>9} {'s_margin':>9}  Note")
        print("  " + "-" * 90)
        shown = set()
        for a, b, wrem, sm, note in near_misses[:10]:
            key = f"{a['ref']}+{b['ref']}"
            if key in shown:
                continue
            shown.add(key)
            label = a['func'] + ' + ' + b['func']
            if a['kind'] == 'BUF' or b['kind'] == 'BUF':
                label += " (buf)"
            print(f"  {label:<55} {wrem:>+8.1f}ps {sm:>+8.1f}ps  {note}")

# Final recommendation
insert_pin = "$INSERT_PIN"
GREEN = "\033[32m"
RED = "\033[31m"
RESET = "\033[0m"
fixable = bool(combos or best_single)

print()
print("  " + "=" * 70)
verdict = f"{GREEN}FIXABLE{RESET}" if fixable else f"{RED}UNFIXABLE{RESET}"
print(f"  RECOMMENDATION: {verdict}")
print("  " + "=" * 70)
print(f"  Insertion point: {insert_pin}")
print(f"  Checks: {', '.join(hold_tags_present)} (all hold corners)")
print()

if combos:
    a, b, combo_hold, combo_setup, worst_rem, s_margin = combos[0]
    if best_single:
        _, bs_rem = fixes_all_hold(best_single["d_hold"], hold_slacks)
        _, bs_smargin = setup_safe(best_single["d_setup"], setup_slacks)
        print(f"  Option A (single cell): 1x {best_single['ref']}")
        print(f"           hold margin: +{bs_rem:.1f}ps | setup margin: +{bs_smargin:.1f}ps (worst corners)")
        print()
        print(f"  Option B (2-cell):      1x {a['ref']}")
        print(f"                        + 1x {b['ref']}")
        print(f"           hold margin: +{worst_rem:.1f}ps | setup margin: +{s_margin:.1f}ps (worst corners)")
    else:
        print(f"  Insert: 1x {a['ref']}")
        print(f"        + 1x {b['ref']}")
        print(f"  hold margin: +{worst_rem:.1f}ps | setup margin: +{s_margin:.1f}ps (worst corners)")
elif best_single:
    _, bs_rem = fixes_all_hold(best_single["d_hold"], hold_slacks)
    _, bs_smargin = setup_safe(best_single["d_setup"], setup_slacks)
    print(f"  Insert: 1x {best_single['ref']}")
    print(f"  hold margin: +{bs_rem:.1f}ps | setup margin: +{bs_smargin:.1f}ps (worst corners)")
else:
    print("  No single or 2-cell LVT combination fixes ALL hold & setup corners.")
    print("  Consider clock tree investigation or multi-point insertion.")

print("  " + "=" * 70)
PYEOF

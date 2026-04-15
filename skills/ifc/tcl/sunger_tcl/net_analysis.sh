#!/bin/bash
# net_analysis.sh - Analyze a net's routing: metal layers, RC, delay, wire length
#
# Usage:
#   net_analysis.sh <pin_name> [corner]
#
# Pin can be either input or output - the script auto-detects direction.
#
# Examples:
#   net_analysis.sh icore0/par_fmav0/simuldisablebugfixm3nnh__FEEDTHRU_1_ft_buf4/Z     # output pin
#   net_analysis.sh icore0/par_fmav0/simuldisablebugfixm3nnh__FEEDTHRU_1_ft_buf3/I     # input pin
#   net_analysis.sh icore0/par_fmav0/HFSBUF_2338_3566771/Z func.max_med.T_85.typical
#
# Default corner: func.max_high.T_85.typical

set -uo pipefail

PT_CLIENT="/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl"

PIN="$1"
CORNER="${2:-func.max_high.T_85.typical}"
MODEL="modelb_gfcn2clienta0_bu_prp_${CORNER}"

# =====================================================================
#  Helper: query PT server (strips header lines)
# =====================================================================
pt_query() {
    local cmd="$1"
    "$PT_CLIENT" -m "$MODEL" -c "$cmd" 2>&1 | grep -v "^-I-" | grep -v "^$" | tail -1 | tr -d '\r'
}

pt_query_full() {
    local cmd="$1"
    "$PT_CLIENT" -m "$MODEL" -c "$cmd" 2>&1 | grep -v "^-I-" | tr -d '\r'
}

echo "==========================================================="
echo "  Net Analysis"
echo "==========================================================="
echo "  Pin   : $PIN"
echo "  Corner: $CORNER"
echo "  Model : $MODEL"
echo "-----------------------------------------------------------"

# =====================================================================
#  Step 1: Get net name and connected pins from PT
# =====================================================================
echo ""
echo "[1/4] Querying PT for net info..."

# Detect pin direction to find the correct net
PIN_DIR=$(pt_query "get_attribute [get_pins $PIN] direction")
if [ -z "$PIN_DIR" ] || echo "$PIN_DIR" | grep -qi "error\|warning"; then
    echo "ERROR: Could not get pin direction for: $PIN"
    echo "PT response: $PIN_DIR"
    exit 1
fi
echo "  Pin direction: $PIN_DIR"

NET_NAME=$(pt_query "get_object_name [get_nets -of_objects [get_pins $PIN]]")
if [ -z "$NET_NAME" ] || echo "$NET_NAME" | grep -qi "error\|warning"; then
    echo "ERROR: Could not get net for pin: $PIN"
    echo "PT response: $NET_NAME"
    exit 1
fi
echo "  Net name: $NET_NAME"

# Get driver and load pins (use filter_collection - curly brace filters don't work via pt_client)
DRIVER=$(pt_query "get_object_name [filter_collection [get_pins -of_objects [get_nets $NET_NAME]] \"direction==out\"]")
LOADS=$(pt_query "get_object_name [filter_collection [get_pins -of_objects [get_nets $NET_NAME]] \"direction==in\"]")

# If user gave an input pin, the net we got is driven by someone else - that's fine, we already have driver/loads.
# If user gave an output pin, same thing - it's the driver of this net.
echo "  Driver: $DRIVER"

# Count loads
NLOADS=$(echo "$LOADS" | wc -w)
echo "  Loads : $NLOADS pin(s)"

# =====================================================================
#  Step 2: Get delay & RC for each load from PT
# =====================================================================
echo ""
echo "[2/4] Querying PT for delay & RC per load..."

# Temp file for results
TMPFILE="/tmp/net_analysis_$$_results.txt"
: > "$TMPFILE"

for LOAD in $LOADS; do
    # Strip braces from PT output
    LOAD=$(echo "$LOAD" | tr -d '{}')
    
    DELAY_OUT=$(pt_query_full "report_delay_calculation -from $DRIVER -to $LOAD -nosplit")
    
    # Extract values
    NET_DELAY_R=$(echo "$DELAY_OUT" | grep "Net delay" | awk '{print $4}')
    NET_DELAY_F=$(echo "$DELAY_OUT" | grep "Net delay" | awk '{print $5}')
    TOTAL_CAP=$(echo "$DELAY_OUT" | grep "Total capacitance  = 0\." | awk '{print $4}')
    TOTAL_RES=$(echo "$DELAY_OUT" | grep "Total resistance" | awk '{print $4}')
    NUM_RC=$(echo "$DELAY_OUT" | grep "Number of elements" | head -1)
    NUM_CAP=$(echo "$NUM_RC" | grep -oP '\d+ Capacitances' | awk '{print $1}')
    NUM_RES=$(echo "$NUM_RC" | grep -oP '\d+ Resistances' | awk '{print $1}')
    
    # Use rise delay as primary
    [ -z "$NET_DELAY_R" ] && NET_DELAY_R="N/A"
    [ -z "$TOTAL_CAP" ] && TOTAL_CAP="N/A"
    [ -z "$TOTAL_RES" ] && TOTAL_RES="N/A"

    echo "$LOAD|$NET_DELAY_R|$NET_DELAY_F|$TOTAL_CAP|$TOTAL_RES|$NUM_CAP|$NUM_RES" >> "$TMPFILE"
done

# =====================================================================
#  Step 3: Get metal layers and wire length from DEF
# =====================================================================
echo ""
echo "[3/4] Analyzing DEF routing..."

# Extract partition name from net (e.g., icore0/par_fmav0/netname -> par_fmav0)
PAR_NAME=$(echo "$NET_NAME" | grep -oP '(par_\w+)' | head -1)
SHORT_NET=$(echo "$NET_NAME" | sed "s|.*/||")

if [ -z "$PAR_NAME" ]; then
    echo "  WARNING: Could not detect partition from net name. Skipping DEF analysis."
    METALS="N/A"
    WIRE_LEN="N/A"
else
    # Find the PT log to get work area path
    PT_MODEL_PATH=$(pt_query "pwd")
    # Find the work area by going up from model path
    WORK_AREA=$(echo "$PT_MODEL_PATH" | grep -oP '.+?\.bu_postcts')
    
    if [ -z "$WORK_AREA" ]; then
        # Try from the model info
        MODEL_INFO=$("$PT_CLIENT" -m "$MODEL" -c "pwd" 2>&1 | grep "^-I- MODEL:")
        WORK_AREA=$(echo "$MODEL_INFO" | grep -oP '/nfs.*?\.bu_postcts')
    fi

    DEF_PATH="$WORK_AREA/runs/$PAR_NAME/n2p_htall_conf4/release/latest/sta_primetime/$PAR_NAME.def.gz"
    
    if [ ! -f "$DEF_PATH" ]; then
        # Try to find it
        DEF_PATH=$(find "$WORK_AREA/runs/$PAR_NAME/" -name "$PAR_NAME.def.gz" 2>/dev/null | head -1)
    fi

    if [ -n "$DEF_PATH" ] && [ -f "$DEF_PATH" ]; then
        echo "  DEF: $DEF_PATH"
        
        # Get DEF units
        DEF_UNITS=$(zcat "$DEF_PATH" | head -50 | grep "UNITS DISTANCE" | grep -oP '\d+(?= ;)')
        [ -z "$DEF_UNITS" ] && DEF_UNITS=2000
        
        # Extract routing for this net using streaming (awk) - handles huge DEF files
        # Finds the net definition block that contains ROUTED info; falls back to first match
        DEF_ROUTING=$(zcat "$DEF_PATH" 2>/dev/null | awk -v net="$SHORT_NET" '
        BEGIN { found=0; has_routed=0; block=""; best="" }
        /^- / {
            if (found) {
                # End of previous net block
                if (has_routed) { print best; exit }
                if (best == "") best = block
                found = 0
            }
            # Check if this line defines our net
            line = $0; sub(/^- /, "", line); sub(/[ \t]*$/, "", line)
            if (line == net) {
                found = 1; block = $0 "\n"; has_routed = 0
                next
            }
        }
        found {
            block = block $0 "\n"
            if ($0 ~ /ROUTED/) has_routed = 1
            if ($0 ~ /;[ \t]*$/) {
                if (has_routed) { print block; exit }
                if (best == "") best = block
                found = 0
            }
        }
        END { if (found && best == "") best = block; if (best != "" && !has_routed) print best }
        ')
        
        if [ -n "$DEF_ROUTING" ]; then
            # Extract metal layers
            METALS=$(echo "$DEF_ROUTING" | grep -oP '\bM[0-9]+\b' | sort -t'M' -k1 -n | uniq -c | sort -rn)
            
            # Calculate wire length - write routing to temp file to avoid shell quoting issues
            DEF_TMP="/tmp/net_analysis_$$_def.txt"
            echo "$DEF_ROUTING" > "$DEF_TMP"
            WIRE_LEN=$(python3 -c "
import re, sys
with open('$DEF_TMP') as f:
    lines = f.read()
coords = re.findall(r'\(\s*(\d+|\*)\s+(\d+|\*)\s*(?:\d+)?\s*\)', lines)
total = 0
px, py = None, None
for xs, ys in coords:
    x = int(xs) if xs != '*' else px
    y = int(ys) if ys != '*' else py
    if x is None or y is None:
        px, py = x, y
        continue
    if px is not None and py is not None:
        dx, dy = abs(x - px), abs(y - py)
        if dx > 0 or dy > 0:
            total += dx + dy
    px, py = x, y
print(f'{total / $DEF_UNITS:.1f}')
" 2>/dev/null)
            rm -f "$DEF_TMP"
        else
            METALS="N/A (net not found in DEF)"
            WIRE_LEN="N/A"
        fi
    else
        echo "  WARNING: DEF not found at $DEF_PATH"
        METALS="N/A"
        WIRE_LEN="N/A"
    fi
fi

# =====================================================================
#  Step 4: Print summary table
# =====================================================================
echo ""
echo "==========================================================="
echo "  NET ANALYSIS RESULTS"
echo "==========================================================="
echo "  Net name   : $NET_NAME"
echo "  Driver     : $DRIVER"
echo "  Loads      : $NLOADS"
if [ -n "$WIRE_LEN" ] && [ "$WIRE_LEN" != "N/A" ]; then
    echo "  Wire length: ${WIRE_LEN} um"
fi
echo "-----------------------------------------------------------"

# Metal layers
echo ""
echo "  METAL LAYER USAGE:"
if [ -n "$METALS" ] && [ "$METALS" != "N/A" ] && [ "$METALS" != "N/A (net not found in DEF)" ]; then
    echo "$METALS" | while read count layer; do
        printf "    %-6s : %s segments\n" "$layer" "$count"
    done
    MAX_METAL=$(echo "$METALS" | awk '{print $2}' | sed 's/M//' | sort -n | tail -1)
    MIN_METAL=$(echo "$METALS" | awk '{print $2}' | sed 's/M//' | sort -n | head -1)
    echo "  Range: M$MIN_METAL - M$MAX_METAL"
else
    echo "    $METALS"
fi

# Delay table
echo ""
echo "  DELAY & RC PER LOAD:"
printf "  %-70s %8s %8s %8s %8s\n" "LOAD PIN" "R(ps)" "F(ps)" "Cap(pF)" "Res(kΩ)"
printf "  %s\n" "$(printf '%.0s-' {1..110})"

while IFS='|' read -r load delay_r delay_f cap res ncap nres; do
    # Truncate long pin names
    short_load="$load"
    if [ ${#load} -gt 70 ]; then
        short_load="...${load: -67}"
    fi
    printf "  %-70s %8s %8s %8s %8s\n" "$short_load" "$delay_r" "$delay_f" "$cap" "$res"
done < "$TMPFILE"

printf "  %s\n" "$(printf '%.0s-' {1..110})"

# Summary line
if [ "$NLOADS" -eq 1 ]; then
    IFS='|' read -r load delay_r delay_f cap res ncap nres < "$TMPFILE"
    echo ""
    echo "  SUMMARY: Net delay=${delay_r}ps(R)/${delay_f}ps(F) | R=${res}kΩ | C=${cap}pF | Wire=${WIRE_LEN:-N/A}um"
fi

echo "==========================================================="

# Cleanup
rm -f "$TMPFILE"

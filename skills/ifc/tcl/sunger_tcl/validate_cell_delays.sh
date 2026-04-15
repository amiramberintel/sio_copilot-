#!/bin/bash
# validate_cell_delays.sh - Compare cell delays from CSV against real timing paths
#
# Usage:
#   validate_cell_delays.sh <cell_delay.csv> [model_name]
#
# Example:
#   validate_cell_delays.sh cell_delay_high.csv modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical
#
# Picks 5 random cell types from the CSV, runs report_delay_calculation
# on the PT server, and compares against CSV averages.

CSV="$1"
MODEL="${2:-modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical}"
PT_CLIENT="/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl"

if [ -z "$CSV" ] || [ ! -f "$CSV" ]; then
    echo "Usage: validate_cell_delays.sh <cell_delay.csv> [model_name]"
    exit 1
fi

echo "=== Cell Delay Validation ==="
echo "CSV:   $CSV"
echo "Model: $MODEL"
echo ""

# Pick 5 random cell types that have reasonable counts (>100 instances)
CELLS=$(awk -F, 'NR>1 && $6+0 > 100 {print $1}' "$CSV" | sort -u | shuf | head -5)

printf "%-40s | %-12s | %-6s | %12s | %12s | %8s\n" "ref_name" "arc" "edge" "csv_avg" "pt_delay" "diff%"
printf "%s\n" "---------------------------------------------------------------------------------------------------------------"

for REF in $CELLS; do
    # Get first arc for this cell from CSV
    ARC_LINE=$(grep "^${REF}," "$CSV" | head -1)
    ARC=$(echo "$ARC_LINE" | awk -F, '{print $7}')
    EDGE=$(echo "$ARC_LINE" | awk -F, '{print $8}')
    CSV_AVG=$(echo "$ARC_LINE" | awk -F, '{print $10}')

    # Parse arc pins
    FROM_PIN=$(echo "$ARC" | sed 's/->.*//')
    TO_PIN=$(echo "$ARC" | sed 's/.*->//')

    # Find a cell instance on the PT server
    CELL_NAME=$($PT_CLIENT -m "$MODEL" -c "get_object_name [index_collection [get_cells -hierarchical -filter \"ref_name==${REF} && is_hierarchical==false\" -quiet] 0]" 2>&1 | grep -v "^-I-" | grep -v "^$" | tail -1 | tr -d '\r')

    if [ -z "$CELL_NAME" ] || echo "$CELL_NAME" | grep -qi "error\|warning\|LOADING"; then
        printf "%-40s | %-12s | %-6s | %12s | %12s | %8s\n" "$REF" "$ARC" "$EDGE" "$CSV_AVG" "N/A" "N/A"
        continue
    fi

    # Run report_delay_calculation
    FROM_FULL="${CELL_NAME}/${FROM_PIN}"
    TO_FULL="${CELL_NAME}/${TO_PIN}"

    RDC=$($PT_CLIENT -m "$MODEL" -c "report_delay_calculation -from ${FROM_FULL} -to ${TO_FULL}" 2>&1 | tr -d '\r')

    # Parse cell delay (first Cell delay line, rise or fall based on edge)
    if [ "$EDGE" = "rise" ]; then
        PT_DELAY=$(echo "$RDC" | grep -i "Cell delay" | head -1 | awk '{print $4}')
    else
        PT_DELAY=$(echo "$RDC" | grep -i "Cell delay" | head -1 | awk '{print $5}')
    fi

    if [ -n "$PT_DELAY" ] && [ -n "$CSV_AVG" ] && [ "$CSV_AVG" != "0" ]; then
        DIFF=$(python3 -c "csv=$CSV_AVG; pt=$PT_DELAY; print(f'{((pt-csv)/csv)*100:.1f}')" 2>/dev/null)
        printf "%-40s | %-12s | %-6s | %12.6f | %12.6f | %7s%%\n" "$REF" "$ARC" "$EDGE" "$CSV_AVG" "$PT_DELAY" "$DIFF"
    else
        printf "%-40s | %-12s | %-6s | %12s | %12s | %8s\n" "$REF" "$ARC" "$EDGE" "$CSV_AVG" "${PT_DELAY:-N/A}" "N/A"
    fi
done

echo ""
echo "Note: PT delay is from a single instance; CSV avg is across up to 20 instances."
echo "Differences are expected since each instance has different slew/load conditions."

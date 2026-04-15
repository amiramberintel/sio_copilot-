#!/bin/bash

# Analysis script for par_msid external interface timing status
# Daily model: GFC_CLIENT_26ww06b_ww07_6_TIP_clockroute_RCOs-FCT26WW08D_dcm_daily-CLK039
# Corner: func.max_high.T_85.typical

BASE_WA="/nfs/site/disks/idc_gfc_fct_bu_daily/work_area/GFC_CLIENT_26ww06b_ww07_6_TIP_clockroute_RCOs-FCT26WW08D_dcm_daily-CLK039.bu_postcts"
PARTITION="par_msid"
CORNER="func.max_high.T_85.typical"
OUTDIR="/nfs/site/disks/sunger_wa/fc_data/my_learns/temp_txt_files"

echo "==============================================================================="
echo "PAR_MSID EXTERNAL INTERFACE TIMING ANALYSIS - MAX_HIGH CORNER (DAILY MODEL)"
echo "==============================================================================="
echo "Partition: ${PARTITION}"
echo "Corner: ${CORNER}"
echo "Model: GFC_CLIENT_26ww06b_ww07_6_TIP_clockroute_RCOs-FCT26WW08D_dcm_daily-CLK039"
echo "Date: $(date)"
echo "==============================================================================="
echo ""

# Find timing closure directory
TIMING_DIR="${BASE_WA}/runs/${PARTITION}/n2p_htall_conf4/release/latest/timing_closure"

if [ ! -d "$TIMING_DIR" ]; then
    echo "ERROR: Timing directory not found: $TIMING_DIR"
    exit 1
fi

# Check for timing summary file
TIMING_FILE="${TIMING_DIR}/core_client.${CORNER}_timing_summary.xml.filtered"

if [ ! -f "$TIMING_FILE" ]; then
    echo "ERROR: Timing file not found: $TIMING_FILE"
    exit 1
fi

echo "Found timing file: $TIMING_FILE"
echo "File size: $(du -h "$TIMING_FILE" | cut -f1)"
echo ""

# ===== SECTION 1: Extract all external paths =====
EXTERNAL_FILE="${OUTDIR}/par_msid_max_high_external_paths.xml"
echo "Extracting external paths..."
grep 'int_ext="external"' "$TIMING_FILE" > "$EXTERNAL_FILE"
EXTERNAL_COUNT=$(wc -l < "$EXTERNAL_FILE")
echo "Total external paths: $EXTERNAL_COUNT"
echo "Saved to: $EXTERNAL_FILE"
echo ""

# ===== SECTION 2: Extract paths crossing par_msid boundary =====
echo "==============================================================================="
echo "EXTERNAL PATH ANALYSIS"
echo "==============================================================================="

echo ""
echo "Extracting paths impacting par_msid..."
grep "blocks_impacted.*par_msid" "$EXTERNAL_FILE" > "${OUTDIR}/par_msid_max_high_crossing_par_msid.xml"
PAR_MSID_PATHS=$(wc -l < "${OUTDIR}/par_msid_max_high_crossing_par_msid.xml")
echo "Paths crossing par_msid boundary: $PAR_MSID_PATHS"

# ===== SECTION 3: Extract boundary pins =====
echo ""
echo "Extracting boundary pins..."
grep -o 'boundary_pins="[^"]*"' "${OUTDIR}/par_msid_max_high_crossing_par_msid.xml" | \
    sed 's/boundary_pins="//;s/"$//' | \
    tr ',' '\n' | sed 's/[{}]//g' | sed 's/^ *//;s/ *$//' | sort -u > "${OUTDIR}/par_msid_max_high_boundary_pins.txt"
UNIQUE_PINS=$(wc -l < "${OUTDIR}/par_msid_max_high_boundary_pins.txt")
echo "Unique boundary pins: $UNIQUE_PINS"
echo "Saved to: ${OUTDIR}/par_msid_max_high_boundary_pins.txt"

# ===== SECTION 4: Slack distribution =====
echo ""
echo "==============================================================================="
echo "SLACK DISTRIBUTION (EXTERNAL PATHS CROSSING PAR_MSID)"
echo "==============================================================================="

awk -F'slack="' '{if (NF>1) {split($2,a,"\""); print a[1]}}' "${OUTDIR}/par_msid_max_high_crossing_par_msid.xml" | \
    awk '{
        slack = $1
        if (slack < -1000) neg1000++
        else if (slack < -500) neg500++
        else if (slack < -100) neg100++
        else if (slack < 0) neg0++
        else if (slack < 100) pos100++
        else if (slack < 500) pos500++
        else pos1000++

        if (NR==1 || slack < worst) worst = slack
        if (NR==1 || slack > best) best = slack
        sum += slack
        count++
    }
    END {
        print "Slack Range (ps)         Count"
        print "------------------------------"
        printf "< -1000ps:           %8d\n", neg1000
        printf "-1000 to -500ps:     %8d\n", neg500
        printf "-500 to -100ps:      %8d\n", neg100
        printf "-100 to 0ps:         %8d\n", neg0
        printf "0 to 100ps:          %8d\n", pos100
        printf "100 to 500ps:        %8d\n", pos500
        printf "> 500ps:             %8d\n", pos1000
        print "------------------------------"
        printf "Total paths:         %8d\n", count
        printf "\nWorst slack:         %8d ps\n", worst
        printf "Best slack:          %8d ps\n", best
        printf "Average slack:       %8.2f ps\n", (count>0 ? sum/count : 0)
    }'

# ===== SECTION 5: Neighbor partition breakdown =====
echo ""
echo "==============================================================================="
echo "NEIGHBOR PARTITION BREAKDOWN (paths crossing par_msid)"
echo "==============================================================================="

awk '{
    match($0, /blocks_impacted="([^"]*)"/, bi)
    info = bi[1]
    # Extract partition names
    while (match(info, /\{([^(]+)\(/, m)) {
        part = m[1]
        gsub(/^[ \t]+|[ \t]+$/, "", part)
        if (part !~ /par_msid/) {
            parts[part]++
        }
        info = substr(info, RSTART + RLENGTH)
    }
}
END {
    printf "%-40s  %s\n", "Neighbor Partition", "Path Count"
    print "------------------------------------------------------"
    for (p in parts) {
        printf "%-40s  %8d\n", p, parts[p]
    }
}' "${OUTDIR}/par_msid_max_high_crossing_par_msid.xml" | sort -t'|' -k2 -rn

# ===== SECTION 6: Direction analysis (par_msid as source vs sink) =====
echo ""
echo "==============================================================================="
echo "DIRECTION ANALYSIS (par_msid as source vs endpoint)"
echo "==============================================================================="

awk '{
    match($0, /startpoint="([^"]*)"/, sp)
    match($0, /endpoint="([^"]*)"/, ep)
    if (sp[1] ~ /par_msid/) src++
    if (ep[1] ~ /par_msid/) snk++
}
END {
    printf "par_msid as startpoint (data source):  %8d paths\n", src
    printf "par_msid as endpoint   (data sink):    %8d paths\n", snk
}' "${OUTDIR}/par_msid_max_high_crossing_par_msid.xml"

# ===== SECTION 7: Top 50 worst paths =====
echo ""
echo "==============================================================================="
echo "TOP 50 WORST EXTERNAL PATHS CROSSING PAR_MSID"
echo "==============================================================================="

awk -F'slack="|"' '{
    slack = $2

    match($0, /startpoint="([^"]*)"/, sp)
    match($0, /endpoint="([^"]*)"/, ep)
    match($0, /path_group="([^"]*)"/, pg)
    match($0, /boundary_pins="([^"]*)"/, bp)
    match($0, /por_slack="([^"]*)"/, ps)

    print slack "\t" pg[1] "\t" sp[1] "\t" ep[1] "\t" bp[1] "\t" ps[1]
}' "${OUTDIR}/par_msid_max_high_crossing_par_msid.xml" | sort -n | head -50 > "${OUTDIR}/par_msid_max_high_top50_worst.txt"

echo "Rank  Slack(ps)  POR_Slack  Path_Group       Startpoint -> Endpoint"
echo "---------------------------------------------------------------------------------"
awk -F'\t' '{
    printf "%4d  %8s  %9s  %-15s  %s -> %s\n", NR, $1, $6, $2, $3, $4
}' "${OUTDIR}/par_msid_max_high_top50_worst.txt"

echo ""
echo "Full details saved to: ${OUTDIR}/par_msid_max_high_top50_worst.txt"

# ===== SECTION 8: Interface pin slack summary =====
echo ""
echo "==============================================================================="
echo "INTERFACE PIN SLACK SUMMARY (par_msid pins only)"
echo "==============================================================================="

awk '{
    match($0, /slack="([^"]*)"/, s)
    if (s[1] != "") {
        slack = s[1] + 0
        match($0, /boundary_pins="([^"]*)"/, bp)
        pin_str = bp[1]
        gsub(/[{}]/, "", pin_str)
        n = split(pin_str, pins, " ")
        for (i = 1; i <= n; i++) {
            pin = pins[i]
            gsub(/^[ \t]+|[ \t]+$/, "", pin)
            if (pin ~ /par_msid/) {
                if (!(pin in pin_slack) || slack < pin_slack[pin]) {
                    pin_slack[pin] = slack
                }
                pin_count[pin]++
            }
        }
    }
}
END {
    for (pin in pin_slack) {
        print pin_slack[pin] "\t" pin_count[pin] "\t" pin
    }
}' "${OUTDIR}/par_msid_max_high_crossing_par_msid.xml" | \
    sort -n > "${OUTDIR}/par_msid_max_high_pin_slack_summary.txt"

echo "Top 100 worst par_msid interface pins (by worst slack):"
echo ""
echo "Rank  Worst_Slack(ps)  Path_Count  Pin_Name"
echo "-------------------------------------------------------------------------------"
head -100 "${OUTDIR}/par_msid_max_high_pin_slack_summary.txt" | \
    awk -F'\t' '{printf "%4d  %15s  %10s  %s\n", NR, $1, $2, $3}'

echo ""
echo "Full pin summary saved to: ${OUTDIR}/par_msid_max_high_pin_slack_summary.txt"

# ===== SECTION 9: Clock domain analysis =====
echo ""
echo "==============================================================================="
echo "CLOCK DOMAIN ANALYSIS"
echo "==============================================================================="

awk -F'path_group="|"' 'NF>1 {
    match($0, /slack="([^"]*)"/, s)
    if (s[1] != "") {
        slack = s[1] + 0
        clk = $2
        clk_count[clk]++
        clk_slack_sum[clk] += slack
        if (!(clk in clk_worst) || slack < clk_worst[clk]) {
            clk_worst[clk] = slack
        }
    }
}
END {
    printf "%-25s  %8s  %15s  %13s\n", "Clock_Domain", "Paths", "Worst_Slack(ps)", "Avg_Slack(ps)"
    print "-----------------------------------------------------------------------"
    for (clk in clk_count) {
        printf "%-25s  %8d  %15d  %13.2f\n", clk, clk_count[clk], clk_worst[clk], clk_slack_sum[clk]/clk_count[clk]
    }
}' "${OUTDIR}/par_msid_max_high_crossing_par_msid.xml" | sort -k3 -n

# ===== SUMMARY =====
echo ""
echo "==============================================================================="
echo "GENERATED FILES"
echo "==============================================================================="
echo "1. All external paths:            ${OUTDIR}/par_msid_max_high_external_paths.xml"
echo "2. Par_msid crossing paths:       ${OUTDIR}/par_msid_max_high_crossing_par_msid.xml"
echo "3. Boundary pins list:            ${OUTDIR}/par_msid_max_high_boundary_pins.txt"
echo "4. Top 50 worst paths:            ${OUTDIR}/par_msid_max_high_top50_worst.txt"
echo "5. Pin slack summary:             ${OUTDIR}/par_msid_max_high_pin_slack_summary.txt"
echo "==============================================================================="
echo ""
echo "Analysis complete!"

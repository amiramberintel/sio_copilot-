#!/bin/bash
# sta_corner_monitor.sh - Monitor PrimeTime STA corner run status
#
# Usage:
#   sta_corner_monitor.sh [work_area]
#
# work_area: path to the BU work area (e.g., .../GFC_CLIENT_...bu_postcts)
# If no argument given, uses the current working directory as the work area.

set -uo pipefail

# Resolve work area
if [ $# -ge 1 ]; then
    WORK_AREA="$1"
else
    WORK_AREA="$(pwd)"
fi

if [ ! -d "$WORK_AREA" ]; then
    echo "ERROR: Work area not found: $WORK_AREA"
    exit 1
fi

# Find sta_pt directory under work area
STA_DIR=$(ls -d "$WORK_AREA"/runs/core_client/*/sta_pt/ 2>/dev/null | head -1)
if [ -z "$STA_DIR" ]; then
    echo "ERROR: No sta_pt directory found under $WORK_AREA/runs/core_client/*/sta_pt/"
    exit 1
fi

cd "$STA_DIR"

# Collect corners (exclude infra dirs and .ct sub-corners)
corners=$(ls -d */ 2>/dev/null | sed 's/\/$//' \
    | grep -v -E '^(dmsa|inputs|logs|outputs|reports|scripts)$' \
    | grep -v '\.ct[0-9]*$')

if [ -z "$corners" ]; then
    echo "No corner directories found in $STA_DIR"
    exit 1
fi

done_count=0
running_count=0
total_count=0

# Header
printf "%-7s | %-50s | %-12s | %-14s | %-20s | %s\n" "STATUS" "CORNER" "START TIME" "RUNTIME" "LAST STAGE" "CURRENT ACTIVITY"
printf "%s\n" "$(printf '%.0s-' {1..155})"

for c in $corners; do
    total_count=$((total_count + 1))
    ptlog="$c/logs/core_client.${c}.pt.log"
    proclog="$c/logs/proc_time.log"

    # Check completion
    if [ -f "$ptlog" ] && tail -50 "$ptlog" | grep -q "Thank you for using pt_shell!"; then
        status="DONE"
        done_count=$((done_count + 1))
    else
        status="RUNNING"
        running_count=$((running_count + 1))
    fi

    # Start time & Runtime
    total="N/A"
    stage="N/A"
    start_time="N/A"
    if [ -f "$proclog" ]; then
        first_ts=$(grep -m1 "^TimeStamp" "$proclog")
        last_ts=$(grep "^TimeStamp" "$proclog" | tail -1 || true)

        # Extract start time from first TimeStamp
        if [ -n "$first_ts" ]; then
            start_time=$(echo "$first_ts" | grep -oP '\w{3} \w{3} +\d+ \d+:\d+:\d+ \d{4}$')
            start_epoch=$(date -d "$start_time" +%s 2>/dev/null)
            # Reformat to compact form
            start_time=$(date -d "$start_time" '+%b-%d %H:%M' 2>/dev/null || echo "$start_time")
        fi

        if [ -n "$last_ts" ]; then
            stage=$(echo "$last_ts" | grep -oP 'TimeStamp : \S+' | sed 's/TimeStamp : //')
        fi

        if [ "$status" = "RUNNING" ] && [ -n "${start_epoch:-}" ]; then
            # Calculate elapsed time from start to now
            now_epoch=$(date +%s)
            elapsed=$((now_epoch - start_epoch))
            hours=$((elapsed / 3600))
            mins=$(( (elapsed % 3600) / 60 ))
            secs=$((elapsed % 60))
            total=$(printf "%02dh:%02dm:%02ds" "$hours" "$mins" "$secs")
        else
            # For completed corners, use the last recorded total from proc_time.log
            total=$(echo "$last_ts" | grep -oP 'Total : \S+' | sed 's/Total : //')
        fi
    fi

    # For running corners: get current script from last SCRIPT_START in PT log + XLS status
    activity=""
    if [ "$status" = "RUNNING" ]; then
        if [ -f "$ptlog" ]; then
            activity=$(grep "SCRIPT_START" "$ptlog" | tail -1 \
                | grep -oP 'SCRIPT_START : \K[^ ]+' \
                | xargs -I{} basename {} 2>/dev/null || true)
        fi
        if ls "$c/reports/csv/indicator_table_"*.xlsx &>/dev/null; then
            activity="$activity \033[32m[XLS_READY]\033[0m"
        else
            activity="$activity \033[31m[XLS_NOT_READY]\033[0m"
        fi
    fi

    printf "%-7s | %-50s | %-12s | %-14s | %-20s | %b\n" "$status" "$c" "$start_time" "$total" "$stage" "$activity"
done

# Summary
printf "%s\n" "$(printf '%.0s-' {1..155})"
echo "Total: $total_count | Done: $done_count | Running: $running_count"

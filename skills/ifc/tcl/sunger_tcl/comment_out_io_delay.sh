#!/bin/bash
# comment_out_io_delay.sh
# Comments out active set_input_delay / set_output_delay lines for a given port
# in all io_constraints files across corners.
#
# Usage:
#   comment_out_io_delay.sh <port_name> <ward_path>
#
# Examples:
#   comment_out_io_delay.sh sapwrgoodyxznnnh $ward
#   comment_out_io_delay.sh c2u_dfx_tdo_ztnfwl $ward

PORT="$1"
WARD="${2:-.}"
PATTERN="runs/core_client/n2p_htall_conf4/release/latest/timing_collateral/*/core_client_io_constraints.tcl"

if [ -z "$PORT" ]; then
    echo "Usage: comment_out_io_delay.sh <port_name> [ward_path]"
    exit 1
fi

count=0
files=0
for f in ${WARD}/${PATTERN}; do
    [ -f "$f" ] || continue
    if grep -q "$PORT" "$f"; then
        changed=$(awk -v port="$PORT" \
            '/set_(input|output)_delay/ && $0 ~ port && !/^#/ {n++; $0 = "# " $0} {print} END {print n+0 > "/dev/stderr"}' \
            "$f" 2>&1 1>"${f}.tmp")
        if [ "$changed" -gt 0 ] 2>/dev/null; then
            mv "${f}.tmp" "$f"
            corner=$(basename "$(dirname "$f")")
            echo "Modified ($changed lines): $corner"
            count=$((count + changed))
            files=$((files + 1))
        else
            rm -f "${f}.tmp"
        fi
    fi
done

echo "Done. Commented out $count lines in $files files for port: $PORT"

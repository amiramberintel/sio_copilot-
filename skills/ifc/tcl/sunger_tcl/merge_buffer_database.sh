#!/bin/bash
# merge_buffer_database.sh - Merge per-corner buffer_cell_database.csv into one cross-corner file
#
# Usage:
#   merge_buffer_database.sh <work_area_path>
#
# Input:  <work_area>/runs/core_client/n2p_htall_conf4/sta_pt/*/reports/buffer_cell_database.csv
# Output: <work_area>/buffer_cell_database_all_corners.csv
#
# Each corner column contains avg_delay_ps = mean(avg_rise_delay, avg_fall_delay)
# Columns: ref_name, func, type, vt_class, drive_strength, instance_count, <corner1>, <corner2>, ...

set -uo pipefail

WA="${1:-.}"

# Resolve symlinks and trailing slashes
WA=$(cd "$WA" 2>/dev/null && pwd)

STADIR="$WA/runs/core_client/n2p_htall_conf4/sta_pt"
OUTFILE="$WA/buffer_cell_database_all_corners.csv"

if [ ! -d "$STADIR" ]; then
    echo "ERROR: STA directory not found: $STADIR"
    exit 1
fi

# Find all per-corner CSVs
CSV_FILES=$(ls "$STADIR"/*/reports/buffer_cell_database.csv 2>/dev/null)
NFILES=$(echo "$CSV_FILES" | grep -c ".")

if [ "$NFILES" -eq 0 ]; then
    echo "ERROR: No buffer_cell_database.csv files found under $STADIR/*/reports/"
    exit 1
fi

echo "==========================================="
echo " Merge Buffer Cell Database"
echo "==========================================="
echo " Work area : $WA"
echo " CSVs found: $NFILES corners"
echo " Output    : $OUTFILE"
echo "-------------------------------------------"

python3 << PYEOF
import csv, glob, os, sys

wa = "$WA"
pattern = os.path.join(wa, "runs/core_client/n2p_htall_conf4/sta_pt/*/reports/buffer_cell_database.csv")
files = sorted(glob.glob(pattern))

if not files:
    print("ERROR: No CSV files found")
    sys.exit(1)

corners = []
data = {}   # ref_name -> {corner -> avg_delay}
meta = {}   # ref_name -> {func, type, vt_class, drive_strength, instance_count}

for f in files:
    corner = f.split("/sta_pt/")[1].split("/reports/")[0]
    corners.append(corner)

    with open(f) as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            ref = row["ref_name"]
            if ref not in meta:
                meta[ref] = {
                    "func": row.get("func", ""),
                    "type": row["type"],
                    "vt_class": row["vt_class"],
                    "drive_strength": row["drive_strength"],
                    "instance_count": row["instance_count"],
                }

            try:
                r = float(row["avg_rise_delay_ps"])
                f_val = float(row["avg_fall_delay_ps"])
                avg = round((r + f_val) / 2, 4)
            except (ValueError, KeyError):
                avg = "N/A"

            if ref not in data:
                data[ref] = {}
            data[ref][corner] = avg

# Sort corners: max first, then min
max_corners = sorted([c for c in corners if ".max_" in c])
min_corners = sorted([c for c in corners if ".min_" in c])
sorted_corners = max_corners + min_corners

outfile = "$OUTFILE"
with open(outfile, "w", newline="") as fh:
    header = ["ref_name", "func", "type", "vt_class", "drive_strength", "instance_count"] + sorted_corners
    w = csv.writer(fh)
    w.writerow(header)

    for ref in sorted(data.keys()):
        m = meta[ref]
        row = [ref, m["func"], m["type"], m["vt_class"], m["drive_strength"], m["instance_count"]]
        for c in sorted_corners:
            row.append(data[ref].get(c, "N/A"))
        w.writerow(row)

print(f"  Cell types: {len(data)}")
print(f"  Corners   : {len(sorted_corners)} ({len(max_corners)} max + {len(min_corners)} min)")
print(f"  Output    : {outfile}")
PYEOF

echo "==========================================="
echo " Done!"
echo "==========================================="

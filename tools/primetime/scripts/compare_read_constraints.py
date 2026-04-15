#!/usr/bin/env python3
"""
compare_read_constraints.py
----------------------------
Compare 'read_constraints' stage runtime across multiple PrimeTime runs.

Usage:
    python3 compare_read_constraints.py \
        --model "today:/path/to/run1/runs/core_client/n2p_htall_conf4/sta_pt" \
        --model "ww09_release:/path/to/run2/runs/core_client/n2p_htall_conf4/sta_pt" \
        --model "ww10_release:/path/to/run3/runs/core_client/n2p_htall_conf4/sta_pt" \
        --model "yesterday:/path/to/run4/runs/core_client/n2p_htall_conf4/sta_pt" \
        [--stage read_constraints] \
        [--ref today]

Each --model argument is  NAME:PATH  where PATH is the sta_pt directory
containing  <corner>/logs/proc_time.log  files.

Options:
    --stage     Stage name to extract from proc_time.log  (default: read_constraints)
    --ref       Model name to use as the reference for ratio calculations (default: first model)
    --sort      Sort corners by: name | ref | delta  (default: name)
"""

import argparse
import glob
import re
import sys


def parse_logs(sta_pt_dir, stage):
    """Return {corner: (hh:mm:ss_str, total_minutes)} for the given stage."""
    results = {}
    pattern = f"{sta_pt_dir}/*/logs/proc_time.log"
    for f in sorted(glob.glob(pattern)):
        corner = f.split("/logs/proc_time.log")[0].rsplit("/", 1)[-1]
        with open(f) as fh:
            for line in fh:
                if stage in line:
                    m = re.search(r"Incr : (\d+)h:(\d+)m:(\d+)s", line)
                    if m:
                        h, mn, s = int(m.group(1)), int(m.group(2)), int(m.group(3))
                        results[corner] = (f"{h:02d}h:{mn:02d}m:{s:02d}s", h * 60 + mn + s / 60)
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--model", action="append", required=True, metavar="NAME:PATH",
                        help="Model label and sta_pt path (can be repeated)")
    parser.add_argument("--stage", default="read_constraints",
                        help="Stage name to compare (default: read_constraints)")
    parser.add_argument("--ref", default=None,
                        help="Reference model name for ratio columns (default: first model)")
    parser.add_argument("--sort", choices=["name", "ref", "delta"], default="name",
                        help="Sort corners by name, ref runtime, or delta vs ref (default: name)")
    args = parser.parse_args()

    # Parse model arguments
    models = {}
    model_order = []
    for entry in args.model:
        if ":" not in entry:
            print(f"ERROR: --model must be NAME:PATH, got: {entry}", file=sys.stderr)
            sys.exit(1)
        name, path = entry.split(":", 1)
        models[name] = parse_logs(path, args.stage)
        model_order.append(name)
        if not models[name]:
            print(f"WARNING: no '{args.stage}' data found for model '{name}' at {path}", file=sys.stderr)

    ref_name = args.ref if args.ref else model_order[0]
    if ref_name not in models:
        print(f"ERROR: reference model '{ref_name}' not found in provided models", file=sys.stderr)
        sys.exit(1)

    all_corners = sorted(set(c for m in models.values() for c in m))

    def fmt(name, c): return models[name][c][0] if c in models[name] else "N/A"
    def mins(name, c): return models[name][c][1] if c in models[name] else None

    # Column widths
    col_corner = 47
    col_data   = 16
    col_ratio  = 10

    # Sort corners
    if args.sort == "ref":
        all_corners = sorted(all_corners, key=lambda c: mins(ref_name, c) or 0, reverse=True)
    elif args.sort == "delta":
        def delta_key(c):
            vals = [mins(n, c) for n in model_order if mins(n, c)]
            return (max(vals) - min(vals)) if len(vals) > 1 else 0
        all_corners = sorted(all_corners, key=delta_key, reverse=True)

    # Build ratio column headers (each non-ref model vs ref)
    ratio_headers = [f"{n}/{ref_name}" for n in model_order if n != ref_name]

    # Header
    header = f"{'Corner':<{col_corner}}"
    for n in model_order:
        header += f" {n:<{col_data}}"
    for rh in ratio_headers:
        header += f" {rh:<{col_ratio}}"
    print(f"\nStage: {args.stage}   |   Reference: {ref_name}")
    print("=" * len(header))
    print(header)
    print("-" * len(header))

    for c in all_corners:
        row = f"{c:<{col_corner}}"
        for n in model_order:
            row += f" {fmt(n, c):<{col_data}}"
        ref_val = mins(ref_name, c)
        for n in model_order:
            if n == ref_name:
                continue
            val = mins(n, c)
            ratio = f"{val/ref_val:.2f}x" if val and ref_val else "N/A"
            row += f" {ratio:<{col_ratio}}"
        print(row)

    # Summary averages over corners present in ALL models
    common = [c for c in all_corners if all(mins(n, c) for n in model_order)]
    if common:
        print("-" * len(header))
        avg_row = f"{'AVERAGE (N='+str(len(common))+' common corners)':<{col_corner}}"
        avgs = {n: sum(mins(n, c) for c in common) / len(common) for n in model_order}
        for n in model_order:
            avg_row += f" {avgs[n]:.1f} min{'':<{col_data-10}}"
        ref_avg = avgs[ref_name]
        for n in model_order:
            if n == ref_name:
                continue
            ratio = f"{avgs[n]/ref_avg:.2f}x"
            avg_row += f" {ratio:<{col_ratio}}"
        print(avg_row)
    print()


if __name__ == "__main__":
    main()

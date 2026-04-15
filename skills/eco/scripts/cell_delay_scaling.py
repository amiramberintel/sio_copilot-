#!/usr/bin/env python3
"""Merge cell delay CSVs from different corners into one combined CSV.

Usage:
    python3 cell_delay_scaling.py -o merged.csv corner1.csv corner2.csv [...]

The first file is the reference corner. Scaling ratios = other / reference.
Corner names are extracted from file names (e.g., "cell_delay_max_high.csv" -> "max_high").

Output CSV columns:
    ref_name, arc, edge, count, <corner1>_avg, <corner2>_avg, ..., <corner2>/<corner1>, ...
Plus a summary section at the bottom.
"""

import csv
import sys
import os


def load_csv(path):
    """Load cell delay CSV into dict: (ref_name, arc, edge) -> info."""
    data = {}
    meta = {}  # per-file metadata: voltage, mclk_period
    with open(path) as f:
        for row in csv.DictReader(f):
            try:
                avg = float(row.get('avg_delay') or 0)
                if avg > 0:
                    key = (row['ref_name'], row['arc'], row['edge'])
                    data[key] = {
                        'count': int(row.get('count') or 0),
                        'measured': int(row.get('measured') or 0),
                        'avg': avg,
                        'min': float(row.get('min_delay') or 0),
                        'max': float(row.get('max_delay') or 0),
                        'cell_type': row.get('cell_type', ''),
                        'vt': row.get('vt', ''),
                    }
                    # Capture per-corner metadata from first valid row
                    if not meta:
                        meta['voltage'] = row.get('voltage', '')
                        meta['mclk_period'] = row.get('mclk_period', '')
            except (ValueError, TypeError):
                continue
    return data, meta


def extract_corner_name(filepath):
    """Extract corner name from filename."""
    base = os.path.basename(filepath).replace('.csv', '')
    for prefix in ('delays_', 'cell_delays_', 'cell_delay_', 'cell_type_delays_'):
        if base.startswith(prefix):
            base = base[len(prefix):]
            break
    return base


def main():
    # Parse arguments
    outfile = None
    infiles = []
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == '-o' and i + 1 < len(args):
            outfile = args[i + 1]
            i += 2
        else:
            infiles.append(args[i])
            i += 1

    if len(infiles) < 1:
        print("Usage: cell_delay_scaling.py -o merged.csv corner1.csv [corner2.csv ...]")
        print("  Merges cell delay CSVs from different corners into one file.")
        print("  -o <file>  Output CSV (default: stdout)")
        sys.exit(1)

    corners = []
    all_data = {}
    all_meta = {}

    for f in infiles:
        name = extract_corner_name(f)
        corners.append(name)
        all_data[name], all_meta[name] = load_csv(f)
        print(f"Loaded {name}: {len(all_data[name])} arcs", file=sys.stderr)

    # Print per-corner metadata
    for c in corners:
        m = all_meta[c]
        print(f"  {c}: voltage={m.get('voltage','N/A')} mclk_period={m.get('mclk_period','N/A')}", file=sys.stderr)

    # Use all keys present in ANY corner (union), not just common
    all_keys = set()
    for d in all_data.values():
        all_keys.update(d.keys())
    print(f"Total unique arcs: {len(all_keys)}", file=sys.stderr)

    # Common keys (present in all corners) for scaling summary
    common = set.intersection(*[set(d.keys()) for d in all_data.values()])
    print(f"Common arcs (in all corners): {len(common)}", file=sys.stderr)

    ref_corner = corners[0]

    # Sort by (ref_name, arc, edge)
    by_name = sorted(all_keys, key=lambda k: (k[0], k[1], k[2]))

    # Build CSV header
    header = ['ref_name', 'cell_type', 'vt', 'arc', 'edge', 'count']
    # Per-corner voltage and mclk_period info row
    meta_voltage = ['# voltage', '', '', '', '', '']
    meta_ct = ['# mclk_period', '', '', '', '', '']
    for c in corners:
        header.append(f'{c}_avg')
        meta_voltage.append(all_meta[c].get('voltage', ''))
        meta_ct.append(all_meta[c].get('mclk_period', ''))
    for c in corners[1:]:
        header.append(f'{c}/{ref_corner}')
        meta_voltage.append('')
        meta_ct.append('')

    # Open output
    if outfile:
        fh = open(outfile, 'w', newline='')
    else:
        fh = sys.stdout

    writer = csv.writer(fh)
    writer.writerow(meta_voltage)
    writer.writerow(meta_ct)
    writer.writerow(header)

    # Data rows
    for k in by_name:
        ref_name, arc, edge = k
        # Use count, cell_type, vt from reference corner or first available
        count = ''
        cell_type = ''
        vt = ''
        for c in corners:
            if k in all_data[c]:
                count = all_data[c][k]['count']
                cell_type = all_data[c][k].get('cell_type', '')
                vt = all_data[c][k].get('vt', '')
                break

        row = [ref_name, cell_type, vt, arc, edge, count]

        # Delay columns
        for c in corners:
            if k in all_data[c]:
                row.append(f"{all_data[c][k]['avg']:.6f}")
            else:
                row.append('')

        # Scaling ratio columns
        for c in corners[1:]:
            if k in all_data[ref_corner] and k in all_data[c]:
                ref_d = all_data[ref_corner][k]['avg']
                if ref_d > 0:
                    row.append(f"{all_data[c][k]['avg'] / ref_d:.4f}")
                else:
                    row.append('')
            else:
                row.append('')

        writer.writerow(row)

    # Summary rows (blank separator + scaling stats)
    if len(corners) > 1:
        writer.writerow([])
        writer.writerow(['# Scaling Summary'])
        for c in corners[1:]:
            ratios = []
            weighted_sum = 0.0
            total_weight = 0
            for k in common:
                ref_d = all_data[ref_corner][k]['avg']
                if ref_d > 0:
                    ratio = all_data[c][k]['avg'] / ref_d
                    ratios.append(ratio)
                    weight = all_data[ref_corner][k]['count']
                    weighted_sum += ratio * weight
                    total_weight += weight

            if ratios:
                avg_r = sum(ratios) / len(ratios)
                wavg_r = weighted_sum / total_weight if total_weight > 0 else 0
                min_r = min(ratios)
                max_r = max(ratios)
                writer.writerow([f'# {c} vs {ref_corner}',
                                 f'avg={avg_r:.4f}',
                                 f'weighted={wavg_r:.4f}',
                                 f'range={min_r:.4f}..{max_r:.4f}',
                                 f'arcs={len(ratios)}'])

    if outfile:
        fh.close()
        print(f"Written to {outfile}", file=sys.stderr)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
par_status_diff.py — Partition Status Diff Tool
Compares IFC timing across 2 or 3 daily builds to show what changed:
regressions, improvements, new signals, and gone signals.

Usage:
  python3 par_status_diff.py --latest WW11G                    (auto-finds E,F,G)
  python3 par_status_diff.py --builds WW11E WW11G              (compare 2)
  python3 par_status_diff.py --builds WW11E WW11F WW11G        (compare 3)
  python3 par_status_diff.py --partition par_exe --latest WW11G (single partition)
  python3 par_status_diff.py --latest WW11G --threshold 10     (only show >10ps changes)

Output:
  Generates per-partition diff reports and a summary across all partitions.
  Saves to <outdir>/<partition>_diff.txt and all_par_diff_summary.txt

Data sources:
  <WA>/par_*_ifc.rpt  or  <WA>/test_par_*_ifc.rpt — IFC timing reports
"""

import argparse
import re
import os
import sys
import glob as globmod
from collections import defaultdict

# === ANSI COLORS ===
RED = '\033[1;31m'
GRN = '\033[1;32m'
YEL = '\033[1;33m'
BLU = '\033[1;34m'
MAG = '\033[1;35m'
CYN = '\033[1;36m'
WHT = '\033[1;37m'
DIM = '\033[2m'
RST = '\033[0m'

# === CONFIGURATION ===
WA_BASE = "/nfs/site/disks/idc_gfc_fct_bu_daily/work_area"
WA_PATTERN = "GFC_CLIENT_26ww08b_ww10_5_TIP_and_RCOs-FCT26{tag}_dcm_daily-CLK039.bu_postcts"

ALL_PARTITIONS = [
    'par_ooo_int', 'par_meu', 'par_ooo_vec', 'par_msid', 'par_fe',
    'par_exe', 'par_pmh', 'par_mlc', 'par_fmav0', 'par_fmav1', 'par_pm'
]


def find_wa(tag):
    """Find WA directory for a build tag like WW11G or WW12A."""
    # Try exact match with CLK039 first (older builds)
    wa_dir = os.path.join(WA_BASE, WA_PATTERN.format(tag=tag))
    if os.path.isdir(wa_dir):
        return wa_dir
    # Try glob for any CLK version (CLK039, CLK045, etc.)
    matches = globmod.glob(os.path.join(WA_BASE, f"*FCT26{tag}_dcm_daily-CLK*.bu_postcts"))
    if matches:
        return sorted(matches)[-1]  # latest CLK version
    # Broadest fallback
    matches = globmod.glob(os.path.join(WA_BASE, f"*{tag}*"))
    if matches:
        return sorted(matches)[-1]
    return None


def find_previous_builds(latest_tag):
    """Given a tag like WW11G, find the 2 previous builds (E, F)."""
    # Extract week and letter: WW11G → week=11, letter=G
    m = re.match(r'WW(\d+)([A-Z])', latest_tag)
    if not m:
        return []
    week = int(m.group(1))
    letter = m.group(2)
    letter_idx = ord(letter) - ord('A')

    builds = []
    for i in range(2, 0, -1):
        prev_idx = letter_idx - i
        if prev_idx >= 0:
            prev_tag = f"WW{week}{chr(ord('A') + prev_idx)}"
        else:
            # Previous week
            prev_week = week - 1
            # Assume up to 7 builds per week (A-G)
            prev_tag = f"WW{prev_week}{chr(ord('G') + prev_idx + 1)}"
        wa = find_wa(prev_tag)
        if wa:
            builds.append((prev_tag, wa))

    return builds


def parse_ifc(wa_path, partition):
    """Parse IFC report, dedup icore0/icore1, return dict of signal→{wns,tns,paths}."""
    # Try both naming conventions
    ifc_file = os.path.join(wa_path, f"{partition}_ifc.rpt")
    if not os.path.exists(ifc_file):
        ifc_file = os.path.join(wa_path, f"test_{partition}_ifc.rpt")
    if not os.path.exists(ifc_file):
        ifc_file = os.path.join(wa_path, f"test2_{partition}_ifc.rpt")
    if not os.path.exists(ifc_file):
        # Try glob for any prefix
        matches = globmod.glob(os.path.join(wa_path, f"*{partition}_ifc.rpt"))
        if matches:
            ifc_file = sorted(matches)[-1]
        else:
            return {}

    entries = {}
    with open(ifc_file) as f:
        for line in f:
            line = line.rstrip()
            if not line or line.startswith('-WNS') or line.startswith('#') or line.startswith('----'):
                continue
            parts = line.split()
            if len(parts) < 5:
                continue
            try:
                wns = int(float(parts[0]))
                wns_norm = float(parts[1])
                tns = int(float(parts[2]))
                paths = int(parts[3])
            except (ValueError, IndexError):
                continue

            # Get port names and strip icore prefix
            ports = parts[4:]
            ports_clean = []
            for p in ports:
                p = re.sub(r'\{?icore\d+/', '', p)
                p = p.strip('{}')
                ports_clean.append(p)

            # Build signal key from port names
            sig_names = extract_signals(' '.join(ports_clean))
            sig_key = '|'.join(sorted(set(sig_names))) if sig_names else ports_clean[0] if ports_clean else ''

            # Build crossing description
            crossing = build_crossing(ports_clean, partition)

            # Build display name
            display = build_display_name(ports_clean, partition)

            # Dedup: keep worst WNS
            if sig_key not in entries or wns < entries[sig_key]['wns']:
                entries[sig_key] = {
                    'wns': wns, 'tns': tns, 'paths': paths,
                    'wns_norm': wns_norm,
                    'crossing': crossing, 'display': display
                }

    return entries


def extract_signals(text):
    """Extract signal base names from port text."""
    signals = []
    patterns = [
        r'par_\w+/(\w+?)(?:\[|\*|_\d+_|\s|$)',
        r'par_\w+/(\w+)',
        r'\b([a-z][a-z0-9_]*m\d{3}h)\b',
        r'\b([a-z][a-z0-9_]*mnn+h)\b',
        r'\b([a-z][a-z0-9_]*m\d{3}l)\b',
        r'\b([a-z][a-z0-9_]*mnn+l)\b',
    ]
    for pat in patterns:
        for m in re.finditer(pat, text.lower()):
            sig = m.group(1)
            sig = re.sub(r'\[\d*\]', '', sig)
            sig = re.sub(r'_\*$', '', sig)
            sig = re.sub(r'\*', '', sig)
            if sig and len(sig) > 3:
                signals.append(sig)
    # Fallback: CR signals
    for m in re.finditer(r'\b(cr_\w+)\b', text.lower()):
        signals.append(m.group(1))
    # Fallback: FEEDTHRU signals
    for m in re.finditer(r'(\w+)_FEEDTHRU', text):
        signals.append(m.group(1).lower())
    return list(dict.fromkeys(signals))  # unique, preserve order


def build_crossing(ports, partition):
    """Build crossing description from port names."""
    pars = []
    for p in ports:
        m = re.match(r'(par_\w+)/', p)
        if m and m.group(1) not in pars:
            pars.append(m.group(1))
    if not pars:
        return partition
    return ' → '.join(pars)


def build_display_name(ports, partition):
    """Build short display name for a signal."""
    names = []
    for p in ports:
        # Strip par_xxx/ prefix
        name = re.sub(r'par_\w+/', '', p)
        if name not in names:
            names.append(name)
    if len(names) > 2:
        return f"{names[0]} → {names[1]}"
    elif len(names) == 2 and names[0] != names[1]:
        return f"{names[0]} → {names[1]}"
    elif names:
        return names[0]
    return '???'


def compute_diff(old_data, new_data, threshold=3):
    """Compare two IFC datasets, return categorized results."""
    all_keys = set(old_data.keys()) | set(new_data.keys())

    regressions = []  # got worse
    improvements = []  # got better
    new_signals = []  # only in new
    gone_signals = []  # only in old
    unchanged = 0

    for key in all_keys:
        in_old = key in old_data
        in_new = key in new_data

        if in_old and in_new:
            delta = new_data[key]['wns'] - old_data[key]['wns']
            entry = {
                'key': key,
                'display': new_data[key]['display'],
                'crossing': new_data[key]['crossing'],
                'old_wns': old_data[key]['wns'],
                'new_wns': new_data[key]['wns'],
                'delta': delta,
                'old_paths': old_data[key]['paths'],
                'new_paths': new_data[key]['paths'],
            }
            if delta < -threshold:
                regressions.append(entry)
            elif delta > threshold:
                improvements.append(entry)
            else:
                unchanged += 1

        elif in_new and not in_old:
            new_signals.append({
                'key': key,
                'display': new_data[key]['display'],
                'crossing': new_data[key]['crossing'],
                'wns': new_data[key]['wns'],
                'paths': new_data[key]['paths'],
            })

        elif in_old and not in_new:
            gone_signals.append({
                'key': key,
                'display': old_data[key]['display'],
                'crossing': old_data[key]['crossing'],
                'wns': old_data[key]['wns'],
                'paths': old_data[key]['paths'],
            })

    regressions.sort(key=lambda x: x['delta'])
    improvements.sort(key=lambda x: x['delta'], reverse=True)
    new_signals.sort(key=lambda x: x['wns'])
    gone_signals.sort(key=lambda x: x['wns'])

    return {
        'regressions': regressions,
        'improvements': improvements,
        'new': new_signals,
        'gone': gone_signals,
        'unchanged': unchanged,
    }


def format_diff_report(partition, tag_old, tag_new, diff, old_count, new_count):
    """Format a diff report as a list of lines."""
    lines = []
    lines.append("=" * 100)
    lines.append(f"  STATUS DIFF — {partition.upper()}")
    lines.append(f"  {tag_old} → {tag_new}")
    lines.append(f"  Families: {old_count} → {new_count}  (delta: {new_count - old_count:+d})")
    lines.append("=" * 100)
    lines.append("")

    nr = len(diff['regressions'])
    ni = len(diff['improvements'])
    nn = len(diff['new'])
    ng = len(diff['gone'])
    nu = diff['unchanged']

    lines.append(f"  REGRESSIONS (worse):    {nr:>4d} signals")
    lines.append(f"  IMPROVEMENTS (better):  {ni:>4d} signals")
    lines.append(f"  NEW (not in {tag_old}):     {nn:>4d} signals")
    lines.append(f"  GONE (not in {tag_new}):    {ng:>4d} signals")
    lines.append(f"  UNCHANGED:              {nu:>4d} signals")
    lines.append("")

    if nr > 0:
        lines.append(f"  {'─' * 95}")
        lines.append(f"  REGRESSIONS — got WORSE ({nr} signals)")
        lines.append(f"  {'─' * 95}")
        lines.append(f"  {'Signal':<55s}  {'Crossing':<25s}  {tag_old:>5s}  {tag_new:>5s}  {'Δ':>5s}")
        lines.append(f"  {'─'*55}  {'─'*25}  {'─'*5}  {'─'*5}  {'─'*5}")
        for e in diff['regressions']:
            disp = e['display'][:55]
            cross = e['crossing'][:25]
            lines.append(f"  {disp:<55s}  {cross:<25s}  {e['old_wns']:>5d}  {e['new_wns']:>5d}  {e['delta']:>+5d}")
        lines.append("")

    if ni > 0:
        lines.append(f"  {'─' * 95}")
        lines.append(f"  IMPROVEMENTS — got BETTER ({ni} signals)")
        lines.append(f"  {'─' * 95}")
        lines.append(f"  {'Signal':<55s}  {'Crossing':<25s}  {tag_old:>5s}  {tag_new:>5s}  {'Δ':>5s}")
        lines.append(f"  {'─'*55}  {'─'*25}  {'─'*5}  {'─'*5}  {'─'*5}")
        for e in diff['improvements']:
            disp = e['display'][:55]
            cross = e['crossing'][:25]
            lines.append(f"  {disp:<55s}  {cross:<25s}  {e['old_wns']:>5d}  {e['new_wns']:>5d}  {e['delta']:>+5d}")
        lines.append("")

    if nn > 0:
        lines.append(f"  {'─' * 95}")
        lines.append(f"  NEW SIGNALS — only in {tag_new} ({nn} signals)")
        lines.append(f"  {'─' * 95}")
        lines.append(f"  {'Signal':<55s}  {'Crossing':<25s}  {'WNS':>5s}  {'Paths':>5s}")
        lines.append(f"  {'─'*55}  {'─'*25}  {'─'*5}  {'─'*5}")
        for e in diff['new']:
            disp = e['display'][:55]
            cross = e['crossing'][:25]
            lines.append(f"  {disp:<55s}  {cross:<25s}  {e['wns']:>5d}  {e['paths']:>5d}")
        lines.append("")

    if ng > 0:
        lines.append(f"  {'─' * 95}")
        lines.append(f"  GONE SIGNALS — were in {tag_old}, not in {tag_new} ({ng} signals)")
        lines.append(f"  {'─' * 95}")
        lines.append(f"  {'Signal':<55s}  {'Crossing':<25s}  {'was':>5s}  {'Paths':>5s}")
        lines.append(f"  {'─'*55}  {'─'*25}  {'─'*5}  {'─'*5}")
        for e in diff['gone']:
            disp = e['display'][:55]
            cross = e['crossing'][:25]
            lines.append(f"  {disp:<55s}  {cross:<25s}  {e['wns']:>5d}  {e['paths']:>5d}")
        lines.append("")

    return lines


def colorize_line(line):
    """Add ANSI colors to a diff report line."""
    if line.startswith('=' * 10):
        return f"{WHT}{line}{RST}"
    if 'STATUS DIFF' in line:
        return f"{WHT}{line}{RST}"
    if 'REGRESSIONS' in line:
        return f"{RED}{line}{RST}"
    if 'IMPROVEMENTS' in line:
        return f"{GRN}{line}{RST}"
    if 'NEW SIGNALS' in line or 'NEW (not in' in line:
        return f"{YEL}{line}{RST}"
    if 'GONE SIGNALS' in line or 'GONE (not in' in line:
        return f"{CYN}{line}{RST}"
    if 'UNCHANGED' in line:
        return f"{DIM}{line}{RST}"
    if '─' * 10 in line:
        return f"{DIM}{line}{RST}"
    # Data rows with delta
    m = re.search(r'([+-]\d+)\s*$', line)
    if m:
        delta = int(m.group(1))
        if delta < -10:
            return f"{RED}{line}{RST}"
        elif delta < 0:
            return f"{YEL}{line}{RST}"
        elif delta > 10:
            return f"{GRN}{line}{RST}"
        elif delta > 0:
            return f"{GRN}{line}{RST}"
    # New signals with WNS
    if re.search(r'\s-\d+\s+\d+\s*$', line) and 'Signal' not in line:
        return f"{YEL}{line}{RST}"
    return line


def main():
    parser = argparse.ArgumentParser(description='par_status diff between daily builds')
    parser.add_argument('--latest', help='Latest build tag (e.g. WW11G). Auto-finds previous 2.')
    parser.add_argument('--builds', nargs='+', help='Build tags to compare (2 or 3)')
    parser.add_argument('--partition', '-p', default='all', help='Partition name or "all"')
    parser.add_argument('--threshold', '-t', type=int, default=3, help='Min WNS delta to report (ps)')
    parser.add_argument('--outdir', '-o', default='.', help='Output directory')
    parser.add_argument('--color', action='store_true', default=True, help='Bake ANSI colors into output files')
    parser.add_argument('--no-color', action='store_true', help='Plain text output (no colors)')
    args = parser.parse_args()

    use_color = args.color and not args.no_color

    # Determine which builds to compare
    if args.latest:
        latest_tag = args.latest.upper()
        wa_latest = find_wa(latest_tag)
        if not wa_latest:
            print(f"{RED}ERROR: Cannot find WA for {latest_tag}{RST}")
            sys.exit(1)

        prev = find_previous_builds(latest_tag)
        if not prev:
            print(f"{RED}ERROR: Cannot find previous builds for {latest_tag}{RST}")
            sys.exit(1)

        builds = prev + [(latest_tag, wa_latest)]

    elif args.builds:
        builds = []
        for tag in args.builds:
            tag = tag.upper()
            wa = find_wa(tag)
            if not wa:
                print(f"{RED}ERROR: Cannot find WA for {tag}{RST}")
                sys.exit(1)
            builds.append((tag, wa))
    else:
        parser.print_help()
        sys.exit(1)

    print(f"Comparing {len(builds)} builds:")
    for tag, wa in builds:
        print(f"  {tag}: {os.path.basename(wa)}")
    print()

    # Determine partitions
    if args.partition == 'all':
        partitions = ALL_PARTITIONS
    else:
        partitions = [args.partition]

    # Summary across all partitions
    summary = []
    summary.append("=" * 100)
    summary.append(f"  ALL-PARTITION DIFF SUMMARY")
    summary.append(f"  {builds[0][0]} → {builds[-1][0]}")
    summary.append("=" * 100)
    summary.append("")
    summary.append(f"  {'PARTITION':<14s}  {'Total→':>7s}  {'Regress':>7s}  {'Improve':>7s}  {'New':>5s}  {'Gone':>5s}  {'Unchg':>5s}  {'Worst Regression':<45s}  {'Δ':>5s}")
    summary.append(f"  {'─'*14}  {'─'*7}  {'─'*7}  {'─'*7}  {'─'*5}  {'─'*5}  {'─'*5}  {'─'*45}  {'─'*5}")

    for partition in partitions:
        print(f"Processing {partition}...")

        # Parse IFC from each build
        build_data = []
        for tag, wa in builds:
            data = parse_ifc(wa, partition)
            build_data.append((tag, data))

        # Compare first vs last (and optionally middle vs last)
        tag_old, data_old = build_data[0]
        tag_new, data_new = build_data[-1]

        diff = compute_diff(data_old, data_new, threshold=args.threshold)
        report_lines = format_diff_report(
            partition, tag_old, tag_new, diff,
            len(data_old), len(data_new)
        )

        # If 3 builds, add middle comparison too
        if len(build_data) == 3:
            tag_mid, data_mid = build_data[1]
            diff_mid = compute_diff(data_mid, data_new, threshold=args.threshold)
            mid_lines = format_diff_report(
                partition, tag_mid, tag_new, diff_mid,
                len(data_mid), len(data_new)
            )
            report_lines.append("")
            report_lines.extend(mid_lines)

        # Save report
        outfile = os.path.join(args.outdir, f"{partition}_diff.txt")
        with open(outfile, 'w') as f:
            for line in report_lines:
                if use_color:
                    f.write(colorize_line(line) + '\n')
                else:
                    f.write(line + '\n')

        # Add to summary
        nr = len(diff['regressions'])
        ni = len(diff['improvements'])
        nn = len(diff['new'])
        ng = len(diff['gone'])
        nu = diff['unchanged']
        worst_reg = diff['regressions'][0]['display'][:45] if nr > 0 else '---'
        worst_delta = diff['regressions'][0]['delta'] if nr > 0 else 0
        fam_change = f"{len(data_old)}→{len(data_new)}"

        sline = f"  {partition:<14s}  {fam_change:>7s}  {nr:>7d}  {ni:>7d}  {nn:>5d}  {ng:>5d}  {nu:>5d}  {worst_reg:<45s}  {worst_delta:>+5d}"
        summary.append(sline)

    summary.append("")

    # Save summary
    sumfile = os.path.join(args.outdir, "all_par_diff_summary.txt")
    with open(sumfile, 'w') as f:
        for line in summary:
            if use_color:
                f.write(colorize_line(line) + '\n')
            else:
                f.write(line + '\n')

    # Print summary to stdout
    print()
    for line in summary:
        print(colorize_line(line) if use_color else line)

    print()
    print(f"Files saved to {args.outdir}/")
    print(f"  all_par_diff_summary.txt + {len(partitions)} partition diff files")


if __name__ == '__main__':
    main()

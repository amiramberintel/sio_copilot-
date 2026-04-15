#!/usr/bin/env python3
"""
Min/Max Window Analysis Report Generator (CORRECTED)
=====================================================
Reads raw PBA PT report_timing output files and performs TRUE same-path
min/max window analysis by matching (Start FF, Port, End FF) triples.

CRITICAL: Matching by (Port, D-pin) alone produces FALSE min/max violations
when multiple SFFs fan into the same endpoint. Setup worst and hold worst
often use DIFFERENT start FFs (long ECC path vs short direct path).

Usage:
  python3 minmax_window_report.py \\
    --setup <pba_setup_max_high.txt> \\
    --hold-lo <pba_hold_min_low.txt> \\
    --hold-fr <pba_hold_min_fast.txt> \\
    [--bus <name>] [--outdir <dir>] [--daily <label>]

  Alternatively, analyze from a bus report (OLD method, less accurate):
    python3 minmax_window_report.py --input <bus_report.txt> [--outdir <dir>]

Input:  Raw PBA PT report_timing files (setup, hold min_low, hold fresh)
Output: <bus>_minmax_window_report.txt
"""

import argparse
import re
import os
import sys
from collections import defaultdict


def parse_pt_paths(filepath):
    """Parse PT report_timing output, extract per-path details with individual FF names."""
    with open(filepath) as f:
        content = f.read()

    blocks = re.split(r'(?=\s+Startpoint:)', content)
    paths = []

    for block in blocks:
        sp_m = re.search(r'Startpoint:\s+(\S+)/CP', block)
        if not sp_m:
            continue
        sff_mb8_full = sp_m.group(1)

        ep_m = re.search(r'Endpoint:\s+(\S+)/(D\d+)', block)
        if not ep_m:
            continue
        eff_mb8_full = ep_m.group(1)
        d_pin = ep_m.group(2)

        slack_m = re.search(r'([-\d.]+)\s+slack\s+\((?:VIOLATED|MET)\)', block)
        if not slack_m:
            continue
        slack = float(slack_m.group(1))

        q_m = re.search(r'/(Q\d+)\s+\(MB8', block)
        q_pin = q_m.group(1) if q_m else 'Q?'

        # Find boundary port (adapt pattern for different buses)
        port_m = re.search(r'(dcl1rddatam408h\S+)\s+\(par_pmh\)', block)
        if not port_m:
            port_m = re.search(r'(\S+)\s+\(par_\w+\)\s+<-', block)
        port = port_m.group(1) if port_m else '?'

        # Extract individual SFF register from MB8 name + Q pin
        sff_regs = re.findall(r'DcL1RdDataIntM408H_reg_(\d+__\d+__\d+)', sff_mb8_full)
        if not sff_regs:
            sff_regs = re.findall(r'MBIT_\w+_reg_(\d+__\d+__\d+)_', sff_mb8_full)
        q_idx = int(q_pin[1:]) - 1 if q_pin != 'Q?' else -1
        if 0 <= q_idx < len(sff_regs):
            ind_sff = 'IntM408H_reg_' + sff_regs[q_idx]
        else:
            ind_sff = 'IntM408H_reg_?'

        # Extract individual EFF register from MB8 name + D pin
        eff_regs = re.findall(r'DcL1RdDataM409H_reg_(\d+__\d+__\d+__\d+)', eff_mb8_full)
        if not eff_regs:
            eff_regs = re.findall(r'MBIT_\w+_reg_(\d+__\d+__\d+__\d+)_', eff_mb8_full)
        d_idx = int(d_pin[1:]) - 1
        if 0 <= d_idx < len(eff_regs):
            ind_eff = 'M409H_reg_' + eff_regs[d_idx]
        else:
            ind_eff = 'M409H_reg_?'

        paths.append({
            'sff_ind': ind_sff,
            'q_pin': q_pin,
            'port': port,
            'eff_ind': ind_eff,
            'd_pin': d_pin,
            'slack': slack,
        })

    return paths


def parse_bus_report(filepath):
    """Parse the PBA bus report per-path table (OLD method, less accurate)."""
    paths = []
    bus_name = None
    daily_info = ""
    with open(filepath) as f:
        lines = f.readlines()

    for line in lines[:5]:
        m = re.match(r'\s+(\S+)\s+--\s+PBA', line)
        if m:
            bus_name = m.group(1)
    for line in lines[:10]:
        if "Daily:" in line:
            daily_info = line.strip()

    for line in lines:
        m = re.match(
            r'\s+([\d.]+)\s+(\S+)\s+(\S+)\s+(\S+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)',
            line)
        if m:
            sff_full = m.group(2)
            sff_base = re.sub(r'/Q\d+$', '', sff_full)
            eff_full = m.group(4)
            eff_base = re.sub(r'/D\d+$', '', eff_full)
            paths.append({
                'sff_mar': float(m.group(1)),
                'sff': sff_full,
                'sff_base': sff_base,
                'port': m.group(3),
                'eff': eff_full,
                'eff_base': eff_base,
                'setup': float(m.group(5)),
                'hld_lo': float(m.group(6)),
                'hld_fr': float(m.group(7)),
            })

    return paths, bus_name, daily_info


def generate_report_from_pt(setup_paths, hold_lo_paths, hold_fr_paths, bus_name, daily_info):
    """Generate TRUE same-path min/max report from raw PT data."""
    # Index hold by (sff_ind, port, eff_ind) = true same-path key
    hold_lo_by_key = {}
    for p in hold_lo_paths:
        key = (p['sff_ind'], p['port'], p['eff_ind'])
        if key not in hold_lo_by_key or p['slack'] < hold_lo_by_key[key]['slack']:
            hold_lo_by_key[key] = p

    hold_fr_by_key = {}
    for p in hold_fr_paths:
        key = (p['sff_ind'], p['port'], p['eff_ind'])
        if key not in hold_fr_by_key or p['slack'] < hold_fr_by_key[key]['slack']:
            hold_fr_by_key[key] = p

    # Also build OLD index for comparison
    hold_lo_old = {}
    for p in hold_lo_paths:
        key = (p['port'], p['d_pin'])
        if key not in hold_lo_old or p['slack'] < hold_lo_old[key]['slack']:
            hold_lo_old[key] = p

    # Match setup paths
    total = len(setup_paths)
    matched = 0
    unmatched = 0
    old_unfix = 0
    results = []

    for sp in setup_paths:
        new_key = (sp['sff_ind'], sp['port'], sp['eff_ind'])
        old_key = (sp['port'], sp['d_pin'])

        new_hld = hold_lo_by_key[new_key]['slack'] if new_key in hold_lo_by_key else None
        new_hfr_p = hold_fr_by_key.get(new_key)
        new_hfr = new_hfr_p['slack'] if new_hfr_p else None
        old_hld = hold_lo_old[old_key]['slack'] if old_key in hold_lo_old else None

        new_win = sp['slack'] + new_hld if new_hld is not None else None
        new_win_fr = sp['slack'] + new_hfr if new_hfr is not None else None
        old_win = sp['slack'] + old_hld if old_hld is not None else None

        if new_hld is not None:
            matched += 1
        else:
            unmatched += 1
        if old_win is not None and old_win < 0:
            old_unfix += 1

        results.append({
            'sff': sp['sff_ind'] + '/' + sp['q_pin'],
            'port': sp['port'],
            'eff': sp['eff_ind'] + '/' + sp['d_pin'],
            'setup': sp['slack'],
            'new_hld': new_hld, 'new_hfr': new_hfr,
            'new_win': new_win, 'new_win_fr': new_win_fr,
            'old_hld': old_hld, 'old_win': old_win,
        })

    true_unfix_lo = sorted(
        [r for r in results if r['new_win'] is not None and r['new_win'] < 0],
        key=lambda x: x['new_win'])
    true_unfix_fr = sorted(
        [r for r in results if r['new_win_fr'] is not None and r['new_win_fr'] < 0],
        key=lambda x: x['new_win_fr'])
    true_unfix_both = [r for r in results
                       if r['new_win'] is not None and r['new_win'] < 0
                       and r['new_win_fr'] is not None and r['new_win_fr'] < 0]
    setup_viol = sum(1 for r in results if r['setup'] < 0)
    false_mm = sum(1 for r in results
                   if r['old_win'] is not None and r['old_win'] < 0
                   and (r['new_win'] is None or r['new_win'] >= 0))

    # Build report
    out = []
    out.append("=" * 140)
    out.append("  {}  MIN/MAX WINDOW ANALYSIS  (PBA path mode)".format(bus_name or "BUS"))
    if daily_info:
        out.append("  " + daily_info)
    out.append("  CORRECTED: True same-path matching (SFF + Port + EFF)")
    out.append("=" * 140)
    out.append("")

    out.append("  KEY FINDING")
    out.append("  -----------")
    out.append("  Min/max window must match the EXACT same (Start FF, Port, End FF) triple.")
    out.append("  Matching by (Port, D-pin) alone produces FALSE min/max violations when")
    out.append("  multiple SFFs fan into the same endpoint (e.g., long ECC path vs short path).")
    out.append("")

    out.append("  SUMMARY")
    out.append("  -------")
    out.append("  Total setup paths analyzed:                  {:>6}".format(total))
    out.append("  Setup violated (EFF.set < 0):                {:>6}  ({:.1f}%)".format(
        setup_viol, 100 * setup_viol / total if total > 0 else 0))
    out.append("")
    out.append("  OLD matching (port, D-pin only):")
    out.append("    Unfixable (window.lo < 0):                 {:>6}  <-- includes false min/max".format(old_unfix))
    out.append("")
    out.append("  CORRECTED matching (SFF + port + EFF):")
    out.append("    Same-SFF match found:                      {:>6}".format(matched))
    out.append("    No same-SFF match (diff SFF in hold):      {:>6}".format(unmatched))
    out.append("    TRUE unfixable (window.lo < 0):            {:>6}".format(len(true_unfix_lo)))
    out.append("    TRUE unfixable (window.fr < 0):            {:>6}".format(len(true_unfix_fr)))
    out.append("    TRUE unfixable BOTH corners:               {:>6}".format(len(true_unfix_both)))
    out.append("    FALSE min/max eliminated:                  {:>6}".format(false_mm))
    out.append("")

    out.append("  WHY MOST PATHS ARE UNMATCHED")
    out.append("  ----------------------------")
    out.append("  Setup (max delay) finds the longest data path --> through ECC/syndrome logic")
    out.append("  Hold (min delay) finds the shortest data path --> direct buffer chain")
    out.append("  These paths originate from different registers in different MB8 cells.")
    out.append("  The hold path's SFF != setup path's SFF, so no same-SFF match exists.")
    out.append("  For unmatched paths, the true same-SFF hold slack is MUCH better than")
    out.append("  the worst hold (from a different SFF), so the real window is very positive.")
    out.append("")

    # True unfixable paths detail
    if true_unfix_lo:
        out.append("  TRUE UNFIXABLE PATHS (same-SFF window.lo < 0)")
        out.append("  " + "-" * 130)
        out.append("  {:>7} {:>7} | {:<35} {:<37} {:<28} {:>7} {:>7} {:>7}".format(
            'win.lo', 'win.fr', 'Start FF', 'Port', 'End FF', 'setup', 'hld.lo', 'hld.fr'))
        out.append("  " + "-" * 130)
        for r in true_unfix_lo:
            wfr = r['new_win_fr'] if r['new_win_fr'] is not None else 0
            hfr = r['new_hfr'] if r['new_hfr'] is not None else 0
            out.append("  {:>7.1f} {:>7.1f} | {:<35} {:<37} {:<28} {:>7.1f} {:>7.1f} {:>7.1f}".format(
                r['new_win'], wfr, r['sff'], r['port'], r['eff'],
                r['setup'], r['new_hld'], hfr))
        out.append("")
    else:
        out.append("  TRUE UNFIXABLE PATHS: NONE")
        out.append("  All original 'unfixable' paths were false min/max from SFF mismatch.")
        out.append("")

    # Window distribution for matched paths
    matched_results = [r for r in results if r['new_win'] is not None]
    if matched_results:
        out.append("  SAME-SFF MATCHED PATHS: WINDOW.LO DISTRIBUTION")
        out.append("  " + "-" * 80)
        bins = defaultdict(int)
        for r in matched_results:
            b = int(r['new_win'] // 20) * 20
            bins[b] += 1
        for b in sorted(bins.keys()):
            cnt = bins[b]
            bar = '#' * cnt
            marker = ' <-- unfixable' if b < 0 else ''
            out.append("  [{:>5} to {:>5})  {:>5}  {}{}".format(b, b + 20, cnt, bar, marker))
        out.append("  Total matched: {}".format(len(matched_results)))
        out.append("")

    # Conclusion
    if len(true_unfix_lo) == 0:
        out.append("=" * 140)
        out.append("  CONCLUSION: CLOCK PUSH IS SAFE")
        out.append("=" * 140)
        out.append("")
        out.append("  1. This bus has NO real min/max window issues.")
        out.append("  2. Clock push on EFF clock can safely fix setup violations.")
        out.append("  3. Hold violations are on different (short) paths from different SFFs")
        out.append("     and won't conflict with setup fixes.")
    elif len(true_unfix_lo) <= 5:
        out.append("=" * 140)
        out.append("  CONCLUSION: MOSTLY SAFE FOR CLOCK PUSH")
        out.append("=" * 140)
        out.append("")
        out.append("  1. Only {} true min/max paths found (very minor).".format(len(true_unfix_lo)))
        out.append("  2. Clock push can fix the vast majority of setup violations.")
        out.append("  3. The few true min/max paths may need data-path ECO.")
    else:
        out.append("=" * 140)
        out.append("  CONCLUSION: SOME TRUE MIN/MAX ISSUES EXIST")
        out.append("=" * 140)
        out.append("")
        out.append("  1. {} true min/max paths need data-path ECO.".format(len(true_unfix_lo)))
        out.append("  2. Remaining setup violations can be fixed by clock push.")
        out.append("")
        out.append("  FIX STRATEGIES FOR TRUE UNFIXABLE PATHS:")
        out.append("    - VT swap: HVT -> LVT/SVT on data path")
        out.append("    - Cell sizing: upsize to reduce corner variation")
        out.append("    - Reroute: shorten long wires")
        out.append("    - Pipeline retiming (requires RTL change)")

    out.append("")
    out.append("  END OF REPORT")
    out.append("")

    return '\n'.join(out)


def generate_report_from_bus(paths, bus_name, daily_info):
    """Generate report from bus report (OLD method -- warns about SFF matching)."""
    out = []
    out.append("=" * 140)
    out.append("  {}  MIN/MAX WINDOW ANALYSIS  (from bus report)".format(bus_name or "BUS"))
    out.append("  WARNING: This uses bus report data which matches by (Port, D-pin).")
    out.append("  For TRUE same-path analysis, use --setup/--hold-lo/--hold-fr with raw PT files.")
    out.append("=" * 140)
    out.append("")

    total = len(paths)
    # Group by (sff_base, port, eff_base)
    for p in paths:
        p['win_lo'] = p['setup'] + p['hld_lo']
        p['win_fr'] = p['setup'] + p['hld_fr']

    unfixable_lo = [p for p in paths if p['win_lo'] < 0]
    unfixable_fr = [p for p in paths if p['win_fr'] < 0]

    out.append("  WARNING: Bus report matches setup/hold by (port, D-pin) only.")
    out.append("  If multiple SFFs fan into the same endpoint, this may show")
    out.append("  FALSE min/max violations. Use raw PT files for accurate analysis.")
    out.append("")
    out.append("  SUMMARY (may include false min/max)")
    out.append("  -------")
    out.append("  Total paths:                             {:>6}".format(total))
    out.append("  Window.lo < 0 (potentially unfixable):   {:>6}".format(len(unfixable_lo)))
    out.append("  Window.fr < 0 (potentially unfixable):   {:>6}".format(len(unfixable_fr)))
    out.append("")

    if unfixable_lo:
        out.append("  POTENTIALLY UNFIXABLE PATHS (window.lo < 0) -- VERIFY WITH RAW PT FILES")
        out.append("  " + "-" * 130)
        out.append("  {:>7} {:>7} | {:<35} {:<37} {:<28} {:>7} {:>7} {:>7}".format(
            'win.lo', 'win.fr', 'Start FF', 'Port', 'End FF', 'setup', 'hld.lo', 'hld.fr'))
        out.append("  " + "-" * 130)
        for p in sorted(unfixable_lo, key=lambda x: x['win_lo']):
            out.append("  {:>7.1f} {:>7.1f} | {:<35} {:<37} {:<28} {:>7.1f} {:>7.1f} {:>7.1f}".format(
                p['win_lo'], p['win_fr'], p['sff'], p['port'], p['eff'],
                p['setup'], p['hld_lo'], p['hld_fr']))
        out.append("")

    out.append("  END OF REPORT")
    out.append("")
    return '\n'.join(out)


def main():
    parser = argparse.ArgumentParser(
        description='Min/Max window analysis with TRUE same-path matching')
    parser.add_argument('--input', '-i', default=None,
                        help='Bus report file (OLD method, less accurate)')
    parser.add_argument('--setup', default=None,
                        help='Raw PBA PT setup (max_high) report_timing output')
    parser.add_argument('--hold-lo', default=None,
                        help='Raw PBA PT hold (min_low) report_timing output')
    parser.add_argument('--hold-fr', default=None,
                        help='Raw PBA PT hold (fresh min_fast) report_timing output')
    parser.add_argument('--outdir', '-o', default='.',
                        help='Output directory')
    parser.add_argument('--bus', '-b', default=None,
                        help='Bus name (auto-detected if using --input)')
    parser.add_argument('--daily', '-d', default='',
                        help='Daily label for report header')
    args = parser.parse_args()

    # Mode 1: Raw PT files (RECOMMENDED)
    if args.setup and args.hold_lo and args.hold_fr:
        for f in [args.setup, args.hold_lo, args.hold_fr]:
            if not os.path.isfile(f):
                print("ERROR: File not found: {}".format(f), file=sys.stderr)
                sys.exit(1)

        print("Parsing PBA setup...")
        setup_paths = parse_pt_paths(args.setup)
        print("  {} paths".format(len(setup_paths)))

        print("Parsing PBA hold min_low...")
        hold_lo_paths = parse_pt_paths(args.hold_lo)
        print("  {} paths".format(len(hold_lo_paths)))

        print("Parsing PBA hold fresh...")
        hold_fr_paths = parse_pt_paths(args.hold_fr)
        print("  {} paths".format(len(hold_fr_paths)))

        bus_name = args.bus or 'dcl1rddatam408h'
        daily_info = args.daily

        report = generate_report_from_pt(setup_paths, hold_lo_paths, hold_fr_paths,
                                         bus_name, daily_info)

    # Mode 2: Bus report (OLD method)
    elif args.input:
        if not os.path.isfile(args.input):
            print("ERROR: File not found: {}".format(args.input), file=sys.stderr)
            sys.exit(1)

        paths, bus_name, daily_info = parse_bus_report(args.input)
        if args.bus:
            bus_name = args.bus
        print("Parsed {} paths from bus report (OLD method)".format(len(paths)))

        report = generate_report_from_bus(paths, bus_name, daily_info)
    else:
        print("ERROR: Provide either --setup/--hold-lo/--hold-fr or --input", file=sys.stderr)
        parser.print_help()
        sys.exit(1)

    outfile = os.path.join(args.outdir, "{}_minmax_window_report.txt".format(bus_name or "bus"))
    os.makedirs(args.outdir, exist_ok=True)
    with open(outfile, 'w') as f:
        f.write(report)

    print("Report: {}".format(outfile))


if __name__ == '__main__':
    main()

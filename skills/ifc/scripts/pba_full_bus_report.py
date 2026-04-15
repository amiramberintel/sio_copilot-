#!/usr/bin/env python3
"""
pba_full_bus_report.py -- Generate per-bit PBA bus analysis report
Author: sunger (with copilot) | Date: 2026-04-09

Usage:
  python3 pba_full_bus_report.py \
    --setup   /tmp/pba_setup_max_high.txt \
    --hold-lo /tmp/pba_hold_min_low.txt \
    --hold-fr /tmp/pba_hold_min_fast.txt \
    --sff     /tmp/pba_sff_setup.txt \
    --bus     dcl1rddatam408h \
    --daily   "FCT26WW15D_dcm_daily / CLK050" \
    --outdir  /path/to/output/

See cookbook: cookbooks/pba_full_bus_report_cookbook.txt
"""

import re
import sys
import os
import argparse
from collections import defaultdict, Counter


def parse_report(filepath, bus_pattern):
    """Parse PT report_timing -nosplit output. Extract boundary pin, SFF, EFF, slack."""
    paths = {}
    sff = eff = bpin = None
    pin_re = re.compile(
        r'(icore0/par_\w+/' + bus_pattern + r'_\S+\[\d+\])\s+\(par_\w+\)\s+<-'
    )
    with open(filepath) as f:
        for line in f:
            line = line.rstrip()
            m = re.match(r'\s*Startpoint:\s+(\S+)', line)
            if m:
                sff = m.group(1); eff = bpin = None; continue
            m = re.match(r'\s*Endpoint:\s+(\S+)', line)
            if m:
                eff = m.group(1); continue
            m = pin_re.search(line)
            if m:
                bpin = m.group(1); continue
            m = re.search(r'([-]?\d+\.\d+)\s+slack\s+\((MET|VIOLATED)\)', line)
            if m and bpin and sff and eff:
                slack = float(m.group(1))
                pin = bpin.split('/', 2)[-1]  # remove icore0/par_xxx/
                # keep shortest hierarchy: just par_name/pin
                parts = bpin.split('/')
                pin = '/'.join(parts[1:])  # par_pmh/dcl1rddatam408h_...
                pin_short = parts[-1]  # dcl1rddatam408h_...  (for grouping key)
                paths[pin_short] = {
                    'sff_full': sff, 'eff_full': eff,
                    'slack': slack, 'bpin_full': bpin
                }
                sff = eff = bpin = None
    return paths


def parse_sff_setup(filepath):
    """Parse SFF incoming setup report. Returns {CP_path: worst_slack}."""
    result = {}
    ep = None
    with open(filepath) as f:
        for line in f:
            line = line.rstrip()
            m = re.match(r'\s*Endpoint:\s+(\S+)', line)
            if m:
                ep = m.group(1); continue
            m = re.search(r'([-]?\d+\.\d+)\s+slack\s+\((MET|VIOLATED)\)', line)
            if m and ep:
                s = float(m.group(1))
                cp = ep.rsplit('/', 1)[0] + '/CP'
                if cp not in result or s < result[cp]:
                    result[cp] = s
                ep = None
    return result


def short_sff(full):
    """Abbreviate SFF MB8 cell name."""
    regs = re.findall(r'DcL1RdDataIntM408H_reg_(\d+)__(\d+)__(\d+)', full)
    if regs:
        a, b = regs[0], regs[-1]
        return f"IntM408H_reg_{a[0]}__{a[1]}__[{a[2]}..{b[2]}]/CP"
    # Generic fallback
    rel = re.sub(r'^icore0/par_\w+/', '', full)
    return rel[:60]


def short_eff(full):
    """Abbreviate EFF MB8 cell name."""
    regs = re.findall(r'DcL1RdDataM409H_reg_(\d+)__(\d+)__(\d+)__(\d+)', full)
    bank_m = re.search(r'dcibbankd(\d+)', full)
    bank = bank_m.group(1) if bank_m else '?'
    dpin_m = re.search(r'/(D\d+)', full)
    dpin = dpin_m.group(1) if dpin_m else '?'
    if regs:
        a = regs[0]
        return f"bk{bank}/M409H_reg_{a[0]}__{a[1]}__{a[2]}__[0..7]/{dpin}"
    rel = re.sub(r'^icore0/par_\w+/', '', full)
    return rel[:60]


def make_histogram(slacks, bin_size=5, bar_width=60):
    """Build ASCII histogram lines."""
    if not slacks:
        return ["    (no data)"]
    bins = Counter()
    for s in slacks:
        b = int(s // bin_size) * bin_size
        bins[b] += 1
    max_count = max(bins.values()) if bins else 1
    lines = []
    lines.append(f"  SETUP SLACK HISTOGRAM (max_high PBA, {bin_size}ps bins):")
    lines.append("  " + "=" * 78)
    lines.append(f"    {'Slack range':>16s}  {'Count':>5s}  Bar")
    lines.append(f"    {'':>16s}  {'':>5s}  |")
    for b in sorted(bins):
        cnt = bins[b]
        bar_len = int(cnt / max_count * bar_width)
        bar = '#' * bar_len
        marker = "  <-- WNS=0" if b <= 0 < b + bin_size else ""
        lines.append(f"    [{b:>4d} to {b+bin_size:>4d})  {cnt:>5d}  {bar}{marker}")
    lines.append(f"    {'':>16s}  {'':>5s}  |")
    n_viol = sum(1 for s in slacks if s < 0)
    n_met = sum(1 for s in slacks if s >= 0)
    lines.append(f"    Total: {len(slacks)} paths   |   Violating (< 0): {n_viol}   |   Met (>= 0): {n_met}")
    ss = sorted(slacks)
    lines.append(f"    WNS: {ss[0]:.1f} ps   |   Median: {ss[len(ss)//2]:.1f} ps   |   Best: {ss[-1]:.1f} ps")
    return lines


def generate_report(setup, hold_ml, hold_fr, sff_map, bus_name, daily_tag):
    """Generate the full report as a list of lines."""
    all_pins = sorted(set(list(setup.keys()) + list(hold_ml.keys()) + list(hold_fr.keys())))

    # Merge per-pin data
    data = {}
    for pin in all_pins:
        d = {}
        for src, k in [(setup, 'setup'), (hold_ml, 'hold_ml'), (hold_fr, 'hold_fr')]:
            if pin in src:
                d[k] = src[pin]['slack']
                if 'sff_full' not in d:
                    d['sff_full'] = src[pin]['sff_full']
                    d['eff_full'] = src[pin]['eff_full']
        d['sff_setup'] = sff_map.get(d.get('sff_full', ''))
        d['sff_short'] = short_sff(d.get('sff_full', ''))
        d['eff_short'] = short_eff(d.get('eff_full', ''))
        data[pin] = d

    # Stats
    s_slacks = [d['setup'] for d in data.values() if 'setup' in d]
    h_lo = [d['hold_ml'] for d in data.values() if 'hold_ml' in d]
    h_fr = [d['hold_fr'] for d in data.values() if 'hold_fr' in d]
    sff_s = [d['sff_setup'] for d in data.values() if d.get('sff_setup') is not None]

    out = []
    w = 180

    # Header
    out.append("=" * w)
    out.append(f"  {bus_name} -- FULL BUS ANALYSIS -- SFF (par_pmh) --> Port --> EFF (par_meu)")
    out.append(f"  Daily: {daily_tag}  |  PBA/POCV")
    out.append(f"  Total paths: {len(all_pins)}")
    out.append("=" * w)
    out.append("")

    # How to read
    out.append("  HOW TO READ THIS REPORT:")
    out.append("  ========================")
    out.append("  Each line = one timing path through the bus:")
    out.append("")
    out.append("    SFF.margin  = setup slack ARRIVING at the Start FF (max_high corner)")
    out.append("                  This is your budget to PULL the SFF clock (mclk_pmh)")
    out.append("                  Positive = margin available, pull up to this amount")
    out.append("")
    out.append("    EFF.setup   = setup slack at the End FF (max_high corner)")
    out.append("                  This is the VIOLATION you need to fix by push + pull")
    out.append("                  Negative = violation, you need push+pull >= |this value|")
    out.append("")
    out.append("    EFF.hld.lo  = hold slack at the End FF (func.min_low corner)")
    out.append("    EFF.hld.fr  = hold slack at the End FF (fresh.min_fast corner)")
    out.append("                  Positive = margin, pushing EFF clock eats into this")
    out.append("                  After push, PTECO fixes any new hold violations")
    out.append("")
    out.append("  DECISION: for each path, need:  push(EFF) + pull(SFF) >= |EFF.setup|")
    out.append("            constrained by:       pull(SFF) <= SFF.margin")
    out.append("            hold cost:            new_hold = EFF.hld - push(EFF)")
    out.append("")

    # Summary
    if s_slacks and h_lo and h_fr and sff_s:
        out.append("  SUMMARY:")
        out.append(f"    SFF margin (worst):  {min(sff_s):.1f} ps   (limits total SFF pull)")
        out.append(f"    EFF setup  (WNS):   {min(s_slacks):.1f} ps  (need {abs(min(s_slacks)):.0f}ps total fix)")
        out.append(f"    EFF hold.lo (WNS):  {min(h_lo):.1f} ps  (pre-PTECO, {sum(1 for s in h_lo if s<0)} violations)")
        out.append(f"    EFF hold.fr (WNS):   {min(h_fr):.1f} ps  (CLEAN, {sum(1 for s in h_fr if s<0)} violations)")
        out.append("")

        # Push/pull impact
        out.append("  PUSH/PULL IMPACT:")
        out.append(f"    {'Push':>5s} {'Pull':>5s} {'Total':>5s}  {'EFF.set':>8s} {'EFF.h.lo':>8s} {'EFF.h.fr':>8s} {'SFF.mar':>8s}  {'h.lo viol':>10s} {'h.fr viol':>10s}")
        out.append(f"    {'-'*5} {'-'*5} {'-'*5}  {'-'*8} {'-'*8} {'-'*8} {'-'*8}  {'-'*10} {'-'*10}")
        for push, pull in [(0,0),(10,0),(20,0),(30,0),(40,0),(44,0),(40,1),(35,1),(30,1),(20,1)]:
            t = push + pull
            n_paths = max(len(h_lo), len(h_fr))
            out.append(f"    {push:5d} {pull:5d} {t:5d}  {min(s_slacks)+t:8.1f} {min(h_lo)-push:8.1f} {min(h_fr)-push:8.1f} {min(sff_s)-pull:8.1f}  {sum(1 for s in h_lo if s-push<0):>7d}/{n_paths} {sum(1 for s in h_fr if s-push<0):>7d}/{n_paths}")
        out.append("")

    # Histogram
    if s_slacks:
        out.extend(make_histogram(s_slacks))
        out.append("")

    # Per-path table
    out.append("=" * w)
    out.append("  PER-PATH TABLE")
    out.append("  Sorted by worst EFF setup slack (most violated first)")
    out.append("=" * w)
    out.append("")

    def pin_sort_key(pin):
        return data[pin].get('setup', 999)

    # Group by EFF cell
    eff_groups = defaultdict(list)
    for pin in all_pins:
        d = data[pin]
        eff_regs = re.findall(r'DcL1RdDataM409H_reg_(\d+__\d+__\d+)__\d+', d.get('eff_full', ''))
        bank_m = re.search(r'dcibbankd(\d+)', d.get('eff_full', ''))
        bank = bank_m.group(1) if bank_m else '?'
        eff_grp = f"bk{bank}_reg_{eff_regs[0]}" if eff_regs else "?"
        eff_groups[eff_grp].append(pin)

    def grp_sort(key):
        return min(data[p].get('setup', 999) for p in eff_groups[key])

    sorted_grps = sorted(eff_groups.keys(), key=grp_sort)

    out.append(f"    {'SFF.mar':>7s}  {'Start FF (par_pmh)':45s}  {'Port':42s}  {'End FF (par_meu)':45s}  {'EFF.set':>7s} {'EFF.h.lo':>8s} {'EFF.h.fr':>8s}")
    out.append(f"    {'pull$':>7s}  {'SFF cell / clk pin':45s}  {'boundary pin (pmh<->meu)':42s}  {'EFF cell / data pin':45s}  {'push$':>7s} {'hold':>8s} {'hold':>8s}")
    out.append("    " + "-" * 172)

    for gk in sorted_grps:
        pins = sorted(eff_groups[gk], key=pin_sort_key)
        worst = min(data[p].get('setup', 999) for p in pins)
        eff_n = data[pins[0]].get('eff_short', '?')
        eff_hdr = re.sub(r'/D\d+$', '', eff_n)
        out.append("")
        out.append(f"    --- EFF group: {eff_hdr}  (worst setup = {worst:.1f} ps) ---")
        for pin in pins:
            d = data[pin]
            ss = f"{d['sff_setup']:.0f}" if d.get('sff_setup') is not None else "n/a"
            se = f"{d['setup']:.1f}" if 'setup' in d else ">2"
            hl = f"{d['hold_ml']:.1f}" if 'hold_ml' in d else ">39"
            hf = f"{d['hold_fr']:.1f}" if 'hold_fr' in d else ">49"
            sff_name = d.get('sff_short', '?')
            eff_name = d.get('eff_short', '?')
            out.append(f"    {ss:>7s}  {sff_name:45s}  {pin:42s}  {eff_name:45s}  {se:>7s} {hl:>8s} {hf:>8s}")

    return out


def main():
    parser = argparse.ArgumentParser(description='Generate PBA full bus analysis report')
    parser.add_argument('--setup', required=True, help='PBA setup max_high report file')
    parser.add_argument('--hold-lo', required=True, help='PBA hold min_low report file')
    parser.add_argument('--hold-fr', required=True, help='PBA hold fresh.min_fast report file')
    parser.add_argument('--sff', required=True, help='PBA SFF incoming setup report file')
    parser.add_argument('--bus', required=True, help='Bus name pattern (e.g. dcl1rddatam408h)')
    parser.add_argument('--daily', default='unknown', help='Daily tag string for report header')
    parser.add_argument('--outdir', default='.', help='Output directory')
    args = parser.parse_args()

    print(f"Parsing setup:   {args.setup}")
    setup = parse_report(args.setup, args.bus)
    print(f"  -> {len(setup)} paths")

    print(f"Parsing hold.lo: {args.hold_lo}")
    hold_ml = parse_report(args.hold_lo, args.bus)
    print(f"  -> {len(hold_ml)} paths")

    print(f"Parsing hold.fr: {args.hold_fr}")
    hold_fr = parse_report(args.hold_fr, args.bus)
    print(f"  -> {len(hold_fr)} paths")

    print(f"Parsing SFF:     {args.sff}")
    sff_map = parse_sff_setup(args.sff)
    print(f"  -> {len(sff_map)} SFF cells")

    lines = generate_report(setup, hold_ml, hold_fr, sff_map, args.bus, args.daily)

    outfile = os.path.join(args.outdir, f"{args.bus}_full_bus_report.txt")
    with open(outfile, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print(f"\nReport: {outfile} ({len(lines)} lines)")


if __name__ == '__main__':
    main()

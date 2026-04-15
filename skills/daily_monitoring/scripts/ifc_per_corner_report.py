#!/usr/bin/env python3
"""Generate per-corner IFC timing report (setup + hold) for any partition.

Cross-references Gil's IFC family report with daily timing summary XMLs
and (optionally) Alex's PTECO nworst XMLs to produce a single ASCII report.

Usage:
  ifc_per_corner_report.py --daily <daily_wa> --par <partition> --outdir <dir> [--pteco <pteco_wa>] [--ifc <ifc_file>]

Examples:
  # par_meu with PTECO data
  ifc_per_corner_report.py \\
    --daily /nfs/site/disks/idc_gfc_fct_bu_daily/work_area/GFC_CLIENT_..._dcm_daily-CLK050.bu_postcts \\
    --par par_meu \\
    --pteco /nfs/site/disks/ayarokh_wa/pteco/runs/GFC/core_client_260329_ww13 \\
    --outdir /nfs/site/disks/sunger_wa/fc_data/my_learns/ww14_2

  # par_ooo_int without PTECO
  ifc_per_corner_report.py \\
    --daily /nfs/site/disks/idc_gfc_fct_bu_daily/work_area/GFC_CLIENT_..._dcm_daily-CLK050.bu_postcts \\
    --par par_ooo_int \\
    --outdir /nfs/site/disks/sunger_wa/fc_data/my_learns/ww15_1

  # Use a specific IFC file instead of auto-discovering from daily WA
  ifc_per_corner_report.py \\
    --daily <daily_wa> --par par_meu --outdir <dir> \\
    --ifc /path/to/my_par_meu_ifc.rpt
"""
import argparse
import os
import re
import sys
import glob
from collections import defaultdict

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def parse_args():
    p = argparse.ArgumentParser(
        description="Per-corner IFC timing report (setup + hold, daily + PTECO)")
    p.add_argument("--daily", required=True,
                   help="Daily build work area root (the .bu_postcts directory)")
    p.add_argument("--par", required=True,
                   help="Partition name, e.g. par_meu, par_ooo_int, par_exe")
    p.add_argument("--outdir", required=True,
                   help="Output directory for the report file")
    p.add_argument("--pteco", default=None,
                   help="PTECO run root (contains runs/core_client/...); optional")
    p.add_argument("--ifc", default=None,
                   help="Explicit IFC report file; auto-discovered from daily WA if omitted")
    p.add_argument("--legend", default=None,
                   help="Append PVT/OCV legend from this file (optional)")
    return p.parse_args()

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
def resolve_paths(args):
    daily = args.daily.rstrip("/")
    par = args.par
    short = par.replace("par_", "")  # e.g. "meu", "ooo_int"

    # STA directory
    sta_dir = f"{daily}/runs/core_client/n2p_htall_conf4/sta_pt"
    if not os.path.isdir(sta_dir):
        sys.exit(f"ERROR: STA directory not found: {sta_dir}")

    # IFC file: explicit > <daily>/par_<name>_ifc.rpt > <outdir>/par_<name>_ifc.rpt
    if args.ifc:
        ifc_file = args.ifc
    else:
        ifc_file = f"{daily}/{par}_ifc.rpt"
        if not os.path.exists(ifc_file):
            alt = os.path.join(args.outdir, f"{par}_ifc.rpt")
            if os.path.exists(alt):
                ifc_file = alt
    if not os.path.exists(ifc_file):
        sys.exit(f"ERROR: IFC file not found: {ifc_file}\n"
                 f"  Tried: {daily}/{par}_ifc.rpt and {args.outdir}/{par}_ifc.rpt\n"
                 f"  Use --ifc to specify explicitly.")

    # PTECO reports directory
    pteco_reports = None
    if args.pteco:
        pteco_reports = f"{args.pteco}/runs/core_client/n2p_htall_conf4/pt_eco/reports"
        if not os.path.isdir(pteco_reports):
            # Try if user passed the reports dir directly
            if os.path.isdir(args.pteco) and glob.glob(f"{args.pteco}/*nworst*xml"):
                pteco_reports = args.pteco
            else:
                print(f"WARNING: PTECO reports dir not found: {pteco_reports}", file=sys.stderr)
                pteco_reports = None

    # Derive labels for the report header
    daily_label = os.path.basename(daily)
    m = re.search(r'FCT(\d+WW\d+\w)', daily_label)
    daily_tag = m.group(1) if m else daily_label[:40]
    m = re.search(r'(CLK\d+)', daily_label)
    clk_tag = m.group(1) if m else ""

    pteco_label = ""
    if args.pteco:
        pteco_label = os.path.basename(args.pteco.rstrip("/"))

    return dict(
        daily=daily, par=par, short=short,
        sta_dir=sta_dir, ifc_file=ifc_file,
        pteco_reports=pteco_reports,
        daily_tag=daily_tag, clk_tag=clk_tag, pteco_label=pteco_label,
        outdir=args.outdir, legend_file=args.legend,
    )

# ---------------------------------------------------------------------------
# 1. Parse IFC
# ---------------------------------------------------------------------------
def parse_ifc(ifc_file, par):
    short = par.replace("par_", "")
    families = []
    with open(ifc_file) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('-WNS') or line.startswith('Ports'):
                continue
            parts = line.split()
            if len(parts) < 5:
                continue
            try:
                wns = int(parts[0])
                tns = int(parts[2])
            except Exception:
                continue
            npaths = int(parts[3])
            ports = parts[4:]

            raw_sig = ports[0]
            sig = re.sub(r'^\{?icore\d/par_\w+/', '', raw_sig)
            sig = re.sub(r'\[.*?\]', '', sig)
            sig = re.sub(r'[\{\}]', '', sig)
            sig = sig.rstrip('_*').rstrip('_')
            sig_lower = sig.lower()

            match_key = sig_lower
            match_key = re.sub(r'_\*$', '', match_key)
            match_key = re.sub(r'_op_\d+$', '', match_key)
            match_key = re.sub(r'_feedthru.*', '', match_key)

            # Direction from port ordering
            first_par = None
            second_par = None
            partner = "?"
            for p in ports:
                m = re.search(r'par_(\w+)/', p)
                if m:
                    pname = m.group(1)
                    if first_par is None:
                        first_par = pname
                    elif second_par is None and pname != first_par:
                        second_par = pname
                    if pname != short:
                        partner = pname

            if first_par == short and second_par:
                direction = f"{short} --> {second_par}"
            elif first_par and first_par != short:
                direction = f"{first_par} --> {short}"
            else:
                direction = f"{short} <-> {partner}"

            families.append(dict(
                sig=sig_lower, match_key=match_key,
                sig_display=sig[:42], wns=wns, tns=tns,
                npaths=npaths, partner=partner, direction=direction,
            ))

    # Deduplicate by match_key (keep worst WNS, accumulate paths/TNS)
    deduped = {}
    for fam in families:
        mk = fam['match_key']
        if mk not in deduped or fam['wns'] < deduped[mk]['wns']:
            deduped[mk] = fam
        else:
            deduped[mk]['npaths'] += fam['npaths']
            deduped[mk]['tns'] += fam['tns']

    unique = sorted(deduped.values(), key=lambda x: x['wns'])
    print(f"Loaded {len(families)} IFC lines -> {len(unique)} unique families", file=sys.stderr)
    return unique

# ---------------------------------------------------------------------------
# 2. Scan timing summary XMLs
# ---------------------------------------------------------------------------
def scan_xmls(xml_path, ifc_unique, par, extract_clocks=False):
    """Return (sig_data, sig_clocks).
       sig_data[match_key] = [worst_slack, path_count]
       sig_clocks[match_key] = (sp_clk, ep_clk)"""
    sig_data = defaultdict(lambda: [0, 0])
    sig_clocks = {}
    with open(xml_path) as f:
        for line in f:
            if par not in line:
                continue
            if 'icore1/' in line:
                continue
            m_slack = re.search(r' slack="(-?\d+)', line)
            if not m_slack:
                continue
            slack = int(m_slack.group(1))
            path_lower = line.lower()
            for fam in ifc_unique:
                mk = fam['match_key']
                if mk in path_lower:
                    if slack < sig_data[mk][0]:
                        sig_data[mk][0] = slack
                        if extract_clocks:
                            sp = re.search(r'startpoint_clock="([^"]+)"', line)
                            ep = re.search(r'endpoint_clock="([^"]+)"', line)
                            if sp and ep:
                                sig_clocks[mk] = (sp.group(1), ep.group(1))
                    sig_data[mk][1] += 1
                    break
    return dict(sig_data), sig_clocks

# ---------------------------------------------------------------------------
# 3. Discover corners & collect data
# ---------------------------------------------------------------------------
def collect_daily(sta_dir, ifc_unique, par):
    daily_data = {}
    all_clocks = {}
    corners = []

    for d in sorted(glob.glob(f"{sta_dir}/*")):
        bn = os.path.basename(d)
        if not (bn.startswith('func.max_') or bn.startswith('func.min_') or bn.startswith('fresh.min_')):
            continue
        if '.ct' in bn:
            continue
        xml = f"{d}/reports/core_client.{bn}_timing_summary.xml"
        if os.path.exists(xml):
            corners.append((bn, xml))

    if not corners:
        print("WARNING: No daily corners found!", file=sys.stderr)
        return daily_data, all_clocks, corners

    # First pass: all corners; extract clocks from max_high
    for cname, xml in corners:
        print(f"  daily {cname}...", file=sys.stderr)
        extract = (cname == 'func.max_high.T_85.typical')
        data, clks = scan_xmls(xml, ifc_unique, par, extract_clocks=extract)
        daily_data[cname] = data
        if clks:
            all_clocks.update(clks)

    # Second pass: fill missing clocks from other setup corners
    for cname, xml in corners:
        if 'max_' in cname and cname != 'func.max_high.T_85.typical':
            missing = [f['match_key'] for f in ifc_unique
                       if f['match_key'] not in all_clocks
                       and f['match_key'] in daily_data.get(cname, {})]
            if missing:
                print(f"  clocks from {cname} ({len(missing)} missing)...", file=sys.stderr)
                _, clks = scan_xmls(xml, ifc_unique, par, extract_clocks=True)
                for mk, pair in clks.items():
                    if mk not in all_clocks:
                        all_clocks[mk] = pair

    # Third pass: fill from hold corners
    for cname, xml in corners:
        if 'min_' in cname:
            missing = [f['match_key'] for f in ifc_unique
                       if f['match_key'] not in all_clocks
                       and f['match_key'] in daily_data.get(cname, {})]
            if missing:
                print(f"  clocks from {cname} ({len(missing)} missing)...", file=sys.stderr)
                _, clks = scan_xmls(xml, ifc_unique, par, extract_clocks=True)
                for mk, pair in clks.items():
                    if mk not in all_clocks:
                        all_clocks[mk] = pair

    print(f"  Extracted clocks for {len(all_clocks)}/{len(ifc_unique)} families", file=sys.stderr)
    return daily_data, all_clocks, corners


def collect_pteco(pteco_reports, ifc_unique, par):
    pteco_data = {}
    if not pteco_reports:
        return pteco_data
    for xml in sorted(glob.glob(f"{pteco_reports}/*nworst*xml")):
        bn = os.path.basename(xml)
        m = re.match(r'core_client\.(.+)_timing_summary\.nworst\.xml', bn)
        if m:
            cname = m.group(1)
            print(f"  pteco {cname}...", file=sys.stderr)
            data, _ = scan_xmls(xml, ifc_unique, par)
            pteco_data[cname] = data
    return pteco_data

# ---------------------------------------------------------------------------
# 4. Column definitions
# ---------------------------------------------------------------------------
# These are the standard GFC corners. The script auto-filters to only those
# actually present in the data so it works even if some corners are missing.

DAILY_SETUP_CORNERS = [
    ('func.max_high.T_85.typical',                    'max_hi'),
    ('func.max_nom.T_85.typical',                     'max_nom'),
    ('func.max_low.T_85.typical',                     'max_low'),
    ('func.max_med.T_85.typical',                     'max_med'),
    ('func.max_fast.F_125.rcworst_CCworst_T',         'max_fst'),
    ('func.max_slow_rc_high.S_125.rcworst_CCworst_T', 'max_sRC'),
]

DAILY_HOLD_CORNERS = [
    ('fresh.min_fast.F_125.rcworst_CCworst',          'fr_fst'),
    ('fresh.min_fast_cold.F_M40.rcworst_CCworst',     'fr_cld'),
    ('fresh.min_slow.S_125.cworst_CCworst',           'fr_slw'),
    ('fresh.min_hi_lo_hi.T_85.typical',               'fr_hlh'),
    ('func.min_low.T_85.typical',                     'mn_low'),
    ('func.min_nom.T_85.typical',                     'mn_nom'),
]

PTECO_SETUP_CORNERS = [
    ('func.max_high.T_85.typical',    'E_mx_hi'),
    ('func.max_nom.T_85.typical',     'E_mx_nom'),
    ('func.max_low.T_85.typical',     'E_mx_low'),
    ('func.max_med.T_85.typical',     'E_mx_med'),
]

PTECO_HOLD_CORNERS = [
    ('fresh.min_fast.F_125.rcworst_CCworst',      'E_fr_fst'),
    ('fresh.min_fast_cold.F_M40.rcworst_CCworst', 'E_fr_cld'),
    ('fresh.min_hi_lo_hi.T_85.typical',           'E_fr_hlh'),
    ('func.min_low.T_85.typical',                 'E_mn_low'),
    ('func.min_nom.T_85.typical',                 'E_mn_nom'),
]

# ---------------------------------------------------------------------------
# 5. Build report
# ---------------------------------------------------------------------------
CW = 8       # column width for corner data
CLK_W = 20   # clock column width
TNS_W = 7    # TNS column width
NP_W = 5     # #paths column width


def col_span(cols):
    return len(cols) * (CW + 1) - 1 if cols else 0

def make_header_row(cols):
    return ' '.join(f"{name:>{CW}s}" for _, name in cols)

def make_dash_row(cols):
    return ' '.join(f"{'-'*CW:>{CW}s}" for _ in cols)

def make_data_row(cols, data_dict, match_key):
    parts = []
    for cname, _ in cols:
        cd = data_dict.get(cname, {})
        if match_key in cd:
            parts.append(f"{cd[match_key][0]:>{CW}d}")
        else:
            parts.append(f"{'':>{CW}s}")
    return ' '.join(parts)


def build_report(ifc_unique, daily_data, pteco_data, all_clocks, cfg):
    par = cfg['par']
    short = cfg['short']

    # Filter columns to only those present in data
    daily_setup = [(c, s) for c, s in DAILY_SETUP_CORNERS if c in daily_data]
    daily_hold  = [(c, s) for c, s in DAILY_HOLD_CORNERS  if c in daily_data]
    pteco_setup = [(c, s) for c, s in PTECO_SETUP_CORNERS if c in pteco_data]
    pteco_hold  = [(c, s) for c, s in PTECO_HOLD_CORNERS  if c in pteco_data]

    dir_width = max((len(f['direction']) for f in ifc_unique), default=9)
    dir_width = max(dir_width, 9)

    prefix_w = 2 + 43 + 1 + dir_width + 1 + CLK_W + 1 + CLK_W + 1 + 4 + 1 + TNS_W + 1 + NP_W
    ds_w = col_span(daily_setup)
    ps_w = col_span(pteco_setup)
    dh_w = col_span(daily_hold)
    ph_w = col_span(pteco_hold)
    total_w = prefix_w + 3 + ds_w + 3 + ps_w + 4 + dh_w + 3 + ph_w

    out = []

    # Header
    out.append("=" * total_w)
    out.append(f"  {par.upper()} IFC TIMING -- PER-CORNER REPORT (WNS in ps)")
    pteco_hdr = f"   PTECO: {cfg['pteco_label']}" if cfg['pteco_label'] else ""
    out.append(f"  Daily: {cfg['daily_tag']} / {cfg['clk_tag']}{pteco_hdr}")
    out.append(f"  Daily WA: {cfg['daily']}")
    if cfg['pteco_reports']:
        out.append(f"  PTECO WA: {cfg['pteco_reports']}")
    out.append(f"  IFC: {os.path.basename(cfg['ifc_file'])} ({len(ifc_unique)} unique families)")
    out.append(f"  Blank = path not in failing XML.  Negative = WNS (ps).  SP_CLK=startpoint clock, EP_CLK=endpoint clock")
    out.append("=" * total_w)
    out.append("")

    # Section label row
    lbl = f"  {'':43s} {'':>{dir_width}s} {'':>{CLK_W}s} {'':>{CLK_W}s} {'':>4s} {'':>{TNS_W}s} {'':>{NP_W}s}"
    lbl += " | " + f"{'--- DAILY SETUP ---':^{ds_w}s}" if daily_setup else ""
    lbl += " | " + f"{'-- PTECO SETUP --':^{ps_w}s}" if pteco_setup else ""
    lbl += " || " + f"{'--- DAILY HOLD ---':^{dh_w}s}" if daily_hold else ""
    lbl += " | " + f"{'-- PTECO HOLD --':^{ph_w}s}" if pteco_hold else ""
    out.append(lbl)

    # Column name row
    h = f"  {'SIGNAL':<43s} {'DIRECTION':<{dir_width}s} {'SP_CLK':>{CLK_W}s} {'EP_CLK':>{CLK_W}s} {'WNS':>4s} {'TNS':>{TNS_W}s} {'#Path':>{NP_W}s}"
    if daily_setup: h += " | " + make_header_row(daily_setup)
    if pteco_setup: h += " | " + make_header_row(pteco_setup)
    if daily_hold:  h += " || " + make_header_row(daily_hold)
    if pteco_hold:  h += " | " + make_header_row(pteco_hold)
    out.append(h)

    # Dash row
    u = f"  {'-'*43:<43s} {'-'*dir_width:<{dir_width}s} {'-'*CLK_W:>{CLK_W}s} {'-'*CLK_W:>{CLK_W}s} {'-'*4:>4s} {'-'*TNS_W:>{TNS_W}s} {'-'*NP_W:>{NP_W}s}"
    if daily_setup: u += " | " + make_dash_row(daily_setup)
    if pteco_setup: u += " | " + make_dash_row(pteco_setup)
    if daily_hold:  u += " || " + make_dash_row(daily_hold)
    if pteco_hold:  u += " | " + make_dash_row(pteco_hold)
    out.append(u)

    # Data rows
    matched = 0
    for fam in ifc_unique:
        mk = fam['match_key']
        sp_clk, ep_clk = all_clocks.get(mk, ('', ''))

        row = (f"  {fam['sig_display']:<43s} {fam['direction']:<{dir_width}s} "
               f"{sp_clk:>{CLK_W}s} {ep_clk:>{CLK_W}s} "
               f"{fam['wns']:>4d} {fam['tns']:>{TNS_W}d} {fam['npaths']:>{NP_W}d}")

        has = False
        if daily_setup: row += " | " + make_data_row(daily_setup, daily_data, mk)
        if pteco_setup: row += " | " + make_data_row(pteco_setup, pteco_data, mk)
        if daily_hold:  row += " || " + make_data_row(daily_hold, daily_data, mk)
        if pteco_hold:  row += " | " + make_data_row(pteco_hold, pteco_data, mk)

        for cname, _ in daily_setup + daily_hold:
            if mk in daily_data.get(cname, {}):
                has = True
                break
        if has:
            matched += 1
        out.append(row)

    # Corner summary
    out.append("")
    out.append("=" * total_w)
    out.append("  CORNER SUMMARY")
    out.append("=" * total_w)
    out.append("")
    out.append(f"  {'CORNER':<52s} {'SRC':>5s} {'TYPE':>5s} {'WNS':>6s} {'#Fam':>6s} {'#Paths':>8s}")
    out.append(f"  {'-'*52} {'-'*5:>5s} {'-'*5:>5s} {'-'*6:>6s} {'-'*6:>6s} {'-'*8:>8s}")

    for cname, sname in daily_setup + daily_hold:
        cd = daily_data.get(cname, {})
        ctype = "SETUP" if "max_" in cname else "HOLD"
        if cd:
            wns = min(v[0] for v in cd.values())
            nfam = len(cd)
            npaths = sum(v[1] for v in cd.values())
        else:
            wns = nfam = npaths = 0
        out.append(f"  {cname:<52s} {'DAILY':>5s} {ctype:>5s} {wns:>6d} {nfam:>6d} {npaths:>8d}")

    if pteco_setup or pteco_hold:
        out.append("")
        for cname, sname in pteco_setup + pteco_hold:
            cd = pteco_data.get(cname, {})
            ctype = "SETUP" if "max_" in cname else "HOLD"
            if cd:
                wns = min(v[0] for v in cd.values())
                nfam = len(cd)
                npaths = sum(v[1] for v in cd.values())
            else:
                wns = nfam = npaths = 0
            out.append(f"  {cname:<52s} {'PTECO':>5s} {ctype:>5s} {wns:>6d} {nfam:>6d} {npaths:>8d}")

    out.append("")
    out.append(f"  Matched {matched}/{len(ifc_unique)} IFC families to daily XML failing paths")
    out.append(f"  Clock pairs extracted for {len(all_clocks)}/{len(ifc_unique)} families")
    if pteco_setup or pteco_hold:
        out.append(f"  PTECO corners: setup={len(pteco_setup)} hold={len(pteco_hold)} ({cfg['pteco_label']})")
    out.append("")

    # Source paths for reproducibility
    out.append(f"  Sources:")
    out.append(f"    Daily : {cfg['daily']}")
    out.append(f"    IFC   : {cfg['ifc_file']}")
    if cfg['pteco_reports']:
        out.append(f"    PTECO : {cfg['pteco_reports']}")
    out.append("")

    return '\n'.join(out)


# ---------------------------------------------------------------------------
# 5b. Build CSV
# ---------------------------------------------------------------------------
import csv
from io import StringIO

def build_csv(ifc_unique, daily_data, pteco_data, all_clocks, cfg):
    """Build CSV version of the per-corner report."""
    daily_setup = [(c, s) for c, s in DAILY_SETUP_CORNERS if c in daily_data]
    daily_hold  = [(c, s) for c, s in DAILY_HOLD_CORNERS  if c in daily_data]
    pteco_setup = [(c, s) for c, s in PTECO_SETUP_CORNERS if c in pteco_data]
    pteco_hold  = [(c, s) for c, s in PTECO_HOLD_CORNERS  if c in pteco_data]

    buf = StringIO()
    w = csv.writer(buf)

    # Header row
    header = ['SIGNAL', 'DIRECTION', 'SP_CLK', 'EP_CLK', 'WNS', 'TNS', '#Path']
    for _, s in daily_setup:
        header.append(f"D_SETUP_{s}")
    for _, s in pteco_setup:
        header.append(f"P_SETUP_{s}")
    for _, s in daily_hold:
        header.append(f"D_HOLD_{s}")
    for _, s in pteco_hold:
        header.append(f"P_HOLD_{s}")
    w.writerow(header)

    # Data rows
    for fam in ifc_unique:
        mk = fam['match_key']
        sp_clk, ep_clk = all_clocks.get(mk, ('', ''))
        row = [fam['sig_display'], fam['direction'], sp_clk, ep_clk,
               fam['wns'], fam['tns'], fam['npaths']]

        for cname, _ in daily_setup:
            cd = daily_data.get(cname, {})
            row.append(cd[mk][0] if mk in cd else '')
        for cname, _ in pteco_setup:
            cd = pteco_data.get(cname, {})
            row.append(cd[mk][0] if mk in cd else '')
        for cname, _ in daily_hold:
            cd = daily_data.get(cname, {})
            row.append(cd[mk][0] if mk in cd else '')
        for cname, _ in pteco_hold:
            cd = pteco_data.get(cname, {})
            row.append(cd[mk][0] if mk in cd else '')

        w.writerow(row)

    return buf.getvalue()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    args = parse_args()
    cfg = resolve_paths(args)

    os.makedirs(cfg['outdir'], exist_ok=True)

    # 1. Parse IFC
    ifc_unique = parse_ifc(cfg['ifc_file'], cfg['par'])

    # 2. Collect daily data
    daily_data, all_clocks, _ = collect_daily(cfg['sta_dir'], ifc_unique, cfg['par'])

    # 3. Collect PTECO data
    pteco_data = collect_pteco(cfg['pteco_reports'], ifc_unique, cfg['par'])

    # 4. Build report
    report = build_report(ifc_unique, daily_data, pteco_data, all_clocks, cfg)
    print(report)

    # 4b. Build CSV
    csv_text = build_csv(ifc_unique, daily_data, pteco_data, all_clocks, cfg)

    # 5. Save
    outfile = os.path.join(cfg['outdir'], f"{cfg['par']}_per_corner_report.txt")

    # Preserve legend section if the file already exists
    legend_section = ""
    if os.path.exists(outfile):
        with open(outfile) as f:
            existing = f.read()
        marker = "  PVT & OCV REFERENCE"
        idx = existing.find(marker)
        if idx > 0:
            pre = existing[:idx].rstrip()
            last_eq = pre.rfind("=" * 20)
            if last_eq > 0:
                legend_section = '\n' + existing[last_eq:]
            else:
                legend_section = '\n' + existing[idx:]

    # Optionally append legend from external file
    if cfg['legend_file'] and os.path.exists(cfg['legend_file']):
        with open(cfg['legend_file']) as f:
            legend_section = '\n' + f.read()

    with open(outfile, 'w') as f:
        f.write(report.rstrip('\n'))
        if legend_section:
            f.write(legend_section)
        f.write('\n')

    # Save CSV
    csvfile = os.path.join(cfg['outdir'], f"{cfg['par']}_per_corner_report.csv")
    with open(csvfile, 'w') as f:
        f.write(csv_text)

    print(f"\nSaved to: {outfile}", file=sys.stderr)
    print(f"CSV  to: {csvfile}", file=sys.stderr)


if __name__ == '__main__':
    main()

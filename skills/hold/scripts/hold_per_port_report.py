#!/usr/bin/env python3
"""
hold_per_port_report.py — Multi-Corner Hold Per-Port Detail Report

Generates a detailed hold timing report showing every unique IFC crossing
(start port -> end port) with the actual start/end FF names and slack
across all available hold corners.

Usage:
  python3 hold_per_port_report.py --wa <WA_PATH> --par <PAR_NAME> --outdir <DIR>

Examples:
  python3 hold_per_port_report.py --wa /nfs/site/disks/idc_gfc_fct_bu_daily/work_area/GFC_CLIENT_26ww12b_ww13_1_initial_with_TIP-FCT26WW14B_dcm_daily-CLK050.bu_postcts --par par_meu --outdir /nfs/site/disks/sunger_wa/fc_data/my_learns/ww14_3

  # Uses default daily WA:
  python3 hold_per_port_report.py --par par_meu --outdir ./output

Output:
  <outdir>/<par_name>_hold_per_port.txt

Report structure:
  - Header: daily tag, CLK, partition, corner count
  - Corner Legend: short name, full name, STA directory path
  - Corner Summary: ports, paths, worst WNS per corner
  - Per-Port sections: grouped by IFC boundary port pair
    - PORT header: start_port --> end_port [IN/OUT from par_X] WNS= Paths=
    - Per-path rows: Clk(s>e), Port, slack per corner, Start FF --> End FF

Data source:
  <WA>/runs/core_client/n2p_htall_conf4/sta_pt/<corner>/reports/*_timing_summary.xml.filtered
"""

import xml.etree.ElementTree as ET
import argparse
import re
import os
import sys
from collections import defaultdict

# === CONFIGURATION ===
DEFAULT_WA = "/nfs/site/disks/idc_gfc_fct_bu_daily/work_area/GFC_CLIENT_26ww12b_ww13_1_initial_with_TIP-FCT26WW14B_dcm_daily-CLK050.bu_postcts"

HOLD_CORNERS = [
    ("func.min_low",     "mn_lo",  "func.min_low.T_85.typical"),
    ("func.min_nom",     "mn_nm",  "func.min_nom.T_85.typical"),
    ("func.min_high",    "mn_hi",  "func.min_high.T_85.typical"),
    ("func.min_turbo",   "mn_tb",  "func.min_turbo.T_85.typical"),
    ("fr.min_slow",      "fr_slw", "fresh.min_slow.S_125.cworst_CCworst"),
    ("fr.min_slow_cold", "fr_scd", "fresh.min_slow_cold.S_M40.cworst_CCworst"),
    ("fr.min_fast",      "fr_fst", "fresh.min_fast.F_125.rcworst_CCworst"),
    ("fr.min_fast_cold", "fr_fcd", "fresh.min_fast_cold.F_M40.rcworst_CCworst"),
    ("fr.min_lo_hi_hi",  "fr_lhh", "fresh.min_lo_hi_hi.T_85.typical"),
    ("fr.min_hi_lo_hi",  "fr_hlh", "fresh.min_hi_lo_hi.T_85.typical"),
    ("fr.min_hi_hi_lo",  "fr_hhl", "fresh.min_hi_hi_lo.T_85.typical"),
    ("fr.min_hvqk",      "fr_hvq", "fresh.min_hvqk.F_125.rcworst_CCworst"),
]


def find_xml(sta_dir, corner_dir):
    """Find the timing_summary.xml.filtered file for a corner."""
    rpt_dir = os.path.join(sta_dir, corner_dir, "reports")
    if not os.path.isdir(rpt_dir):
        return None
    for f in os.listdir(rpt_dir):
        if f.endswith("_timing_summary.xml.filtered") and "only_dfx" not in f:
            return os.path.join(rpt_dir, f)
    return None


def clean(s):
    """Strip icore0/icore1 prefix."""
    return re.sub(r'^icore[01]/', '', s)


def clean_bp(s):
    """Strip {}, icore prefix from boundary pin."""
    return re.sub(r'^[{\s]*(?:icore[01]/)?', '', s).rstrip('} ')


def parse_corner(xml_path, par_name):
    """Parse external paths for given partition. Return list of path dicts."""
    results = []
    for _, elem in ET.iterparse(xml_path, events=["end"]):
        if elem.tag != "path":
            continue
        if elem.get("int_ext") != "external":
            elem.clear()
            continue
        sp = elem.get("startpoint", "")
        ep = elem.get("endpoint", "")
        if par_name not in sp and par_name not in ep:
            elem.clear()
            continue

        slack = int(elem.get("slack", "0"))
        bpins_raw = elem.get("boundary_pins", "")
        sp_clk = elem.get("startpoint_clock", "")
        ep_clk = elem.get("endpoint_clock", "")

        bp_parts = bpins_raw.split()
        sp_clean = clean(sp)
        ep_clean = clean(ep)
        sp_par = sp_clean.split("/")[0]
        ep_par = ep_clean.split("/")[0]

        sp_bpin = ""
        ep_bpin = ""
        for bp in bp_parts:
            bpc = clean_bp(bp)
            if bpc.startswith(sp_par + "/"):
                sp_bpin = bpc
            elif bpc.startswith(ep_par + "/"):
                ep_bpin = bpc
        if not sp_bpin and len(bp_parts) >= 1:
            sp_bpin = clean_bp(bp_parts[0])
        if not ep_bpin and len(bp_parts) >= 2:
            ep_bpin = clean_bp(bp_parts[-1])

        port_key = f"{sp_bpin}||{ep_bpin}"
        sp_ff = "/".join(sp_clean.split("/")[1:])
        ep_ff = "/".join(ep_clean.split("/")[1:])
        path_key = f"{sp_ff}||{ep_ff}"

        results.append({
            "port_key": port_key, "path_key": path_key,
            "sp_bpin": sp_bpin, "ep_bpin": ep_bpin,
            "sp_ff": sp_ff, "ep_ff": ep_ff,
            "slack": slack, "sp_clk": sp_clk, "ep_clk": ep_clk,
        })
        elem.clear()
    return results


def port_worst(port_data):
    """Get worst slack across all corners for a port."""
    worst = 0
    for pth in port_data["paths"].values():
        for s in pth["slacks"].values():
            if s < worst:
                worst = s
    return worst


def main():
    parser = argparse.ArgumentParser(description="Multi-corner hold per-port detail report")
    parser.add_argument("--wa", default=DEFAULT_WA, help="Daily work area path")
    parser.add_argument("--par", required=True, help="Partition name (e.g. par_meu)")
    parser.add_argument("--outdir", required=True, help="Output directory")
    args = parser.parse_args()

    par_name = args.par
    daily = args.wa
    outdir = args.outdir
    sta_dir = os.path.join(daily, "runs/core_client/n2p_htall_conf4/sta_pt")

    if not os.path.isdir(sta_dir):
        print(f"ERROR: STA dir not found: {sta_dir}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(outdir, exist_ok=True)
    outfile = os.path.join(outdir, f"{par_name}_hold_per_port.txt")

    # Parse all corners
    print(f"Generating hold per-port report for {par_name}...", file=sys.stderr)
    print(f"  WA: {daily}", file=sys.stderr)
    active_corners = []
    ports = {}

    for cname, cshort, cdir in HOLD_CORNERS:
        xml = find_xml(sta_dir, cdir)
        if not xml:
            print(f"  {cname} ({cshort}): NO XML — skipping", file=sys.stderr)
            continue
        print(f"  {cname} ({cshort}): parsing...", file=sys.stderr)
        paths = parse_corner(xml, par_name)
        active_corners.append((cname, cshort, cdir))

        for p in paths:
            pk = p["port_key"]
            if pk not in ports:
                ports[pk] = {"sp_bpin": p["sp_bpin"], "ep_bpin": p["ep_bpin"], "paths": {}}
            port = ports[pk]

            pthk = p["path_key"]
            if pthk not in port["paths"]:
                port["paths"][pthk] = {
                    "sp_ff": p["sp_ff"], "ep_ff": p["ep_ff"],
                    "sp_clk": p["sp_clk"], "ep_clk": p["ep_clk"],
                    "slacks": {},
                }
            pth = port["paths"][pthk]
            if cshort not in pth["slacks"] or p["slack"] < pth["slacks"][cshort]:
                pth["slacks"][cshort] = p["slack"]

        print(f"  {cname}: {len(paths)} paths", file=sys.stderr)

    if not active_corners:
        print("ERROR: No hold corners found with data!", file=sys.stderr)
        sys.exit(1)

    # Sort ports by worst slack
    sorted_ports = sorted(ports.items(), key=lambda x: port_worst(x[1]))
    col_w = 7

    # Write report
    with open(outfile, "w") as out:
        W = out.write

        tag = re.search(r'(FCT\w+)', os.path.basename(daily))
        tag_str = tag.group(1) if tag else "?"
        clk = re.search(r'(CLK\d+)', os.path.basename(daily))
        clk_str = clk.group(1) if clk else "?"

        W("=" * 180 + "\n")
        W(f"  {par_name.upper()} HOLD -- Per-Port Detail (Start FF / End FF) -- All Hold Corners\n")
        W(f"  Daily: {tag_str} / {clk_str}\n")
        W(f"  Partition: {par_name}\n")
        W(f"  WA: {daily}\n")
        W(f"  Total ports: {len(sorted_ports)}  |  Total unique paths: {sum(len(p['paths']) for p in ports.values())}\n")
        W("=" * 180 + "\n\n")

        # Corner legend
        W("  CORNER LEGEND:\n")
        W(f"    {'Short':<8s}  {'Full Name':<25s}  {'Directory'}\n")
        W(f"    {'-----':<8s}  {'-'*25}  {'-'*60}\n")
        for cname, cshort, cdir in active_corners:
            W(f"    {cshort:<8s}  {cname:<25s}  {cdir}\n")
        W("\n")

        # Corner summary
        W("  CORNER SUMMARY:\n")
        W(f"    {'Short':<8s}  {'Full Name':<25s}  {'Ports':>6s}  {'Paths':>8s}  {'Worst WNS':>10s}\n")
        W(f"    {'-----':<8s}  {'-'*25}  {'------':>6s}  {'--------':>8s}  {'----------':>10s}\n")
        for cname, cshort, cdir in active_corners:
            n_ports = 0
            n_paths = 0
            worst = 0
            for pk, pdata in ports.items():
                port_has = False
                for pth in pdata["paths"].values():
                    if cshort in pth["slacks"]:
                        n_paths += 1
                        port_has = True
                        if pth["slacks"][cshort] < worst:
                            worst = pth["slacks"][cshort]
                if port_has:
                    n_ports += 1
            W(f"    {cshort:<8s}  {cname:<25s}  {n_ports:>6d}  {n_paths:>8d}  {worst:>10d}\n")
        W("\n")

        # Per-port detail
        slack_hdr = "".join(f"{c[1]:>{col_w}s}" for c in active_corners)

        for port_key, pdata in sorted_ports:
            sp_bpin = pdata["sp_bpin"]
            ep_bpin = pdata["ep_bpin"]

            if ep_bpin.startswith(f"{par_name}/"):
                dirn = "IN"
                other = sp_bpin.split("/")[0]
            elif sp_bpin.startswith(f"{par_name}/"):
                dirn = "OUT"
                other = ep_bpin.split("/")[0]
            else:
                dirn = "?"
                other = "?"

            port_worst_val = port_worst(pdata)
            n_paths = len(pdata["paths"])
            port_name = sp_bpin.split("/", 1)[1] if "/" in sp_bpin else sp_bpin

            W(f"  PORT: {sp_bpin}  -->  {ep_bpin}  [{dirn} from {other}]  WNS={port_worst_val}  Paths={n_paths}\n")
            W(f"    {'Clk(s>e)':<25s}  {'Port':<45s}  {slack_hdr}  Start FF (clk pin)  -->  End FF (data pin)\n")
            sep_line = "  ".join(["------"] * len(active_corners))
            W(f"    {'-'*25}  {'-'*45}  {sep_line}  {'-'*100}\n")

            sorted_paths = sorted(pdata["paths"].items(),
                                  key=lambda x: min(x[1]["slacks"].values()))

            seen = set()
            for pthk, pth in sorted_paths:
                if pthk in seen:
                    continue
                seen.add(pthk)

                vals = []
                for _, cshort, _ in active_corners:
                    if cshort in pth["slacks"]:
                        v = pth["slacks"][cshort]
                        vals.append(f"{v:>{col_w}d}")
                    else:
                        vals.append(f"{'':>{col_w}s}")
                slack_str = "".join(vals)

                clk_str = f"{pth['sp_clk']}>{pth['ep_clk']}"
                W(f"    {clk_str:<25s}  {port_name:<45s}  {slack_str}  {pth['sp_ff']}  -->  {pth['ep_ff']}\n")
            W("\n")

    print(f"\nSaved: {outfile} ({len(sorted_ports)} ports, {sum(len(p['paths']) for p in ports.values())} unique paths)", file=sys.stderr)


if __name__ == "__main__":
    main()

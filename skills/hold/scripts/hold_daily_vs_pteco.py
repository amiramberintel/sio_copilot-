#!/usr/bin/env python3
"""
hold_daily_vs_pteco.py — Daily Hold vs PTECO Post-ECO Comparison

Compares daily hold timing with PTECO post-ECO results to identify:
  - REMAINING: paths still failing after PTECO
  - FIXED: paths no longer in PTECO nworst (likely fixed)
  - NEW_FROM_ECO: new violations introduced by ECO

Usage:
  python3 hold_daily_vs_pteco.py --wa <DAILY_WA> --par <PAR> --pteco <PTECO_ROOT> --outdir <DIR>

Examples:
  python3 hold_daily_vs_pteco.py \
    --wa /nfs/site/disks/idc_gfc_fct_bu_daily/work_area/GFC_CLIENT_..._CLK050.bu_postcts \
    --par par_meu \
    --pteco /nfs/site/disks/ayarokh_wa/pteco/runs/GFC/core_client_260322_ww12 \
    --outdir /nfs/site/disks/sunger_wa/fc_data/my_learns/ww14_3

Output:
  <outdir>/<par_name>_hold_daily_vs_pteco.txt

Data sources:
  Daily:  <WA>/runs/core_client/n2p_htall_conf4/sta_pt/<corner>/reports/*_timing_summary.xml.filtered
  PTECO:  <PTECO>/runs/core_client/n2p_htall_conf4/pt_eco/reports/*_timing_summary.nworst.xml
"""

import xml.etree.ElementTree as ET
import argparse
import re
import os
import sys
from collections import defaultdict

# === CONFIGURATION ===
DEFAULT_WA = "/nfs/site/disks/idc_gfc_fct_bu_daily/work_area/GFC_CLIENT_26ww12b_ww13_1_initial_with_TIP-FCT26WW14B_dcm_daily-CLK050.bu_postcts"
DEFAULT_PTECO = "/nfs/site/disks/ayarokh_wa/pteco/runs/GFC/core_client_260322_ww12"

# All possible hold corners: (short_name, daily_dir, pteco_xml_pattern)
# PTECO nworst XML naming: core_client.<corner>_timing_summary.nworst.xml
ALL_HOLD_CORNERS = [
    # (short, full_name, daily_dir, pteco_pattern)
    ("mn_lo",  "func.min_low",       "func.min_low.T_85.typical",                     "func.min_low.T_85.typical"),
    ("mn_nm",  "func.min_nom",       "func.min_nom.T_85.typical",                     "func.min_nom.T_85.typical"),
    ("mn_hi",  "func.min_high",      "func.min_high.T_85.typical",                    "func.min_high.T_85.typical"),
    ("mn_tb",  "func.min_turbo",     "func.min_turbo.T_85.typical",                   "func.min_turbo.T_85.typical"),
    ("fr_slw", "fr.min_slow",        "fresh.min_slow.S_125.cworst_CCworst",           "fresh.min_slow.S_125.cworst_CCworst"),
    ("fr_scd", "fr.min_slow_cold",   "fresh.min_slow_cold.S_M40.cworst_CCworst",      "fresh.min_slow_cold.S_M40.cworst_CCworst"),
    ("fr_fst", "fr.min_fast",        "fresh.min_fast.F_125.rcworst_CCworst",           "fresh.min_fast.F_125.rcworst_CCworst"),
    ("fr_fcd", "fr.min_fast_cold",   "fresh.min_fast_cold.F_M40.rcworst_CCworst",     "fresh.min_fast_cold.F_M40.rcworst_CCworst"),
    ("fr_lhh", "fr.min_lo_hi_hi",    "fresh.min_lo_hi_hi.T_85.typical",               "fresh.min_hi_lo_hi.T_85.typical"),
    ("fr_hlh", "fr.min_hi_lo_hi",    "fresh.min_hi_lo_hi.T_85.typical",               "fresh.min_hi_lo_hi.T_85.typical"),
    ("fr_hhl", "fr.min_hi_hi_lo",    "fresh.min_hi_hi_lo.T_85.typical",               "fresh.min_hi_hi_lo.T_85.typical"),
    ("fr_hvq", "fr.min_hvqk",        "fresh.min_hvqk.F_125.rcworst_CCworst",          "fresh.min_hvqk.F_125.rcworst_CCworst"),
]


def clean(s):
    """Strip icore0/icore1 prefix."""
    return re.sub(r'^icore[01]/', '', s)


def clean_bp(s):
    """Strip {}, icore prefix from boundary pin."""
    return re.sub(r'^[{\s]*(?:icore[01]/)?', '', s).rstrip('} ')


def find_daily_xml(sta_dir, corner_dir):
    """Find timing_summary.xml.filtered in daily STA corner."""
    rpt_dir = os.path.join(sta_dir, corner_dir, "reports")
    if not os.path.isdir(rpt_dir):
        return None
    for f in os.listdir(rpt_dir):
        if f.endswith("_timing_summary.xml.filtered") and "only_dfx" not in f:
            return os.path.join(rpt_dir, f)
    return None


def find_pteco_xml(pteco_rpt_dir, corner_pattern):
    """Find nworst XML in PTECO reports dir matching a corner."""
    target = f"core_client.{corner_pattern}_timing_summary.nworst.xml"
    path = os.path.join(pteco_rpt_dir, target)
    return path if os.path.exists(path) else None


def parse_xml(xml_path, par_name, has_bpins=True):
    """Parse external paths for partition. Return dict of path_key -> info."""
    paths = {}
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
        sp_clean = clean(sp)
        ep_clean = clean(ep)
        sp_ff = "/".join(sp_clean.split("/")[1:])
        ep_ff = "/".join(ep_clean.split("/")[1:])
        path_key = f"{sp_ff}||{ep_ff}"

        # Extract port from boundary pins if available
        port = ""
        if has_bpins:
            bpins_raw = elem.get("boundary_pins", "")
            bp_parts = bpins_raw.split()
            sp_par = sp_clean.split("/")[0]
            for bp in bp_parts:
                bpc = clean_bp(bp)
                if bpc.startswith(sp_par + "/"):
                    port = bpc.split("/", 1)[1] if "/" in bpc else bpc
                    break
            if not port and bp_parts:
                bpc = clean_bp(bp_parts[0])
                port = bpc.split("/", 1)[1] if "/" in bpc else bpc

        sp_clk = elem.get("startpoint_clock", "")
        ep_clk = elem.get("endpoint_clock", "")

        if path_key not in paths or slack < paths[path_key]["slack"]:
            paths[path_key] = {
                "slack": slack, "sp_ff": sp_ff, "ep_ff": ep_ff,
                "sp_clk": sp_clk, "ep_clk": ep_clk, "port": port,
                "sp_par": sp_clean.split("/")[0], "ep_par": ep_clean.split("/")[0],
            }
        elem.clear()
    return paths


def main():
    parser = argparse.ArgumentParser(description="Daily hold vs PTECO post-ECO comparison")
    parser.add_argument("--wa", default=DEFAULT_WA, help="Daily work area path")
    parser.add_argument("--par", required=True, help="Partition name (e.g. par_meu)")
    parser.add_argument("--pteco", default=DEFAULT_PTECO, help="PTECO run root (contains runs/core_client/...)")
    parser.add_argument("--outdir", required=True, help="Output directory")
    args = parser.parse_args()

    par_name = args.par
    daily_wa = args.wa
    pteco_root = args.pteco
    outdir = args.outdir

    sta_dir = os.path.join(daily_wa, "runs/core_client/n2p_htall_conf4/sta_pt")
    pteco_rpt_dir = os.path.join(pteco_root, "runs/core_client/n2p_htall_conf4/pt_eco/reports")

    if not os.path.isdir(sta_dir):
        print(f"ERROR: Daily STA dir not found: {sta_dir}", file=sys.stderr)
        sys.exit(1)
    if not os.path.isdir(pteco_rpt_dir):
        print(f"ERROR: PTECO reports dir not found: {pteco_rpt_dir}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(outdir, exist_ok=True)
    outfile = os.path.join(outdir, f"{par_name}_hold_daily_vs_pteco.txt")

    # Auto-discover which hold corners have data in both daily and PTECO
    print(f"Comparing hold: daily vs PTECO for {par_name}...", file=sys.stderr)
    print(f"  Daily WA: {daily_wa}", file=sys.stderr)
    print(f"  PTECO:    {pteco_root}", file=sys.stderr)

    daily_all = {}
    pteco_all = {}
    active_corners = []

    for cshort, _full_name, daily_dir, pteco_pattern in ALL_HOLD_CORNERS:
        daily_xml = find_daily_xml(sta_dir, daily_dir)
        pteco_xml = find_pteco_xml(pteco_rpt_dir, pteco_pattern)

        if not daily_xml:
            continue
        if not pteco_xml:
            continue

        # Avoid duplicate corners (fr_lhh and fr_hlh may share same PTECO XML)
        if cshort in [c for c in active_corners]:
            continue

        active_corners.append(cshort)

        print(f"  {cshort} daily: parsing...", file=sys.stderr)
        d_paths = parse_xml(daily_xml, par_name, has_bpins=True)
        print(f"  {cshort} daily: {len(d_paths)} unique paths", file=sys.stderr)

        print(f"  {cshort} pteco: parsing...", file=sys.stderr)
        p_paths = parse_xml(pteco_xml, par_name, has_bpins=False)
        print(f"  {cshort} pteco: {len(p_paths)} unique paths", file=sys.stderr)

        for pk, pd in d_paths.items():
            if pk not in daily_all:
                daily_all[pk] = {"meta": pd, "corners": {}}
            daily_all[pk]["corners"][cshort] = pd["slack"]

        for pk, pd in p_paths.items():
            if pk not in pteco_all:
                pteco_all[pk] = {"meta": pd, "corners": {}}
            pteco_all[pk]["corners"][cshort] = pd["slack"]

    if not active_corners:
        print("ERROR: No matching hold corners found in both daily and PTECO!", file=sys.stderr)
        sys.exit(1)

    # Build comparison
    rows = []
    for pk, dd in daily_all.items():
        meta = dd["meta"]
        daily_worst = min(dd["corners"].values())

        pteco_slacks = {}
        if pk in pteco_all:
            pteco_slacks = pteco_all[pk]["corners"]

        pteco_worst = min(pteco_slacks.values()) if pteco_slacks else None

        if pteco_worst is None:
            status = "FIXED"
        elif pteco_worst >= 0:
            status = "FIXED"
        else:
            status = "REMAINING"

        if meta["ep_par"] == par_name:
            dirn = "IN"
            other = meta["sp_par"]
        elif meta["sp_par"] == par_name:
            dirn = "OUT"
            other = meta["ep_par"]
        else:
            dirn = "?"
            other = "?"

        rows.append({
            "pk": pk, "status": status, "dirn": dirn, "other": other,
            "port": meta["port"], "sp_clk": meta["sp_clk"], "ep_clk": meta["ep_clk"],
            "sp_ff": meta["sp_ff"], "ep_ff": meta["ep_ff"],
            "daily_corners": dd["corners"],
            "pteco_corners": pteco_slacks,
            "daily_worst": daily_worst,
            "pteco_worst": pteco_worst,
        })

    # PTECO-only paths (new violations from ECO)
    for pk, pd in pteco_all.items():
        if pk in daily_all:
            continue
        meta = pd["meta"]
        pteco_worst = min(pd["corners"].values())
        if pteco_worst >= 0:
            continue
        if meta["ep_par"] == par_name:
            dirn = "IN"
            other = meta["sp_par"]
        elif meta["sp_par"] == par_name:
            dirn = "OUT"
            other = meta["ep_par"]
        else:
            dirn = "?"
            other = "?"
        rows.append({
            "pk": pk, "status": "NEW_FROM_ECO", "dirn": dirn, "other": other,
            "port": "", "sp_clk": meta["sp_clk"], "ep_clk": meta["ep_clk"],
            "sp_ff": meta["sp_ff"], "ep_ff": meta["ep_ff"],
            "daily_corners": {},
            "pteco_corners": pd["corners"],
            "daily_worst": None,
            "pteco_worst": pteco_worst,
        })

    # Sort: REMAINING first (by pteco_worst), then NEW_FROM_ECO, then FIXED
    status_order = {"REMAINING": 0, "NEW_FROM_ECO": 1, "FIXED": 2}
    rows.sort(key=lambda r: (status_order.get(r["status"], 9),
                              r["pteco_worst"] if r["pteco_worst"] is not None else 0))

    remaining = [r for r in rows if r["status"] == "REMAINING"]
    fixed = [r for r in rows if r["status"] == "FIXED"]
    new_eco = [r for r in rows if r["status"] == "NEW_FROM_ECO"]

    col_w = 7

    # Write report
    with open(outfile, "w") as out:
        W = out.write

        tag_d = re.search(r'(FCT\w+)', os.path.basename(daily_wa))
        tag_d = tag_d.group(1) if tag_d else "?"
        pteco_name = os.path.basename(pteco_root)

        W("=" * 180 + "\n")
        W(f"  {par_name.upper()} HOLD -- Daily vs PTECO Comparison\n")
        W(f"  Daily: {tag_d}  |  PTECO: {pteco_name}\n")
        W(f"  Partition: {par_name}\n")
        W(f"  Daily WA: {daily_wa}\n")
        W(f"  PTECO:    {pteco_root}\n")
        W(f"  Corners compared: {', '.join(active_corners)}\n")
        W("=" * 180 + "\n\n")

        # Corner legend
        corner_lookup = {c[0]: c for c in ALL_HOLD_CORNERS}
        W("  CORNER LEGEND:\n")
        W(f"    {'Short':<8s}  {'Full Name':<25s}  {'Directory':<60s}\n")
        W(f"    {'-----':<8s}  {'-------------------------':<25s}  {'-'*60}\n")
        for cs in active_corners:
            rec = corner_lookup[cs]
            W(f"    {cs:<8s}  {rec[1]:<25s}  {rec[2]}\n")
        W("\n")

        # Status legend
        W("  STATUS LEGEND:\n")
        W("    REMAINING  : path exists in PTECO post-ECO nworst with negative slack.\n")
        W("                 PTECO applied a fix but could not fully close the violation.\n")
        W("                 D_ columns = daily slack (no ECO), P_ columns = PTECO post-ECO slack.\n")
        W("    FIXED      : path NOT in PTECO post-ECO nworst (or slack >= 0).\n")
        W("                 PTECO successfully closed the hold violation.\n")
        W("    NEW_FROM_ECO: path in PTECO nworst but NOT in daily. Usually a model vintage\n")
        W("                 mismatch (different RTL/netlist between daily and PTECO base).\n")
        W("\n")

        W("  SUMMARY:\n")
        W(f"    Total daily failing paths (unique FF pairs): {len(daily_all)}\n")
        W(f"    REMAINING after PTECO:  {len(remaining):>6d}  (PTECO applied fix but residual slack < 0)\n")
        W(f"    FIXED by PTECO:         {len(fixed):>6d}  (PTECO closed the violation, slack >= 0)\n")
        W(f"    NEW from ECO:           {len(new_eco):>6d}  (in PTECO nworst but not in daily -- model mismatch)\n")
        W("\n")

        # Per-corner summary
        W("  PER-CORNER SUMMARY:\n")
        W(f"    {'Corner':<8s}  {'Daily Fails':>12s}  {'PTECO Fails':>12s}  {'Fixed':>8s}  {'Remaining':>10s}  {'New':>6s}\n")
        W(f"    {'------':<8s}  {'----------':>12s}  {'-----------':>12s}  {'-----':>8s}  {'---------':>10s}  {'---':>6s}\n")
        for cs in active_corners:
            d_fail = sum(1 for r in rows if cs in r["daily_corners"] and r["daily_corners"][cs] < 0)
            p_fail = sum(1 for r in rows if cs in r["pteco_corners"] and r["pteco_corners"][cs] < 0)
            c_fixed = sum(1 for r in rows if r["status"] == "FIXED" and cs in r["daily_corners"] and r["daily_corners"][cs] < 0)
            c_remain = sum(1 for r in rows if r["status"] == "REMAINING" and cs in r["pteco_corners"] and r["pteco_corners"][cs] < 0)
            c_new = sum(1 for r in rows if r["status"] == "NEW_FROM_ECO" and cs in r["pteco_corners"] and r["pteco_corners"][cs] < 0)
            W(f"    {cs:<8s}  {d_fail:>12d}  {p_fail:>12d}  {c_fixed:>8d}  {c_remain:>10d}  {c_new:>6d}\n")
        W("\n")

        # Column headers for tables
        d_hdr = "".join(f"{'D_'+c:>{col_w}s}" for c in active_corners)
        p_hdr = "".join(f"{'P_'+c:>{col_w}s}" for c in active_corners)

        # REMAINING section
        W(f"  === REMAINING AFTER PTECO ({len(remaining)} paths) ===\n")
        W(f"    {'Status':<12s}  {'Clk(s>e)':<25s}  {'Port':<45s}  {d_hdr}  {p_hdr}  Start FF  -->  End FF\n")
        sep = "  ".join(["------"] * len(active_corners))
        W(f"    {'-'*12}  {'-'*25}  {'-'*45}  {sep}  {sep}  {'-'*80}\n")

        for r in remaining:
            clk = f"{r['sp_clk']}>{r['ep_clk']}"[:24]
            port = r["port"][:44] if r["port"] else ""
            d_vals = []
            for c in active_corners:
                if c in r["daily_corners"]:
                    d_vals.append(f"{r['daily_corners'][c]:>{col_w}d}")
                else:
                    d_vals.append(f"{'':>{col_w}s}")
            p_vals = []
            for c in active_corners:
                if c in r["pteco_corners"]:
                    p_vals.append(f"{r['pteco_corners'][c]:>{col_w}d}")
                else:
                    p_vals.append(f"{'':>{col_w}s}")
            W(f"    {'REMAINING':<12s}  {clk:<25s}  {port:<45s}  {''.join(d_vals)}  {''.join(p_vals)}  {r['sp_ff']}  -->  {r['ep_ff']}\n")
        W("\n")

        # NEW FROM ECO section
        if new_eco:
            W(f"  === VIOLATIONS IN PTECO BUT NOT IN DAILY ({len(new_eco)} paths) ===\n")
            W(f"    {'Status':<12s}  {'Clk(s>e)':<25s}  {p_hdr}  Start FF  -->  End FF\n")
            W(f"    {'-'*12}  {'-'*25}  {sep}  {'-'*80}\n")
            for r in new_eco:
                clk = f"{r['sp_clk']}>{r['ep_clk']}"[:24]
                p_vals = []
                for c in active_corners:
                    if c in r["pteco_corners"]:
                        p_vals.append(f"{r['pteco_corners'][c]:>{col_w}d}")
                    else:
                        p_vals.append(f"{'':>{col_w}s}")
                W(f"    {'NEW_ECO':<12s}  {clk:<25s}  {''.join(p_vals)}  {r['sp_ff']}  -->  {r['ep_ff']}\n")
            W("\n")

        # FIXED summary (grouped by port)
        W(f"  === FIXED BY PTECO ({len(fixed)} paths) ===\n")
        fixed_by_port = defaultdict(int)
        for r in fixed:
            p = r["port"] if r["port"] else "unknown"
            fixed_by_port[p] += 1
        fixed_sorted = sorted(fixed_by_port.items(), key=lambda x: -x[1])
        W(f"    {'Port':<60s}  {'Paths Fixed':>12s}\n")
        W(f"    {'-'*60}  {'-'*12}\n")
        for port, cnt in fixed_sorted[:50]:
            W(f"    {port:<60s}  {cnt:>12d}\n")
        if len(fixed_sorted) > 50:
            W(f"    ... and {len(fixed_sorted)-50} more port groups\n")
        W("\n")

    print(f"\nSaved: {outfile}", file=sys.stderr)
    print(f"  REMAINING: {len(remaining)}, FIXED: {len(fixed)}, NEW: {len(new_eco)}", file=sys.stderr)


if __name__ == "__main__":
    main()

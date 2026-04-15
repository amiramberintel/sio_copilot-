#!/usr/bin/env python3
"""
check_daily_vs_po.py — Compare daily build partition versions vs PO (manifest LATEST)

Usage:
    python3 check_daily_vs_po.py                          # auto-detect latest daily
    python3 check_daily_vs_po.py --daily <daily_wa_path>  # specify daily WA
    python3 check_daily_vs_po.py --color                  # colorized output (default)
    python3 check_daily_vs_po.py --no-color               # plain text
    python3 check_daily_vs_po.py --output <file>          # write to file

Compares:
  - Arc version (VER_NNN) in daily symlinks vs manifest LATEST
  - PO owner, date, workspace path
  - Shows MATCH / DAILY BEHIND / DAILY AHEAD status
"""

import os, sys, re, gzip, glob, argparse
from datetime import datetime

# ─── Config ───
ARC_BASE = "/nfs/site/disks/gfc_n2_client_arc_proj_archive/arc"
DAILY_BASE = "/nfs/site/disks/idc_gfc_fct_bu_daily/work_area"
PARTITIONS = [
    "par_meu", "par_ooo_int", "par_ooo_vec", "par_exe", "par_fe",
    "par_pmh", "par_mlc", "par_fmav0", "par_fmav1", "par_msid", "par_pm"
]

# ─── ANSI Colors ───
class C:
    R   = "\033[31m"
    G   = "\033[32m"
    M   = "\033[35m"
    CY  = "\033[36m"
    W   = "\033[1;37m"
    DIM = "\033[2m"
    RST = "\033[0m"
    BG_G = "\033[42;1;37m"
    BG_R = "\033[41;1;37m"
    BG_M = "\033[45;1;37m"
    BG_C = "\033[46;1;37m"

class NC:
    R = G = M = CY = W = DIM = RST = ""
    BG_G = BG_R = BG_M = BG_C = ""

def find_latest_daily():
    """Find the most recent daily build directory."""
    dailies = sorted(glob.glob(f"{DAILY_BASE}/GFC_CLIENT_*"))
    return dailies[-1] if dailies else None

def parse_manifest(par):
    """Parse manifest for a partition, return dict of fields."""
    manifest = f"{ARC_BASE}/{par}/sta_primetime/GFCN2CLIENTA0LATEST/{par}.sta_primetime.manifest.gz"
    if not os.path.exists(manifest):
        return None
    info = {}
    with gzip.open(manifest, 'rt') as f:
        for line in f:
            line = line.strip()
            for field in ['Version', 'User Name', 'Current Date', 'Configs', 'From dir', 'Work Area']:
                if line.startswith(f"{field}:"):
                    val = re.sub(r'^[^:]+:\s*\.+\s*', '', line).strip()
                    info[field] = val
    return info

def get_daily_version(daily_wa, par):
    """Extract arc version from daily symlink targets."""
    sta_dir = f"{daily_wa}/runs/{par}/n2p_htall_conf4/release/latest/sta_primetime"
    if not os.path.isdir(sta_dir):
        return None, None
    
    # Find any symlink and extract version from target path
    for f in os.listdir(sta_dir):
        fp = os.path.join(sta_dir, f)
        if os.path.islink(fp):
            target = os.readlink(fp)
            # Extract VER_NNN from path like .../GFCN2CLIENTA0_SC8_VER_053/...
            m = re.search(r'(GFCN2CLIENTA0_SC8_VER_(\d+))', target)
            if m:
                return m.group(1), int(m.group(2))
    
    # Not a symlink — check if files exist (copied, not linked)
    files = os.listdir(sta_dir)
    if files:
        return "COPIED (ver unknown)", -1
    return None, None

def extract_ver_num(ver_str):
    """Extract numeric version from string like GFCN2CLIENTA0_SC8_VER_053."""
    m = re.search(r'VER_(\d+)', ver_str or "")
    return int(m.group(1)) if m else -1

def get_daily_tag(daily_wa):
    """Extract the daily tag (e.g., WW13B) from path."""
    m = re.search(r'FCT26(\w+)_', os.path.basename(daily_wa))
    return m.group(1) if m else "unknown"

def get_daily_clk(daily_wa):
    """Extract CLK version from path."""
    m = re.search(r'CLK(\d+)', os.path.basename(daily_wa))
    return f"CLK{m.group(1)}" if m else "unknown"

def get_daily_date(daily_wa):
    """Get daily build date from directory modification time."""
    try:
        mtime = os.path.getmtime(daily_wa)
        return datetime.fromtimestamp(mtime).strftime("%b %d %H:%M")
    except:
        return "unknown"

def main():
    parser = argparse.ArgumentParser(description="Compare daily build vs PO manifest versions")
    parser.add_argument('--daily', help='Path to daily WA (auto-detect if not specified)')
    parser.add_argument('--no-color', action='store_true', help='Plain text output')
    parser.add_argument('--color', action='store_true', default=True, help='Colorized output (default)')
    parser.add_argument('--output', '-o', help='Write output to file')
    args = parser.parse_args()
    
    c = NC() if args.no_color else C()
    
    # Find daily
    daily_wa = args.daily or find_latest_daily()
    if not daily_wa or not os.path.isdir(daily_wa):
        print(f"ERROR: Cannot find daily WA: {daily_wa}")
        sys.exit(1)
    
    daily_tag = get_daily_tag(daily_wa)
    daily_clk = get_daily_clk(daily_wa)
    daily_date = get_daily_date(daily_wa)
    
    # Collect data
    rows = []
    for par in PARTITIONS:
        manifest = parse_manifest(par)
        daily_ver_str, daily_ver_num = get_daily_version(daily_wa, par)
        
        po_ver = manifest.get('Version', 'N/A') if manifest else 'NO MANIFEST'
        po_ver_num = extract_ver_num(po_ver)
        po_owner = manifest.get('User Name', 'N/A') if manifest else 'N/A'
        po_date = manifest.get('Current Date', 'N/A') if manifest else 'N/A'
        po_config = manifest.get('Configs', 'N/A') if manifest else 'N/A'
        po_from = manifest.get('From dir', 'N/A') if manifest else 'N/A'
        po_wa = manifest.get('Work Area', 'N/A') if manifest else 'N/A'
        
        # Short date
        po_date_short = po_date[:16] if po_date != 'N/A' else 'N/A'
        
        # Compare
        if daily_ver_num == -1 or po_ver_num == -1:
            status = "UNKNOWN"
        elif daily_ver_num == po_ver_num:
            status = "MATCH"
        elif daily_ver_num < po_ver_num:
            status = f"DAILY BEHIND (-{po_ver_num - daily_ver_num})"
        else:
            status = f"DAILY AHEAD (+{daily_ver_num - po_ver_num})"
        
        # Extract short config name
        config_short = po_config.split(',')[0][:40] if po_config != 'N/A' else 'N/A'
        
        rows.append({
            'par': par,
            'po_ver': po_ver,
            'po_ver_num': po_ver_num,
            'daily_ver': daily_ver_str or 'NOT FOUND',
            'daily_ver_num': daily_ver_num if daily_ver_num else -1,
            'status': status,
            'po_owner': po_owner,
            'po_date': po_date_short,
            'po_config': config_short,
            'po_from': po_from,
            'po_wa': po_wa
        })
    
    # Build output
    o = []
    o.append("")
    o.append(f"  {c.BG_C} DAILY vs PO (MANIFEST LATEST) — PARTITION VERSION COMPARISON {c.RST}")
    o.append("")
    o.append(f"  {c.DIM}Daily Build :{c.RST}  {os.path.basename(daily_wa)[:80]}")
    o.append(f"  {c.DIM}Daily Tag   :{c.RST}  {daily_tag} / {daily_clk}")
    o.append(f"  {c.DIM}Daily Date  :{c.RST}  {daily_date}")
    o.append(f"  {c.DIM}Arc Archive :{c.RST}  {ARC_BASE}")
    o.append(f"  {c.DIM}Manifest Tag:{c.RST}  GFCN2CLIENTA0LATEST (per partition)")
    o.append("")
    
    # Summary table
    o.append(f"  {c.W}{'Partition':<14s}  {'Daily VER':>10s}  {'PO VER':>10s}  {'Status':<22s}  {'PO Owner':<12s}  {'PO Date':<18s}{c.RST}")
    o.append(f"  {c.DIM}{'─'*14}  {'─'*10}  {'─'*10}  {'─'*22}  {'─'*12}  {'─'*18}{c.RST}")
    
    match_count = 0
    behind_count = 0
    ahead_count = 0
    
    for r in rows:
        dv = f"VER_{r['daily_ver_num']:03d}" if r['daily_ver_num'] >= 0 else r['daily_ver'][:10]
        pv = f"VER_{r['po_ver_num']:03d}" if r['po_ver_num'] >= 0 else 'N/A'
        
        if 'MATCH' in r['status']:
            sc = c.G
            match_count += 1
        elif 'BEHIND' in r['status']:
            sc = c.R
            behind_count += 1
        elif 'AHEAD' in r['status']:
            sc = c.M
            ahead_count += 1
        else:
            sc = c.DIM
        
        o.append(f"  {c.CY}{r['par']:<14s}{c.RST}  {dv:>10s}  {pv:>10s}  {sc}{r['status']:<22s}{c.RST}  {c.DIM}{r['po_owner']:<12s}  {r['po_date']:<18s}{c.RST}")
    
    o.append("")
    o.append(f"  {c.G}MATCH: {match_count}{c.RST}  │  {c.R}DAILY BEHIND: {behind_count}{c.RST}  │  {c.M}DAILY AHEAD: {ahead_count}{c.RST}")
    o.append("")
    
    # Detailed section
    o.append(f"  {c.W}DETAILED PO WORKSPACE INFO{c.RST}")
    o.append(f"  {c.DIM}{'─'*95}{c.RST}")
    
    for r in rows:
        if 'MATCH' in r['status']:
            sc = c.G
        elif 'BEHIND' in r['status']:
            sc = c.R
        else:
            sc = c.M if 'AHEAD' in r['status'] else c.DIM
        
        o.append(f"  {c.CY}{r['par']}{c.RST}  {sc}{r['status']}{c.RST}")
        o.append(f"    {c.DIM}PO Owner  :{c.RST} {r['po_owner']}")
        o.append(f"    {c.DIM}PO Version:{c.RST} {r['po_ver']}")
        o.append(f"    {c.DIM}PO Config :{c.RST} {r['po_config']}")
        o.append(f"    {c.DIM}PO Date   :{c.RST} {r['po_date']}")
        o.append(f"    {c.DIM}PO WA     :{c.RST} {r['po_wa']}")
        if r['po_from'] != 'N/A':
            o.append(f"    {c.DIM}From Dir  :{c.RST} {r['po_from']}")
        o.append("")
    
    # Legend
    o.append(f"  {c.DIM}{'═'*95}{c.RST}")
    o.append(f"  {c.DIM}Status meanings:{c.RST}")
    o.append(f"  {c.G}  MATCH        {c.RST}{c.DIM}= Daily uses same arc version as PO manifest LATEST{c.RST}")
    o.append(f"  {c.R}  DAILY BEHIND {c.RST}{c.DIM}= PO has newer version — daily needs refresh to pick it up{c.RST}")
    o.append(f"  {c.M}  DAILY AHEAD  {c.RST}{c.DIM}= Daily has newer version than manifest (rare, possible arc race){c.RST}")
    o.append(f"  {c.DIM}{'═'*95}{c.RST}")
    
    report = "\n".join(o)
    
    # Output
    if args.output:
        with open(args.output, 'w') as f:
            f.write(report + "\n")
        print(f"Report written to: {args.output}")
    
    print(report)

if __name__ == '__main__':
    main()


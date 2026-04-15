#!/usr/bin/env python3
"""
par_status.py — Partition Health Status Tool
Cross-references IFC timing data with HSD fix tracking to show
which failing interfaces are tracked, pending, fixed, or untracked.

Usage:
  python3 par_status.py --partition par_ooo_int --wa <WA_PATH>
  python3 par_status.py --partition par_ooo_int  (uses default WA)
  python3 par_status.py --partition all          (all partitions summary)

Data sources:
  1. <WA>/par_*_ifc.rpt          — interface timing families
  2. gfc.rtl4be                  — RTL4BE HSDs (fix requests)
  3. gfc.sio2po.rtl4be           — SIO2PO HSDs (pending SIO fixes)
  4. <WA>/csv/uarch_sum_hv.csv   — UARC official summary
"""

import argparse
import re
import os
import sys
import sqlite3
from collections import defaultdict

# === CONFIGURATION ===
DEFAULT_WA = "/nfs/site/disks/idc_gfc_fct_bu_daily/work_area/GFC_CLIENT_26ww12b_ww13_1_initial_with_TIP-FCT26WW14A_dcm_daily-CLK050.bu_postcts"
HSD_RTL4BE = "/nfs/site/disks/baselibr_wa/tmp/gfc.rtl4be"
HSD_SIO2PO = "/nfs/site/disks/baselibr_wa/tmp/gfc.sio2po.rtl4be"

# === COLORS ===
USE_COLOR = True  # set via --color / --no-color

def _init_colors(enabled):
    global RED, GRN, YEL, BLU, MAG, CYN, WHT, DIM, RST, BG_RED, BG_GRN, BG_MAG
    if enabled:
        RED    = '\033[1;31m'
        GRN    = '\033[1;32m'
        YEL    = '\033[1;35m'  # magenta instead of yellow per preference
        BLU    = '\033[1;34m'
        MAG    = '\033[1;35m'
        CYN    = '\033[1;36m'
        WHT    = '\033[1;37m'
        DIM    = '\033[2m'
        RST    = '\033[0m'
        BG_RED = '\033[41m'
        BG_GRN = '\033[42m'
        BG_MAG = '\033[45m'
    else:
        RED = GRN = YEL = BLU = MAG = CYN = WHT = DIM = RST = ''
        BG_RED = BG_GRN = BG_MAG = ''

# Initialize as plain text; main() will call _init_colors()
RED = GRN = YEL = BLU = MAG = CYN = WHT = DIM = RST = ''
BG_RED = BG_GRN = BG_MAG = ''

# === SIGNAL NAME EXTRACTION ===
def extract_signal_names(text):
    """Extract signal-like names from text for matching.
    Returns a list of lowercase signal base names."""
    signals = []
    # Match patterns like par_xxx/signalname or just signalname with timing suffixes
    # Signal names typically: lowercase + digits + underscores, ending in mNNNh or mnnnh
    patterns = [
        r'par_\w+/(\w+?)(?:\[|\*|_\d+_|\s|$)',  # par_xxx/signalname[
        r'par_\w+/(\w+)',                          # par_xxx/signalname
        r'\b([a-z][a-z0-9_]*m\d{3}h)\b',          # signalm803h pattern
        r'\b([a-z][a-z0-9_]*mnn+h)\b',            # signalmnnnh pattern
        r'\b([a-z][a-z0-9_]*m\d{3}l)\b',          # signalm803l pattern
        r'\b([a-z][a-z0-9_]*mnn+l)\b',            # signalmnnnl pattern
    ]
    for pat in patterns:
        for m in re.finditer(pat, text.lower()):
            sig = m.group(1)
            # Strip bus indices and wildcards
            sig = re.sub(r'\[\d*\]', '', sig)
            sig = re.sub(r'_\*$', '', sig)
            sig = re.sub(r'\*', '', sig)
            sig = sig.rstrip('_')
            if len(sig) > 4:  # skip very short matches
                signals.append(sig)
    return list(set(signals))


def normalize_signal(sig):
    """Normalize a signal name for matching — strip prefixes, indices, wildcards."""
    sig = sig.lower().strip()
    # Remove hierarchy prefix (icore0/par_xxx/ or par_xxx/)
    sig = re.sub(r'icore\d+/', '', sig)
    sig = re.sub(r'par_\w+/', '', sig)
    # Remove bus indices
    sig = re.sub(r'\[\d*:?\d*\]', '', sig)
    sig = re.sub(r'\{[^}]*\}', '', sig)
    # Remove wildcards and FEEDTHRU suffixes
    sig = re.sub(r'_*\*_*', '', sig)
    sig = re.sub(r'_*feedthru_*\d*', '', sig)
    sig = sig.rstrip('_').strip()
    return sig


# === TIP STATUS PARSER ===
def parse_tip_status(wa_path, partition):
    """Parse tip_status.rpt to find which signals have TIP cells in this build.
    Returns dict: { normalized_signal_name: [{'cell': ..., 'slack': ..., 'rc_delay': ...}, ...] }
    """
    tip_file = os.path.join(wa_path, 'partition_reports', 'func.max_high.T_85.typical',
                            partition, 'tip_status.rpt')
    tips = defaultdict(list)
    if not os.path.exists(tip_file):
        return tips

    with open(tip_file) as f:
        for line in f:
            line = line.rstrip()
            if not line or line.startswith('Writing') or line.startswith('id') or line.startswith('----'):
                continue
            parts = [p.strip() for p in line.split('|')]
            if len(parts) < 7:
                continue
            try:
                slack = float(parts[1])
                cell = parts[2]
                rc_delay = float(parts[5])
            except (ValueError, IndexError):
                continue

            # Extract signal name from cell: tip_cell_0_<signalname>
            sig = re.sub(r'^tip_cell_\d+_', '', cell)
            # Normalize: strip trailing _N_ (bit index), lowercase
            sig_base = re.sub(r'_\d+_*$', '', sig).lower()
            sig_base = re.sub(r'_*feedthru_*\d*$', '', sig_base).rstrip('_')

            tips[sig_base].append({
                'cell': cell, 'slack': slack, 'rc_delay': rc_delay,
                'signal_raw': sig
            })

    return tips


# === PARSERS ===
def parse_ifc(wa_path, partition):
    """Parse par_*_ifc.rpt file into list of dicts."""
    ifc_file = os.path.join(wa_path, f"{partition}_ifc.rpt")
    if not os.path.exists(ifc_file):
        # Try alternate naming: test_par_*_ifc.rpt
        ifc_file = os.path.join(wa_path, f"test_{partition}_ifc.rpt")
    if not os.path.exists(ifc_file):
        # Fallback: look in the script's own directory (local copy)
        script_dir = os.path.dirname(os.path.abspath(__file__))
        ifc_file = os.path.join(script_dir, f"{partition}_ifc.rpt")
    if not os.path.exists(ifc_file):
        ifc_file = os.path.join(script_dir, f"test_{partition}_ifc.rpt")
    if not os.path.exists(ifc_file):
        print(f"{RED}ERROR: {partition}_ifc.rpt not found (tried WA, test_ prefix, and local dir){RST}")
        return []
    
    entries = []
    with open(ifc_file) as f:
        for line in f:
            line = line.rstrip()
            if not line or line.startswith('#'):
                continue
            # Skip header line (starts with -WNS or ----)
            if line.startswith('-WNS') or line.startswith('----'):
                continue
            
            # Parse fixed-width fields: WNS WNS_norm TNS Paths Port1 Port2 [Port3] [Port4]
            parts = line.split()
            if len(parts) < 5:
                continue
            
            try:
                wns = float(parts[0])
                wns_norm = float(parts[1])
                tns = float(parts[2])
                paths = int(parts[3])
            except (ValueError, IndexError):
                continue
            
            # Remaining parts are port names — strip icore0/icore1 prefix for dedup
            ports = parts[4:]
            ports = [re.sub(r'\{?icore\d+/', '{', p).lstrip('{') if 'icore' in p else p for p in ports]
            port1 = ports[0] if len(ports) > 0 else ''
            port2 = ports[1] if len(ports) > 1 else ''
            port3 = ports[2] if len(ports) > 2 else ''
            port4 = ports[3] if len(ports) > 3 else ''
            
            # Extract signal key for matching
            all_ports = ' '.join(ports)
            sig_names = extract_signal_names(all_ports)
            signal_key = '|'.join(sorted(set(sig_names))) if sig_names else normalize_signal(port1)
            
            entries.append({
                'partition': partition,
                'wns': wns, 'wns_norm': wns_norm, 'tns': tns, 'paths': paths,
                'port1': port1, 'port2': port2, 'port3': port3, 'port4': port4,
                'signal_key': signal_key,
                'sig_names': sig_names
            })
    
    # Deduplicate icore0/icore1 entries — keep worst WNS per signal_key
    seen = {}
    for e in entries:
        key = e['signal_key']
        if key not in seen or e['wns'] < seen[key]['wns']:
            seen[key] = e
    
    return list(seen.values())


def parse_hsd_file(filepath):
    """Parse fixed-width HSD file into list of dicts."""
    entries = []
    if not os.path.exists(filepath):
        print(f"{RED}ERROR: {filepath} not found{RST}")
        return []
    
    with open(filepath) as f:
        lines = f.readlines()
    
    if len(lines) < 2:
        return []
    
    # Find column positions from header
    header = lines[0]
    # Fields: id, title, updated_date, owner, submitted_by, status, tag, description
    # These are fixed-width — find positions
    id_start = 0
    title_start = header.find('title')
    date_start = header.find('updated_date')
    owner_start = header.find('owner')
    sub_start = header.find('submitted_by')
    status_start = header.find('status')
    tag_start = header.find('tag')
    desc_start = header.find('description')
    
    for line in lines[2:]:  # skip header + separator
        if not line.strip():
            continue
        
        try:
            hsd_id = line[id_start:title_start].strip()
            title = line[title_start:date_start].strip() if date_start > 0 else line[title_start:].strip()
            updated = line[date_start:owner_start].strip() if owner_start > 0 else ''
            owner = line[owner_start:sub_start].strip() if sub_start > 0 else ''
            submitted = line[sub_start:status_start].strip() if status_start > 0 else ''
            
            if tag_start > 0:
                status = line[status_start:tag_start].strip()
                tag = line[tag_start:desc_start].strip() if desc_start > 0 else line[tag_start:].strip()
            else:
                status = line[status_start:].strip().split()[0] if status_start > 0 else ''
                tag = ''
            
            # Extract partition from tag or title
            par_match = re.search(r'\[(?:RTL4BE|SIO2PO)?\]?\[?(par_\w+)', title, re.I)
            if not par_match:
                par_match = re.search(r'gfca0_\w+_(par_\w+)', tag, re.I)
            if not par_match:
                par_match = re.search(r'(par_\w+)', title, re.I)
            partition_tag = par_match.group(1).lower() if par_match else ''
            
            # Extract signal names for matching
            sig_names = extract_signal_names(title)
            signal_key = '|'.join(sorted(set(sig_names))) if sig_names else ''
            
            entries.append({
                'id': hsd_id, 'title': title.strip(), 'updated_date': updated,
                'owner': owner, 'submitted_by': submitted, 'status': status,
                'partition_tag': partition_tag, 'signal_key': signal_key,
                'sig_names': sig_names
            })
        except Exception:
            continue
    
    return entries


# === MATCHING ===
def match_ifc_to_hsds(ifc_entries, rtl4be_entries, sio2po_entries, tip_data):
    """Match IFC timing entries to HSD entries and TIP cells by signal name overlap."""
    results = []
    
    for ifc in ifc_entries:
        ifc_sigs = set(ifc['sig_names'])
        matched_rtl4be = []
        matched_sio2po = []
        
        for hsd in rtl4be_entries:
            hsd_sigs = set(hsd['sig_names'])
            # Match if any signal name overlaps
            overlap = ifc_sigs & hsd_sigs
            if overlap:
                matched_rtl4be.append(hsd)
        
        for hsd in sio2po_entries:
            hsd_sigs = set(hsd['sig_names'])
            overlap = ifc_sigs & hsd_sigs
            if overlap:
                matched_sio2po.append(hsd)
        
        # Match TIP cells — check if any IFC signal has a TIP
        matched_tips = []
        for sig in ifc_sigs:
            if sig in tip_data:
                matched_tips.extend(tip_data[sig])
        
        # Determine category
        total_hsds = len(matched_rtl4be) + len(matched_sio2po)
        
        if ifc['wns'] >= 0:
            if total_hsds > 0:
                category = 'FIXED'       # ✅ was tracked and now clean
            else:
                category = 'CLEAN'       # ✅ always clean
        else:
            # Failing — check HSD status
            complete_count = sum(1 for h in matched_rtl4be if h['status'] in ('complete', 'repo_modified'))
            pending_rtl4be = sum(1 for h in matched_rtl4be if h['status'] not in ('complete', 'repo_modified', 'rejected'))
            pending_sio2po = sum(1 for h in matched_sio2po if h['status'] not in ('complete', 'closed'))
            
            if total_hsds == 0:
                category = 'UNTRACKED'   # 🔴 no HSD at all
            elif complete_count > 0 and ifc['wns'] < 0:
                category = 'FIX_LANDED_STILL_FAILING'  # 🟠
            elif pending_rtl4be > 0 or pending_sio2po > 0:
                category = 'FIX_PENDING'  # 🟡
            else:
                category = 'FIX_REJECTED_OR_UNKNOWN'  # ⚫
        
        results.append({
            'ifc': ifc,
            'rtl4be': matched_rtl4be,
            'sio2po': matched_sio2po,
            'tips': matched_tips,
            'category': category,
            'total_hsds': total_hsds
        })
    
    return results


# === REPORT GENERATION ===
def category_icon(cat):
    icons = {
        'UNTRACKED': f'{BG_RED}{WHT} 🔴 UNTRACKED {RST}',
        'FIX_PENDING': f'{YEL} 🟡 FIX PENDING {RST}',
        'FIX_LANDED_STILL_FAILING': f'{MAG} 🟠 LANDED BUT FAILING {RST}',
        'FIX_REJECTED_OR_UNKNOWN': f'{DIM} ⚫ REJECTED/UNKNOWN {RST}',
        'FIXED': f'{GRN} ✅ FIXED {RST}',
        'CLEAN': f'{GRN} ✅ CLEAN {RST}',
    }
    return icons.get(cat, cat)


def short_category(cat):
    icons = {
        'UNTRACKED': '🔴 UNTRKD',
        'FIX_PENDING': '🟡 PENDNG',
        'FIX_LANDED_STILL_FAILING': '🟠 LANDED',
        'FIX_REJECTED_OR_UNKNOWN': '⚫ REJ/UK',
        'FIXED': '✅ FIXED',
        'CLEAN': '✅ CLEAN',
    }
    return icons.get(cat, cat)


def make_sig_desc(ifc):
    """Build a readable signal description from port names."""
    p1 = ifc['port1'].split('/')[-1] if ifc['port1'] else ''
    p2 = ifc['port2'].split('/')[-1] if ifc['port2'] else ''
    # Strip leading/trailing braces and whitespace
    p1 = p1.strip('{}').strip()
    p2 = p2.strip('{}').strip()
    if p2 and p2 != p1:
        return f"{p1} → {p2}"
    return p1


def make_crossing_chain(ifc):
    """Build partition crossing chain like par_meu → par_ooo_int or par_meu → par_fe → par_ooo_int."""
    ports = [ifc.get(f'port{i}', '') for i in range(1, 5)]
    pars = []
    for p in ports:
        if not p:
            continue
        m = re.search(r'(par_\w+)', p)
        if m and (not pars or m.group(1) != pars[-1]):
            pars.append(m.group(1))
    return ' → '.join(pars) if pars else ''


def tip_indicator(r):
    """Return TIP status indicator string."""
    tips = r.get('tips', [])
    if not tips:
        return '---'
    n = len(tips)
    worst_slack = min(t['slack'] for t in tips)
    if worst_slack < 0:
        return f'TIP({n})'
    else:
        return f'TIP({n})ok'


def fmt_row(num, sig, crossing, wns, norm, tns, paths, tip):
    """Format a single data row with fixed column widths and color."""
    wns_val = float(wns)
    if wns_val <= -100:
        wc = RED
    elif wns_val <= -50:
        wc = MAG
    elif wns_val < 0:
        wc = CYN
    else:
        wc = GRN
    return f"  {DIM}{num:>4}.{RST} {sig:<75} {DIM}{crossing:<40}{RST} {wc}{wns:>7}{RST} {DIM}{norm:>6}{RST} {wc}{tns:>10}{RST} {DIM}{paths:>6}{RST}  {tip:<10}"


def section_header():
    """Return the column header line."""
    return f"  {WHT}{'#':>4}  {'Signal':<75} {'Crossing':<40} {'WNS':>7} {'Norm':>6} {'TNS':>10} {'Paths':>6}  {'TIP':<10}{RST}"


def print_report(results, partition, wa_path='', show_clean=False):
    """Print the cross-referenced status report with ANSI colors."""
    cats = defaultdict(list)
    for r in results:
        cats[r['category']].append(r)

    total = len(results)
    failing = sum(1 for r in results if r['ifc']['wns'] < 0)
    has_tip = sum(1 for r in results if r.get('tips'))

    W = 163
    print(f"\n{WHT}{'='*W}{RST}")
    print(f"  {WHT}PAR_STATUS — {partition.upper()}{RST}")
    print(f"  {CYN}Cross-referencing IFC timing x RTL4BE x SIO2PO x TIP cells{RST}")
    if wa_path:
        print(f"  {DIM}Daily WA: {wa_path}{RST}")
    print(f"{WHT}{'='*W}{RST}")

    # Legend
    print()
    print(f"  LEGEND:")
    print(f"  {'─'*72}")
    print(f"  Columns:  Signal     = interface signal family name")
    print(f"            Crossing   = partition path  (e.g. par_meu -> par_ooo_int)")
    print(f"            WNS        = worst negative slack (ps)")
    print(f"            Norm       = WNS normalized to clock period (e.g. -0.45 = 45%)")
    print(f"            TNS        = total negative slack across all paths")
    print(f"            Paths      = number of failing timing paths")
    print(f"            TIP        = TIP cell status in THIS build:")
    print(f"                         ---       = no TIP cell (fix not in build)")
    print(f"                         TIP(N)    = N TIP cells placed (fix in build, still failing)")
    print(f"                         TIP(N)ok  = N TIP cells placed, all meeting timing")
    print(f"  HSD types:")
    print(f"    RTL4BE  = RTL fix request     | complete / repo_modified = fix landed in RTL repo")
    print(f"    SIO2PO  = physical fix request | sign_off = SIO done, awaiting approval")
    print(f"                                  | not_done / open / new   = still in progress")
    print(f"  {'─'*72}")

    print(f"\n  {WHT}Total families: {total}{RST}  |  Failing: {RED}{failing}{RST}  |  Clean: {GRN}{total-failing}{RST}  |  With TIP: {CYN}{has_tip}{RST}")
    print()

    # Summary bar
    cat_colors = {
        'UNTRACKED':                 RED,
        'FIX_PENDING':               MAG,
        'FIX_LANDED_STILL_FAILING':  MAG,
        'FIX_REJECTED_OR_UNKNOWN':   DIM,
        'FIXED':                     GRN,
        'CLEAN':                     GRN,
    }

    # Summary bar
    cat_labels = {
        'UNTRACKED':                 'UNTRACKED (no HSD)',
        'FIX_PENDING':               'FIX PENDING',
        'FIX_LANDED_STILL_FAILING':  'FIX LANDED but still FAILING',
        'FIX_REJECTED_OR_UNKNOWN':   'REJECTED / UNKNOWN',
        'FIXED':                     'FIXED (was tracked, now clean)',
        'CLEAN':                     'CLEAN (always clean)',
    }
    for cat in ['UNTRACKED', 'FIX_PENDING', 'FIX_LANDED_STILL_FAILING', 'FIX_REJECTED_OR_UNKNOWN', 'FIXED', 'CLEAN']:
        count = len(cats.get(cat, []))
        if count > 0:
            cc = cat_colors.get(cat, '')
            print(f"    {cc}{cat_labels[cat]:<40} {count:>4} families{RST}")
    print()

    # Helper to print a section
    def print_section(title, cat_key, show_hsds=False):
        items = cats.get(cat_key)
        if not items:
            return
        sec_color = {'UNTRACKED': RED, 'FIX_LANDED_STILL_FAILING': MAG, 'FIX_PENDING': MAG}.get(cat_key, WHT)
        print(f"\n  {DIM}{'─'*W}{RST}")
        print(f"  {sec_color}{title} ({len(items)} families){RST}")
        print(f"  {DIM}{'─'*W}{RST}")
        print(section_header())
        print(f"  {DIM}{'-'*W}{RST}")
        for i, r in enumerate(sorted(items, key=lambda x: x['ifc']['wns'])):
            ifc = r['ifc']
            sig_desc = make_sig_desc(ifc)
            crossing = make_crossing_chain(ifc)
            tip = tip_indicator(r)
            print(fmt_row(i+1, sig_desc, crossing, f"{ifc['wns']:.0f}", f"{ifc['wns_norm']:.2f}",
                          f"{ifc['tns']:.0f}", f"{ifc['paths']}", tip))
            if show_hsds:
                for h in r['rtl4be']:
                    st_c = GRN if h['status'] in ('complete','repo_modified') else (MAG if h['status'] in ('open','new') else DIM)
                    print(f"         {CYN}RTL4BE{RST}  {h['id'][:11]}  {st_c}{h['status']:<15}{RST}  {DIM}{h['title'][:85]}{RST}")
                for h in r['sio2po']:
                    st_c = GRN if h['status'] in ('complete','closed') else (MAG if h['status'] in ('not_done','open','new') else DIM)
                    print(f"         {BLU}SIO2PO{RST}  {h['id'][:11]}  {st_c}{h['status']:<15}{RST}  {DIM}{h['title'][:85]}{RST}")
                print()

    # Sections in priority order
    print_section("UNTRACKED — NO HSD FILED", 'UNTRACKED', show_hsds=False)
    print_section("FIX LANDED BUT STILL FAILING", 'FIX_LANDED_STILL_FAILING', show_hsds=True)
    print_section("FIX PENDING", 'FIX_PENDING', show_hsds=True)

    # Quick summary
    print(f"\n  {WHT}{'='*W}{RST}")
    print(f"  {WHT}QUICK ACTION SUMMARY{RST}")
    print(f"  {WHT}{'='*W}{RST}")

    untracked = sorted(cats.get('UNTRACKED', []), key=lambda x: x['ifc']['wns'])
    landed = sorted(cats.get('FIX_LANDED_STILL_FAILING', []), key=lambda x: x['ifc']['wns'])

    if untracked:
        print(f"\n  {RED}TOP 5 UNTRACKED — NEED HSD NOW:{RST}")
        for r in untracked[:5]:
            ifc = r['ifc']
            sig = make_sig_desc(ifc)[:45]
            tip = tip_indicator(r)
            wc = RED if ifc['wns'] <= -100 else (MAG if ifc['wns'] <= -50 else CYN)
            print(f"    {sig:<45}  WNS={wc}{ifc['wns']:>7.0f}{RST}  TNS={DIM}{ifc['tns']:>10.0f}{RST}  paths={DIM}{ifc['paths']:>5}{RST}  {tip}")

    if landed:
        print(f"\n  {MAG}TOP 5 LANDED BUT STILL FAILING — NEED FOLLOW-UP:{RST}")
        for r in landed[:5]:
            ifc = r['ifc']
            sig = make_sig_desc(ifc)[:45]
            tip = tip_indicator(r)
            wc = RED if ifc['wns'] <= -100 else (MAG if ifc['wns'] <= -50 else CYN)
            print(f"    {sig:<45}  WNS={wc}{ifc['wns']:>7.0f}{RST}  TNS={DIM}{ifc['tns']:>10.0f}{RST}  HSDs={r['total_hsds']}  {tip}")

    # How to read this report — for SIOs
    print(f"\n  {'='*W}")
    print(f"  HOW TO READ THIS REPORT")
    print(f"  {'='*W}")
    print()
    print(f"  This report cross-references 4 data sources to show the health of every")
    print(f"  interface signal family in the partition:")
    print()
    print(f"    1. IFC timing report  — which signals are failing and how bad (WNS/TNS/Paths)")
    print(f"    2. RTL4BE HSDs        — RTL fix requests filed by the timing team")
    print(f"    3. SIO2PO HSDs        — physical fix requests (bound flop, push clock, etc.)")
    print(f"    4. TIP cell status    — whether the fix is physically present in THIS build")
    print()
    print(f"  CATEGORIES:")
    print(f"    UNTRACKED              = failing signal with NO HSD filed — needs attention")
    print(f"    FIX PENDING            = HSD filed but fix not yet landed (not_done / sign_off)")
    print(f"    FIX LANDED still FAILING = fix is in RTL repo but signal still fails timing")
    print(f"    CLEAN                  = signal meeting timing — no action needed")
    print()
    print(f"  TIP COLUMN — is the fix in this build?")
    print(f"    ---        = NO TIP cells found for this signal — fix is NOT in this build")
    print(f"                 (either no fix exists, or it was not picked up yet)")
    print(f"    TIP(N)     = N TIP cells found — fix IS in this build, but still failing")
    print(f"                 (the fix was not enough, or other paths still need work)")
    print(f"    TIP(N)ok   = N TIP cells found and ALL meeting timing — fix is working")
    print()
    print(f"  TIP cells are RTL changes (flop moves, buffer insertions, clock adjustments)")
    print(f"  applied on top of the frozen RTL base. The tip_status.rpt file in each partition")
    print(f"  lists every TIP cell placed in the build with its slack and RC delay info.")
    print()
    print(f"  HSD STATUS FLOW:")
    print(f"    RTL4BE:  new -> open -> repo_modified -> complete")
    print(f"    SIO2PO:  new -> open -> not_done -> sign_off -> complete")
    print(f"    repo_modified = RTL code committed, not yet validated")
    print(f"    sign_off      = SIO finished work, awaiting approval")
    print(f"    complete       = fully merged — but check TIP column to see if it's in THIS build")
    print()

    print()


# === MAIN ===
def main():
    parser = argparse.ArgumentParser(description='Partition Health Status Tool')
    parser.add_argument('--partition', '-p', required=True, help='Partition name (e.g. par_ooo_int) or "all"')
    parser.add_argument('--wa', default=DEFAULT_WA, help='Work area path')
    parser.add_argument('--show-clean', action='store_true', help='Also show clean/fixed entries')
    parser.add_argument('--top', type=int, default=0, help='Only show top N worst entries')
    parser.add_argument('--color', action='store_true', default=True, help='Bake ANSI colors into output (default)')
    parser.add_argument('--no-color', action='store_true', help='Plain text output (no colors)')
    args = parser.parse_args()
    
    _init_colors(not args.no_color)
    
    print(f"\n{DIM}Loading data...{RST}")
    
    # Parse HSD files (only once, shared across partitions)
    rtl4be_all = parse_hsd_file(HSD_RTL4BE)
    sio2po_all = parse_hsd_file(HSD_SIO2PO)
    print(f"  RTL4BE: {len(rtl4be_all)} HSDs | SIO2PO: {len(sio2po_all)} HSDs")
    
    if args.partition == 'all':
        partitions = ['par_ooo_int', 'par_meu', 'par_ooo_vec', 'par_msid', 
                       'par_fe', 'par_exe', 'par_pmh', 'par_mlc', 'par_fmav0', 'par_fmav1', 'par_pm']
    else:
        partitions = [args.partition]
    
    for partition in partitions:
        # Parse IFC for this partition
        ifc_entries = parse_ifc(args.wa, partition)
        if not ifc_entries:
            continue
        # Parse TIP status for this partition
        tip_data = parse_tip_status(args.wa, partition)
        tip_count = sum(len(v) for v in tip_data.values())
        print(f"  {partition}: {len(ifc_entries)} interface families | {len(tip_data)} TIP signal families ({tip_count} cells)")
        
        # Filter HSDs relevant to this partition
        rtl4be_part = [h for h in rtl4be_all if partition in h.get('partition_tag', '')]
        sio2po_part = [h for h in sio2po_all if partition in h.get('partition_tag', '')]
        
        # Also include HSDs that mention signals from IFC even without partition tag
        all_ifc_sigs = set()
        for e in ifc_entries:
            all_ifc_sigs.update(e['sig_names'])
        
        for h in rtl4be_all:
            if h not in rtl4be_part:
                if all_ifc_sigs & set(h['sig_names']):
                    rtl4be_part.append(h)
        
        for h in sio2po_all:
            if h not in sio2po_part:
                if all_ifc_sigs & set(h['sig_names']):
                    sio2po_part.append(h)
        
        # Match
        results = match_ifc_to_hsds(ifc_entries, rtl4be_part, sio2po_part, tip_data)
        
        # Optionally limit
        if args.top > 0:
            results = sorted(results, key=lambda x: x['ifc']['wns'])[:args.top]
        
        # Report
        print_report(results, partition, wa_path=args.wa, show_clean=args.show_clean)


if __name__ == '__main__':
    main()

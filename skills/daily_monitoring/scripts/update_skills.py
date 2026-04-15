#!/usr/bin/env python3
"""
update_skills.py — Update the SIO Copilot skills knowledge base.

Scans the work area for new/updated scripts, cookbooks, knowledge docs,
and analysis reports, then copies them to the skills directory.
Does NOT delete anything from skills — only adds or updates newer files.

Usage:
  python3 update_skills.py [--dry-run]    # preview what would change
  python3 update_skills.py                # apply updates
  python3 update_skills.py --bootstrap    # also regenerate bootstrap file

Run this whenever you learn something new or create a new script/cookbook.
"""
import argparse
import os
import shutil
import sys
from datetime import datetime

SKILLS = "/nfs/site/disks/sunger_wa/skills_for_sio_copilot"
SRC    = "/nfs/site/disks/sunger_wa/fc_data/my_learns"
SRC2   = "/nfs/site/disks/sunger_wa/daily_update"

# ---------------------------------------------------------------------------
# Mapping: (source_pattern, skills_subdir, description)
# Each entry is (src_dir, glob_or_files, dest_subdir)
# ---------------------------------------------------------------------------
COPY_RULES = [
    # --- Scripts (latest versions from most recent ww dir) ---
    {
        'name': 'Core Python scripts',
        'dest': 'scripts',
        'files': [
            (f'{SRC}/cookbooks/ifc_per_corner_report.py', 'ifc_per_corner_report.py'),
            (f'{SRC}/avi_exe/check_daily_vs_po.py',       'check_daily_vs_po.py'),
        ],
        'find_latest': [
            # Find latest par_status.py and par_status_diff.py from ww* dirs
            {'pattern': 'par_status.py',      'glob_dir': f'{SRC}/ww*/', 'dest_name': 'par_status.py'},
            {'pattern': 'par_status_diff.py', 'glob_dir': f'{SRC}/ww*/', 'dest_name': 'par_status_diff.py'},
        ],
    },
    # --- Cookbooks ---
    {
        'name': 'Cookbooks (txt + sh)',
        'dest': 'cookbooks',
        'scan_dir': f'{SRC}/cookbooks',
        'extensions': ['.txt', '.sh'],
    },
    # --- Knowledge docs (top-level .txt files) ---
    {
        'name': 'Knowledge docs',
        'dest': 'knowledge',
        'scan_dir': SRC,
        'extensions': ['.txt'],
        'max_depth': 0,  # top-level only
        'extra_dirs': [f'{SRC}/avi_exe'],  # also grab analysis .txt from here
        'extra_extensions': ['.txt'],
    },
    # --- Aliases ---
    {
        'name': 'Aliases',
        'dest': 'aliases',
        'files': [
            (f'{SRC}/my.aliases', 'my.aliases'),
        ],
        'scan_dir': f'{SRC}/aliases',
        'extensions': ['_aliases'],  # match by suffix
    },
    # --- TCL scripts ---
    {
        'name': 'TCL scripts',
        'dest': 'tcl',
        'scan_dirs': [
            (f'{SRC}/avi_exe',          ['.tcl']),
            (f'{SRC}/tp_file_to_JNC',   ['.tcl']),
        ],
    },
    # --- JNC conversion ---
    {
        'name': 'JNC conversion',
        'dest': 'jnc_conversion',
        'scan_dir': f'{SRC}/tp_file_to_JNC',
        'extensions': ['.py', '.sh', '.csh', '.txt'],
    },
    # --- Specs ---
    {
        'name': 'Specs',
        'dest': 'specs',
        'scan_dir': f'{SRC}/specs',
        'extensions': ['.csv', '.xml'],
    },
    # --- TIP files ---
    {
        'name': 'TIP files',
        'dest': 'tip',
        'scan_dir': f'{SRC}/TIP',
        'extensions': ['.tp', '.tp.bak', '.txt', '.sh'],
    },
    # --- IO constraints ---
    {
        'name': 'IO constraints',
        'dest': 'io_constraints',
        'scan_dir': f'{SRC}/ww13_4/io_constraints_fixed',
        'extensions': ['.tcl'],
    },
    # --- daily_update/par_meu — uarch knowledge ---
    {
        'name': 'Uarch knowledge (par_meu)',
        'dest': 'knowledge',
        'scan_dir': f'{SRC2}/par_meu',
        'extensions': ['.txt'],
    },
    # --- daily_update/daily_runs — daily run scripts ---
    {
        'name': 'Daily run scripts',
        'dest': 'scripts',
        'scan_dir': f'{SRC2}/daily_runs',
        'extensions': ['.py'],
    },
    # --- daily_update/timing — timing tools & docs ---
    {
        'name': 'Timing tools (scripts)',
        'dest': 'scripts',
        'scan_dir': f'{SRC2}/timing',
        'extensions': ['.py'],
    },
    {
        'name': 'Timing tools (shell)',
        'dest': 'tcl',
        'scan_dir': f'{SRC2}/timing',
        'extensions': ['.tcl', '.sh', '.csh', '.pl'],
    },
    {
        'name': 'Timing docs',
        'dest': 'knowledge',
        'scan_dir': f'{SRC2}/timing',
        'extensions': ['.md', '.txt'],
    },
    # --- DFX knowledge (from ww* dirs and dfx skill dir itself) ---
    {
        'name': 'DFX knowledge',
        'dest': 'dfx',
        'scan_dirs': [
            (f'{SRC}/ww14_2', ['.txt']),  # dfx_status summaries
        ],
        'file_filter': lambda f: 'dfx' in f.lower(),
    },
    # --- Caliber knowledge (from ww* dirs) ---
    {
        'name': 'Caliber knowledge',
        'dest': 'caliber',
        'scan_dirs': [
            (f'{SRC}/ww14_2', ['.txt']),
        ],
        'file_filter': lambda f: 'caliber' in f.lower(),
    },
    # --- FEV knowledge (from ww* dirs) ---
    {
        'name': 'FEV knowledge',
        'dest': 'fev',
        'scan_dirs': [
            (f'{SRC}/ww14_2', ['.txt']),
        ],
        'file_filter': lambda f: 'fev' in f.lower(),
    },
]

# Directories to scan for ECO fix scripts (ww* dirs + RSMOClearVM803H)
ECO_SCAN_DIRS = [
    f'{SRC}/RSMOClearVM803H',
    f'{SRC}/temp_txt_files',
]

# PT analysis directories to scan
PT_ANALYSIS_DIRS = [
    f'{SRC}/RSMOClearVM803H',
]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def is_newer(src, dst):
    """Return True if src is newer than dst, or dst doesn't exist."""
    if not os.path.exists(dst):
        return True
    return os.path.getmtime(src) > os.path.getmtime(dst)


def find_latest_in_wwdirs(pattern, glob_dir):
    """Find the newest version of a file across ww* directories."""
    import glob as g
    candidates = []
    for d in sorted(g.glob(glob_dir)):
        f = os.path.join(d, pattern)
        if os.path.exists(f):
            candidates.append((os.path.getmtime(f), f))
    if candidates:
        candidates.sort(reverse=True)
        return candidates[0][1]
    return None


def scan_dir_for_extensions(directory, extensions, max_depth=None):
    """Return list of files matching extensions in directory."""
    results = []
    if not os.path.isdir(directory):
        return results
    for entry in os.listdir(directory):
        full = os.path.join(directory, entry)
        if not os.path.isfile(full):
            continue
        for ext in extensions:
            if entry.endswith(ext):
                results.append((full, entry))
                break
    return results


def scan_ww_dirs_for_eco_scripts():
    """Find ECO fix scripts (.sh, .tcl) in ww* dirs and special dirs."""
    import glob as g
    results = []
    # ww* directories
    for d in sorted(g.glob(f'{SRC}/ww*/')):
        for entry in os.listdir(d):
            full = os.path.join(d, entry)
            if os.path.isfile(full) and (entry.endswith('.sh') or entry.endswith('.tcl')):
                # Skip par_status scripts (they go to scripts/)
                if entry.startswith('par_status'):
                    continue
                # Skip colorize helpers
                if entry == 'par_status_color.sh':
                    continue
                results.append((full, entry))
    # Special dirs
    for d in ECO_SCAN_DIRS:
        if os.path.isdir(d):
            for entry in os.listdir(d):
                full = os.path.join(d, entry)
                if os.path.isfile(full) and (entry.endswith('.sh') or entry.endswith('.tcl')):
                    results.append((full, entry))
    # ww12_2_master_test
    mt = f'{SRC}/ww12_2_master_test'
    if os.path.isdir(mt):
        for entry in os.listdir(mt):
            full = os.path.join(mt, entry)
            if os.path.isfile(full) and entry.endswith('.tcl'):
                results.append((full, entry))
    return results


def scan_pt_analysis():
    """Find PT analysis reports across ww* dirs."""
    import glob as g
    results = []
    # ww13_3 — PBA and DCU L1 analysis
    d = f'{SRC}/ww13_3'
    if os.path.isdir(d):
        for entry in os.listdir(d):
            full = os.path.join(d, entry)
            if not os.path.isfile(full):
                continue
            if entry.endswith('.rpt') or 'pteco' in entry or 'pba' in entry or 'dcu_l1' in entry:
                results.append((full, entry))
    # ww13_4 — PTECO analysis
    d = f'{SRC}/ww13_4'
    if os.path.isdir(d):
        for entry in os.listdir(d):
            full = os.path.join(d, entry)
            if not os.path.isfile(full):
                continue
            if entry.endswith('.rpt') or entry.endswith('.csv') or entry.endswith('.tsv') or 'pteco' in entry:
                results.append((full, entry))
    # ww14_1+ — PTECO reports
    for wd in sorted(g.glob(f'{SRC}/ww1[4-9]*/')):
        for entry in os.listdir(wd):
            full = os.path.join(wd, entry)
            if os.path.isfile(full) and 'pteco' in entry:
                results.append((full, entry))
    # RSMOClearVM803H
    d = f'{SRC}/RSMOClearVM803H'
    if os.path.isdir(d):
        for entry in os.listdir(d):
            full = os.path.join(d, entry)
            if os.path.isfile(full) and (entry.endswith('.txt') or entry.endswith('.sh')):
                results.append((full, entry))
    return results


# ---------------------------------------------------------------------------
# Main update logic
# ---------------------------------------------------------------------------
def run_update(dry_run=False, update_bootstrap=False):
    added = 0
    updated = 0
    skipped = 0

    def do_copy(src, dest_dir, dest_name, category):
        nonlocal added, updated, skipped
        dst = os.path.join(dest_dir, dest_name)
        if not os.path.exists(src):
            return
        if is_newer(src, dst):
            action = "NEW" if not os.path.exists(dst) else "UPD"
            if action == "NEW":
                added += 1
            else:
                updated += 1
            print(f"  [{action}] {category}/{dest_name}")
            if not dry_run:
                os.makedirs(dest_dir, exist_ok=True)
                shutil.copy2(src, dst)
        else:
            skipped += 1

    print(f"{'DRY RUN — ' if dry_run else ''}Updating skills: {SKILLS}")
    print(f"Source: {SRC}")
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print()

    # Process each rule
    for rule in COPY_RULES:
        dest_dir = os.path.join(SKILLS, rule['dest'])

        # Explicit file list
        for src, dname in rule.get('files', []):
            do_copy(src, dest_dir, dname, rule['dest'])

        # Find latest from ww* dirs
        for fl in rule.get('find_latest', []):
            latest = find_latest_in_wwdirs(fl['pattern'], fl['glob_dir'])
            if latest:
                do_copy(latest, dest_dir, fl['dest_name'], rule['dest'])

        # Scan directory
        if 'scan_dir' in rule:
            exts = rule.get('extensions', [])
            for src, fname in scan_dir_for_extensions(rule['scan_dir'], exts):
                do_copy(src, dest_dir, fname, rule['dest'])

        # Scan multiple dirs
        for sdir, exts in rule.get('scan_dirs', []):
            for src, fname in scan_dir_for_extensions(sdir, exts):
                do_copy(src, dest_dir, fname, rule['dest'])

        # Extra dirs
        for edir in rule.get('extra_dirs', []):
            eexts = rule.get('extra_extensions', rule.get('extensions', []))
            for src, fname in scan_dir_for_extensions(edir, eexts):
                do_copy(src, dest_dir, fname, rule['dest'])

    # ECO fixes
    eco_dir = os.path.join(SKILLS, 'eco_fixes')
    for src, fname in scan_ww_dirs_for_eco_scripts():
        do_copy(src, eco_dir, fname, 'eco_fixes')

    # PT analysis
    pt_dir = os.path.join(SKILLS, 'pt_analysis')
    for src, fname in scan_pt_analysis():
        do_copy(src, pt_dir, fname, 'pt_analysis')

    # PT shell command log
    ptlog = f'{SRC}/pt_shell_command.log'
    if os.path.exists(ptlog):
        do_copy(ptlog, os.path.join(SKILLS, 'knowledge'), 'pt_shell_command.log', 'knowledge')

    print()
    print(f"Summary: {added} new, {updated} updated, {skipped} unchanged")

    if update_bootstrap and not dry_run:
        print("\nUpdating bootstrap timestamp...")
        bsfile = os.path.join(SKILLS, 'copilot_bootstrap.txt')
        if os.path.exists(bsfile):
            with open(bsfile) as f:
                content = f.read()
            today = datetime.now().strftime('%Y-%m-%d')
            import re
            content = re.sub(r'Last updated: \d{4}-\d{2}-\d{2}',
                           f'Last updated: {today}', content)
            with open(bsfile, 'w') as f:
                f.write(content)
            print(f"  Bootstrap timestamp updated to {today}")

    return added + updated


if __name__ == '__main__':
    p = argparse.ArgumentParser(description="Update SIO Copilot skills knowledge base")
    p.add_argument('--dry-run', action='store_true', help="Preview changes without copying")
    p.add_argument('--bootstrap', action='store_true', help="Also update bootstrap timestamp")
    args = p.parse_args()
    run_update(dry_run=args.dry_run, update_bootstrap=args.bootstrap)

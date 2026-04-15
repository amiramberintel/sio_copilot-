#!/usr/bin/env python3
"""
run_daily_update.py — Automated Daily Update Pipeline
Orchestrates the full daily analysis flow from the daily_update_cookbook:
  1. Detect or accept a daily build WA
  2. Create output directory (ww<WW>_<day>/)
  3. Copy and patch par_status.py / par_status_diff.py
  4. Generate all 11 partition status reports
  5. Generate diff reports vs previous build
  6. Run check_daily_vs_po.py (daily vs PO version comparison)
  7. Print summary

Usage:
  python3 run_daily_update.py                             # auto-detect latest daily
  python3 run_daily_update.py --daily <WA_PATH>           # specific daily
  python3 run_daily_update.py --tag WW13B                 # find daily by tag
  python3 run_daily_update.py --prev-tag WW13A            # explicit previous tag for diff
  python3 run_daily_update.py --outdir ww13_2             # explicit output dir name
  python3 run_daily_update.py --no-color                  # plain text reports
  python3 run_daily_update.py --skip-diff                 # skip diff generation
  python3 run_daily_update.py --skip-status               # skip status generation
  python3 run_daily_update.py --skip-version-check        # skip daily vs PO check
  python3 run_daily_update.py --dry-run                   # show what would be done
"""

import os
import sys
import re
import glob
import shutil
import subprocess
import argparse
from datetime import datetime

# ─── Config ───
BASE_DIR = "/nfs/site/disks/sunger_wa/fc_data/my_learns"
DAILY_BASE = "/nfs/site/disks/idc_gfc_fct_bu_daily/work_area"
CHECK_DAILY_SCRIPT = "/nfs/site/disks/sunger_wa/sio_scripts/check_daily_vs_po.py"

PARTITIONS = [
    "par_ooo_int", "par_meu", "par_ooo_vec", "par_msid", "par_fe",
    "par_exe", "par_pmh", "par_mlc", "par_fmav0", "par_fmav1", "par_pm"
]

# ─── ANSI ───
class C:
    R   = "\033[1;31m"
    G   = "\033[1;32m"
    M   = "\033[1;35m"
    CY  = "\033[1;36m"
    W   = "\033[1;37m"
    DIM = "\033[2m"
    RST = "\033[0m"

class NC:
    R = G = M = CY = W = DIM = RST = ""

# ─── Helpers ───

def log(msg, c=None, color_obj=None):
    """Print with optional color."""
    co = color_obj or C
    prefix = f"{co.CY}>>>{co.RST} "
    if c:
        print(f"{prefix}{c}{msg}{co.RST}")
    else:
        print(f"{prefix}{msg}")

def log_ok(msg, co=None):
    co = co or C
    log(msg, co.G, co)

def log_err(msg, co=None):
    co = co or C
    log(msg, co.R, co)

def log_dim(msg, co=None):
    co = co or C
    log(msg, co.DIM, co)

def find_latest_daily():
    """Find the most recent daily build directory (skip noise_daily, clk_pd)."""
    dailies = sorted(glob.glob(f"{DAILY_BASE}/GFC_CLIENT_*"))
    # Prefer dcm_daily builds — skip noise/clk_pd variants
    for d in reversed(dailies):
        bn = os.path.basename(d)
        if 'dcm_daily' in bn:
            return d
    return dailies[-1] if dailies else None

def find_daily_by_tag(tag):
    """Find a daily WA by build tag (e.g. WW13B)."""
    matches = sorted(glob.glob(f"{DAILY_BASE}/*FCT26{tag}_*daily*CLK*.bu_postcts"))
    if matches:
        return matches[-1]
    # Broader fallback
    matches = sorted(glob.glob(f"{DAILY_BASE}/*FCT26{tag}*"))
    return matches[-1] if matches else None

def extract_tag(daily_wa):
    """Extract build tag (e.g. WW13B) from daily path."""
    m = re.search(r'FCT26(\w+?)_', os.path.basename(daily_wa))
    return m.group(1) if m else None

def extract_clk(daily_wa):
    """Extract CLK version from daily path."""
    m = re.search(r'CLK(\d+)', os.path.basename(daily_wa))
    return f"CLK{m.group(1)}" if m else "unknown"

def find_previous_tag(tag):
    """Find the previous daily tag by looking at existing ww directories and dailies."""
    # Build list of all known tags from daily dirs
    all_dailies = sorted(glob.glob(f"{DAILY_BASE}/GFC_CLIENT_*"))
    tags = []
    for d in all_dailies:
        t = extract_tag(d)
        if t:
            tags.append(t)

    if tag in tags:
        idx = tags.index(tag)
        if idx > 0:
            return tags[idx - 1]
    return None

def find_latest_output_dir():
    """Find the latest ww<N>_<D> output directory."""
    dirs = sorted(glob.glob(f"{BASE_DIR}/ww[0-9]*_[0-9]*"))
    # Filter out non-standard dirs like ww12_2_master_test
    dirs = [d for d in dirs if re.match(r'.*/ww\d+_\d+$', d)]
    return dirs[-1] if dirs else None

def compute_output_dir(tag):
    """Compute the next output directory name based on tag and existing dirs."""
    # Extract WW number from tag (e.g. WW13B -> 13)
    m = re.match(r'WW(\d+)', tag)
    if not m:
        return f"ww_unknown"
    ww_num = int(m.group(1))

    # Find existing dirs for this WW
    existing = sorted(glob.glob(f"{BASE_DIR}/ww{ww_num}_[0-9]*"))
    existing = [d for d in existing if re.match(rf'.*/ww{ww_num}_\d+$', d)]

    if existing:
        # Get the highest day number and increment
        last = os.path.basename(existing[-1])
        m2 = re.search(r'_(\d+)$', last)
        next_day = int(m2.group(1)) + 1 if m2 else 1
    else:
        next_day = 1

    return f"ww{ww_num}_{next_day}"

def find_par_status_source():
    """Find the most recent directory containing par_status.py."""
    dirs = sorted(glob.glob(f"{BASE_DIR}/ww[0-9]*_[0-9]*"))
    dirs = [d for d in dirs if re.match(r'.*/ww\d+_\d+$', d)]
    # Search backwards from newest to oldest
    for d in reversed(dirs):
        if os.path.exists(os.path.join(d, "par_status.py")):
            return d
    return None

def validate_daily(daily_wa, co):
    """Check that the daily WA has the expected IFC files."""
    ifc_files = glob.glob(f"{daily_wa}/par_*_ifc.rpt") + \
                glob.glob(f"{daily_wa}/test_par_*_ifc.rpt") + \
                glob.glob(f"{daily_wa}/test2_par_*_ifc.rpt")
    if not ifc_files:
        log(f"⚠  No IFC files found (Gil may not have generated yet)", co.M, co)
        log_dim(f"   Status reports will run without IFC cross-reference", co)
        return True  # continue anyway — IFC is optional for status
    log_dim(f"Found {len(ifc_files)} IFC files", co)
    return True

def patch_par_status(script_path, new_wa, co):
    """Patch DEFAULT_WA in par_status.py to point to the new daily."""
    with open(script_path, 'r') as f:
        content = f.read()

    new_content = re.sub(
        r'(DEFAULT_WA\s*=\s*")[^"]*(")',
        rf'\g<1>{new_wa}\2',
        content,
        count=1
    )
    if new_content == content:
        log_err("Could not patch DEFAULT_WA — pattern not found", co)
        return False

    with open(script_path, 'w') as f:
        f.write(new_content)

    log_ok(f"Patched DEFAULT_WA → ...{os.path.basename(new_wa)[:60]}", co)
    return True

def run_cmd(cmd, cwd=None, co=None):
    """Run a shell command and return (success, stdout, stderr)."""
    co = co or C
    try:
        result = subprocess.run(
            cmd, shell=True, cwd=cwd,
            capture_output=True, text=True, timeout=600
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        log_err(f"Command timed out (10min): {cmd[:60]}...", co)
        return False, "", "timeout"
    except Exception as e:
        log_err(f"Command failed: {e}", co)
        return False, "", str(e)


# ─── Main Steps ───

def step_status(outdir, daily_wa, use_color, co):
    """STEP 3: Generate all partition status reports."""
    log(f"Generating status reports for {len(PARTITIONS)} partitions...", co.W, co)

    color_flag = "--color" if use_color else "--no-color"
    success = 0
    fail = 0

    for par in PARTITIONS:
        outfile = os.path.join(outdir, f"{par}_status.txt")
        cmd = f'python3 par_status.py -p "{par}" --wa "{daily_wa}" {color_flag}'
        ok, stdout, stderr = run_cmd(cmd, cwd=outdir, co=co)
        if ok and stdout.strip():
            with open(outfile, 'w') as f:
                f.write(stdout)
            lines = len(stdout.strip().split('\n'))
            log_dim(f"  {par:<16s} → {lines:>5d} lines", co)
            success += 1
        else:
            log_err(f"  {par:<16s} FAILED: {stderr[:80]}", co)
            fail += 1

    if success == len(PARTITIONS):
        log_ok(f"All {success} status reports generated", co)
    else:
        log_err(f"{success} ok, {fail} failed", co)

    return success

def step_diff(outdir, tag, prev_tag, use_color, co):
    """STEP 5: Generate diff reports vs previous build."""
    if not prev_tag:
        log_err("No previous tag found — skipping diff generation", co)
        log_dim("  Use --prev-tag to specify manually", co)
        return False

    log(f"Generating diff reports: {prev_tag} → {tag}...", co.W, co)

    color_flag = "--color" if use_color else "--no-color"
    cmd = f'python3 par_status_diff.py --builds {prev_tag} {tag} --partition all {color_flag} --outdir .'

    ok, stdout, stderr = run_cmd(cmd, cwd=outdir, co=co)
    if ok:
        # Count generated files
        diff_files = glob.glob(f"{outdir}/par_*_diff.txt")
        summary = os.path.join(outdir, "all_par_diff_summary.txt")
        has_summary = os.path.exists(summary)
        log_ok(f"Generated {len(diff_files)} diff files" +
               (" + all_par_diff_summary.txt" if has_summary else ""), co)
        if has_summary:
            with open(summary, 'r') as f:
                log_dim("", co)
                for line in f.readlines()[:30]:
                    print(f"    {line.rstrip()}")
                print()
    else:
        log_err(f"Diff generation failed: {stderr[:120]}", co)

    return ok

def step_version_check(outdir, daily_wa, tag, use_color, co):
    """STEP 7e: Run check_daily_vs_po.py."""
    log("Running daily vs PO version comparison...", co.W, co)

    if not os.path.exists(CHECK_DAILY_SCRIPT):
        log_err(f"Script not found: {CHECK_DAILY_SCRIPT}", co)
        return False

    color_flag = "" if use_color else "--no-color"
    outfile = os.path.join(outdir, f"{tag}_daily_vs_po.txt")
    cmd = f'python3 {CHECK_DAILY_SCRIPT} --daily "{daily_wa}" {color_flag} -o "{outfile}"'

    ok, stdout, stderr = run_cmd(cmd, cwd=outdir, co=co)
    if ok:
        log_ok(f"Saved to {os.path.basename(outfile)}", co)
        # Show the summary counts from stdout
        for line in stdout.split('\n'):
            if 'MATCH' in line and 'BEHIND' in line:
                print(f"    {line.strip()}")
                break
    else:
        log_err(f"Version check failed: {stderr[:120]}", co)

    return ok


def main():
    parser = argparse.ArgumentParser(
        description="Automated Daily Update Pipeline — orchestrates the full daily analysis flow",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                          # auto-detect latest daily, run everything
  %(prog)s --tag WW13B              # find daily by tag
  %(prog)s --tag WW13B --prev-tag WW13A  # explicit previous build for diff
  %(prog)s --outdir ww13_2          # use specific output dir name
  %(prog)s --no-color               # plain text reports
  %(prog)s --skip-diff              # only status + version check
  %(prog)s --dry-run                # show what would be done
        """
    )
    parser.add_argument('--daily', help='Path to daily WA (auto-detect if not given)')
    parser.add_argument('--tag', help='Build tag to find (e.g. WW13B)')
    parser.add_argument('--prev-tag', help='Previous build tag for diff (auto-detect if not given)')
    parser.add_argument('--outdir', help='Output directory name (auto-computed if not given)')
    parser.add_argument('--no-color', action='store_true', help='Plain text output (no ANSI)')
    parser.add_argument('--skip-diff', action='store_true', help='Skip diff report generation')
    parser.add_argument('--skip-status', action='store_true', help='Skip status report generation')
    parser.add_argument('--skip-version-check', action='store_true', help='Skip daily vs PO check')
    parser.add_argument('--dry-run', action='store_true', help='Show plan without executing')
    args = parser.parse_args()

    co = NC() if args.no_color else C()
    use_color = not args.no_color

    print()
    print(f"  {co.W}{'='*70}{co.RST}")
    print(f"  {co.W}  DAILY UPDATE PIPELINE{co.RST}")
    print(f"  {co.W}  {datetime.now().strftime('%Y-%m-%d %H:%M')}{co.RST}")
    print(f"  {co.W}{'='*70}{co.RST}")
    print()

    # ─── STEP 0: Find daily WA ───
    log("STEP 0: Identifying daily build...", co.W, co)

    daily_wa = args.daily
    if not daily_wa and args.tag:
        daily_wa = find_daily_by_tag(args.tag)
        if daily_wa:
            log_ok(f"Found daily by tag {args.tag}", co)
        else:
            log_err(f"No daily found for tag {args.tag}", co)
            sys.exit(1)
    elif not daily_wa:
        daily_wa = find_latest_daily()
        if daily_wa:
            log_ok("Auto-detected latest daily", co)
        else:
            log_err("No daily builds found — use --daily or --tag", co)
            sys.exit(1)

    if not os.path.isdir(daily_wa):
        log_err(f"Daily WA not found: {daily_wa}", co)
        sys.exit(1)

    tag = args.tag or extract_tag(daily_wa)
    clk = extract_clk(daily_wa)
    log_dim(f"  WA:  {os.path.basename(daily_wa)}", co)
    log_dim(f"  Tag: {tag}  CLK: {clk}", co)

    if not validate_daily(daily_wa, co):
        sys.exit(1)

    # ─── STEP 0b: Find previous tag ───
    prev_tag = args.prev_tag or find_previous_tag(tag)
    if prev_tag:
        log_dim(f"  Previous tag: {prev_tag}", co)
    else:
        log_dim("  Previous tag: not found (diff will be skipped)", co)

    # ─── STEP 1: Create output directory ───
    print()
    log("STEP 1: Setting up output directory...", co.W, co)

    outdir_name = args.outdir or compute_output_dir(tag)
    outdir = os.path.join(BASE_DIR, outdir_name)

    if os.path.isdir(outdir):
        log_dim(f"  Directory exists: {outdir_name}/", co)
        # Check if it already has status files
        existing = glob.glob(f"{outdir}/par_*_status.txt")
        if existing:
            log(f"  Found {len(existing)} existing status files — will overwrite", co.M, co)
    else:
        if not args.dry_run:
            os.makedirs(outdir, exist_ok=True)
        log_ok(f"  Created: {outdir_name}/", co)

    # ─── STEP 2: Copy and patch tools ───
    print()
    log("STEP 2: Copying and patching tools...", co.W, co)

    source_dir = find_par_status_source()
    if not source_dir:
        log_err("Cannot find par_status.py in any previous ww directory", co)
        sys.exit(1)

    log_dim(f"  Source: {os.path.basename(source_dir)}/", co)

    for script in ["par_status.py", "par_status_diff.py"]:
        src = os.path.join(source_dir, script)
        dst = os.path.join(outdir, script)
        if os.path.exists(src):
            if not args.dry_run and os.path.realpath(src) != os.path.realpath(dst):
                shutil.copy2(src, dst)
            log_dim(f"  Copied {script}", co)
        else:
            log_err(f"  {script} not found in {os.path.basename(source_dir)}/", co)

    # Patch DEFAULT_WA
    par_status_path = os.path.join(outdir, "par_status.py")
    if os.path.exists(par_status_path) and not args.dry_run:
        patch_par_status(par_status_path, daily_wa, co)

    # ─── DRY RUN STOP ───
    if args.dry_run:
        print()
        log("DRY RUN — would execute:", co.M, co)
        if not args.skip_status:
            log_dim(f"  Generate {len(PARTITIONS)} status reports in {outdir_name}/", co)
        if not args.skip_diff and prev_tag:
            log_dim(f"  Generate diff reports: {prev_tag} → {tag}", co)
        if not args.skip_version_check:
            log_dim(f"  Run daily vs PO version check", co)
        print()
        return

    # ─── STEP 3: Generate status reports ───
    if not args.skip_status:
        print()
        step_status(outdir, daily_wa, use_color, co)

    # ─── STEP 5: Generate diff reports ───
    if not args.skip_diff:
        print()
        step_diff(outdir, tag, prev_tag, use_color, co)

    # ─── STEP 7e: Version check ───
    if not args.skip_version_check:
        print()
        step_version_check(outdir, daily_wa, tag, use_color, co)

    # ─── Summary ───
    print()
    print(f"  {co.W}{'='*70}{co.RST}")
    log("DONE — Output directory:", co.G, co)
    log_dim(f"  {outdir}", co)
    print()

    # List generated files
    all_files = sorted(os.listdir(outdir))
    status_count = len([f for f in all_files if f.endswith('_status.txt')])
    diff_count = len([f for f in all_files if f.endswith('_diff.txt')])
    other = [f for f in all_files if not f.endswith('.py') and not f.endswith('_status.txt') and not f.endswith('_diff.txt')]

    log_dim(f"  {status_count} status reports  |  {diff_count} diff reports", co)
    if other:
        log_dim(f"  Other: {', '.join(other)}", co)

    print()
    log("Quick review commands:", co.W, co)
    print(f"    cd {outdir}")
    print(f"    cat all_par_diff_summary.txt")
    print(f"    less -R par_meu_status.txt")
    if tag:
        print(f"    less -R {tag}_daily_vs_po.txt")
    print()


if __name__ == '__main__':
    main()

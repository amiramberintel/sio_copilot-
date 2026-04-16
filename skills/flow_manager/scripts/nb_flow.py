#!/usr/bin/env python3
"""
nb_flow.py — NB Job Orchestration with Dependencies
Submit multi-step NB flows where jobs depend on other jobs completing.

Usage:
  python3 nb_flow.py --flow flow_file.json [--dry-run] [--workdir /path]
  python3 nb_flow.py --status flow_file.json
  python3 nb_flow.py --example

Flow file format (JSON):
  {
    "name": "my_flow",
    "description": "PBA analysis for par_meu all corners",
    "defaults": {
      "target": "sc8_express",
      "qslot": "/c2dg/BE_BigCore/gfc/sd",
      "class": "SLES15&&500G&&16C",
      "workdir": "/nfs/site/disks/sunger_wa/meu_manual_work"
    },
    "jobs": [
      {
        "id": "pba_max_high",
        "task": "PBA max_high par_meu",
        "script": "/path/to/nb_pba_max_high.sh",
        "depends_on": []
      },
      {
        "id": "pba_max_med",
        "task": "PBA max_med par_meu",
        "script": "/path/to/nb_pba_max_med.sh",
        "depends_on": []
      },
      {
        "id": "merge_report",
        "task": "Merge PBA results",
        "script": "/path/to/merge_pba.sh",
        "depends_on": ["pba_max_high", "pba_max_med"],
        "class": "SLES15&&4C&&16G"
      }
    ]
  }

Author: sunger (with copilot) | WW16C April 2026
"""

import json
import sys
import os
import subprocess
import re
from datetime import datetime

# --- NB defaults ---
NB_DEFAULTS = {
    "target": "sc8_express",
    "qslot": "/c2dg/BE_BigCore/gfc/sd",
    "class": "SLES15&&500G&&16C",
}

def load_flow(flow_file):
    """Load flow definition from JSON file."""
    with open(flow_file) as f:
        flow = json.load(f)
    # Validate
    assert "name" in flow, "Flow must have a 'name'"
    assert "jobs" in flow, "Flow must have 'jobs' list"
    ids = set()
    for job in flow["jobs"]:
        assert "id" in job, f"Each job must have an 'id': {job}"
        assert "script" in job, f"Job '{job['id']}' must have a 'script'"
        assert job["id"] not in ids, f"Duplicate job id: {job['id']}"
        ids.add(job["id"])
    # Validate deps reference existing jobs
    for job in flow["jobs"]:
        for dep in job.get("depends_on", []):
            assert dep in ids, f"Job '{job['id']}' depends on unknown job '{dep}'"
    return flow


def topo_sort(jobs):
    """Topological sort of jobs by dependencies. Returns ordered list."""
    job_map = {j["id"]: j for j in jobs}
    visited = set()
    order = []

    def visit(jid):
        if jid in visited:
            return
        visited.add(jid)
        for dep in job_map[jid].get("depends_on", []):
            visit(dep)
        order.append(jid)

    for j in jobs:
        visit(j["id"])
    return [job_map[jid] for jid in order]


def submit_job(job, defaults, nb_job_ids, dry_run=False):
    """Submit a single NB job, with triggers if it has dependencies."""
    target = job.get("target", defaults.get("target", NB_DEFAULTS["target"]))
    qslot = job.get("qslot", defaults.get("qslot", NB_DEFAULTS["qslot"]))
    nbclass = job.get("class", defaults.get("class", NB_DEFAULTS["class"]))
    task = job.get("task", job["id"])
    script = job["script"]
    workdir = job.get("workdir", defaults.get("workdir"))
    log_dir = job.get("log_dir", defaults.get("log_dir"))

    cmd = [
        "nbjob", "run",
        "--target", target,
        "--qslot", qslot,
        "--class", nbclass,
        "--task", task,
    ]

    if workdir:
        cmd += ["--work-dir", workdir]
    if log_dir:
        cmd += ["--log-file-dir", log_dir]

    # Add dependency triggers
    deps = job.get("depends_on", [])
    if deps:
        trigger_parts = []
        for dep_id in deps:
            if dep_id not in nb_job_ids:
                print(f"  WARNING: dependency '{dep_id}' not yet submitted, skipping trigger")
                continue
            trigger_parts.append(f"{nb_job_ids[dep_id]}:done")
        if trigger_parts:
            cmd += ["--triggers", ",".join(trigger_parts)]

    cmd.append(script)

    if dry_run:
        print(f"  [DRY-RUN] {' '.join(cmd)}")
        return f"DRY-{job['id']}"

    print(f"  Submitting: {task}")
    print(f"    Script: {script}")
    if deps:
        dep_info = ", ".join(f"{d} (JobID {nb_job_ids.get(d, '?')})" for d in deps)
        print(f"    Depends on: {dep_info}")

    result = subprocess.run(cmd, capture_output=True, text=True)
    output = result.stdout.strip() + result.stderr.strip()
    print(f"    {output}")

    # Extract JobID
    match = re.search(r'JobID (\d+)', output)
    if match:
        return match.group(1)
    else:
        print(f"    ERROR: Could not extract JobID from output")
        return None


def run_flow(flow_file, dry_run=False):
    """Submit all jobs in a flow with proper dependencies."""
    flow = load_flow(flow_file)
    defaults = flow.get("defaults", {})
    jobs = topo_sort(flow["jobs"])

    print(f"{'='*70}")
    print(f"  FLOW: {flow['name']}")
    if flow.get("description"):
        print(f"  {flow['description']}")
    print(f"  Jobs: {len(jobs)}")
    print(f"  {'[DRY-RUN MODE]' if dry_run else ''}")
    print(f"{'='*70}")

    nb_job_ids = {}  # job_id -> NB JobID
    status_file = flow_file.replace(".json", "_status.json")

    for i, job in enumerate(jobs, 1):
        deps = job.get("depends_on", [])
        dep_str = f" (after: {', '.join(deps)})" if deps else " (no deps)"
        print(f"\n[{i}/{len(jobs)}] {job['id']}{dep_str}")

        nb_id = submit_job(job, defaults, nb_job_ids, dry_run)
        if nb_id:
            nb_job_ids[job["id"]] = nb_id
        else:
            print(f"  FAILED to submit {job['id']} — aborting flow")
            break

    # Save status file
    status = {
        "flow": flow["name"],
        "submitted": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "jobs": {}
    }
    for job in jobs:
        jid = job["id"]
        status["jobs"][jid] = {
            "nb_job_id": nb_job_ids.get(jid, "NOT_SUBMITTED"),
            "task": job.get("task", jid),
            "depends_on": job.get("depends_on", []),
            "script": job["script"],
        }

    if not dry_run:
        with open(status_file, "w") as f:
            json.dump(status, f, indent=2)
        print(f"\n{'='*70}")
        print(f"  Flow submitted! Status: {status_file}")
    else:
        print(f"\n{'='*70}")
        print(f"  [DRY-RUN] Would save status to: {status_file}")

    print(f"{'='*70}")

    # Print summary table
    print(f"\n  {'Job ID':<25} {'NB JobID':<25} {'Depends On'}")
    print(f"  {'-'*25} {'-'*25} {'-'*30}")
    for job in jobs:
        jid = job["id"]
        nb_id = nb_job_ids.get(jid, "N/A")
        deps = ", ".join(job.get("depends_on", [])) or "-"
        print(f"  {jid:<25} {nb_id:<25} {deps}")

    return nb_job_ids


def show_status(flow_file):
    """Show status of a previously submitted flow."""
    status_file = flow_file.replace(".json", "_status.json")
    if not os.path.exists(status_file):
        print(f"No status file found: {status_file}")
        print(f"Submit the flow first with: python3 nb_flow.py --flow {flow_file}")
        return

    with open(status_file) as f:
        status = json.load(f)

    print(f"{'='*70}")
    print(f"  FLOW: {status['flow']}")
    print(f"  Submitted: {status['submitted']}")
    print(f"{'='*70}")

    print(f"\n  {'Job ID':<25} {'NB JobID':<25} {'Depends On'}")
    print(f"  {'-'*25} {'-'*25} {'-'*30}")
    for jid, info in status["jobs"].items():
        deps = ", ".join(info.get("depends_on", [])) or "-"
        print(f"  {jid:<25} {info['nb_job_id']:<25} {deps}")

    print(f"\nTo check individual jobs:")
    for jid, info in status["jobs"].items():
        if info["nb_job_id"] != "NOT_SUBMITTED":
            print(f"  {jid}: check log files or NB web UI for JobID {info['nb_job_id']}")


def print_example():
    """Print an example flow file."""
    example = {
        "name": "par_meu_pba_all_corners",
        "description": "Run PBA queries on par_meu IFC for all setup corners, then merge",
        "defaults": {
            "target": "sc8_express",
            "qslot": "/c2dg/BE_BigCore/gfc/sd",
            "class": "SLES15&&500G&&16C",
            "workdir": "/nfs/site/disks/sunger_wa/meu_manual_work"
        },
        "jobs": [
            {
                "id": "pba_max_high",
                "task": "PBA par_meu max_high",
                "script": "/nfs/site/disks/sunger_wa/meu_manual_work/nb_pba_max_high.sh",
                "depends_on": []
            },
            {
                "id": "pba_max_med",
                "task": "PBA par_meu max_med",
                "script": "/nfs/site/disks/sunger_wa/meu_manual_work/nb_pba_max_med.sh",
                "depends_on": []
            },
            {
                "id": "pba_max_low",
                "task": "PBA par_meu max_low",
                "script": "/nfs/site/disks/sunger_wa/meu_manual_work/nb_pba_max_low.sh",
                "depends_on": []
            },
            {
                "id": "merge_pba",
                "task": "Merge all PBA results",
                "script": "/nfs/site/disks/sunger_wa/meu_manual_work/merge_pba_results.sh",
                "depends_on": ["pba_max_high", "pba_max_med", "pba_max_low"],
                "class": "SLES15&&4C&&16G"
            }
        ]
    }
    print(json.dumps(example, indent=2))


def main():
    import argparse
    parser = argparse.ArgumentParser(
        description="NB Job Orchestration with Dependencies",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Show example flow file:
  python3 nb_flow.py --example > my_flow.json

  # Dry-run (preview commands without submitting):
  python3 nb_flow.py --flow my_flow.json --dry-run

  # Submit flow:
  python3 nb_flow.py --flow my_flow.json

  # Check status:
  python3 nb_flow.py --status my_flow.json
        """
    )
    parser.add_argument("--flow", help="Flow JSON file to submit")
    parser.add_argument("--dry-run", action="store_true", help="Preview commands without submitting")
    parser.add_argument("--status", help="Show status of a submitted flow")
    parser.add_argument("--example", action="store_true", help="Print example flow JSON")

    args = parser.parse_args()

    if args.example:
        print_example()
    elif args.status:
        show_status(args.status)
    elif args.flow:
        run_flow(args.flow, args.dry_run)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()

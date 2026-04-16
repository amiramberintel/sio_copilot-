================================================================================
  SKILL: flow_manager -- NB Job Orchestration & ECO Flow Execution
================================================================================

TRIGGERS: flow, run, auto, eco_flow, clone, ward, sonicade, run_auto_pt_eco,
          orchestrate, pipeline, chain, dependency, multi-step

WHAT THIS SKILL DOES:
  - Submit multi-step NB flows with job dependencies (A waits for B)
  - Parallel job execution with automatic dependency resolution
  - Create and run PT-ECO flows using run_auto_pt_eco.py
  - Clone work areas for ECO iterations
  - Track flow status and results

================================================================================
  NB JOB ORCHESTRATION (nb_flow.py)
================================================================================

  Script: scripts/nb_flow.py

  KEY FEATURE: NB --triggers for job dependencies
    --triggers "JobID1:done"              Job waits for JobID1 to finish
    --triggers "JobID1:done,JobID2:done"  Job waits for BOTH to finish

  USAGE:
    # Generate example flow file:
    python3 nb_flow.py --example > my_flow.json

    # Preview without submitting:
    python3 nb_flow.py --flow my_flow.json --dry-run

    # Submit the flow:
    python3 nb_flow.py --flow my_flow.json

    # Check status:
    python3 nb_flow.py --status my_flow.json

  FLOW FILE FORMAT (JSON):
    {
      "name": "flow_name",
      "description": "what this flow does",
      "defaults": {
        "target": "sc8_express",
        "qslot": "/c2dg/BE_BigCore/gfc/sd",
        "class": "SLES15&&500G&&16C",
        "workdir": "/path/to/workdir"
      },
      "jobs": [
        { "id": "job_a", "script": "/path/a.sh", "depends_on": [] },
        { "id": "job_b", "script": "/path/b.sh", "depends_on": [] },
        { "id": "merge", "script": "/path/merge.sh", "depends_on": ["job_a", "job_b"] }
      ]
    }

  HOW IT WORKS:
    1. Topologically sorts jobs by dependencies
    2. Submits independent jobs first (no deps → start immediately)
    3. Dependent jobs get --triggers with parent JobIDs
    4. NB holds triggered jobs in queue until parents finish
    5. Saves status to <flow>_status.json for tracking

  DEPENDENCY PATTERNS:
    Parallel:     A, B, C all have depends_on: []  → run simultaneously
    Sequential:   B depends_on: [A], C depends_on: [B]  → A → B → C
    Fan-out:      B, C both depend_on: [A]  → A → (B + C parallel)
    Fan-in:       D depends_on: [B, C]  → B,C parallel → D after both
    Diamond:      A → (B,C parallel) → D  (combine fan-out + fan-in)

  PER-JOB OVERRIDES:
    Any job can override defaults:
      { "id": "merge", "script": "...", "class": "SLES15&&4C&&16G", ... }

================================================================================
  COMMON FLOW PATTERNS
================================================================================

  PATTERN 1: PBA all corners then merge
    pba_max_high ─┐
    pba_max_med  ─┼─→ merge_report
    pba_max_low  ─┘

  PATTERN 2: PT-ECO with validation
    pt_eco_fix ──→ sta_signoff ──→ ifc_check

  PATTERN 3: Multi-partition parallel ECO
    eco_par_meu ──┐
    eco_par_pmh ──┼─→ full_chip_sta ──→ release_check
    eco_par_exe ──┘

  PATTERN 4: Session restore → analysis → report
    restore_session ──→ run_queries ──→ generate_report

================================================================================
  AUTOMATED ECO FLOW (run_auto_pt_eco.py)
================================================================================

MAIN TOOL:
  /nfs/site/disks/ucde/tools/tool_utils/apr_eco/latest/scripts/run_auto_pt_eco.py

  USAGE:
    run_auto_pt_eco.py --ref_ward <path> --flow <flow_name> [options]

  REQUIRED ARGS:
    --ref_ward REF_WARD     Reference workspace path
    --flow FLOW             Flow name (e.g. apr_fc_*, apr_cdns_*)

  OPTIONAL ARGS:
    --block BLOCK           Block name (auto-detected from par_* under runs/)
    --clone_ward CLONE_WARD New (cloned) ward path
    --nc                    Skip cloning (no copy of ref ward data)
    --tcl TCL               Path to ECO TCL file
    --nbc NBCLASS           NB class [Default: SLES15&&500G&&16C]
    --nbq NBQSLOT           NB queue [Default: /c2dg/BE_BigCore/gfc/sd]
    --nbp NBPOOL            NB pool  [Default: sc8_express]

NBVAR OVERRIDE:
  - If nbvar file exists in work area, sonic reads it automatically
  - Command-line flags (--nbc, --nbq, --nbp) override nbvar
  - Recommendation: use flags for one-off runs, nbvar for persistent config

================================================================================
  AVAILABLE SCRIPTS
================================================================================

  scripts/nb_flow.py              NB job orchestration with dependencies
  cookbooks/nb_flow_cookbook.txt   Step-by-step guide for multi-step flows
  examples/pba_all_corners.json   Example: PBA on 3 corners then merge

PREREQS:
  - NB access to sc8_express pool
  - Queue slot permissions for /c2dg/BE_BigCore/gfc/sd
  - Python 3 (for nb_flow.py)

SEE ALSO:
  skills/nb/                    NB configuration, gotchas, templates
  skills/nb/cookbooks/          PBA via NB cookbook
  skills/eco/                   ECO fix strategies
  tools/pt_eco/                 PT-ECO tool reference
  config/tools.cfg              Tool paths and NB defaults
================================================================================

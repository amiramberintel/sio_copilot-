================================================================================
  SKILL: flow_manager -- Automated ECO Flow Execution
================================================================================

TRIGGERS: flow, run, auto, eco_flow, clone, ward, sonicade, run_auto_pt_eco

WHAT THIS SKILL DOES:
  - Create and run PT-ECO flows using run_auto_pt_eco.py
  - Clone work areas for ECO iterations
  - Configure NB resources for flow execution
  - Track flow status and results

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
                            (copied to pt_eco/outputs/<block>.final.icc2tcl.tcl)
    --nbc NBCLASS           NB class [Default: SLES15&&500G&&16C]
    --nbq NBQSLOT           NB queue [Default: /c2dg/BE_BigCore/gfc/sd]
    --nbp NBPOOL            NB pool  [Default: sc8_express]

EXAMPLE COMMANDS:

  # Run ECO flow with default NB settings:
  run_auto_pt_eco.py \
    --ref_ward /path/to/ref_ward \
    --flow apr_fc_pteco_setup

  # Run with custom TCL fix and 512G memory:
  run_auto_pt_eco.py \
    --ref_ward /path/to/ref_ward \
    --flow apr_fc_pteco_setup \
    --tcl /path/to/my_eco_fix.tcl \
    --nbc "SLES15&&500G&&16C"

  # Clone ward and run ECO:
  run_auto_pt_eco.py \
    --ref_ward /path/to/ref_ward \
    --clone_ward /path/to/new_ward \
    --flow apr_fc_pteco_setup

  # Skip cloning (reuse existing ward):
  run_auto_pt_eco.py \
    --ref_ward /path/to/ref_ward \
    --flow apr_fc_pteco_setup \
    --nc

NBVAR OVERRIDE:
  - If nbvar file exists in work area, sonic reads it automatically
  - Command-line flags (--nbc, --nbq, --nbp) override nbvar
  - Recommendation: use flags for one-off runs, nbvar for persistent config

FLOW EXECUTION STEPS:
  1. Generate auto_pt_eco.csv from reference ward
  2. Invoke sonicade with the CSV
  3. NB job submitted with configured class/queue/pool
  4. Monitor via NB job tracking

PREREQS:
  - Reference ward with valid build
  - ECO TCL file (if applying fixes)
  - NB queue access

SEE ALSO:
  skills/nb/          -- NB configuration details
  skills/eco/         -- ECO fix strategies
  tools/pt_eco/       -- PT-ECO tool reference
  config/tools.cfg    -- Tool paths and NB defaults
================================================================================

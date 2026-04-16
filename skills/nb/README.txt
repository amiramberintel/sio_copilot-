================================================================================
  SKILL: nb -- NetBatch Job Management
================================================================================

TRIGGERS: nb, nbjob, netbatch, queue, pool, class, submit, batch, farm

WHAT THIS SKILL DOES:
  - Submit NB jobs for PT session restore, PBA queries, ECO runs, STA
  - Configure NB class, queue slot, pool
  - Track job status and resource usage

NB DEFAULTS (GFC Client A0):
  Class:   SLES15&&500G&&16C
  Queue:   /c2dg/BE_BigCore/gfc/sd
  Pool:    sc8_express

================================================================================
  NBJOB RUN SYNTAX
================================================================================

  nbjob run --target <pool> \
    --qslot <queue_slot> \
    --class "<class_expression>" \
    [--task "<job_name>"] \
    [--log-file-dir <path>] \
    [--wash] \
    <script_or_command>

  SUPPORTED FLAGS (confirmed working):
    --target         Pool target (e.g. sc8_express)
    --qslot          Queue slot path
    --class          Resource class expression (quoted!)
    --task           Job name/label (replaces old --title)
    --log-file-dir   Where NB writes stdout/stderr logs
    --wash           Clean environment
    --properties     Key=value pairs
    --work-dir       Working directory for the job

  *** NOT SUPPORTED ***
    --title          DOES NOT EXIST — use --task instead

  OUTPUT:
    "Your job has been queued (JobID NNNNN, Class ..., Queue ..., Slot ...)"

================================================================================
  PT SESSION RESTORE VIA NB
================================================================================

  CORRECT METHOD (2 steps inside NB script):
    1. cth_psetup   — sets up CTH container, environment, tools
    2. load_session_cth.csh — restores PT session, sources procs

  FULL COMMAND (NB wrapper script):
  ┌──────────────────────────────────────────────────────────┐
  │ #!/bin/bash                                              │
  │ DAILY="/path/to/daily_ward"                              │
  │ SESSION="$DAILY/runs/core_client/.../pt_session.<corner>"│
  │ TCL="/path/to/my_queries.tcl"                            │
  │                                                          │
  │ /nfs/site/proj/hdk/pu_tu/prd/liteinfra/1.19.p1/commonFlow/bin/cth_psetup \ │
  │   -proj gfc_n2_client/GFC_TS2025.17.0 \                 │
  │   -nowash \                                              │
  │   -cfg gfcn2clienta0.cth \                               │
  │   -ward $DAILY \                                         │
  │   -x "\$SETUP_R2G ; /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh \ │
  │       $SESSION -file $TCL -title my_job"                 │
  └──────────────────────────────────────────────────────────┘

  CTH_PSETUP FLAGS:
    -proj <project/tag>  Project and tag (e.g. gfc_n2_client/GFC_TS2025.17.0)
    -nowash              Don't clean environment
    -cfg <config.cth>    CTH config file (gfcn2clienta0.cth)
    -cfg_ov <file.cth>   Config overrides (optional)
    -ward <path>         Work area (daily ward path)
    -x '<commands>'      Commands to run inside CTH container

  LOAD_SESSION_CTH.CSH FLAGS:
    <session_path>       (required) Path to saved PT session
    -file <tcl>          Source TCL after session restore, then exit
    -title <name>        Window title / job label
    -log <logfile>       Redirect PT log to file
    -no_setup            Skip sourcing procs/setup files
    -no_exit             Stay in PT shell after -file script completes

  WHY 2 STEPS:
    cth_psetup sets up the container with all tools, licenses, env vars.
    load_session_cth.csh needs to run INSIDE that container.
    The -x flag of cth_psetup passes commands into the container.

  INTERACTIVE PT ON NB MACHINE:
    nbjob run --target sc8_express \
      --qslot /c2dg/BE_BigCore/gfc/sd \
      --class "SLES15&&500G&&16C" \
      --task "pt_interactive" \
      /path/to/wrapper.sh

  INTERACTIVE PT ON LOCAL XTERM (needs enough RAM):
    /nfs/site/proj/hdk/pu_tu/prd/liteinfra/1.19.p1/commonFlow/bin/cth_psetup \
      -proj gfc_n2_client/GFC_TS2025.17.0 -nowash -cfg gfcn2clienta0.cth \
      -ward <daily> \
      -x '$SETUP_R2G ; /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh \
          <session_path> -title core_client_BU_max_high'

================================================================================
  HOW DAILY FLOW SUBMITS PT JOBS
================================================================================

  The daily flow uses:
    cth_submit run --wash --target sc8_express \
      --qslot bc15_gfc_sd \
      --class "SLES15&&512G&&16C" \
      Ipt_shell -F sta_pt -B core_client ...

  cth_submit = CTH wrapper around nbjob (adds prediction, env setup)
  Ipt_shell  = CTH PT wrapper (sets up container, env vars, runs PT)

  For MANUAL work (session restore, PBA queries, ECO):
  - Do NOT use Ipt_shell (it runs the full STA flow)
  - Use pt_shell -file directly (see above)
  - The PT binary is accessible from NB machines at the path above

================================================================================
  GOTCHAS & LESSONS LEARNED
================================================================================

  1. --title flag DOES NOT EXIST
     nbjob does not support --title. Use --task for job naming.
     Symptom: silent failure or "unknown option"

  2. sg soc FAILS in NB jobs
     "setgid: Operation not permitted"
     NB machines cannot switch security groups.
     NEVER use "sg soc -c ..." in NB scripts.
     Use the full PT binary path directly instead.

  3. -restore_session is TCL, not CLI
     pt_shell does NOT accept -restore_session on command line.
     Error: "unknown option '-restore_session' (CMD-010)"
     MUST put restore_session inside a .tcl file and use -file flag.

  4. -execute is NOT a valid CLI flag
     pt_shell uses -x for inline commands, -file for script files.
     -execute will fail with CMD-010.

  5. Log capture in NB
     NB captures stdout/stderr to its own log files.
     For explicit logging, use "exec > >(tee -a logfile) 2>&1" in bash.
     Or use --log-file-dir to specify NB's log directory.

  6. Session restore is SLOW
     Expect 15-30 minutes for a full partition session (~100-200GB).
     Plan NB class accordingly (500G+ memory).

  7. Old aliases use SLES12 and pnc queue
     Team aliases (timor) reference SLES12 and /c2dg/BE_BigCore/pnc/.
     Current project needs SLES15 and /c2dg/BE_BigCore/gfc/sd.

================================================================================
  TEMPLATE: PBA VIA NB
================================================================================

  Wrapper script template (nb_pba_template.sh):
  ┌──────────────────────────────────────────────────────────┐
  │ #!/bin/bash                                              │
  │ LOGFILE="/path/to/my_job.log"                            │
  │ exec > >(tee -a "$LOGFILE") 2>&1                         │
  │                                                          │
  │ echo "=== Job Start: $(date) ==="                        │
  │ echo "Host: $(hostname)"                                 │
  │                                                          │
  │ DAILY="/path/to/daily_ward"                              │
  │ SESSION="$DAILY/runs/core_client/n2p_htall_conf4/sta_pt/<corner>/outputs/core_client.pt_session.<corner>"  │
  │ TCL="/path/to/my_queries.tcl"                            │
  │                                                          │
  │ /nfs/site/proj/hdk/pu_tu/prd/liteinfra/1.19.p1/commonFlow/bin/cth_psetup \  │
  │   -proj gfc_n2_client/GFC_TS2025.17.0 \                 │
  │   -nowash -cfg gfcn2clienta0.cth \                       │
  │   -ward $DAILY \                                         │
  │   -x "\$SETUP_R2G ; /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh \  │
  │       $SESSION -file $TCL -title my_job"                 │
  │                                                          │
  │ echo "=== Job Done: $(date) ==="                         │
  └──────────────────────────────────────────────────────────┘

  TCL template (pba_template.tcl):
  ┌──────────────────────────────────────────────────────────┐
  │ # Session already restored by load_session_cth.csh       │
  │                                                          │
  │ # Run PBA query                                          │
  │ set paths [get_timing_paths -from <sp> -to <ep> \        │
  │   -pba_mode path -max_paths 1 -nworst 1]                │
  │ set slack [get_attribute [index_collection $paths 0] slack]  │
  │ puts "PBA slack = $slack"                                │
  │                                                          │
  │ exit                                                     │
  └──────────────────────────────────────────────────────────┘

  Submit:
    nbjob run --target sc8_express \
      --qslot /c2dg/BE_BigCore/gfc/sd \
      --class "SLES15&&500G&&16C" \
      --task "pba_<partition>_<corner>" \
      /path/to/nb_pba_template.sh

================================================================================
  NB ALIASES (from team -- NEED UPDATE for SLES15/GFC)
================================================================================

  Original (Timor, SLES12/PNC):
    load_pt_session_in_nb_express       -- 128G, SLES12, pnc queue
    load_pt_session_in_nb_express_256G  -- 256G
    load_pt_session_in_nb_express_512G  -- 512G

  These use: /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh
  and SLES12 class + pnc/sd qslot — may need updating for GFC SLES15.

AVAILABLE SCRIPTS:
  scripts/load_daily_pt_sessions.csh  -- Submit PT session load for all corners
  knowledge/timor_aliases_reference.txt -- Team aliases including NB shortcuts

PREREQS:
  - NB access configured
  - Queue slot permissions for /c2dg/BE_BigCore/gfc/sd

SEE ALSO:
  skills/flow_manager/  -- Uses NB to run ECO flows
  tools/pt_server/      -- PT sessions loaded via NB
  config/tools.cfg      -- NB defaults defined here
  skills/ifc/cookbooks/pba_full_bus_report_cookbook.txt -- PBA report workflow
================================================================================

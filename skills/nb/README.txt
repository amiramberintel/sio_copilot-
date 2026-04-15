================================================================================
  SKILL: nb -- NetBatch Job Management
================================================================================

TRIGGERS: nb, nbjob, netbatch, queue, pool, class, submit, batch, farm

WHAT THIS SKILL DOES:
  - Submit NB jobs for PT session loading, ECO runs, STA
  - Configure NB class, queue slot, pool
  - Track job status and resource usage

NB DEFAULTS (GFC Client A0):
  Class:   SLES15&&500G&&16C
  Queue:   /c2dg/BE_BigCore/gfc/sd
  Pool:    sc8_express

COMMON NB COMMANDS:
  # Submit a PT session load
  nbjob run --target sc8_express \
    --qslot /c2dg/BE_BigCore/gfc/sd \
    --class "SLES15&&500G&&16C" \
    <command>

  # Load PT sessions for all corners (from Timor's script):
  # See scripts/load_daily_pt_sessions.csh
  # Uses: /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh
  # Base: $GFC_LINKS/daily_gfc0a_n2_core_client_bu_postcts/runs/core_client/n2p_htall_conf4/sta_pt

NB ALIASES (from team):
  load_pt_session_in_nb_express       -- 128G memory
  load_pt_session_in_nb_express_256G  -- 256G memory
  load_pt_session_in_nb_express_512G  -- 512G memory (for large partitions)

NBVAR FILE:
  - If nbvar exists in work area, sonic reads it automatically
  - Flags to run_auto_pt_eco.py override nbvar settings
  - Flags: --nbc (class), --nbq (qslot), --nbp (pool)

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
================================================================================

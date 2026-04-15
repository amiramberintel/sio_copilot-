SKILL: Daily Build Monitoring & Partition Status
TRIGGERS: daily status, partition status, build status, regressions, par_status, wns tns
PRIORITY: P1
STATUS: HAVE

WHAT:
  Track partition health across daily builds. Detect regressions.
  Generate per-corner reports. Compare vs PO baseline.
  This is the #1 daily SIO task.

KEY SCRIPTS:
  scripts/par_status.py          -- partition health (IFC + HSD tracking)
    Usage: python3 scripts/par_status.py -p par_meu --wa <daily_wa>

  scripts/par_status_diff.py     -- build-to-build diff
    Usage: python3 scripts/par_status_diff.py --latest WW13G -p par_meu

  scripts/ifc_per_corner_report.py -- per-corner setup+hold IFC report
    Usage: python3 scripts/ifc_per_corner_report.py --daily <daily_wa> --par par_meu --outdir <dir>

  scripts/check_daily_vs_po.py   -- daily vs PO timing comparison
  scripts/model_timing_status.py -- fast WNS/TNS/FEP status (50-70x faster)
  scripts/run_daily_update.py    -- orchestrate daily refresh pipeline

WEEKLY WORKFLOW:
  1. New daily build drops -> run par_status.py for all 11 partitions
  2. Diff vs previous build -> run par_status_diff.py
  3. Generate per-corner report -> run ifc_per_corner_report.py
  4. Analyze regressions, track in HSD
  5. Results stored in: fc_data/my_learns/ww<NN>_<N>/

SEE ALSO:
  skills/bu_model/, skills/model_comparison/, skills/reporting/

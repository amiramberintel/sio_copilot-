================================================================================
  SKILL: bu_model -- Process Daily Build (BU) Model Data
================================================================================

TRIGGERS: bu, daily, build, model, contour, tag, latest, postcts, sta

WHAT THIS SKILL DOES:
  - Process new daily BU model data from contour
  - Extract WNS/TNS/FEP per partition per corner
  - Parse IFC reports from builds
  - Track build-over-build trends
  - Support model review workflow

DAILY BUILD PATH PATTERN:
  $GFC_LINKS/daily_gfc0a_n2_core_client_bu_postcts/runs/core_client/
    n2p_htall_conf4/sta_pt/<corner>/outputs/

EXAMPLE DATA:
  examples/par_mlc_ifc.rpt  -- Real IFC report from par_mlc build

BUILD PROCESSING WORKFLOW:
  1. Identify latest build tag from contour
  2. Locate STA results: <build>/runs/<block>/<process>/sta_pt/<corner>/
  3. Parse timing reports: WNS, TNS, FEP
  4. Parse IFC reports: per-family breakdown
  5. Compare against previous build (see skills/model_comparison/)
  6. Generate status report (see skills/reporting/)

CORNERS TO CHECK:
  Setup: func.max_high, func.max_med, func.max_low, func.max_nom
  Hold:  func.min_low, func.min_high, fresh.min_fast
  (All at T_85.typical unless otherwise noted)

PREREQS:
  - Access to daily build directories
  - contour access for build tags

SEE ALSO:
  skills/model_comparison/ -- Compare 2+ builds
  skills/daily_monitoring/ -- Automated monitoring
  skills/reporting/        -- Build status reports
  config/paths.cfg         -- Build directory paths
================================================================================

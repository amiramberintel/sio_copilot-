================================================================================
  SKILL: model_comparison -- Compare BU Models and Track Regressions
================================================================================

TRIGGERS: compare, model, build, regression, delta, diff, ww, weekly, port_diff

WHAT THIS SKILL DOES:
  - Compare partition status across 2+ BU models (daily builds)
  - Track WNS/TNS/FEP deltas between builds
  - Detect new/removed ports between builds
  - Generate per-corner EXT/INT/CLK comparison tables
  - Send model review summary mails

AVAILABLE SCRIPTS:
  scripts/model_review.py
    -- Full model review with XML parsing
    -- Generates HTML mail with per-corner tables
    -- Sections: uArc, DFX EXT, DFX INT, per-corner EXT/INT
    -- Args: wa, partition, corners, main_corner, dfx_corner

  scripts/par_model_review.py
    -- Per-partition model review variant
    -- Focused on single partition across corners

  scripts/checkdifferent.py
    -- Quick port diff between two builds
    -- Shows: added ports, removed ports
    -- Useful for RTL change impact analysis

EXAMPLE DATA:
  examples/ww14b_par_mlc.csv  -- WW14 build B par_mlc IFC data
  examples/ww14g_par_mlc.csv  -- WW14 build G par_mlc IFC data
  -- Compare these to see weekly progression

COMPARISON WORKFLOW:
  1. Get IFC reports from both builds (daily_build paths in config/paths.cfg)
  2. Run checkdifferent.py to find port changes
  3. Run model_review.py for full corner-by-corner comparison
  4. Generate delta report: WNS improved/degraded, new violations

PREREQS:
  - Access to daily build directories
  - Python3 with pandas, xml.etree

SEE ALSO:
  skills/bu_model/          -- Process single build data
  skills/daily_monitoring/  -- Daily automated checks
  skills/reporting/         -- Report templates for comparisons
  config/paths.cfg          -- Daily build paths
================================================================================

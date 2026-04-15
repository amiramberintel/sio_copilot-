================================================================================
  SKILL: reporting -- Structured Report Generation
================================================================================

TRIGGERS: report, summary, table, csv, mail, what_if, status, weekly,
          delta, regression

WHAT THIS SKILL DOES:
  - Generate structured timing reports (ASCII tables)
  - Convert IFC RPT files to CSV format
  - Create what-if analysis reports
  - Generate comparison/delta reports between builds
  - Status summaries per partition/corner

AVAILABLE SCRIPTS:
  scripts/covert_to_csv.py  -- IFC report to CSV converter
    -- Reads PT report format, extracts timing data
    -- Filters by pattern/regex
    -- Output: CSV with path, slack, endpoint columns

REPORT FORMAT RULES:
  1. HEADER: Task name, date, partition, corner, build
  2. SUMMARY: One-line bottom line (improved/degraded/no_change)
  3. TABLES: ASCII with | separators, aligned columns
  4. STATUS FLAGS: [IMPROVED] [DEGRADED] [NO_CHANGE] [CRITICAL]
  5. FOOTER: Copilot disclaimer, data source, next steps
  6. NO UNICODE -- ASCII only for terminal compatibility

REPORT TEMPLATES:
  templates/what_if.txt        -- "What if I push clock X by Y ps?"
  templates/status.txt         -- Partition/corner status snapshot
  templates/comparison.txt     -- Side-by-side build comparison
  templates/eco_impact.txt     -- ECO before/after analysis
  templates/path_analysis.txt  -- Deep dive on specific paths
  templates/multi_corner.txt   -- Cross-corner timing summary
  templates/regression.txt     -- Week-over-week regression tracking
  templates/weekly_summary.txt -- Full weekly status mail format

EXAMPLE -- WHAT_IF REPORT:
  ================================================================
  WHAT-IF REPORT: Push mclk_meu +5ps in func.max_high
  Date: 2026-04-13  Partition: par_meu  Corner: func.max_high
  ================================================================
  SUMMARY: WNS improves from -103ps to -98ps [IMPROVED]
  ----------------------------------------------------------------
  | Metric     | Before  | After   | Delta   | Status     |
  |------------|---------|---------|---------|------------|
  | WNS        | -103ps  | -98ps   | +5ps    | [IMPROVED] |
  | TNS        | -45.2ns | -42.1ns | +3.1ns  | [IMPROVED] |
  | FEP        | 246     | 239     | -7      | [IMPROVED] |
  ----------------------------------------------------------------
  NOTE: Clock push affects ALL paths in mclk_meu domain.
  NEXT: Check hold impact in func.min_* corners.
  ================================================================

SEE ALSO:
  skills/model_comparison/ -- Uses reporting for build diffs
  skills/daily_monitoring/ -- Daily reports
  skills/ifc/             -- IFC data for reports
================================================================================

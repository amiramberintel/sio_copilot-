SKILL: Setup Timing Analysis
TRIGGERS: setup timing, setup violation, setup wns, setup analysis, worst setup, setup path
PRIORITY: P1
STATUS: HAVE

WHAT:
  Analyze setup timing violations. Identify worst paths, root causes,
  fix candidates. Covers all setup corners (func.max_*).

SETUP CORNERS:
  max_high, max_nom, max_low, max_med, max_fast,
  max_slow_rc_high, max_turbo, max_slow_low, max_slow_mid

PT COMMANDS:
  report_timing -through <signal> -max_paths 10
  report_timing -from <start> -to <end> -pba_mode path
  report_timing -through <signal> -path_type full_clock_expanded
  get_attribute [get_cells <cell>] ref_name
  get_attribute [get_cells <cell>] threshold_voltage_group

PBA (Path-Based Analysis):
  More accurate than GBA -- removes pessimism
  -pba_mode path (single paths), -pba_mode exhaustive (full)
  Typical improvement: 5-15ps

SEE ALSO:
  skills/ifc/, skills/clock/, tools/primetime/, tools/pt_server/

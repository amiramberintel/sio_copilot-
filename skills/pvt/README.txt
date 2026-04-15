SKILL: PVT Corner System
TRIGGERS: corner, voltage, derate, pvt, scenario, ocv, corner naming
PRIORITY: P1
STATUS: HAVE

WHAT:
  Understand PVT corner naming, voltage mapping, derate settings.
  29 IO constraint TCL files.

SCENARIO NAME FORMAT:
  <mode>.<voltage_corner>.<process_temp>.<rc_corner>
  Example: func.max_high.T_85.typical

  Mode:     func = aged (BTI),  fresh = no aging
  Process:  T = typical,  F = fast,  S = slow
  Temp:     85 = 85C,  125 = 125C,  M40 = -40C
  RC:       typical, cworst, rcworst, CCworst, CCworst_T

FULL DETAILS:
  -> config/corners.cfg

SEE ALSO:
  config/corners.cfg, config/paths.cfg (pvt.tcl, pvt.csv, global_derate_table.tcl)

SKILL: Regression Debug
TRIGGERS: regression, why regressed, build regression, timing worse, what changed
PRIORITY: P4
STATUS: GAP

WHAT:
  Why did timing regress build-to-build? Common causes, bisect strategy,
  netlist diff tools.

COMMON CAUSES:
  - RTL change (new logic, changed pipeline)
  - Constraint change (new SDC, removed false path)
  - Lib update (new cell characterization)
  - Routing change (SPEF update, reroute)
  - Clock tree change (CTS rerun)

SEE ALSO:
  skills/model_comparison/, skills/daily_monitoring/

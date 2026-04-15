SKILL: Caliber Signoff
TRIGGERS: caliber, slow slope, max cap, pulse width, signoff rule, clock min pulse
PRIORITY: P3
STATUS: HAVE

WHAT:
  Intel FC signoff rule checker. Physical/electrical rules.
  Different from STA: checks cap, slopes, pulse widths, clock integrity.
  Violations are per-pin (not per-path).

TOP RULES: SlowSlope, MaxCap, ClockMinPulseWidth, LatchMarginWithRecovery
OWNER TYPES: PO_PV (physical), PO_SYN (synthesis), PO (partition owner)

REPORTS:
  <daily_wa>/runs/core_client/n2p_htall_conf4/intel_caliber_all/<corner>/reports/caliber/
  <daily_wa>/runs/core_client/n2p_htall_conf4/sta_pt/reports/caliber_indicators/

FULL KNOWLEDGE:
  /nfs/site/disks/sunger_wa/skills_for_sio_copilot/caliber/

SEE ALSO:
  tools/caliber_tool/, partitions/<par>/

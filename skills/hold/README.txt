SKILL: Hold Timing Analysis
TRIGGERS: hold timing, hold violation, hold wns, hold analysis, hold per port, hold daily vs pteco
PRIORITY: P1
STATUS: HAVE

WHAT:
  Multi-corner hold timing debug. Daily vs PTECO comparison.
  Per-port hold detail across all 12 hold corners.

HOLD CORNERS:
  fresh.min_fast, fresh.min_fast_cold, fresh.min_slow,
  func.min_hi_lo_hi, func.min_low, func.min_nom,
  func.min_hvqk, func.min_slow_cold
  (+ more -- check config/corners.cfg)

KEY SCRIPTS:
  scripts/hold_per_port_report.py -- multi-corner hold per-port detail
    Usage: python3 scripts/hold_per_port_report.py --wa <daily_wa> --par par_meu --outdir <dir>

  scripts/hold_daily_vs_pteco.py -- daily vs PTECO comparison
    Usage: python3 scripts/hold_daily_vs_pteco.py --wa <daily_wa> --par par_meu --pteco <pteco_root> --outdir <dir>

HOLD CLOCK NAMES (not just mclk!):
  idvfreqOut, idvfreqOut_div2/4/8/16, dcmcbbclk,
  ijtag_tck, scanclk_div, scanclk_notdiv_phyex, ssh_ijtag, etc.
  ALWAYS show full clock names.

SEE ALSO:
  skills/ifc/, skills/eco/, tools/primetime/

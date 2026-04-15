SKILL: DFX Timing (Design for Testability)
TRIGGERS: dfx, test mode, bist, bisr, jtag, ijtag, scanclk, scan chain, test timing
PRIORITY: P3
STATUS: HAVE

WHAT:
  Test mode timing separate from functional. Covers BIST, BISR, JTAG,
  IJTAG, scan chains. Uses test clocks with different periods.

DFX CLOCKS:
  bist, bisr, misr, scanclk, ijtag_tck, bisr_ijtag, ssh_ijtag,
  ssnclk, slos, tap, clkg, pm_clock, saf, m4saf, async
  Clock periods: mclk=186ps to ijtag=6266ps

KEY CORNERS: func.max_high (setup), func.min_low (hold), func.max_low+CT

DFX REPORTS:
  <daily_wa>/runs/core_client/n2p_htall_conf4/sta_pt/<corner>/reports/*only_dfx.x*
  NOTE: uses dcm_release models, not dcm_daily

FULL KNOWLEDGE:
  /nfs/site/disks/sunger_wa/skills_for_sio_copilot/dfx/

SEE ALSO:
  skills/pvt/, tools/primetime/, config/corners.cfg

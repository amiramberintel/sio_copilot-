SKILL: FEV (Formal Equivalence Verification)
TRIGGERS: fev, formal, equivalence, conformal, lec, greenstone, rtl vs netlist
PRIORITY: P3
STATUS: HAVE

WHAT:
  RTL vs netlist logic equivalence check (Cadence Conformal LEC).
  Must-pass signoff: no tapeout without clean FEV.

CHECKS: NonEquivalent, NotMapped, RTLUndrivenNets, BBox matching, power intent

FEV LOCATIONS:
  FEV WA: /nfs/site/disks/idc_bei_fev/gpavanku/GFC_FEV_RUN/FEV_RUN/
  Summary: .../IF_<par>_fev_rtl2apr/results/Greenstone_summary.rpt
  LEC log: .../fev_conformal/fev_rtl2apr/logs/lec.log

STATUS (WW14A): 5 PASS, 7 FAIL. par_meu FAIL (243 RTL dangling, AR on RTL team).
RUN OWNER: gpavanku

SEE ALSO:
  tools/conformal/, partitions/<par>/

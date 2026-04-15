SKILL: power
PRIORITY: LOW
STATUS: PARTIAL
TRIGGERS: power, leakage, dynamic power, power report, power_on, fct_attribute

DESCRIPTION
-----------
Power analysis and power-on interface for GFC partitions.

AVAILABLE SCRIPTS
-----------------
scripts/power_on_all_par.csh  -- Run power-on flow across all partitions
tcl/get_power.tcl             -- PT shell: extract power data per partition
tcl/fct_attribute.tcl         -- FCT attribute queries for power analysis

USAGE
-----
Power-on flow:
  source scripts/power_on_all_par.csh

PT shell power extraction:
  source tcl/get_power.tcl

FCT attribute analysis:
  source tcl/fct_attribute.tcl

SOURCE: /nfs/site/disks/home_user/baselibr/GFC_script/power_on_interface/

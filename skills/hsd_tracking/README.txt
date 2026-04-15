SKILL: hsd_tracking
PRIORITY: MEDIUM
STATUS: PARTIAL
TRIGGERS: hsd, rtl4be, rtl bug, hsdes, bug tracking, silicon bug

DESCRIPTION
-----------
HSD (HSDES) tracking for GFC RTL4BE items.
Search and track RTL bugs that impact SIO timing closure.

AVAILABLE SCRIPTS
-----------------
scripts/find_hsd  -- Search RTL4BE database for GFC-A0 items
                     Caches results in ~baselibr/STOD/tmp/gfc.rtl4be
                     Auto-refreshes if data > 24 hours old
                     Uses esquery to pull from HSDES

USAGE
-----
  find_hsd <search_term>

Example:
  find_hsd mclk_meu        -- find all RTL4BE items mentioning mclk_meu
  find_hsd par_exe          -- find bugs impacting par_exe partition

NOTE: Database updates require baselibr user access. If stale, ask Basel.

SOURCE: /nfs/site/disks/home_user/baselibr/GFC_script/find_hsd

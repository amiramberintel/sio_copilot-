TOOL: PT-ECO (PrimeTime ECO Mode)
Make timing fixes inside PrimeTime.

KEY COMMANDS:
  insert_buffer <net> <buffer_cell>
  remove_buffer <buffer_cell>
  size_cell <cell> <new_ref>
  swap_cell <cell> <new_ref>
  set_eco_options -allow_design_rule_fixing true
  write_changes -format icc2 -output <file>
  report_eco_changes

PTECO FLOW (Alex's runs):
  Location: /nfs/site/disks/ayarokh_wa/pteco/runs/GFC/core_client_<date>_ww<N>/
  Structure: runs/core_client/n2p_htall_conf4/pt_eco/reports/*nworst*xml
  Multi-corner: runs separate PT-ECO per corner

WORKFLOW:
  1. Load design + constraints
  2. Identify failing path (report_timing)
  3. Apply fix (insert_buffer / size_cell / swap_cell)
  4. Check impact (report_timing again)
  5. Write changes for PO (write_changes -format icc2)

SEE ALSO: tools/estimate_eco/, tools/primetime/, skills/eco/

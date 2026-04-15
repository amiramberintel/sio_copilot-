================================================================================
  TOOL: pt_server -- PrimeTime Server Mode
================================================================================

WHAT:
  Interactive PT sessions accessed remotely via pt_client.pl or pt_client.py.
  Each corner runs as a separate PT server with socket interface.

SESSION LOADING:
  Sessions loaded via NB:
    nbjob run --target sc8_express \
      --qslot /c2dg/BE_BigCore/gfc/sd \
      --class "SLES15&&500G&&16C" \
      /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh <session_path>

  Session base path:
    $GFC_LINKS/daily_gfc0a_n2_core_client_bu_postcts/runs/core_client/n2p_htall_conf4/sta_pt

  Corner session format:
    <base>/<corner>/outputs/core_client.pt_session.<corner>/

PT SERVER MODE FORMAT:
  latest_gfcn2clienta0_bu_prp_<corner>
  Example: latest_gfcn2clienta0_bu_prp_func.max_high.T_85.typical

AVAILABLE CORNERS:
  func.max_med.T_85.typical
  func.max_low.T_85.typical
  func.max_high.T_85.typical
  func.max_nom.T_85.typical
  func.min_low.T_85.typical
  fresh.min_fast.F_125.rcworst_CCworst
  func.min_high.T_85.typical

PT CLIENT ACCESS:
  Via pt_client.pl (Perl):
    sg soc -c "pt_client.pl -mode latest_gfcn2clienta0_bu_prp_<corner> -cmd '<tcl_cmd>'"

  Via pt_client.py (Python, from testCSPT):
    python3 pt_client.py <host> <port> "<tcl_cmd>"
    python3 pt_client.py <host>:<port> "<tcl_cmd>"

PT SERVER TCL SETUP (per corner):
  Each corner has a source_*.tcl wrapper that sets:
    pt_server_project  = gfcn2clienta0
    pt_server_type     = bu_prp
    pt_server_corner   = <corner>
    pt_server_model    = modela
    pt_server_process  = n2p_htall_conf4
  Then sources pt_server.tcl for socket server

FORBIDDEN COMMANDS (will crash PT server):
  source, exit, save, exec, insert_buffer, size_cell

AVAILABLE SCRIPTS:
  examples/testCSPT/pt_client.pl       -- Perl PT client (production)
  examples/testCSPT/pt_client.py       -- Python PT client (lightweight)
  examples/testCSPT/pt_gui.py          -- PT GUI tool
  examples/testCSPT/fct2.py            -- FCT tool
  examples/testCSPT/fct_server_tool.py -- FCT server tool
  examples/testCSPT/pt_server.tcl      -- Server-side TCL
  examples/testCSPT/source_*.tcl       -- Per-corner source wrappers

SEE ALSO:
  tools/primetime/    -- PT shell commands
  skills/nb/          -- NB job submission for loading
  config/corners.cfg  -- Corner definitions
================================================================================

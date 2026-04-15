# Wrapper: source this file in your PT session to start the server for corner: func.min_fast
# Usage (inside pt_shell):
#   source /path/to/testCSPT/source_func.min_fast.tcl

set pt_server_project "gfcn2clienta0"
set pt_server_type    "bu_prp"
set pt_server_corner  "fresh.min_fast.F_125.rcworst_CCworst"
set pt_server_model   "modela"
set pt_server_process "n2p_htall_conf4"
source [file join [file dirname [file normalize [info script]]] pt_server.tcl]

# Wrapper: source this file in your PT session to start the server for corner: func.max_med
# Usage (inside pt_shell):
#   source /path/to/testCSPT/source_func.max_med.tcl

set pt_server_project "gfcn2clienta0"
set pt_server_type    "bu_prp"
set pt_server_corner  "func.max_med.T_85.typical"
set pt_server_model   "modela"
set pt_server_process "n2p_htall_conf4"
source [file join [file dirname [file normalize [info script]]] pt_server.tcl]

#!/bin/bash
# TEMPLATE: NB wrapper for PT session restore + PBA queries
# Uses cth_psetup + load_session_cth.csh (full CTH container setup)
#
# Usage: nbjob run --target sc8_express --qslot /c2dg/BE_BigCore/gfc/sd \
#          --class "SLES15&&500G&&16C" --task "pba_<name>" this_script.sh

LOGFILE="/path/to/my_pba.log"    # <-- EDIT
DAILY="/path/to/daily_ward"      # <-- EDIT
SESSION="$DAILY/runs/core_client/n2p_htall_conf4/sta_pt/<corner>/outputs/core_client.pt_session.<corner>"  # <-- EDIT
TCL="/path/to/my_pba.tcl"        # <-- EDIT

exec > >(tee -a "$LOGFILE") 2>&1

echo "=== PBA NB Job Start: $(date) ==="
echo "Host: $(hostname)"
echo "Session: $SESSION"
echo "TCL: $TCL"

/nfs/site/proj/hdk/pu_tu/prd/liteinfra/1.19.p1/commonFlow/bin/cth_psetup \
  -proj gfc_n2_client/GFC_TS2025.17.0 \
  -nowash \
  -cfg gfcn2clienta0.cth \
  -ward $DAILY \
  -x "\$SETUP_R2G ; /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh $SESSION -file $TCL -title pba_job"

echo "=== PBA NB Job Done: $(date) ==="

#!/bin/tcsh -f
# This script runs inside cth_psetup -x environment
# It sources R2G, then runs fc_shell with our extraction script

echo "Setting up R2G..."
$SETUP_R2G -force -b core_server -w TIP

echo "License file: $SNPSLMD_LICENSE_FILE"
echo "Running fc_shell..."

fc_shell -f /nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/extract_jnc_pins.tcl

echo "DONE"

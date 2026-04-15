#!/bin/bash
# Farm job wrapper for FC pin extraction
export SNPSLMD_LICENSE_FILE="26586@fm_synopsys_1:26586@fm_synopsys_2:26586@fm_synopsys_3:26586@fm_synopsys_4:26586@fm_synopsys_5:26586@an_synopsys_1"
cd /nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC
sg jnc_pcore_ex -c "/p/hdk/cad/fusioncompiler/V-2023.12-SP5-6-613-T-20250917/bin/fc_shell -f fc_extract_standalone.tcl"

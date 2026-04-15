#!/bin/csh

# Define corners
set corners = (func.max_med.T_85.typical func.max_low.T_85.typical func.max_high.T_85.typical func.max_nom.T_85.typical func.min_low.T_85.typical fresh.min_fast.F_125.rcworst_CCworst func.min_high.T_85.typical )

# Base path
set base_path = "$GFC_LINKS/daily_gfc0a_n2_core_client_bu_postcts/runs/core_client/n2p_htall_conf4/sta_pt"

# Loop through corners and submit jobs
foreach corner ($corners)
    set corner_path = "${base_path}/${corner}/outputs/core_client.pt_session.${corner}/"
    echo "Submitting job for $corner"
    echo $corner_path
    nbjob run --target sc8_express --qslot /c2dg/BE_BigCore/pnc/sd/sles12_sd --class "SLES12&&4C&&512G" /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh $corner_path -title "$corner"
end

echo "Done!"

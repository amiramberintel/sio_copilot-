#!/usr/bin/tcsh -f
source /nfs/site/disks/home_user/gilkeren/.aliases
source /p/hdk/pu_tu/prd/fct_alias/latest/utils/fct_run_aliases
set top = $1
if ($top == "icore") then
echo "starting:" `date` >> /nfs/site/disks/home_user/gilkeren/daily.log
cthFct /nfs/site/disks/home_user/gilkeren/user_fct_vars/pnc_client/user_fct_vars.1278.bu.icore.daily.tcl
echo "finished:" `date` >> /nfs/site/disks/home_user/gilkeren/daily.log
else
echo "starting:" `date` >> /nfs/site/disks/home_user/gilkeren/daily_dcm.log
cthFct /nfs/site/disks/home_user/gilkeren/user_fct_vars/pnc_client/user_fct_vars.1278.bu.dcm.daily.tcl
echo "finished:" `date` >> /nfs/site/disks/home_user/gilkeren/daily_dcm.log
endif

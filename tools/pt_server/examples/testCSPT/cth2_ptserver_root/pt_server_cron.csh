#!/usr/intel/bin/tcsh -f

##############################################################################
#C2DG PT Server CTH2 Systems | Created by ohad.givol@intel.com | January 2021#
##############################################################################

#/p/hdk/bin/cth_psetup -proj lnltr -cfg LNLTRP05_nrc.cth -cfg_ov #/nfs/iil/proj/icl/icl_soc_execution2/soc/matanros/CH2/test//A0_IIL_VER_001-FCT20WW42A_latest_setup_eou_dev_lnl-CLK008.fcl/fct/cth_ovr.cth -ward <ward> -x '$SETUP_R2G -tech 1278.2 #-force -w <ward> -t eou_dev_lnl -b soc' 

#/p/hdk/bin/cth_psetup -grp 'c2dgusers mpgall adl adl_rtl sklall soc hdk10nm hdk7nm hdk7nmproc tyc tyc78 tyc78proc' -proj lnl/latest -cfg lnlca0.cth -ward /nfs/iil/proj/lnl/pt_server/cth2_ptserver/cth2_ptserver_ward -cmd 'echo -I- Pre_R2G_Setup ... ; $SETUP_R2G -force -tech 1277.2 -force -w icsl10043 -b soc ; echo -I-Pre_Server_Scripter... ; ./pt_server_supervisor.pl -config ./pt_server_c2dgbcptserver_cron.cfg ; echo -I-Exit_now_from_current_shell'
#-I-Post_R2G/CTH_setup_kill...

#Default settings here:
echo "-I- C2DG PT Server CTH2 Systems, Welcome $USER...\n"
#set script_path = `/bin/dirname $0`
set script_path = "/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/"
echo "-I- Your scripts location is : script_path = $script_path\n"

#Setup Definitions:
echo "-I- Prepare Basic definitions for now.\n"
set block            = "core_server"
#set proj             = "pnc_78_server/TS2023.3.hfww07"
set proj             = "lnc_n3_client/lncb0.01"
#set tech             = "1278.3"
set tech             = "h169p45_80nm_tsmc_m18"
#set cfg              = "pnc78servera0.cth"
set cfg              = "lncn3b0.cth"
set template_ver     = ""                  #empty means no template here
set pt_server_ward   = "/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_ward"

#Local Scripting definitions:
echo "-I- Prepare Basic definitions - Scripting data for now.\n"
set host                        = "${HOST}"
set cron_log                    = "$pt_server_ward/pt_server_c2dgbcptserver_cron.log"
set pt_server_supervisor_script = "$script_path/pt_server_supervisor.pl"
set string_of_groups            = "'c2dgusers mpgall sklall n3 n2p gfcn2_pcore_ex soc hdk10nm hdk7nm hdk7nmproc tyc tyc78 i1278proc pncn2_pcore_ex i1278'"
set pt_server_config            = "$script_path/pt_server_c2dgbcptserver_cron.cfg"
set cmd_on_setup                = "$pt_server_supervisor_script -config $pt_server_config > /dev/null"
set cmd_on_setup                = "$pt_server_supervisor_script -config $pt_server_config"

#Local Scripting definitions - R2G Setup:
echo "-I- Prepare Basic definitions - R2G Executable Command.\n"
set executable_command = '$SETUP_R2G '"-force -tech $tech -force -w $host -t $template_ver -b $block"
if ($template_ver == "") then
    set executable_command = '$SETUP_R2G '"-force -tech $tech -force -w $host -b $block"
endif

#Prepare tcsh file which will hold all related data here:
/bin/rm -f /tmp/pt_server_c2dgbcptserver_cron_$host.tcsh
/usr/bin/touch /tmp/pt_server_c2dgbcptserver_cron_$host.tcsh
echo '#\!/usr/intel/bin/tcsh -f\n' >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
#echo 'echo "-I- Entring Now R2G Setup..."' >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
#echo '' >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
#echo "/nfs/site/disks/crt_tools_003/liteinfra/1.1.p01/commonFlow/bin/cth_psetup -grp ${string_of_groups} -proj ${proj} -cfg ${cfg} -ward ${pt_server_ward} -x '$executable_command'"  >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
#echo '' >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
#echo 'echo "-I- Running now pt_server checker... Begin..."' >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
#echo '' >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
#echo "${cmd_on_setup}" >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
#echo '' >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
#echo 'echo "-I- Running now pt_server checker... End..."' >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
#echo '' >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh

#https://www.unix.com/shell-programming-and-scripting/96920-quitting-bash-script-any-alternatives-exit.html
#echo "/nfs/site/disks/crt_tools_003/liteinfra/1.1.p01/commonFlow/bin/cth_psetup -grp ${string_of_groups} -proj ${proj} -cfg ${cfg} -ward ${pt_server_ward} -cmd 'echo "-I- Pre R2G Setup ..." ; $executable_command ; echo "-I- Pre Server Scripter..." ; $cmd_on_setup ; echo "-I- Exit now from current shell"'"  >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
#set cmd_pre_r2g_setup = 'echo "-I- Pre_R2G_Setup..."'
#set cmd_pre_server_script = 'echo "-I- Pre_Server_Script..."'
#set cmd_exit_now_current_shell = 'echo "-I- ExitNowFromCurrentShell..."'
#echo "/p/hdk/bin/cth_psetup -grp ${string_of_groups} -proj ${proj} -cfg ${cfg} -ward ${pt_server_ward} -cmd 'echo "-I- Pre_R2G_Setup ..." ; $executable_command ; echo "-I-Pre_Server_Scripter..." ; $cmd_on_setup ; echo "-I-Exit_now_from_current_shell"'"  >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
echo 'echo "-I-Pre_R2G/CTH_setup_kill..."\n ' >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
echo "/p/hdk/bin/cth_psetup -grp ${string_of_groups} -proj ${proj} -cfg ${cfg} -ward ${pt_server_ward}/${host} -cmd ' $executable_command ; $cmd_on_setup '"  >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
echo 'echo "-I-Post_R2G/CTH_setup_kill..."\n ' >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
echo 'exit 0' >> /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh

/bin/chmod 770 /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh

#Execute current command:
echo "-I- Running for now: /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh : Begin\n"
/tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh
echo "-I- Running for now: /tmp/pt_server_c2dgbcptserver_cron_${host}.tcsh : End\n"

echo "-I- PT SERVER CRON: Completed Running now...Bye..Bye...\n"
echo "-I- C2DG PT Server CTH2 Systems, Completed run for now, have a great day: $USER...\n"
echo "-I- Bye Bye...\n"
exit 0

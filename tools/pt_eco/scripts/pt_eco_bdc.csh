###Hello Gil,
###
###
###Below are the steps to run PTECO :
###1.	Do Flow setup:
###/p/hdk/bin/cth_psetup -proj lnc_n3_client/2021.12.14 -cfg lncn3a0.cth -ward $PWD -x '$SETUP_R2G -w $PWD -force'
###2.	Link the PT sessions. Update the sta_ward area with latest FCT run area.
###set block = "lnc_client"
###set sta_ward = "/nfs/iil/disks/core_fct/lnc/fct/rishavsh/sd10-RTL22ww40a_41_1_RTL_update-FCT22WW43C_1810-CLK228.bu_post"
###mkdir -p runs/${block}/h169p45_80nm_tsmc_m18/release/latest/sta_primetime
###ln -s $sta_ward/runs/${block}/h169p45_80nm_tsmc_m18/release/latest/sta_primetime/* runs/${block}/h169p45_80nm_tsmc_m18/release/latest/sta_primetime/.
###\rm runs/${block}/h169p45_80nm_tsmc_m18/release/latest/sta_primetime/*session*
###ln -s $sta_ward/runs/${block}/h169p45_80nm_tsmc_m18/sta_pt/*/outputs/*session* runs/${block}/h169p45_80nm_tsmc_m18/release/latest/sta_primetime/.
###3.	Copy below reference scripts :
###cp -rf /nfs/iil/disks/core_fct/lnc/fct/rishavsh/raghav/logical_scripts runs/${block}/h169p45_80nm_tsmc_m18/scripts
###4.	Update the PT version:
###$CTH_TSETUP -tool primetime/S-2021.06-SP5-CS2-T-20220629
###5.	Do setup of the PTECO run:
###Ipteco_shell --setup_only -B ${block} --run_dir <run_directory>
###6.	Copy the reference scripts for pteco:
###cp -rf /nfs/iil/disks/core_fct/lnc/fct/rishavsh/raghav/pteco_scripts/*  runs/${block}/h169p45_80nm_tsmc_m18/<run_directory>/scripts/.
###7.	Update the required options in vars.tcl (eg : scenarios, netbatch options, fixing options,etc)
###8.	Update the fix eco task file with the required fix for eco. Example:
###/nfs/iil/stod/stod901/w.raghavg1.100/analysis/pteco_ooo_vec_42D_20221013_1/runs/lnc_client/h169p45_80nm_tsmc_m18/pt_eco_run2/scripts/pteco_template_fix_hold.tcl
###9.	Command to invoke PTECO shell:
###Ipteco_shell -B ${block} -P -I --run_dir <run_directory> &
###10.	Command to run flow just before eco fix:
###eou::debug -break pteco_template_fix_hold.tcl
###11.	Below commands are executed to exclude sio_ovr_buffer from final ECO:
###remote_execute -verbose {write_changes -format icc2tcl -output sio_ovr_buffer.icc2tcl}
###remote_execute -verbose {write_changes -reset -format text -output sio_ovr_buffer.txt}
###12.	Depending on fix methods provided run flow till finish/<another task>:
###eou::debug -break pteco_template_fix_hold_iter2.tcl
###13.	The ECO will be present in the outputs folder.
###
###Reference Area1 to restrict fixing inside specific partition:
###/nfs/iil/stod/stod901/w.raghavg1.100/analysis/pteco_ooo_vec_42D_20221013_1/runs/lnc_client/h169p45_80nm_tsmc_m18/pt_eco_run2/
###
###Reference Area 2 with different fixing options:
###/nfs/iil/stod/stod901/w.raghavg1.100/analysis/pteco_fma_20221019_43C_1/runs/lnc_client/h169p45_80nm_tsmc_m18/pt_eco_run1_meu/scripts/pteco_template_fix_hold.tcl


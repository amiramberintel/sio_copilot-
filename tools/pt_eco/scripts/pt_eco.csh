#WIKI: https://wiki.ith.intel.com/display/LNLBE/PT_ECO+Optimization+at+FullChip

#enter FCT setup
/p/hdk/pu_tu/prd/fct_alias/latest/utils/cth_duplicate.csh <REF FCT model> <NEW area>

#Link run area to model (in case your model is in different ward)
#make sure that REF model promote STA results 

set src_dir = <REF FCT model>

mkdir -p $ward/runs/$block/$tech/release/latest
mkdir -p $ward/runs/$block/$tech/sta_pt/scripts/
mkdir -p $ward/runs/$block/$tech/pt_eco/
foreach dir ( `ls -d $src_dir/runs/$block/$tech/release/latest/*` )
set basename=`basename $dir`
rm -rf $ward/runs/$block/$tech/release/latest/$basename
ln -s $dir $ward/runs/$block/$tech/release/latest/$basename
end
foreach partition_area (ls -d $src_dir/runs/*)
    if ( -d $partition_area ) then
       if ( `basename $partition_area` != $block ) then
             echo "Linking: $partition_area"
             ln -vs $partition_area $ward/runs/
       endif
    endif
end
ln -s $src_dir/runs/$block/$tech/hip_data $ward/runs/$block/$tech/hip_data
cp -rf $src_dir/runs/$block/$tech/sta_pt/scripts $ward/runs/$block/$tech/sta_pt/
cp -rf $src_dir/runs/$block/$tech/scripts $ward/runs/$block/$tech/
cp -rf $src_dir/user_env_vars_file.csh $ward/
source $ward/user_env_vars_file.csh
cp -Lrf $HACK_DIR/runs/$block/$tech/scripts/* $ward/runs/$block/$tech/scripts/
cp -rf $HACK_DIR/runs/$block/$tech/pt_eco/scripts $ward/runs/$block/$tech/pt_eco/
cp -rf $HACK_DIR/runs/$block/$tech/pt_eco/inputs $ward/runs/$block/$tech/pt_eco/


#par_tmul_stub issue (for running physical aware)
\rm -rf $ward/runs/par_tmul_stub
\cp -rf $src_dir/runs/par_tmul_stub $ward/runs/par_tmul_stub
\rm -rf $ward/runs/par_tmul_stub/$tech/release/latest/sta_primetime
eouMGR --populate --bundle sta_primetime --block par_tmul_stub --tag clean_ring_ww45_from_plo_updated_closure_tag_sta_pt_ww46p2

\rm -rf $ward/runs/par_pm
\cp -rf $src_dir/runs/par_pm $ward/runs/par_pm
\rm -rf $ward/runs/par_pm/$tech/release/latest/sta_primetime
eouMGR --populate --bundle sta_primetime --block par_pm --tag sd1.0_rtlww31d_2011



#in case ref wa didnt promote pt sessions
#rm -rf $ward/runs/$block/$tech/release/latest/sta_primetime/*
#foreach corner (`ls -ltr $src_dir/runs/$block/$tech/sta_pt/*/outputs/ | grep "pt_session" | awk -F "pt_session." '{print $NF}'`)
#ln -s `realpath $src_dir/runs/$block/$tech/sta_pt/$corner/outputs/$block.pt_session.$corner` $ward/runs/$block/$tech/release/latest/sta_primetime/$block.pt_session.$corner
#end

#edit 
gvim $ward/runs/$block/$tech/pt_eco/scripts/vars.tcl
#edit 
gvim $ward/runs/$block/$tech/pt_eco/scripts/pt_eco.$block.cfg
#edit
gvim $ward/runs/$block/$tech/scripts/nb_vars.tcl

#defult ivars: design_class/c2dg_be/snps/pt_eco/vars.tcl

#open shell
Ipteco_shell -B $block -P -I -N &


#to start another run at same WARD:
Ipteco_shell --setup_only -B ${block} --run_dir <run_directory>
#edit 
gvim $ward/runs/$block/$tech/<run_directory>/scripts/vars.tcl
#edit 
gvim $ward/runs/$block/$tech/<run_directory>/scripts/pt_eco.$block.cfg
Ipteco_shell -B ${block} -P -I -N --run_dir <run_directory> &


#start full run
::eou::debug -resume

#innovus change list fix
/nfs/iil/proj/skl/skl_optimization2/central_runs/da_utils/PT_ECO/convert_icc2tcl_to_innovus.tcl -dir $ward/runs/$block/$tech/pt_eco/outputs/splitted_icc2_changelist -verbose

#logs
$ward/runs/$block/$tech/pt_eco/logs/pt_eco.log - main log file
$ward/runs/$block/$tech/pt_eco/multisessions/multisession_2022_08_03_22_58_17/func.max_high.T_85.typical/out.log - slave log file

#output files
$ward/runs/$block/$tech/pt_eco/outputs/par_vtu_soc.final.icc2tcl.tcl  - PT & FC change list
$ward/runs/$block/$tech/pt_eco/outputs/par_vtu_soc.inn_change_list    - Innovus change list

#reports
$ward/runs/$block/$tech/pt_eco/reports/soc.latest.loops_qor.rpt     - summary results
$ward/runs/$block/$tech/pt_eco/reports/soc.path_margin_hold.eco.rpt - analyze hold violated paths

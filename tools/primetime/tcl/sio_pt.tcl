source $::env(SD_USER_UTILS)/cheetah_utils/init_cheetah_utils.tcl ; init_cheetah_utils 1
source /nfs/site/disks/hdk_putu_4/tool_utils/rdt/18.04.01/pkgs/parseOpt/parseOpt.7.0.tcl
source /nfs/site/disks/hdk_putu_4/tool_utils/rdt/18.04.01/pkgs/parseOpt/rls_table.tcl

#create path report based on archive io const.
mf_rpt_new -gen_header -max_paths 1000000 -th [get_ports ]  -nworst 1 -file $ivar(design_name).$scenario.rpt_ar
#load latest io const. and internal_exception
source ~gilkeren/lnc_links/latest_lnc0a_n3_fcl/runs/$ivar(design_name)/$tech/release/latest/timing_collateral/$scenario/$ivar(design_name)_io_constraints.tcl
set ivar(dst_dir) ./
source ~gilkeren/lnc_links/latest_lnc0a_n3_fcl/runs/$ivar(design_name)/$tech/release/latest/timing_collateral/$scenario/$ivar(design_name)_io_clock_uncertainty.tcl
iproc_source -file /nfs/site/disks/lnc_n3_client.arc.proj_archive/arc/$ivar(design_name)/sio_timing_collateral/GOLDEN/$ivar(design_name)_internal_exceptions.tcl -optional
iproc_source -file /nfs/site/disks/lnc_n3_client.arc.proj_archive/arc/$ivar(design_name)/sio_timing_collateral/GOLDEN/$scenario/$ivar(design_name)_temp_scenario_exceptions.tcl -optional
#create path report based on latest io const.
mf_rpt_new -gen_header -max_paths 1000000 -th [get_ports ]  -nworst 1 -file $ivar(design_name).$scenario.rpt_new

suppress_message "RC-009 RC-204 RC-201 UITE-487"
iproc_source -file $ward/runs/core_client/n2p_htall_conf4/sta_pt/scripts/fct_custom_report.tcl
set tp ""
set nworst 10
set mpath 5000000
foreach par [list icore0/par_fmav1 icore0/par_fmav0 icore0/par_exe icore0/par_ooo_int icore0/par_ooo_vec icore0/par_msid icore0/par_fe icore0/par_meu icore0/par_pmh par_pm par_mlc] {
puts "$par [date]"
append_to_collection -unique tp [get_timing_paths -delay_type max -slack_lesser_than 0 -pba_mode path  -include_hierarchical_pins -normalized_slack -max_paths $mpath -start_end_pair -th $par/* -to [get_clocks mclk_*]]
puts "[sizeof_collection $tp] [date]"																					   
}
fct_report_timing_summary $ivar(rpt_dir)/$ivar(design_name).$scenario\_timing_summary.external_mclk.xml $tp

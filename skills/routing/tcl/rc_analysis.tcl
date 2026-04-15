if {![info exists clk_name]} {
    puts "Error: clk_name not set. Usage: set clk_name <clock>; source rc_analysis.tcl"
    return
}
set pba path
set net_th 10
iproc_source -file /nfs/site/disks/home_user/gilkeren/scripts/tcl/report_nets_rc.tcl -optional
set messages "RC-201 RC-204 RC-004 RC-009 RC-104 RC-005"
suppress_message $messages
set paths [get_timing_paths -normalized_slack -from [get_clocks $clk_name] -to [get_clocks $clk_name] -pba $pba -max_paths 100000]
report_nets_rc $paths $net_th [pwd]/rc_nets_nworst_$ivar(design_name)_${clk_name}_${scenario}_${pba}.csv
unsuppress_message $messages
puts "done, file locate at: [pwd]/rc_nets_nworst_$ivar(design_name)_${clk_name}_${scenario}_${pba}.csv"

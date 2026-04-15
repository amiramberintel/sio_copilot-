source ~gilkeren/scripts/tcl/check_clk_latency.tcl

set out_file "$env(ward)/runs/$env(block)/$tech/sta_pt/$scenario/reports/check_clk_latency.$scenario.rpt"

redirect -file $out_file { puts "clk_name,avg_ntwrk,avg_src" }
foreach clk [list mclk_exe mclk_exe_int mclk_fe mclk_fma mclk_meu mclk_mlc mclk_msid mclk_ooo_int mclk_ooo_vec mclk_pmhglb mclk_pm uclk sbclk] {
redirect -append -file $out_file {check_clk_latency $clk}
}


set old_value1 [get_app_var timing_report_unconstrained_paths]
set old_value2 [get_app_var timing_report_fixed_width_columns_on_left]

set_app_var timing_report_unconstrained_paths true
set_app_var timing_report_fixed_width_columns_on_left true


#paths to CLKIN

set rise_late "$env(ward)/runs/$env(block)/$tech/sta_pt/$scenario/reports/paths_to_dop_rise_late.$scenario.rpt"
set rise_early "$env(ward)/runs/$env(block)/$tech/sta_pt/$scenario/reports/paths_to_dop_rise_early.$scenario.rpt"
set fall_late "$env(ward)/runs/$env(block)/$tech/sta_pt/$scenario/reports/paths_to_dop_fall_late.$scenario.rpt"
set fall_early "$env(ward)/runs/$env(block)/$tech/sta_pt/$scenario/reports/paths_to_dop_fall_early.$scenario.rpt"

redirect -file $rise_late { puts "#[date]" }
redirect -file $rise_early { puts "#[date]" }
redirect -file $fall_late { puts "#[date]" }
redirect -file $fall_early { puts "#[date]" }

set glb_col [get_pins -hierarchical -filter "full_name=~*glbdrv*CLKIN*"]
foreach_in_collection p $glb_col {
redirect -append -file $rise_late {puts "[get_object_name $p]"} 
redirect -append -file $rise_early {puts "[get_object_name $p]"} 
redirect -append -file $fall_late {puts "[get_object_name $p]"} 
redirect -append -file $fall_early {puts "[get_object_name $p]"} 

redirect -append -file $rise_late {report_timing -from mclk_pll -physical -voltage -supply_net_group -derate -var -delay_type max -cap -input -trans -nosplit -rise_through $p}
redirect -append -file $rise_early {report_timing -from mclk_pll -physical -voltage -supply_net_group -derate -var -delay_type min -cap -input -trans -nosplit -rise_through $p}
redirect -append -file $fall_late {report_timing -from mclk_pll -physical -voltage -supply_net_group -derate -var -delay_type max -cap -input -trans -nosplit -fall_through $p}
redirect -append -file $fall_early {report_timing -from mclk_pll -physical -voltage -supply_net_group -derate -var -delay_type min -cap -input -trans -nosplit -fall_through $p}

}

set_app_var timing_report_unconstrained_paths $old_value1
set_app_var timing_report_fixed_width_columns_on_left $old_value2


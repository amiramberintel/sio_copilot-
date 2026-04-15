proc icg_on_boundary {} {
    iproc_msg -info "starting icg_on_boundary"

    global env
    global ivar
    
    set f [open $ivar(rpt_dir)/ports_with_icg_summary.csv w]
    set f2 [open $ivar(rpt_dir)/ports_with_icg_summary_skew_slack.csv w]
    set debug [open $ivar(rpt_dir)/ports_with_icg_debug.rpt w]
     	
    set port_col [get_pins -quiet par_*/* -filter "full_name!~*FEEDTHRU* && direction==in"]   
    append_to_collection port_col [get_pins -quiet icore0/par_*/* -filter "full_name!~*FEEDTHRU* && direction==in"]
    append_to_collection port_col [get_pins -quiet icore0/* -filter "full_name!~*FEEDTHRU* && direction==in"]
    
    puts $f "TYPE,IN_PORT,ICG_name,start_clock,end_clock,gen_clk_ltncy,samp_clk_ltncy,slack,startpoint"
    puts $f2 "TYPE,IN_PORT,ICG_name,start_clock,end_clock,gen_clk_ltncy,samp_clk_ltncy,slack,startpoint"

    set slack_th 0
    set skew_th 20

    foreach_in_collection port $port_col {
		set p_obj [get_object_name $port]
		puts $debug "working on: $p_obj"
        	set port_fo [filter_collection [all_fanout -flat -trace_arcs all -endpoints_only -from $port] "full_name!~*diode* && full_name!~*DIODE*"]
		if {[sizeof_collection $port_fo] > 6000} {
		    	set port_fo_icg [filter_collection $port_fo "is_clock_gating_pin"]
        		if {[sizeof_collection $port_fo_icg] > 0} {set icg_on_fo 1}				
		    	puts $debug "high FO for $p_obj, [sizeof_collection $port_fo], icg_on_fo=$icg_on_fo"
		} else { 
			set drv_port [get_pins -quiet -of_objects [get_nets -quiet -of_objects [get_pins -quiet $port]] -filter "direction==out"]
        		set icg_on_fo 0
        		set port_fo_icg [filter_collection $port_fo "is_clock_gating_pin"]		
			set num_ep_icgs [sizeof_collection $port_fo_icg]
        		if {[sizeof_collection $port_fo_icg] > 0} {set icg_on_fo 1}	
			if {(![sizeof_collection $port_fo])} {
		    		puts $debug "no rcv, skipping"
			} else {
				if {$icg_on_fo == "1"} {
					puts $debug "rcv is icg"
		    			if {[get_attribute [get_pins $port] max_slack] == INFINITY } {
					    	puts $debug "rcv is icg and no slack, skipping"
					} else {
						puts $debug "ICG,[get_object_name $drv_port],[get_object_name $port],$num_ep_icgs"
						foreach_in_collection icg $port_fo_icg {
					    		set tp [get_timing_path -from [get_clocks mclk_*] -th $port -to $icg]
							if {[sizeof_collection $tp] == 0} {
							    	puts $debug "no mclk path to [get_object_name $icg]"
							} else {
								set strt_clk [get_attribute $tp startpoint_clock]
								set end_clk [get_attribute $tp endpoint_clock]
								set end_clk_ltncy [get_attribute $tp endpoint_clock_latency]
								set strt_clk_ltncy [get_attribute $tp startpoint_clock_latency]						
								set skew [expr $strt_clk_ltncy - $end_clk_ltncy]
								set slack [get_attribute $tp slack]
								set strt [get_attribute $tp startpoint]
								puts $f "ICG,$p_obj,[get_object_name $icg],[get_object_name $strt_clk],[get_object_name $end_clk],$strt_clk_ltncy,$end_clk_ltncy,$slack,[ get_object_name $strt]"
								if {$skew > $skew_th && $slack < $slack_th} {
									puts $f2 "ICG,$p_obj,[get_object_name $icg],[get_object_name $strt_clk],[get_object_name $end_clk],$strt_clk_ltncy,$end_clk_ltncy,$slack,[ get_object_name $strt]"
								}
					    		}
						}
		        		} 
		        	} else {
					puts $debug "no ICG at rcv"
				}
		    	}
    		}
    }
    close $f
    close $f2
    close $debug

    iproc_msg -info "Done icg_on_boundary"

}

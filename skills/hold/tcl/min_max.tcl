set port [get_ports [all_inputs] -filter {constrained_launch_clocks.full_name=~uclk*}]
set cmd_file [open [pwd]/$ivar(sta,delay_type)_req.csv w]
puts $cmd_file "name,type,$ivar(sta,delay_type)_req,$ivar(sta,delay_type)_slack,end_template,input_delay"
foreach_in_collection p $port {
    	set path [get_timing_path -delay_type $ivar(sta,delay_type) -th $p -to uclk]

	set data_arrival [get_attribute $path arrival] 
	set input_delay [get_attribute $path startpoint_input_delay_value] 
	set cclk_latency [get_attribute $path endpoint_clock_latency]
	set end_template [get_attribute [get_cells -of_objects [get_attribute $path endpoint]] ref_name]
    	if {$ivar(sta,delay_type) == "min"} {
	    	set hold [get_attribute $path endpoint_hold_time_value]

    		set req [expr $data_arrival - $input_delay - $cclk_latency - $hold]
	} else {
	    	set setup [get_attribute $path endpoint_setup_time_value]
		set latency_spec [get_attribute [get_clocks uclk] clock_source_latency_early_fall_max]

    		set req [expr $data_arrival - $input_delay - $cclk_latency + $setup + $latency_spec]
	}
	
	puts $cmd_file "[get_object_name $p],$ivar(sta,delay_type),$req,[get_attribute $path slack],$end_template,$input_delay"
}
close $cmd_file

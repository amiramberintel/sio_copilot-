proc gk_min_max_ebb {ebb {outfile ""}} {
    global env
    global ivar
    global scenario    
    if {$outfile eq ""} { set outfile "$env(ward)/${ebb}_${scenario}.csv" }

	set fp [open $outfile w]
	get_cells -hierarchical -filter full_name=~*$ebb*
	foreach_in_collection inst [get_cells -hierarchical -filter full_name=~*$ebb*] {	
	    	puts "[get_object_name $inst]"
		#set inst [lindex [get_object_name [get_cells -hierarchical -filter full_name=~*$ebb*]] 0]
		set pins [get_pins -of_objects $inst -filter "direction==in && !is_clock_pin"]
		foreach_in_collection p $pins {
		    	puts "[get_object_name $p]"
			if {$ivar(sta,delay_type) == "max"} {
				set req [get_attribute [get_timing_paths -to $p -delay_type $ivar(sta,delay_type)] endpoint_setup_time_value]
			} else {
				set req [get_attribute [get_timing_paths -to $p -delay_type $ivar(sta,delay_type)] endpoint_hold_time_value]
			}
		puts $fp "[get_object_name $inst],[get_object_name $p],$req"
		}
		puts "output pins"
		#outputs
		set pins [get_pins -of_objects $inst -filter "direction==out && !is_clock_pin"]
		set clk_pin [get_pins -of_objects $inst -filter "direction==in && is_clock_pin"]
		foreach_in_collection p $pins {
			if {$ivar(sta,delay_type) == "max"} {
				#set req [get_attribute [get_timing_paths -from $clk_pin -th $p -delay_type $ivar(sta,delay_type)] endpoint_setup_time_value]
			} else {
				#set req [get_attribute [get_timing_paths -from $clk_pin -th $p -delay_type $ivar(sta,delay_type)] endpoint_hold_time_value]
			}
		#puts $fp "[get_object_name $inst],[get_object_name $p],$req"
		}
		
	}
	close $fp
}

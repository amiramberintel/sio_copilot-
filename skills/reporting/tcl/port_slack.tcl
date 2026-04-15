proc port_slack {par pba_type} {
    global ivar
    switch $pba_type {
        path {set pba_mode path}
        gba {set pba_mode none}
        ex {set pba_mode ex}
	none {set pba_mode none}
    }
        set file "$::env(ward)/runs/$::env(block)/$::env(tech)/$::env(flow)/$::scenario/reports/fct_level_slack_per_port.$par.$::scenario.$pba_mode.rpt"
        set fileh [open $file w]
	if { [info exists ::ivar(design_name)] && ($::ivar(design_name) == "core_server"||$::ivar(design_name) == "core_client") } {
	    if { ($par == "par_mlc") || ($par == "par_pm") } {
		current_instance $par
		set ports [get_ports]
		current_instance
	    } else {
		current_instance icore1/$par
		set ports [get_ports]
		current_instance
	    }
	} else {
	    	current_instance $par
		set ports [get_ports]
		current_instance
	}
        puts "pba_mode: $pba_mode"
        puts $fileh "#pba_mode: $pba_mode"
	puts $fileh "#numbder of ports: [sizeof_collection $ports]"
        puts $fileh "#[date]"
        foreach_in_collection p $ports {
                set port_dir [get_attribute -quiet $p direction]
                set tp [get_timing_path -th $p -pba_mode $pba_mode -normalized_slack -delay_type $::ivar(sta,delay_type)]
		if {[sizeof_collection $tp]} {
                	set slack [get_attribute -quiet $tp slack]
		} else {
                	set slack "no_path"
		}
		puts $fileh "[get_object_name $p],$port_dir,$slack"
        }
        puts $fileh "#[date]"
        close $fileh
        puts "Done report at: $file"
}


proc port_slack_parallel {par pba_type} {
    global ivar
    switch $pba_type {
        path {set pba_mode path}
        gba {set pba_mode none}
        ex {set pba_mode ex}
	none {set pba_mode none}
    }
        set file "$::env(ward)/runs/$::env(block)/$::env(tech)/$::env(flow)/$::scenario/reports/fct_level_slack_per_port.$par.$::scenario.$pba_mode.parallel.rpt"
        set fileh [open $file w]
	if { [info exists ::ivar(design_name)] && ($::ivar(design_name) == "core_server"||$::ivar(design_name) == "core_client") } {
	    if { ($par == "par_mlc") || ($par == "par_pm") } {
		current_instance $par
		set ports [get_ports]
		current_instance
	    } else {
		current_instance icore1/$par
		set ports [get_ports]
		current_instance
	    }
	} else {
	    	current_instance $par
		set ports [get_ports]
		current_instance
	}
        puts "pba_mode: $pba_mode"
        puts $fileh "#pba_mode: $pba_mode"
	puts $fileh "#numbder of ports: [sizeof_collection $ports]"
        puts $fileh "#[date]"
        parallel_foreach_in_collection p $ports {
                set port_dir [get_attribute -quiet $p direction]
                set tp [get_timing_path -th $p -pba_mode $pba_mode -normalized_slack -delay_type $::ivar(sta,delay_type)]
		if {[sizeof_collection $tp]} {
                	set slack [get_attribute -quiet $tp slack]
		} else {
                	set slack "no_path"
		}
		puts $fileh "[get_object_name $p],$port_dir,$slack"
        }
        puts $fileh "#[date]"
        close $fileh
        puts "Done report at: $file"
}


proc port_slack_att {par} {
    global ivar
        set file "$::env(ward)/runs/$::env(block)/$::env(tech)/$::env(flow)/$::scenario/reports/fct_level_slack_per_port.$par.$::scenario.attribute.rpt"
        set fileh [open $file w]
	if { [info exists ::ivar(design_name)] && ($::ivar(design_name) == "core_server"||$::ivar(design_name) == "core_client") } {
	    if { ($par == "par_mlc") || ($par == "par_pm") } {
		current_instance $par
		set ports [get_ports]
		current_instance
	    } else {
		current_instance icore1/$par
		set ports [get_ports]
		current_instance
	    }
	} else {
	    	current_instance $par
		set ports [get_ports]
		current_instance
	}
	puts $fileh "#numbder of ports: [sizeof_collection $ports]"
        puts $fileh "#[date]"
        foreach_in_collection p $ports {
                set port_dir [get_attribute -quiet $p direction]
		puts $fileh "[get_object_name $p],$port_dir,[get_attribute [get_pins $p] max_slack]"
        }
        puts $fileh "#[date]"
        close $fileh
        puts "Done report at: $file"
}

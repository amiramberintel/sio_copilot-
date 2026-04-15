proc full_update_timing {} {
    puts "[date] start update_timing -full"
    redirect -file /dev/null {update_timing -full}
    puts "[date] done update_timing -full"
}

proc set_clock_freq {period clock_spec} {
    set clocks [get_clocks $clock_spec -filter defined(sources)]
    if {![sizeof_collection $clocks]} {
        error "no clocks matches $clock_spec"
    }
    foreach_in_collection clock $clocks {
        # add master clocks
        if {[get_attribute $clock is_generated]} {
            set master_clock [get_attribute $clock master_clock]
            while {[get_attribute $master_clock is_generated]} {
                append_to_collection -unique clocks $master_clock
                set master_clock [get_attribute $master_clock master_clock]
            }
            append_to_collection -unique clocks $master_clock
        }
    }
    set redefine_clocks {}
    foreach_in_collection clock $clocks {
        set clock_name [get_object_name $clock]
        set propagated [get_attribute $clock propagated_clock]
        set sources [get_attribute $clock sources]
        if {[get_attribute $clock is_generated]} {
            set master_clock [get_attribute $clock master_clock]
            set master_pin [get_attribute $clock master_pin]
        } else {
            lappend redefine_clocks [list [get_object_name $clock] $propagated $sources]
        }
    }
    suppress_message UITE-130
    foreach touple $redefine_clocks {
	lassign $touple clock_name propagated sources
	puts "create_clock -name $clock_name -period $period {[get_object_name $sources]}"
	create_clock -name $clock_name -period $period $sources
	if {$propagated} {
	    set_propagated_clock [get_clocks $clock_name]
	}
    }
    full_update_timing

    return [get_attribute [get_clocks $clock_name] period]
}


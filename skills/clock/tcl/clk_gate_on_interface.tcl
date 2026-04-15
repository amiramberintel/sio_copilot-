proc check_clk_gate { port } {
	set ports [get_pins $port]
	foreach_in_collection p $ports {
		set end_cells [get_cells -of_objects [all_fanout -flat -trace_arcs all -endpoints_only -from $p]]
		foreach_in_collection cell $end_cells {
		set template [get_attribute [get_cells $cell] ref_name]
			if { [regexp "^CK" $template] } {
				puts "[get_object_name $p],[get_object_name $cell],$template"
			}
		}
	}
}


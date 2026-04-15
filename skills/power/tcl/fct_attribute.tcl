set power_dir /nfs/site/disks/baselibr_wa/auto_fct/RTLB0_25ww06b_ww07_4_initial-FCT25WW10D_par_ooo_int_par_ooo_int_RTL8a_cont8__AUTO_SIO_MODEL_CI-CLK012.bu_postcts/power_results/
foreach file [glob  $power_dir/*user_attribute.tcl] {
    source $file 
}
proc get_ports_from_path {path} {
    # Assume path should include -include_hirehir (comment indicates a possible typo or specific flag)
    # Filter the collection to get only hierarchical pins from the path's points.object attribute
    set all_hier_pins [filter_collection [get_attribute $path points.object] is_hierarchical]

    # Initialize an empty list to store the ports
    set ports_list {}

    # Iterate over each hierarchical pin in the collection
    foreach_in_collection hier_pin $all_hier_pins {
        # Check if the hierarchical pin name matches the first regular expression pattern
        if {[regexp -all {^par_[^/]*/[^/]*$} [get_object_name $hier_pin]]} {
            # If it matches, add the pin to the ports list
            append_to_collection ports_list $hier_pin
        }
        # Check if the hierarchical pin name matches the second regular expression pattern
        if {[regexp -all {icore[0-9]/par_[^/]*/[^/]*$} [get_object_name $hier_pin]]} {
            # If it matches, add the pin to the ports list
            append_to_collection ports_list $hier_pin
        }
    }

    # Return the list of ports
    return $ports_list
}
proc calc_power_factor { path port } {
    set ports [get_ports_from_path $path ] 
    set total_power 0
    foreach item [get_attribute -quiet  $ports bu_dynamic_power] { 
        set total_power [expr $item+$total_power]
    }
    set port_power [get_attribute -quiet $port bu_dynamic_power ]      
    if { $port_power == "" } { 
        set port_power_factor  0 
        set port_power 0
    } else {
        set port_power_factor [format "%.2f" [expr $port_power/$total_power]]
    }
    if {$total_power < 10 } { 
        set port_power_factor 0.5
    }
    if {$port_power_factor < 0.2 } { 
        set port_power_factor 0.2 
    }
    if {$port_power_factor > 0.8 } { 
        set port_power_factor 0.8 
    }
    return $port_power_factor   
    foreach_in_collection port $ports {
        set port_power [get_attribute -quiet $port bu_dynamic_power ]      
        if { $port_power == "" } { 
            set port_power_factor  0 
            set port_power 0
        } else {
            set port_power_factor [format "%.2f" [expr $port_power/$total_power]]
        }
        if {$total_power < 10 } { 
            set port_power_factor 0.5
        }
        if {$port_power_factor < 0.2 } { 
            set port_power_factor 0.2 
        }
        if {$port_power_factor > 0.8 } { 
            set port_power_factor 0.8 
        }
        echo -n [get_object_name $port ],$port_power_factor,$port_power,$total_power,
    }
    echo ""
}

#===============================================================================
# physical_net_query.tcl -- Fast physical data queries in PT session
#===============================================================================
# Source this in your PT session:
#   source /nfs/site/disks/sunger_wa/init_sio_copilot/skills/spef_query/tcl/physical_net_query.tcl
#
# All queries are INSTANT because PT already has SPEF loaded in memory.
#===============================================================================

# Get full physical summary for a net
proc sio_net_physical {net_name} {
    set net [get_nets $net_name]
    if {[sizeof_collection $net] == 0} {
        puts "ERROR: Net '$net_name' not found"
        return
    }

    set cap   [get_attribute $net total_capacitance]
    set wlen  [get_attribute -quiet $net wire_length]
    set fanout [get_attribute -quiet $net fanout]

    puts "============================================================"
    puts "NET: $net_name"
    puts "============================================================"
    puts "Total Capacitance:  $cap"
    puts "Wire Length:        $wlen"
    puts "Fanout:             $fanout"

    # Driver info
    set driver_pins [get_pins -of $net -filter "direction==out"]
    if {[sizeof_collection $driver_pins] > 0} {
        set drv_pin [get_object_name $driver_pins]
        set drv_cell [get_cells -of $driver_pins]
        set drv_ref [get_attribute $drv_cell ref_name]
        set drv_loc [get_attribute -quiet $drv_cell location]
        puts "Driver:             $drv_pin ($drv_ref) @ $drv_loc"
    }

    # Receiver info
    set recv_pins [get_pins -of $net -filter "direction==in"]
    set num_recv [sizeof_collection $recv_pins]
    puts "Receivers:          $num_recv"

    # Show first few receivers
    set count 0
    foreach_in_collection pin $recv_pins {
        if {$count >= 5} {
            puts "  ... and [expr {$num_recv - 5}] more"
            break
        }
        set pname [get_object_name $pin]
        set cell [get_cells -of $pin]
        set ref [get_attribute $cell ref_name]
        set loc [get_attribute -quiet $cell location]
        set load [get_attribute -quiet $pin capacitance]
        puts "  [$count] $pname ($ref) @ $loc  load=$load"
        incr count
    }
    puts "============================================================"
}

# Get RC for all nets on a timing path
proc sio_path_physical {from to {max_paths 1}} {
    set paths [get_timing_paths -from $from -to $to -max_paths $max_paths]
    if {[sizeof_collection $paths] == 0} {
        puts "ERROR: No paths found from $from to $to"
        return
    }

    puts "============================================================"
    puts "PHYSICAL DATA FOR PATH: $from -> $to"
    puts "============================================================"
    set path [index_collection $paths 0]
    set slack [get_attribute $path slack]
    puts "Slack: $slack"
    puts ""
    puts [format "%-50s %-12s %-10s %-10s" "Net" "Cap(fF)" "WireLen" "Fanout"]
    puts [string repeat "-" 85]

    set prev_net ""
    foreach_in_collection point [get_attribute $path points] {
        set obj [get_attribute $point object]
        set net_col [get_attribute -quiet $obj net]
        if {$net_col != ""} {
            set nname [get_object_name $net_col]
            if {$nname != $prev_net} {
                set cap [get_attribute $net_col total_capacitance]
                set wlen [get_attribute -quiet $net_col wire_length]
                set fanout [get_attribute -quiet $net_col fanout]
                puts [format "%-50s %-12s %-10s %-10s" $nname $cap $wlen $fanout]
                set prev_net $nname
            }
        }
    }
    puts "============================================================"
}

# Find worst-RC nets connected to a clock domain
proc sio_worst_nets {clk_name {top_n 20} {cap_threshold 0}} {
    puts "Finding worst nets for clock $clk_name ..."
    set paths [get_timing_paths -from [get_clocks $clk_name] \
                                -to [get_clocks $clk_name] \
                                -max_paths 10000 -slack_lesser_than 0]
    set net_data [dict create]
    foreach_in_collection path $paths {
        foreach_in_collection point [get_attribute $path points] {
            set obj [get_attribute $point object]
            set net_col [get_attribute -quiet $obj net]
            if {$net_col != ""} {
                set nname [get_object_name $net_col]
                if {![dict exists $net_data $nname]} {
                    set cap [get_attribute $net_col total_capacitance]
                    if {$cap > $cap_threshold} {
                        dict set net_data $nname $cap
                    }
                }
            }
        }
    }

    # Sort by cap descending
    set sorted [lsort -real -decreasing -stride 2 -index 1 [dict get $net_data]]
    puts "============================================================"
    puts "TOP $top_n WORST-CAP NETS ON FAILING PATHS ($clk_name)"
    puts "============================================================"
    puts [format "%-5s %-50s %s" "#" "Net" "Cap(fF)"]
    puts [string repeat "-" 70]
    set i 0
    foreach {net cap} $sorted {
        if {$i >= $top_n} break
        incr i
        puts [format "%-5d %-50s %s" $i $net $cap]
    }
    puts "============================================================"
}

# Quick distance between two pins
proc sio_pin_distance {pin1 pin2} {
    set loc1 [get_attribute -quiet [get_pins $pin1] location]
    set loc2 [get_attribute -quiet [get_pins $pin2] location]
    if {$loc1 == "" || $loc2 == ""} {
        puts "ERROR: Could not get locations for pins"
        return
    }
    set x1 [lindex $loc1 0]; set y1 [lindex $loc1 1]
    set x2 [lindex $loc2 0]; set y2 [lindex $loc2 1]
    set dx [expr {abs($x2 - $x1)}]
    set dy [expr {abs($y2 - $y1)}]
    set dist [expr {$dx + $dy}]
    puts "$pin1 @ ($x1, $y1)"
    puts "$pin2 @ ($x2, $y2)"
    puts "Manhattan distance: $dist um  (dx=$dx, dy=$dy)"
}

puts "=== physical_net_query.tcl loaded ==="
puts "  sio_net_physical <net>            -- Full physical summary for a net"
puts "  sio_path_physical <from> <to>     -- RC for all nets on a path"
puts "  sio_worst_nets <clk> ?top_n?      -- Worst-cap nets on failing paths"
puts "  sio_pin_distance <pin1> <pin2>    -- Manhattan distance between pins"
puts "========================================="

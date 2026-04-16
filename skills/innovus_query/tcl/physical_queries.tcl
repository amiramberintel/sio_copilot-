#===============================================================================
# physical_queries.tcl -- Ready-to-use Innovus physical query procs
#===============================================================================
# Source this in an Innovus session for instant physical data queries.
# All procs use Innovus native APIs -- instant results once design is loaded.
#===============================================================================

# Full physical report for a net: metals, vias, wire length, cap, resistance
proc inv_net_report {net_name} {
    puts "============================================================"
    puts "NET PHYSICAL REPORT: $net_name"
    puts "============================================================"

    # Get net object
    set net [dbGet -p top.nets.name $net_name]
    if {$net == ""} {
        puts "ERROR: Net '$net_name' not found"
        return
    }

    # Wire length and segment count
    set wires [dbGet $net.wires]
    set total_length 0.0
    set layer_length [dict create]
    set layer_wire_count [dict create]
    set via_count 0
    set via_layers [dict create]

    foreach wire $wires {
        set segs [dbGet $wire.segs]
        foreach seg $segs {
            set layer [dbGet $seg.layer.name]
            set seg_length [dbGet $seg.length]

            if {[string match "VIA*" $layer] || [string match "via*" $layer]} {
                incr via_count
                dict incr via_layers $layer
            } else {
                set total_length [expr {$total_length + $seg_length}]
                if {[dict exists $layer_length $layer]} {
                    dict set layer_length $layer [expr {[dict get $layer_length $layer] + $seg_length}]
                } else {
                    dict set layer_length $layer $seg_length
                }
                dict incr layer_wire_count $layer
            }
        }
    }

    puts "Total wire length:  $total_length um"
    puts "Total vias:         $via_count"
    puts ""

    # Metal layer breakdown
    puts "METAL LAYER USAGE:"
    puts [format "  %-10s %-12s %-10s %s" "Layer" "Length(um)" "Segments" "% of Total"]
    puts "  [string repeat - 50]"
    foreach layer [lsort [dict keys $layer_length]] {
        set len [dict get $layer_length $layer]
        set cnt [dict get $layer_wire_count $layer]
        set pct [expr {$total_length > 0 ? ($len / $total_length) * 100.0 : 0.0}]
        puts [format "  %-10s %-12.3f %-10d %.1f%%" $layer $len $cnt $pct]
    }
    puts ""

    # Via breakdown
    if {$via_count > 0} {
        puts "VIA BREAKDOWN:"
        puts [format "  %-15s %s" "Via Layer" "Count"]
        puts "  [string repeat - 30]"
        foreach via_layer [lsort [dict keys $via_layers]] {
            puts [format "  %-15s %d" $via_layer [dict get $via_layers $via_layer]]
        }
        puts ""
    }

    # Driver and receivers
    set driver_pins [dbGet [dbGet -p $net.instTerms.isOutput 1].name]
    set recv_pins [dbGet [dbGet -p $net.instTerms.isInput 1].name]
    puts "Driver:    $driver_pins"
    puts "Receivers: [llength $recv_pins] pins"
    if {[llength $recv_pins] <= 10} {
        foreach pin $recv_pins {
            puts "  - $pin"
        }
    } else {
        for {set i 0} {$i < 5} {incr i} {
            puts "  - [lindex $recv_pins $i]"
        }
        puts "  ... and [expr {[llength $recv_pins] - 5}] more"
    }
    puts "============================================================"
}

# Partition-wide metal usage summary
proc inv_metal_summary {} {
    puts "============================================================"
    puts "PARTITION METAL USAGE SUMMARY"
    puts "============================================================"
    reportRoute -summary
    puts "============================================================"
}

# Congestion report for a region or full chip
proc inv_congestion {{x1 ""} {y1 ""} {x2 ""} {y2 ""}} {
    puts "============================================================"
    puts "CONGESTION REPORT"
    puts "============================================================"
    if {$x1 != ""} {
        puts "Region: ($x1, $y1) - ($x2, $y2)"
        reportCongestion -overflow -direction both \
            -window [list $x1 $y1 $x2 $y2]
    } else {
        puts "Full chip:"
        reportCongestion -overflow -direction both
    }
    puts "============================================================"
}

# Cell utilization report
proc inv_utilization {} {
    puts "============================================================"
    puts "CELL UTILIZATION"
    puts "============================================================"
    reportGateCount -level 1
    puts ""
    reportDesign -physicalStat
    puts "============================================================"
}

# DRC violations summary
proc inv_drc_summary {} {
    puts "============================================================"
    puts "DRC VIOLATIONS SUMMARY"
    puts "============================================================"
    verify_drc -report drc_check.rpt
    puts ""
    puts "Detail report: drc_check.rpt"
    puts "============================================================"
}

# Net query by pattern (find nets matching wildcard)
proc inv_find_nets {pattern {max_results 20}} {
    set nets [dbGet -p top.nets.name $pattern]
    set count [llength $nets]
    puts "Found $count nets matching '$pattern'"
    set show [expr {$count < $max_results ? $count : $max_results}]
    for {set i 0} {$i < $show} {incr i} {
        set net [lindex $nets $i]
        set name [dbGet $net.name]
        set nterms [llength [dbGet $net.instTerms]]
        puts [format "  %-60s  %d pins" $name $nterms]
    }
    if {$count > $max_results} {
        puts "  ... and [expr {$count - $max_results}] more"
    }
}

# Quick distance between two instances
proc inv_inst_distance {inst1 inst2} {
    set loc1 [dbGet [dbGet -p top.insts.name $inst1].pt]
    set loc2 [dbGet [dbGet -p top.insts.name $inst2].pt]
    if {$loc1 == "" || $loc2 == ""} {
        puts "ERROR: Instance not found"
        return
    }
    set x1 [lindex $loc1 0]; set y1 [lindex $loc1 1]
    set x2 [lindex $loc2 0]; set y2 [lindex $loc2 1]
    set dx [expr {abs($x2 - $x1)}]
    set dy [expr {abs($y2 - $y1)}]
    puts "$inst1 @ ($x1, $y1)"
    puts "$inst2 @ ($x2, $y2)"
    puts "Manhattan distance: [expr {$dx + $dy}] um  (dx=$dx, dy=$dy)"
}

puts "=== physical_queries.tcl loaded ==="
puts "Available procs:"
puts "  inv_net_report <net>               Full physical report (metals, vias, length)"
puts "  inv_metal_summary                  Partition-wide metal usage"
puts "  inv_congestion ?x1 y1 x2 y2?      Congestion (region or full chip)"
puts "  inv_utilization                    Cell utilization stats"
puts "  inv_drc_summary                    DRC violations check"
puts "  inv_find_nets <pattern>            Find nets by wildcard"
puts "  inv_inst_distance <inst1> <inst2>  Distance between instances"
puts "========================================="

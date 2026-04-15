#######################################################################
# Clock Balance ECO for miBypLevelM304H registers
#
# Purpose: Reduce Large Clock Skew (LCS) on miBypLevelM304H registers
#          by creating local ICGs near the sink flops.
#          This is the #1 root cause of internal setup failures
#          in par_exe (WNS=-102.8ps, 1,922 LCS paths).
#
# Usage:
#   1. Open CTS ECO design in fc_shell:
#      open_block par_exe -lib apr_fc_cts_eco
#   2. Source this script:
#      source balance_byplevel_clk.tcl
#   3. Run the main proc:
#      balance_byplevel_clk
#   4. Run clock routing:
#      route_group -all_clock_nets
#   5. Run optimization:
#      clock_opt -from final_opto
#   6. Check timing:
#      report_timing -group mclk_exe -max_paths 20
#      report_global_timing
#
# What it does:
#   - Loops over 32 bypass-level groups (2 vec × 2 half × 8 ports)
#   - For each group, creates a NEW local ICG at the center of gravity
#     of the miBypLevelM304H sink registers
#   - Disconnects sinks from old (distant) clock gate
#   - Connects sinks to new local ICG → reduces clock skew
#   - Inserts inverter pair buffer if source ICG is far (>10um)
#   - Sets proper NDR routing rules on new clock nets
#
# Expected impact:
#   - Fixes top 20 worst internal setup paths
#   - Addresses ~1,922 LCS setup violations
#   - Also improves ~30,000 LCS hold violations (same root cause)
#
# Author: sunger (based on analysis of par_exe clock skew)
# Date:   2026-03-22
#######################################################################


#======================================================================
# CONFIGURATION — edit these if cell library names change
#======================================================================
namespace eval ::byplvl_cfg {
    # ICG cell: clock gate with drive strength 8, ULVT
    variable icg_ref "tcbn02p_bwph156pnpnl3p48cpd_base_ulvt_c240429/CKLNQD8BWP156HPNPN3P48CPDULVT"

    # Inverter cell: CKND6 for buffer pair insertion
    variable inv_ref "tcbn02p_bwph156pnpnl3p48cpd_base_ulvt_c240429tt_1p1v_85c_typical_ccs/CKND6BWP156HPNPN3P48CPDULVT"

    # Distance threshold for buffer insertion (um)
    variable buf_threshold 10

    # Legalization moveable distance (um)
    variable legal_dist 5

    # Minimum routing layer for trunk nets
    variable trunk_min_layer M9

    # User attribute name for tracking ECO cells
    variable eco_tag "eco_byplvl_clk"
}


#======================================================================
# HELPER: Calculate center of gravity of a cell collection
#======================================================================
proc byplvl_center_of_gravity {cells} {
    set sum_x 0.0
    set sum_y 0.0
    set count 0

    foreach_in_collection cell $cells {
        set origin [get_attribute $cell origin]
        set sum_x [expr {$sum_x + [lindex $origin 0]}]
        set sum_y [expr {$sum_y + [lindex $origin 1]}]
        incr count
    }

    if {$count > 0} {
        return [list [expr {$sum_x / $count}] [expr {$sum_y / $count}]]
    }
    return [list 0 0]
}


#======================================================================
# HELPER: Manhattan distance between two {x y} locations
#======================================================================
proc byplvl_manhattan {loc1 loc2} {
    set dx [expr {abs([lindex $loc1 0] - [lindex $loc2 0])}]
    set dy [expr {abs([lindex $loc1 1] - [lindex $loc2 1])}]
    return [expr {$dx + $dy}]
}


#======================================================================
# HELPER: Find nearest ICG matching a name pattern within search radius
# Returns the first matching ICG cell, or empty collection if none found
#======================================================================
proc byplvl_find_nearest_icg {pattern cx cy} {
    foreach radius {10 20 40 60 80 100 150} {
        set x_min [expr {$cx - $radius}]
        set y_min [expr {$cy - $radius}]
        set x_max [expr {$cx + $radius}]
        set y_max [expr {$cy + $radius}]
        set box [list [list $x_min $y_min] [list $x_max $y_max]]
        set hits [get_cells -quiet -touching $box \
                    -filter "full_name=~*${pattern}*/*dcszo*"]
        if {[sizeof_collection $hits] > 0} {
            return [index_collection $hits 0]
        }
    }
    return [create_collection]
}


#======================================================================
# HELPER: Place two inverters at 1/3 and 2/3 along the path
# from source to destination (distributes delay evenly)
#======================================================================
proc byplvl_place_inv_pair {inv1 inv2 src_loc dst_loc} {
    set x1 [lindex $src_loc 0]; set y1 [lindex $src_loc 1]
    set x2 [lindex $dst_loc 0]; set y2 [lindex $dst_loc 1]

    # 1/3 point (closer to source)
    set mx1 [expr {$x1 + ($x2 - $x1) / 3.0}]
    set my1 [expr {$y1 + ($y2 - $y1) / 3.0}]

    # 2/3 point (closer to destination)
    set mx2 [expr {$x1 + ($x2 - $x1) * 2.0 / 3.0}]
    set my2 [expr {$y1 + ($y2 - $y1) * 2.0 / 3.0}]

    set_cell_location -coordinates [list $mx1 $my1] $inv1
    set_cell_location -coordinates [list $mx2 $my2] $inv2
}


#======================================================================
# HELPER: Report pre-ECO timing baseline for mclk_exe
#======================================================================
proc byplvl_report_baseline {} {
    puts "\n====== PRE-ECO BASELINE ======"
    puts "Reporting mclk_exe timing before ECO..."
    redirect -variable baseline {
        report_timing -group mclk_exe -max_paths 5 -nosplit
    }
    # Extract WNS from first path
    foreach line [split $baseline "\n"] {
        if {[regexp {slack\s+\(VIOLATED\)\s+([-\d.]+)} $line -> slack]} {
            puts "  Current mclk_exe WNS: ${slack}ps"
            break
        }
    }
    puts "================================\n"
}


#======================================================================
# MAIN: Create local ICGs for all bypass-level register groups
#======================================================================
proc balance_byplevel_clk {} {
    variable ::byplvl_cfg::icg_ref
    variable ::byplvl_cfg::inv_ref
    variable ::byplvl_cfg::buf_threshold
    variable ::byplvl_cfg::legal_dist
    variable ::byplvl_cfg::trunk_min_layer
    variable ::byplvl_cfg::eco_tag

    puts "#####################################################"
    puts "# balance_byplevel_clk — Clock Skew ECO             #"
    puts "# Target: miBypLevelM304H registers (32 groups)     #"
    puts "#####################################################"

    # Report baseline timing
    byplvl_report_baseline

    # Define tracking attribute
    define_user_attribute -quiet -classes cell -type boolean $eco_tag

    set total_icgs  0
    set total_bufs  0
    set total_sinks 0
    set skipped     0

    # ── Loop all 32 bypass-level groups ──
    # Architecture: 2 vectors × 2 halves (high/low) × 8 ports
    foreach vec {0 1} {
        foreach half {h l} {
            foreach port {0 1 2 3 4 5 6 7} {

                set group_id "v${vec}_${half}_p${port}"
                set hier "exe_vec/miv${vec}c/mimxv${vec}${half}c/mimxv0d"

                puts "\n──── Processing group: $group_id ────"

                #──────────────────────────────────────────────
                # Step 1: Collect target flops
                #──────────────────────────────────────────────
                set sinks [get_cells -quiet \
                    ${hier}/miBypLevelM304H_reg_p_${port}*]
                set sink_count [sizeof_collection $sinks]

                if {$sink_count == 0} {
                    puts "  WARN: No sinks found, skipping"
                    incr skipped
                    continue
                }
                puts "  Found $sink_count sink registers"

                #──────────────────────────────────────────────
                # Step 2: Calculate center of gravity
                #──────────────────────────────────────────────
                set cog [byplvl_center_of_gravity $sinks]
                set cx [lindex $cog 0]
                set cy [lindex $cog 1]
                puts "  Center of gravity: ($cx, $cy)"

                #──────────────────────────────────────────────
                # Step 3: Find donor ICG (for E and TE signals)
                # The donor is an existing ICG in the same
                # bypass hierarchy that has the correct enable
                #──────────────────────────────────────────────
                set icg_parent "${hier}/L1_Bypassintdispfor_${port}__core_icg_ClkPortEn303LMH_port__0_"
                set donor_icg [byplvl_find_nearest_icg $icg_parent $cx $cy]

                if {[sizeof_collection $donor_icg] == 0} {
                    puts "  ERROR: No donor ICG found, skipping"
                    incr skipped
                    continue
                }
                puts "  Donor ICG: [get_object_name $donor_icg]"

                # Clone the enable and test-enable connections
                set en_net [get_nets -of [get_pins -of $donor_icg -filter "name==E"]]
                set te_net [get_nets -of [get_pins -of $donor_icg -filter "name==TE"]]

                #──────────────────────────────────────────────
                # Step 4: Find upstream source ICG (clock root)
                # This is the main clock distribution ICG for
                # this vector's clock domain
                #──────────────────────────────────────────────
                set src_icg_pattern "core_icg_Mmiuv${vec}Clk"
                set src_icg [byplvl_find_nearest_icg $src_icg_pattern $cx $cy]

                if {[sizeof_collection $src_icg] == 0} {
                    puts "  ERROR: No source ICG found, skipping"
                    incr skipped
                    continue
                }
                puts "  Source ICG: [get_object_name $src_icg]"

                set src_clk_net [get_nets -of [get_pins -of $src_icg -filter "name==Q"]]

                #──────────────────────────────────────────────
                # Step 5: Create new local ICG
                #──────────────────────────────────────────────
                set new_icg "${icg_parent}/eco_local_icg"

                create_cell $new_icg $icg_ref
                set_cell_location -coordinates [list $cx $cy] $new_icg
                set_attribute [get_cells $new_icg] $eco_tag true

                # Wire up: CP ← source clock, E ← enable, TE ← test enable
                connect_net $src_clk_net [get_pins ${new_icg}/CP]
                connect_net $en_net      [get_pins ${new_icg}/E]
                connect_net $te_net      [get_pins ${new_icg}/TE]

                # Create output net for new ICG
                set out_net "${new_icg}_clk_out"
                create_net $out_net
                connect_net $out_net [get_pins ${new_icg}/Q]

                incr total_icgs
                puts "  Created ICG: $new_icg"

                #──────────────────────────────────────────────
                # Step 6: Reconnect all sinks to new local ICG
                #──────────────────────────────────────────────
                set sink_cps [get_pins -of $sinks -filter "name==CP"]
                disconnect_net $sink_cps
                connect_net $out_net $sink_cps

                set total_sinks [expr {$total_sinks + $sink_count}]
                puts "  Reconnected $sink_count flops to new ICG"

                #──────────────────────────────────────────────
                # Step 7: Insert buffer pair if source is far
                # Inverter pair maintains polarity while
                # distributing delay along the clock path
                #──────────────────────────────────────────────
                set src_loc [get_attribute $src_icg origin]
                set dist [byplvl_manhattan $src_loc [list $cx $cy]]
                puts "  Distance to source ICG: ${dist}um"

                if {$dist > $buf_threshold} {
                    puts "  Inserting inverter pair (dist > ${buf_threshold}um)"

                    set buf_name "eco_inv_${group_id}"
                    insert_buffer -inverter_pair \
                        -lib_cell $inv_ref \
                        -new_cell_names $buf_name \
                        [get_pins ${new_icg}/CP]

                    # The insert_buffer command creates:
                    #   *buf_name   = inv2 (output side)
                    #   *buf_name_1 = inv1 (input side)
                    set inv1 [get_flat_cells *${buf_name}_1]
                    set inv2 [get_flat_cells *${buf_name}]

                    byplvl_place_inv_pair $inv1 $inv2 $src_loc [list $cx $cy]

                    set_attribute $inv1 $eco_tag true
                    set_attribute $inv2 $eco_tag true
                    incr total_bufs 2

                    puts "  Placed inv pair at 1/3 and 2/3 along path"
                }

                #──────────────────────────────────────────────
                # Step 8: Set clock routing rules on new leaf nets
                #──────────────────────────────────────────────
                set leaf_nets [get_flat_nets -quiet \
                    -of [get_clock_tree_pins -to $sink_cps]]
                if {[sizeof_collection $leaf_nets] > 0} {
                    set_routing_rule -rule CLK_Leaves $leaf_nets \
                        -min_layer_mode allow_pin_connection
                }

                puts "  ✓ Group $group_id complete"
            }
        }
    }

    #──────────────────────────────────────────────────────
    # Step 9: Post-ECO finalization
    #──────────────────────────────────────────────────────
    puts "\n──── Finalizing ECO ────"

    set eco_cells [get_flat_cells -quiet -filter $eco_tag]
    set eco_count [sizeof_collection $eco_cells]

    if {$eco_count > 0} {
        # Legalize placement of all new cells
        puts "  Legalizing $eco_count ECO cells..."
        legalize_placement -cells $eco_cells -moveable_distance $legal_dist

        # Lock cells so optimizer doesn't move them
        set_size_only $eco_cells

        # Set NDR on trunk nets (ICG1 → new ICG path)
        set cp_pins [get_pins -of $eco_cells -filter "name==CP"]
        set trunk_nets [get_flat_nets -quiet \
            -of [get_clock_tree_pins -to $cp_pins] \
            -filter "vr_length>20 && full_name!~*mclk_exe*"]

        if {[sizeof_collection $trunk_nets] > 0} {
            set trunk_count [sizeof_collection $trunk_nets]
            puts "  Setting NDR on $trunk_count trunk nets (min layer: $trunk_min_layer)"
            set_routing_rule -rule CLK_Trunk $trunk_nets \
                -min_routing_layer $trunk_min_layer \
                -min_layer_mode allow_pin_connection
            set_attribute $trunk_nets net_type clock
            set_dont_touch $trunk_nets
        }
    }

    #──────────────────────────────────────────────────────
    # Summary
    #──────────────────────────────────────────────────────
    puts "\n╔══════════════════════════════════════════════╗"
    puts "║         CLOCK BALANCE ECO SUMMARY            ║"
    puts "╠══════════════════════════════════════════════╣"
    puts "║  Groups processed: [expr {32 - $skipped}] / 32                    ║"
    puts "║  Groups skipped:   $skipped                              ║"
    puts "║  New ICGs created:  $total_icgs                           ║"
    puts "║  Buffer cells added: $total_bufs                          ║"
    puts "║  Total ECO cells:   $eco_count                           ║"
    puts "║  Sinks reconnected: $total_sinks                         ║"
    puts "╠══════════════════════════════════════════════╣"
    puts "║  NEXT STEPS:                                 ║"
    puts "║  1. route_group -all_clock_nets              ║"
    puts "║  2. clock_opt -from final_opto               ║"
    puts "║  3. report_global_timing                     ║"
    puts "║  4. report_timing -group mclk_exe -max 20    ║"
    puts "╚══════════════════════════════════════════════╝"
}


#======================================================================
# UTILITY: Remove all ECO cells (rollback)
# Use this if something goes wrong and you want to undo
#======================================================================
proc remove_byplevel_eco {} {
    variable ::byplvl_cfg::eco_tag

    set eco_cells [get_flat_cells -quiet -filter $eco_tag]
    set count [sizeof_collection $eco_cells]

    if {$count == 0} {
        puts "No ECO cells found to remove."
        return
    }

    puts "Removing $count ECO cells..."

    # Get all nets created by ECO
    set eco_nets [get_flat_nets -quiet -filter "full_name=~*eco_local_icg*"]

    # Remove cells first, then nets
    remove_cell $eco_cells
    if {[sizeof_collection $eco_nets] > 0} {
        remove_net $eco_nets
    }

    puts "Rollback complete. $count cells removed."
    puts "WARNING: Sink flops are now disconnected from clock!"
    puts "         You must reload the design or reconnect manually."
}


#======================================================================
# UTILITY: Report status of ECO cells
#======================================================================
proc report_byplevel_eco {} {
    variable ::byplvl_cfg::eco_tag

    set eco_cells [get_flat_cells -quiet -filter $eco_tag]
    set count [sizeof_collection $eco_cells]

    puts "\n====== BYPASS LEVEL ECO STATUS ======"
    puts "Total ECO cells: $count"

    if {$count == 0} {
        puts "No ECO cells found."
        return
    }

    # Count by type
    set icg_count 0
    set inv_count 0
    foreach_in_collection c $eco_cells {
        set name [get_object_name $c]
        if {[string match "*eco_local_icg*" $name]} {
            incr icg_count
        } else {
            incr inv_count
        }
    }

    puts "  ICG cells:     $icg_count"
    puts "  Inverter cells: $inv_count"

    # Check legality
    set illegal [get_flat_cells -quiet -filter "$eco_tag && is_placed==false"]
    if {[sizeof_collection $illegal] > 0} {
        puts "  WARNING: [sizeof_collection $illegal] cells not placed!"
    } else {
        puts "  All cells legally placed ✓"
    }

    puts "====================================\n"
}

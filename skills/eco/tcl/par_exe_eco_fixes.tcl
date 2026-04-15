##############################################################################
#  PAR_EXE ECO FIX SCRIPT — Based on master_timing_fix_cookbook.txt
#  PO: atraitel | Generated: 2026-03-22
#  
#  USAGE: Source in FC shell after opening the design
#    fc_shell> source par_exe_eco_fixes.tcl
#
#  IMPORTANT:
#    - Review each section before running
#    - Run report_timing BEFORE and AFTER each fix to verify improvement
#    - Comment out sections you don't want to apply
#    - Paths/cells are TEMPLATES — verify against actual design
##############################################################################


##############################################################################
# HELPER PROCS
##############################################################################

proc rpt {args} {
    # Quick report_timing wrapper
    eval report_timing -max_paths 5 -nosplit $args
}

proc rpt_slack {from to} {
    # Report just the WNS for a specific path
    set paths [get_timing_paths -from $from -to $to -max_paths 1]
    if {[sizeof_collection $paths] > 0} {
        set slack [get_attribute [index_collection $paths 0] slack]
        puts "  Slack: ${slack}ps"
        return $slack
    } else {
        puts "  No path found"
        return "N/A"
    }
}

proc check_vt {cell_name} {
    # Check current Vt of a cell
    set cells [get_cells $cell_name]
    if {[sizeof_collection $cells] > 0} {
        set ref [get_attribute $cells ref_name]
        if {[regexp {ULVTLL} $ref]} { return "ULVTLL" }
        if {[regexp {ULVT} $ref]} { return "ULVT" }
        if {[regexp {LVT} $ref]} { return "LVT" }
        return "UNKNOWN"
    }
    return "NOT_FOUND"
}

proc swap_vt_faster {cell_name} {
    # Swap cell to faster Vt: LVT→ULVTLL→ULVT
    # Cookbook technique C3
    set cells [get_cells $cell_name]
    foreach_in_collection c $cells {
        set ref [get_attribute $c ref_name]
        set new_ref $ref
        if {[regexp {LVT} $ref] && ![regexp {ULVT} $ref]} {
            # LVT → ULVTLL
            regsub {LVT} $new_ref {ULVTLL} new_ref
        } elseif {[regexp {ULVTLL} $ref]} {
            # ULVTLL → ULVT (remove the LL)
            regsub {ULVTLL} $new_ref {ULVT} new_ref
        }
        if {$new_ref ne $ref} {
            puts "  Vt swap: [get_attribute $c full_name]"
            puts "    $ref → $new_ref"
            size_cell $c $new_ref
        }
    }
}

proc upsize_cell {cell_name} {
    # Upsize cell to next drive strength: D2→D4, D4→D8, etc.
    # Cookbook technique C1
    set cells [get_cells $cell_name]
    foreach_in_collection c $cells {
        set ref [get_attribute $c ref_name]
        set new_ref $ref
        if {[regexp {D1BWP} $ref]} {
            regsub {D1BWP} $new_ref {D2BWP} new_ref
        } elseif {[regexp {D2BWP} $ref]} {
            regsub {D2BWP} $new_ref {D4BWP} new_ref
        } elseif {[regexp {D4BWP} $ref]} {
            regsub {D4BWP} $new_ref {D8BWP} new_ref
        } elseif {[regexp {D8BWP} $ref]} {
            regsub {D8BWP} $new_ref {D16BWP} new_ref
        }
        if {$new_ref ne $ref} {
            puts "  Upsize: [get_attribute $c full_name]"
            puts "    $ref → $new_ref"
            size_cell $c $new_ref
        }
    }
}


##############################################################################
# P1: rsrealdispm304h (-77ps) | meu → exe
# Cookbook: C1 (upsize) + C3 (Vt swap) + E1 (useful skew)
# NOTE: PO already working on data305 — coordinate!
##############################################################################
puts "\n========== P1: rsrealdispm304h (-77ps) =========="

# Step 1: Check current slack
# rpt -to [get_ports *rsintrealdispm304h*]

# Step 2: Find receiver cells and their Vt
# set rx_cells [get_cells -of [all_fanout -from [get_ports *rsintrealdispm304h*] -endpoints_only -flat]]
# foreach_in_collection c $rx_cells { puts "[get_attribute $c full_name] [get_attribute $c ref_name]" }

# Step 3: Vt swap on receiver cone (C3)
# swap_vt_faster [get_cells <receiver_cell_path>]

# Step 4: Upsize driver cells (C1)
# upsize_cell [get_cells <driver_cell_path>]


##############################################################################
# P2: mistdatam3n6h (-68ps) | exe → meu | UNTRACKED — 610 paths!
# Cookbook: C1 + C3 + C4 (insert buffer) + E1 (useful skew)
##############################################################################
puts "\n========== P2: mistdatam3n6h (-68ps) =========="

# Step 1: Check current slack — this is exe→meu, source is in exe
# rpt -from [get_cells exe_vec/siu/*/*/*mistdatam3n6h*/D*] -to [get_ports *mistdatam3n6h*]
# rpt -through [get_ports *mistdatam3n6h*]

# Step 2: Find the critical path cells
# set worst [get_timing_paths -from *mistdatam3n6h* -to [get_ports *mistdatam3n6h*] -max_paths 1]
# set path_cells [get_attribute $worst cells]

# Step 3: Vt swap LVT→ULVT on data path cells (C3)
# foreach_in_collection c $path_cells {
#     set vt [check_vt $c]
#     if {$vt eq "LVT" || $vt eq "ULVTLL"} { swap_vt_faster $c }
# }

# Step 4: Upsize small-drive cells on critical path (C1)
# foreach_in_collection c $path_cells {
#     set ref [get_attribute $c ref_name]
#     if {[regexp {D[12]BWP} $ref]} { upsize_cell $c }
# }


##############################################################################
# P3: rsvecsbidm301h (-60ps) | ooo_vec → exe → meu | FIX_PENDING
# Multi-partition FEEDTHRU — check FEEDTHRU buffer chain
# Cookbook: C1 + C3 + C5 (remove excess buffers)
##############################################################################
puts "\n========== P3: rsvecsbidm301h (-60ps) =========="

# Step 1: Check FEEDTHRU chain
# rpt -through [get_ports *RSVecSBIDM301H*FEEDTHRU*]

# Step 2: Find FEEDTHRU buffers — are there excess?
# set feedthru_bufs [get_cells *FEEDTHRU* -filter "ref_name=~*BUF*"]
# foreach_in_collection b $feedthru_bufs {
#     puts "[get_attribute $b full_name] drive=[get_attribute $b ref_name]"
# }

# Step 3: Upsize FEEDTHRU buffers (C1)
# upsize_cell [get_cells *RSVecSBIDM301H*FEEDTHRU*BUF*]

# Step 4: Vt swap FEEDTHRU buffers (C3)
# swap_vt_faster [get_cells *RSVecSBIDM301H*FEEDTHRU*BUF*]


##############################################################################
# P4: deponld_v2im303h (-57ps) | exe → meu | UNTRACKED
# Cookbook: C1 + C3 + E1
##############################################################################
puts "\n========== P4: deponld_v2im303h (-57ps) =========="

# rpt -to [get_ports *deponld_v2im303h*]
# Step 1: Identify source FF and its clock
# Step 2: Vt swap + upsize on source cone
# Step 3: Consider E1 useful skew if >30ps gap after ECO


##############################################################################
# P5: rsvecldprfwrcancelm805h (-57ps) | meu → exe | UNTRACKED
# Cookbook: C1 + C3 + E1 (receiver side)
##############################################################################
puts "\n========== P5: rsvecldprfwrcancelm805h (-57ps) =========="

# rpt -from [get_ports *rsvecldprfwrcancelm805h*]
# Receiver path — upsize + Vt swap on first few levels of receiver logic


##############################################################################
# P6: rsvecldportwritemuxctlm805h (-52ps) | meu → exe | UNTRACKED
# NEW regression from WW12C — investigate what changed
# Cookbook: C1 + C3 + E1
##############################################################################
puts "\n========== P6: rsvecldportwritemuxctlm805h (-52ps) =========="

# rpt -from [get_ports *rsvecldportwritemuxctlm805h*]


##############################################################################
# P7: gatherelmidm805h (-51ps) | meu → exe | FIX_PENDING
# 2 SIO2PO HSDs in sign_off — follow up!
# Cookbook: C1 + C3 + E1
##############################################################################
puts "\n========== P7: gatherelmidm805h (-51ps) =========="

# rpt -from [get_ports *gatherelmidm805h*]


##############################################################################
# BATCH: shuf2vfpp* family (exe → fmav0/fmav1) — 5 signals, 100K+ paths
# These are massive fanout shuffle buses
# Cookbook: C3 (Vt swap) is safest for high-fanout
##############################################################################
puts "\n========== BATCH: shuf2vfpp* family =========="

# Step 1: Identify the shuf mux cells
# set shuf_cells [get_cells exe_vec/shuf/*/*/shuf2vfpp*]
# puts "Shuf cells: [sizeof_collection $shuf_cells]"

# Step 2: Check Vt distribution
# set lvt_count 0; set ulvtll_count 0; set ulvt_count 0
# foreach_in_collection c $shuf_cells {
#     set vt [check_vt $c]
#     if {$vt eq "LVT"} { incr lvt_count }
#     if {$vt eq "ULVTLL"} { incr ulvtll_count }
#     if {$vt eq "ULVT"} { incr ulvt_count }
# }
# puts "LVT=$lvt_count ULVTLL=$ulvtll_count ULVT=$ulvt_count"

# Step 3: Swap LVT/ULVTLL → ULVT on shuf drivers (C3)
# WARNING: Test on shuf2vfpp7v0 first, then apply to others
# foreach_in_collection c $shuf_cells {
#     set vt [check_vt $c]
#     if {$vt ne "ULVT"} { swap_vt_faster $c }
# }


##############################################################################
# USEFUL SKEW TEMPLATE (E1) — apply to any path needing clock adjustment
# Use after C1+C3 if still >20ps gap
##############################################################################

# proc apply_useful_skew {endpoint_ff skew_ps} {
#     # Positive skew = delay capture clock = more setup margin
#     set clk_pin [get_pins -of $endpoint_ff -filter "is_clock_pin"]
#     set_clock_latency -late $skew_ps $clk_pin
#     puts "  Applied ${skew_ps}ps useful skew to [get_attribute $endpoint_ff full_name]"
# }


##############################################################################
# POST-ECO VERIFICATION
##############################################################################
puts "\n========== POST-ECO CHECKS =========="
puts "Run these after applying fixes:"
puts "  1. report_timing -to \[get_ports *rsintrealdispm304h*\] -max_paths 3"
puts "  2. report_timing -to \[get_ports *mistdatam3n6h*\] -max_paths 3"
puts "  3. report_constraint -all_violators -max_paths 10"
puts "  4. check_legality"
puts "  5. route_eco  ;# cleanup routing after cell changes"
puts ""
puts "Done loading par_exe_eco_fixes.tcl"

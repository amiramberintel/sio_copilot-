#######################################################################
# Shifter Data Path ECO Fix — par_exe Internal Paths
#
# Target:  278 paths in the -50ps to -46.5ps slack range
#          These are M305H→M305H data path violations through
#          the shifter/ALU/shuffle logic
#
# Based on: master_timing_fix_cookbook.txt (Mode 1 — ECO techniques)
#           Avi's PO WA: apr_fc_cts_eco, clock_route_opt stage
#
# Strategy:
#   1. C3 — Vt swap: LVT/ULVTLL → ULVT on critical data path cells
#   2. C1 — Upsize: D1/D2 → D4, D4 → D8 on weak drivers
#   3. C4 — Insert buffer on long nets between shifter stages
#   4. C5 — Remove unnecessary buffers in over-buffered paths
#
# Usage:
#   1. Open CTS ECO design in fc_shell
#   2. source fix_shifter_datapath.tcl
#   3. SAFE preview:         preview_shifter_fix   ← no changes!
#   4. Capture baseline:     snapshot_timing BEFORE
#   5. Run Vt swap:          fix_shifter_vt_swap
#   6. Run upsizing:         fix_shifter_upsize
#   7. Run buffer insert:    fix_shifter_buffers
#   8. Finalize:             finalize_shifter_eco
#   9. Capture after:        snapshot_timing AFTER
#  10. Compare:              compare_before_after
#  11. Full report:          generate_eco_report
#
# Author: sunger
# Date:   2026-03-22
#######################################################################


#======================================================================
# CONFIGURATION
#======================================================================
namespace eval ::shf_cfg {
    # Target hierarchy blocks (shifter/ALU/shuffle)
    variable target_blocks {
        exe_vec/siu/sishiftalup0v0
        exe_vec/siu/sishiftalup0v1
        exe_vec/siu/sishiftalup1v0
        exe_vec/siu/sishiftalup1v1
        exe_vec/siu/sishiftalup4v0
        exe_vec/siu/sishiftalup4v1
        exe_vec/siu/sishiftalup5v0
        exe_vec/siu/sishiftalup5v1
        exe_vec/shuf/shufp2v0c
        exe_vec/shuf/shufp3v0c
        exe_vec/shuf/shufp3v1c
        exe_vec/shuf/shufp6v0c
        exe_vec/shuf/shufp6v1c
        exe_vec/shuf/shufp7v0c
        exe_vec/shuf/shufp7v1c
    }

    # Startpoint register patterns (the bottleneck sources)
    variable sp_patterns {
        */ShufS1dataM305H_reg*
        */ShufS2dataM305H_reg*
        */noninvsource1M305H_reg*
        */noninvsource2M305H_reg*
        */invsource1M305H_reg*
        */invsource2M305H_reg*
        */sis2dataM305H_reg*
        */addercin0M305H_reg*
        */IsPintMultiShiftqbM305H_reg*
    }

    # Endpoint register patterns (where violations land)
    variable ep_patterns {
        */siSrcDataM305H_reg*
        */sis1dataM305H_reg*
        */sis2dataM305H_reg*
        */sis3dataM305H_reg*
        */shufS2dataM305H_reg*
        */ShufS1dataM305H_reg*
        */ShufS2dataM305H_reg*
    }

    # Legal Vt swap targets (cookbook C3)
    # SAFE: LVT → ULVT, ULVTLL → ULVT
    variable vt_swap_map {
        CPDLVT    CPDULVT
        CPDULVTLL CPDULVT
    }

    # Minimum drive strengths (cookbook C1)
    # Cells below these are upsized
    variable min_drive_map {
        D1  D4
        D2  D4
        D3  D4
        D4  D8
    }

    # Buffer cell for insertion (cookbook C4)
    variable buf_ref "tcbn02p_bwph156pnpnl3p48cpd_base_ulvt_c240429/BUFFD4BWP156HPNPN3P48CPDULVT"

    # Illegal cell check file
    variable illegal_file ""

    # ECO tracking attribute
    variable eco_tag "eco_shifter_fix"

    # Slack threshold — only fix paths worse than this
    variable slack_threshold -46.5

    # Max transition threshold (ps) — flag cells above this
    variable max_tran_threshold 15.0
}


#======================================================================
# STEP 0: ANALYZE — Report current state of shifter paths
# Run this FIRST to understand what needs fixing
#======================================================================
proc analyze_shifter_paths {} {
    variable ::shf_cfg::target_blocks
    variable ::shf_cfg::slack_threshold

    puts "\n╔══════════════════════════════════════════════════════════╗"
    puts "║  SHIFTER DATA PATH ANALYSIS                             ║"
    puts "╚══════════════════════════════════════════════════════════╝\n"

    # Report worst paths through shifter blocks
    foreach block $target_blocks {
        set cells [get_cells -quiet ${block}/*]
        if {[sizeof_collection $cells] == 0} { continue }

        # Get timing through this block
        redirect -variable rpt {
            report_timing -through $cells -max_paths 3 \
                -group mclk_exe -nosplit -input_pins
        }

        # Extract WNS
        set wns "met"
        foreach line [split $rpt "\n"] {
            if {[regexp {slack\s+\(VIOLATED\)\s+([-\d.]+)} $line -> s]} {
                set wns $s
                break
            }
        }
        set short_block [lindex [split $block /] end-1]/[lindex [split $block /] end]
        puts "  $short_block: WNS = $wns"
    }

    # Overall mclk_exe status
    puts "\n  ── Overall mclk_exe ──"
    redirect -variable overall {
        report_qor -group mclk_exe -nosplit
    }
    foreach line [split $overall "\n"] {
        if {[regexp {Critical Path Slack|Total Negative Slack|Violating Paths} $line]} {
            puts "  $line"
        }
    }
}


#======================================================================
# STEP 1: VT SWAP — Change LVT/ULVTLL → ULVT on data path
# Cookbook technique C3: ~2-3ps gain per cell
#======================================================================
proc fix_shifter_vt_swap {} {
    variable ::shf_cfg::target_blocks
    variable ::shf_cfg::eco_tag
    variable ::shf_cfg::slack_threshold

    puts "\n╔══════════════════════════════════════════════════════════╗"
    puts "║  STEP 1: VT SWAP (C3) — LVT/ULVTLL → ULVT             ║"
    puts "╚══════════════════════════════════════════════════════════╝\n"

    define_user_attribute -quiet -classes cell -type boolean $eco_tag

    set total_swapped 0
    set total_checked 0

    foreach block $target_blocks {
        set block_swapped 0

        # Get all cells in this block that are on failing timing paths
        set failing_eps [get_pins -quiet ${block}/*M305H*/D -filter "setup_slack < $slack_threshold"]
        if {[sizeof_collection $failing_eps] == 0} {
            # Also check through cells (combinational)
            set failing_eps [get_cells -quiet ${block}/* \
                -filter "ref_name=~*LVT* || ref_name=~*ULVTLL*"]
        }

        # Get cells on critical paths through this block
        # Collect all cells that are LVT or ULVTLL
        set lvt_cells [get_cells -quiet ${block}/* \
            -filter "ref_name=~*CPDLVT* && !ref_name=~*CPDULVT*"]
        set ulvtll_cells [get_cells -quiet ${block}/* \
            -filter "ref_name=~*CPDULVTLL*"]

        set swap_candidates [add_to_collection $lvt_cells $ulvtll_cells]

        foreach_in_collection cell $swap_candidates {
            incr total_checked
            set ref [get_attribute $cell ref_name]
            set cell_name [get_object_name $cell]

            # Check if cell is on a failing timing path
            set pins [get_pins -quiet -of $cell -filter "name=~Z* || name=~Q*"]
            set on_critical 0
            foreach_in_collection p $pins {
                redirect -variable slack_rpt {
                    report_timing -through $p -max_paths 1 \
                        -group mclk_exe -nosplit 2>/dev/null
                }
                if {[regexp {slack\s+\(VIOLATED\)\s+([-\d.]+)} $slack_rpt -> s]} {
                    if {$s < $slack_threshold} {
                        set on_critical 1
                        break
                    }
                }
            }

            if {!$on_critical} { continue }

            # Determine new ref (swap Vt)
            set new_ref $ref
            if {[regsub {CPDULVTLL} $new_ref {CPDULVT} new_ref]} {
                # ULVTLL → ULVT swap
            } elseif {[regsub {CPDLVT} $new_ref {CPDULVT} new_ref]} {
                # LVT → ULVT swap (but not ULVT → ULVTULVT)
                # Make sure we didn't double-swap
                if {[string match "*ULVTULVT*" $new_ref]} {
                    continue
                }
            } else {
                continue
            }

            # Perform the swap
            puts "  VT_SWAP: $cell_name"
            puts "    OLD: $ref"
            puts "    NEW: $new_ref"
            size_cell $cell_name $new_ref
            set_attribute $cell $eco_tag true
            incr block_swapped
            incr total_swapped
        }

        if {$block_swapped > 0} {
            set short [lindex [split $block /] end-1]/[lindex [split $block /] end]
            puts "  [$short]: $block_swapped cells swapped"
        }
    }

    puts "\n  ── VT SWAP SUMMARY ──"
    puts "  Cells checked:  $total_checked"
    puts "  Cells swapped:  $total_swapped"
    puts "  Expected gain:  ~[expr {$total_swapped * 2.5}]ps total"
}


#======================================================================
# STEP 2: UPSIZE — Increase drive strength of weak cells
# Cookbook technique C1: ~2-5ps gain per cell
#======================================================================
proc fix_shifter_upsize {} {
    variable ::shf_cfg::target_blocks
    variable ::shf_cfg::eco_tag
    variable ::shf_cfg::slack_threshold
    variable ::shf_cfg::max_tran_threshold

    puts "\n╔══════════════════════════════════════════════════════════╗"
    puts "║  STEP 2: UPSIZE (C1) — Increase drive strength          ║"
    puts "╚══════════════════════════════════════════════════════════╝\n"

    define_user_attribute -quiet -classes cell -type boolean $eco_tag

    set total_upsized 0

    foreach block $target_blocks {
        # Find cells with high output transition (sign of weak driver)
        set all_cells [get_cells -quiet ${block}/* \
            -filter "is_hierarchical==false && ref_name=~*BWP*"]

        foreach_in_collection cell $all_cells {
            set ref [get_attribute $cell ref_name]
            set cell_name [get_object_name $cell]

            # Check if cell has weak drive strength (D1 or D2)
            set is_weak 0
            set new_ref $ref
            if {[regexp {([A-Z]+[A-Z0-9]*)D([12])BWP} $ref -> func drv]} {
                set is_weak 1
                # D1/D2 → D4
                regsub "D${drv}BWP" $new_ref "D4BWP" new_ref
            }

            if {!$is_weak} { continue }

            # Verify cell is on failing path
            set out_pins [get_pins -quiet -of $cell -filter "direction==out"]
            set on_critical 0
            foreach_in_collection p $out_pins {
                # Check transition
                set tran [get_attribute -quiet $p max_rise_transition]
                if {$tran == "" || $tran == "INFINITY"} { continue }
                if {$tran > $max_tran_threshold} {
                    set on_critical 1
                    break
                }
            }

            if {!$on_critical} { continue }

            puts "  UPSIZE: $cell_name"
            puts "    OLD: $ref (D${drv})"
            puts "    NEW: $new_ref (D4)"
            size_cell $cell_name $new_ref
            set_attribute $cell $eco_tag true
            incr total_upsized
        }
    }

    puts "\n  ── UPSIZE SUMMARY ──"
    puts "  Cells upsized:    $total_upsized"
    puts "  Expected gain:    ~[expr {$total_upsized * 3}]ps total"
}


#======================================================================
# STEP 3: BUFFER INSERTION — Add buffers on long nets
# Cookbook technique C4: ~5-15ps gain per buffer
#======================================================================
proc fix_shifter_buffers {} {
    variable ::shf_cfg::target_blocks
    variable ::shf_cfg::eco_tag
    variable ::shf_cfg::buf_ref

    puts "\n╔══════════════════════════════════════════════════════════╗"
    puts "║  STEP 3: BUFFER INSERT (C4) — Long wire buffering       ║"
    puts "╚══════════════════════════════════════════════════════════╝\n"

    define_user_attribute -quiet -classes cell -type boolean $eco_tag

    set total_buffers 0

    foreach block $target_blocks {
        # Find nets with high wire delay (long nets between stages)
        set nets [get_nets -quiet ${block}/* \
            -filter "vr_length > 50"]

        foreach_in_collection net $nets {
            set net_name [get_object_name $net]
            set length [get_attribute $net vr_length]

            # Get driver and sink
            set driver_pin [get_pins -quiet -of $net -filter "direction==out"]
            set sink_pins  [get_pins -quiet -of $net -filter "direction==in"]
            set fanout [sizeof_collection $sink_pins]

            if {[sizeof_collection $driver_pin] == 0} { continue }
            if {$fanout == 0} { continue }

            # Check if any sink is on a failing path
            set on_critical 0
            set worst_sink ""
            foreach_in_collection sp $sink_pins {
                redirect -variable srpt {
                    report_timing -through $sp -max_paths 1 \
                        -group mclk_exe -nosplit 2>/dev/null
                }
                if {[regexp {slack\s+\(VIOLATED\)\s+([-\d.]+)} $srpt -> s]} {
                    if {$s < -46.5} {
                        set on_critical 1
                        set worst_sink $sp
                        break
                    }
                }
            }

            if {!$on_critical} { continue }

            puts "  BUFFER: $net_name (length: ${length}um, fanout: $fanout)"

            # Insert buffer at the worst sink
            set buf_name "eco_shf_buf_[incr total_buffers]"
            set new_buf [insert_buffer $worst_sink $buf_ref \
                -new_cell_name $buf_name]
            set_attribute [get_cells $buf_name] $eco_tag true

            # Place buffer at midpoint between driver and sink
            set drv_loc [get_attribute [get_cells -of $driver_pin] origin]
            set snk_loc [get_attribute [get_cells -of $worst_sink] origin]
            set mx [expr {([lindex $drv_loc 0] + [lindex $snk_loc 0]) / 2.0}]
            set my [expr {([lindex $drv_loc 1] + [lindex $snk_loc 1]) / 2.0}]
            set_cell_location -coordinates [list $mx $my] $buf_name

            puts "    Placed at ($mx, $my)"
        }
    }

    puts "\n  ── BUFFER SUMMARY ──"
    puts "  Buffers inserted:  $total_buffers"
    puts "  Expected gain:     ~[expr {$total_buffers * 8}]ps total"
}


#======================================================================
# STEP 4: BATCH AUTO-FIX — Let FC handle remaining paths
# This uses FC's built-in ECO fixer for paths still failing
#======================================================================
proc fix_shifter_auto {} {
    variable ::shf_cfg::slack_threshold
    variable ::shf_cfg::target_blocks

    puts "\n╔══════════════════════════════════════════════════════════╗"
    puts "║  STEP 4: AUTO ECO FIX (remaining paths)                 ║"
    puts "╚══════════════════════════════════════════════════════════╝\n"

    # Collect all endpoints in target blocks that still fail
    set target_eps [list]
    foreach block $target_blocks {
        set eps [get_pins -quiet ${block}/*M305H*/D]
        if {[sizeof_collection $eps] > 0} {
            lappend target_eps $eps
        }
    }

    puts "  Running set_fix_eco_timing on shifter endpoints..."
    puts "  Slack target: ${slack_threshold}ps"

    # FC auto-fix: upsize + Vt swap + buffer on remaining violations
    set_fix_eco_timing \
        -type setup \
        -methods {size_cell insert_buffer} \
        -slack_lesser_than $slack_threshold

    puts "  Auto-fix complete. Check timing with:"
    puts "    report_timing -group mclk_exe -max_paths 50"
}


#======================================================================
# FINALIZE: Legalize, route, and report
#======================================================================
proc finalize_shifter_eco {} {
    variable ::shf_cfg::eco_tag

    puts "\n╔══════════════════════════════════════════════════════════╗"
    puts "║  FINALIZE: Legalize + Route + Report                    ║"
    puts "╚══════════════════════════════════════════════════════════╝\n"

    set eco_cells [get_flat_cells -quiet -filter $eco_tag]
    set count [sizeof_collection $eco_cells]

    if {$count == 0} {
        puts "  No ECO cells found. Nothing to finalize."
        return
    }

    # Legalize placement
    puts "  Legalizing $count ECO cells..."
    legalize_placement -cells $eco_cells -moveable_distance 5

    # Route ECO changes
    puts "  Running route_eco..."
    route_eco

    # Report timing
    puts "\n  ── POST-ECO TIMING ──"
    redirect -variable post_rpt {
        report_timing -group mclk_exe -max_paths 10 -nosplit
    }

    set post_wns "N/A"
    foreach line [split $post_rpt "\n"] {
        if {[regexp {slack\s+\(VIOLATED\)\s+([-\d.]+)} $line -> s]} {
            set post_wns $s
            break
        }
    }

    # Report QoR
    redirect -variable qor {
        report_qor -group mclk_exe -nosplit
    }
    set nvp "N/A"; set tns "N/A"
    foreach line [split $qor "\n"] {
        if {[regexp {Total Negative Slack:\s+([-\d.]+)} $line -> t]} { set tns $t }
        if {[regexp {No. of Violating Paths:\s+(\d+)} $line -> n]} { set nvp $n }
    }

    puts "\n╔══════════════════════════════════════════════════════════╗"
    puts "║  SHIFTER ECO RESULTS                                    ║"
    puts "╠══════════════════════════════════════════════════════════╣"
    puts "║  ECO cells:        $count                               "
    puts "║  mclk_exe WNS:     ${post_wns}ps                       "
    puts "║  mclk_exe TNS:     ${tns}ps                             "
    puts "║  mclk_exe NVP:     $nvp                                 "
    puts "╠══════════════════════════════════════════════════════════╣"
    puts "║  NEXT: report_global_timing                             ║"
    puts "║        report_constraints -max_transition -all_violators║"
    puts "╚══════════════════════════════════════════════════════════╝"
}


#======================================================================
# UTILITY: Rollback all shifter ECO changes
#======================================================================
proc remove_shifter_eco {} {
    variable ::shf_cfg::eco_tag

    set eco_cells [get_flat_cells -quiet -filter $eco_tag]
    set count [sizeof_collection $eco_cells]

    if {$count == 0} {
        puts "No shifter ECO cells found."
        return
    }

    puts "WARNING: Removing $count ECO cells..."
    puts "  This will undo Vt swaps, upsizes, and buffer insertions."
    puts "  You should reload the design after rollback."

    # For buffers: remove them
    set buf_cells [get_flat_cells -quiet -filter "$eco_tag && ref_name=~*BUFF*"]
    if {[sizeof_collection $buf_cells] > 0} {
        foreach_in_collection bc $buf_cells {
            remove_buffer $bc
        }
    }

    puts "  Rollback complete. Reload design to fully revert size/Vt changes."
}


#======================================================================
# UTILITY: Quick report of what would be fixed
#======================================================================
proc preview_shifter_fix {} {
    variable ::shf_cfg::target_blocks

    puts "\n  ── PREVIEW: Cells eligible for ECO ──\n"

    set total_lvt 0; set total_ulvtll 0; set total_weak 0

    foreach block $target_blocks {
        set lvt [sizeof_collection [get_cells -quiet ${block}/* \
            -filter "ref_name=~*CPDLVT* && !ref_name=~*CPDULVT*"]]
        set ulvtll [sizeof_collection [get_cells -quiet ${block}/* \
            -filter "ref_name=~*CPDULVTLL*"]]
        set weak [sizeof_collection [get_cells -quiet ${block}/* \
            -filter "ref_name=~*D1BWP* || ref_name=~*D2BWP*"]]

        set total_lvt [expr {$total_lvt + $lvt}]
        set total_ulvtll [expr {$total_ulvtll + $ulvtll}]
        set total_weak [expr {$total_weak + $weak}]

        set short [lindex [split $block /] end-1]/[lindex [split $block /] end]
        if {$lvt > 0 || $ulvtll > 0 || $weak > 0} {
            puts [format "  %-40s  LVT:%4d  ULVTLL:%4d  Weak(D1/D2):%4d" \
                $short $lvt $ulvtll $weak]
        }
    }

    puts "\n  ── TOTALS ──"
    puts "  LVT cells (→ULVT):        $total_lvt   (gain: ~[expr {$total_lvt * 2.5}]ps)"
    puts "  ULVTLL cells (→ULVT):     $total_ulvtll (gain: ~[expr {$total_ulvtll * 2}]ps)"
    puts "  Weak drive (D1/D2→D4):    $total_weak  (gain: ~[expr {$total_weak * 3}]ps)"
    puts ""
    puts "  Run order:"
    puts "    1. preview_shifter_fix       ← YOU ARE HERE (safe, no changes)"
    puts "    2. snapshot_timing BEFORE     — capture baseline"
    puts "    3. fix_shifter_vt_swap        — swap LVT/ULVTLL→ULVT"
    puts "    4. fix_shifter_upsize         — upsize D1/D2→D4"
    puts "    5. fix_shifter_buffers        — buffer long nets"
    puts "    6. finalize_shifter_eco       — legalize + route + report"
    puts "    7. snapshot_timing AFTER      — capture post-ECO"
    puts "    8. compare_before_after       — show delta"
    puts "    9. generate_eco_report        — full summary to file"
}


#======================================================================
# TIMING SNAPSHOT — Capture timing state at a given point
# Usage: snapshot_timing BEFORE  (or AFTER)
# Stores results in global arrays for comparison
#======================================================================
proc snapshot_timing {label} {
    variable ::shf_cfg::target_blocks

    puts "\n╔══════════════════════════════════════════════════════════╗"
    puts "║  SNAPSHOT: $label                                       "
    puts "╚══════════════════════════════════════════════════════════╝\n"

    # --- Global timing ---
    redirect -variable grpt {
        report_global_timing -nosplit
    }

    set wns_r2r "N/A"; set tns_r2r "N/A"; set nvp_r2r "N/A"
    set wns_tot "N/A"; set tns_tot "N/A"; set nvp_tot "N/A"

    set in_setup 0
    foreach line [split $grpt "\n"] {
        if {[string match "*Setup violations*" $line]} { set in_setup 1 }
        if {$in_setup && [regexp {^WNS\s+([-\d.]+)\s+([-\d.]+)} $line -> tot r2r]} {
            set wns_tot $tot; set wns_r2r $r2r
        }
        if {$in_setup && [regexp {^TNS\s+([-\d.]+)\s+([-\d.]+)} $line -> tot r2r]} {
            set tns_tot $tot; set tns_r2r $r2r
        }
        if {$in_setup && [regexp {^NUM\s+(\d+)\s+(\d+)} $line -> tot r2r]} {
            set nvp_tot $tot; set nvp_r2r $r2r
            set in_setup 0
        }
    }

    # Store in global
    global snap_data
    set snap_data(${label},wns_r2r) $wns_r2r
    set snap_data(${label},tns_r2r) $tns_r2r
    set snap_data(${label},nvp_r2r) $nvp_r2r
    set snap_data(${label},wns_tot) $wns_tot
    set snap_data(${label},tns_tot) $tns_tot
    set snap_data(${label},nvp_tot) $nvp_tot

    # --- mclk_exe group timing ---
    redirect -variable mrpt {
        report_qor -group mclk_exe -nosplit
    }
    set mclk_wns "N/A"; set mclk_tns "N/A"; set mclk_nvp "N/A"
    foreach line [split $mrpt "\n"] {
        if {[regexp {Critical Path Slack:\s+([-\d.]+)} $line -> s]} { set mclk_wns $s }
        if {[regexp {Total Negative Slack:\s+([-\d.]+)} $line -> t]} { set mclk_tns $t }
        if {[regexp {No. of Violating Paths:\s+(\d+)} $line -> n]}  { set mclk_nvp $n }
    }
    set snap_data(${label},mclk_wns) $mclk_wns
    set snap_data(${label},mclk_tns) $mclk_tns
    set snap_data(${label},mclk_nvp) $mclk_nvp

    # --- Cell counts (Vt distribution) ---
    set ulvt_cnt 0; set lvt_cnt 0; set ulvtll_cnt 0
    foreach block $target_blocks {
        incr ulvt_cnt [sizeof_collection [get_cells -quiet ${block}/* \
            -filter "ref_name=~*CPDULVT* && !ref_name=~*CPDULVTLL*"]]
        incr lvt_cnt [sizeof_collection [get_cells -quiet ${block}/* \
            -filter "ref_name=~*CPDLVT* && !ref_name=~*CPDULVT*"]]
        incr ulvtll_cnt [sizeof_collection [get_cells -quiet ${block}/* \
            -filter "ref_name=~*CPDULVTLL*"]]
    }
    set snap_data(${label},ulvt)   $ulvt_cnt
    set snap_data(${label},lvt)    $lvt_cnt
    set snap_data(${label},ulvtll) $ulvtll_cnt

    # --- Per-block worst slack ---
    set block_data [list]
    foreach block $target_blocks {
        set cells [get_cells -quiet ${block}/*]
        if {[sizeof_collection $cells] == 0} { continue }
        redirect -variable brpt {
            report_timing -through $cells -max_paths 1 \
                -group mclk_exe -nosplit 2>/dev/null
        }
        set bwns "met"
        foreach line [split $brpt "\n"] {
            if {[regexp {slack\s+\(VIOLATED\)\s+([-\d.]+)} $line -> s]} {
                set bwns $s; break
            }
        }
        set short [lindex [split $block /] end-1]/[lindex [split $block /] end]
        lappend block_data [list $short $bwns]
        set snap_data(${label},block,$short) $bwns
    }

    # --- Print snapshot ---
    puts "  ┌─────────────────────────────────────────────────────┐"
    puts "  │  GLOBAL SETUP                                       │"
    puts "  │  WNS (total):    ${wns_tot}ps                       "
    puts "  │  WNS (R2R):      ${wns_r2r}ps                       "
    puts "  │  TNS (R2R):      ${tns_r2r}ps                       "
    puts "  │  NVP (R2R):      ${nvp_r2r}                         "
    puts "  ├─────────────────────────────────────────────────────┤"
    puts "  │  mclk_exe GROUP                                     │"
    puts "  │  WNS:            ${mclk_wns}ps                      "
    puts "  │  TNS:            ${mclk_tns}ps                      "
    puts "  │  NVP:            ${mclk_nvp}                        "
    puts "  ├─────────────────────────────────────────────────────┤"
    puts "  │  SHIFTER BLOCK Vt (target blocks only)              │"
    puts "  │  ULVT:           ${ulvt_cnt}                        "
    puts "  │  LVT:            ${lvt_cnt}                         "
    puts "  │  ULVTLL:         ${ulvtll_cnt}                      "
    puts "  ├─────────────────────────────────────────────────────┤"
    puts "  │  PER-BLOCK WORST SLACK                              │"
    foreach bd $block_data {
        set bn [lindex $bd 0]; set bs [lindex $bd 1]
        puts [format "  │  %-35s  %s" $bn "${bs}ps"]
    }
    puts "  └─────────────────────────────────────────────────────┘"

    puts "\n  Snapshot '$label' saved. Use compare_before_after to see delta."
}


#======================================================================
# COMPARE BEFORE vs AFTER — Show what changed
#======================================================================
proc compare_before_after {} {
    global snap_data

    # Check both snapshots exist
    if {![info exists snap_data(BEFORE,wns_r2r)] || ![info exists snap_data(AFTER,wns_r2r)]} {
        puts "ERROR: Need both BEFORE and AFTER snapshots."
        puts "  Run: snapshot_timing BEFORE  (before ECO)"
        puts "  Run: snapshot_timing AFTER   (after ECO)"
        return
    }

    puts "\n"
    puts "╔═══════════════════════════════════════════════════════════════════════╗"
    puts "║           SHIFTER DATAPATH ECO — BEFORE vs AFTER                    ║"
    puts "╠═══════════════════════════════════════════════════════════════════════╣"

    # Helper to compute delta
    proc _delta {before after} {
        if {$before == "N/A" || $after == "N/A" || $before == "met" || $after == "met"} {
            return "N/A"
        }
        set d [expr {$after - $before}]
        if {$d > 0} { return "+[format %.1f $d]" }
        return [format %.1f $d]
    }

    set metrics {
        {wns_r2r "Setup WNS (R2R)"    "ps"}
        {tns_r2r "Setup TNS (R2R)"    "ps"}
        {nvp_r2r "Setup NVP (R2R)"    ""}
        {mclk_wns "mclk_exe WNS"      "ps"}
        {mclk_tns "mclk_exe TNS"      "ps"}
        {mclk_nvp "mclk_exe NVP"      ""}
        {ulvt     "ULVT cells (shf)"  ""}
        {lvt      "LVT cells (shf)"   ""}
        {ulvtll   "ULVTLL cells (shf)" ""}
    }

    puts [format "║  %-25s │ %12s │ %12s │ %12s ║" \
        "Metric" "BEFORE" "AFTER" "DELTA"]
    puts "╠═══════════════════════════╪══════════════╪══════════════╪══════════════╣"

    foreach m $metrics {
        set key   [lindex $m 0]
        set name  [lindex $m 1]
        set unit  [lindex $m 2]
        set bval  $snap_data(BEFORE,$key)
        set aval  $snap_data(AFTER,$key)
        set delta [_delta $bval $aval]

        # Color hint: positive delta on slack = improvement
        set mark ""
        if {$delta != "N/A" && [string index $delta 0] == "+"} {
            if {$key == "wns_r2r" || $key == "mclk_wns"} {
                set mark " ▲"  ;# slack improved
            }
        }
        if {$delta != "N/A" && [string index $delta 0] != "+" && $delta != "0.0"} {
            if {$key == "nvp_r2r" || $key == "mclk_nvp"} {
                set mark " ▼"  ;# NVP decreased = good
            }
            if {$key == "tns_r2r" || $key == "mclk_tns"} {
                set mark " ▲"  ;# TNS less negative = good (but delta shows as positive)
            }
        }

        puts [format "║  %-25s │ %10s%s │ %10s%s │ %10s%s ║" \
            $name $bval $unit $aval $unit "${delta}${unit}${mark}"]
    }

    puts "╚═══════════════════════════╧══════════════╧══════════════╧══════════════╝"

    # Per-block comparison
    puts "\n  ── PER-BLOCK SLACK DELTA ──"
    puts [format "  %-40s │ %10s │ %10s │ %10s" "Block" "BEFORE" "AFTER" "DELTA"]
    puts "  [string repeat ─ 80]"

    foreach key [lsort [array names snap_data "BEFORE,block,*"]] {
        set block_name [lindex [split $key ,] 2]
        set bval $snap_data($key)
        set akey "AFTER,block,$block_name"
        if {[info exists snap_data($akey)]} {
            set aval $snap_data($akey)
        } else {
            set aval "N/A"
        }
        set delta [_delta $bval $aval]
        puts [format "  %-40s │ %8sps │ %8sps │ %8sps" \
            $block_name $bval $aval $delta]
    }

    rename _delta ""
}


#======================================================================
# GENERATE FULL ECO REPORT — Write summary to file
#======================================================================
proc generate_eco_report {{filename "shifter_eco_report.txt"}} {
    global snap_data
    variable ::shf_cfg::eco_tag
    variable ::shf_cfg::target_blocks

    set fh [open $filename w]

    puts $fh "╔══════════════════════════════════════════════════════════════════╗"
    puts $fh "║    SHIFTER DATAPATH ECO REPORT — par_exe                       ║"
    puts $fh "║    Generated: [clock format [clock seconds] -format {%Y-%m-%d %H:%M}]                               ║"
    puts $fh "╚══════════════════════════════════════════════════════════════════╝"

    puts $fh "\n═══════════════════════════════════════════════════════════════════"
    puts $fh " SECTION 1: ECO SCOPE"
    puts $fh "═══════════════════════════════════════════════════════════════════"
    puts $fh "  Target: 278 internal paths (-50ps to -46.5ps slack)"
    puts $fh "  Root cause: Shifter/ALU data path delay (M305H→M305H)"
    puts $fh "  Techniques: C1 (upsize), C3 (Vt swap), C4 (buffer insert)"
    puts $fh "  Source: master_timing_fix_cookbook.txt, Mode 1 (ECO)"

    # ECO cell count
    set eco_cells [get_flat_cells -quiet -filter $eco_tag]
    set eco_count [sizeof_collection $eco_cells]
    puts $fh "\n  ECO cells created/modified: $eco_count"

    # Count by type
    set vt_swapped 0; set upsized 0; set buffers 0
    foreach_in_collection c $eco_cells {
        set rn [get_attribute $c ref_name]
        if {[string match "*BUFF*" $rn]} {
            incr buffers
        } else {
            # Can't perfectly distinguish vt-swap from upsize after the fact
            incr vt_swapped
        }
    }
    puts $fh "    Vt swaps + upsizes: $vt_swapped"
    puts $fh "    Buffers inserted:   $buffers"

    puts $fh "\n═══════════════════════════════════════════════════════════════════"
    puts $fh " SECTION 2: BEFORE vs AFTER"
    puts $fh "═══════════════════════════════════════════════════════════════════"

    if {[info exists snap_data(BEFORE,wns_r2r)] && [info exists snap_data(AFTER,wns_r2r)]} {
        set metrics {
            {wns_r2r "Setup WNS (R2R)"}
            {tns_r2r "Setup TNS (R2R)"}
            {nvp_r2r "Setup NVP (R2R)"}
            {mclk_wns "mclk_exe WNS"}
            {mclk_tns "mclk_exe TNS"}
            {mclk_nvp "mclk_exe NVP"}
            {ulvt     "ULVT cells"}
            {lvt      "LVT cells"}
            {ulvtll   "ULVTLL cells"}
        }

        puts $fh [format "\n  %-25s │ %12s │ %12s │ %12s" \
            "Metric" "BEFORE" "AFTER" "DELTA"]
        puts $fh "  [string repeat ─ 70]"

        foreach m $metrics {
            set key  [lindex $m 0]
            set name [lindex $m 1]
            set bval $snap_data(BEFORE,$key)
            set aval $snap_data(AFTER,$key)
            if {$bval != "N/A" && $aval != "N/A" && $bval != "met" && $aval != "met"} {
                set delta [format "%.1f" [expr {$aval - $bval}]]
            } else {
                set delta "N/A"
            }
            puts $fh [format "  %-25s │ %12s │ %12s │ %12s" \
                $name $bval $aval $delta]
        }

        # Per-block
        puts $fh "\n  Per-block slack:"
        puts $fh [format "  %-40s │ %10s │ %10s │ %10s" "Block" "BEFORE" "AFTER" "DELTA"]
        puts $fh "  [string repeat ─ 78]"
        foreach key [lsort [array names snap_data "BEFORE,block,*"]] {
            set bn [lindex [split $key ,] 2]
            set bv $snap_data($key)
            set ak "AFTER,block,$bn"
            set av [expr {[info exists snap_data($ak)] ? $snap_data($ak) : "N/A"}]
            if {$bv != "N/A" && $av != "N/A" && $bv != "met" && $av != "met"} {
                set dv [format "%.1f" [expr {$av - $bv}]]
            } else {
                set dv "N/A"
            }
            puts $fh [format "  %-40s │ %8sps │ %8sps │ %8sps" $bn $bv $av $dv]
        }
    } else {
        puts $fh "\n  WARNING: BEFORE/AFTER snapshots not available."
        puts $fh "  Run snapshot_timing BEFORE and snapshot_timing AFTER."
    }

    puts $fh "\n═══════════════════════════════════════════════════════════════════"
    puts $fh " SECTION 3: TARGET BLOCKS"
    puts $fh "═══════════════════════════════════════════════════════════════════"
    foreach block $target_blocks {
        puts $fh "  $block"
    }

    puts $fh "\n═══════════════════════════════════════════════════════════════════"
    puts $fh " SECTION 4: RECOMMENDATIONS"
    puts $fh "═══════════════════════════════════════════════════════════════════"
    puts $fh "  After this ECO:"
    puts $fh "  1. Run DRC check: report_constraints -max_transition -all_violators"
    puts $fh "  2. Run hold check: report_timing -delay_type min -group mclk_exe -max 20"
    puts $fh "  3. If hold degrades: may need hold buffer insertion"
    puts $fh "  4. Run FEV to verify logical equivalence"
    puts $fh "  5. Next ECO target: balance_byplevel_clk.tcl (clock skew fix)"

    close $fh
    puts "\n  Report written to: $filename"
    puts "  Use: cat $filename"
}

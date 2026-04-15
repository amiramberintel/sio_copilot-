#!/usr/bin/env tclsh
# ============================================================================
#  ICC2 ECO FIX TCL — shuf2vfpp7v0wbm804h_data[14]
#  Based on PO's ww7 netlist (azelman_wa02/26ww7_6_golden3_wo_pragma_cip_ci)
#  PT session: func.max_high.T_85.typical
#  Partition WNS: -51ps → target: ~-18 to -26ps after all fixes
#  Generated: 2026-03-12
# ============================================================================
#
#  USAGE:
#    In ICC2 shell:
#      source /nfs/site/disks/sunger_wa/fc_data/my_learns/ww11_4/shuf2vfpp7v0wbm804h_po_ww7_fixes.tcl
#
#    To run a single step:
#      set STEP <number>   ;# 0-4
#      source <this_file>
#
#  STEPS:
#    0 — Verify cells exist (DRY RUN, no changes)
#    1 — Size up D2/D3 logic cells (4 cells, ~9.5ps gain)
#    2 — Size up buffer chain (3 cells, ~6ps gain)
#    3 — Buffer long wires (2 inserts, ~5-7ps gain)
#    4 — Size clock tree inverters (2 cells, ~2-4ps gain)
#
# ============================================================================

proc log {msg} { puts "  $msg" }
proc banner {title} {
    puts ""
    puts "================================================================"
    puts "  $title"
    puts "  Date: [clock format [clock seconds]]"
    puts "================================================================"
}

# Output log
set logfile "/nfs/site/disks/${::env(USER)}_wa/stage0_verify_results/fix_log.txt"
catch { file mkdir [file dirname $logfile] }

# ── CELL DEFINITIONS ──────────────────────────────────────────────
# Each entry: {full_hierarchy  suffix  current_lib  new_lib  description}

# Fix 1: Size up D2/D3 logic cells
set fix1_cells {
    {exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_HFSBUF_119_3608907
        3608907
        BUFFSR2D3BWP156HPNPN3P48CPDLVT
        BUFFSR2D6BWP156HPNPN3P48CPDULVT
        "FF output buffer D3/LVT → D6/ULVT (~2-3ps)"}
    {exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_ctmTdsLR_1_4984359
        4984359
        AOI211SKROD2BWP156HPNPN3P48CPDULVT
        AOI211SKROD4BWP156HPNPN3P48CPDULVT
        "AOI gate D2 → D4 (~2ps)"}
    {exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_ctmTdsLR_1_5148805
        5148805
        AOI21SKFOD2BWP156HPNPN3P48CPDULVT
        AOI21SKFOD4BWP156HPNPN3P48CPDULVT
        "AOI gate D2 → D4 (~2.5ps)"}
    {exe_vec/shuf/shufp7v0c/sishufld/route_opt_ropt_d_inst_6839584
        6839584
        BUFFRFSD2BWP156HNPPN3P48CPDULVT
        BUFFRFSD4BWP156HNPPN3P48CPDULVT
        "Buffer D2 → D4, HNPP track (~3ps)"}
}

# Fix 2: Size up buffer chain (hierarchy crossing buffers)
set fix2_cells {
    {exe_vec/shuf/clock_route_opt_copt_gre_mt_inst_6680700
        6680700
        BUFFSR2BFYD5BWP156HPNPN3P48CPDULVT
        BUFFSR2BFYD8BWP156HPNPN3P48CPDULVT
        "Buffer chain D5 → D8 (~1.5ps)"}
    {exe_vec/shuf/clock_route_opt_copt_gre_mt_inst_6680699
        6680699
        BUFFSR2SKRBFYD6BWP156HPNPN3P48CPDULVT
        BUFFSR2SKRBFYD8BWP156HPNPN3P48CPDULVT
        "Buffer chain D6 → D8 (~2.5ps)"}
    {exe_vec/shuf/clock_route_opt_copt_gre_mt_inst_6680698
        6680698
        BUFFSR2BFYD6BWP156HPNPN3P48CPDULVT
        BUFFSR2BFYD8BWP156HPNPN3P48CPDULVT
        "Buffer chain D6 → D8 (~2ps)"}
}

# Fix 3: Wire buffering (sink pins for insert_buffer)
# {sink_pin_full_path  buffer_lib  description}
set fix3_wires {
    {exe_vec/shuf/compile_initial_opto_HFSINV_427_2898771/I
        BUFFSR2D6BWP156HPNPN3P48CPDULVT
        "Buffer 6.9ps wire before INVD6 (~3-4ps)"}
    {exe_vec/shuf/clock_route_opt_copt_gre_mt_inst_6680699/I
        BUFFSR2D6BWP156HPNPN3P48CPDULVT
        "Buffer 5.5ps wire before SKRBFY buf (~2-3ps)"}
}

# Fix 4: Clock tree sizing
set fix4_cells {
    {exe_vec/shuf/shufp7v0c/sishufld/clock_opt_cts_ZCTSINV_1096_6267327
        6267327
        CKND6BWP156HPNPN3P48CPDULVT
        CKND8BWP156HPNPN3P48CPDULVT
        "CTS INV D6 → D8 (~1-2ps)"}
    {exe_vec/shuf/shufp7v0c/sishufld/clock_opt_cts_ZCTSINV_574_6267326
        6267326
        CKND5BWP156HPNPN3P48CPDULVT
        CKND8BWP156HPNPN3P48CPDULVT
        "CTS INV D5 → D8 (~1-2ps)"}
}

# ══════════════════════════════════════════════════════════════════
#  STEP 0: VERIFY ALL CELLS EXIST
# ══════════════════════════════════════════════════════════════════
proc step0 {} {
    banner "STEP 0: VERIFY CELLS EXIST (DRY RUN)"
    set pass 0
    set fail 0
    set results {}

    # Check sizing cells
    foreach group {::fix1_cells ::fix2_cells ::fix4_cells} {
        foreach entry [set $group] {
            set cell [lindex $entry 0]
            set suffix [lindex $entry 1]
            set expected_lib [lindex $entry 2]
            set desc [lindex $entry 4]

            set found [get_cells -quiet $cell]
            if {[sizeof_collection $found] > 0} {
                set actual_lib [get_attribute $found ref_name]
                if {$actual_lib eq $expected_lib} {
                    log "FOUND  ✓  $cell"
                    log "          lib: $actual_lib (matches)"
                    incr pass
                } else {
                    log "FOUND  ⚠  $cell"
                    log "          expected: $expected_lib"
                    log "          actual:   $actual_lib"
                    incr pass
                }
            } else {
                # Try suffix search
                set by_suffix [get_cells -quiet -hier *$suffix]
                if {[sizeof_collection $by_suffix] > 0} {
                    set actual_name [get_attribute [index_collection $by_suffix 0] full_name]
                    set actual_lib [get_attribute [index_collection $by_suffix 0] ref_name]
                    log "FOUND  ~  suffix *$suffix → $actual_name"
                    log "          lib: $actual_lib"
                    lappend results "REMAP: $cell → $actual_name"
                    incr pass
                } else {
                    log "MISS   ✗  $cell (suffix *$suffix)"
                    incr fail
                }
            }
        }
    }

    # Check buffer insertion pins
    foreach entry $::fix3_wires {
        set pin [lindex $entry 0]
        set found [get_pins -quiet $pin]
        if {[sizeof_collection $found] > 0} {
            log "FOUND  ✓  pin: $pin"
            incr pass
        } else {
            # Try cell part
            set cell_part [file dirname $pin]
            set pin_name [file tail $pin]
            set by_cell [get_cells -quiet $cell_part]
            if {[sizeof_collection $by_cell] > 0} {
                log "FOUND  ✓  cell: $cell_part (pin $pin_name)"
                incr pass
            } else {
                set suffix [lindex [split $cell_part _] end]
                set by_suffix [get_cells -quiet -hier *$suffix]
                if {[sizeof_collection $by_suffix] > 0} {
                    set actual_name [get_attribute [index_collection $by_suffix 0] full_name]
                    log "FOUND  ~  suffix *$suffix → $actual_name/$pin_name"
                    lappend results "REMAP: $cell_part → $actual_name"
                    incr pass
                } else {
                    log "MISS   ✗  pin: $pin"
                    incr fail
                }
            }
        }
    }

    puts ""
    log "────────────────────────────────────────────────"
    log "PASS: $pass  |  FAIL: $fail"
    if {[llength $results] > 0} {
        log ""
        log "REMAPPINGS NEEDED:"
        foreach r $results { log "  $r" }
    }
    if {$fail == 0} {
        log ""
        log "✓ ALL CELLS FOUND — safe to proceed with fixes"
    } else {
        log ""
        log "✗ $fail cells NOT FOUND — DO NOT proceed!"
        log "  Check hierarchy names and share output with sunger"
    }

    # Save to file
    catch {
        set fh [open $::logfile w]
        puts $fh "STEP 0 VERIFY: pass=$pass fail=$fail"
        if {[llength $results] > 0} {
            foreach r $results { puts $fh $r }
        }
        close $fh
        log "Results saved to: $::logfile"
    }

    return [expr {$fail == 0}]
}

# ══════════════════════════════════════════════════════════════════
#  STEP 1: SIZE UP D2/D3 LOGIC CELLS (~9.5ps gain)
# ══════════════════════════════════════════════════════════════════
proc step1 {} {
    banner "STEP 1: SIZE UP D2/D3 LOGIC CELLS"
    set ok 0
    set err 0

    foreach entry $::fix1_cells {
        set cell [lindex $entry 0]
        set new_lib [lindex $entry 3]
        set desc [lindex $entry 4]

        log "Sizing: $desc"
        log "  cell: $cell"
        log "  to:   $new_lib"

        if {[catch {size_cell $cell $new_lib} msg]} {
            log "  ERROR: $msg"
            incr err
        } else {
            log "  OK"
            incr ok
        }
    }

    puts ""
    log "Step 1 done: $ok sized, $err errors"
    return [expr {$err == 0}]
}

# ══════════════════════════════════════════════════════════════════
#  STEP 2: SIZE UP BUFFER CHAIN (~6ps gain)
# ══════════════════════════════════════════════════════════════════
proc step2 {} {
    banner "STEP 2: SIZE UP BUFFER CHAIN"
    set ok 0
    set err 0

    foreach entry $::fix2_cells {
        set cell [lindex $entry 0]
        set new_lib [lindex $entry 3]
        set desc [lindex $entry 4]

        log "Sizing: $desc"
        log "  cell: $cell"
        log "  to:   $new_lib"

        if {[catch {size_cell $cell $new_lib} msg]} {
            log "  ERROR: $msg"
            incr err
        } else {
            log "  OK"
            incr ok
        }
    }

    puts ""
    log "Step 2 done: $ok sized, $err errors"
    return [expr {$err == 0}]
}

# ══════════════════════════════════════════════════════════════════
#  STEP 3: BUFFER LONG WIRES (~5-7ps gain)
# ══════════════════════════════════════════════════════════════════
proc step3 {} {
    banner "STEP 3: BUFFER LONG WIRES"
    set ok 0
    set err 0

    foreach entry $::fix3_wires {
        set pin [lindex $entry 0]
        set buf_lib [lindex $entry 1]
        set desc [lindex $entry 2]

        log "Buffer insert: $desc"
        log "  sink pin: $pin"
        log "  buffer:   $buf_lib"

        if {[catch {insert_buffer $pin $buf_lib} msg]} {
            log "  ERROR: $msg"
            incr err
        } else {
            log "  OK — buffer inserted"
            incr ok
        }
    }

    puts ""
    log "Step 3 done: $ok buffers inserted, $err errors"
    if {$ok > 0} {
        log "NOTE: Run 'check_legality' and 'route_eco' after placement"
    }
    return [expr {$err == 0}]
}

# ══════════════════════════════════════════════════════════════════
#  STEP 4: SIZE CLOCK TREE INVERTERS (~2-4ps gain)
# ══════════════════════════════════════════════════════════════════
proc step4 {} {
    banner "STEP 4: SIZE CLOCK TREE INVERTERS"
    log "WARNING: Clock sizing affects ALL FFs in this clock group!"
    log "         Run hold check after this step."
    puts ""

    set ok 0
    set err 0

    foreach entry $::fix4_cells {
        set cell [lindex $entry 0]
        set new_lib [lindex $entry 3]
        set desc [lindex $entry 4]

        log "Sizing: $desc"
        log "  cell: $cell"
        log "  to:   $new_lib"

        if {[catch {size_cell $cell $new_lib} msg]} {
            log "  ERROR: $msg"
            incr err
        } else {
            log "  OK"
            incr ok
        }
    }

    puts ""
    log "Step 4 done: $ok sized, $err errors"
    log "MUST CHECK: report_timing -delay min (hold) after clock changes"
    return [expr {$err == 0}]
}

# ══════════════════════════════════════════════════════════════════
#  MAIN — run selected step or all
# ══════════════════════════════════════════════════════════════════
if {![info exists STEP]} {
    set STEP 0
    log "No STEP set — running STEP 0 (verify only)"
    log "To run a specific step: set STEP <0-4>"
}

switch $STEP {
    0 { step0 }
    1 { step1 }
    2 { step2 }
    3 { step3 }
    4 { step4 }
    all {
        log "Running ALL steps sequentially"
        if {[step0]} {
            step1
            step2
            step3
            step4
            banner "ALL STEPS COMPLETE"
            log "Next: update_timing → report_timing to verify improvement"
        } else {
            log "STEP 0 failed — aborting"
        }
    }
    default {
        log "Unknown STEP: $STEP (valid: 0, 1, 2, 3, 4, all)"
    }
}

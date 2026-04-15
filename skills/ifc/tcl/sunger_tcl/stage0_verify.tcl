###############################################################################
#  stage0_verify.tcl — Run in ICC2 to collect ALL data for fix TCL creation
#  Output:  /nfs/site/disks/$USER_wa/stage0_verify_results/stage0_verify_results.txt
#
#  HOW TO RUN:
#    icc2_shell> source /nfs/site/disks/sunger_wa/fc_data/my_learns/ww11_4/stage0_verify.tcl
#
#  WHAT THIS COLLECTS:
#    Section A: Environment (design, lib, block)
#    Section B: Signal port check + fanout
#    Section C: Timing report on the signal (setup + hold)
#    Section D: Clock tree cells on the path
#    Section E: Data path cells from timing report
#    Section F: Cell search by suffix (verify PT names)
#    Section G: Available lib cell sizes for fixes
#
#  REUSABLE: Change the SIGNAL variable below for any other signal.
###############################################################################

#==========================================================================
# CONFIGURATION — CHANGE THESE FOR YOUR SIGNAL
#==========================================================================
set SIGNAL    "shuf2vfpp7v0wbm804h"
set MAX_PATHS 3

# Cell suffixes to verify (from PT analysis)
set CELL_SUFFIXES {
    "Fix1a_INR2D1_sizing"    "*4757944"
    "Fix1b_MUXAO4D1_sizing"  "*4647004"
    "Fix1c_INVD4_sizing"     "*6774874"
    "Fix2_BUFFD12_source"    "*2996657"
    "Fix2_IAOI21D4_sink"     "*3924589"
    "Fix3_BUFFSRD8_port"     "*6944842"
    "FixB1_NR2D16_source"    "*4080370"
    "FixB1_ND2D4_sink"       "*4293068"
    "FixB2_INVD8_source"     "*6774875"
}

set CLK_SUFFIXES {
    "CLK1a_CKND9"   "*ZCTSINV_721"
    "CLK1b_CKND12"  "*ZCTSINV_539"
}

set NET_PATTERNS {
    "HFSNET_507"       "*HFSNET_507"
    "HFSNET_131"       "*HFSNET_131"
    "tropt_4327106"    "*tropt_net_4327106"
}

#==========================================================================
# SETUP — output file
#==========================================================================
set user $::env(USER)
set outdir "/nfs/site/disks/${user}_wa/stage0_verify_results"
file mkdir $outdir
set outfile "${outdir}/stage0_verify_results.txt"
set fp [open $outfile w]

proc log {msg} {
    upvar fp fp
    puts $msg
    puts $fp $msg
}

proc log_cmd {cmd} {
    upvar fp fp
    puts "  Running: $cmd"
    if {[catch {set result [uplevel 1 $cmd]} err]} {
        puts "  ERROR: $err"
        puts $fp "  ERROR: $err"
    } else {
        puts $result
        puts $fp $result
    }
}

# Redirect report commands to file
proc log_report {cmd} {
    upvar fp fp
    if {[catch {set result [uplevel 1 $cmd]} err]} {
        puts "  ERROR: $err"
        puts $fp "  ERROR: $err"
    } else {
        puts $fp $result
        puts "  (report captured to file)"
    }
}

log "######################################################################"
log "  STAGE 0 VERIFY — Signal: $SIGNAL"
log "  Date: [date]"
log "  User: $user"
log "######################################################################"


#==========================================================================
# SECTION A: ENVIRONMENT
#==========================================================================
log "\n================================================================"
log "  SECTION A: ENVIRONMENT"
log "================================================================"

log "\n--- Design ---"
if {[catch {set des [current_design]} err]} {
    log "  current_design ERROR: $err"
} else {
    log "  design: $des"
}

log "\n--- Library ---"
if {[catch {set lib [current_lib]} err]} {
    log "  current_lib ERROR: $err"
} else {
    log "  lib: $lib"
}

log "\n--- Block ---"
if {[catch {set blk [current_block]} err]} {
    log "  current_block ERROR: $err"
} else {
    log "  block: $blk"
}

log "\n--- Top-level hierarchy (2 levels deep) ---"
if {[catch {
    set top_cells [get_cells -quiet *]
    set count [sizeof_collection $top_cells]
    log "  Top-level cell count: $count"
    if {$count <= 30} {
        foreach_in_collection c $top_cells {
            set n [get_attribute $c full_name]
            set r [get_attribute $c ref_name]
            log "    $n  ($r)"
        }
    } else {
        log "  (too many to list — showing first 20)"
        set i 0
        foreach_in_collection c $top_cells {
            if {$i >= 20} break
            set n [get_attribute $c full_name]
            set r [get_attribute $c ref_name]
            log "    $n  ($r)"
            incr i
        }
    }
} err]} {
    log "  ERROR listing top cells: $err"
}


#==========================================================================
# SECTION B: SIGNAL PORT CHECK
#==========================================================================
log "\n================================================================"
log "  SECTION B: SIGNAL PORT — ${SIGNAL}"
log "================================================================"

log "\n--- Search for port ---"
if {[catch {
    set ports [get_ports -quiet *${SIGNAL}*]
    set pcount [sizeof_collection $ports]
    log "  Ports matching *${SIGNAL}*: $pcount"
    if {$pcount > 0 && $pcount <= 50} {
        foreach_in_collection p $ports {
            set pn [get_attribute $p full_name]
            set dir [get_attribute $p direction]
            log "    $dir  $pn"
        }
    } elseif {$pcount > 50} {
        log "  (too many — showing first 10)"
        set i 0
        foreach_in_collection p $ports {
            if {$i >= 10} break
            set pn [get_attribute $p full_name]
            set dir [get_attribute $p direction]
            log "    $dir  $pn"
            incr i
        }
    }
} err]} {
    log "  ERROR: $err"
}

log "\n--- Search for nets ---"
if {[catch {
    set nets [get_nets -hier -quiet *${SIGNAL}*]
    set ncount [sizeof_collection $nets]
    log "  Nets matching *${SIGNAL}*: $ncount"
    if {$ncount > 0 && $ncount <= 20} {
        foreach_in_collection n $nets {
            set nn [get_attribute $n full_name]
            log "    $nn"
        }
    } elseif {$ncount > 20} {
        log "  (showing first 10 of $ncount)"
        set i 0
        foreach_in_collection n $nets {
            if {$i >= 10} break
            set nn [get_attribute $n full_name]
            log "    $nn"
            incr i
        }
    }
} err]} {
    log "  ERROR: $err"
}


#==========================================================================
# SECTION C: TIMING REPORTS
#==========================================================================
log "\n================================================================"
log "  SECTION C: TIMING REPORTS"
log "  NOTE: Requires update_timing. If errors, timing is not loaded."
log "================================================================"

log "\n--- Setup (max) — worst $MAX_PATHS paths through *${SIGNAL}* ---"
if {[catch {
    set rpt [report_timing -through [get_pins -hier -quiet *${SIGNAL}*] \
        -max_paths $MAX_PATHS -nosplit -input_pins -nets \
        -transition_time -capacitance -physical \
        -path_type full -delay_type max]
    puts $fp $rpt
    log "  (setup report captured — $MAX_PATHS paths)"
} err]} {
    log "  SETUP TIMING ERROR: $err"
    log "  → Try: update_timing  then re-source this script"
}

log "\n--- Hold (min) — worst path through *${SIGNAL}* ---"
if {[catch {
    set rpt_hold [report_timing -through [get_pins -hier -quiet *${SIGNAL}*] \
        -max_paths 1 -nosplit -path_type full -delay_type min]
    puts $fp $rpt_hold
    log "  (hold report captured)"
} err]} {
    log "  HOLD TIMING ERROR: $err"
}


#==========================================================================
# SECTION D: CLOCK TREE — cells on the clock path to source FF
#==========================================================================
log "\n================================================================"
log "  SECTION D: CLOCK TREE CELLS"
log "================================================================"

log "\n--- Source FF clock pins matching *${SIGNAL}* ---"
if {[catch {
    set ff_pins [get_pins -hier -quiet *${SIGNAL}*/CP]
    set ff_count [sizeof_collection $ff_pins]
    log "  FF clock pins (CP) matching: $ff_count"
    if {$ff_count == 0} {
        set ff_pins [get_pins -hier -quiet *${SIGNAL}*/CK]
        set ff_count [sizeof_collection $ff_pins]
        log "  FF clock pins (CK) matching: $ff_count"
    }
    if {$ff_count > 0} {
        set pin1 [index_collection $ff_pins 0]
        set pin_name [get_attribute $pin1 full_name]
        log "  First FF pin: $pin_name"
    }
} err]} {
    log "  ERROR: $err"
}

log "\n--- CTS cells (ZCTSINV, CKBUF, CKN) in hierarchy ---"
if {[catch {
    set cts_cells [get_cells -hier -quiet *ZCTS*]
    set cts_count [sizeof_collection $cts_cells]
    log "  ZCTS* cells found: $cts_count"
    if {$cts_count > 0 && $cts_count <= 30} {
        foreach_in_collection c $cts_cells {
            set n [get_attribute $c full_name]
            set r [get_attribute $c ref_name]
            log "    $n  ($r)"
        }
    } elseif {$cts_count > 30} {
        log "  (too many — showing first 15)"
        set i 0
        foreach_in_collection c $cts_cells {
            if {$i >= 15} break
            set n [get_attribute $c full_name]
            set r [get_attribute $c ref_name]
            log "    $n  ($r)"
            incr i
        }
    } else {
        log "  No ZCTS cells found — trying *CKB* and *CKND*"
        set ck_cells [get_cells -hier -quiet -filter "ref_name=~*CKND*||ref_name=~*CKBUF*"]
        set ck_count [sizeof_collection $ck_cells]
        log "  CK buffer/inv cells: $ck_count"
        if {$ck_count > 0 && $ck_count <= 20} {
            foreach_in_collection c $ck_cells {
                set n [get_attribute $c full_name]
                set r [get_attribute $c ref_name]
                log "    $n  ($r)"
            }
        }
    }
} err]} {
    log "  ERROR: $err"
}


#==========================================================================
# SECTION E: ALL CELLS ON DATA PATH (from timing report fanout cone)
#==========================================================================
log "\n================================================================"
log "  SECTION E: DATA PATH CELLS — fanin/fanout of signal"
log "================================================================"

log "\n--- Cells driving *${SIGNAL}* port/pin ---"
if {[catch {
    set drv_pins [get_pins -hier -quiet -filter "direction==out" \
        [all_fanin -to [get_ports -quiet *${SIGNAL}_data*] -only_cells -flat]]
    # fallback: just list cells connected to the signal nets
    set sig_nets [get_nets -hier -quiet *${SIGNAL}*data*]
    if {[sizeof_collection $sig_nets] > 0} {
        set first_net [index_collection $sig_nets 0]
        set net_name [get_attribute $first_net full_name]
        set drv [all_fanin -to [get_nets -quiet $net_name] -only_cells -flat -levels 10]
        set drv_count [sizeof_collection $drv]
        log "  Cells in fanin cone of $net_name (10 levels): $drv_count"
        if {$drv_count > 0 && $drv_count <= 40} {
            foreach_in_collection c $drv {
                set n [get_attribute $c full_name]
                set r [get_attribute $c ref_name]
                set loc ""
                catch {set loc [get_attribute $c origin]}
                log "    $n  ($r)  $loc"
            }
        } elseif {$drv_count > 40} {
            log "  (too many — showing first 20)"
            set i 0
            foreach_in_collection c $drv {
                if {$i >= 20} break
                set n [get_attribute $c full_name]
                set r [get_attribute $c ref_name]
                log "    $n  ($r)"
                incr i
            }
        }
    } else {
        log "  No nets matching *${SIGNAL}*data*"
    }
} err]} {
    log "  ERROR: $err"
}


#==========================================================================
# SECTION F: CELL SEARCH BY SUFFIX (from PT analysis)
#==========================================================================
log "\n================================================================"
log "  SECTION F: CELL SEARCH BY SUFFIX (PT → ICC2 mapping)"
log "================================================================"

log "\n--- Data path cells ---"
foreach {tag suffix} $CELL_SUFFIXES {
    if {[catch {
        set cells [get_cells -hier -quiet $suffix]
        set count [sizeof_collection $cells]
        if {$count > 0} {
            set full_name [get_attribute [index_collection $cells 0] full_name]
            set ref       [get_attribute [index_collection $cells 0] ref_name]
            set loc ""
            catch {set loc [get_attribute [index_collection $cells 0] origin]}
            log "  OK    $tag"
            log "         path: $full_name"
            log "         lib:  $ref"
            log "         loc:  $loc"
        } else {
            log "  MISS  $tag  (searched: $suffix)"
        }
    } err]} {
        log "  ERROR  $tag: $err"
    }
}

log "\n--- Clock cells ---"
foreach {tag suffix} $CLK_SUFFIXES {
    if {[catch {
        set cells [get_cells -hier -quiet $suffix]
        set count [sizeof_collection $cells]
        if {$count > 0} {
            set full_name [get_attribute [index_collection $cells 0] full_name]
            set ref       [get_attribute [index_collection $cells 0] ref_name]
            log "  OK    $tag"
            log "         path: $full_name"
            log "         lib:  $ref"
        } else {
            log "  MISS  $tag  (searched: $suffix)"
        }
    } err]} {
        log "  ERROR  $tag: $err"
    }
}

log "\n--- Nets ---"
foreach {tag pattern} $NET_PATTERNS {
    if {[catch {
        set nets [get_nets -hier -quiet $pattern]
        set count [sizeof_collection $nets]
        if {$count > 0} {
            set full_name [get_attribute [index_collection $nets 0] full_name]
            log "  OK    $tag  → $full_name"
        } else {
            log "  MISS  $tag  (searched: $pattern)"
        }
    } err]} {
        log "  ERROR  $tag: $err"
    }
}


#==========================================================================
# SECTION G: AVAILABLE LIB CELLS (for sizing options)
#==========================================================================
log "\n================================================================"
log "  SECTION G: AVAILABLE LIB CELL SIZES"
log "  (so we know which drive strengths exist)"
log "================================================================"

foreach base {INR2 AN3 BUFFD INVD CKND BUFFSR2BFYD BUFFSR2D IAOI21 MUXAO4} {
    log "\n--- ${base}*ULVT ---"
    if {[catch {
        set libs [get_lib_cells -quiet */${base}*CPDULVT]
        set lcount [sizeof_collection $libs]
        if {$lcount > 0} {
            set names {}
            foreach_in_collection lc $libs {
                lappend names [get_attribute $lc name]
            }
            set names [lsort $names]
            foreach n $names { log "    $n" }
        } else {
            log "    (none found)"
        }
    } err]} {
        log "    ERROR: $err"
    }
}


#==========================================================================
# DONE
#==========================================================================
log "\n######################################################################"
log "  DONE — All data collected"
log "  Results: $outfile"
log "######################################################################"

close $fp
puts "\n  >>> File written: $outfile <<<"

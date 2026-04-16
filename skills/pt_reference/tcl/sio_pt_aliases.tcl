#!/usr/bin/env pt_shell
#===============================================================================
#  SIO PT Shell Aliases -- Timing Analysis Quick Commands
#===============================================================================
#  Source in PT: source skills/pt_reference/tcl/sio_pt_aliases.tcl
#
#  Based on team scripts from: baselibr, sunger, ahaimovi, gilkeren
#  Organized by category for SIO timing closure workflow
#===============================================================================

puts "Loading SIO PT aliases..."

#===============================================================================
#  SETTINGS
#===============================================================================
# Fixed-width columns for cleaner report output
redirect /dev/null {set_app_var timing_report_fixed_width_columns_on_left true}

#===============================================================================
#  REPORT TIMING -- Core aliases
#===============================================================================

# Full detailed report (THE workhorse -- physical, nets, transitions, cap, xtalk)
alias rpt "report_timing -significant_digits 1 -nosplit -nets -physical -input_pins -transition_time -capacitance -crosstalk_delta -include_hierarchical_pins"

# Directional shortcuts
alias rptf  "rpt -from"
alias rptt  "rpt -to"
alias rpth  "rpt -through"

# Summary mode (quick scan, one-line per path)
alias rpts   "report_timing -include_hierarchical_pins -path summary"
alias rpts0  "rpts -start_end_pair -slack_lesser_than 0"
alias rpts1  "rpts -start_end_pair -slack_lesser_than 1"
alias rptsthr "rpts -through"

# Min delay (hold) reporting
alias rptmin    "report_timing -include_hierarchical_pins -delay min"
alias rptmins   "rptmin -path summary -start_end_pair -slack_lesser_than 0"
alias rptminsthr "rptmin -path summary -through"

# Full clock expanded (see launch + capture clock paths)
alias rptfc  "rpt -path full_clock_expanded"
alias rptminfc "rptmin -include_hierarchical_pins -path full_clock_expanded"

# PBA mode (path-based, more accurate but slower)
alias rptpba  "rpt -pba_mode path"
alias rptpbax "rpt -pba_mode exhaustive"

# Clock gating paths
alias rptcg "report_timing -include_hierarchical_pins -group **clock_gating_default**"

#===============================================================================
#  PER-SCENARIO shortcuts (GFC corners)
#===============================================================================

alias trptf "rpt -scenario func.max_turbo.T_85.typical -from"
alias trptt "rpt -scenario func.max_turbo.T_85.typical -to"
alias trpth "rpt -scenario func.max_turbo.T_85.typical -through"
alias nrptf "rpt -scenario func.max_nom.T_85.typical -from"
alias nrptt "rpt -scenario func.max_nom.T_85.typical -to"
alias nrpth "rpt -scenario func.max_nom.T_85.typical -through"

#===============================================================================
#  GET TIMING PATHS -- For programmatic access
#===============================================================================

alias gtp   "get_timing_paths"
alias gtpf  "gtp -from"
alias gtpt  "gtp -to"
alias gtph  "gtp -through"
alias gtpmin "gtp -delay min"

#===============================================================================
#  MULTI-PATH reports (N worst paths)
#===============================================================================

# Top N violations
proc rptN {n args} {
    eval report_timing -significant_digits 1 -nosplit -nets -physical -input_pins \
        -transition_time -capacitance -crosstalk_delta -include_hierarchical_pins \
        -max_paths $n -nworst $n $args
}

# Top N violations, summary only
proc rptsN {n args} {
    eval report_timing -include_hierarchical_pins -path summary \
        -max_paths $n -nworst $n $args
}

# Top 10/50/100 violations
alias rpt10  "rptN 10"
alias rpt50  "rptN 50"
alias rpt100 "rptN 100"
alias rpts10  "rptsN 10"
alias rpts50  "rptsN 50"
alias rpts100 "rptsN 100"

# All violating paths through a net/pin
proc rpt_all_viol {args} {
    eval report_timing -significant_digits 1 -nosplit -nets -physical -input_pins \
        -transition_time -capacitance -crosstalk_delta -include_hierarchical_pins \
        -slack_lesser_than 0 -max_paths 100 -nworst 10 $args
}

#===============================================================================
#  CONSTRAINT & QOR REPORTS
#===============================================================================

alias rc   "report_constraint -all_violators -nosplit"
alias rcmax "report_constraint -all_violators -nosplit -max_delay"
alias rcmin "report_constraint -all_violators -nosplit -min_delay"
alias rck  "report_clocks"
alias rqor "report_qor"
alias rac  "report_analysis_coverage"

#===============================================================================
#  OBJECT ACCESS shortcuts
#===============================================================================

alias gc   "get_cells"
alias gch  "get_cells -hierarchical"
alias gp   "get_pins"
alias gph  "get_pins -hierarchical"
alias gn   "get_nets"
alias gnh  "get_nets -hierarchical"
alias gpt  "get_ports"
alias ga   "get_attribute"
alias gon  "get_object_name"
alias gs   "get_selection"
alias cs   "change_selection"
alias sz   "sizeof_collection"

#===============================================================================
#  FANIN / FANOUT tracing
#===============================================================================

alias fit  "all_fanin  -flat -trace_arcs timing -startpoints_only -to"
alias fot  "all_fanout -flat -trace_arcs timing -endpoints_only -from"
alias afi  "all_fanin  -startpoints_only -only_cells -flat -to"
alias afo  "all_fanout -endpoints_only -only_cells -flat -from"
alias fis  "all_fanin  -flat -trace_arcs all -startpoints_only -to"
alias fos  "all_fanout -flat -trace_arcs all -endpoints_only -from"
alias ac   "all_connected -leaf"

#===============================================================================
#  CELL / NET ANALYSIS
#===============================================================================

# Quick cell info
proc cell_info {pattern} {
    set cells [get_cells -hierarchical -filter "full_name=~*${pattern}*"]
    foreach_in_collection c $cells {
        set name [get_object_name $c]
        set ref  [get_attribute $c ref_name]
        set area [get_attribute $c area -quiet]
        puts [format "%-60s  ref=%-25s  area=%s" $name $ref $area]
    }
}

# Quick slack of selected objects
alias slack_of_selected "get_attribute \[gs\] max_slack"

#===============================================================================
#  SIO-SPECIFIC PROCS
#===============================================================================

# Sort & Report: worst slack per pin of an EBB/hierarchical block
proc sort_sr {pins args} {
    set results [list]
    foreach_in_collection pin $pins {
        set name [get_object_name $pin]
        set dir  [get_attribute $pin direction]
        redirect /dev/null {set tp [get_timing_paths -through $pin]}
        set slack [get_attribute $tp slack -quiet]
        if {$slack eq ""} {set slack 999.9}
        lappend results [list $slack $dir $name]
    }
    set sorted [lsort -real -index 0 -increasing $results]
    puts [format "%-8s %-6s %s" "Slack" "Dir" "Pin"]
    puts [string repeat "-" 80]
    foreach r $sorted {
        puts [format "%-8.1f %-6s %s" [lindex $r 0] [lindex $r 1] [lindex $r 2]]
    }
}

# Margin report: worst slack for every pin of an EBB instance (setup)
proc mar {pattern} {
    set pins [get_pins -of_objects [get_cells -hierarchical -filter "full_name=~*${pattern}*"] -filter "direction!=internal"]
    sort_sr $pins
}

# Same but for min delay (hold)
proc mart {pattern} {
    set results [list]
    set pins [get_pins -of_objects [get_cells -hierarchical -filter "full_name=~*${pattern}*"] -filter "direction!=internal"]
    foreach_in_collection pin $pins {
        set name [get_object_name $pin]
        set dir  [get_attribute $pin direction]
        redirect /dev/null {set tp [get_timing_paths -through $pin -delay min]}
        set slack [get_attribute $tp slack -quiet]
        if {$slack eq ""} {set slack 999.9}
        lappend results [list $slack $dir $name]
    }
    set sorted [lsort -real -index 0 -increasing $results]
    puts [format "%-8s %-6s %s" "Slack" "Dir" "Pin"]
    puts [string repeat "-" 80]
    foreach r $sorted {
        puts [format "%-8.1f %-6s %s" [lindex $r 0] [lindex $r 1] [lindex $r 2]]
    }
}

# IFC path report: from partition A through port to partition B
proc ifc_path {from_par port to_par args} {
    eval report_timing -significant_digits 1 -nosplit -nets -physical -input_pins \
        -transition_time -capacitance -crosstalk_delta -include_hierarchical_pins \
        -from [get_pins ${from_par}/*] -through [get_pins *${port}*] \
        -to [get_pins ${to_par}/*] $args
}

# Inter-partition worst paths summary
proc ifc_worst {from_par to_par {n 20}} {
    report_timing -include_hierarchical_pins -path summary \
        -from [get_pins ${from_par}/*] -to [get_pins ${to_par}/*] \
        -max_paths $n -nworst 1
}

# EBB audit: all pins of a block, sorted by slack with full path detail
proc ebb_audit {cell_pattern {outfile ""}} {
    set cells [get_cells -hierarchical -filter "full_name=~*${cell_pattern}*"]
    foreach_in_collection cell $cells {
        set name [get_object_name $cell]
        set total [sizeof_collection [get_pins -of_objects $cell -filter "direction!=internal"]]
        puts "=== Auditing: $name ($total pins) ==="

        set table [list]
        set i 0
        foreach_in_collection pin [get_pins -of_objects $cell -filter "direction!=internal"] {
            incr i
            if {$i % 50 == 0} {puts "  ... $i / $total"}
            redirect /dev/null {set tp [get_timing_paths -through $pin]}
            set slack [get_attribute $tp slack -quiet]
            set dir   [get_attribute $pin direction]
            set pname [get_object_name $pin]
            if {$slack eq ""} {set slack 999.9}
            lappend table [list $slack $dir $pname]
        }
        set sorted [lsort -real -index 0 -increasing $table]

        if {$outfile ne ""} {
            set fname [regsub -all {/} "ebb_audit_${name}_${outfile}.rpt" {_}]
            set fh [open $fname w]
            puts $fh [format "%-8s %-6s %s" "Slack" "Dir" "Pin"]
            puts $fh [string repeat "-" 80]
            foreach r $sorted {
                puts $fh [format "%-8.1f %-6s %s" [lindex $r 0] [lindex $r 1] [lindex $r 2]]
            }
            close $fh
            puts "Written to: $fname"
        } else {
            puts [format "%-8s %-6s %s" "Slack" "Dir" "Pin"]
            puts [string repeat "-" 80]
            foreach r $sorted {
                puts [format "%-8.1f %-6s %s" [lindex $r 0] [lindex $r 1] [lindex $r 2]]
            }
        }
        puts ""
    }
}

# Path stage counter: count logic levels between two points
proc path_stages {args} {
    set tp [eval get_timing_paths $args -nworst 1]
    if {$tp eq ""} {puts "No path found"; return}
    set points [get_attribute $tp points]
    set stages 0
    set cell_delay 0.0
    set net_delay 0.0
    foreach_in_collection pt $points {
        set incr [get_attribute $pt arrival_increment]
        set obj  [get_attribute $pt object -quiet]
        set cls  [get_attribute $pt object_class -quiet]
        if {$cls eq "pin"} {
            set dir [get_attribute $obj direction -quiet]
            if {$dir eq "out"} {
                incr stages
            }
            set cell_delay [expr {$cell_delay + $incr}]
        } else {
            set net_delay [expr {$net_delay + $incr}]
        }
    }
    set slack [get_attribute $tp slack]
    set total [expr {$cell_delay + $net_delay}]
    puts [format "Stages:     %d"   $stages]
    puts [format "Cell delay: %.1f" $cell_delay]
    puts [format "Net delay:  %.1f" $net_delay]
    puts [format "Total:      %.1f" $total]
    puts [format "Slack:      %.1f" $slack]
}

# Quick WNS/TNS per group
proc wns_summary {{groups ""}} {
    if {$groups eq ""} {
        set groups [get_object_name [get_path_groups]]
    }
    puts [format "%-40s %8s %10s %6s" "Group" "WNS" "TNS" "NVP"]
    puts [string repeat "-" 70]
    foreach grp $groups {
        redirect -variable rpt {report_qor -path_group $grp}
        set wns "N/A"; set tns "N/A"; set nvp "N/A"
        foreach line [split $rpt "\n"] {
            if {[regexp {WNS\s+(-?[\d.]+)} $line -> val]} {set wns $val}
            if {[regexp {TNS\s+(-?[\d.]+)} $line -> val]} {set tns $val}
            if {[regexp {Violating Paths:\s+(\d+)} $line -> val]} {set nvp $val}
        }
        puts [format "%-40s %8s %10s %6s" $grp $wns $tns $nvp]
    }
}

# Net physical info (cap, fanout, driver)
proc net_info {net_pattern} {
    set nets [get_nets -hierarchical -filter "full_name=~*${net_pattern}*"]
    foreach_in_collection net $nets {
        set name [get_object_name $net]
        set cap  [get_attribute $net total_capacitance -quiet]
        set fan  [get_attribute $net fanout -quiet]
        set drv  [get_object_name [get_pins -of_objects $net -filter "direction==out"] -quiet]
        puts [format "%-50s  cap=%-8s  fanout=%-4s  drv=%s" $name $cap $fan $drv]
    }
}

# Check buffer/inverter chain on a path
proc buff_chain {args} {
    set tp [eval get_timing_paths $args -nworst 1]
    if {$tp eq ""} {puts "No path found"; return}
    set points [get_attribute $tp points]
    set chain [list]
    foreach_in_collection pt $points {
        set obj [get_attribute $pt object -quiet]
        set cls [get_attribute $pt object_class -quiet]
        if {$cls eq "pin"} {
            set dir [get_attribute $obj direction -quiet]
            if {$dir eq "out"} {
                set cell [get_cells -of_objects $obj -quiet]
                if {$cell ne ""} {
                    set ref [get_attribute $cell ref_name -quiet]
                    set incr [get_attribute $pt arrival_increment]
                    set name [get_object_name $cell]
                    if {[regexp -nocase {buff|inv|clkbuf|del} $ref]} {
                        lappend chain [list $name $ref [format "%.1f" $incr]]
                    }
                }
            }
        }
    }
    if {[llength $chain] == 0} {
        puts "No buffers/inverters found on path"
        return
    }
    puts [format "%-60s %-25s %s" "Instance" "Ref" "Delay"]
    puts [string repeat "-" 95]
    foreach item $chain {
        puts [format "%-60s %-25s %s" [lindex $item 0] [lindex $item 1] [lindex $item 2]]
    }
    puts "Total buffers/inverters: [llength $chain]"
}

#===============================================================================
#  TIMING SNAPSHOT (before/after ECO comparison)
#===============================================================================

# Capture WNS/TNS/NVP for before/after comparison
proc snapshot_timing {label} {
    puts "============================================================"
    puts "  SNAPSHOT: $label"
    puts "============================================================"
    redirect -variable grpt {report_global_timing -nosplit}
    set wns "N/A"; set tns "N/A"; set nvp "N/A"
    foreach line [split $grpt "\n"] {
        if {[regexp {WNS\s+(-?[\d.]+)} $line -> val]} {set wns $val}
        if {[regexp {TNS\s+(-?[\d.]+)} $line -> val]} {set tns $val}
        if {[regexp {Violating.*?(\d+)} $line -> val]} {set nvp $val}
    }
    puts "  WNS: $wns   TNS: $tns   NVP: $nvp"
    puts "============================================================"
    return [list $wns $tns $nvp]
}

# Clock latency report
proc clk_latency {clk_pattern {n 10}} {
    report_clock_timing -type latency -clock [get_clocks $clk_pattern] -nworst $n -nosplit
}

# Transition violations
alias rctran "report_constraint -max_transition -all_violators -nosplit"
# Capacitance violations
alias rccap  "report_constraint -max_capacitance -all_violators -nosplit"

#===============================================================================
#  ECO helpers
#===============================================================================

alias sc "size_cell"
alias rv "read_verilog"
alias wv "write -f verilog"

# Quick size_cell with before/after timing check
proc eco_size {inst new_ref} {
    puts "=== BEFORE ==="
    rpt -through [get_pins ${inst}/*]
    puts "\n=== SIZING: $inst -> $new_ref ==="
    size_cell $inst $new_ref
    puts "\n=== AFTER ==="
    rpt -through [get_pins ${inst}/*]
}

# Insert buffer with timing check
proc eco_insert_buf {net buf_ref {inst_name ""}} {
    if {$inst_name eq ""} {
        set inst_name "eco_buf_[clock clicks]"
    }
    puts "=== BEFORE ==="
    rpt -through [get_nets $net]
    puts "\n=== INSERTING: $buf_ref as $inst_name on $net ==="
    insert_buffer $net $buf_ref -new_cell_names $inst_name
    puts "\n=== AFTER ==="
    rpt -through [get_pins ${inst_name}/*]
}

#===============================================================================
#  UTILITY
#===============================================================================

alias h   "history"
alias e   "echo"
alias s   "source"
alias sv  "source -verbose -echo"
alias ps  "set_user_units -type time -value 1.0e-12"

# Unix commands in PT
alias xl   "exec xterm -e less -S"
alias grep "exec grep"
alias gvim "exec gvim"

# Redirect to file with timestamp
proc rpt_to_file {filename args} {
    redirect -file $filename {
        puts "#[date]"
        eval report_timing -significant_digits 1 -nosplit -nets -physical -input_pins \
            -transition_time -capacitance -crosstalk_delta -include_hierarchical_pins $args
        puts "#[date]"
    }
    puts "Written to: $filename"
}

# GUI helpers
alias clr "gui_remove_all_annotations; gui_remove_all_rulers; gui_change_highlight -remove -all_colors"

# Reload this alias file
alias s_sio "source skills/pt_reference/tcl/sio_pt_aliases.tcl"

puts "SIO PT aliases loaded. Key commands:"
puts "  rpt/rptf/rptt/rpth      -- Full timing report (from/to/through)"
puts "  rpts/rpts0               -- Summary / violators only"
puts "  rptmin/rptmins           -- Hold timing"
puts "  rptfc/rptpba/rptpbax     -- Clock expanded / PBA modes"
puts "  trptf/nrptf              -- Per-scenario (turbo/nominal)"
puts "  rptN 50 -from X         -- Top N paths"
puts "  mar <ebb_pattern>        -- Setup margin audit (all pins)"
puts "  mart <ebb_pattern>       -- Hold margin audit (all pins)"
puts "  ifc_path par_a port par_b -- IFC path report"
puts "  ifc_worst par_a par_b   -- Inter-partition worst"
puts "  ebb_audit <cell>         -- Full EBB pin audit"
puts "  path_stages -from X -to Y -- Count logic levels"
puts "  buff_chain -through X    -- Show buffer/inverter chain"
puts "  wns_summary              -- WNS/TNS per group"
puts "  net_info <pattern>       -- Net cap/fanout/driver"
puts "  eco_size inst new_ref    -- Size cell with before/after"
puts "  eco_insert_buf net ref   -- Insert buffer with timing check"
puts "  rpt_to_file file.rpt -from X  -- Save report to file"
puts ""

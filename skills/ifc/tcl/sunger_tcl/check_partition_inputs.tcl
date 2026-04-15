# check_partition_inputs.tcl
# Auto-detects all partitions from PT and checks which input pins have
# timing paths vs are unconstrained.
#
# Optional variables (set before sourcing):
#   delay_type  - "max" for setup, "min" for hold (default: "max")
#   output_file - write combined CSV results to file (default: "")
#
# Usage via pt_client.pl:
#   pt_client.pl -m <model> -c "set delay_type max; source /nfs/site/disks/gilkeren_wa/copilot/scripts/check_partition_inputs.tcl"
#   pt_client.pl -m <model> -c "set delay_type max; set output_file /path/to/results.csv; source /nfs/site/disks/gilkeren_wa/copilot/scripts/check_partition_inputs.tcl"

if {![info exists delay_type]} {
    set delay_type $ivar(sta,delay_type)
}
if {![info exists output_file]} {
    set output_file "$ivar(rpt_dir)/partition_input_check.csv"
}

# ===================================================================
#  Runtime helpers
# ===================================================================

proc format_elapsed {seconds} {
    set h [expr {int($seconds) / 3600}]
    set m [expr {(int($seconds) % 3600) / 60}]
    set s [expr {int($seconds) % 60}]
    return [format "%02dh:%02dm:%02ds" $h $m $s]
}

set script_start_time [clock seconds]

# ===================================================================
#  Step 1: Auto-detect partitions from the design
# ===================================================================

set step1_start [clock seconds]

# Collect partitions from all hierarchy levels:
#   - icore0/par_*, icore1/par_*  (core partitions)
#   - par_*                        (top-level partitions like par_pm, par_mlc)
set partition_list {}

foreach inst {icore0 icore1} {
    set cells [get_cells ${inst}/par_* -quiet]
    foreach_in_collection cell $cells {
        lappend partition_list [get_object_name $cell]
    }
}

# Top-level partitions (e.g., par_pm, par_mlc)
set top_cells [get_cells par_* -quiet]
foreach_in_collection cell $top_cells {
    lappend partition_list [get_object_name $cell]
}

set partition_list [lsort -unique $partition_list]
set n_partitions [llength $partition_list]

set step1_elapsed [expr {[clock seconds] - $step1_start}]

if {$n_partitions == 0} {
    puts "ERROR: No par_* cells found under icore0/, icore1/, or top level."
    return
}

puts "==========================================================="
puts "  Partition Input Timing Check - Auto-Detect"
puts "==========================================================="
puts "  Searched        : icore0/par_*, icore1/par_*, par_*"
puts "  Delay type      : ${delay_type}"
puts "  Partitions found: ${n_partitions}"
puts "  Detection time  : [format_elapsed $step1_elapsed]"
puts "-----------------------------------------------------------"
foreach par_path $partition_list {
    puts "    $par_path"
}
puts "==========================================================="
puts ""

# ===================================================================
#  Step 2: Helper proc to check one partition
# ===================================================================

proc check_partition_inputs {par_path delay_type} {
    set all_inputs [get_pins ${par_path}/* -filter {direction==in} -quiet]
    set n_total [sizeof_collection $all_inputs]

    if {$n_total == 0} {
        puts "  WARNING: No input pins found at ${par_path}/* - skipping"
        return [list {} {} {} 0 {} 0]
    }

    # Use a temp file to collect results from parallel threads safely.
    set tmpfile "/tmp/par_input_check_[pid]_[clock seconds].tmp"
    set fh [open $tmpfile w]
    close $fh

    puts "    Checking ${n_total} pins using parallel_foreach_in_collection..."

    set check_start [clock seconds]

    parallel_foreach_in_collection pin $all_inputs {
        set pname [get_object_name $pin]
        set result "UNCONSTRAINED"

        # Step A: Check for clock pin or sampling sink inside partition
        set has_sink 1
        set is_clock 0
        set sink_ok [catch {
            set all_ep [all_fanout -from $pname -endpoints_only -flat -trace_arcs all -quiet]
            set local_ep [filter_collection $all_ep "full_name =~ ${par_path}/*"]
            if {[sizeof_collection $local_ep] == 0} {
                set has_sink 0
            } else {
                set clk_ep [filter_collection $local_ep "is_clock_pin == true"]
                if {[sizeof_collection $clk_ep] > 0} {
                    set is_clock 1
                }
            }
        }]

        if {$sink_ok == 0 && $is_clock == 1} {
            set result "CLOCK"
        } elseif {$sink_ok == 0 && $has_sink == 0} {
            set result "SKIPPED"
        }

        # Step B: If pin has a data sink, check for constrained timing path
        if {$result ne "SKIPPED" && $result ne "CLOCK"} {
            set path_ok [catch {
                set paths [get_timing_paths -through $pname -max_paths 1 -nworst 1 -delay_type $delay_type]
                if {[sizeof_collection $paths] > 0} {
                    set pg [get_attribute [index_collection $paths 0] path_group -quiet]
                    if {$pg ne "" && $pg ne "**async_default**"} {
                        set result "CONSTRAINED"
                    }
                }
            } path_err]

            if {$path_ok != 0} {
                set result "ERROR"
            }
        }

        # Step C: Write result to shared temp file
        set fh [open $tmpfile a]
        puts $fh "${result},${pname}"
        close $fh
    }

    set check_elapsed [expr {[clock seconds] - $check_start}]

    # Parse results from temp file
    set con_list {}
    set unc_list {}
    set skip_list {}
    set err_list {}
    set clk_list {}

    set fh [open $tmpfile r]
    while {[gets $fh line] >= 0} {
        set comma_idx [string first "," $line]
        set status [string range $line 0 [expr {$comma_idx - 1}]]
        set pname  [string range $line [expr {$comma_idx + 1}] end]
        switch $status {
            CONSTRAINED   { lappend con_list $pname }
            UNCONSTRAINED { lappend unc_list $pname }
            SKIPPED       { lappend skip_list $pname }
            CLOCK         { lappend clk_list $pname }
            ERROR         { lappend err_list $pname }
        }
    }
    close $fh
    file delete -force $tmpfile

    return [list [lsort $con_list] [lsort $unc_list] [lsort $err_list] $n_total [lsort $skip_list] $check_elapsed [lsort $clk_list]]
}

# ===================================================================
#  Step 3: Run check on all partitions, collect results
# ===================================================================

set step3_start [clock seconds]

# Accumulate per-partition summary for final table
set summary_lines {}
# Accumulate all results for CSV output
set all_results {}

foreach par_path $partition_list {
    # Extract short partition name (e.g., par_fe from icore0/par_fe)
    set par_short [lindex [split $par_path "/"] end]

    puts "-----------------------------------------------------------"
    puts "  Checking: ${par_path}"
    puts "-----------------------------------------------------------"

    set par_start [clock seconds]

    set result [check_partition_inputs $par_path $delay_type]
    set con_list  [lindex $result 0]
    set unc_list  [lindex $result 1]
    set err_list  [lindex $result 2]
    set n_total   [lindex $result 3]
    set skip_list [lindex $result 4]
    set par_check_time [lindex $result 5]
    set clk_list  [lindex $result 6]

    set par_elapsed [expr {[clock seconds] - $par_start}]

    if {$n_total == 0} {
        lappend summary_lines [list $par_short 0 0 0 0 0 0 "N/A" "N/A" $par_elapsed]
        continue
    }

    set n_con  [llength $con_list]
    set n_unc  [llength $unc_list]
    set n_skip [llength $skip_list]
    set n_clk  [llength $clk_list]
    set n_err  [llength $err_list]
    set n_checked [expr {$n_con + $n_unc}]
    set con_pct "0.0"
    set unc_pct "0.0"
    if {$n_checked > 0} {
        set con_pct [format "%.1f" [expr {100.0 * $n_con / $n_checked}]]
        set unc_pct [format "%.1f" [expr {100.0 * $n_unc / $n_checked}]]
    }

    puts "    Total: ${n_total}  Checked: ${n_checked}  Skipped (no sink): ${n_skip}  Clock: ${n_clk}  Constrained: ${n_con} (${con_pct}%)  Unconstrained: ${n_unc} (${unc_pct}%)"
    puts "    Runtime: [format_elapsed $par_elapsed] (parallel check: [format_elapsed $par_check_time])"

    if {$n_unc > 0 && $n_unc <= 50} {
        puts "    Unconstrained pins:"
        foreach p $unc_list {
            puts "      $p"
        }
    } elseif {$n_unc > 50} {
        puts "    Unconstrained pins (first 50 of ${n_unc}):"
        set i 0
        foreach p $unc_list {
            if {$i >= 50} break
            puts "      $p"
            incr i
        }
        puts "      ... and [expr {$n_unc - 50}] more"
    }
    puts ""

    lappend summary_lines [list $par_short $n_total $n_checked $n_skip $n_clk $n_con $n_unc $con_pct $unc_pct $par_elapsed]

    # Store for CSV
    foreach p $con_list {
        lappend all_results [list $par_short "CONSTRAINED" $p]
    }
    foreach p $unc_list {
        lappend all_results [list $par_short "UNCONSTRAINED" $p]
    }
    foreach p $skip_list {
        lappend all_results [list $par_short "SKIPPED_NO_SINK" $p]
    }
    foreach p $clk_list {
        lappend all_results [list $par_short "CLOCK" $p]
    }
    foreach p $err_list {
        lappend all_results [list $par_short "ERROR" $p]
    }
}

set step3_elapsed [expr {[clock seconds] - $step3_start}]

# ===================================================================
#  Step 4: Print combined summary table
# ===================================================================

puts ""
puts "==========================================================="
puts "  COMBINED SUMMARY - ALL PARTITIONS"
puts "==========================================================="
puts [format "  %-20s %7s %7s %7s %7s %7s %7s %7s %7s %12s" "PARTITION" "TOTAL" "CHKD" "SKIP" "CLOCK" "CONSTR" "UNCONST" "CON%" "UNC%" "RUNTIME"]
puts "  -----------------------------------------------------------------------------------------------------------------------"

set grand_total 0
set grand_checked 0
set grand_skip 0
set grand_clk 0
set grand_con 0
set grand_unc 0

foreach line $summary_lines {
    set par_short [lindex $line 0]
    set n_total   [lindex $line 1]
    set n_checked [lindex $line 2]
    set n_skip    [lindex $line 3]
    set n_clk     [lindex $line 4]
    set n_con     [lindex $line 5]
    set n_unc     [lindex $line 6]
    set con_pct   [lindex $line 7]
    set unc_pct   [lindex $line 8]
    set runtime   [lindex $line 9]
    puts [format "  %-20s %7s %7s %7s %7s %7s %7s %6s%% %6s%% %12s" $par_short $n_total $n_checked $n_skip $n_clk $n_con $n_unc $con_pct $unc_pct [format_elapsed $runtime]]
    set grand_total   [expr {$grand_total + $n_total}]
    set grand_checked [expr {$grand_checked + $n_checked}]
    set grand_skip    [expr {$grand_skip + $n_skip}]
    set grand_clk     [expr {$grand_clk + $n_clk}]
    set grand_con     [expr {$grand_con + $n_con}]
    set grand_unc     [expr {$grand_unc + $n_unc}]
}

puts "  -----------------------------------------------------------------------------------------------------------------------"
if {$grand_checked > 0} {
    set g_con_pct [format "%.1f" [expr {100.0 * $grand_con / $grand_checked}]]
    set g_unc_pct [format "%.1f" [expr {100.0 * $grand_unc / $grand_checked}]]
    puts [format "  %-20s %7d %7d %7d %7d %7d %7d %6s%% %6s%% %12s" "TOTAL" $grand_total $grand_checked $grand_skip $grand_clk $grand_con $grand_unc $g_con_pct $g_unc_pct [format_elapsed $step3_elapsed]]
}
puts "==========================================================="

# ===================================================================
#  Step 5: Runtime summary
# ===================================================================

set total_elapsed [expr {[clock seconds] - $script_start_time}]

puts ""
puts "==========================================================="
puts "  RUNTIME SUMMARY"
puts "==========================================================="
puts "  Partition detection : [format_elapsed $step1_elapsed]"
puts "  All partition checks: [format_elapsed $step3_elapsed]"
puts "  ---"
foreach line $summary_lines {
    set par_short [lindex $line 0]
    set n_total   [lindex $line 1]
    set runtime   [lindex $line 9]
    set pct_of_total "0.0"
    if {$step3_elapsed > 0} {
        set pct_of_total [format "%.1f" [expr {100.0 * $runtime / $step3_elapsed}]]
    }
    puts [format "    %-20s %7d pins  %12s  (%5s%%)" $par_short $n_total [format_elapsed $runtime] $pct_of_total]
}
puts "  ---"
puts "  Total script runtime: [format_elapsed $total_elapsed]"
puts "==========================================================="
puts ""

# ===================================================================
#  Step 6: Write CSV output if requested
# ===================================================================

if {$output_file ne ""} {
    set fh [open $output_file w]
    puts $fh "# Partition Input Timing Check - All Partitions"
    puts $fh "# Delay type: ${delay_type}"
    puts $fh "# Partitions: ${n_partitions}"
    puts $fh "# Grand total: ${grand_total}  Constrained: ${grand_con}  Unconstrained: ${grand_unc}"
    puts $fh "# Total runtime: [format_elapsed $total_elapsed]"
    puts $fh "#"
    puts $fh "PARTITION,STATUS,PIN_NAME"
    foreach row $all_results {
        puts $fh "[lindex $row 0],[lindex $row 1],[lindex $row 2]"
    }
    close $fh
    puts "Results written to: ${output_file}"
}

puts "Done."

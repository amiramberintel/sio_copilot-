proc ts_debug_port {port} {
    puts "Starting script of checking if we can bound the flops of $port\n"
    set tr [get_timing_paths -through $port -max_paths 1000 -slack_lesser_than 0 -nworst 100 ] ;# timing path report
    set startpoints [get_cells -of_object [get_attribute $tr startpoint]]
    set endpoints [get_cells -of_object [get_attribute $tr endpoint]]

    set can_be_bounded_flops [dict create]
    set cant_be_bounded_flops [dict create]

    puts "### STARTPOINTS ###"
    puts "<flop> | <worst slack> | <worst slack through flop> | <worst slack to flop> "
    # first check all the startpoints if they have positive slack
    foreach_in_collection sp $startpoints {
		set cell_name [get_attribute $sp full_name ]
        redirect -var kuku {set tr_startpoint [get_timing_paths -through $cell_name/* -exclude $port ]}
        set sp_slack [get_attribute $tr_startpoint slack]
        redirect -var kuku {set to_flop [get_attribute [get_timing_paths -to $cell_name/* ] slack]}
        redirect -var kuku {set sl [get_attribute [get_timing_paths -through $cell_name/*] slack]}

        puts "$cell_name | $sl | $sp_slack | $to_flop "


    }
    puts " \n-----------------------------------------------------------------\n"
    # check all the endpoints if they have positive slack 
    puts "### ENDPOINTS ###"
    puts "<flop> | <worst slack through> | <worst slack from flop> "

    foreach_in_collection  ep $endpoints {
	    set cell_name [get_attribute $ep full_name ]
        redirect -var kuku {set tr_endpoint [get_timing_paths -through $cell_name/* -exclude $port]}
        set ep_slack [get_attribute $tr_endpoint slack]
        redirect -var kuku {set to_flop [get_attribute [get_timing_paths -from $cell_name/*] slack]}
        redirect -var kuku {set sl [get_attribute [get_timing_paths -through $cell_name/*] slack]}


        puts "$cell_name | $sl | $ep_slack | $to_flop "



    }
    
}



proc ts_check_slack_of_file {inputfile th} {

    set fp [open $inputfile "r"]
    set lines [read $fp]
    close $fp

    puts "####### PRINTING BAD PORTS UNDER $th SLACK #######"
    foreach port [split $lines "\n"] {
        set slack [get_attribute [get_timing_paths -through $port ] slack]
        
        if { $slack < $th} {
            puts "$port  |  $slack"
        }
    }

}

proc ts_get_ex_slack_of_ports {inputfile} {
    set fp [open $inputfile "r"]
    set lines [read $fp]
    close $fp

    puts "####### PRINTING SLACK OF PORTS EXHAUSTIVE MODE #######"
    foreach port [split $lines "\n"] {
        set slack [get_attribute [get_timing_paths -through $port -pba_mode exhaustive ] slack]
        puts "$slack"
        
    }
}


proc ts_get_bad_flops_from_port {port th} {
    
    set badflops [list]
    #puts "Starting script to find flops until slack of $th through $port\n"

    set tr [get_timing_paths -through $port -max_paths 1000 -slack_lesser_than 0 -nworst 100 -pba_mode exhaustive] 
    set startpoints [get_cells -of_object [get_attribute $tr startpoint]]
    foreach_in_collection sp $startpoints {
        set cell_name [get_attribute $sp full_name]
        
        redirect -var kuku {set tr_startpoint [get_timing_paths -from $cell_name -through $port -max_paths 1]}
        
        if {[sizeof_collection $tr_startpoint] > 0} {
            set sp_slack [get_attribute $tr_startpoint slack]
            
            if {$sp_slack < $th} {
                lappend badflops $cell_name
                #puts "Bad flop: $cell_name | slack: $sp_slack"
                #puts " "
            } else {
                break
            }
        }
    }
    
    #puts "\n=== BAD FLOPS SUMMARY ==="
    foreach flop $badflops {
        puts "$flop/*"
    }
}

proc ts_get_bad_flops_to_port {port th} {
    
    set badflops [list]
    #puts "Starting script to find flops until slack of $th to $port\n"

    set tr [get_timing_paths -through $port -max_paths 1000 -slack_lesser_than 0 -nworst 100 -pba_mode exhaustive] 
    set endpoints [get_cells -of_object [get_attribute $tr endpoint]]
    foreach_in_collection ep $endpoints {
        set cell_name [get_attribute $ep full_name]
	#puts "$cell_name"
        redirect -var kuku {set tr_endpoint [get_timing_paths -to $cell_name/* -through $port -max_paths 1]}
        
        if {[sizeof_collection $tr_endpoint] > 0} {
            set ep_slack [get_attribute $tr_endpoint slack]
            if {$ep_slack < $th} {
                lappend badflops $cell_name
                #puts "Bad flop: $cell_name (slack: $ep_slack)"
                #puts " "
            } else {
                break
            }
        }
    }
    
    #puts "\n=== BAD FLOPS SUMMARY ==="
    foreach flop $badflops {
        puts "$flop/*"
    }
}


#I want another script that opens PT FC sesscions for certain corners 

proc mb_readlines {filename} {
    # set lines [split [read [open $file]] "\n"]
    # puts $lines
    if {[catch {open $filename r} file_handle]} {
        puts "Error: Cannot open file '$filename'"
        return [list]
    }
    set lines [list]
    while {[gets $file_handle line] >= 0} {
        lappend lines $line
    }
    close $file_handle
    return $lines
}


proc pinfo {proc {body 1}} {
  set args [info args $proc]
  set args_list [list]
  foreach a $args {
    if [info default $proc $a d] {
      lappend args_list [list $a $d]
    }  else {
      lappend args_list $a
    }
  }
  if {!$body} {return $args_list}
  set body [info body $proc]
  append result "\n" proc " " $proc " " "{" $args_list "}"
  append result " {$body}"
  return $result
}


proc ts_file_get_bad_flops_from_port {port th fp} {
    
    set badflops [list]
    #puts "Starting script to find flops until slack of $th through $port\n"

    set tr [get_timing_paths -through $port -max_paths 1000 -slack_lesser_than 0 -nworst 100 -pba_mode exhaustive] 
    set startpoints [get_cells -of_object [get_attribute $tr startpoint]]
    foreach_in_collection sp $startpoints {
        set cell_name [get_attribute $sp full_name]
        
        redirect -var kuku {set tr_startpoint [get_timing_paths -from $cell_name -through $port -max_paths 1]}
        
        if {[sizeof_collection $tr_startpoint] > 0} {
            set sp_slack [get_attribute $tr_startpoint slack]
            
            if {$sp_slack < $th} {
                lappend badflops $cell_name
                #puts "Bad flop: $cell_name | slack: $sp_slack"
                #puts " "
            } else {
                break
            }
        }
    }
    set fp [open $output_file w]
    #puts "\n=== BAD FLOPS SUMMARY ==="
    foreach flop $badflops {
        puts $fp "$flop/*"
    }
    
}


# Helper: extract VT type from cell name
# Order matters: match longer suffixes first (ULVTLL before ULVT, etc.)
proc _extract_vt {cell_name} {
    if {[regexp {(ULVTLL|ULVT|UHVT|EHLVT|ELVT|HVT|LVT|SVT|RVT)} $cell_name vt]} {
        return $vt
    }
    return "unknown"
}

# Load illegal_cells.txt into a dict: { cell_short_name -> reason }
# File format: <lib_pattern>  <cell_short_name>  <reason>
proc _load_illegal_cells {filepath} {
    if {[catch {open $filepath r} fh]} {
        puts "WARNING: Cannot open illegal cells file: $filepath"
        return {}
    }
    set illegal {}
    while {[gets $fh line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string index $line 0] eq "#"} { continue }
        set parts [split $line]
        if {[llength $parts] >= 2} {
            dict set illegal [lindex $parts 1] [lindex $parts 2]
        }
    }
    close $fh
    return $illegal
}

proc ts_estimate_eco_best_buffer {{cell_path ""} {orig_short ""} {allow_vt_swap 0} {illegal_cells {}}} {
    # ── 1. Parse input line ────────────────────────────────────────────────
    if { ![string length $cell_path] || ![string length $orig_short] } {
        puts "ERROR: Missing required input parameter"
        puts "Usage: ts_estimate_eco_best_buffer <cell> <cell_short_name> ?allow_vt_swap?"
        puts "Example: ts_estimate_eco_best_buffer par_mlc/invs_cts_FE_OFC121676_mluncorepmim5nnh_0 BUFFSR2BFYD6BWP156HNPPN3P48CPDULVT"
        puts "Set allow_vt_swap=1 to consider cells from all libraries (cross-VT)"
        return
    }
    # ── 2. Run estimate_eco ────────────────────────────────────────────────
    if {$allow_vt_swap} {
        redirect -variable raw_output {
            estimate_eco $cell_path
        }
    } else {
        redirect -variable raw_output {
            estimate_eco $cell_path -current_library
        }
    }

    # ── 3. Parse tables ────────────────────────────────────────────────────
    set tables       {}
    set cur_dtype    ""
    set cur_rows     {}
    set pending_cell ""
    set in_table     0

    foreach line [split $raw_output "\n"] {
        set s [string trim $line]

        if {[regexp {delay type\s*:\s*(\S+)} $s -> dtype]} {
            if {$in_table && [llength $cur_rows] > 0} {
                lappend tables [dict create delay_type $cur_dtype rows $cur_rows]
            }
            set cur_dtype $dtype ; set cur_rows {} ; set pending_cell ""
            set in_table 1 ; continue
        }

        if {!$in_table} { continue }
        if {[regexp {^lib cell} $s] || [regexp {^-{10,}} $s]} { continue }
        if {$s eq ""} { set pending_cell "" ; continue }

        if {[regexp {^\s*([\d.]+)\s+([\d.]+)\s+([\d.eE+\-]+)\s+([\d.eE+\-]+)\s*$} \
                    $line -> area sdly arrival slack]} {
            if {$pending_cell ne ""} {
                lappend cur_rows [dict create \
                    lib_cell $pending_cell area $area \
                    stage_delay $sdly arrival $arrival slack $slack]
                set pending_cell ""
            }
            continue
        }
        if {[string match "*/*" $s]} { set pending_cell $s }
    }
    if {$in_table && [llength $cur_rows] > 0} {
        lappend tables [dict create delay_type $cur_dtype rows $cur_rows]
    }

    if {[llength $tables] == 0} {
        puts "ERROR: No candidate tables found in estimate_eco output."
        puts $raw_output
        return ""
    }

    # ── 4. Collect fall/rise slack per candidate (no table printout) ──────
    set fall_slack {}
    set rise_slack {}

    foreach tbl $tables {
        set dtype [dict get $tbl delay_type]
        set rows  [dict get $tbl rows]
        set edge  [string tolower $dtype]

        foreach row $rows {
            set lc  [dict get $row lib_cell]
            set slk [dict get $row slack]
            set sn  [lindex [split $lc "/"] end]

            # keep worst (lowest) slack per candidate across tables of same edge
            if {[string match "*fall*" $edge]} {
                if {![dict exists $fall_slack $sn] ||
                    $slk < [lindex [dict get $fall_slack $sn] 1]} {
                    dict set fall_slack $sn [list $lc $slk]
                }
            } elseif {[string match "*rise*" $edge]} {
                if {![dict exists $rise_slack $sn] ||
                    $slk < [lindex [dict get $rise_slack $sn] 1]} {
                    dict set rise_slack $sn [list $lc $slk]
                }
            }
        }
    }

    # ── 5. Get original buffer's slack in fall and rise ────────────────────
    if {![dict exists $fall_slack $orig_short]} {
        puts "WARNING: '$orig_short' not found in any fall table."
        set orig_fall_slack ""
    } else {
        set orig_fall_slack [lindex [dict get $fall_slack $orig_short] 1]
    }

    if {![dict exists $rise_slack $orig_short]} {
        puts "WARNING: '$orig_short' not found in any rise table."
        set orig_rise_slack ""
    } else {
        set orig_rise_slack [lindex [dict get $rise_slack $orig_short] 1]
    }

    if {$orig_fall_slack eq "" || $orig_rise_slack eq ""} {
        puts "Cannot compare — original buffer missing from one or both edge tables."
        return ""
    }

    # ── 6. Find candidates that beat original in BOTH fall AND rise ────────
    set qualified {}
    set orig_vt [_extract_vt $orig_short]

    set skipped_illegal 0
    dict for {short fall_info} $fall_slack {
        if {$short eq $orig_short}             { continue }
        if {![dict exists $rise_slack $short]} { continue }

        # skip candidates listed in the illegal cells file
        if {[dict exists $illegal_cells $short]} {
            incr skipped_illegal
            continue
        }

        set fall_slk [lindex $fall_info 1]
        set lc_fall  [lindex $fall_info 0]
        set rise_slk [lindex [dict get $rise_slack $short] 1]

        if {$fall_slk > $orig_fall_slack && $rise_slk > $orig_rise_slack} {
            set fg       [expr {$fall_slk - $orig_fall_slack}]
            set rg       [expr {$rise_slk - $orig_rise_slack}]
            set min_gain [expr {min($fall_slk, $rise_slk) - min($orig_fall_slack, $orig_rise_slack)}]
            set cand_vt  [_extract_vt $short]
            lappend qualified [list $min_gain $short $lc_fall $fall_slk $fg $rise_slk $rg $cand_vt]
        }
    }

    # ── 8. Report ──────────────────────────────────────────────────────────
    # Ranked by: min(new_fall, new_rise) - min(orig_fall, orig_rise)
    # i.e. how much the overall worst-case slack improves.
    set orig_min_slack [expr {min($orig_fall_slack, $orig_rise_slack)}]
    set dsep "  +===================================================================================+"
    puts ""
    puts $dsep
    if {$skipped_illegal > 0} {
        puts [format "  |  (skipped %d illegal candidate(s) from illegal_cells.txt)%-28s|" \
                  $skipped_illegal ""]
    }

    if {[llength $qualified] == 0} {
        puts "  |  NO CANDIDATE improves BOTH fall and rise slack vs original.                      |"
        puts $dsep
        return ""
    }

    set qualified [lsort -decreasing -real -index 0 $qualified]

    if {$allow_vt_swap} {
        puts "  |  CANDIDATES IMPROVING BOTH FALL AND RISE SLACK (cross-VT enabled)                |"
    } else {
        puts "  |  CANDIDATES IMPROVING BOTH FALL AND RISE SLACK (same-VT only)                    |"
    }
    puts $dsep
    puts [format "  | %-38s | %6s | %10s | %10s | %10s |" \
              "lib_cell (short)" "VT" "fall_slack" "rise_slack" "min_gain"]
    puts "  +----------------------------------------+--------+------------+------------+------------+"
    # original buffer row for reference
    set orig_disp $orig_short
    if {[string length $orig_disp] > 38} { set orig_disp "[string range $orig_disp 0 34]..." }
    puts [format "  | %-38s | %6s | %10s | %10s | %10s |" \
              $orig_disp $orig_vt $orig_fall_slack $orig_rise_slack "(original)"]
    puts "  +----------------------------------------+--------+------------+------------+------------+"

    set best_cell ""
    foreach q $qualified {
        lassign $q min_gain short lc_fall fall_slk fall_gain rise_slk rise_gain cand_vt
        set disp $short
        if {[string length $disp] > 38} { set disp "[string range $disp 0 34]..." }
        set vt_tag $cand_vt
        if {$cand_vt ne $orig_vt} { set vt_tag "${cand_vt}*" }
        set prefix "  "
        if {$best_cell eq ""} { set prefix "★ " ; set best_cell $lc_fall }
        puts [format "%s| %-38s | %6s | %10s | %10s | %+10.3f |" \
                  $prefix $disp $vt_tag $fall_slk $rise_slk $min_gain]
    }
    puts "  +----------------------------------------+--------+------------+------------+------------+"

    lassign [lindex $qualified 0] min_gain short lc_fall fall_slk fall_gain rise_slk rise_gain best_vt
    set new_min_slack [expr {min($fall_slk, $rise_slk)}]
    puts ""
    puts "  ★ BEST CANDIDATE (max overall worst-case slack improvement)"
    puts "  $lc_fall"
    if {$best_vt ne $orig_vt} {
        puts "    VT change   : $orig_vt -> $best_vt"
    }
    puts [format "    fall  slack : %-12s  (gain: %+.3f)" $fall_slk $fall_gain]
    puts [format "    rise  slack : %-12s  (gain: %+.3f)" $rise_slk $rise_gain]
    puts [format "    min gain    : min(%s,%s) - min(%s,%s) = %+.3f" \
              $fall_slk $rise_slk $orig_fall_slack $orig_rise_slack $min_gain]
    puts $dsep

    return $lc_fall
}

proc ts_analyze_cell_vt {cell_path args} {
    # ── 1. Validate input ─────────────────────────────────────────────────
    if {![string length $cell_path]} {
        puts "Usage: ts_analyze_cell_vt <cell_path> ?filter_pattern?"
        puts "Examples:"
        puts "  ts_analyze_cell_vt par_mlc/.../p0028A393625              ;# cross-VT (ULVT/ULVTLL/LVT)"
        puts "  ts_analyze_cell_vt par_mlc/.../p0028A393625 IOA*         ;# all IOA* cells across VTs"
        puts "  ts_analyze_cell_vt par_mlc/.../p0028A393625 -lib_cells IOA*   ;# same as above"
        puts "  ts_analyze_cell_vt par_mlc/.../p0028A393625 *ULVT        ;# only ULVT cells"
        return
    }

    # ── 2. Parse args: support both "IOA*" and "-lib_cells IOA*" syntax ──
    set filter ""
    for {set i 0} {$i < [llength $args]} {incr i} {
        set arg [lindex $args $i]
        if {$arg eq "-lib_cells"} {
            set filter [lindex $args [expr {$i + 1}]]
            incr i
        } elseif {[string index $arg 0] ne "-"} {
            set filter $arg
        }
    }

    # ── 3. Auto-detect current ref_name ───────────────────────────────────
    redirect -variable kuku {set cell_obj [get_cells $cell_path]}
    if {[sizeof_collection $cell_obj] == 0} {
        puts "ERROR: Cell '$cell_path' not found."
        return
    }
    set orig_ref [get_attribute $cell_obj ref_name]
    set orig_vt  [_extract_vt $orig_ref]

    puts "=== VT ANALYSIS FOR CELL: $cell_path ==="
    puts "Current ref  : $orig_ref"
    puts "Current VT   : $orig_vt"
    if {$filter ne ""} {
        puts "Filter       : $filter"
    }
    puts "estimate_eco : estimate_eco $cell_path  (all libraries, filter applied to display)"
    puts ""

    # ── 4. Run estimate_eco (NO flags — search all libraries for cross-VT)
    # Filter is applied to the display table, not to estimate_eco
    redirect -variable raw_output {
        estimate_eco $cell_path
    }

    # ── 5. Parse estimate_eco tables ──────────────────────────────────────
    set tables       {}
    set cur_dtype    ""
    set cur_rows     {}
    set pending_cell ""
    set in_table     0

    foreach line [split $raw_output "\n"] {
        set s [string trim $line]

        if {[regexp {delay type\s*:\s*(\S+)} $s -> dtype]} {
            if {$in_table && [llength $cur_rows] > 0} {
                lappend tables [dict create delay_type $cur_dtype rows $cur_rows]
            }
            set cur_dtype $dtype ; set cur_rows {} ; set pending_cell ""
            set in_table 1 ; continue
        }

        if {!$in_table} { continue }
        if {[regexp {^lib cell} $s] || [regexp {^-{10,}} $s]} { continue }
        if {$s eq ""} { set pending_cell "" ; continue }

        if {[regexp {^\s*([\d.]+)\s+([\d.]+)\s+([\d.eE+\-]+)\s+([\d.eE+\-]+)\s*$} \
                    $line -> area sdly arrival slack]} {
            if {$pending_cell ne ""} {
                lappend cur_rows [dict create \
                    lib_cell $pending_cell area $area \
                    stage_delay $sdly arrival $arrival slack $slack]
                set pending_cell ""
            }
            continue
        }
        if {[string match "*/*" $s]} { set pending_cell $s }
    }
    if {$in_table && [llength $cur_rows] > 0} {
        lappend tables [dict create delay_type $cur_dtype rows $cur_rows]
    }

    if {[llength $tables] == 0} {
        puts "ERROR: No candidate tables found in estimate_eco output."
        puts $raw_output
        return
    }

    # ── 6. Collect fall/rise slack per candidate ──────────────────────────
    set fall_slack {}
    set rise_slack {}

    foreach tbl $tables {
        set dtype [dict get $tbl delay_type]
        set rows  [dict get $tbl rows]
        set edge  [string tolower $dtype]

        foreach row $rows {
            set lc  [dict get $row lib_cell]
            set slk [dict get $row slack]
            set sn  [lindex [split $lc "/"] end]

            if {[string match "*fall*" $edge]} {
                if {![dict exists $fall_slack $sn] ||
                    $slk < [lindex [dict get $fall_slack $sn] 1]} {
                    dict set fall_slack $sn [list $lc $slk]
                }
            } elseif {[string match "*rise*" $edge]} {
                if {![dict exists $rise_slack $sn] ||
                    $slk < [lindex [dict get $rise_slack $sn] 1]} {
                    dict set rise_slack $sn [list $lc $slk]
                }
            }
        }
    }

    # ── 7. Get original cell slack ────────────────────────────────────────
    if {![dict exists $fall_slack $orig_ref]} {
        puts "WARNING: '$orig_ref' not found in fall table."
        set orig_fall_slack ""
    } else {
        set orig_fall_slack [lindex [dict get $fall_slack $orig_ref] 1]
    }
    if {![dict exists $rise_slack $orig_ref]} {
        puts "WARNING: '$orig_ref' not found in rise table."
        set orig_rise_slack ""
    } else {
        set orig_rise_slack [lindex [dict get $rise_slack $orig_ref] 1]
    }

    if {$orig_fall_slack eq "" || $orig_rise_slack eq ""} {
        puts "Cannot compare — original cell missing from one or both edge tables."
        return
    }

    set orig_min_slack [expr {min($orig_fall_slack, $orig_rise_slack)}]

    # ── 8. Filter candidates ──────────────────────────────────────────────
    # If a filter pattern was given, use it to match cell short names.
    # Otherwise fall back to the default ULVT/ULVTLL/LVT VT filter.
    set qualified {}

    dict for {short fall_info} $fall_slack {
        if {$short eq $orig_ref}              { continue }
        if {![dict exists $rise_slack $short]} { continue }

        if {$filter ne ""} {
            if {![string match $filter $short]} { continue }
        } else {
            set cand_vt [_extract_vt $short]
            if {$cand_vt ni {ULVT ULVTLL LVT}} { continue }
        }

        set fall_slk [lindex $fall_info 1]
        set lc_fall  [lindex $fall_info 0]
        set rise_slk [lindex [dict get $rise_slack $short] 1]
        set min_gain [expr {min($fall_slk, $rise_slk) - $orig_min_slack}]
        set cand_vt  [_extract_vt $short]

        lappend qualified [list $min_gain $short $lc_fall $fall_slk $rise_slk $cand_vt]
    }

    # ── 9. Report ─────────────────────────────────────────────────────────
    set dsep "  +=========================================================================================+"
    puts $dsep
    if {$filter ne ""} {
        set hdr "  |  CANDIDATES MATCHING: $filter"
        puts [format "%-91s|" $hdr]
    } else {
        puts "  |  VT SWAP OPTIONS (ULVT / ULVTLL / LVT)                                                |"
    }
    puts $dsep
    puts [format "  | %-45s | %7s | %10s | %10s | %10s |" \
              "new_cell" "new_VT" "fall_slack" "rise_slack" "min_gain"]
    puts "  +-----------------------------------------------+---------+------------+------------+------------+"

    # Original row
    set orig_disp $orig_ref
    if {[string length $orig_disp] > 45} { set orig_disp "[string range $orig_disp 0 41]..." }
    puts [format "  | %-45s | %7s | %10s | %10s | %10s |" \
              $orig_disp $orig_vt $orig_fall_slack $orig_rise_slack "(current)"]
    puts "  +-----------------------------------------------+---------+------------+------------+------------+"

    if {[llength $qualified] == 0} {
        puts "  |  No matching candidates found.                                                         |"
        puts $dsep
        return
    }

    set qualified [lsort -decreasing -real -index 0 $qualified]

    set best_cell ""
    foreach q $qualified {
        lassign $q min_gain short lc_fall fall_slk rise_slk cand_vt
        set disp $short
        if {[string length $disp] > 45} { set disp "[string range $disp 0 41]..." }
        set prefix "  "
        if {$best_cell eq ""} { set prefix "★ " ; set best_cell $lc_fall }
        puts [format "%s| %-45s | %7s | %10s | %10s | %+10.3f |" \
                  $prefix $disp $cand_vt $fall_slk $rise_slk $min_gain]
    }
    puts "  +-----------------------------------------------+---------+------------+------------+------------+"

    # Best candidate summary
    lassign [lindex $qualified 0] min_gain short lc_fall fall_slk rise_slk best_vt
    puts ""
    puts "  ★ BEST OPTION:"
    puts "    New cell    : $lc_fall"
    puts "    New VT      : $best_vt"
    if {$best_vt ne $orig_vt} {
        puts "    VT change   : $orig_vt -> $best_vt"
    }
    puts [format "    Min Gain    : %+.3f" $min_gain]
    puts $dsep

    return $lc_fall
}

  proc ts_get_inv_buff_cells_par_mlc {port_name {gtp_flags ""}} {
    # Build the gtp command with optional flags
    if {$gtp_flags != ""} {
        set path [eval "gtp -th $port_name $gtp_flags"]
    } else {
        set path [gtp -th $port_name]
    }
    
    set points [get_attribute $path points]
    set pins [get_attribute $points object]
    set cells [get_cells -of $pins]
    
    foreach_in_collection cell $cells {
        set ref_name [get_attribute $cell ref_name]
        set full_name [get_attribute $cell full_name]
        
        # Filter for INV/BUFF cells AND par_mlc/ path
        if {[regexp -nocase {INV|BUFF} $ref_name] && [string match "par_mlc/*" $full_name]} {
            puts "$full_name $ref_name"
        }
    }
}

proc ts_vt_swap_all_partitions {port_name {gtp_flags ""} {allow_vt_swap 0} {illegal_cells_file "/nfs/site/disks/tsabek_wa01/playground/illegal_cells.txt"}} {
    if {$allow_vt_swap} {
        puts "=== VT SWAP ANALYSIS FOR : $port_name (cross-VT enabled) ==="
    } else {
        puts "=== VT SWAP ANALYSIS FOR : $port_name (same-VT only) ==="
    }
    puts ""

    # Load illegal cells once for all candidate checks
    set illegal_cells [_load_illegal_cells $illegal_cells_file]
    puts "Loaded [dict size $illegal_cells] illegal cell entries from $illegal_cells_file"

    # Build the gtp command with optional flags
    if {$gtp_flags != ""} {
        set paths [eval "gtp -th $port_name $gtp_flags"]
    } else {
        set paths [gtp -th $port_name]
    }
    
    if {[sizeof_collection $paths] == 0} {
        puts "ERROR: No timing paths found through port '$port_name'"
        return
    }
    
    set points [get_attribute $paths points]
    set pins [get_attribute $points object]
    set cells [get_cells -of $pins]
    
    # Collect all cells on the path (combinational + sequential)
    set candidate_cells {}
    foreach_in_collection cell $cells {
        set ref_name [get_attribute $cell ref_name]
        set full_name [get_attribute $cell full_name]
        lappend candidate_cells [list $full_name $ref_name]
    }
    
    if {[llength $candidate_cells] == 0} {
        puts "No cells found in this path."
        return
    }
    
    # Remove duplicates
    set unique_cells {}
    set seen_cells {}
    foreach cell_info $candidate_cells {
        set full_name [lindex $cell_info 0]
        if {![dict exists $seen_cells $full_name]} {
            dict set seen_cells $full_name 1
            lappend unique_cells $cell_info
        }
    }
    
    puts "Found [llength $unique_cells] unique cells in this path:"
    #puts "=================================================================="
    
    set swap_candidates {}
    set cell_count 0
    set total_min_gain 0.0
    set total_cells [llength $unique_cells]
    
    foreach cell_info $unique_cells {
        incr cell_count
        set full_name [lindex $cell_info 0]
        set ref_name [lindex $cell_info 1]
        
        # Capture the estimate_eco output to extract gain information
        redirect -variable eco_output {
            set best_candidate [ts_estimate_eco_best_buffer $full_name $ref_name $allow_vt_swap $illegal_cells]
        }
        
        # Parse the min gain from the output
        set min_gain 0.0
        if {[regexp {min gain\s*:\s*[^=]*=\s*([\+\-]?[\d\.]+)} $eco_output -> gain_value]} {
            set min_gain $gain_value
        }
        
        if {$best_candidate ne "" && $best_candidate ne $ref_name && $min_gain > 0} {
            set best_short [lindex [split $best_candidate "/"] end]
            set orig_vt [_extract_vt $ref_name]
            set new_vt  [_extract_vt $best_short]
            set vt_change ""
            if {$orig_vt ne $new_vt} { set vt_change "${orig_vt}->${new_vt}" }
            lappend swap_candidates [list $full_name $ref_name $best_candidate $best_short $min_gain $vt_change]
            set total_min_gain [expr {$total_min_gain + $min_gain}]
        }
    }
    
    # Summary report
    puts ""
    puts "=================================================================="
    puts "                        SUMMARY REPORT"
    puts "=================================================================="
    puts "Total cells analyzed: $total_cells"
    puts "Swap opportunities found: [llength $swap_candidates]"
    puts "Total worst-case slack improvement: +[format "%.3f" $total_min_gain]"
    
    if {[llength $swap_candidates] > 0} {
        puts ""
        puts "RECOMMENDED SWAPS (sorted by worst-case improvement):"
        puts "--------------------------------------------------------"
        
        # Sort by min gain (descending)
        set sorted_swaps [lsort -decreasing -real -index 4 $swap_candidates]
        
        set swap_count 0
        foreach swap $sorted_swaps {
            incr swap_count
            lassign $swap full_name current_ref best_candidate best_short min_gain vt_change
            puts "\[${swap_count}\] $full_name"
            puts "    Current: $current_ref"
            puts "    Swap to: $best_short"
            if {$vt_change ne ""} {
                puts "    VT swap : $vt_change"
            }
            puts "    Min Gain: +[format "%.3f" $min_gain]"
            puts ""
        }
        
        puts "=================================================================="
        puts "TOTAL EXPECTED WORST-CASE SLACK IMPROVEMENT: +[format "%.3f" $total_min_gain]"
        puts "=================================================================="
        puts "Note: Min gain = improvement in worst-case (fall/rise) slack"
        if {$allow_vt_swap} {
            puts "Note: Entries with 'VT swap' indicate a voltage threshold change"
        }
    } else {
        puts ""
        puts "No beneficial swaps found for any cells in this path."
        puts "=================================================================="
    }
    
    #return [list "total_min_gain" $total_min_gain "swaps" $swap_candidates]
}


proc ts_vt_swap {port_name {gtp_flags ""} {allow_vt_swap 0} {illegal_cells_file "/nfs/site/disks/tsabek_wa01/playground/illegal_cells.txt"}} {
    if {$allow_vt_swap} {
        puts "=== VT SWAP ANALYSIS FOR : $port_name (cross-VT enabled, all cells) ==="
    } else {
        puts "=== VT SWAP ANALYSIS FOR : $port_name (same-VT only, all cells) ==="
    }
    puts ""

    # Load illegal cells once for all candidate checks
    set illegal_cells [_load_illegal_cells $illegal_cells_file]
    puts "Loaded [dict size $illegal_cells] illegal cell entries from $illegal_cells_file"

    # Build the gtp command with optional flags
    if {$gtp_flags != ""} {
        set paths [eval "gtp -th $port_name $gtp_flags"]
    } else {
        set paths [gtp -th $port_name]
    }
    
    if {[sizeof_collection $paths] == 0} {
        puts "ERROR: No timing paths found through port '$port_name'"
        return
    }
    
    set points [get_attribute $paths points]
    set pins [get_attribute $points object]
    set cells [get_cells -of $pins]
    
    # Collect ALL cells on the path (no partition or type filter)
    set candidate_cells {}
    foreach_in_collection cell $cells {
        set ref_name  [get_attribute $cell ref_name]
        set full_name [get_attribute $cell full_name]
        lappend candidate_cells [list $full_name $ref_name]
    }
    
    if {[llength $candidate_cells] == 0} {
        puts "No cells found on this path."
        return
    }
    
    # Remove duplicates
    set unique_cells {}
    set seen_cells {}
    foreach cell_info $candidate_cells {
        set full_name [lindex $cell_info 0]
        if {![dict exists $seen_cells $full_name]} {
            dict set seen_cells $full_name 1
            lappend unique_cells $cell_info
        }
    }
    
    puts "Found [llength $unique_cells] unique cells in par_mlc partition:"
    
    set swap_candidates {}
    set cell_count 0
    set total_min_gain 0.0
    set total_cells [llength $unique_cells]
    
    foreach cell_info $unique_cells {
        incr cell_count
        set full_name [lindex $cell_info 0]
        set ref_name [lindex $cell_info 1]
        
        # Capture the estimate_eco output to extract gain information
        redirect -variable eco_output {
            set best_candidate [ts_estimate_eco_best_buffer $full_name $ref_name $allow_vt_swap $illegal_cells]
        }
        
        # Parse the min gain from the output
        set min_gain 0.0
        if {[regexp {min gain\s*:\s*[^=]*=\s*([\+\-]?[\d\.]+)} $eco_output -> gain_value]} {
            set min_gain $gain_value
        }
        
        if {$best_candidate ne "" && $best_candidate ne $ref_name && $min_gain > 0} {
            set best_short [lindex [split $best_candidate "/"] end]
            set orig_vt [_extract_vt $ref_name]
            set new_vt  [_extract_vt $best_short]
            set vt_change ""
            if {$orig_vt ne $new_vt} { set vt_change "${orig_vt}->${new_vt}" }
            lappend swap_candidates [list $full_name $ref_name $best_candidate $best_short $min_gain $vt_change]
            set total_min_gain [expr {$total_min_gain + $min_gain}]
        }
    }
    
    # Summary report
    puts ""
    puts "=================================================================="
    puts "                        SUMMARY REPORT"
    puts "=================================================================="
    puts "Total cells analyzed: $total_cells"
    puts "Swap opportunities found: [llength $swap_candidates]"
    puts "Total worst-case slack improvement: +[format "%.3f" $total_min_gain]"
    
    if {[llength $swap_candidates] > 0} {
        puts ""
        puts "RECOMMENDED SWAPS (sorted by worst-case improvement):"
        puts "--------------------------------------------------------"
        
        # Sort by min gain (descending)
        set sorted_swaps [lsort -decreasing -real -index 4 $swap_candidates]
        
        set swap_count 0
        foreach swap $sorted_swaps {
            incr swap_count
            lassign $swap full_name current_ref best_candidate best_short min_gain vt_change
            puts "\[${swap_count}\] $full_name"
            puts "    Current: $current_ref"
            puts "    Swap to: $best_short"
            if {$vt_change ne ""} {
                puts "    VT swap : $vt_change"
            }
            puts "    Min Gain: +[format "%.3f" $min_gain]"
            puts ""
        }
        
        puts "=================================================================="
        puts "TOTAL EXPECTED WORST-CASE SLACK IMPROVEMENT: +[format "%.3f" $total_min_gain]"
        puts "=================================================================="
        puts "Note: Min gain = improvement in worst-case (fall/rise) slack"
        if {$allow_vt_swap} {
            puts "Note: Entries with 'VT swap' indicate a voltage threshold change"
        }
    } else {
        puts ""
        puts "No beneficial swaps found for any cells in this path."
        puts "=================================================================="
    }
    
    #return [list "total_min_gain" $total_min_gain "swaps" $swap_candidates]
}
# cell_type_delays.tcl - Report average delay per cell type and arc in PrimeTime
#
# Usage in PT shell:
#   source cell_type_delays.tcl
#   report_cell_type_delays -output cell_delays_max_high.csv
#   report_cell_type_delays -output cell_delays_max_med.csv -sample 50
#   report_cell_type_delays -output cell_delays_max_high.csv -partition icore0/par_meu
#
# Run at each corner, then use cell_delay_scaling.py to compare.
#
# Method: For each cell instance, runs report_delay_calculation on every
# combinational timing arc (input->output), parses the actual cell delay.
# Reports per-arc averages (e.g., NAND2: A->Y rise, A->Y fall, B->Y rise, B->Y fall).

proc report_cell_type_delays {args} {
    parse_proc_arguments -args $args opts
    set outfile $opts(-output)
    set max_sample 20
    if {[info exists opts(-sample)]} { set max_sample $opts(-sample) }
    set partition ""
    if {[info exists opts(-partition)]} { set partition $opts(-partition) }

    # Time unit info
    set tu [lindex [get_attribute [get_libs *] time_unit -quiet] 0]
    puts "INFO: Library time unit: $tu"

    # Get mclk_pll cycle time
    set mclk_period ""
    if {[catch {
        set mclk_period [get_attribute [get_clocks mclk_pll -quiet] period -quiet]
        if {$mclk_period ne "" && $mclk_period == int($mclk_period)} {
            set mclk_period [expr {int($mclk_period)}]
        }
    }]} { set mclk_period "N/A" }
    if {$mclk_period eq ""} { set mclk_period "N/A" }
    puts "INFO: mclk_pll period: $mclk_period"

    # Get leaf cells — scoped to partition if specified
    if {$partition ne ""} {
        puts "INFO: Scoping to partition: $partition"
        set all_cells [get_cells -hierarchical -filter "full_name=~${partition}/* && is_hierarchical==false" -quiet]
    } else {
        set all_cells [get_cells * -hier -filter "is_hierarchical==false" -quiet]
    }
    set n_total [sizeof_collection $all_cells]
    puts "INFO: Total leaf cells: $n_total"

    # Build ref_name histogram (bulk attribute fetch — fast)
    puts "INFO: Building cell type histogram..."
    set all_refs [get_attribute $all_cells ref_name]
    array set cnt {}
    foreach r $all_refs { incr cnt($r) }
    set types [lsort [array names cnt]]
    puts "INFO: Unique cell types: [llength $types]"

    set fh [open $outfile w]
    puts $fh "ref_name,cell_type,vt,voltage,mclk_period,count,arc,edge,measured,avg_delay,min_delay,max_delay"

    set n_types [llength $types]
    set i 0
    set n_with_data 0

    foreach ref $types {
        incr i
        if {$i % 50 == 0 || $i > $n_types - 20} { puts "INFO: Processing $i / $n_types: $ref ..." }

        set cells [filter_collection $all_cells "ref_name==$ref"]
        set n [sizeof_collection $cells]

        # Get VT type from ref_name (e.g., ...CPDULVT -> ulvt, ...CPDLVT -> lvt)
        set vt "unknown"
        set ref_upper [string toupper $ref]
        foreach vt_pat {ULVTLL ULVT ELVT LVT SVT HVT} {
            if {[string match "*${vt_pat}*" $ref_upper] || [string match "*${vt_pat}" $ref_upper]} {
                set vt [string tolower $vt_pat]
                break
            }
        }

        # Classify cell function type from ref_name
        set cell_type "complex"
        if {[regexp -nocase {^BUFF|^BUF|^DEL|^DCCKBD|^CKNBD} $ref]} {
            set cell_type "buffer"
        } elseif {[regexp -nocase {^INV|^CKND|^DCCKN} $ref]} {
            set cell_type "inverter"
        } elseif {[regexp -nocase {^NAND|^ND} $ref]} {
            set cell_type "nand"
        } elseif {[regexp -nocase {^NOR|^NR} $ref]} {
            set cell_type "nor"
        } elseif {[regexp -nocase {^AND} $ref]} {
            set cell_type "and"
        } elseif {[regexp -nocase {^OR} $ref]} {
            set cell_type "or"
        } elseif {[regexp -nocase {^XOR|^XNOR|^XNR} $ref]} {
            set cell_type "xor"
        } elseif {[regexp -nocase {^AOI|^AIOI} $ref]} {
            set cell_type "aoi"
        } elseif {[regexp -nocase {^OAI|^OIAI} $ref]} {
            set cell_type "oai"
        } elseif {[regexp -nocase {^MUX|^MX} $ref]} {
            set cell_type "mux"
        } elseif {[regexp -nocase {^DFF|^SDFF|^EDFK|^SEDF|^FD} $ref]} {
            set cell_type "flop"
        } elseif {[regexp -nocase {^LATCH|^LH|^LD} $ref]} {
            set cell_type "latch"
        } elseif {[regexp -nocase {^TIE} $ref]} {
            set cell_type "tie"
        } elseif {[regexp -nocase {^AN} $ref]} {
            set cell_type "and"
        }

        # Get operating voltage from the library
        set voltage ""
        if {[catch {
            set first_cell [index_collection $cells 0]
            set lib_obj [get_libs -of_objects [get_lib_cells -of_objects $first_cell -quiet] -quiet]
            set voltage [get_attribute $lib_obj default_operating_conditions.voltage -quiet]
            if {$voltage eq ""} {
                set voltage [get_attribute $lib_obj voltage -quiet]
            }
        }]} {}
        if {$voltage eq ""} { set voltage "N/A" }

        if {$n > $max_sample} {
            set cells [index_collection $cells 0 [expr {$max_sample - 1}]]
        }

        # Collect delays per arc+edge: key = "from_pin_name->to_pin_name:rise|fall"
        array unset arc_delays
        array set arc_delays {}

        foreach_in_collection cell $cells {
            set cell_name [get_attribute $cell full_name]

            set arcs [get_timing_arcs -of_objects $cell -quiet]
            if {[sizeof_collection $arcs] == 0} continue
            if {[sizeof_collection $arcs] > 10} continue

            # Track arcs already processed for this cell (avoid duplicate pin pairs)
            array unset seen_arcs
            array set seen_arcs {}

            foreach_in_collection arc $arcs {
                set from_pin [get_attribute $arc from_pin -quiet]
                set to_pin   [get_attribute $arc to_pin -quiet]
                if {$from_pin eq "" || $to_pin eq ""} continue

                set from_name [get_attribute $from_pin full_name -quiet]
                set to_name   [get_attribute $to_pin full_name -quiet]

                # Skip if already processed this pin pair
                set pair_key "${from_name}::${to_name}"
                if {[info exists seen_arcs($pair_key)]} continue
                set seen_arcs($pair_key) 1

                # Extract pin-level names (strip hierarchy)
                set from_short [lindex [split $from_name "/"] end]
                set to_short   [lindex [split $to_name "/"] end]
                set arc_name "${from_short}->${to_short}"

                if {[catch {
                    redirect -variable rpt_str {
                        report_delay_calculation -from $from_name -to $to_name
                    }
                }]} {
                    continue
                }

                # Parse first "Cell delay = <rise_val> <fall_val>" line only
                foreach line [split $rpt_str "\n"] {
                    if {[regexp -nocase {^\s*Cell delay\s+=\s+([\d.eE\+\-]+)\s+([\d.eE\+\-]+)} $line -> rise_val fall_val]} {
                        if {[string is double -strict $rise_val] && $rise_val > 0} {
                            lappend arc_delays(${arc_name}:rise) $rise_val
                        }
                        if {[string is double -strict $fall_val] && $fall_val > 0} {
                            lappend arc_delays(${arc_name}:fall) $fall_val
                        }
                        break
                    }
                }
            }
        }

        # Write one CSV row per arc+edge
        set has_data 0
        foreach key [lsort [array names arc_delays]] {
            set has_data 1
            set vals $arc_delays($key)

            # Parse key: "A->Y:rise"
            regexp {^(.+):(\w+)$} $key -> arc_name edge

            set sum 0.0; set mn 1e30; set mx -1e30
            foreach d $vals {
                set sum [expr {$sum + $d}]
                if {$d < $mn} { set mn $d }
                if {$d > $mx} { set mx $d }
            }
            set avg [expr {$sum / [llength $vals]}]

            puts $fh [format "%s,%s,%s,%s,%s,%d,%s,%s,%d,%.6f,%.6f,%.6f" \
                $ref $cell_type $vt $voltage $mclk_period $cnt($ref) $arc_name $edge [llength $vals] $avg $mn $mx]
        }

        if {$has_data} { incr n_with_data }

        if {$i % 50 == 0 && $has_data} {
            puts "INFO:   $ref: $cnt($ref) instances, [llength [array names arc_delays]] arcs"
        }
    }

    close $fh
    puts "INFO: Done. $n_with_data cell types with data written to $outfile"
}

define_proc_attributes report_cell_type_delays \
    -info "Report average delay per cell type and arc using report_delay_calculation" \
    -define_args {
        {-output    "Output CSV file path" "" string required}
        {-sample    "Max instances to sample per type (default: 20)" "" int optional}
        {-partition "Scope to partition hierarchy (e.g., icore0/par_meu)" "" string optional}
    }

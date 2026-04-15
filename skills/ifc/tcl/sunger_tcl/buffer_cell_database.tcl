# buffer_cell_database.tcl
# Creates a database of all buffer-like cells with average delays from actual instances
#
# Cell families included:
#   BUFF*  - data buffers (BUFFD, BUFFSR2, BUFFSKF, BUFFSKR, BUFFREPM, BUFFBBOX, etc.)
#   INV*   - inverters (INVD, INVSKF, INVSKFO, INVSKR, INVSKRO, INVREP, etc.)
#   CKB*   - clock buffers (CKBD, CKBDH, CKBSLOW)
#   CKN*   - clock inverters (CKND, CKNDH, CKND2)
#   DCCK*  - DC-coupled clock buffers
#   DEL*   - delay cells (DELA-DELG)
#
# Usage in PT:
#   source /nfs/site/disks/gilkeren_wa/copilot/scripts/buffer_cell_database.tcl
#   build_buffer_database
#   build_buffer_database -output /path/to/output.csv
#
# Output CSV columns:
#   ref_name, func, type, vt_class, drive_strength, instance_count,
#   arc_count, avg_rise_delay_ps, avg_fall_delay_ps,
#   min_rise_delay_ps, max_rise_delay_ps,
#   min_fall_delay_ps, max_fall_delay_ps

# =====================================================================
#  Helper: compute mean/min/max of a numeric list
# =====================================================================
proc _buf_db_stats {values} {
    set n [llength $values]
    if {$n == 0} {return [list 0.0 0.0 0.0 0]}
    set sum 0.0
    set vmin 1e30
    set vmax -1e30
    set valid 0
    foreach v $values {
        if {![string is double -strict $v]} continue
        set sum [expr {$sum + $v}]
        if {$v < $vmin} {set vmin $v}
        if {$v > $vmax} {set vmax $v}
        incr valid
    }
    if {$valid == 0} {return [list 0.0 0.0 0.0 0]}
    set mean [expr {$sum / $valid}]
    return [list $mean $vmin $vmax $valid]
}

# =====================================================================
#  Helper: extract VT class from cell ref_name
# =====================================================================
proc _buf_db_vt {ref} {
    if {[regexp {(ULVTLL|ULVT|LVTLL|LVT|SVT|HVT)$} $ref -> vt]} {
        return $vt
    }
    return "unknown"
}

# =====================================================================
#  Helper: extract drive strength (D<N> before BWP)
# =====================================================================
proc _buf_db_drive {ref} {
    if {[regexp {D(\d+)BWP} $ref -> d]} {
        return $d
    }
    if {[regexp {D(\d+)} $ref -> d]} {
        return $d
    }
    return "?"
}

# =====================================================================
#  Helper: extract cell function type (e.g., BUFFD, INVD, CKBD, DELA, etc.)
# =====================================================================
proc _buf_db_func {ref} {
    # Match up to the drive strength D<N>BWP marker
    if {[regexp {^([A-Z0-9]+?)D\d+BWP} $ref -> func]} {
        return $func
    }
    if {[regexp {^([A-Z]+)} $ref -> func]} {
        return $func
    }
    return $ref
}

# =====================================================================
#  Main procedure
# =====================================================================
proc build_buffer_database {args} {
    # Parse arguments
    set output_file ""
    set delay_type ""
    set ref_filter ""

    for {set i 0} {$i < [llength $args]} {incr i} {
        set arg [lindex $args $i]
        switch -- $arg {
            -output {
                incr i
                set output_file [lindex $args $i]
            }
            -delay_type {
                incr i
                set delay_type [lindex $args $i]
            }
            -ref {
                incr i
                set ref_filter [lindex $args $i]
            }
        }
    }

    # Defaults
    if {$output_file eq ""} {
        set output_file "$::ivar(rpt_dir)/buffer_cell_database.csv"
    }
    if {$delay_type eq ""} {
        set delay_type $::ivar(sta,delay_type)
    }

    puts "============================================="
    puts " Buffer Cell Database Builder"
    puts "============================================="
    puts " Output    : $output_file"
    puts " Delay type: $delay_type"
    if {$ref_filter ne ""} {
        puts " Filter    : $ref_filter"
    }
    puts "---------------------------------------------"

    # Determine attribute names based on delay type
    if {$delay_type eq "max"} {
        set rise_attr "delay_max_rise"
        set fall_attr "delay_max_fall"
    } else {
        set rise_attr "delay_min_rise"
        set fall_attr "delay_min_fall"
    }

    # ─── Step 1: Collect all buffer-like cells ───
    puts "\n\[1/3\] Collecting buffer-like cells..."
    set t0 [clock seconds]

    if {$ref_filter ne ""} {
        # Single ref_name filter mode
        set all_cells [get_cells -hier -filter "ref_name=~${ref_filter}" -quiet]
        puts "  Filter '$ref_filter' : [sizeof_collection $all_cells] instances"
    } else {
        set buf_cells  [get_cells -hier -filter {ref_name=~BUFF*}  -quiet]
        set inv_cells  [get_cells -hier -filter {ref_name=~INV*}   -quiet]
        set ckb_cells  [get_cells -hier -filter {ref_name=~CKB*}   -quiet]
        set ckn_cells  [get_cells -hier -filter {ref_name=~CKN*}   -quiet]
        set dcck_cells [get_cells -hier -filter {ref_name=~DCCK*}  -quiet]
        set del_cells  [filter_collection [get_cells -hier -filter {ref_name=~DEL*} -quiet] "ref_name=~DELA* || ref_name=~DELB* || ref_name=~DELC* || ref_name=~DELD* || ref_name=~DELE* || ref_name=~DELF* || ref_name=~DELG*"]

        set n_buf  [sizeof_collection $buf_cells]
        set n_inv  [sizeof_collection $inv_cells]
        set n_ckb  [sizeof_collection $ckb_cells]
        set n_ckn  [sizeof_collection $ckn_cells]
        set n_dcck [sizeof_collection $dcck_cells]
        set n_del  [sizeof_collection $del_cells]
        puts "  BUFF instances : $n_buf"
        puts "  INV  instances : $n_inv"
        puts "  CKB  instances : $n_ckb"
        puts "  CKN  instances : $n_ckn"
        puts "  DCCK instances : $n_dcck"
        puts "  DEL  instances : $n_del"

        set all_cells $buf_cells
        foreach col [list $inv_cells $ckb_cells $ckn_cells $dcck_cells $del_cells] {
            if {[sizeof_collection $col] > 0} {
                set all_cells [add_to_collection $all_cells $col]
            }
        }
    }
    puts "  Time: [expr {[clock seconds] - $t0}]s"

    # ─── Step 2: Get unique ref_names ───
    puts "\n\[2/3\] Extracting unique cell types..."
    set t1 [clock seconds]

    set all_refs [lsort -unique [get_attribute $all_cells ref_name]]
    set n_refs [llength $all_refs]
    puts "  Unique cell types: $n_refs"
    puts "  Time: [expr {[clock seconds] - $t1}]s"

    # ─── Step 3: Compute delays per cell type ───
    puts "\n\[3/3\] Computing delays per cell type..."
    set t2 [clock seconds]

    set fp [open $output_file w]
    puts $fp "ref_name,func,type,vt_class,drive_strength,instance_count,arc_count,avg_rise_delay_ps,avg_fall_delay_ps,min_rise_delay_ps,max_rise_delay_ps,min_fall_delay_ps,max_fall_delay_ps"

    set idx 0
    set skipped 0
    foreach ref $all_refs {
        incr idx

        # Classify cell
        if {[string match CKB* $ref]} {
            set type "CK_BUF"
        } elseif {[string match CKN* $ref]} {
            set type "CK_INV"
        } elseif {[string match DCCK* $ref]} {
            set type "CK_BUF"
        } elseif {[string match DEL* $ref]} {
            set type "DELAY"
        } elseif {[string match INV* $ref]} {
            set type "INV"
        } else {
            set type "BUF"
        }
        set vt   [_buf_db_vt $ref]
        set drive [_buf_db_drive $ref]
        set func  [_buf_db_func $ref]

        # Get cells of this type
        set cells [get_cells -hier -filter "ref_name==$ref" -quiet]
        set count [sizeof_collection $cells]

        if {$count == 0} {
            incr skipped
            continue
        }

        # Get combinational timing arcs (data arcs, not constraint arcs)
        set arcs [get_timing_arcs -of_objects $cells -quiet]
        set n_arcs [sizeof_collection $arcs]

        if {$n_arcs == 0} {
            puts $fp "$ref,$func,$type,$vt,$drive,$count,0,N/A,N/A,N/A,N/A,N/A,N/A"
            if {$idx % 20 == 0 || $idx == $n_refs} {
                puts "  \[$idx/$n_refs\] $ref: $count inst, 0 arcs (skipped)"
            }
            continue
        }

        # Bulk query delays
        set rise_delays [get_attribute $arcs $rise_attr]
        set fall_delays [get_attribute $arcs $fall_attr]

        # Compute stats
        lassign [_buf_db_stats $rise_delays] r_mean r_min r_max r_valid
        lassign [_buf_db_stats $fall_delays] f_mean f_min f_max f_valid

        puts $fp [format "%s,%s,%s,%s,%s,%d,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f" \
            $ref $func $type $vt $drive $count $n_arcs \
            $r_mean $f_mean $r_min $r_max $f_min $f_max]

        # Progress every 20 cell types or at the end
        if {$idx % 20 == 0 || $idx == $n_refs} {
            set elapsed [expr {[clock seconds] - $t2}]
            puts "  \[$idx/$n_refs\] $ref: $count inst, $n_arcs arcs (${elapsed}s)"
        }
    }

    close $fp

    set total_time [expr {[clock seconds] - $t0}]
    puts "\n============================================="
    puts " Done!"
    puts "  Cell types processed: [expr {$idx - $skipped}]"
    puts "  Skipped (0 instances): $skipped"
    puts "  Output: $output_file"
    puts "  Total time: ${total_time}s"
    puts "============================================="

    return $output_file
}

puts "Loaded: build_buffer_database"
puts "Usage:  build_buffer_database \[-output <file>\] \[-delay_type max|min\] \[-ref <pattern>\]"
puts "  -ref: filter to specific cell type, e.g. -ref BUFFD4* or -ref BUFFD1BWP156HPNPN3P48CPDLVT"
puts "Default output: \$ivar(rpt_dir)/buffer_cell_database.csv"

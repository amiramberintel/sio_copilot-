# Standalone FC script: open JNC nlib and extract all pin locations
# Run with: fc_shell -f fc_extract_standalone.tcl

puts "=== Opening JNC nlib ==="
set nlib "/nfs/site/disks/kknopp_wa/JNC/TIP/core_server.nlib"
open_lib $nlib -read
open_block icore -read
link_block

set outfile "/nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/jnc_pin_locations.csv"
set fd [open $outfile w]
puts $fd "signal,partition,pin_name,bbox_pct_x,bbox_pct_y,abs_x,abs_y,partition_llx,partition_lly,partition_urx,partition_ury"

set parts [get_cells -quiet -filter "is_soft_macro==true"]
puts "Found [sizeof_collection $parts] partitions"

set count 0
foreach_in_collection cell $parts {
    set cell_name [get_attribute $cell full_name]
    set bbox [get_attribute $cell boundary_bbox]
    set bbox_ll_x [lindex [lindex $bbox 0] 0]
    set bbox_ll_y [lindex [lindex $bbox 0] 1]
    set bbox_ur_x [lindex [lindex $bbox 1] 0]
    set bbox_ur_y [lindex [lindex $bbox 1] 1]
    set bbox_w [expr {$bbox_ur_x - $bbox_ll_x}]
    set bbox_h [expr {$bbox_ur_y - $bbox_ll_y}]
    
    puts "Partition: $cell_name  bbox: \[$bbox_ll_x $bbox_ll_y\] \[$bbox_ur_x $bbox_ur_y\]"
    
    set pins [get_pins -quiet -of_objects $cell]
    foreach_in_collection pin $pins {
        set pin_name [get_attribute $pin full_name]
        set location [get_attribute -quiet $pin location]
        if {$location eq ""} continue
        
        set x [lindex $location 0]
        set y [lindex $location 1]
        
        if {$bbox_w > 0 && $bbox_h > 0} {
            set pct_x [format %.3f [expr {($x - $bbox_ll_x) / $bbox_w * 100.0}]]
            set pct_y [format %.3f [expr {($y - $bbox_ll_y) / $bbox_h * 100.0}]]
        } else {
            set pct_x "0.000"
            set pct_y "0.000"
        }
        
        regexp {^[^/]+/(.+)$} $pin_name -> sig_name
        if {![info exists sig_name]} { set sig_name $pin_name }
        
        puts $fd "$sig_name,$cell_name,$pin_name,$pct_x,$pct_y,[format %.5f $x],[format %.5f $y],[format %.5f $bbox_ll_x],[format %.5f $bbox_ll_y],[format %.5f $bbox_ur_x],[format %.5f $bbox_ur_y]"
        incr count
        unset -nocomplain sig_name
    }
}

close $fd
puts "\n=== DONE: Wrote $count pin locations to $outfile ==="
close_lib
exit

#================================================================
# JNC TIP: Extract pin locations for all cross-partition signals
#
# USAGE: Source this in FC after opening the JNC nlib
#   source /nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/extract_pin_locations.tcl
#
# OUTPUT: /nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/jnc_pin_locations.csv
#   Format: signal,partition,pin_name,bbox_x,bbox_y,abs_x,abs_y
#================================================================

set outfile "/nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/jnc_pin_locations.csv"
set fd [open $outfile w]
puts $fd "signal,partition,pin_name,bbox_pct_x,bbox_pct_y,abs_x,abs_y"

# Get all soft macro pins (cross-partition pins)
set all_pins [get_pins -quiet -of_objects [get_cells -quiet -filter "is_soft_macro==true"] -filter "is_hierarchical==true && port.is_shadow==false"]

puts "Found [sizeof_collection $all_pins] cross-partition pins"

set count 0
foreach_in_collection pin $all_pins {
    set pin_name [get_attribute $pin full_name]
    set location [get_attribute $pin location]
    set x [lindex $location 0]
    set y [lindex $location 1]
    
    # Extract partition and signal name
    regexp {^([^/]+)/(.+)} $pin_name -> partition sig_name
    
    # Get partition bbox
    set cell [get_cells -quiet $partition]
    if {[sizeof_collection $cell] > 0} {
        set bbox [get_attribute $cell boundary_bbox]
        set bbox_ll_x [lindex [lindex $bbox 0] 0]
        set bbox_ll_y [lindex [lindex $bbox 0] 1]
        set bbox_ur_x [lindex [lindex $bbox 1] 0]
        set bbox_ur_y [lindex [lindex $bbox 1] 1]
        set bbox_w [expr {$bbox_ur_x - $bbox_ll_x}]
        set bbox_h [expr {$bbox_ur_y - $bbox_ll_y}]
        
        if {$bbox_w > 0 && $bbox_h > 0} {
            set pct_x [expr {($x - $bbox_ll_x) / $bbox_w * 100.0}]
            set pct_y [expr {($y - $bbox_ll_y) / $bbox_h * 100.0}]
        } else {
            set pct_x 0
            set pct_y 0
        }
    } else {
        set pct_x 0
        set pct_y 0
    }
    
    puts $fd "$sig_name,$partition,$pin_name,[format %.3f $pct_x],[format %.3f $pct_y],[format %.5f $x],[format %.5f $y]"
    incr count
}

close $fd
puts "Wrote $count pin locations to $outfile"

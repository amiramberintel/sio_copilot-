set out_dir [exec pwd]
set summary_rpt "$ivar(rpt_dir)/BBMinDelayBufferCountOnMaxTrace.rpt"
set detailed_rpt "$ivar(rpt_dir)/BBMinDelayBufferCountOnMaxTrace_detailed.rpt"
set pba path
#puts -nonewline "Enter the file path for the summary report(default : $summary_report): "
#flush stdout
#gets stdin summary_rpt
#if {$summary_rpt == ""} {
#	set summary_rpt $summary_report
#}
#puts -nonewline "Enter the file path for the detailed report(default : $detailed_report): "
#flush stdout
#gets stdin detailed_rpt
#if {$detailed_rpt == ""} {
#	set detailed_rpt $detailed_report
#}


# Remove old report files if they exist
foreach rpt [list "$summary_rpt" "$detailed_rpt"] {
    if {[file exists $rpt]} {
        puts "-I- File '$rpt' already exists. Removing previous report."
        file delete $rpt
    }
}

set path_id 0
set viol [list]

set CT [lindex [lsort -decreasing [get_attribute [get_clocks mclk_pll] period]] 0]
set limit [expr 0.05 * $CT]
puts "-I- Checking 200000 timing paths with -slack_lesser_than $limit for consecutive MDF buffers"

foreach_in_collection path [get_timing_paths -max_paths 200000 -pba_mode $pba -slack_lesser_than $limit -from [get_clocks mclk_*] -to [get_clocks mclk_*]] {
    set points [get_attribute -quiet $path points]
    set start_pin [get_attribute -quiet $path startpoint]
    set end_pin [get_attribute -quiet $path endpoint]
    set slack [get_attribute -quiet $path slack]
    set consec_count 0        
    set prev_mdf 0  	;# Flag to track if the previous element was an MDF buffer
    set b2b_occu 0  	;#To count how many times mdf buffer chains repeated in path
    set viol_count 0 	;#when >1 buffers are found in a path then it is set to 1
    foreach_in_collection arc $points {
        set pin [get_attribute -quiet $arc object]
        set direction [get_attribute -quiet $pin direction]
        set cell_name [get_attribute -quiet $pin cell.ref_name]
        
        # Check if the cell is an MDF buffer
        if {[string match "i0mbfm*" $cell_name]} {
            
            # Only increment if the buffer direction is 'in'
            if {$prev_mdf && $direction eq "in"} {
                incr consec_count
		if {$consec_count == 1} {incr b2b_occu}
		if {$consec_count >= 1} {set viol_count 1}
            }
            
            # Set prev_mdf to 1 as this is an MDF buffer
            set prev_mdf 1  
        } else {
            # Reset prev_mdf when encountering a non-MDF buffer
            set prev_mdf 0
	    set consec_count 0
	    
        }
    }
    
    # If consecutive count is 1 or more, log violation
    if {$b2b_occu > 0 && $viol_count} {
        incr path_id
        lappend viol "$path_id\t[get_object_name $start_pin]\t[get_object_name $end_pin]\t$b2b_occu\t$slack"
        echo "Path Id $path_id" >> $detailed_rpt
        report_timing -from $start_pin -to $end_pin -input -net -pba_mode $pba >> $detailed_rpt
        echo "   - - - - END OF PATH - - - -\n" >> $detailed_rpt
    }
}

# Create the summary report
set FH [open $summary_rpt w]
puts $FH "#Path_Id\tStart_Point\tEnd_Point\tBb_mdf_occ\tSlack"
foreach line [lsort -index 3 -integer -decreasing $viol] {
    puts $FH $line
}
close $FH

puts "-I- Final report with consecutive MDF buffers count > 1: $summary_rpt"
puts "-I- Detailed path trace for violated paths: $detailed_rpt"

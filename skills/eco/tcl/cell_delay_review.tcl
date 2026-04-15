proc bi_histogram_tran { bins vector {accum 0} } { 
    if { [regexp {\.} $vector] } {
        set sorted_vector [lsort -real -increasing $vector]
    } else {
        set sorted_vector [lsort -integer -increasing $vector]
    }

    array unset accum_bins_arr
    array unset bins_arr
    set prev_number 0

    foreach bin $bins {
        set index [lsearch -real -sorted -bisect $sorted_vector $bin]
        set number [expr {$index+1}]
        set accum_bins_arr($bin) $number
        set bins_arr($bin) [expr {$number-$prev_number}]
        set prev_number $number
    }

    set i 0
    foreach bin $bins {
        if { $i==0 } {
            set prev_bin " "
        } else {
            set prev_bin [lindex $bins [expr {$i-1}]]
        }
        if { $accum==1 } {
            puts $accum_bins_arr($bin),
        } else {
            puts $bins_arr($bin),
        }
        incr i
    }
}

set bins {0 2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32 34 36 38 40 42 44 46 48 50} 
echo "template,is_combinational,is_sequential,total,in_pin,out_pin,arch_avg,[regsub -all " " $bins ","] " > cell_delay_neg.csv
set templates [lsort -unique [get_attribute [get_cells -hierarchical -filter ref_name=~*i0m*] ref_name]]

foreach template $templates {
set cells [get_cells -quiet  -hierarchical -filter "ref_name==$template && pins.max_slack<0" ]
set in_pin [sizeof_collection [filter_collection [get_attribute [index_collection $cells 0 ] pins] direction==in]]
set out_pin [sizeof_collection [filter_collection [get_attribute [index_collection $cells 0 ] pins] direction==out]]

set is_sequential [get_attribute [index_collection $cells 0 ] is_sequential] 
set is_combinational [get_attribute [index_collection $cells 0 ] is_combinational]

set total [sizeof_collection $cells]
set arcs [get_timing_arcs -quiet -of_objects $cells]
set total_arcs [sizeof_collection $arcs] 
set arcs_delay [get_attribute -quiet $arcs delay_max ]
if {$total_arcs > 0 } { 
    set sum 0
    foreach i $arcs_delay {
        set sum [expr $sum + $i]
    }
    set arch_avg [expr $sum / $total_arcs] 
} else { 
    set arch_avg 0
}

redirect -var histogram {bi_histogram_tran $bins $arcs_delay } 
set histogram [regsub -all "\n" $histogram ""]
echo "$template,$is_combinational,$is_sequential,$total,$in_pin,$out_pin,$arch_avg,$histogram"  >> cell_delay_neg.csv
}

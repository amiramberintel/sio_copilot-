proc bi_check_port_location {ports file_name} {
    set threshold 0 
    file delete $file_name
    set f [open $file_name w]
    puts $f "port,x_port,y_port,x_min,y_min,x_max,y_max,avg_x_min,avg_y_min,avg_x_max,avg_y_max,distance_global,distance_avg"
    foreach_in_collection port [get_pins $ports]  {
        set fos_list [filter_collection [all_fanout -flat -trace_arcs all -endpoints_only -from $port ] full_name!~*_dft/*]
        set fis_list [filter_collection [all_fanin  -flat -trace_arcs all -startpoints_only -to $port ] full_name!~*_dft/*]
    
        if { [sizeof_collection $fos_list ] == 0  || [sizeof_collection $fis_list ]==0 } {
            continue
        }

        set fos_x_list [lsort -increasing -dictionary [get_attribute -quiet $fos_list x_coordinate]]
        set fos_y_list [lsort -increasing -dictionary [get_attribute -quiet $fos_list y_coordinate]]
        set fis_x_list [lsort -increasing -dictionary [get_attribute -quiet $fis_list x_coordinate]]
        set fis_y_list [lsort -increasing -dictionary [get_attribute -quiet $fis_list y_coordinate]]
        if { [llength $fos_x_list ] > 0 && [llength $fos_y_list ] > 0 && [llength $fis_x_list ] > 0 && [llength $fis_y_list ] > 0 } {
            set fos_x_center [expr [expr [bi_lsum $fos_x_list ] / [llength $fos_x_list ] ]  / 1000 ]
            set fos_y_center [expr [expr [bi_lsum $fos_y_list ] / [llength $fos_y_list ] ]  / 1000 ]
            set fis_x_center [expr [expr [bi_lsum $fis_x_list ] / [llength $fis_x_list ] ]  / 1000 ]
            set fis_y_center [expr [expr [bi_lsum $fis_y_list ] / [llength $fis_y_list ] ]  / 1000 ]
        } else {
        
        }
        set x_list [lsort -increasing -dictionary  [concat $fos_x_list $fis_x_list ] ]
        set y_list [lsort -increasing -dictionary  [concat $fos_y_list $fis_y_list ] ]

        set port_x [get_attribute -quiet [get_pins -quiet $port] x_coordinate] 
        set port_y [get_attribute -quiet [get_pins -quiet $port] y_coordinate]
        if { $port_x == "" || $port_y == "" } {
            puts $f "[get_object_name [get_pins $port] ],can't locate the port"
            continue 
        } else {
            set port_x_scale [expr $port_x / 1000 ]
            set port_y_scale [expr $port_y / 1000 ]
        }
        
        set max_x [expr [lindex $x_list end] / 1000 ] 
        set min_x [expr [lindex $x_list 0] / 1000]
        set max_y [expr [lindex $y_list end] / 1000 ]
        set min_y [expr [lindex $y_list 0] / 1000]
        set min_x_avg [lindex [lsort -increasing -dictionary  [concat $fos_x_center $fis_x_center ] ] 0]
        set max_x_avg [lindex [lsort -increasing -dictionary  [concat $fos_x_center $fis_x_center ] ] end] 
        set min_y_avg [lindex [lsort -increasing -dictionary  [concat $fos_y_center $fis_y_center ] ] 0]
        set max_y_avg [lindex [lsort -increasing -dictionary  [concat $fos_y_center $fis_y_center ] ] end] 

        set port_inside_global_box 0 
        if {$min_x < $port_x_scale + $threshold && $port_x_scale- $threshold< $max_x && $min_y< $port_y_scale+ $threshold && $port_y_scale-$threshold<$max_y} {
        } else {
            if {$min_x > $port_x_scale + $threshold } {set port_inside_global_box [expr $min_x - $port_x_scale] } 
            if {$port_x_scale- $threshold > $max_x } {set port_inside_global_box [expr $port_x_scale - $max_x ] }
            if {$min_y > $port_y_scale+ $threshold } {set port_inside_global_box [expr $min_y - $port_y_scale ] } 
            if {$port_y_scale-$threshold>$max_y}     {set port_inside_global_box [expr $port_y_scale - $max_y ] }
        }
       
        set port_inside_avg_box 0 
        if {$min_x_avg < $port_x_scale + $threshold && $port_x_scale- $threshold< $max_x_avg && $min_y_avg< $port_y_scale+ $threshold && $port_y_scale-$threshold<$max_y_avg} {
        } else {
            if {$min_x_avg > $port_x_scale + $threshold } {set port_inside_avg_box [expr $min_x_avg - $port_x_scale] } 
            if {$port_x_scale- $threshold > $max_x_avg } {set port_inside_avg_box [expr $port_x_scale - $max_x_avg ] }
            if {$min_y_avg > $port_y_scale+ $threshold } {set port_inside_avg_box [expr $min_y_avg - $port_y_scale ] } 
            if {$port_y_scale-$threshold>$max_y_avg}     {set port_inside_avg_box [expr $port_y_scale - $max_y_avg ] }
        }
        
        if { $port_inside_global_box > $threshold || $port_inside_avg_box > $threshold   } { 
            puts $f  "[get_object_name [get_pins $port] ],$port_x_scale,$port_y_scale,$min_x,$min_y,$max_x,$max_y,$min_x_avg,$min_y_avg,$max_x_avg,$max_y_avg,$port_inside_global_box,$port_inside_avg_box"
        }

    }
    close $f
    echo "report is at $file_name"
}
bi_check_port_location [get_pins {icore0/par*/* par_*/*}] port_location.rpt
set bin {0 10 20 30 50 100 200 300}
set final_resutls ",[regsub -all " " $bin "," ]\n"
foreach_in_collection par [get_cells {icore0/par* par_* } ] {
    set par_name [get_object_name $par ]
    set list [exec cat port_location.rpt | grep $par_name | sed "s/can't locate the port/-1/g" |  awk -F "," {{print $NF}}]
    redirect -variable total {bi_histogram $bin $list }
    set line [regsub -all " " [regsub -all "\n" [regsub -all {[^\n]*<[^ ][^ ]* } $total {}] ","] ""]
    redirect -append -var final_resutls {echo "$par_name,$line"}
}

echo ""
exec echo $final_resutls | column -t -s "," -o " | " 

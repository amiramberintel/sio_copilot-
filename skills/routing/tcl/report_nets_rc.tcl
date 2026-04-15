#usage:
#set paths [get_timing_paths -normalized_slack -from [get_clocks mclk_*] -to [get_clocks mclk_*] -pba none -max_paths 100000]
#report_nets_rc $paths 2.0 rc_nets_nwors1.csv

proc report_nets_rc {paths {rc_threshold 2.0} {outfile "rc_nets.csv"}} {
    foreach_in_collection path $paths {
        set prevPinName ""
        set prevObjectName ""
        set prevRefName ""
        set prevTransition 0.0
        set distance ""

        set slack [get_attribute $path slack]
        set normalized_slack [get_attribute -quiet $path normalized_slack]
        foreach_in_collection point [get_attribute $path points] {
            set object [get_attribute $point object]
            set pinName [get_object_name $object]
	    if {$prevPinName != ""} {
	    set distance [disp_quiet $pinName $prevPinName]
	    }	 
            set transition [get_attribute $point transition]
            if {[get_attribute $object object_class] == "port"} {
                set objectName "port:[get_object_name $object]"
                set refName "port"
            } else {
                set cell [get_cells -of $object]
                set objectName [get_object_name $cell]
                set refName [get_attribute $cell ref_name]
            }
            if {$prevObjectName != $objectName} {
                if {[get_app_var timing_pocvm_enable_analysis]} {
                    if {[get_app_var timing_pocvm_extended_moments_totals_combine_mean_shift]} {
                        set delay [get_attribute $point variation_increment.mean]
                    } else {
                        set delay [get_attribute $point variation_increment.nominal]
                    }
                } else {
                    set delay [get_attribute $point arrival]            
                }
                if {$delay >= $rc_threshold} {
                    if {[set xtalk [get_attribute -quiet $point annotated_delay_delta]] == ""} {
                        set xtalk 0.0
                    }                    
                    set net [get_nets -of $object -segments -top]
                    set wire_cap [get_attribute $net wire_capacitance_max]
                    set pin_cap [get_attribute $net pin_capacitance_max]
                    set key "$prevPinName,$pinName,[get_object_name $net]"
                    if {![info exists net_delay($key)]} {
                        set net_delay($key) "$prevRefName,$wire_cap,$pin_cap,$delay,$distance,$xtalk,$prevTransition,$transition,$slack,$normalized_slack"
                        set net_nworst($key) 1
                    } else {
                        incr net_nworst($key)
                    }
                }
            }
            set prevObjectName $objectName
            set prevPinName $pinName
            set prevRefName $refName
            set prevTransition $transition
        }
    }
    set fout [open $outfile "w"]
    puts $fout "1.from_pin,2.to_pin,3.net,4.driver_cell,5.wire_cap,6.pin_cap,7.net_delay,8.distance,9.xtalk,10.drv_trans,11.rcv_trans,12.slack,13.normalized_slack,14.nworst"
    foreach {key value} [array get net_delay] {
        puts $fout "$key,$value,$net_nworst($key)"
    }
    close $fout
}


proc disp_quiet {obj1 obj2} {

    set x1 [get_attribute -quiet [get_pin_or_port $obj1] x_coordinate]
    set y1 [get_attribute -quiet [get_pin_or_port $obj1] y_coordinate]
    if {$x1 == "" || $y1 == ""} {return -999}

    set x1_scale [format "%0.2f" [expr  $x1/ 1000]]
    set y1_scale [format "%0.2f" [expr  $y1/ 1000]]

    set x2 [get_attribute -quiet [get_pin_or_port $obj2] x_coordinate]
    set y2 [get_attribute -quiet [get_pin_or_port $obj2] y_coordinate]
    if {$x2 == "" || $y2 == ""} {return -999}

    set x2_scale [format "%0.2f" [expr  $x2/ 1000]]
    set y2_scale [format "%0.2f" [expr  $y2/ 1000]]

     set dx  [format "%0.2f" [expr abs($x1_scale-$x2_scale)]];
     set dy  [format "%0.2f" [expr abs($y1_scale-$y2_scale)]];
     set dis [format "%0.2f" [expr $dx + $dy]]
     return $dis
}

proc get_pin_or_port {args} {
if {![regexp {\/} $args]} {
get_ports $args
} else {
get_pins $args
}
}


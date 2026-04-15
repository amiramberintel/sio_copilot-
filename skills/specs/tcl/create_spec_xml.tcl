proc create_spec_xml {par pin clk edge nom_dly hv_dly nom_file hv_file app_bu} {

#set pp [string range $par 4 [string length $par]]

set pin_col [get_pins -quiet $par/$pin -filter full_name!~*FEEDTHRU*]

if {[sizeof_collection $pin_col] == 0} {puts "$pin is not in $par"}

set hv_delay $hv_dly
set nom_delay $nom_dly
if {$edge == "R"} {set clock_edge Rise} else {
    if {$edge == "r"} {set clock_edge Rise} else {
	if {$edge == "F"} {set clock_edge Fall} else {
	    if {$edge == "f"} {set clock_edge Fall} else {
		puts "" ; puts "edge must be R/r/F/f" ; puts ""
	    }
	}
    }
}


foreach_in_collection p $pin_col {
set b [lindex [split [get_object_name $p] "/"] 0]
set a [lindex [split [get_object_name $p] "/"] 1]
puts $nom_file "<net dir=\"\" disableInBU=\"0\" applySpecOnBU=\"$app_bu\" lockDelay=\"0\" lbForward=\"0\" par=\"$b\" pin=\"$a\" related_clk_latency=\"\" related_clk_port=\"\" rollup_mode=\"\" spec=\"$nom_delay\" spec_clock=\"${clk}\" spec_edge=\"$clock_edge\" />"
puts $hv_file "<net dir=\"\" disableInBU=\"0\" applySpecOnBU=\"$app_bu\" lockDelay=\"0\" lbForward=\"0\" par=\"$b\" pin=\"$a\" related_clk_latency=\"\" related_clk_port=\"\" rollup_mode=\"\" spec=\"$hv_delay\" spec_clock=\"${clk}\" spec_edge=\"$clock_edge\" />"
}

}

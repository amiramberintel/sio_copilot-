set fileh [open uc.bu.with_drv_rcv.txt w]
foreach_in_collection p [get_pins par_*/*  -filter "direction==in"] {
set uc_port [get_object_name [get_pins -quiet $p]]
set drv [get_pins -quiet [get_pins -quiet [all_fanin -to [get_pins -quiet $p] -flat -level 1]  -filter "is_hierarchical==false && full_name !~ *DIODE*"] -filter "direction==out"]
if {[sizeof_collection $drv] > 0} {
	set drv_obj [get_object_name $drv]
} else {
	set drv_obj ""
}
set rcv [get_pins -quiet [get_pins -quiet [all_fanout -from [get_pins -quiet $p] -flat -level 1]  -filter "is_hierarchical==false && full_name !~ *DIODE*"] -filter "direction==in"]
if {[sizeof_collection $rcv] > 0} {
	set rcv_obj [get_object_name $rcv]
} else {
	set rcv_obj ""
}
set constant_case [get_attribute -quiet [get_pins -quiet $p] case_value]
puts $fileh "uc port: $uc_port ,drv: $drv_obj,rcv: $rcv_obj,constant_case: $constant_case"
}

close $fileh


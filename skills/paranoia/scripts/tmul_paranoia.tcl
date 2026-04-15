set tmul_out_pins [get_pins icore*/par_tmul/* -filter direction=="out"]
foreach_in_collection p $tmul_out_pins {
get_drv [get_object_name $p] 
}


proc get_drv {port_name} {
set p [get_pins $port_name]
set p_obj [get_object_name $p]
set drv [filter_collection [all_connected -leaf $p_obj] "direction==out"]
set template [get_attribute $drv lib_pin]
set template_obj [get_object_name [get_attribute $drv lib_pin]]
echo "$p_obj $template_obj"
}

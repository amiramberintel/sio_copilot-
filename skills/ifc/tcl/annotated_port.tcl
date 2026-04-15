proc annotet_port {port_name value} {
        global ivar
        set bus [get_pins -quiet $port_name]
        sizeof_collection $bus
        if {[sizeof_collection $bus] > 0} {
        foreach_in_collection port $bus {
                set port_name [ get_object_name $port ]
                set par [regsub "/.*" $port_name ""]
                set drv [get_pins -quiet [all_fanin -to [get_pins -quiet $port ] -flat -level 1] -filter {is_hierarchical==false && direction==out}]
                if {[sizeof_collection $drv] > 0} {
                        set buffer_name ${par}_[regsub -all "/" $port_name "_"]_sio_ovr_buffer
                        echo "insert_buffer -new_cell_names ${buffer_name} -new_net_names ${buffer_name} [get_object_name $drv] i0mbff000ab1n36x5" >> [pwd]/file_1_insert
                        } else {puts "no drv for $port_name"}
                                        }
        } else {puts "-I- didnt find any port with name $port_name"}
}

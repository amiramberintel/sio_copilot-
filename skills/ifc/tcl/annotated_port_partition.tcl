proc annotet_port {port_name value} {
        set bus [get_ports -quiet $port_name]
        sizeof_collection $bus
        if {[sizeof_collection $bus] > 0} {
        foreach_in_collection port $bus {
                set port_name [ get_object_name $port ]
                set port_dir [get_attribute -quiet $port direction]
                if {$port_dir == "out"} {
                        #set net [get_net -of_objects [get_pins -quiet [all_fanin -to [get_pins -quiet $port ] -flat -level 1] -filter {is_hierarchical==false && direction==out} ] ]
                        set drv [get_pins -quiet [all_fanin -to [get_ports -quiet $port ] -flat -level 1] -filter {is_hierarchical==false && direction==out}]
                        if {[sizeof_collection $drv] > 0} {
                                set buffer_name [regsub -all "/" [get_object_name $drv] "_"]_sio_ovr_buffer
                                echo "insert_buffer -new_cell_names ${buffer_name} -new_net_names ${buffer_name} [get_object_name $drv] BUFFSPSDHD16BWP169H3P45CPDULVT" >> file_1_insert_buffers
                                echo "set buffer_i \[get_pins -of_objects \[get_cells *${buffer_name} -hierarchical ] -filter {direction==in}]" >> file_2_annotated
                                echo "set buffer_o \[get_pins -of_objects \[get_cells *${buffer_name} -hierarchical ] -filter {direction==out}]" >> file_2_annotated
                                echo "set_annotated_delay $value -cell -from \${buffer_i} -to \${buffer_o}" >> file_2_annotated
                            } else {puts "no drv for $port_name"}
                } elseif {$port_dir == "in"} {
                        #set net [get_net -of_objects [get_pins -quiet [all_fanout -from [get_pins -quiet $port ] -flat -level 1] -filter {is_hierarchical==false && direction==in} ] ]
                        set rcvs [get_pins -quiet [all_fanout -from [get_ports -quiet $port ] -flat -level 1] -filter {is_hierarchical==false && direction==in}]
                        if {[sizeof_collection $rcvs] > 0} {
                                set i 0
                                foreach_in_collection rcv $rcvs {
                                        set buffer_name [regsub -all "/" [get_object_name $rcv] "_"]_${i}_sio_ovr_buffer
                                        echo "insert_buffer -new_cell_names ${buffer_name} -new_net_names ${buffer_name} [get_object_name $rcv] BUFFSPSDHD16BWP169H3P45CPDULVT" >> file_1_insert_buffers
                                        echo "set buffer_i \[get_pins -of_objects \[get_cells *${buffer_name} -hierarchical ] -filter {direction==in}]" >> file_2_annotated
                                        echo "set buffer_o \[get_pins -of_objects \[get_cells *${buffer_name} -hierarchical ] -filter {direction==out}]" >> file_2_annotated
                                        echo "set_annotated_delay $value -cell -from \${buffer_i} -to \${buffer_o}" >> file_2_annotated
                                        set i [expr $i + 1]
                                }
                        } else {puts "no rcvs for $port_name"}
                } else {
                    echo "error"
                }
                        }
        } else {puts "-I- didnt find any port with name $port_name"}
}


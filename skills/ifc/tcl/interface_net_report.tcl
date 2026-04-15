proc bi_interface_net_report { ports } {
    	echo "Port,Net,drv_ref_name,num drv,num rcv,net_factor,max_dist,net_delay,max_tran,norm WNS,WNS,num_path,TNS"

    	 foreach_in_collection port $ports {
		set recivers [get_pins -quiet [get_pins -quiet [all_fanout -from [get_pins -quiet $port] -flat -level 1] -filter "is_hierarchical==false"] -filter "direction==in"] 
	 	set drivers  [get_pins -quiet [get_pins -quiet [all_fanin -to [get_pins -quiet $port] -flat -level 1] -filter "is_hierarchical==false"] -filter "direction==out"]
		set max_dist_drv_port  0 
		foreach_in_collection drv $drivers {
		    set dist [ disp_quiet [get_object_name $drv] [get_object_name $port]  ] 
		    if {$dist > $max_dist_drv_port } {
			set max_dist_drv_port $dist
		    }
		}
		set max_dist_rcv_port  0
  		foreach_in_collection rcv $recivers {
		    set dist [ disp_quiet [get_object_name $rcv] [get_object_name $port]  ] 
		    if {$dist > $max_dist_rcv_port } {
			set max_dist_rcv_port $dist
		    }
		}

		set num_rcv  		[sizeof_collection $recivers ] 
		set num_drv  		[sizeof_collection $drivers ]  
		set max_dist 		[expr $max_dist_rcv_port + $max_dist_drv_port ]
		set max_net_delay 	[bi_lmax [get_attribute [get_timing_arcs -from $drivers -to $recivers -quiet ] delay_max  ] ]
		set max_tran_on_rcv 	[bi_lmax [get_attribute $recivers actual_transition_max ] ]
		set drv_ref_name 	[get_attribute [get_cells -of_object $drivers ] ref_name ]
		set net_factor 0
		if { $max_net_delay != "" } { 
			set net_factor 		[expr 100 * $max_net_delay / $max_dist ]
		}
		redirect -file /dev/null {set paths [gtp -th $port -to mclk_* -pba_mode path -slack_lesser_than 190 -norm ]  }
#            	set TNS [bi_lsum [ get_attribute  $paths  slack ]]
            	set TNS 0	
            	set WNS [lindex [ get_attribute  $paths  slack ]  0 ]
		set num_path [sizeof_collection $paths]
		set nor_WNS $WNS
		if { $num_path > 0 } {
			set nor_WNS [expr 190 * [lindex [ get_attribute  $paths  normalized_slack ]  0 ] ]
		}
            	set dir [get_attribute [get_pins $port ] direction]
		echo "[get_object_name $port],[get_object_name [get_nets -of_object $port]],$drv_ref_name,$num_drv,$num_rcv,$net_factor,$max_dist,$max_net_delay,$max_tran_on_rcv,$nor_WNS,$WNS,$num_path,$TNS"
	}
}

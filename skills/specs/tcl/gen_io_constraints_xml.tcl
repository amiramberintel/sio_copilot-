#if running for contour - need to make sure  /nfs/iil/home/gilkeren/lnc/io_constraints/user_xml/full_user_spec.tcl is update
#also need 
proc gen_io_constraints {corner1 par tag contour} {
  
    if {$corner1 == "highv"} {set corner func.max_high.TT_100.tttt}
    if {$corner1 == "nominal"} {set corner func.max.TT_100.tttt}

    if {$contour == 1} {
    source /nfs/iil/home/gilkeren/lnc/io_constraints/user_xml/full_user_spec.tcl
    } else {
    source ~$::env(USER)/lnc/io_constraints/create_user_spec_file_xml.tcl
    }
    
    set dir  "/nfs/iil/stod/stod901/w.gilkeren.102/lnc/fct/io_constraints"   
    catch {exec mkdir $dir/$tag}
    if {$contour == 1} {
    	if {$corner == "func.max_high.TT_100.tttt"} {set user_spec "~$::env(USER)/lnc/io_constraints/lncserver.func.max_high.TT_100.tttt_timing_specs.xml"}
	if {$corner == "func.max.TT_100.tttt"} {set user_spec "~$::env(USER)/lnc/io_constraints/lncserver.func.max.TT_100.tttt_timing_specs.xml"}
    } else {
	if {$corner == "func.max_high.TT_100.tttt"} {set user_spec "~$::env(USER)/lnc/io_constraints/hv_user_spec.xml"}
	if {$corner == "func.max.TT_100.tttt"} {set user_spec "~$::env(USER)/lnc/io_constraints/nom_user_spec.xml"}
    }
    set DBG [open $dir/$tag/gen_io_constraints_DBG_$corner.rpt w]
    set const_file [open $dir/$tag/gen_io_constraints_$corner.tcl w]
#    set no_const_file [open $dir/$tag/gen_io_constraints_missing_$corner.rpt w]
    set info [open $dir/$tag/gen_io_constraints_info_$corner.rpt w]
    set other_side [open $dir/$tag/gen_io_constraints_other_side_$corner.rpt w]
    set missing [open $dir/$tag/gen_io_constraints_missing_user_spec_$corner.rpt w]
    set clock_file [open $dir/$tag/gen_io_constraints_clocks_$corner.rpt w]
    
    file copy -force $user_spec $dir/$tag/

    # for debug
    set good_ports_col ""
    set all_ports_col ""
    set def_ports_col ""
    
    if {$corner == "func.max_high.TT_100.tttt"} {
#       set CT 212
        set CT 204
        #set UC 11.5
        set UC 28
        set flop2out 40
        set input2flop 20
        set GB 12
        set GLC_CT 226
        set GLC_avg_clk 40
        set tango_ref "/nfs/iil/proj/skl/fct_core_execution/fct/glcsrvr0p_TI_model/glc_io_constrains/glc.valid.report.filtered.highv"
        source /nfs/iil/disks/home01/gilkeren/scripts/tcl/gen_io_constraints_hv_vars.tcl

    }

    if {$corner == "func.max.TT_100.tttt"} {
#       set CT 346
        set CT 320
        #set UC 15.5
        set UC 45
        set flop2out 80
        set input2flop 40
        set GB 20
        set GLC_CT 386
        set GLC_avg_clk 70
        set tango_ref "/nfs/iil/proj/skl/fct_core_execution/fct/glcsrvr0p_TI_model/glc_io_constrains/glc.valid.report.filtered.nominal"
	source /nfs/iil/disks/home01/gilkeren/scripts/tcl/gen_io_constraints_nom_vars.tcl

    }

    
    if {$par == "all"} {
        set output_col [get_pins par_*/* -filter direction=~out]
    } else {
        set output_col [get_pins $par/* -filter direction=~out]
    }
    
    # create tango data
    array set tango_arr [parse_tango_valids $tango_ref]
    
    # create user spec data
    array set user_spec_arr [parse_user_spec $user_spec]
    
    array set exist_spec_arr ""
    array set missing_spec_arr ""
    
    puts $info "number of pins to run: [sizeof_collection $output_col]"
    
    # handle user spec first
    set user_spec_pin_col ""
    set other_side_spec ""
    set added_spec_arr ""
    set clock_pins ""

    foreach pin_name [array names user_spec_arr] {
        set pin_col [get_pins $pin_name]
        set clk [lindex $user_spec_arr($pin_name) 0]
        set clk_edge [lindex $user_spec_arr($pin_name) 1]
        set val [lindex $user_spec_arr($pin_name) 2]
	set ref_clock [lindex $user_spec_arr($pin_name) 3]
        foreach_in_collection p $pin_col {
	    set pin_dir [get_attribute  [get_pins $p] direction]
#puts "[get_object_name $p]"

            append_to_collection user_spec_pin_col $p
           
#puts "setting rcvs"
            set rcvs [get_pins -quiet -of [get_nets -of $p -top -seg -quiet] -filter direction=~in]
#puts "setting drvs"
            set drvs [get_pins -quiet -of [get_nets -of $p -top -seg -quiet] -filter direction=~out]

	switch $ref_clock {
		mclk {
	    		set budget [expr $mclk_ct-$mclk_uc]
		        set ck mclk_virtual
		}
		uclk {
	    		set budget [expr $uclk_ct-$uclk_uc]
		        set ck $ref_clock
		}
		dfx_secure_clk {
	    		set budget [expr $dfx_secure_clk_ct-$dfx_secure_clk_uc]
		        set ck $ref_clock
		}
		npkclk {
	    		set budget [expr $npkclk_ct-$npkclk_uc]
		        set ck $ref_clock
		}
		sbclk {
	    		set budget [expr $sbclk_ct-$sbclk_uc]
		        set ck $ref_clock
		}
	    	sbxclk {
	    		set budget [expr $sbxclk_ct-$sbxclk_uc]
		        set ck $ref_clock
		}
		tapclk {
	    		set budget [expr $tapclk_ct-$tapclk_uc]
		        set ck $ref_clock
		}
		visacfg {
	    		set budget [expr $visacfg_ct-$visacfg_uc]
		        set ck $ref_clock
		}
		xxtal {
	    		set budget [expr $xxtal_ct-$xxtal_uc]
		        set ck $ref_clock
		}
		default {
      			puts "Invalid ref_clock"
			puts "$ref_clock"
			return
   		}
	}
    		set delay [expr $budget-$val]

#            set drv_par_name [lindex [split [get_object_name $p] "/"] 0]
#            set drv_pin_name [lindex [split [get_object_name $p] "/"] 1]
            

#puts "setting par_name"
            set par_name [lindex [split [get_object_name $p] "/"] 0]
#puts "setting pin_name"
            set pin_name [lindex [split [get_object_name $p] "/"] 1]
#puts "setting set_output_delay"
	    if {$pin_dir == "out"} {
	            if {$clk_edge == "Rise"} {
	                puts $const_file "set_output_delay $delay -clock $ck \[get_ports $pin_name\] ;$par_name, user spec [get_object_name $p]"
	            } else {
	                puts $const_file "set_output_delay $delay -clock $ck -clock_fall \[get_ports $pin_name\] ;$par_name, user spec [get_object_name $p]"
	            }
            puts $info "-G drv- $par_name $pin_name" ; # for debug
	    puts $other_side "added spec on [get_object_name $p] (set_output_delay $delay), other side is $rcvs"
#puts "appending rcvs"

	    append_to_collection other_side_spec $rcvs
	    append_to_collection added_spec_arr $p

	    }
            
            
#            puts $info "-G drv- $drv_par_name $drv_pin_name" ; # for debug

#puts "setting set_input_delay"

	    if {$pin_dir == "in"} {
	            if {$clk_edge == "Rise"} {
	                puts $const_file "set_input_delay $delay -clock $ck \[get_ports $pin_name\] ;$par_name, user spec [get_object_name $p]"
	            } else {
	                puts $const_file "set_input_delay $delay -clock $ck -clock_fall \[get_ports $pin_name\] ;$par_name, user spec [get_object_name $p]"
	            }
            puts $info "-G rcv- $par_name $pin_name"
	    puts $other_side "added spec on [get_object_name $p] (set_input_delay $delay), other side is $drvs"
#puts "appending drvs"

	    append_to_collection other_side_spec $drvs
	    append_to_collection added_spec_arr $p   
	    }

#            foreach_in_collection rcv $rcvs {
#                set rcv_par_name [lindex [split [get_object_name $rcv] "/"] 0]
#                set rcv_pin_name [lindex [split [get_object_name $rcv] "/"] 1]
                
#                if {$clk_edge == "Rise"} {
#                    puts $const_file "set_input_delay [expr $CT-$output_delay+$GB] -clock mclk \[get_ports $rcv_pin_name\] ;$rcv_par_name, user spec [get_object_name $p]"
#                } else {
#                    puts $const_file "set_input_delay [expr $CT-$output_delay+$GB] -clock mclk -clock_fall \[get_ports $rcv_pin_name\] ;$rcv_par_name, user spec [get_object_name $p]"
#                }
                
#                puts $info "-G rcv- $rcv_par_name $rcv_pin_name"

#                append_to_collection all_ports_col $rcv
#            }
            
        }
    }

    puts "done running user spec"
    puts ""
#    return
    set output_col2 [remove_from_collection $output_col $other_side_spec]  
    set output_col3 [remove_from_collection $output_col2 $user_spec_pin_col]
    set missing_user_spec [remove_from_collection $other_side_spec $added_spec_arr]

#######removing clocks from list#########
    foreach_in_collection port $output_col3 {
	set blabla [get_pins $port]
	 if {[check_clock $port] == "1"} {puts $clock_file "$port"}
	 if {[check_clock $port] == "1"} {append_to_collection clock_pins $blabla}    
    }

   puts $info "number of clock ports: [sizeof_collection $clock_pins]"

   set new_output_col [remove_from_collection $output_col3 $clock_pins]

#########################################



    foreach_in_collection side [get_pins $missing_user_spec] {
	puts $missing "[get_object_name $side]"
    }







    set cnt 0 ;set dang_out 0 ; set dang_input 0 ; set fall_edge 0
    foreach_in_collection op $new_output_col {
        
        set drv $op
        set drv_par [lindex [split [get_object_name $drv] "/"] 0]
        
        set drv_edge "R"
        if {[regexp {par_.*\/(.*\d+l_.*)} [get_object_name $drv]] || [regexp {par_.*\/(.*\d+l\[.*)} [get_object_name $drv]] || [regexp {par_.*\/(.*\d+l)$} [get_object_name $drv]] || [regexp {par_.*\/(.*nnl.*)} [get_object_name $drv]]} {
            set drv_edge "F"
        }
        
        set port_fanin [all_fanin -quiet -to $drv -flat  -only_cells -startpoints_only]
        set port_driver [get_pins -quiet [all_fanin -to [get_pins -quiet $drv] -flat -level 1]  -filter "is_hierarchical==false && direction==out"]

        if {[sizeof_collection $port_driver] == 0} {
            puts $DBG "-W- the following port has no fanin: [get_object_name $drv]"
            set dang_input [expr $dang_input + 1]
            continue
        }

        set drv_fubs ""
        foreach_in_collection c $port_fanin {
            set drv_name [get_object_name $c]
            set drv_parent [get_object_name [get_attribute -quiet $c parent_cell]]
            set drv_fub [lindex [split $drv_parent "/"] end]
            set drv_fubs [lappend drv_fubs $drv_fub]
        }
        
        set rcvs [get_pins -quiet -of [get_nets -of $op -top -seg] -filter direction=~in]
        if {[sizeof_collection $rcvs] == 0} {
            puts $DBG "-W- the folloiwng port has no FO: [get_object_name $drv]"
            set dang_out [expr $dang_out + 1]
            continue
        }
        
        foreach_in_collection rcv $rcvs {
            set rcv_port_fo [all_fanout -quiet -from $rcv -endpoints_only -only_cells -flat]
            #set rcv_eps [get_pins -quiet [all_fanout -from $rcv -flat -endpoints_only -only_cells] -filter lib_pin_name=~*clk*]
            #set rcv_edge [get_attribute -quiet $rcv_eps is_rise_edge_triggered_clock_pin]
            #if {[lsearch $rcv_edge "false"] > -1} {
            #    puts $info "not rise->rise paths (one of the rcv is "F", need to set user spec on [get_object_name $drv]"
            #    continue
            #}

            if {[sizeof_collection $rcv_port_fo] == 0} {
                puts $DBG  "-W- the folloiwng port has no FO: [get_object_name $drv]"
                set dang_out [expr $dang_out + 1]
                continue
            }
        }

        # check if thre is flop on output port
        set flop_on_port 0
        set flop_on_drv 0
        if {[sizeof_collection $port_fanin] == 1} {

            set ref_name [get_attribute -quiet $port_fanin ref_name]
            if {[regexp {g1mf} $ref_name]} {

		# checking driver color (R/F)
                if {[get_attribute $port_fanin is_rise_edge_triggered] == "true"} {
                   if {$drv_edge == "F"} {
			#set drv_edge "R"
                    puts $DBG "wrong net/FF color: port [get_object_name $drv] net [get_object_name $port_fanin]"
                    }
                }
                if {[get_attribute $port_fanin is_rise_edge_triggered] == "false"} {
                    if {$drv_edge == "R"} {
			#set drv_edge "F"
                    puts $DBG "wrong net/FF color: port [get_object_name $drv] net [get_object_name $port_fanin]"
                    }
                }

                # driver color (AR/AF)
                #set clk_pin [get_pins -quiet -of $port_fanin -filter lib_pin_name=~*clk*]
                #set drv_edge [get_attribute -quiet $clk_pin is_rise_edge_triggered_clock_pin]

                #if {!$drv_edge} {
                #    puts $info "not rise->rise paths, need to set user spec on [get_object_name $drv]"
                #    continue
                #}

                set flop_on_port 1
                set flop_on_drv 1
                set drv_name [get_object_name $port_fanin]
                set drv_parent [get_object_name [get_attribute -quiet $port_fanin parent_cell]]
                set drv_fubs [lindex [split $drv_parent "/"] end]
            }
        }

        set drv_par_name [lindex [split [get_object_name $drv] "/"] 0]
        set drv_pin_name [lindex [split [get_object_name $drv] "/"] 1]
        
        set flop_on_rcv 0
        if {[sizeof_collection $rcvs] == 1 && !$flop_on_port && [sizeof_collection $rcv_port_fo] == 1} {
            # check if there is flop on input port

            set rcv_par_name [lindex [split [get_object_name $rcvs] "/"] 0]
            set rcv_pin_name [lindex [split [get_object_name $rcvs] "/"] 1]

            
            set ref_name [get_attribute -quiet $rcv_port_fo ref_name]
            if {[regexp {g1mf} $ref_name]} {

		# checking rcv color (R/F)
		if {[get_attribute $rcv_port_fo is_rise_edge_triggered] == "true"} {
                   if {$drv_edge == "F"} {
			#set drv_edge "R"
                    puts $DBG "wrong net/FF color: port [get_object_name $rcvs] net [get_object_name $rcv_port_fo]"
                    }
                }
                if {[get_attribute $rcv_port_fo is_rise_edge_triggered] == "false"} {
                    if {$drv_edge == "R"} {
			#set drv_edge "F"
                    puts $DBG "wrong net/FF color: port [get_object_name $rcvs] net [get_object_name $rcv_port_fo]"
                    }
                }

                set flop_on_port 1
                set flop_on_rcv 1
                set rcv_name [get_object_name $rcv_port_fo]
                set rcv_parent [get_object_name [get_attribute -quiet $rcv_port_fo parent_cell]]
                set rcv_fubs [lindex [split $rcv_parent "/"] end]
                
            }
        }
        if {$flop_on_port } {
           if {$flop_on_drv} {
               
               set budget [expr $CT-$UC]
               set output_delay [expr $budget-$flop2out]
              
	       if {$drv_edge == "R"} {
               		puts $const_file "set_output_delay $output_delay -clock mclk_virtual \[get_ports $drv_pin_name\] ;$drv_par_name, flop on drv [get_object_name $drv]"
                 } else {
               		puts $const_file "set_output_delay $output_delay -clock mclk_virtual -clock_fall \[get_ports $drv_pin_name\] ;$drv_par_name, flop on drv [get_object_name $drv]"
		}
	       puts $info "-G drv- $drv_par_name $drv_pin_name" ; # for debug
               
	       foreach_in_collection rcv $rcvs {
                    set rcv_par_name [lindex [split [get_object_name $rcv] "/"] 0]
                    set rcv_pin_name [lindex [split [get_object_name $rcv] "/"] 1]

                    if {$drv_edge == "R"} {
                    		puts $const_file "set_input_delay [expr $budget-$output_delay+$GB] -clock mclk_virtual \[get_ports $rcv_pin_name\] ;$rcv_par_name, flop on drv [get_object_name $drv]"
			} else {
                    		puts $const_file "set_input_delay [expr $budget-$output_delay+$GB] -clock mclk_virtual -clock_fall \[get_ports $rcv_pin_name\] ;$rcv_par_name, flop on drv [get_object_name $drv]"
			}
                    puts $info "-G rcv- $rcv_par_name $rcv_pin_name"

                    append_to_collection all_ports_col $rcv
               }

               set exist_spec_arr([get_object_name $drv]) 1
               append_to_collection good_ports_col $drv
           
           } elseif {$flop_on_rcv} {
               set budget [expr $CT-$UC]
               set input_delay [expr $budget-$input2flop]
		
	       if {$drv_edge == "R"} {
                        	puts $const_file "set_input_delay $input_delay -clock mclk_virtual \[get_ports $rcv_pin_name\] ;$rcv_par_name, flop on rcv"
			} else {
               			puts $const_file "set_input_delay $input_delay -clock mclk_virtual -clock_fall \[get_ports $rcv_pin_name\] ;$rcv_par_name, flop on rcv"
		}

               puts $info "-G rcv- $rcv_par_name $rcv_pin_name" ; # for debug
               
               if {$drv_edge == "R"} {
	       			puts $const_file "set_output_delay [expr $budget-$input_delay+$GB] -clock mclk_virtual \[get_ports $drv_pin_name\] ;$drv_par_name, flop on rcv"
			} else {
				puts $const_file "set_output_delay [expr $budget-$input_delay+$GB] -clock mclk_virtual -clock_fall \[get_ports $drv_pin_name\] ;$drv_par_name, flop on rcv"
			}

               puts $info "-G drv- $drv_par_name $drv_pin_name"
               
               append_to_collection good_ports_col $drv
           }
         } else {
                # check if pin exist in GLC (Tango)
                
                set drv_port_full_name [get_object_name $drv]
                set drv_port_name [lindex [split $drv_port_full_name "/"] 1]
                regsub -all {\[\d+\]}  $drv_port_name  {} port_base_name_temp
                set port_base_name [lindex [split $port_base_name_temp "_"] 0]
                puts $info "looking of $port_base_name [get_object_name $drv] in Tango"
                
                set output_delay -999
                foreach c [lsort -unique $drv_fubs] {
                    if {[info exists tango_arr($c%$port_base_name)]} {
                        set val [format "%.0f"  [expr $CT./$GLC_CT*[lindex $tango_arr($c%$port_base_name) 0]]]
                        set mar [expr [lindex $tango_arr($c%$port_base_name) 1]]
                        if {$mar<0} {set mar 0}
                        set edge [lindex $tango_arr($c%$port_base_name) 2]
                        if {$edge == "F"} {
                            puts $DBG "port [get_object_name $drv] has AF valid in Tango - Skipping"
                            set fall_edge [expr $fall_edge + 1]
                            continue
                        }

                        set budget [expr $CT-$UC]
                        set output_delay_new [format "%.0f"  [expr $budget-$val-($mar/2)]]
                        if {$output_delay_new>$output_delay} {set output_delay $output_delay_new}

                    }
                 }

                if {$output_delay != -999} {
                    if {![info exists exist_spec_arr([get_object_name $drv])]} {

                        puts $const_file "set_output_delay $output_delay -clock mclk_virtual \[get_ports $drv_pin_name\] ;$drv_par_name, Tango Spec "
                        puts $info "-G drv- $drv_par_name $drv_pin_name" ; # for debug

                       foreach_in_collection rcv $rcvs {
                            set rcv_par_name [lindex [split [get_object_name $rcv] "/"] 0]
                            set rcv_pin_name [lindex [split [get_object_name $rcv] "/"] 1]

                            puts $const_file "set_input_delay [expr $budget-$output_delay+$GB-($mar/2)] -clock mclk_virtual \[get_ports $rcv_pin_name\] ;$rcv_par_name, Tango Spec"
                            puts $info "-G rcv- $rcv_par_name $rcv_pin_name"

                            append_to_collection all_ports_col $rcv
                       }


                        set exist_spec_arr([get_object_name $drv]) 1

                        append_to_collection good_ports_col $drv
                    }

                } else {
                    if {![info exists missing_spec_arr([get_object_name $drv])]} {

                       puts $info "-Default drv- [get_object_name $drv]" ; # for debug
                       
                       set budget [expr $CT-$UC]
                       set output_delay [expr $budget-($CT*0.4)]

                       if {$drv_edge == "R"} {
                            puts $const_file "set_output_delay $output_delay -clock mclk_virtual \[get_ports $drv_pin_name\] ;$drv_par_name, Default Spec "
                       } else {
                            puts $const_file "set_output_delay $output_delay -clock_fall -clock mclk_virtual \[get_ports $drv_pin_name\] ;$drv_par_name, Default Spec "
                       }
                       
                       
                       foreach_in_collection rcv $rcvs {
                            set rcv_par_name [lindex [split [get_object_name $rcv] "/"] 0]
                            set rcv_pin_name [lindex [split [get_object_name $rcv] "/"] 1]
                            set input_delay [expr $budget-($CT*0.4)]
                            
                            if {$drv_edge == "R"} {
                                puts $const_file "set_input_delay $input_delay -clock mclk_virtual \[get_ports $rcv_pin_name\] ;$rcv_par_name, Default Spec"
                            } else {
                                puts $const_file "set_input_delay $input_delay -clock mclk_virtual -clock_fall \[get_ports $rcv_pin_name\] ;$rcv_par_name, Default Spec"
                            }

                            puts $info "-Default rcv- $rcv_par_name $rcv_pin_name"
                       }

                        set missing_spec_arr([get_object_name $drv]) 1

                        append_to_collection def_ports_col $drv
                    }
                }
           }

       set cnt [expr $cnt +1]
   }
   puts $DBG $cnt
   puts $info "\nnumber of Dangling outputs $dang_out" 
   puts $info "\nnumber of Dangling inputs $dang_input"
   puts $info "\nnumber of falling edge valids (GLC) $fall_edge"
   
   puts $info "\noutput ports with spec [sizeof_collection $good_ports_col]"
   puts $info "\noutput ports with default spec [sizeof_collection $def_ports_col]"
   puts $info "number of user spec output ports: [sizeof_collection $user_spec_pin_col]"

   
   close $DBG
   close $const_file
#   close $no_const_file
   close $info
   close $other_side 
   close $missing
   close $clock_file

   #return [append_to_collection all_ports_col $good_ports_col]
   
   #parse files per partition:
   gen_io_const_per_par $dir/$tag/gen_io_constraints_$corner.tcl $dir $tag $corner
}

proc parse_tango_valids {file} {
    set f [open $file r]
    
    array set arr ""
    while {[gets $f line] != -1} {
      set full_pin_name [lindex $line 0]
      set fub [lindex [split $full_pin_name "%"] 0]
      set port_name [lindex [split $full_pin_name "%"] 1]
      set port_base_name [lindex [split $port_name "_"] 0]
      
      set val [lindex $line 1]
      set clock_edge [lindex $line 2]
      set margin [lindex $line 3]
      
      
      if {![info exists arr($fub%$port_base_name)]} {
        set arr($fub%$port_base_name) "$val $margin $clock_edge"
      } else {
        # take WC valid
        set prev_val [lindex $arr($fub%$port_base_name) 0]
        if {$prev_val>$val} {
           lreplace $arr($fub%$port_base_name) 0 0 $prev_val
        }
        
      }
    }
    
    close $f
    return [array get arr]
}

proc parse_user_spec {file} {
    set f [open $file r]
    
    array set arr ""
    while {[gets $f line] != -1} {
      if {$line == "" || [regexp {^\#} $line] || [regexp {^\<xml} $line] || [regexp {^\<\/xml} $line]} {continue}
      
      set full_par_name [lindex $line 6]
      set par_name [lindex [split $full_par_name "\""] 1]
      set full_pins [lindex $line 7]
      set pins [lindex [split $full_pins "\""] 1]
      set full_clock [lindex $line 12]
      set clock [lindex [split $full_clock "\""] 1]
#      set ref_clock [lindex [split [lindex [split $full_clock "\""] 1] "_"] 0]
      if {[regexp {.*mclk.*} $clock]} {set ref_clock mclk} else {set ref_clock $clock}
      set full_clock_edge [lindex $line 13]
      set clock_edge [lindex [split $full_clock_edge "\""] 1]
      set full_val [lindex $line 11]
      set val [lindex [split $full_val "\""] 1]
      
      set full_pin_name "$par_name/$pins"
     
      if {![info exists arr($full_pin_name)]} {
        set arr($full_pin_name) "$clock $clock_edge $val $ref_clock"
      } else {
        puts "-DBG- pin alreay exist $full_pin_name"
      }
    }
    
    close $f
    return [array get arr]
}


# /nfs/iil/proj/skl/fct_sa2/sa2/eran/adl/ADL_ww18/par_list
proc gen_io_const_per_par {file dir tag corner} {
    
    #set corner [lindex [split [lindex [split $file "_"] end] "."] 0]
    
    set f [open $file r]
    
    array set par_arr ""
    while {[gets $f line] != -1} { 
        set par [lindex [split [lindex [split $line ";"] 1] ","] 0]
        
        set par_arr($par) [lappend par_arr($par) [lindex [split $line ";"] 0]]
    }
    
    close $f
    foreach par [array names par_arr] {
       set file_name "$par\_io_constraints_$corner\.tcl"
       set fw [open $dir/$tag/$file_name w]
       
       puts $fw "set_driving_cell -lib_cell g1mbfn000ab1n12x5 -pin o -input_transition_rise 55 -input_transition_fall 55 \[all_inputs -exclude_clock_ports\]"
       puts $fw "set_load 20 \[all_outputs\]"
       puts $fw "\n### $par IO constraints"
       
       foreach cmd $par_arr($par) {
            puts $fw $cmd
       }
       
       close $fw 
    }
    
    puts "files at: $dir/$tag/"   
}

        #set op [get_pins par_pmhglb/pmitphyadrm401h[21]]
        #redirect /dev/null {set tp [get_timing_paths -th $op -include_hierarchical_pins]}
        #if {![sizeof_collection $tp]} {puts  "-W- no path on [get_object_name $op]" ; continue} 
        


        #set startpoint [get_cells -of [get_attribute -quiet $tp startpoint]]
        #set endpoint [get_cells -of [get_attribute -quiet $tp endpoint]]
        
        #set drv_parent [get_object_name [get_attribute -quiet $startpoint parent_cell]]
        #set rcv_parent [get_object_name [get_attribute -quiet $endpoint parent_cell]]
        
        #set drv_fub [lindex [split $drv_parent "/"] end]
        #set rcv_fub [lindex [split $rcv_parent "/"] end]
        
        # check if flop on output
        
        #set drv_cell [get_cells -of [l1d $op]]
        #set drv_ref [get_attribute -quiet $drv_cell ref_name]
        #if {[regexp {.*bfm.*} $drv_ref]} {
        #    set buf_in [get_pins -of $drv_cell -filter direction=~in] 
        #    set buf_drv [l1d $buf_in]
        #}
        
        
        


## long runtime for get_timing_paths 
#        set points [get_attribute -quiet $tp points]

        #set ind 0
        #set flop_on_port 0
        #foreach_in_collection p $points {
        #    set p1 [get_attribute -quiet $p object]
        #    set point_name [get_object_name $p1]
        #    set obj_class [get_object_class $p1]
        #    
        #    
        #   set cell [get_cells -of $p1] 
        #   set cell_ref [get_attribute -quiet $cell ref_name]
#
         #  if {[regexp {.*g1mf.*} $cell_ref]} {
         #       set ind 1
         #       continue
          # }
#
 #          if {[regexp {.*bfn.*} $cell_ref] || [regexp {.*bfm.*} $cell_ref] || [regexp {.*inv.*} $cell_ref] } {set ind 1; continue} else {
  #              if {[regexp {.*g1m.*} $cell_ref]} {
   #                 set ind 0
    #                break
     #           }
      #      }
       #     
        #    #puts $point_name
         #  if {$point_name == [get_object_name $op] && $ind == 1} {
          #  puts [get_object_name $op] 
           # set flop_on_port 1
            #break
          #}
                
        #}



proc check_clock {port} {
foreach_in_collection p [get_pins $port] {
               set pn [get_object_name $p]
	       set drv [l1d $p]
               if {[sizeof_collection [get_attribute -quiet $drv clocks]] > 0 } {
                  set is_clk 1
               } else {
                  set is_clk 0
               }               
       }
return $is_clk
}

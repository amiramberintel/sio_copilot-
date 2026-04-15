proc gen_io_constraints {corner par tag} {
  
    source /nfs/iil/disks/home01/gilkeren/lnc/io_constraints/create_user_spec_file.tcl
 
    set dir  "/nfs/iil/stod/stod901/w.gilkeren.102/lnc/fct/io_constraints"   
    catch {exec mkdir $dir/$tag}
    set user_spec "/nfs/iil/disks/home01/gilkeren/lnc/io_constraints/user_spec.tcl"
    set DBG [open $dir/$tag/gen_io_constraints_DBG_$corner.rpt w]
    set const_file [open $dir/$tag/gen_io_constraints_$corner.tcl w]
    set no_const_file [open $dir/$tag/gen_io_constraints_missing_$corner.rpt w]
    set info [open $dir/$tag/gen_io_constraints_info_$corner.rpt w]
    
    
    # for debug
    set good_ports_col ""
    set all_ports_col ""
    set def_ports_col ""
    
    if {$corner == "func_max_highvcc"} {
        set CT 212
        #set UC 11.5
        set UC 40
        set flop2out 40
        set input2flop 20
        set GB 12
        set GLC_CT 226
        set GLC_avg_clk 40
        set tango_ref "/nfs/iil/proj/skl/fct_core_execution/fct/glcsrvr0p_TI_model/glc_io_constrains/glc.valid.report.filtered.highv"
        
    }

    if {$corner == "func_max"} {
        set CT 346
        #set UC 15.5
        set UC 70
        set flop2out 80
        set input2flop 40
        set GB 20
        set GLC_CT 386
        set GLC_avg_clk 70
        set tango_ref "/nfs/iil/proj/skl/fct_core_execution/fct/glcsrvr0p_TI_model/glc_io_constrains/glc.valid.report.filtered.nominal"
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
    foreach pin_name [array names user_spec_arr] {
        set pin_col [get_pins $pin_name]
        set clk [lindex $user_spec_arr($pin_name) 0]
        set clk_edge [lindex $user_spec_arr($pin_name) 1]
        set val_nom [lindex $user_spec_arr($pin_name) 2]
        set val_hv [lindex $user_spec_arr($pin_name) 3]
        set type  [lindex $user_spec_arr($pin_name) 4]
        if {$corner == "func_max"} {set val $val_nom}
        if {$corner == "func_max_highvcc"} {set val $val_hv}
        
        foreach_in_collection p $pin_col {
            #puts "[get_object_name $p]"
            append_to_collection user_spec_pin_col $p
            
            set rcvs [get_pins -quiet -of [get_nets -of $p -top -seg] -filter direction=~in]
            set budget [expr $CT-$UC]
            set output_delay [expr $budget-$val]

            set drv_par_name [lindex [split [get_object_name $p] "/"] 0]
            set drv_pin_name [lindex [split [get_object_name $p] "/"] 1]
            
            if {$clk_edge == "R"} {
                puts $const_file "set_output_delay $output_delay -clock mclk \[get_ports $drv_pin_name\] ;$drv_par_name, user spec [get_object_name $p]"
            } else {
                puts $const_file "set_output_delay $output_delay -clock mclk -clock_fall \[get_ports $drv_pin_name\] ;$drv_par_name, user spec [get_object_name $p]"
            }
            
            
            puts $info "-G drv- $drv_par_name $drv_pin_name" ; # for debug

            foreach_in_collection rcv $rcvs {
                set rcv_par_name [lindex [split [get_object_name $rcv] "/"] 0]
                set rcv_pin_name [lindex [split [get_object_name $rcv] "/"] 1]
                
                if {$clk_edge == "R"} {
                    puts $const_file "set_input_delay [expr $CT-$output_delay+$GB] -clock mclk \[get_ports $rcv_pin_name\] ;$rcv_par_name, user spec [get_object_name $p]"
                } else {
                    puts $const_file "set_input_delay [expr $CT-$output_delay+$GB] -clock mclk -clock_fall \[get_ports $rcv_pin_name\] ;$rcv_par_name, user spec [get_object_name $p]"
                }
                
                puts $info "-G rcv- $rcv_par_name $rcv_pin_name"

                append_to_collection all_ports_col $rcv
            }
            
        }
    }
    
    set new_output_col [remove_from_collection $output_col $user_spec_pin_col]
    
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
               		puts $const_file "set_output_delay $output_delay -clock mclk \[get_ports $drv_pin_name\] ;$drv_par_name, flop on drv [get_object_name $drv]"
                 } else {
               		puts $const_file "set_output_delay $output_delay -clock mclk -clock_fall \[get_ports $drv_pin_name\] ;$drv_par_name, flop on drv [get_object_name $drv]"
		}
	       puts $info "-G drv- $drv_par_name $drv_pin_name" ; # for debug
               
	       foreach_in_collection rcv $rcvs {
                    set rcv_par_name [lindex [split [get_object_name $rcv] "/"] 0]
                    set rcv_pin_name [lindex [split [get_object_name $rcv] "/"] 1]

                    if {$drv_edge == "R"} {
                    		puts $const_file "set_input_delay [expr $CT-$output_delay+$GB] -clock mclk \[get_ports $rcv_pin_name\] ;$rcv_par_name, flop on drv [get_object_name $drv]"
			} else {
                    		puts $const_file "set_input_delay [expr $CT-$output_delay+$GB] -clock mclk -clock_fall \[get_ports $rcv_pin_name\] ;$rcv_par_name, flop on drv [get_object_name $drv]"
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
                        	puts $const_file "set_input_delay $input_delay -clock mclk \[get_ports $rcv_pin_name\] ;$rcv_par_name, flop on rcv"
			} else {
               			puts $const_file "set_input_delay $input_delay -clock mclk -clock_fall \[get_ports $rcv_pin_name\] ;$rcv_par_name, flop on rcv"
		}

               puts $info "-G rcv- $rcv_par_name $rcv_pin_name" ; # for debug
               
               if {$drv_edge == "R"} {
	       			puts $const_file "set_output_delay [expr $CT-$input_delay+$GB] -clock mclk \[get_ports $drv_pin_name\] ;$drv_par_name, flop on rcv"
			} else {
				puts $const_file "set_output_delay [expr $CT-$input_delay+$GB] -clock mclk -clock_fall \[get_ports $drv_pin_name\] ;$drv_par_name, flop on rcv"
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

                        puts $const_file "set_output_delay $output_delay -clock mclk \[get_ports $drv_pin_name\] ;$drv_par_name, Tango Spec "
                        puts $info "-G drv- $drv_par_name $drv_pin_name" ; # for debug

                       foreach_in_collection rcv $rcvs {
                            set rcv_par_name [lindex [split [get_object_name $rcv] "/"] 0]
                            set rcv_pin_name [lindex [split [get_object_name $rcv] "/"] 1]

                            puts $const_file "set_input_delay [expr $CT-$output_delay+$GB-($mar/2)] -clock mclk \[get_ports $rcv_pin_name\] ;$rcv_par_name, Tango Spec"
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
                            puts $const_file "set_output_delay $output_delay -clock mclk \[get_ports $drv_pin_name\] ;$drv_par_name, Default Spec "
                       } else {
                            puts $const_file "set_output_delay $output_delay -clock_fall -clock mclk \[get_ports $drv_pin_name\] ;$drv_par_name, Default Spec "
                       }
                       
                       
                       foreach_in_collection rcv $rcvs {
                            set rcv_par_name [lindex [split [get_object_name $rcv] "/"] 0]
                            set rcv_pin_name [lindex [split [get_object_name $rcv] "/"] 1]
                            set input_delay [expr $budget-($CT*0.4)]
                            
                            if {$drv_edge == "R"} {
                                puts $const_file "set_input_delay $input_delay -clock mclk \[get_ports $rcv_pin_name\] ;$rcv_par_name, Default Spec"
                            } else {
                                puts $const_file "set_input_delay $input_delay -clock mclk -clock_fall \[get_ports $rcv_pin_name\] ;$rcv_par_name, Default Spec"
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
   puts  $info "\nnumber of Dangling outputs $dang_out" 
   puts $info "\nnumber of Dangling inputs $dang_input"
   puts $info "\nnumber of falling edge valids (GLC) $fall_edge"
   
   puts $info "\noutput ports with spec [sizeof_collection $good_ports_col]"
   puts $info "\noutput ports with default spec [sizeof_collection $def_ports_col]"
   puts $info "number of user spec output ports: [sizeof_collection $user_spec_pin_col]"

   
   close $DBG
   close $const_file
   close $no_const_file
   close $info
   
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
      if {$line == "" || [regexp {^\#} $line]} {continue}
      
      set par_name [lindex $line 0]
      set pins [lindex $line 1]
      set clock [lindex $line 2]
      set clock_edge [lindex $line 3]
      set val_nom [lindex $line 4]
      set val_hv [lindex $line 5]
      set type [lindex $line 6] ;# one side or two
      
      set full_pin_name "$par_name/$pins"
     
      if {![info exists arr($full_pin_name)]} {
        set arr($full_pin_name) "$clock $clock_edge $val_nom $val_hv $type"
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




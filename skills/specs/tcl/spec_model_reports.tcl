# ver1: supports correct latch behaviour 


catch {lappend auto_path "/nfs/iil/disks/core_fct/lnc/fct/erans_files/ecohe15/STO/scripts/misc/package/"} err
catch {package require parseOpt} err
catch {namespace import ::parseOpt::cmdSpec ::parseOpt::parseOpt} err


proc create_port_spec_slack {pin_coll scenario} {
    global env
    
#    exec rm -rf ./spec_margin_status/$scenario
    exec mkdir -p $env(ward)/spec_margin_status/$scenario

    global env
    global port_table
   
    set port_table ""
    
    set file "$env(ward)/spec_margin_status/$scenario/port_spec_report_details.txt"
    set file_sum "$env(ward)/spec_margin_status/$scenario/port_spec_report_summary.txt"
    set file_dbg "$env(ward)/spec_margin_status/$scenario/port_spec_report_debug.txt"
    
    set fileh [open $file w]
    set fileh_sum [open $file_sum w]
    set fileh_debug [open $file_dbg w]
    
    puts $fileh "Spec Report"
    puts $fileh "############\n"
   
#    puts $file_dbg "[date]"
    foreach_in_collection p $pin_coll {
#	puts "working on: [get_object_name $p]"
        set p_dir [get_attribute -quiet $p direction]
        
        if {$p_dir == "in"} { 
            puts $fileh_debug "-W- Script works only in outputs [get_object_name $p]"
            continue
        }
        
        set l_clock [get_attribute -quiet $p launch_clocks]
        
        if {[sizeof_collection $l_clock] == 0} {
            puts $fileh_debug "-W- port has not launch clock [get_object_name $p]"
            set comment "unconstraint"
            lappend port_table "[get_object_name $p] NA NA NA NA 0 0 no_launch_clock $comment"
            continue
        }
      
        
        foreach clk $l_clock {
            calc_port_spec_margin $p $clk $fileh $fileh_debug
        }
    }
    
    close $fileh
    
    set header "Port_Name Startpoint Endpoint StartClk EndClk Slack Spec_Slack Mar_diff Pos/Neg Comment"
    rls_table -header $header -table $port_table -breaks -spacious -format "{} {} {} {} {}  %-2s %-2s {} {} {}" -to $fileh_sum
    
    close $fileh_sum
    close $fileh_debug
    
    puts "\n$env(ward)/spec_margin_status/$scenario/port_spec_report_details.txt\n$env(ward)/spec_margin_status/$scenario/port_spec_report_summary.txt\n$env(ward)/spec_margin_status/$scenario/port_spec_report_debug.txt\n"
    
    
}

proc calc_port_spec_margin {port clock fileh DBG} {
    global port_table
    
    puts $fileh "\nworks on: [get_object_name $port]"
    puts $DBG "\nworks on: [get_object_name $port]"
    
    set latch_template "^SLH|^LN|^LH|^MB\[2|4|8\]L|^LHQ|^MB\[2|4|8\]SRLSLH" 
    define_user_attribute -quiet -type string -classes pin spec_slack
    
    redirect /dev/null {set tps [get_timing_path -from $clock -th $port -slack_lesser_than INFINITY -include_hierarchical_pins]}
    
    if {[sizeof_collection $tps] == 0} {
        puts $DBG  "-I- No timing path on [get_object_name $port]"
        return 
    }
    # timing paths attributes
    if {[get_attribute -quiet $tps startpoint_clock_open_edge_value] == ""} { 
        puts $DBG "-I- No startpoint_clock_open_edge_value"
        set startpoint_clk_open_edge 0
	puts $DBG "-I- setting startpoint_clk_open_edge to be 0"
    } else {
	set startpoint_clk_open_edge [get_attribute -quiet $tps startpoint_clock_open_edge_value]
	puts $DBG "-I- startpoint clock open edge: $startpoint_clk_open_edge"
	puts $fileh "startpoint clock open edge: $startpoint_clk_open_edge"

    }
#    set startpoint_clk_open_edge [get_attribute -quiet $tps startpoint_clock_open_edge_value]

    set borrow [get_attribute -quiet $tps time_lent_to_startpoint]
	puts $DBG "-I- borrowing from startpoint: $borrow"
	puts $fileh "borrowing from startpoint: $borrow"

    set strt_clk_ltncy [get_attribute $tps startpoint_clock_latency]
	puts $DBG "-I- startpoint_clock_latency: $strt_clk_ltncy"
	puts $fileh "startpoint_clock_latency: $strt_clk_ltncy"
	
    set startpoint [get_object_name [get_attribute -quiet $tps startpoint]]
    set startpoint_par [lindex [split $startpoint "/"] 0]
    set endpoint [get_object_name [get_attribute -quiet $tps endpoint]]
    set endpoint_par [lindex [split $endpoint "/"] 0]
    set startpoint_clk_obj [get_attribute -quiet $tps startpoint_clock]
    set endpoint_clk_obj [get_attribute -quiet $tps endpoint_clock]
#    set endpoint_setup [get_attribute -quiet $tps endpoint_setup_time_value]
  
    if {[get_attribute -quiet $tps endpoint_setup_time_value] == ""} { 
        puts $DBG "-I- No setup"
        set endpoint_setup 0
    } else {
	set endpoint_setup [get_attribute -quiet $tps endpoint_setup_time_value]
    }

    if {[sizeof_collection $startpoint_clk_obj] == 0 || [sizeof_collection $endpoint_clk_obj] == 0} {
	lappend port_table "[get_object_name $port] $startpoint $endpoint NA NA NA NA MissingGenOrSmpClk NA Unconst"
	puts $DBG "-I- Unconst - no startpoint_clk or endpoint_clk"

        return
    }

    set startpoint_clk [get_object_name [get_attribute -quiet $tps startpoint_clock]]
    set endpoint_clk [get_object_name [get_attribute -quiet $tps endpoint_clock]]

    set tp_slack [get_attribute -quiet $tps slack]
    
    if {$tp_slack == INFINITY} {
        set UC_reason ""
        if {[get_attribute -quiet $tps endpoint_unconstrained_reason] != ""} {set UC_reason [get_attribute -quiet $tps endpoint_unconstrained_reason]}
        if {[get_attribute -quiet $tps startpoint_unconstrained_reason] !=""} {set UC_reason [get_attribute -quiet $tps startpoint_unconstrained_reason]}
	puts $DBG "$UC_reason"
        lappend port_table "[get_object_name $port] $startpoint $endpoint $startpoint_clk $endpoint_clk $tp_slack $tp_slack $UC_reason Pos Unconst"
        return
    }
    
    set new_slack $tp_slack
    
    set startpoint_clock [get_object_name [get_attribute -quiet $tps startpoint_clock]]
    set endpoint_clock [get_object_name [get_attribute -quiet $tps endpoint_clock]]
    set points [get_attribute -quiet $tps points]
    set tp_arrival [expr [format "%.1f" [get_attribute -quiet $tps arrival]]]
    set tp_arrival_acc [expr [format "%.1f" [get_attribute -quiet $tps arrival]] + $borrow + $strt_clk_ltncy + $startpoint_clk_open_edge]
    
    set new_val 0
    set out_ft_pin NA
    set val_diff 0
    set req_diff 0
    array unset delay_arr
    array set delay_arr ""
    set rcv_spec 1
    set drv_spec 1
    set latch_count 0
    
    array unset ft_arr ""

#    array unset valid_arr ""


####################################### starting points analysis ########################################
#########################################################################################################

    foreach_in_collection p $points {
        set p_obj [get_attribute $p object]
        set p_name [get_object_name $p_obj]
        set p_dir [get_attribute -quiet $p_obj direction]
        set p_arrival [expr [format "%.1f" [get_attribute -quiet $p arrival]] + $borrow]

	set p_arrival_acc [expr $p_arrival +  $strt_clk_ltncy + $startpoint_clk_open_edge]

	puts $DBG "$p_name $p_arrival_acc"

        set p_name_hier [split $p_name "/"]
        set partition [lindex $p_name_hier 0]
        
        # check if this is a latch
        if {$p_dir=="out"} {
            set cell [get_cells -quiet -of $p_obj]
            set template [get_attribute -quiet $cell ref_name]
            
            if {[regexp $latch_template $template]} {
#                report_attribute $p -application
                # check if this is not the path startpoint
                set start_cell [get_object_name [get_cells -quiet -of $startpoint]]
                set cell_name [get_object_name $cell]
		if {$start_cell eq $cell_name} {continue}
#		puts "$cell_name"
#		    puts "[get_attribute [get_cell $cell_name] is_positive_level_sensitive]"
                incr latch_count
		    puts $DBG "-I- current latch count: $latch_count"
		    puts $fileh "-I- current latch count: $latch_count"
            }
        }
        
        # gets into/out from parittion 
        if {[llength $p_name_hier] == 2} {
            
            # port is feedthough
            ########################
            set ft_spec  [get_attribute -quiet $p_obj FT_DLY_USER_OVR]
            
            if {[regexp {FEEDTHRU} $p_name] || [llength $ft_spec]} {
		puts $DBG "-I- $p_name port have FT attribute or *FEEDTHRU* in name"
                
                set ft_spec "{xx 0} yy"
                if {$p_dir=="in" && $endpoint_par!=$partition} {
		    puts $DBG "-I- $p_name port is FT"
                    if {[llength [get_attribute -quiet $p_obj FT_DLY_USER_OVR]] > 0} {
                        set ft_spec  [get_attribute -quiet $p_obj FT_DLY_USER_OVR]
                    } elseif {[llength [get_attribute -quiet $p_obj FT_DLY_CALC]] > 0} {
                        set ft_spec  [get_attribute -quiet $p_obj FT_DLY_CALC]
                    }

                    set ft_arr($p_name) $p_arrival
                    
                    #set ft_delay [lindex [lindex $ft_spec 0] 1]
                    #set out_ft_pin [lindex [lindex $ft_spec 0] 0]
                    #set val_diff [expr $val_diff + $ft_delay]
                    #puts $fileh "$p_name $p_arrival $ft_delay"
#                    continue
                } else {
		    if {[llength [get_attribute -quiet $p_obj FT_DLY_USER_OVR]] > 0} {
                        set ft_spec  [get_attribute -quiet $p_obj FT_DLY_USER_OVR]
                    } elseif {[llength [get_attribute -quiet $p_obj FT_DLY_CALC]] > 0} {
                        set ft_spec  [get_attribute -quiet $p_obj FT_DLY_CALC]
                    }
		    
		    if {($p_dir=="out" && $startpoint_par!=$partition) || ($p_dir=="out" && [info exists ft_arr([lindex [lindex $ft_spec 0] 0])])} {
			puts $DBG "-I- $p_name port is output of FT"
                    if {[llength [get_attribute -quiet $p_obj FT_DLY_USER_OVR]] > 0} {
                        set ft_spec  [get_attribute -quiet $p_obj FT_DLY_USER_OVR]
                    } elseif {[llength [get_attribute -quiet $p_obj FT_DLY_CALC]] > 0} {
                        set ft_spec  [get_attribute -quiet $p_obj FT_DLY_CALC]
                    }
                    
                    set ft_delay [format "%.1f" [lindex [lindex $ft_spec 0] 1]]
			puts $DBG "-I- FT spec is: $ft_delay"
                    set in_ft_pin [lindex [lindex $ft_spec 0] 0]
                    
                    if {[info exists ft_arr($in_ft_pin)]} {
                        #puts "$p_arrival $ft_arr($in_ft_pin) $ft_delay"
			puts $DBG "-I- current val diff: $val_diff"
			    puts $DBG "-I- valid diff = $val_diff (prev val diff) - ( $p_arrival (p_arrival) - $ft_arr($in_ft_pin) (in FT arrival) )+ $ft_delay (ft spec)"
			
                        set val_diff [expr $val_diff - ($p_arrival - $ft_arr($in_ft_pin)) + $ft_delay]
			    puts $DBG "-I- new valid diff = $val_diff"

                        puts $fileh "$p_name $p_arrival $ft_delay [expr 0 - ($p_arrival - $ft_arr($in_ft_pin)) + $ft_delay]"
                        continue
                    } elseif {[info exists delay_arr($partition)]} {
                        set val_diff [expr $val_diff - ($p_arrival - $delay_arr($partition)) + $ft_delay]
                        puts $fileh "$p_name $p_arrival $ft_delay [expr 0 - ($p_arrival - $delay_arr($partition)) + $ft_delay]"
                        continue
                    } else {
                        puts $DBG "-I- $p_name no inputs FT Or delay"
#                        continue
                    }
                    
		    }
		}
            }
            
            set user_spec [get_attribute -quiet $p_obj spec_details]
            
            # driver output port
            ###########################
            
            if {$p_dir == "out" && $startpoint_par==$partition} {
		puts $DBG "-I- #### OUTPUT PORT ####: $p_name"
		puts $DBG "-I- latch count driver: $latch_count"
                if {$user_spec == ""} {
		   puts $DBG "-I- $p_name is without spec"
                   puts $fileh "$p_name $p_arrival"
                   set new_val [expr $new_val + $p_arrival]
                   set drv_spec 0 
		   set latch_count 0
		   set o_valid [expr $p_arrival - $startpoint_clk_open_edge]
		   puts $DBG "-I- $p_name no spec and output valid: $o_valid"
                } else {
		   puts $DBG "-I- $p_name spec is: $user_spec"
                   set spec_val [lindex [lindex $user_spec 0] 0]
                   set spec_clk [lindex [lindex $user_spec 0] 1]
                   if {$spec_clk!=$startpoint_clock} {
                        #spec is not on the same valid clock
                        puts $fileh "$p_name $p_arrival"
                        set new_val [expr $new_val + $p_arrival]
                   } else {
                      if {$latch_count} {
                        set phase 0
                        set phase [expr [get_attribute -quiet [get_clocks $spec_clk] period]/2]
                        set transp_p_arrival [expr $p_arrival_acc-$latch_count*$phase-$startpoint_clk_open_edge]
			set o_valid $transp_p_arrival
			puts $DBG "-I- current val diff: $val_diff"
                        set val_diff [format "%.1f" [expr $val_diff + ($spec_val - $transp_p_arrival)]]
                        puts $fileh "$p_name $p_arrival (Trasp valid: $transp_p_arrival) $spec_val $val_diff"
			puts $DBG "-I- latch count: $latch_count"
			puts $DBG "-I- $p_name output valid: $o_valid"
			puts $DBG "-I- Valid diff is: $val_diff"

                        set latch_count 0
                      } else {
			puts $DBG "-I- current val diff: $val_diff"
                        set val_diff [format "%.1f" [expr $val_diff + ($spec_val - $p_arrival) ]]

			puts $DBG "-I- p_arrival is: $p_arrival"			    
			puts $DBG "-I- borrow is: $borrow"			    		    
			puts $DBG "-I- Val_diff is: $val_diff"			    
                      puts $fileh "$p_name $p_arrival $spec_val $val_diff"
			set o_valid [expr $p_arrival]
			puts $DBG "-I- $p_name output valid: $o_valid"

		      }
                      
                   } 
                }
              continue
            }

            # rcv input port
            ####################
            
            if {$p_dir == "in" && $endpoint_par==$partition} {
		puts $DBG "-I- #### INPUT PORT ####: $p_name"
                if {$user_spec == ""} {
                   puts $fileh "$p_name $p_arrival"
                   set rcv_spec 0
                } else {
                   set spec_val [lindex [lindex $user_spec 0] 0]
                   set spec_clk [lindex [lindex $user_spec 0] 1]
		   puts $DBG "-I- $p_name spec is: $user_spec"
                   if {$spec_clk!=$endpoint_clock} {
                        #spec is not on the same as the sampling clock
		        puts $DBG "-I- spec_clk ($spec_clk) is not same as endpoint clock ($endpoint_clock)"
                        puts $fileh "$p_name $p_arrival"
                   } else {

                      set rcv_delay [expr $tp_arrival-$p_arrival]
			  puts $DBG "-I- rcv_delay = $tp_arrival (tp_arrival) - $p_arrival (p_arrival) = $rcv_delay"
#			set latch_count [num_of_latchs $points $p_name]
                      #puts $latch_count
                      
#                      if {$latch_count} {
#                        set phase 0
#                        set phase [expr [get_attribute -quiet [get_clocks $spec_clk] period]/2]
#                        set transp_rcv_delay [format "%.1f" [expr $rcv_delay-($latch_count-1)*$phase]]
                        
#                        set req_diff [format "%.1f" [expr $spec_val - ($transp_rcv_delay + $endpoint_setup)]]
#                        puts $fileh "$p_name $p_arrival (Transp: $transp_rcv_delay) $spec_val $req_diff"
                        
#                        set latch_count 0
#                      }
                       
                       set req_diff [format "%.1f" [expr $spec_val - ($rcv_delay + $endpoint_setup)]]
		       puts $DBG "-I- Req diff is: $req_diff  ($spec_val (spec_val) - ( $rcv_delay (rcv_delay) + $endpoint_setup (endpoint_detup) ))"
                       puts $fileh "$p_name $p_arrival $spec_val $req_diff"
                   } 
                }
             continue   
            }

	# full trans
	####################
	if {$p_dir == "out" && $startpoint_par!=$partition} {
	    if {$latch_count} {
	   	puts $DBG "-I- Full transparency"
	   	puts $DBG "-I- latch count: $latch_count"
#puts $DBG "-I- $o_valid"
	    } else {
		puts $DBG "-I- $p_name port is output and partition is not startpoint"
	    }
	}
        # delay path
        #############
        if {$p_dir == "in" && $endpoint_par!=$partition} {
	    puts $DBG "-I- current latch count: $latch_count"
            if {$user_spec == ""} {
               puts $fileh "$p_name $p_arrival"
            } else {
               set spec_val [lindex [lindex $user_spec 0] 0]
               set spec_clk [lindex [lindex $user_spec 0] 1]
               if {![regexp "mclk" $spec_clk]} {
                    #spec is not on the same as the sampling clock
                    puts $DBG "-I- $p_name Non-Mclk spec is not supported currently"
               } else {
                   set delay_arr($partition) $p_arrival 
                   puts $fileh "$p_name $p_arrival"
               } 
            }
         continue   
        }            
        
        if {$p_dir == "out" && $startpoint_par!=$partition && $latch_count == "0"} {
            if {$user_spec == ""} {
               puts $fileh "$p_name $p_arrival"
               set new_val [expr $new_val + $p_arrival]  
            } else {
               set spec_val [lindex [lindex $user_spec 0] 0]
               set spec_clk [lindex [lindex $user_spec 0] 1]
               if {![regexp "mclk" $spec_clk]} {
                    #spec is not on the same valid clock
                    puts $DBG "-I- $p_name Non-Mclk spec is not supported currently"
               } else {
                  if {![info exists delay_arr($partition)]} {
                     puts $DBG "-I- output delay $p_name without any record of the input"
                  } else {
		      puts $DBG "-I- $p_name possible delay path"
		      puts $DBG "-I- current val diff: $val_diff"
                      set val_diff [format "%.1f"  [expr $val_diff + $spec_val - ($p_arrival - $delay_arr($partition))]]
                      puts $fileh "$p_name $p_arrival $spec_val $val_diff"
                  }
               } 
            }
          continue
        }

       
     
      }  
      
      puts $fileh "$p_name $p_arrival"
    }
    
    set new_slack [expr $tp_slack - $val_diff - $req_diff]
    #puts $new_slack
    set_user_attribute -quiet -class pin $port spec_slack $new_slack
    
    
    set mar_diff "Eq"
    if {[format "%.2f" $new_slack] != [format "%.2f" $tp_slack]} {
        if {$drv_spec && $rcv_spec} {set mar_diff "Full_Spec"}
        if {!$drv_spec && $rcv_spec} {set mar_diff "RCV_Spec"}
        if {$drv_spec && !$rcv_spec} {set mar_diff "DRV_Spec"}
    }
    
    set mar "Pos"
    if {[format "%.2f" $new_slack] < 0} {set mar "Neg"}
    
    set port_name [get_object_name $port]
    set spec_comment [get_attribute -quiet $port spec_comment]
    set comment ""
    
    if {[llength $spec_comment] > 0} {
        set comment_key [lindex $spec_comment 0]
        
        set new_key "$startpoint\:\:$endpoint"
        
        if {[string equal $new_key $comment_key]} {
            regsub -all {\s+} [lindex $spec_comment 1] " " comment
        } 
    }
    
    lappend port_table "$port_name $startpoint $endpoint $startpoint_clk $endpoint_clk $tp_slack $new_slack $mar_diff $mar $comment"
    
    puts $fileh "\nSlack: [format "%.1f" $tp_slack] \nNew Slack: [format "%.1f" $new_slack]\nSetup: [format "%.1f" $endpoint_setup]\nBorrowing from start point: [format "%.1f" $borrow]\n"
    puts $DBG "\nSlack: [format "%.1f" $tp_slack] \nNew Slack: [format "%.1f" $new_slack] (details: $tp_slack (tp_slack) - $val_diff (val_diff) - $req_diff (req_diff))\nSetup: [format "%.1f" $endpoint_setup]\nBorrowing from start point: [format "%.1f" $borrow]\n"
    
}

proc num_of_latchs {points rcv_port} {
    
    set latch_count 0
    set start_count 0
    set latch_template "^SLH|^LN|^LH|^MB\[2|4|8\]L|^LHQ|^MB\[2|4|8\]SRLSLH"
    
    foreach_in_collection p $points {
        set p_obj [get_attribute $p object]
        set p_name [get_object_name $p_obj]
        set p_dir [get_attribute -quiet $p_obj direction]
        set p_name_hier [split $p_name "/"]
        
        # check if i'm on the rcv port
        if {[llength $p_name_hier] == 2 && $rcv_port eq $p_name} {
            set start_count 1
        }
        
        # check if this is a latch
        if {$p_dir=="out" && $start_count} {
            set cell [get_cells -quiet -of $p_obj]
            set template [get_attribute -quiet $cell ref_name]
            
            if {[regexp $latch_template $template]} {
                incr latch_count
            }
        }
        
    }
    
    return $latch_count
}

proc parse_sio_commets {file user date} {
    global env
    
    set f [open $file r]
    set file_out $env(ward)/comment_attribute.$user.tcl
    
    set fw [open $file_out w]
    
    
    set prev_line ""
    array unset comm_arr {}
    define_user_attribute -quiet -type string -classes pin spec_comment
    
    while {[gets $f line] != -1} {
        if {[regexp {^//} $line]} {
            #puts "$line\n$prev_line\n"
            set split_prev_line [split $prev_line "|"]
            
            regsub -all " " [lindex $split_prev_line 0] {} port_name
            regsub -all " " [lindex $split_prev_line 1] {} start
            regsub -all " " [lindex $split_prev_line 2] {} end
            
            set key "$start\:\:$end"
            regsub {^//} $line "$date,($user)\:" comm_arr($key)
            
            puts $fw "set_user_attribute -quiet -class pin \[get_pins $port_name\] spec_comment \[list \"$key\" \"$comm_arr($key)\"\]"
        }
        
        set prev_line $line
    }
    
    close $f
    close $fw
    
    puts "\n$file_out\n"

}

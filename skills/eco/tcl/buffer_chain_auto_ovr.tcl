proc buffer_chain_ovr {input_file} {
global ivar
global env

#apply OVRs only for negative paths
set slack_th -20
#apply OVRs only for bad RC ratio
set ratio_th 30
set dfx_ratio_th 40
#apply OVRs only for >10ps OVRs
set ovr_th -10

set debug [open $ivar(log_dir)/buffer_chain_auto_ovr_log.log w]
set output_file [open $ivar(log_dir)/buffer_chain_auto_ovr_file.tcl w]
set f [open $input_file r]
while {[gets $f line] != -1} {
    	#ignoring first line
	if {[regexp drv_manh_dist $line]} {
	    	puts $debug "ignoring first line"
		continue	
	}

	set drv_flag 0
	set rcv_flag 0
	set dfx_flag 0
	puts $debug "#################################"
	puts $debug "$line"
	set drv_port [lindex [split $line ","] 1]
	if {[regexp "channel_repeater|uscan|_lcp_|dft_" $drv_port]} {set dfx_flag 1}

	set drv_par [lindex [split $drv_port "/"] 0]
	set rcv_port [lindex [split $line ","] 0]
	set rcv_par [lindex [split $rcv_port "/"] 0]

	if { [info exists ::ivar(fct_prep,par_tags_ovr,$drv_par)]  } {
		set drv_tag $ivar(fct_prep,par_tags_ovr,$drv_par)
    	} else {
	    	puts $debug "no TAG for par: $drv_par"
	}

	if { [info exists ::ivar(fct_prep,par_tags_ovr,$rcv_par)]  } {
		set rcv_tag $ivar(fct_prep,par_tags_ovr,$rcv_par)
    	} else {
	    	puts $debug "no TAG for par: $rcv_par"
	}

	set drv_delay [lindex [split $line ","] 5]
	set rcv_delay [lindex [split $line ","] 11]
	set slack [lindex [split $line ","] 2]
	set drv_distance  [lindex [split $line ","] 3]
	set rcv_distance [lindex [split $line ","] 9]
	set drv_ratio [lindex [split $line ","] 6]
	set rcv_ratio [lindex [split $line ","] 12]

	if {$slack > $slack_th} {
		puts $debug "slack ($slack) is better than threshold ($slack_th)"
		continue	
	}

	puts $debug slack=$slack

	if {$dfx_flag} {set ratio $dfx_ratio_th} else {set ratio $ratio_th}

	puts $debug DFX_FLAG=$dfx_flag
	puts $debug rc_ratio=$ratio

	if {$drv_ratio < $ratio} {
	    	set drv_flag 1	
	    	puts $debug "drv rc ratio ($drv_ratio) is better than threshold ($ratio), drv_flag=$drv_flag"
	}

	if {$rcv_ratio < $ratio} {
	    	set rcv_flag 1
	    	puts $debug "rcv rc ratio ($rcv_ratio) is better than threshold ($ratio), rcv_flag=$rcv_flag"
	}

	if {!$drv_flag} {
		puts $debug drv_port=$drv_port
		puts $debug drv_ratio=$drv_ratio
		puts $debug drv_distance=$drv_distance		
		puts $debug drv_delay=$drv_delay
		set drv_new_delay [expr $drv_distance*$ratio/100]
		puts $debug drv_new_delay=$drv_new_delay
		set ovr_delay [expr $drv_new_delay-$drv_delay]
		puts $debug ovr_delay=$ovr_delay
		if {$ovr_delay > $ovr_th} {
		    puts $debug "ovr ($ovr_delay) is better than threshold ($ovr_th)"
		} else {
		    puts $debug "setting the following ovr: annotet_port $drv_port \[expr \${factor}* $ovr_delay\]"
		    puts $output_file "annotet_port $drv_port \[expr \${factor}*$ovr_delay\]"
	    	}
	}

	if {!$rcv_flag} {
		puts $debug rcv_port=$rcv_port
		puts $debug rcv_ratio=$rcv_ratio
		puts $debug rcv_distance=$rcv_distance		
		puts $debug rcv_delay=$rcv_delay
		set rcv_new_delay [expr $rcv_distance*$ratio/100]
		puts $debug rcv_new_delay=$rcv_new_delay
		set ovr_delay [expr $rcv_new_delay-$rcv_delay]
		puts $debug ovr_delay=$ovr_delay
		if {$ovr_delay > $ovr_th} {
		    puts $debug "ovr is better than threshold"
		} else {
		   puts $debug "setting the following ovr: annotet_port $rcv_port \[expr \${factor}* $ovr_delay\]"
		   puts $output_file "annotet_port $rcv_port \[expr \${factor}*$ovr_delay\]"
	       }
	} else {
	    puts $debug "RCV flag is: $rcv_flag"
	}
		
	puts $debug "#################################"	
	puts $debug ""
}
close $f
close $debug
close $output_file
}

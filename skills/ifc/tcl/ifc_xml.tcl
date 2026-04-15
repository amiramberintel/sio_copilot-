proc get_port_clocks {ports} {

    set port [get_ports $ports]
    set rtn_clocks ""

    foreach_in_collection po $port {
        set obj [get_object_name $po]
        redirect -var rpt_port {report_port -verbose [get_object_name $po] -nosplit}
        set rpt [split $rpt_port \n]
        if {[get_attribute [get_ports [get_object_name $po]] direction] eq "out"} {
            set range [lrange $rpt [lsearch -regexp $rpt {\s+Output\s+Delay}] end]

            # puts $range
            # puts "loop:"
            foreach l [lreverse [lrange  $range 0 end-2 ]] {
                # puts $l
                if { [llength $l]==1 } { break}
                # puts [lindex $l end-1]
                lappend rtn_clocks [lindex [split [lindex $l end-1 ] "(" ] 0]
            }

        } else {
            set range [lrange $rpt [lsearch -regexp $rpt {\s+Input\s+Delay}] [expr [lsearch -regexp $rpt {\s+Resistance}] - 1] ]
            foreach l [lreverse [lrange  $range 0 end-2 ]] {
                # puts $l
                if { [llength $l]==1 } { break}
                # puts [lindex $l end-1]
                lappend rtn_clocks [lindex [split [lindex $l end-1 ] "(" ] 0]
            }
        }
    }
    # puts $rtn_clocks
    return [get_clocks $rtn_clocks]

}



set tp ""
set pba none
set port_col [get_ports]
set port_col [filter_collection $port_col !is_clock_source]
set port_col [filter_collection $port_col "full_name!=retensleepindic"]
set port_col [filter_collection $port_col "full_name!=u2c_dfx_ijtag_reset_b"]
set port_col [filter_collection $port_col "full_name!=sapwrgoodyxznnnh"]
set port_col [filter_collection $port_col "full_name!=u2c_dfx_earlyboot_exit_1rxfxh"]
set port_col [filter_collection $port_col "full_name!=u2c_dfx_pstf_reset_b"]
foreach_in_collection p $port_col {
    # puts "[get_object_name $p]"
    if {[get_attribute [get_ports $p] max_slack] != "INFINITY"} {
        set dir [get_attribute [get_ports $p] direction]
        if {$dir == "in"} {
            if {[sizeof_collection [all_fanout -flat -trace_arcs all -endpoints_only -from $p]] < 10000} {
                set p_clocks [get_port_clocks $p]
                foreach_in_collection clk $p_clocks {
                    set p_tp [get_timing_path -from $clk -th $p -delay_type $ivar(sta,delay_type) -pba $pba]
                    if {[get_attribute $p_tp slack] != "INFINITY"} {append_to_collection tp $p_tp}
                    
                }
            } else {
                puts "[get_object_name $p] - high FO"
            }
        } else {
            set p_clocks [get_port_clocks $p]
            foreach_in_collection clk $p_clocks {
                set p_tp [get_timing_path -to $clk -th $p -delay_type $ivar(sta,delay_type) -pba $pba]
                if {[get_attribute $p_tp slack] != "INFINITY"} {append_to_collection tp $p_tp}
            }
        }

    } else {
        puts "[get_object_name $p] - no slack"
    }
}



iproc_source -file fct_custom_report.tcl
fct_report_timing_summary $ivar(rpt_dir)/ifc_paths.xml $tp

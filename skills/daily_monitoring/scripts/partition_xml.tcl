iproc_source -file /nfs/site/disks/crt_tools_061/eou_flow_design_class/TS2024.6_pnc.2/c2dg_be/snps/fct_pt/fct_custom_report.tcl

set block [ get_object_name [current_design] ] 


set ivar(fct_report_timing_summary_scan_paths) 0
set ivar(fct_report_timing_summary_pba_mode_default) path
#set ivar(fct_report_timing_summary_start_end_pair_default) 1
#set ivar(fct_report_timing_summary_show_endpoint_templ_default) 1
#set ivar(fct_report_timing_summary_show_power_rails_default) 1
#set ivar(fct_report_timing_summary_mpaths_default) <number>     
#set ivar(fct_report_timing_summary_nworst_default) <number>      
#set ivar(fct_report_timing_summary_externals_only_default) 1
#set ivar(fct_report_timing_summary_show_common_point_default) 1

set tps [get_timing_path -exclude [get_ports * ] -to [get_clocks {uclk* mclk_*}]  -norm -max_paths 1500000 -pba path  ]
if { [sizeof_collection $tps ] > 0 }  {
    fct_report_timing_summary "[pwd]/${block}_${scenario}_internal.xml"  $tps
} else  {
    exec touch [pwd]/${block}_${scenario}_internal.xml
}

set tps [get_timing_path -from [get_ports * ] -to [get_clocks {uclk* mclk_*}]   -norm -max_paths 1500000 -pba path  ]
if { [sizeof_collection $tps ] > 0 }  {
    fct_report_timing_summary "[pwd]/${block}_${scenario}_input_ports.xml"  $tps
} else { 
    exec touch [pwd]/${block}_${scenario}_input_ports.xml
} 
set tps [get_timing_path -from [get_clocks {uclk* mclk_*}] -to [get_ports * ] -norm -max_paths 1500000 -pba path  ] 
if { [sizeof_collection $tps ] > 0 }  {
    fct_report_timing_summary "[pwd]/${block}_${scenario}_output_ports.xml" $tps
} else {
    exec touch [pwd]/${block}_${scenario}_output_ports.xml
}
set tps [get_timing_path -to feedthrough_virtual_clock -norm -max_paths 1500000 -pba path  ]
if { [sizeof_collection $tps ] > 0 }  {
    fct_report_timing_summary "[pwd]/${block}_${scenario}_feedthru.xml" $tps
} else {
    exec touch [pwd]/${block}_${scenario}_feedthru.xml
}


source /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/check_clock.tcl 
check_clk_latency [regsub par_ $block mclk_]  > [pwd]/${block}_${scenario}_clock.csv


set fh [open [pwd]/${block}_${scenario}_ulvt_usage.csv w]
puts $fh "ULVT,ULVTLL,LVT,BFM,CLOCK_CELLS,TOTAL_CELLS,FF,FF2,FF4,FF6,FF8,TOTAL_FF,L,L2,L4,L6,L8,TOTAL_L,%ULVT,%ULVTLL,%LVT,%BFM,%MB,D20,FDRD"
set ulvt        [sizeof_collection [get_cells -quiet -hierarchical -filter "ref_name=~*ULVT"]]
set lvt         [sizeof_collection [get_cells -quiet -hierarchical -filter "ref_name=~*LVT && ref_name!~*ULVT"]]
set ulvtll      [sizeof_collection [get_cells -quiet -hierarchical -filter "ref_name=~*ULVTLL"]] 
set bfm         [sizeof_collection [get_cells -quiet -hierarchical -filter "ref_name=~DEL*"]]
set clock_cell  [sizeof_collection [get_cells -quiet -hierarchical -filter "is_clock_network_cell"]]
set total       [sizeof_collection [get_cells -quiet -hierarchical -filter "!is_hierarchical"]]
set total_ff    [sizeof_collection [get_cells -quiet -hierarchical -filter "(is_rise_edge_triggered || is_fall_edge_triggered) && is_sequential && !is_black_box"]]
set ff1         [sizeof_collection [get_cells -quiet -hierarchical -filter "(is_rise_edge_triggered || is_fall_edge_triggered) && is_sequential && !is_black_box && ref_name!~MB*"]]
set ff2         [sizeof_collection [get_cells -quiet -hierarchical -filter "(is_rise_edge_triggered || is_fall_edge_triggered) && is_sequential && !is_black_box && ref_name=~MB2*"]]
set ff4         [sizeof_collection [get_cells -quiet -hierarchical -filter "(is_rise_edge_triggered || is_fall_edge_triggered) && is_sequential && !is_black_box && ref_name=~MB4*"]]    
set ff6         [sizeof_collection [get_cells -quiet -hierarchical -filter "(is_rise_edge_triggered || is_fall_edge_triggered) && is_sequential && !is_black_box && ref_name=~MB6*"]]    
set ff8         [sizeof_collection [get_cells -quiet -hierarchical -filter "(is_rise_edge_triggered || is_fall_edge_triggered) && is_sequential && !is_black_box && ref_name=~MB8*"]]    
set total_latch [sizeof_collection [get_cells -quiet -hierarchical -filter "(is_positive_level_sensitive || is_negative_level_sensitive) && is_sequential && !is_black_box"]]
set l1          [sizeof_collection [get_cells -quiet -hierarchical -filter "(is_positive_level_sensitive || is_negative_level_sensitive) && is_sequential && !is_black_box && ref_name!~MB*"]]   
set l2          [sizeof_collection [get_cells -quiet -hierarchical -filter "(is_positive_level_sensitive || is_negative_level_sensitive) && is_sequential && !is_black_box && ref_name=~MB2*"]]  
set l4          [sizeof_collection [get_cells -quiet -hierarchical -filter "(is_positive_level_sensitive || is_negative_level_sensitive) && is_sequential && !is_black_box && ref_name=~MB4*"]]          
set l6          [sizeof_collection [get_cells -quiet -hierarchical -filter "(is_positive_level_sensitive || is_negative_level_sensitive) && is_sequential && !is_black_box && ref_name=~MB6*"]]  
set l8          [sizeof_collection [get_cells -quiet -hierarchical -filter "(is_positive_level_sensitive || is_negative_level_sensitive) && is_sequential && !is_black_box && ref_name=~MB8*"]]
set total_seq   [expr $total_latch+$total_ff]
set total_mb    [expr $ff2+$ff4+$ff6+$ff8+$l2+$l4+$l6+$l8]
if {$total_seq} {
    set mb_prec [format "%.2f" [expr 100*${total_mb}.0/$total_seq]]
} else {
    set mb_prec 0
}
set ulvt_perc   [format "%.2f" [expr 100*${ulvt}.0/$total]]
set ulvtll_perc [format "%.2f" [expr 100*${ulvtll}.0/$total]]
set lvt_perc    [format "%.2f" [expr 100*${lvt}.0/$total]]      
set bfm_perc    [format "%.2f" [expr 100*${bfm}.0/$total]]
set d20         [sizeof_collection [get_cells -quiet -hierarchical -filter "ref_name=~*D20* && full_name!~*_glbdrv_*"]]
set fdrd        [sizeof_collection  [get_pins -quiet -hierarchical -filter {lib_pin_name == FD || lib_pin_name == RD }] ]
puts $fh "$ulvt,$ulvtll,$lvt,$bfm,$clock_cell,$total,$ff1,$ff2,$ff4,$ff6,$ff8,$total_ff,$l1,$l2,$l4,$l6,$l8,$total_latch,$ulvt_perc,$ulvtll_perc,$lvt_perc,$bfm_perc,$mb_prec,$d20,$fdrd"
close $fh

redirect -var ebb_clk {report_clock_timing -clock [regsub par_ $block mclk_] -type latency -nosplit -capture -from [ get_pins -of_objects [ get_cells -hierarchical -filter "is_black_box && number_of_pins>5"] -filter "(is_clock_pin || is_clock_network) && direction==in"] -nworst 10000 }
set output "" 
echo "ebb_clk_pin,network_latency" > [pwd]/${block}_${scenario}_ebb_clock.csv
foreach line [split $ebb_clk "\n"] {
    set ntwrk_latency [lindex $line end-2]
    if { $ntwrk_latency=="" || ! [regexp {[0-9]+\.[0-9]+} $ntwrk_latency] } { continue }
    lappend output [list [lindex $line 0],$ntwrk_latency]
}
foreach line [lsort $output] { echo $line  >> [pwd]/${block}_${scenario}_ebb_clock.csv}

echo "" > done_$scenario

#source /nfs/site/disks/home_user/baselibr/PNC_script/tip_audit.tcl
#tip_audit_cell [get_cells tip_* ] 
#exec mv [pwd]/tip_audit.of_cells.rpt [pwd]/${block}_${scenario}_tip_audit.rpt

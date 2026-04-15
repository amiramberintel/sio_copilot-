iproc_source -file $ward/design_class/c2dg_be/snps/fct_pt/fct_custom_report.tcl

proc local_xml { {outfile ""} {nworst ""} } {
global ivar
global scenario

if {$nworst eq ""} { set nworst 10 }
if {$outfile eq ""} { set outfile "$ivar(rpt_dir)/$ivar(design_name).${scenario}_timing_summary_only_mclk_ext_$nworst.xml" }
set pba none
puts "output file will be: $outfile"
puts "getting paths: nworst=$nworst pba=$pba"
set tp [get_timing_paths -delay_type $ivar(sta,delay_type) -slack_lesser_than 0 -pba_mode $pba -path_type full_clock_expanded  -include_hierarchical_pins -from [get_clocks mclk*] -through [get_pins -quiet {icore0/par_*/* icore1/par_*/* par_mlc/* par_pm/*}] -to [get_clocks mclk_*] -max_paths 1500000 -nworst $nworst]

#set tp [get_timing_paths -delay_type $ivar(sta,delay_type) -slack_lesser_than 0 -pba_mode $pba -path_type full_clock_expanded  -include_hierarchical_pins -from [get_clocks mclk*] -through [get_pins {icore0/par_*/* icore1/par_*/* par_mlc/* par_pm/*}] -to [get_clocks mclk_*] -max_paths 1500000 -start_end_pair]


set flag [sizeof_collection $tp]
if {$flag > 0} {
    puts "number of paths: $flag"
fct_report_timing_summary $outfile $tp
} else {
    puts "no paths"
}

}



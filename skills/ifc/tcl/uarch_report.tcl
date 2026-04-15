#foreach_in_collection p [get_pins par_ooo_vec/*m301h* -filter "direction == out" -quiet] {
#redirect -append -file keke {[get_object_name $p]}
#}

#catch {exec cat /nfs/iil/disks/home01/gilkeren/uarch_list.csv | grep -v "family" | awk -F "," {{ print $3 "/" $2 }} > test}
#catch {exec cat /nfs/iil/disks/core_fct/lnc/fct/sd08-RTL22ww13b_ww14_5_RCOs_and_clockroute-FCT22WW17D_clk_pd-CLK126.bu_post/a | grep -v "family" | awk -F "," {{ print $4 "/" $5 }} > test2}

#catch { exec cat /nfs/iil/disks/home01/gilkeren/uarch_list.csv | grep -v "family" | awk -F "," {{ print "report_timing -th "$3 "/" $2"* -th "$4" -nosplit -include_hierarchical_pins -input_pins -physical -nets -pba_mode path -transition_time" }} > test }

set f [open /nfs/iil/disks/home01/gilkeren/uarch_list.csv r]
set id 1

set old_value [get_app_var timing_report_fixed_width_columns_on_left]
set_app_var timing_report_fixed_width_columns_on_left true
puts "setting timing_report_fixed_width_columns_on_left to be true"

set out_file "$env(ward)/runs/$env(block)/$tech/sta_pt/$scenario/reports/uarch.rpt"
redirect -file $out_file { puts "#[date]" }

while {[gets $f line] != -1} {
if {$line == "" || [regexp {^\#} $line]} {continue}
set fam [lindex [split $line ","] 0]
set startpoint [lindex [split $line ","] 1]
set drv_par [lindex [split $line ","] 2]
set drv_port [lindex [split $line ","] 3]
set rcv_par [lindex [split $line ","] 4]
set rcv_port [lindex [split $line ","] 5]
set endpoint [lindex [split $line ","] 6]
redirect -append -file $out_file {puts "path $id, from: $startpoint th: $drv_par/$drv_port th: $rcv_par/$rcv_port to: $endpoint"}
set id [expr $id +1]
}
close $f


set f [open /nfs/iil/disks/home01/gilkeren/uarch_list.csv r]
set id 1
while {[gets $f line] != -1} {
if {$line == "" || [regexp {^\#} $line]} {continue}   
set fam [lindex [split $line ","] 0]
set startpoint [lindex [split $line ","] 1]
set drv_par [lindex [split $line ","] 2]
set drv_port [lindex [split $line ","] 3]
set rcv_par [lindex [split $line ","] 4]
set rcv_port [lindex [split $line ","] 5]
set endpoint [lindex [split $line ","] 6]
set cmd "report_timing -from $startpoint -th $drv_par/$drv_port* -th $rcv_par/$rcv_port* -to $endpoint -nosplit -include_hierarchical_pins -input_pins -physical -nets -pba_mode exhaustive -transition_time"
redirect -append -file $out_file {puts "start path id $id "}
redirect -append -file $out_file {puts "starting port: $drv_par/$drv_port to $rcv_par/$rcv_port"}
redirect -append -file $out_file {puts "$cmd"}
redirect -append -file $out_file {puts "[report_timing -from $startpoint -th $drv_par/$drv_port* -th $rcv_par/$rcv_port* -to $endpoint -nosplit -include_hierarchical_pins -input_pins -physical -nets -pba_mode path -transition_time]"}
redirect -append -file $out_file {puts "end port: $drv_par/$drv_port to $rcv_par/$rcv_port"}
redirect -append -file $out_file {puts "end path id $id "}
set id [expr $id +1]
}

redirect -append -file $out_file { puts "#[date]" }


close $f


set file_to_exec  [iproc_source -display -file /nfs/iil/disks/home01/gilkeren/scripts/uarch_wns.csh]
iproc_msg -info "executing uarch summary from $file_to_exec $scenario"
exec >&@stdout $file_to_exec $scenario

set_app_var timing_report_fixed_width_columns_on_left $old_value


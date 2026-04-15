set par [get_attribute  [current_design ] full_name]
file mkdir power_results/

set output_file power_results/$par.port_power.csv
set attribute_file power_results/$par.user_attribute.tcl

if {[regexp $par "par_mlc"] || [regexp $par "par_pm"]} {
    set par_templates "$par"
} else { 
    set par_templates "icore0/$par icore1/$par"
}

set ch [open $output_file "w"]
set ch1 [open $attribute_file "w"]

puts $ch1 "define_user_attribute -type float -classes pin bu_dynamic_power"

set ports [get_ports * ]
puts $ch  "port_name,intenal,switch,leak,total_cell,total_net,total"
foreach_in_collection port $ports { 
    if { [get_attribute $port direction] == "out" } {
        set cells [all_fanin -only_cells -to [get_ports $port ] -flat]
        set nets  [get_nets -of_object [all_fanin -to [get_ports $port ] -flat] ]
        if {[sizeof_collection $cells ] == 0} {
            puts $ch "[get_object_name $port ],0,0,0,0,0,0"
            continue 
        }
    } else { 
        set cells [all_fanout -only_cells -from [get_ports $port ] -flat]
        set nets  [get_nets -of_object [all_fanout -from [get_ports $port ] -flat ] ]
        if {[sizeof_collection $cells ] == 0} {
            puts $ch "[get_object_name $port ],0,0,0,0,0,0"
            continue 
        }
    }
    redirect -variable power_results {report_power $cells -cell_power -nosplit -unit uW }
    set power_results_split [split $power_results "\n"]
    set index [lsearch  $power_results_split "*Totals*100.0%*" ]
    if { $index == -1 } { 
        set power "something is worng"
    } 
    set total_line [lindex $power_results_split $index ]
    set internal [expr double([lindex $total_line 3])]
    set switch   [expr double([lindex $total_line 4])]
    set leak     [expr double([lindex $total_line 5])]
    set total    [expr double([lindex $total_line 6])]
   
    redirect -variable power_results {report_power $nets -net_power -nosplit -unit uW }
    set power_results_split [split $power_results "\n"]
    set index [lsearch  $power_results_split "*Total*net*" ]
    if { $index == -1 } { 
        set power "something is worng"
    } 
    set total_line [lindex $power_results_split $index ]
    set net_power [expr double([lindex $total_line 3])]
    puts $ch "[get_object_name $port],$internal,$switch,$leak,$total,$net_power,[expr $total+$net_power]"
    foreach par_template $par_templates {
        puts $ch1 "set_user_attribute \[get_pins $par_template/[get_object_name $port] \] bu_dynamic_power [expr $total+$net_power] "
    }
}
close $ch
close $ch1

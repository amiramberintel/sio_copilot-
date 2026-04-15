puts "sourcing spec_model_reports.tcl"
source /nfs/iil/disks/home01/gilkeren/scripts/tcl/spec_model_reports.tcl
puts "done sourcing"
puts ""

#################################################################################################
#puts "sourcing POR comments"
#define_user_attribute -quiet -type string -classes pin spec_comment
#puts ""
#puts "sourcing gilkeren"
#puts ""
#source /nfs/iil/disks/home01/gilkeren/lnc/specs/comment_attribute.gilkeren.tcl
#puts "done sourcing gilkeren"
#puts ""
#puts "sourcing atraitel"
#puts ""
#source /nfs/iil/disks/home01/atraitel/lnc/specs/comment_attribute.atraitel.tcl
#puts "done sourcing atraitel"
#puts ""
#puts "sourcing lstambul"
#puts ""
#source /nfs/iil/disks/home16/lstambul/lnc/specs/comment_attribute.lstambul.tcl
#puts "done sourcing lstambul"
#puts ""
#puts "sourcing ecohe15"
#puts ""
#source /nfs/iil/disks/home12/ecohe15/lnc/specs/comment_attribute.ecohe15.tcl
#puts "done sourcing ecohe15"
#puts ""
#puts "sourcing ysternal"
#puts ""
#source /nfs/iil/disks/home01/ysternal/lnc/specs/comment_attribute.ysternal.tcl
#puts "done sourcing ysternal"
#puts ""
#puts "done sourcing"
#puts ""

#################################################################################################
puts "finding output pins"
set par_o_pins [get_pins par_*/* -filter "direction==out && full_name!~*FEEDTHRU*"]

set all_out_ft [get_pins par_*/*FEEDTHRU* -filter "direction==out"]
set pins_with_att [filter_collection $all_out_ft FT_DLY_USER_OVR!~""]
set pins_wo_att [remove_from_collection $all_out_ft $pins_with_att]


set fake_ft ""
foreach_in_collection p $pins_wo_att {
#puts [get_object_name $p]
set par [lindex [split [get_object_name $p] "/"] 0]
#puts $par
set tp [get_timing_paths -th $p -slack_lesser_than INFINITY]
#puts [sizeof_collection $tp]
set start_par [lindex [split [get_object_name  [get_attribute $tp startpoint]] "/"] 0]
#puts $start_par
if {$par == $start_par} {
#puts "[get_object_name $p] is fake_ft"
append_to_collection fake_ft $p
}
}

sizeof_collection $fake_ft 











set out_list [add_to_collection  $par_o_pins $fake_ft]
puts "done finding output pins"
puts ""

#################################################################################################
puts "sourcing ft attributes"
#source fct/ft_attribute.${scenario}.tcl
source runs/$block/$tech/$flow/inputs/ft_attribute.${scenario}.tcl
puts "done sourcing ft attributes"
puts ""

#################################################################################################
puts "starting report"
create_port_spec_slack $out_list $scenario
puts "done"
puts ""

#################################################################################################
puts "starting compression"
puts "-I- soucing /nfs/iil/disks/home01/gilkeren/scripts/spec_compress $scenario"
exec /nfs/iil/disks/home01/gilkeren/scripts/spec_compress $scenario
puts "done"
puts ""

#################################################################################################

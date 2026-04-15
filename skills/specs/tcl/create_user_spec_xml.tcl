exec /nfs/iil/home/gilkeren/lnc/io_constraints/user_xml/create_lnserver_tcl.csh
puts ""
puts ""
source /nfs/iil/disks/home01/gilkeren/lnc/io_constraints/user_xml/full_user_spec.tcl
puts ""
puts ""
puts "tkdiff /nfs/iil/disks/home01/gilkeren//lnc/io_constraints/lncserver.func.max_high.TT_100.tttt_timing_specs.xml runs/$block/$tech/sta_pt/inputs/ &"
puts ""
puts "cp /nfs/iil/disks/home01/gilkeren//lnc/io_constraints/lncserver.func.max_nom.TT_100.tttt_timing_specs.xml fct/"
puts "cp /nfs/iil/disks/home01/gilkeren//lnc/io_constraints/lncserver.func.max_high.TT_100.tttt_timing_specs.xml fct/"
puts ""
puts "cp /nfs/iil/disks/home01/gilkeren//lnc/io_constraints/lncserver.func.max_nom.TT_100.tttt_timing_specs.xml runs/$block/$tech/sta_pt/inputs/"
puts "cp /nfs/iil/disks/home01/gilkeren//lnc/io_constraints/lncserver.func.max_high.TT_100.tttt_timing_specs.xml runs/$block/$tech/sta_pt/inputs/"



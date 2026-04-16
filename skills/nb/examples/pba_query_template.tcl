# TEMPLATE: PBA queries TCL script
# Used with: load_session_cth.csh <session> -file this_script.tcl
# Session is ALREADY restored by load_session_cth.csh — do NOT call restore_session

# --- Run PBA queries ---
set outfile "/path/to/results.txt"  ;# <-- EDIT
set fout [open $outfile w]
puts $fout "# PBA results"
puts $fout "# endpoint\tgba_slack\tpba_slack\tdelta"

# Example: single endpoint query
set sp "icore0/par_pmh/.../start_pin"   ;# <-- EDIT
set ep "icore0/par_meu/.../end_pin"     ;# <-- EDIT

set paths [get_timing_paths -from $sp -to $ep -pba_mode path -max_paths 1 -nworst 1]
if {[sizeof_collection $paths] > 0} {
    set slack [get_attribute [index_collection $paths 0] slack]
    puts "PBA slack = $slack"
    puts $fout "endpoint\t0\t[format %.1f $slack]\t0"
} else {
    puts "NO PATH FOUND"
}

# Example: batch query from file
# set fin [open "/path/to/endpoints.txt" r]
# set lines [split [read $fin] "\n"]
# close $fin
# foreach line $lines {
#     if {$line eq ""} continue
#     set fields [split $line "\t"]
#     set bus [lindex $fields 0]
#     set gba [lindex $fields 1]
#     set sp  [lindex $fields 2]
#     set ep  [lindex $fields 3]
#     set paths [get_timing_paths -from $sp -to $ep -pba_mode path -max_paths 1]
#     if {[sizeof_collection $paths] > 0} {
#         set pba [get_attribute [index_collection $paths 0] slack]
#         puts $fout "$bus\t$gba\t[format %.1f $pba]\t[format %.1f [expr {$pba-$gba}]]"
#     }
# }

close $fout
puts ">>> Results: $outfile"
exit

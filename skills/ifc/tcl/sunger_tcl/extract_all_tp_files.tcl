#================================================================
# JNC TIP: Generate tp files for all 97 GFC signals
# 
# USAGE: Source this in FC after opening the JNC nlib
#   In Kris's FC session (ward = /nfs/site/disks/kknopp_wa/JNC/TIP):
#     source /nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/extract_all_tp_files.tcl
#
# This will:
#   1. Read each GFC tp file to get the signal/net names
#   2. Check if those nets exist in the JNC nlib
#   3. For signals that exist: run utc_write_topology_collateral to generate native JNC tp
#   4. For signals that don't exist: report them
#
# Output: tp files in /nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/jnc_native/
#================================================================

set output_dir "/nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/jnc_native"
file mkdir $output_dir

# Signals already done by Kris (skip these)
set done_signals {
    bplsdaborttoidqm155h dsbfespec123bypenm123h dsbhitm124h
    dsbqwrdatabrnumm124h dsbqwrdatabundlevalidsm124h dsbqwrdatauopsnumm124h
    idforcejeclrm201h idspecavx512m200h ifhitextsnoopm105h
    je2mswrearlym805h_a jeclearlatetomsidm805h jeforceallonesearlym805h
}

# GFC tp files directory
set gfc_dir "/nfs/site/disks/idc_gfc_fct_td/GFC_TIP_WA/tip_files/GFCA0_26WW13_1"

set missing_nets {}
set generated 0
set skipped 0

foreach gfc_tp [glob -nocomplain $gfc_dir/icore.*.tp] {
    set fname [file tail $gfc_tp]
    set sig [string range $fname 6 end-3]  ;# strip "icore." and ".tp"
    
    # Skip already-done signals
    if {[lsearch -exact $done_signals $sig] >= 0} {
        incr skipped
        continue
    }
    
    # Extract net names from GFC tp file (the old_rtl_top_nets_list)
    set fd [open $gfc_tp r]
    set content [read $fd]
    close $fd
    
    if {[regexp {set old_rtl_top_nets_list "([^"]+)"} $content -> nets_str]} {
        set net_names [split $nets_str]
        set first_net [lindex $net_names 0]
        
        # Check if this net exists in JNC nlib
        set net_col [get_nets -quiet $first_net]
        if {[sizeof_collection $net_col] > 0} {
            # Net exists — check if topology plan exists
            set plan_name "${sig}_tp"
            if {[sizeof_collection [get_topology_plans -quiet $plan_name]] > 0} {
                # Plan exists, write it
                utc_write_topology_collateral -file_name $output_dir/icore.${sig}.tp -topology_plans $plan_name
                incr generated
                puts "  ✓ Generated: icore.${sig}.tp"
            } else {
                puts "  ⚠ Net exists but no topology plan: $sig"
                lappend missing_nets "$sig (net exists, no plan)"
            }
        } else {
            puts "  ✗ Net not found: $first_net ($sig)"
            lappend missing_nets "$sig (net not in nlib)"
        }
    }
}

puts "\n================================================================"
puts "SUMMARY:"
puts "  Generated: $generated tp files"
puts "  Skipped (already done): $skipped"
puts "  Missing/no plan: [llength $missing_nets]"
if {[llength $missing_nets] > 0} {
    puts "\nSignals without tp files:"
    foreach s $missing_nets {
        puts "  - $s"
    }
}
puts "================================================================"

#!/usr/intel/bin/tclsh8.6

#-- Copyright (c) Intel Corporation
#-- Intel Proprietary and Confidential Information

# basic args parsing - not used in main MOW
foreach i [lsearch -all $argv "\-*"] {
    set j [expr $i+1]
    set flag [lindex $argv $i]
    #     regsub "^\-" $flag "" flag
    set value [lindex $argv $j]
    if {$value == "" || [regexp "^\-" $value]} {
        set opt($flag) ""
    } else {
        set opt($flag) $value
    }
} 

### help message
if {[info exist opt(-h)] || [info exist opt(-help)]} {
    puts "Usage: running Fishtail for SIO FCT"
    puts "Usage: for specific partition: pls run: \$GFC_FCT_SCRIPTS/fishtail.tcl -partitions \"par_a par_b\""
    exit 0
}




###################################################################
#    Source common setup Files                                    #
###################################################################

# source all configs and vars
source $::env(ward)/global/common/setup.tcl

# Redundant?
iproc_source -file $::env(USER_FCT_VARS) -optional

# exit script on iproc_source -fatal
set ivar(exit_on_fatal) 1

#################################################################
# PROCS
#################################################################

# useful proc to run external commands. gives fatal error on nonzero exit code. can run commands in background or source files. see arguments list and description after proc
proc fctSystem {args} {
    set arg(-background) 0
    set arg(-is_file)    0
    set arg(-no_fail)    0
    set arg(-verbose)    0
    set arg(-quiet)      0
    parse_proc_arguments -args $args arg
    set cmd_text   $arg(-cmd)
    set background $arg(-background)
    set is_file    $arg(-is_file)
    set no_fail    $arg(-no_fail)
    set verbose    $arg(-verbose)
    set quiet      $arg(-quiet)
    if {$quiet == 1 && $verbose == 1} {
        iproc_msg -fatal "Can't have -quiet and -verbose active for a cmd in fctSystem, its conflicting"
    }
    if {$quiet == 1} {
        set cmd_text "$cmd_text >/dev/null 2>&1"
    }
    if {$background == 1} {
        set cmd_text "$cmd_text &"
    }
    if {$is_file == 1} {
        set cmd_text "/usr/intel/bin/tcsh -f $cmd_text"
    }
    set cmd "$cmd_text"

    iproc_msg -info "Executing System Command: $cmd_text"
    if {$verbose == 1} {
        set cmd_exit_code [catch {eval exec >&@stdout $cmd} res]
    } else {
        set cmd_exit_code [catch {eval exec $cmd} res]
    }
    if {$cmd_exit_code != 0 && $no_fail == 0} {
        iproc_msg -fatal [concat "-E- Error occurred while executing system command" $::errorInfo]
    }
    return $cmd_exit_code
}

define_proc_attributes fctSystem \
    -info "cthPrep proc that runs external commands or csh scripts " \
    -define_args {
        {-cmd "command or csh script to execute" "CMD" string required}
        {-background "used to decide if to run command with &, in the background" "" boolean optional}
        {-is_file "used to execute csh scripts instead of one line commands" "" boolean optional}
        {-no_fail "don't crash if the command returned non 0 exit code" "" boolean optional}
        {-verbose "print the stdout caught by the catch command" "" boolean optional}
        {-quiet "direct all output to dev/null" "" boolean optional}
    }


##################################################################
# MAIN
#################################################################

if {[info exist opt(-partitions)]} {
    set ivar(fct_setup_cfg,partitions_for_fishtail) $opt(-partitions)
}


#iproc_msg -info "ivar(fct_setup_cfg,partitions_for_fishtail) = $ivar(fct_setup_cfg,partitions_for_fishtail)"

set ivar(fct_prep,enable_fishtail_standalone) 1

# run fishtail
if { [info exists ivar(fct_prep,enable_fishtail_standalone)] && $ivar(fct_prep,enable_fishtail_standalone) == 1} {
    iproc_msg -info "Running fishtail"
    if { [info exists  ivar(fct_setup_cfg,partitions_for_fishtail)]  && $ivar(fct_setup_cfg,partitions_for_fishtail) != ""} {

        # dserebro - create netlist and constraint inputs for fishtail
###        iproc_msg -info "copying timing_collateral to partition level and copying netlist into par_*.pt.v.gz"
###        set FT_pars [split $ivar(fct_setup_cfg,partitions_for_fishtail) ","]
###        foreach FT_par $FT_pars {
###            # Copy global*constraint.tcl to runs/par_*/1277.2/release/latest/timing_collateral/
###            set par_timing_col_dir "$::env(ward)/runs/$FT_par/$::env(tech)/release/latest/timing_collateral/"
###	    file delete -force "$::env(ward)/runs/$FT_par/$::env(tech)/release/latest/timing_collateral/global_*_constraints.tcl"
###            file mkdir $par_timing_col_dir
###            set glob_const_files [glob -nocomplain "$::env(ward)/runs/$top_block/$::env(tech)/release/latest/timing_collateral/global*constraints.tcl"]
###            foreach glob_const_file $glob_const_files {
###                fctSystem -cmd "/bin/cp -f $glob_const_file $par_timing_col_dir"
###            }
###        }

      set partitions "-partitions $ivar(fct_setup_cfg,partitions_for_fishtail)"
      iproc_msg -info "running fishtail on partition list: $ivar(fct_setup_cfg,partitions_for_fishtail)"
    } else {
      set partitions ""
      iproc_msg -info "running netlist mapping on ALL partitions"
    }
    set fishtail_script [iproc_source -display -file "fctRunFishTail.pl"]
    if {$fishtail_script eq ""} {
        iproc_msg -error "fctRunFishTail.pl not found. Skipping fishtail"
    } else {
        fctSystem -verbose -cmd "$fishtail_script $partitions"
    }
} else {
    iproc_msg -info "Skipping fishtail because ivar(fct_prep,enable_fishtail) != 1"
}



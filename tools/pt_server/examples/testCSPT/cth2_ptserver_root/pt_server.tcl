#-----------------------------------------------------------------------------------
# (C) Copyright Intel Corporation, 2021
# Licensed material -- Program property of Intel Corporation
# All Rights Reserved
#
# This program is the property of Intel Corporation and is furnished
# pursuant to a written license agreement. It may not be used, reproduced,
# or disclosed to others except in accordance with the terms and conditions
# of that agreement.
#-----------------------------------------------------------------------------------
# Author      : Givol, Ohad ; Balandin, Dmitry ; Ooi, Thean Wui
# Date        : Jan 01 2021
# Project     : LNL
# Revision    : 3.0
# Description : PT live server session (source code for server setup)
#------------------------------------------------------------------------------------


proc read_cfg {cfg_file _socket} {
   upvar socket $_socket
   set FH [open $cfg_file r]
   while { [gets $FH line] >=0} {
      if {[regexp  {set} $line match] || [regexp  {^\s*\#\#} $line match]} {
         continue
      }
      if {[regexp  {^\s*\#} $line match] } {
         regsub {\#} $line "" line
         set line_split [split $line ","]
	 lassign $line_split model type corner modelb_or_modela process machine socket_num
	 set model_type "${modelb_or_modela}_${model}_${type}"
	 set server_name "${model_type}_${corner}"
	 set socket($server_name) $socket_num
      }
   }
}

##---------------------------------------------------
# Global variable setting      
##---------------------------------------------------


puts "-I- pt_server_dir is '$pt_server_dir'"
source $pt_server_dir/pt_server_c2dgbcptserver_cron.cfg
array set socket {} 
read_cfg "$pt_server_dir/pt_server_c2dgbcptserver_cron.cfg" socket
if {![info exist no_restore]} {
  set no_restore 0  
}

# *** Use static pointer for latest model
#<your_fct_session_db> e.g: /nfs/site/disks/hdk.archive.001/hdk73/ccdoint/fct/GSDB0/models/latest_gsd/primetime/func_max/dbs/soc.func_max.analyze_design

if {![info exist real_session_old]} {
  set real_session_old "NULL"  
} else {
  #puts "-I- real_session_old is defined as '$real_session_old'"
}

#Synthactic suger to capture first and second match below:
#https://wiki.tcl-lang.org/page/Regular+Expression+Examples
#(/nfs/iil/proj/icl/icl_soc_execution/soc/mpollack/fct/lnltr/REFLATEST-FCT20WW31B.try_3-CLK003.fcl/)/runs/soc/1276.31/sta_pt/sta/(func.max_low.TT_100.tttt)/outputs/soc.pt_session.func.max_low.TT_100.tttt/
#(/nfs/iil/disks/soc_fct_backup_models10/backup/adl_backup/adlg0/ADLG0P10-RTL20WW28a_ww31.2-FCNWW31E-FCLWW31G-FCT20WW33C-CLK21.bu_postcts/)primetime/(func_max_lowvcc)/dbs/

#if {[regexp {^(.*)/runs/.*/sta/(.*)/outputs/.*$} $dbs -> fct_path pt_corner]} {
if {[regexp {sta/(.*)/outputs} $dbs]} {
    regexp {^(.*)/runs/.*/sta/(.*)/outputs/.*$} $dbs -> fct_path pt_corner
    set real_path [file readlink $fct_path] 
    puts "-I- for $dbs: case A...\n";
    puts "-I- fct_path:${fct_path} && pt_corner:${pt_corner}\n";
} elseif {[regexp {primetime/(.*)/dbs/} $dbs]} {
    regexp {^(.*)/primetime/(.*)/dbs/.*$} $dbs -> fct_path pt_corner
    set real_path [file readlink $fct_path]
    puts "-I- for $dbs: case B...\n";
    puts "-I- fct_path:${fct_path} && pt_corner:${pt_corner}\n";
}

#proc to deny web queries
proc check_for_web_command {channel command} {
    set favicon_string "favicon.ico"

    if {[regexp {GET\s+(.*)\s+HTTP/.*} $command]} {
      puts "-W- Web access is not allowed. Command ignored."
      redirect -channel $channel "puts \"-W- Web access is not allowed. Command ignored.\""
      #redirect -channel $channel "puts \"POST <html><head>TEST</head></html>HTTP/1.1\""
      close $channel
      return 1
    }
    if {[regexp $command $favicon_string]} {
      close $channel
      return 1
    }
    return 0
}


proc handle_user_request {channel addr port} {
    global counter
    global pt_corner
    global real_path
    global pt_username
    global pt_server_dir
    global dbs
    global command_count
    global real_session_old

    #upvar script variables
    upvar refresh refresh
    upvar force_refresh force_refresh
    upvar sock sock
    upvar no_restore no_restore
    upvar pt_server_no_restore pt_server_no_restore
    upvar latest_flag latest_flag

    #upvar cfg variables
    upvar disallow_list disallow_list
    upvar special_commands_list special_commands_list
    upvar admin_list admin_list
    upvar favicon_string favicon_string


    #supress triple messages
    if {![info exist command_count]} {
      set command_count 0
    } else {
      set command_count [expr ($command_count+1)%3]
    }

    
    ## access limit for GSD db with 128G mem machine //vary for different project and mem capacity
    if {[info exist counter] && $counter >= 10} {
         redirect -channel $channel "puts \"-W- Query queue full (counter = $counter > 10), please try later . . .\""
         close $channel
 	incr counter -1
         return
    }
    set command [gets $channel]

    #init username if needed
    if {![info exist pt_username]} {
      set pt_username "NULL"  
    }



    #deny web access
    if {[check_for_web_command $channel $command]} {
      incr counter -1
      return
    }
    #######################

    ## get username querying db 
    if {[regexp {set pt_user} $command]} {
      regexp {set\spt_user\s(\S+)} $command matched pt_username
    }

    #set admin mode if user is in admin list
    set admin_mode 0
    if {![info exist admin_list]} {
      source $pt_server_dir/pt_server_c2dgbcptserver_cron.cfg
    }

    if {[regexp $pt_username $admin_list]} {
      set admin_mode 1
    }
    if {$admin_mode && $command_count == 0} {
      puts "-I- Admin mode is active. User is $pt_username."
    }

    ## input command limit
    ## disable any commands that will trigger timing update (defined @ cfg file)
    if {![info exist disallow_list]} {
      source $pt_server_dir/pt_server_c2dgbcptserver_cron.cfg
    }
    set regexp "^\s*([join $disallow_list |])"
    if {[regexp $regexp $command] && !$admin_mode} {
        redirect -channel $channel "puts \"-W- Query forbidden - The following command is NOT allowed!!\n    [join $disallow_list ,]\""
        close $channel
	incr counter -1
        return
    }

    #check special commands
    if {![info exist special_commands_list]} {
      source $pt_server_dir/pt_server_c2dgbcptserver_cron.cfg
    }
    set regexp "^\s*([join $special_commands_list |])"
    if {[regexp $regexp $command]} {
        handle_special_command $pt_username $channel $command
	incr counter -1
        return
    }

    ## ping server
    set paging "^\\s*ping\\s*$"
    if {[regexp $paging $command]} {
      redirect -channel $channel "puts \"Hello, ping from server\""
      close $channel
      incr counter -1
      return
    }
    ## fix ww48  //fixed access counter bug //print model info
    if {![info exist counter]} { 
      set counter 1
    } else {
      incr counter
    }

    #set fo "$pt_server_dir/pt_track.log"
    if {![regexp {set pt_user} $command]} {
      puts "[date] Client#$counter $pt_username $addr:$port\nCommand: $command"
      #redirect $fo -append {puts "[date] Client#$counter $pt_username $addr:$port\nCommand: $command"}
    }
    #puts "Client#$counter $addr:$port\nCommand: $command"
    redirect -channel $channel "puts \"\n-I- MODE:  $pt_corner\n-I- MODEL: $real_session_old\n\""

    #try to execute command
    if {[catch {redirect -channel $channel "$command"}]} {
      puts "-W- Failed to execute command:'$command'"
      redirect -channel $channel "puts \"\n-W- Failed to execute command:'$command'\""
      #redirect $fo -append {puts "[date] -W- Failed to execute command:'$command'"}
    }

    incr counter -1
    close $channel
}

#handle special commands - server fucntions instead of pt_shell commands
proc handle_special_command {pt_username channel command } {
  global env
  global counter
  global pt_server_dir
  global pt_corner
  global no_restore
  global sock
  global pt_server_no_restore
  global model_type
  global real_session_old

  if {"$command" == "refresh"} {
    upvar refresh refresh
    refresh $pt_username $channel 
    set counter 0
  }
  if {"$command" == "force_refresh"} {
    upvar refresh refresh
    upvar force_refresh force_refresh
    force_refresh $pt_username $channel
    set counter 0
  }

  if {"$command" == "refresh_no_restore"} {
    upvar no_restore no_restore
    upvar refresh refresh
    refresh_no_restore $pt_username $channel  
  }
  if {"$command" == "terminate"} {
    upvar sock sock
    terminate $pt_username $channel $sock
  }
  if {"$command" == "get_dbs"} {
    upvar dbs dbs
    get_dbs $pt_username $channel $dbs $real_session_old
  }
  if {[regexp "set_global_no_restore" $command]} {
    upvar pt_server_no_restore pt_server_no_restore
    set_global_no_restore $command
  }

  if {"$command" == "set_as_modelb"} {
    if {[regexp {^modelb_} $model_type]} {
       redirect -channel $channel "puts \"\n-I- Server is already modelb. model_type is '$model_type'\"" 
    } else { 
       upvar dbs dbs
       set modelb_model_type $model_type
       regsub {^modela_} $modelb_model_type {modelb_} model_type
       regsub $modelb_model_type $dbs $model_type dbs
       redirect -channel $channel "puts \"\n-I- Server was updated from '$modelb_model_type' to '$model_type'\""
    }
  }

  if {"$command" == "set_as_modela"} {
    if {[regexp {^modela_} $model_type]} {
       redirect -channel $channel "puts \"\n-I- Server is already modela. model_type is '$model_type'\"" 
    } else { 
       upvar dbs dbs
       set modelb_model_type $model_type
       regsub {^modelb_} $modelb_model_type {modela_} model_type
       regsub $modelb_model_type $dbs $model_type dbs
       redirect -channel $channel "puts \"\n-I- Server was updated from '$modelb_model_type' to '$model_type'.\""
    }
  }

  #if {"$command" == "init_user_utils"} {
  #  # source User Utils procs and aliases
  #  redirect -channel $channel "puts \"-I- Sourcing user utils: rdt_source_if_exists -inclusive rdt_utils.tcl\""
  #  if {[lsearch [getvar G_SCRIPTS_SEARCH_PATH] $env(SD_USER_UTILS)/] == -1} {
  #     lappend_var G_SCRIPTS_SEARCH_PATH $env(SD_USER_UTILS)/
  #  }
  #  rdt_source_if_exists -inclusive rdt_utils.tcl
  #}


  close $channel
}

proc set_global_no_restore {command} {
    upvar pt_server_no_restore pt_server_no_restore
    puts "command is '$command'"
    regexp {set_global_no_restore\s+(\d*)} $command matched pt_server_no_restore
    puts "-I- pt_server_no_restore is now set to '$pt_server_no_restore'"
    if {$pt_server_no_restore == 0} {
      catch {unset pt_server_no_restore}
    }
}

#refresh by user request
proc refresh {pt_username channel } {
  puts "-I- Refreshing upon user request. User is '$pt_username'."
  upvar refresh refresh
  set refresh 1
  redirect -channel $channel "puts \"-I- Refresh in progress.\""

}

#force-refresh by user request - session will restore even if it's the same
proc force_refresh {pt_username channel } {
  puts "-I- Refreshing upon user request. User is '$pt_username'."
  upvar refresh refresh
  upvar force_refresh force_refresh
  set force_refresh 1
  set refresh 1
  redirect -channel $channel "puts \"-I- Refresh in progress.\""

}

#refresh without restoring session
proc refresh_no_restore {pt_username channel } {
  puts "-I- Refreshing upon user request without restoring sessions. User is '$pt_username'."
  upvar refresh refresh
  upvar no_restore no_restore
  set no_restore 1
  set refresh 1
  redirect -channel $channel "puts \"-I- Refresh successful.\""
}

#terminate server
proc terminate {pt_username channel sock} {
  puts "-I- Terminating server. User is '$pt_username'."
  redirect -channel $channel "puts \"-I- Terminating server.\""
  close $channel
  close $sock
  exit
}

#get dbs path
proc get_dbs {pt_username channel dbs real_session_old} {
  puts "-I- Returning dbs path: '$dbs'."
  redirect -channel $channel "puts \"-I- dbs is: '$dbs'.\n-I- dbs_real is: '$real_session_old'\""
}

proc get_call_stack {} {
       #puts "Entered x, args $a"
       set distanceToTop [info level]
       for {set i 1} {$i < $distanceToTop} {incr i} {
          set callerlevel [expr {$distanceToTop - $i}]
          puts "CALLER $callerlevel: [info level $callerlevel]"
      }
    # ...
       return
}



proc get_time_to_wait {refreshTime} {
  after 1001 {set refresh_delay 1}
  vwait refresh_delay
  catch {unset refresh_delay}
  set systemTime_seconds [clock seconds]
  set refreshTime_seconds [clock scan $refreshTime -format {%H:%M}]

  set timeToWait_seconds [expr $refreshTime_seconds - $systemTime_seconds]

  while {$timeToWait_seconds < 0} {
    set time24Hours_seconds [expr 24*60*60]
    set timeToWait_seconds [expr $timeToWait_seconds + $time24Hours_seconds]
  }



  return [expr $timeToWait_seconds*1000]
  
} 

proc post_time_to_wait_for_humans {timeToWait_seconds} {
  set t_hour "0"
  set t_minute "0"

  if {$timeToWait_seconds >= [expr 60*60]} {
    set t_hour [expr $timeToWait_seconds/(60*60)]
    set timeToWait_seconds [expr $timeToWait_seconds - $t_hour*60*60]
  }

  if {$timeToWait_seconds >= [expr 60]} {
    set t_minute [expr $timeToWait_seconds/(60)]
    set timeToWait_seconds [expr $timeToWait_seconds - $t_minute*60]
  }

  puts "-I- Next refresh is in $t_hour Hours, $t_minute Minutes, $timeToWait_seconds Seconds."

}


##---------------------------------------------------
# Main TCL program  
##---------------------------------------------------

puts "-I- Server initiating."
catch {unset refresh}  

#set corner and/or model
if {[info exist model_type] && "$model_type" != ""} {
  set model_corner "${model_type}_$pt_corner"
} else {
  set model_corner $pt_corner
}
set model_corner_bak $model_corner  

puts "-I- model_corner is '$model_corner'"
set server_loading_file "$pt_server_model_status_per_model_type/$model_corner.loading"

#validate session and save realpath
if {[file exist $dbs]} {
    set real_session_new [exec realpath $dbs]
    if {! [file exist $real_session_new]} {
       puts "-E- session '$real_session_new' does not exist. set: no_restore = 1" 
       set no_restore 1
    }
} else {
  puts "-E- session '$dbs' does not exist. Aborting server operation."
  exit
}

#if old session and new session are the same - don't refresh
#puts "-I- MIDDLE:\nreal_session_old='$real_session_old'\nreal_session_new='$real_session_new'"
if {"$real_session_new" == "$real_session_old"} {
  puts "-I- New sessions is same as old session, not restoring."
  puts "-I- New session: $real_session_new"
  puts "-I- Old session: $real_session_old"
  set no_restore 1
}

if {[info exist pt_server_no_restore]} {
  if {$pt_server_no_restore == 1} {
    puts "-I- pt_server_no_restore is defined as '$pt_server_no_restore'."
    set no_restore $pt_server_no_restore  
  }
  
}

if {[info exist force_refresh]} {
  if {$force_refresh} {
    set no_restore 0
  }
  set force_refresh 0
}
 

#set default aliases file if one is not supplied @ cfg file
if {![info exist aliases_file]} {
  set aliases_file /nfs/iil/disks/home17/cdgptserver/.synopsys_pt.setup
}
puts "-I- Sourcing PT alias: '$aliases_file'"
catch {redirect -var err "source $aliases_file"}
puts "-I- no restore is '$no_restore'."

#restore session unless it's not required
if {$no_restore == 1} {
  set no_restore 0
  puts "-I- Refreshing server without restoring session."
} else {
  puts "-I- Reloading save session: $dbs ([date])"
  set fp_loading_state [open $server_loading_file w]
  set real_session_dbs_path [exec realpath $dbs]
  puts $fp_loading_state "Your Current dbs path is: $real_session_dbs_path"
  close $fp_loading_state  
  #exec touch $server_loading_file
  #source $env(PV_FLOW_PATH)/scripts/rdt_pv_packages.tcl
  set G_FLOW_TYPE pv
  set G_CORNER_NAME $pt_corner
  #source $::env(RDT_COMMON_PATH)/common/scripts/run.tcl
  set real_session_old [exec realpath $dbs]
  restore_session $dbs
  #source $env(PV_FCT_FLOW_PATH)/utils/report_budget.tcl
}

set counter 0 
#set unconstrained paths to true
set timing_report_unconstrained_paths true

#make sure required socket is defined and open it for listening
if {[info exist socket($model_corner)]} {
  set sock [socket -server handle_user_request $socket($model_corner)]  
} else {
  puts "-E '$model_corner' is not defined at cfg file. Aborting."
  exit
}
puts "-I- Finished loading server at [date]"

#in case refresh_time isn't defined @ pt_server.cfg
if {![info exist refresh_time]} {
  set refresh_time "00:00"
}

set t_sec [get_time_to_wait $refresh_time]
post_time_to_wait_for_humans [expr $t_sec/1000]
 
# remove server loading file
exec rm -f $server_loading_file
puts "removed server_loading_file ($server_loading_file)"
puts "########################################################"
#wait for as long as defined to perform a refresh

after $t_sec {set refresh 1}
vwait refresh
close $sock

#re-source this script recursivly - allows for live updates based on pt_server_dir status based on pt_server_dir status:
set thisScript [info script]
source $thisScript


package require TclOO

proc oo::InfoClass::exists {className} {
  return [expr {[uplevel 1 [list info object isa object $className]] && [uplevel 1 [list info object isa class $className]]}]
}
if {[oo::InfoClass::exists sio_mow_client_api]} {
  sio_mow_client_api destroy
}
oo::class create sio_mow_client_api {
  variable Server Port Channel StartMsg EndMsg Name DEBUG WaitTime allowedCmds
  constructor {server port {name ""} {start startMsg} {end endMsg}} {
    set DEBUG DEBUG
    set Server $server
    set Port $port
    set StartMsg $start 
    set EndMsg $end
    set WaitTime 1000
    set Name $name
    array set allowedCmds [list sio_mow_min_delay_min_max_logic_count 1]
  }
  method ifAllowed {cmdd} {
    my logInfo DEBUG $cmdd
    set cmd [lindex [string trim $cmdd] 0]
    return [expr {[info exists allowedCmds($cmd)] && $allowedCmds($cmd) }]
  }
  destructor {
    catch {close $Channel}
    my logInfo $DEBUG "destructor: Ended with value [self]"
  }
  method GetCmd {line} {
    set job [join [lassign [split $line :] cmd key] :]
    return [list $cmd $key $job]
  }
  method logInfo {type msg } {
    set timeStampLog [clock format [clock seconds] -format "%d/%m/%y::%H:%M:%S"]
    puts "${timeStampLog}::$type - $msg <EOF>"
    flush stdout
  }
  method sendData {data {ch ""}} {
    if {$ch eq ""} {
      set ch $Channel
    }
    my logInfo $DEBUG "sendData: $data"
    puts $Channel "$StartMsg"
    puts $Channel "${data}"
    puts $Channel "$EndMsg"
    flush $Channel
  }
  method OpenChannel {} {
    set do 5
    while {[incr do -1]} {
      try {
        return [set Channel [socket $Server $Port]]
      } on error {result options} {
        if {$do == 1 || $result ne "couldn't open socket: address already in use"} {
          return -options $options $result
        }
      }
    }
  }
  method needMe {} {
    set ch [my OpenChannel]
    my sendData "NEED_ME:${Name}"
    lassign [my GetData $ch] cmd
    return [string equal NEED_YOU $cmd]
    close $ch
  }
  method getStatus {} {
    set ch [my OpenChannel]
    set Channel $ch
    my sendData "GET_STATUS:${Name}"
    puts [gets $ch]
    close $ch
  }
  method ApiSwitch {cmd key job} {
    switch $cmd {
      WAIT {
        my logInfo $DEBUG "WAIT: $cmd"
        after $WaitTime
      }
      JOB_FOR_YOU {
        # my logInfo DEBUG "-> $job <-"
        set data "DATA_FOR_JOB:${Name}:${key}\n"
        set data2 NOT_ALLOWED_COMMAND
        if {[my ifAllowed $job]} {
          set TIME_start [clock clicks -milliseconds]
          set data2 [{*}[set job]]
          set TIME_taken [expr [clock clicks -milliseconds] - $TIME_start]
          my logInfo DEBUG "$job : time: $TIME_taken"
        }
        append data $data2
        set ch [my OpenChannel]
        my sendData $data
        close $ch
      }
      WE_ARE_DONE {
        my logInfo "DEBUG" "Got WE_ARE_DONE"
        return 0
      }
      default {
        return 0
      }
    }
    return 1
  }
  method api {} {
    set do 1
    while {$do} {
      set ch [my OpenChannel]
      my sendData "I_AM_READY:${Name}"
      lassign [my GetData $ch] cmd key job
      close $ch
      set do [my ApiSwitch $cmd $key $job]
    }
  }
  method GetData {{ch ""}} {
    if {$ch eq ""} {
      set ch $Channel
    }
    set todo [gets $ch]
    # my logInfo $DEBUG "GetData: $todo"
    return [my GetCmd $todo]
  }
}

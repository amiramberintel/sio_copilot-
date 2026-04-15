################################################################################
# pt_server.tcl
#
# Simple TCP socket server for a PrimeTime (pt_shell) session.
# Just source this file — the server starts and enters the event loop
# automatically.  No extra calls needed.
#
# Usage (inside pt_shell):
#   source /path/to/testCSPT/pt_server.tcl          ;# default port 9877
#   source /path/to/testCSPT/pt_server.tcl 9900     ;# custom port (not supported
#                                                    ;#  by source; set env var
#                                                    ;#  PT_SERVER_PORT instead)
#
# Or set a custom port before sourcing:
#   set ::env(PT_SERVER_PORT) 9900
#   source /path/to/testCSPT/pt_server.tcl
#
# On startup the script appends a cfg-format entry to the shared "ports" file:
#   #project,type,corner,model,process,machine,port
# This is the same format as pt_server_c2dgbcptserver_cron.cfg so
# pt_client.pl and fct_server_tool.py can parse it directly.
#
# Each client connection sends ONE Tcl command line, the server executes it
# in the global scope, streams all output back through the socket, then
# closes the connection.  Send "ping" to test liveness; send "quit" to stop.
#
# To stop the server from another terminal / client:
#   pt_client.py <host> <port> quit
# Or from inside PT (if you break out of vwait somehow):
#   pt_server_stop
################################################################################

namespace eval pt_server {
    variable sock        ""   ;# server (listening) socket
    variable port        0
    variable stop        0    ;# vwait target — set to 1 to exit event loop
    variable marker_file ""   ;# path of the shared ports file
    variable cfg_file    ""   ;# path of the cfg file (for pt_client.pl)
    variable label       ""   ;# this instance's cfg entry string
}

# ---------------------------------------------------------------------------
# Internal: handle one line received from a client
# ---------------------------------------------------------------------------
proc _pt_server_read {chan} {
    if {[catch {gets $chan line} err] || [eof $chan]} {
        catch {close $chan}
        return
    }
    # gets returns -1 if a full line is not yet available (non-blocking)
    if {$line eq ""} return

    # One command per connection — stop watching for more data
    fileevent $chan readable {}

    set cmd [string trim $line]
    puts "\[pt_server\] recv: $cmd"

    switch -nocase -- $cmd {
        "ping" {
            puts  $chan "PONG"
            flush $chan
            close $chan
            return
        }
        "quit" -
        "stop" {
            puts  $chan "OK stopping server"
            flush $chan
            close $chan
            pt_server_stop
            return
        }
    }

    # Execute the command and send its full output back to the client
    fconfigure $chan -blocking 1 -buffering full
    if {[catch {redirect -channel $chan {uplevel #0 $cmd}} err]} {
        catch {puts $chan "\[ERROR\] $err"}
    }
    catch {flush $chan}
    catch {close $chan}
    puts "\[pt_server\] done"
}

# ---------------------------------------------------------------------------
# Internal: accept a new client connection
# ---------------------------------------------------------------------------
proc _pt_server_accept {chan addr cport} {
    puts "\[pt_server\] connection from $addr:$cport"
    fconfigure $chan -blocking 0 -buffering line -translation auto
    fileevent  $chan readable [list _pt_server_read $chan]
}

# ---------------------------------------------------------------------------
# Internal: open the server socket and write the <host>:<port> marker file
# ---------------------------------------------------------------------------
proc _pt_server_start {{port 9877}} {
    # Tear down any previous instance
    if {$pt_server::sock ne ""} {
        catch {close $pt_server::sock}
        set pt_server::sock ""
    }
    set pt_server::stop 0

    if {[catch {socket -server _pt_server_accept $port} srv]} {
        puts "\[pt_server\] ERROR: cannot open port $port — $srv"
        return -code error $srv
    }

    set pt_server::sock $srv
    lassign [chan configure $srv -sockname] - - actual_port
    set pt_server::port $actual_port

    set host [info hostname]
    # pt_client.pl appends ".${site}.intel.com" to the machine name from cfg,
    # so we need just the short hostname (strip domain if present)
    set short_host [lindex [split $host "."] 0]

    # Read cfg-compatible fields from Tcl variables set by wrapper files.
    # Defaults are provided so the server works even without a wrapper.
    set project "unknown"
    set type    "local"
    set corner  "unknown"
    set model   "modela"
    set process "local"

    if {[info exists ::pt_server_project] && $::pt_server_project ne ""} {
        set project $::pt_server_project
    }
    if {[info exists ::pt_server_type] && $::pt_server_type ne ""} {
        set type $::pt_server_type
    }
    if {[info exists ::pt_server_corner] && $::pt_server_corner ne ""} {
        set corner $::pt_server_corner
    }
    if {[info exists ::pt_server_model] && $::pt_server_model ne ""} {
        set model $::pt_server_model
    }
    if {[info exists ::pt_server_process] && $::pt_server_process ne ""} {
        set process $::pt_server_process
    }

    # CFG format: #project,type,corner,model,process,machine,port
    # Same format as pt_server_c2dgbcptserver_cron.cfg so pt_client.pl can parse it
    # Uses short_host because pt_client.pl appends ".site.intel.com"
    set entry "#${project},${type},${corner},${model},${process},${short_host},${actual_port}"
    set pt_server::label $entry

    # Append to BOTH the ports file (for our GUI) and the local cfg file (for pt_client.pl)
    set script_dir [file dirname [file normalize [info script]]]
    set pt_server::marker_file [file join $script_dir "ports"]
    set fh [open $pt_server::marker_file a]
    puts $fh $entry
    close $fh

    set cfg_file [file join $script_dir "cth2_ptserver_root" "pt_server_c2dgbcptserver_cron.cfg"]
    if {[file exists [file dirname $cfg_file]]} {
        set pt_server::cfg_file $cfg_file
        set fh [open $cfg_file a]
        puts $fh $entry
        close $fh
        puts "  \[pt_server\] written to cfg: $cfg_file"
    }

    puts ""
    puts "  \[pt_server\] project:      $project"
    puts "  \[pt_server\] corner:       $corner"
    puts "  \[pt_server\] model:        $model"
    puts "  \[pt_server\] ready on      ${host}:${actual_port}"
    puts "  \[pt_server\] cfg entry:    $entry"
    puts "  \[pt_server\] to stop:      pt_server_stop"
    puts ""
    return $actual_port
}

# ---------------------------------------------------------------------------
# Public: stop the server, exit the event loop, remove own entry from ports
# ---------------------------------------------------------------------------
proc pt_server_stop {} {
    if {$pt_server::sock ne ""} {
        catch {close $pt_server::sock}
        set pt_server::sock ""
    }
    # Helper: remove this instance's label from a file
    proc _remove_from_file {filepath label} {
        if {$filepath ne "" && [file exists $filepath]} {
            set fh [open $filepath r]
            set lines [split [string trimright [read $fh] "\n"] "\n"]
            close $fh
            set remaining {}
            foreach line $lines {
                if {[string trim $line] ne "" && [string trim $line] ne $label} {
                    lappend remaining [string trim $line]
                }
            }
            set fh [open $filepath w]
            if {[llength $remaining] > 0} {
                puts $fh [join $remaining "\n"]
            }
            close $fh
            puts "\[pt_server\] removed entry from $filepath"
        }
    }
    _remove_from_file $pt_server::marker_file $pt_server::label
    _remove_from_file $pt_server::cfg_file    $pt_server::label
    set pt_server::port 0
    set pt_server::stop 1
    puts "\[pt_server\] stopped"
}

# ---------------------------------------------------------------------------
# Auto-start on source: open the socket then enter the event loop.
# Uses env PT_SERVER_PORT if set, otherwise defaults to 9877.
# ---------------------------------------------------------------------------
set _pt_server_port 9877
if {[info exists ::env(PT_SERVER_PORT)]} {
    set _pt_server_port $::env(PT_SERVER_PORT)
}
_pt_server_start $_pt_server_port
unset _pt_server_port

puts "\[pt_server\] entering event loop  (send 'quit' from a client to stop)"
vwait pt_server::stop
puts "\[pt_server\] event loop exited"

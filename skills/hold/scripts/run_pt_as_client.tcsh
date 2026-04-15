#!/usr/intel/pkgs/tcsh/6.22.04/bin/tcsh

set session=$argv[1]
set server=$argv[2]
set port=$argv[3]
set name=$argv[4]
set start=$argv[5]
set end=$argv[6]

if ( ! -e $session/README ) then
    exit 1
endif

set PT_VER_TO_LOAD = `grep -A1 'PrimeTime Version' $session/README | grep -v 'PrimeTime Version' | awk '{print $1}'`

set sourced=($_)
if ("$sourced" != "") then
    set this_dir=$sourced[2]:h
endif
if ("$0" != "tcsh") then
    set this_dir=$0:h
endif
echo this_dir = $this_dir

set ptfile=`mktemp`
echo $ptfile

echo source $this_dir/sio_common.tcl >> $ptfile
echo source $this_dir/sio_mow_client_to_server.tcl >> $ptfile
echo 'if {[catch {' >> $ptfile
echo run_client_for_sio_mow_min_delay_check_if_exit $server $port $name $start $end >> $ptfile
echo restore_session $session >> $ptfile
echo 'suppress_message {UITE-487 RC-204}' >> $ptfile
echo run_client_for_sio_mow_min_delay_min_max_logic_count $server $port $name $start $end >> $ptfile
echo '} err]} {' >> $ptfile
echo 'echo problem: [set err]' >> $ptfile
echo '}' >> $ptfile

echo exit >> $ptfile

/p/hdk/cad/primetime/$PT_VER_TO_LOAD/bin/pt_shell -file $ptfile
rm $ptfile

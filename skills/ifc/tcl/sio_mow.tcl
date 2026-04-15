#iproc_source -file /nfs/site/disks/home_user/gilkeren/scripts/tcl/icg_on_boundary.tcl -optional
#icg_on_boundary

source /nfs/site/disks/ayarokh_wa/tools/sio_mow/tcl/sio_common.tcl

proc load_carpet {partitions} {
    file mkdir $::ward/carpets
    set tmp_dir [exec mktemp -d -p $::ward/carpets]
    set ret_list [list]
    foreach par $partitions {lappend ret_list ${par}/*}
    
    set ret [get_pins $ret_list -filter "full_name!~*signal_elevator* && full_name!~*pdfx_fib* && full_name!~*power_elevator* && full_name!~*UNCONNECTED*"]
    
    set DB $tmp_dir/sio_mow_port_tns.csv
    
    #$ret - collection of pins that we want data on it
    #$DB - output file
    sio_mow_port_tns $ret $DB
    
    run_sio_mow ""
    redirect -file $tmp_dir/aladdin.log -bg {exec /nfs/site/disks/ayarokh_wa/tools/sio_mow/sio_mow.py -out_file $tmp_dir/aladdin.csv -new $DB -pt_server_address localhost -pt_server_port 9901 -title ${partitions}_[set ::env(USER)]_[set ::scenario] }
    
    echo "Link to $partitions Carpet $::scenario is :\nhttp://$::env(HOST).sc.intel.com:8050" > /tmp/carpet_mail_$::env(USER) 
    exec mail -s "Partiton carpet is ready for $partitions  " $::env(USER)   < /tmp/carpet_mail_$::env(USER) 
}



set partition  [get_cells icore0/par_ooo_int]
set par [regsub  {icore[0-9]/} [get_object_name $partition] "" ]
set pin_list [get_pins -of_object $partition] 

set dir /nfs/site/disks/baselibr_wa/SIO_WORK/${par}/

set day_ww  "$::ivar(envs,PROJECT_STEPPING)_[exec /usr/intel/bin/workweek -f  %YWW%02IW]_[expr [exec /usr/intel/bin/workweek -f  %w] + 1]" 
exec mkdir -p $dir/$day_ww/
set output_dir $dir/$day_ww/

#check distance from spec
check_spec_foreach_port -port $pin_list  -only $par > check_spec.ooo_int
exec mv check_spec.ooo_int $output_dir/distance_from_spec.rpt

source /nfs/site/disks/ayarokh_wa/git/bei/sio/tcl/bei_chain_buffers_report.tcl
source /nfs/site/disks/ayarokh_wa/git/bei/sio/tcl/sio_common.tcl
sio_buff_chains_report $par  $output_dir/buffer_chain.rpt $pin_list

#chech port locaitons issues 
bi_check_port_location $pin_list 0
exec mv check_port_location.rpt $output_dir/port_location.rpt

port_tns $pin_list
exec mv Port_Sum.report_compress $output_dir/Port_status_Each_port.rpt_compress
exec mv Port_Sum.report $output_dir/Port_status_Each_port.rpt

# all critical internal 
#logic_count_path [gtp -from [regsub "par" $par "mclk"] -to [regsub "par" $par "mclk"] -max_paths 1000000 -nworst 10 -include_hierarchical_pins -pba_mode path ] all_critical_report_internal_${par}.FCT22WW${day_ww}_pba.rpt
#exec mv all_critical_report_internal_${par}.FCT22WW${day_ww}_pba.rpt $output_dir/

# all critical exiternal 
#logic_count_path [get_timing_paths -through  icore0/${par}/* -pba_mode path  -max_paths 1000000 -nworst 10 -include_hierarchical_pins ] all_critical_report_external_${par}.FCT22WW${day_ww}_pba.rpt
#exec mv all_critical_report_external_${par}.FCT22WW${day_ww}_pba.rpt $output_dir/



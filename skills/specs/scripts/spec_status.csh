#!/usr/bin/tcsh -f

#before running: gen the following files from PT session
#exec mkdir spec_reports
#t2 dir get_pins */* >> spec_reports/lncserver.interface
#get_core_netlist spec_reports/lncserver.sch
echo "wa: $1"
set fct_wa = `rp $1`

set block = lncserver
set wa = `rp $fct_wa/spec_reports`
set spec_file = $fct_wa/lncserver.func.max_high.TT_100.tttt_timing_specs.xml
set interface = `rp $wa/${block}.interface`
set sch = `rp $wa/lncserver.sch`
set filter_file = `rp ~/lnc/specs/spec_filter.txt`

echo "partition,tot_missing,tot_bits" > $wa/${block}_spec_status.rpt

foreach par (`cat /nfs/iil/disks/home01/gilkeren/lnc_par_list.txt`)
#debug:
#foreach par (par_rob)

echo $par   

cat $interface | grep -v "FEEDTHRU_" | grep "$par" | item 1 3 | replace "/" " " | pie 's/_[0-9]_/ /g' | pie 's/_[0-9][0-9]_/ /g' | awk -F " " '{print $2" "$NF}' | pie 's/\[.*?\]/ /g' | my_count > $wa/${par}.interface


echo "${par} filter list" > $wa/${par}_filter.list
foreach filter ( `cat ~gilkeren/lnc/specs/spec_filter.txt | grep "^${par}" | item 2` )
cat $wa/${par}.interface | grep "${filter}" | item 2 >> $wa/${par}_filter.list
end

echo "par,port,dir,num_of_bits,num_of_specs,num_of_similar_specs,is_filtered" > $wa/${par}_spec.rpt

foreach port (`cat $wa/${par}.interface |awk -F " " '{if ($1 > 15) print $2}'`)
#debug: 
#foreach port (raroballocdatam203h morobidm804h)
	set dir = `grep -w "${port}" $wa/${par}.interface | item 3`
#	echo $par $port $dir>> $wa/${par}_spec.rpt

	set num_of_bits = `grep -w "${port}" $wa/${par}.interface | item 1` >> $wa/${par}_spec.rpt
#	echo num_of_bits $num_of_bits >> $wa/${par}_spec.rpt

	set num_of_specs = `grep "${par}.*${port}" $fct_wa/fct/$spec_file | wc -l` >> $wa/${par}_spec.rpt
#	echo "num_of_specs $num_of_specs" >> $wa/${par}_spec.rpt

	set num_of_similar_specs = `grep "${port}" $fct_wa/fct/$spec_file | wc -l` >> $wa/${par}_spec.rpt
#	echo "num_of_similar_specs $num_of_similar_specs" >> $wa/${par}_spec.rpt

	set filter = `cat $wa/${par}_filter.list | grep "${port}" | wc -l`
	echo "$par,$port,$dir,$num_of_bits,$num_of_specs,$num_of_similar_specs,$filter" >> $wa/${par}_spec.rpt
	#check spec on other side
#	if (${dir} == in) then
#		set other_par = ``
#		set other_port = ``
#	endif

#	if (${dir} == out) then
#		set other_par = ``
#		set other_port = ``
#	endif
	
#	echo $other_par
#	echo $other_port

end

set tot_mis = `grep  ",0,0,0" $wa/${par}_spec.rpt |wc -l`
set tot_bits = `grep "$par" $wa/${par}_spec.rpt |wc -l`

echo "$par,$tot_mis,$tot_bits" >> $wa/${block}_spec_status.rpt

end

echo "$wa/${block}_spec_status.rpt"

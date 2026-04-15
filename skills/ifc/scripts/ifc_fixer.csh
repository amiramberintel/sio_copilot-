set wa = $ward
set outfile = ifc_fixer.csv
set corner = func.max_low.ttttcmaxtttt_100.tttt
set xml = $wa/runs/core_client/1278.6/sta_pt/$corner/reports/core_client.${corner}_timing_summary.xml.filtered
echo "inport,corner,clock,slack" > $outfile
set port_list = `cat $xml | egrep 'int_ext="ifc_external"' |egrep 'endpoint="par_pm/' | awk -F '"' '{print $14}' | sort -u`
foreach inport (`echo "$port_list"`)
set slack = `cat $xml | grep -m1 "$inport" | awk -F '"' '{print $4}'`
set clock = `cat $xml | grep -m1 "$inport" | awk -F '"' '{print $18}'`
echo "$inport,$corner,$clock,$slack" >> $outfile
end

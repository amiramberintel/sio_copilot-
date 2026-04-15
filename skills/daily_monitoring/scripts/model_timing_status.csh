#!/usr/bin/tcsh -f

set wa = `realpath $1`
set partitions = `ls $wa/runs/ |grep "^par_"`
set corners = `ls -ltr ${wa}/vrf_split_no_dfx/*/ext.status.rpt | awk -F "/" '{print $(NF-1)}'|grep -v "noise" |sort`
#set corners = func.max_high.ttttcmaxtttt_100.tttt
set workweek = `cat $wa/env_vars.rpt | grep -w "WW" |awk -F '=' '{print $2}'`
set out_csv = $ward/model_timing_status_$workweek.csv
set priorty_file = $PNC_FCT_SCRIPTS/pvt.csv
echo "#Data based model: $wa" > $out_csv
echo "#all data is uncompressed" >> $out_csv

echo "#corner,priorty,min_or_max,directory,mclk_ct,type,par,|,internal_wns,internal_tns,FEP,FEP_10%,FEP_5%,|,external_in_wns,external_in_tns,external_in_FEP,external_in_FEP_10%,external_in_FEP_5%,|,external_out_wns,external_out_tns,external_out_FEP,external_out_FEP_10%,external_out_FEP_5%" >> $out_csv

echo "taking data from wa: $wa"

foreach type (func dfx)
	foreach cor ($corners)
	    echo "$cor"
		set min_or_max = `grep -w "scenario_delay_type_map.*$cor" $wa/project/$PROJECT_STEPPING/pvt.tcl | awk -F '"' '{print $4}'`
		set mclk_ct = `grep "periodCache.*mclk_pll" $wa/runs/$block/$tech/$flow/$cor/outputs/${block}_clock_params.$cor.debug.propagate_clock_1.tcl |awk '{print $NF}'`
		set priorty = `grep -w "$cor" $priorty_file |awk -F "," '{print $2}'`
		foreach par ($partitions)
			if ($type == func) then
			    if ($min_or_max == min) then
				set dir = vrf_split_no_dfx
			    else
				set dir = vrf_split_normalized_uc
			    endif
			else
				set dir = vrf_split_only_dfx
			endif

			set int_wns = `cat $wa/$dir/$cor/int.status.rpt | grep -w "$par" | head -1 | awk -F "," '{print $(NF-1)}'`
			set int_tns = `cat $wa/$dir/$cor/int.status.rpt | grep -w "$par" | head -1 | awk -F "," '{print $NF}'`
			set int_FEP = `cat $wa/$dir/$cor/int.status.rpt | grep -w "$par" | head -1 | awk -F "," '{print $2}'`
			set int_FEP_10 = `cat $wa/$dir/$cor/int.status.rpt | grep -w "$par" | head -1 | awk -F "," '{print $4}'`
			set int_FEP_5 = `cat $wa/$dir/$cor/int.status.rpt | grep -w "$par" | head -1 | awk -F "," '{print $3}'`

			#all external paths that ends at partition			
			set ext_in_wns = `cat $wa/$dir/$cor/ext.status.rpt | grep -w "$par" | head -1 | awk -F "," '{print $(NF-1)}'`
			set ext_in_tns = `cat $wa/$dir/$cor/ext.status.rpt | grep -w "$par" | head -1 | awk -F "," '{print $NF}'`
			set ext_in_FEP = `cat $wa/$dir/$cor/ext.status.rpt | grep -w "$par" | head -1 | awk -F "," '{print $2}'`
			set ext_in_FEP_10 = `cat $wa/$dir/$cor/ext.status.rpt | grep -w "$par" | head -1 | awk -F "," '{print $4}'`
			set ext_in_FEP_5 = `cat $wa/$dir/$cor/ext.status.rpt | grep -w "$par" | head -1 | awk -F "," '{print $3}'`

			#all external paths that starts at partition
			set ext_out_wns = `cat $wa/$dir/$cor/par_*/*.ext.0.rpt | awk '{print $3" "$8" "$9}' | sort -n -t '"' -k2 | grep 'startpoint.*'"$par"'/.*" endpoint' | head -1 |awk -F '"' '{print $2}'`
			set ext_out_tns = `cat $wa/$dir/$cor/par_*/*.ext.0.rpt | awk '{print $3" "$8" "$9}' | sort -n -t '"' -k2 | grep 'startpoint.*'"$par"'/.*" endpoint' | awk -F '"' '{s+=$2}END{print s}'`
			set ext_out_FEP = `cat $wa/$dir/$cor/par_*/*.ext.0.rpt | awk '{print $8 $9}' | grep "startpoint.*$par/.*endpoint" | wc -l`
			set ext_out_FEP_10 = `cat $wa/$dir/$cor/par_*/*.ext.10.rpt |  awk '{print $8 $9}' | grep "startpoint.*$par/.*endpoint" | wc -l`
			set ext_out_FEP_5 = `cat $wa/$dir/$cor/par_*/*.ext.5.rpt |  awk '{print $8 $9}' | grep "startpoint.*$par/.*endpoint" | wc -l`

			echo "$cor,$priorty,$min_or_max,$dir,$mclk_ct,$type,$par,|,$int_wns,$int_tns,$int_FEP,$int_FEP_10,$int_FEP_5,|,$ext_in_wns,$ext_in_tns,$ext_in_FEP,$ext_in_FEP_10,$ext_in_FEP_5,|,$ext_out_wns,$ext_out_tns,$ext_out_FEP,$ext_out_FEP_10,$ext_out_FEP_5" >> $out_csv
		end
	end
end


echo "Done. report at: $out_csv"

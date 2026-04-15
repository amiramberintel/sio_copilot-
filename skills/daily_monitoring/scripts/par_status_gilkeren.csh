#!/usr/bin/tcsh -f

set fct_wa = `realpath $1`
set ref_fct_wa = `realpath $2`
set corner = $3
set partitions = `cat $PROJ_ARCHIVE/arc/$block/fe_collateral/$FE_COLLATERAL_TAG/soc_hier.tcl | grep "set ivar(lnc_server,child_modules) " | awk -F '"' '{print $2}' | perl -pe 's/ /\n/g' | sort`

echo $corner
echo "REF WA: $ref_fct_wa"
echo "TST WA: $fct_wa"

set tst_block = `cat $fct_wa/env_vars.rpt | grep -w "block" | awk -F "=" '{print $2}'`
set ref_block = `cat $ref_fct_wa/env_vars.rpt | grep -w "block" | awk -F "=" '{print $2}'`
set tst_tech = `cat $fct_wa/env_vars.rpt | grep -w "tech" | awk -F "=" '{print $2}'`
set ref_tech = `cat $ref_fct_wa/env_vars.rpt | grep -w "tech" | awk -F "=" '{print $2}'`

mkdir -p par2spec/${corner}/

#set output_file = ${fct_wa}/runs/${tst_block}/${tst_tech}/${flow}/${corner}/reports/${block}.par2spec.ind
set output_file = par2spec/${corner}/tst



touch ${output_file}
rm ${output_file}

echo "REF: ${ref_fct_wa}" >> ${output_file}
echo "TST: ${fct_wa}" >> ${output_file}
echo "" >> ${output_file}
echo "$corner" >> ${output_file}
echo "" >> ${output_file}

echo "par,model,to200,to100,to50,to30,to0" >> ${output_file}

echo "" >> ${output_file}

foreach par ($partitions)
    	echo "working on $par"
	foreach wa ($fct_wa $ref_fct_wa)
		if ($wa == $fct_wa) then
			set model = TST
		else
			set model = REF
		endif
echo "working on $wa"
		set wa_block = `cat ${wa}/env_vars.rpt | grep -w "^block" |awk -F "=" '{print $2}'`
		set wa_tech = `cat ${wa}/env_vars.rpt | grep -w "^tech" |awk -F "=" '{print $2}'`

		set file = `realpath ${wa}/par_like_status/$corner/status.rpt`

#		set to500 = `cat $file | grep -w "$par" | head -1 | awk -F "," '{print $3}'`		
		set to200 = `cat $file | grep -w "$par" | head -1 | awk -F "," '{print $4}'`		
		set to100 = `cat $file | grep -w "$par" | head -1 | awk -F "," '{print $5}'`		
		set to50 = `cat $file | grep -w "$par" | head -1 | awk -F "," '{print $6}'`		
		set to30 = `cat $file | grep -w "$par" | head -1 | awk -F "," '{print $7}'`		
		set to0 = `cat $file | grep -w "$par" | head -1 | awk -F "," '{print $8}'`		

		echo "$par,$model,$to200,$to100,$to50,$to30,$to0" >> ${output_file}

	end
end

echo "" >> ${output_file}
echo "" >> ${output_file}
echo "Running compressed" >> ${output_file}
echo "" >> ${output_file}
echo "" >> ${output_file}

echo "par,model,to200,to100,to50,to30,to0" >> ${output_file}

foreach par ($partitions)
    	echo "working on $par"
	foreach wa ($fct_wa $ref_fct_wa)
		if ($wa == $fct_wa) then
			set model = TST
		else
			set model = REF
		endif

		set wa_block = `cat ${wa}/env_vars.rpt | grep -w "^block" |awk -F "=" '{print $2}'`
		set wa_tech = `cat ${wa}/env_vars.rpt | grep -w "^tech" |awk -F "=" '{print $2}'`

		set file = `realpath ${wa}/par_like_status/$corner/status.rpt`

#		set to500 = `cat $file | grep -w "$par" | tail -1 | awk -F "," '{print $3}'`		
		set to200 = `cat $file | grep -w "$par" | tail -1 | awk -F "," '{print $4}'`		
		set to100 = `cat $file | grep -w "$par" | tail -1 | awk -F "," '{print $5}'`		
		set to50 = `cat $file | grep -w "$par" | tail -1 | awk -F "," '{print $6}'`		
		set to30 = `cat $file | grep -w "$par" | tail -1 | awk -F "," '{print $7}'`		
		set to0 = `cat $file | grep -w "$par" | tail -1 | awk -F "," '{print $8}'`		

		echo "$par,$model,$to200,$to100,$to50,$to30,$to0" >> ${output_file}

	end
end


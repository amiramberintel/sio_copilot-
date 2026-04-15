#!/usr/bin/tcsh -f

##usage: source ~gilkeren/scripts/fct_status <fct wa> <ref fct wa> <corner>

#runs/lncserver/1277.2/sta_pt/func.max_high.TT_100.tttt/reports/lncserver.func.max_high.TT_100.tttt_margins.rpt
#runs/lncserver/1277.2/sta_pt/func.max_high.TT_100.tttt/reports/lncserver.func.max_high.TT_100.tttt_timing_histogram_external.rpt

#runs/lncserver/1277.2/sta_pt/func.max_high.TT_100.tttt/reports/lncserver.func.max_high.TT_100.tttt.link_issues.rpt
#runs/lncserver/1277.2/sta_pt/func.max_high.TT_100.tttt/reports/lncserver.func.max_high.TT_100.tttt_unstamped.rpt
#/nfs/iil/disks/core_fct/lnc/fct/LNC0A-RTL20ww51a_FCLww52.4-FCT21WW01A_contour_-CLK017.fcl/spec_status/lncserver.missing.spec_filtered.32bit.rpt

set fct_wa = `realpath $1`
set ref_fct_wa = `realpath $2`
set corner = $3
set partitions = `cat $PROJ_ARCHIVE/arc/$block/fe_collateral/$FE_COLLATERAL_TAG/soc_hier.tcl | grep "set ivar($block,child_modules) " | awk -F '"' '{print $2}' | perl -pe 's/ /\n/g' | sort`

echo $corner
echo "REF WA: $ref_fct_wa"
echo "TST WA: $fct_wa"

#set tst_block = `cat $fct_wa/env_vars.rpt | grep -w "block" | awk -F "=" '{print $2}'`
#set ref_block = `cat $ref_fct_wa/env_vars.rpt | grep -w "block" | awk -F "=" '{print $2}'`
#set tst_tech = `cat $fct_wa/env_vars.rpt | grep -w "tech" | awk -F "=" '{print $2}'`
#set ref_tech = `cat $ref_fct_wa/env_vars.rpt | grep -w "tech" | awk -F "=" '{print $2}'`

set output_file = ${fct_wa}/runs/${block}/${tech}/${flow}/${corner}/reports/${block}.summary_mail.csv
touch ${output_file}
rm ${output_file}

echo "REF: ${ref_fct_wa}" >> ${output_file}
echo "TST: ${fct_wa}" >> ${output_file}
echo "" >> ${output_file}
echo "$corner" >> ${output_file}
echo "" >> ${output_file}

echo "par,model,linking,unstamp,miss_spec_4bit,total_pins_8bit,unconst,path_100ct,path_20ct,path_10ct,path_0ct,spec_200ps,spec_100ps,spec_50ps,spec_30ps,int_200,int_100,int_50,int_30,tag,ovrs,missing_spec_0bit,total_pins_0bit,date,vendor,vrf_200ps,vrf_100ps,vrf_50ps,vrf_30ps,full_spec,spec_0ps,vrf_0ps,int_0,ft_ovr,int_vrf_wns,int_vrf_tns,ext_vrf_wns,ext_vrf_tns,spec_200,spec_100,spec_50,spec_30,spec_0,spec_wns,spec_tns,uc_pin,tot_pin,fdr_err,mbist_err" >> ${output_file}

echo "" >> ${output_file}



set unstamp_waiver_file = $fct_wa/runs/$block/$tech/$flow/inputs/unstamped.waivers.xml
cat $unstamp_waiver_file | awk -F '"' '{print $2}' | grep "^par" > /tmp/unstamped.waivers.txt
grep -Fvf /tmp/unstamped.waivers.txt $fct_wa/runs/$block/$tech/$flow/$corner/reports/$block.${corner}_unstamped.rpt > $fct_wa/runs/$block/$tech/$flow/$corner/reports/$block.${corner}_unstamped.rpt.manual_filtered

set fcl_uc = `realpath /nfs/iil/home/gilkeren/lnc/fcl_uc_ww48.txt`
cat $fcl_uc |awk -F "," '{print $1}' > fcl.uc.txt
grep -Fvf fcl.uc.txt $fct_wa/runs/$block/$tech/$flow/$corner/reports/$block.${corner}_margins.rpt > $fct_wa/runs/$block/$tech/$flow/$corner/reports/$block.${corner}_margins.rpt.manual_filtered



echo working on parts from: $ward/runs/$block/$tech/scripts/soc_hier.tcl
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

		set reports = `realpath ${wa}/runs/${wa_block}/${wa_tech}/${flow}/${corner}/reports/`
    		set linking = `cat ${reports}/${wa_block}.${corner}.link_issues.rpt | grep -w "^${par}" |wc -l`
		set unstamp = `cat ${reports}/${wa_block}.${corner}_unstamped.rpt.manual_filtered | grep -w "${par}" |egrep -v "/CD|/SDN" | wc -l`
#		set missing_spec_32bit = `cat ${wa}/spec_status/${corner}/${wa_block}.missing.spec_filtered.32bit.rpt | grep -w "${par}" | wc -l`
#		set total_pins_32bit = `cat ${wa}/spec_status/${corner}/${wa_block}.total.pins.32bit | grep -w "${par}" | wc -l`
#		set missing_spec_16bit = `cat ${wa}/spec_status/${corner}/${wa_block}.missing.spec_filtered.16bit.rpt | grep -w "${par}" | wc -l`
#		set total_pins_16bit = `cat ${wa}/spec_status/${corner}/${wa_block}.total.pins.16bit | grep -w "${par}" | wc -l`
#		set missing_spec_8bit = `cat ${wa}/spec_status/${corner}/${wa_block}.missing.spec.8bit.rpt | grep -w "${par}" | awk -F "," '{print $3}' `
#		set total_pins_8bit = `cat ${wa}/spec_status/${corner}/${wa_block}.missing.spec.8bit.rpt | grep -w "${par}" | awk -F "," '{print $2}' `
#
		set missing_spec_4bit = `cat ${wa}/spec_status/${corner}/${wa_block}.missing.spec.4bit.rpt | grep -w "${par}" | awk -F "," '{print $3}' `
		set total_pins_4bit = `cat ${wa}/spec_status/${corner}/${wa_block}.missing.spec.4bit.rpt | grep -w "${par}" | awk -F "," '{print $2}' `

		set missing_spec_0bit = `cat ${wa}/spec_status/${corner}/${wa_block}.missing.spec.0bit.rpt | grep -w "${par}" | awk -F "," '{print $3}' `
		set total_pins_0bit = `cat ${wa}/spec_status/${corner}/${wa_block}.missing.spec.0bit.rpt | grep -w "${par}" | awk -F "," '{print $2}' `

		echo 1
		set unconstrains = `grep -Fvf /nfs/iil/disks/home01/gilkeren/lnc/primetime_const/output_const_file_ww32_1.rpt ${reports}/${wa_block}.${corner}_margins.rpt.manual_filtered |grep -w "Unconstrained" | grep -w "${par}" |wc -l`
echo 2
		set ovrs = `cat ${wa}/runs/$par/$wa_tech/release/latest/sio_timing_collateral/${par}_internal_exceptions.tcl | egrep "set_multi|set_false|set_path_adjust|set_annotated_delay|set_annotated_check" | egrep -v "^#|\-hold" | wc -l`
echo 4
		set file = `realpath ${reports}/${wa_block}.${corner}_timing_histogram_external.rpt`
		echo 5
		set path_100ct = `cat $file | grep -w "${par}" | awk -F "|" '{print $5}'`
		echo 5
		set path_20ct = `cat $file | grep -w "${par}" | awk -F "|" '{print $4}'`
		set path_10ct = `cat $file | grep -w "${par}" | awk -F "|" '{print $3}'`
		set path_0ct = `cat $file | grep -w "${par}" | awk -F "|" '{print $2}'`
		#spec_margin_status spec compressed
		#		set file = `realpath ${wa}/spec_margin_status/${corner}/${par}_port_spec_report_summary.compress.txt`
		#		set margin_200ps = `cat $file | egrep "^${par}" | grep -v "Unconst" | awk -F "|" '{if ($7 < -200) print $0}' | wc -l`
		#		set margin_100ps = `cat $file | egrep "^${par}" | grep -v "Unconst" | awk -F "|" '{if ($7 < -100) print $0}' | wc -l`
		#		set margin_50ps  = `cat $file | egrep "^${par}" | grep -v "Unconst" | awk -F "|" '{if ($7 < -50) print $0}' | wc -l`
		#		set margin_30ps  = `cat $file | egrep "^${par}" | grep -v "Unconst" | awk -F "|" '{if ($7 < -30) print $0}' | wc -l`
		#		set margin_0ps   = `cat $file | egrep "^${par}" | grep -v "Unconst" | awk -F "|" '{if ($7 < -0) print $0}' | wc -l`
		set margin_200ps = ""
		set margin_100ps = ""
		set margin_50ps  = ""
		set margin_30ps  = ""
		set margin_0ps   = ""

		set vrf_200ps = "" 
		set vrf_100ps = ""
		set vrf_50ps  = ""
		set vrf_30ps  = ""
		set vrf_0ps   = ""
		set internal_200 = ""
		set internal_100 = ""
		set internal_50  = ""
		set internal_30  = ""
		set internal_0   = ""
		set spec_200 = ""
		set spec_100 = ""
		set spec_50 = ""
		set spec_30 = ""
		set spec_0 = ""
		set spec_wns = ""
		set spec_tns = ""
		set uc_pin = ""
		set tot_pin = "0"

		if ($MODEL_TYPE =~ ^bu) then
			#VRF status from vrf_split (compressed)		
			set file = `realpath ${wa}/vrf_split/$corner/ext.status.rpt`
			set vrf_200ps = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $2}'`
			set vrf_100ps = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $3}'`
			set vrf_50ps  = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $4}'`
			set vrf_30ps  = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $5}'`
			set vrf_0ps   = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $6}'`
			set ext_wns = `cat $file | awk "/not compressed/,/compressed by endpoint/" |grep -w "^$par" | awk -F "," '{print $7}'`
			set ext_tns = `cat $file | awk "/not compressed/,/compressed by endpoint/" |grep -w "^$par" | awk -F "," '{print $8}'`

			#int status from vrf_split (compressed)
			set file = `realpath ${wa}/vrf_split/$corner/int.status.rpt`	
			set internal_200 = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $2}'`
			set internal_100 = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $3}'`
			set internal_50  = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $4}'`
			set internal_30  = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $5}'`
			set internal_0   = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $6}'`
			set int_wns = `cat $file | awk "/not compressed/,/compressed by endpoint/" |grep -w "^$par" | awk -F "," '{print $7}'`
			set int_tns = `cat $file | awk "/not compressed/,/compressed by endpoint/" |grep -w "^$par" | awk -F "," '{print $8}'`

			#ext status from spec_split (compressed)
			if (`ls -ltr ${wa}/spec_split_no_dfx/$corner/ext.status.rpt |wc -l` != 0 ) then		
				set file = `realpath ${wa}/spec_split_no_dfx/$corner/ext.status.rpt`
				set spec_200 = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $2}'`
				set spec_100 = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $3}'`
				set spec_50 = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $4}'`
				set spec_30 = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $5}'`
				set spec_0 = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $6}'`
				set spec_wns = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $7}'`
				set spec_tns = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $8}'`
				set uc_pin = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $9}'`
				set tot_pin = `cat $file | awk "/compressed by endpoint/,/par,status/" | grep -w "^$par" |awk -F "," '{print $10}'`
	    		endif
		endif

		set file = `realpath ${wa}/spec_margin_status/${corner}/port_spec_report_summary.compress.txt`
		set full_spec = `cat $file |grep -i "full_spec" | awk -F "|" '{if ($7 < -10) print $0}' |grep -w "$par" |wc -l`

		set ft_ovr = `cat ${reports}/${wa_block}.${corner}.spec_details.rpt |grep -w "FT_ovr" | grep -w "out" | grep -w "$par" |wc -l`

		set tag = "NA"
		set date = "NA"
		set vendor = "NA"
		if ($MODEL_TYPE =~ ^bu) then
			set tag = `cat ${wa}/runs/${wa_block}/${wa_tech}/${flow}/${corner}/logs/${wa_block}.${corner}.pt.log | grep "Overriding.*ivar.*fct_prep,par_tags_ovr"|grep -w "$par" | awk -F "'" '{print $2}' |tail -1`
			set date = `zcat $PROJ_ARCHIVE/arc/${par}/sta_primetime/${tag}/${par}.sta_primetime.manifest.gz | grep -w "Current Date" | item 5 6 8`

			if (`cat ${wa}/runs/${par}/${tech}/release/latest/sta_primetime/${par}.pt_nonpg.v | grep -w "Cadence" |wc -l` != 0) then
			echo "$par $model cadence"
#			set date = `cat ${wa}/runs/${par}/${tech}/release/latest/sta_primetime/${par}.pt_nonpg.v | grep -w "#  Generated on:" | item 5 6 8`
			set vendor = cadence
			else
			echo "$par $model fusion"
#			set date = `cat ${wa}/runs/${par}/${tech}/release/latest/sta_primetime/${par}.pt_nonpg.v | grep "// Generated on " | item 4 | awk -F "/" '{print $2"/"$1"/"$3}'`
			set vendor = fusion
			endif

		endif

		set fdr_err = `cat ${reports}/${par}.fdr_exception.errors.rpt |wc -l`
		set mbist_err = `cat ${reports}/${par}_mbist_exception.errors.rpt |wc -l`

		echo "${par},${model},${linking},${unstamp},${missing_spec_4bit},${total_pins_4bit},${unconstrains},${path_100ct},${path_20ct},${path_10ct},${path_0ct},$margin_200ps,$margin_100ps,$margin_50ps,$margin_30ps,$internal_200,$internal_100,$internal_50,$internal_30,$tag,$ovrs,${missing_spec_0bit},${total_pins_0bit},$date,$vendor,$vrf_200ps,$vrf_100ps,$vrf_50ps,$vrf_30ps,$full_spec,$margin_0ps,$vrf_0ps,$internal_0,$ft_ovr,$int_wns,$int_tns,$ext_wns,$ext_tns,$spec_200,$spec_100,$spec_50,$spec_30,$spec_0,$spec_wns,$spec_tns,$uc_pin,$tot_pin,$fdr_err,$mbist_err" >> ${output_file}

	end
end

echo "done"
echo ""
echo "most ${output_file}"

echo "" >> ${output_file}
echo "Unconstrained:" >> ${output_file}
echo 'cat ${fct_wa}/runs/${block}/${tech}/${flow}/${corner}/reports/${block}.${corner}_margins.rpt |grep -w "Unconstrained" | most' >> ${output_file}
echo "" >> ${output_file}
echo "Linking report:" >> ${output_file}
echo 'most ${fct_wa}/runs/${block}/${tech}/${flow}/${corner}/reports/${block}.${corner}.link_issues.rpt' >> ${output_file}
echo "" >> ${output_file}
echo "Unstamped:" >> ${output_file}
echo 'most ${fct_wa}/runs/${block}/${tech}/${flow}/${corner}/reports/${block}.${corner}_unstamped.rpt' >> ${output_file}
echo "" >> ${output_file}


echo "" >> ${output_file}
echo "start run: "`cat ${fct_wa}/runs/$block/$tech/$flow/$corner/logs/${block}.${corner}.pt.log | grep "script_start" | head -1 | awk -F "[" '{print $(NF)}' |replace "[" ""` >> ${output_file}
echo `date` >> ${output_file}
echo "" >> ${output_file}

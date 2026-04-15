# $2 and $3 should be WAs
#foreach cor (func.max_low.ttttcmaxtttt_100.tttt func.max_nom.ttttcmaxtttt_100.tttt func.max_med.ttttcmaxtttt_100.tttt func.max_high.ttttcmaxtttt_100.tttt func.min_low.ttttcmintttt_100.tttt func.min_nom.ttttcmintttt_100.tttt fresh.min_fast.rcffcminpcff_125.prcs)
#source /nfs/site/disks/home_user/gilkeren/scripts/ind_for_kobi.csh $cor <$2 - REF> <$3 - TST>
#end
set corner = $1
set refmodel = $2
set tstmodel = $3
set REF_NAME = `grep -w "WW" $refmodel/env_vars.rpt |awk -F '=' '{print $2}'`
set TST_NAME = `grep -w "WW" $tstmodel/env_vars.rpt |awk -F '=' '{print $2}'`
set tst_tech = `cat $tstmodel/env_vars.rpt | grep -w "^tech" |awk -F "=" '{print $2}'`
set ref_tech = `cat $refmodel/env_vars.rpt | grep -w "^tech" |awk -F "=" '{print $2}'`
set tst_block = `cat $tstmodel/env_vars.rpt | grep -w block |awk -F '=' '{print $2}'`
set ref_block = `cat $refmodel/env_vars.rpt | grep -w block |awk -F '=' '{print $2}'`
set out_dir = $ward/csv_kobi/$corner/
set partitions = `ls $ward/runs/ |grep "^par_"`
set pt_log = $tstmodel/runs/${tst_block}/${tst_tech}/${flow}/${corner}/logs/${tst_block}.${corner}.pt.log
set pvt_profile = `echo $corner | awk -F "." '{print $2}'`
if ($pvt_profile =~ "max*") then
set cor_type = max
else
set cor_type = min
endif
#set cor_type = `grep -w "$corner" $ward/project/$PROJECT_STEPPING/pvt.tcl | grep -w "scenario_delay_type_map" | awk -F '"' '{print $(NF-1)}'`
echo "cor_type=$cor_type"
\mkdir -p $out_dir
\rm -rf $out_dir/*

set ref_xml = `realpath $refmodel/runs/$block/$tech/sta_pt/$corner/reports/$block.${corner}_timing_summary.xml.filtered`
set tst_xml = `realpath $tstmodel/runs/$block/$tech/sta_pt/$corner/reports/$block.${corner}_timing_summary.xml.filtered`
#splitting XML
/nfs/site/disks/ayarokh_wa/tools/reports/vrf_reports.py -report_in $ref_xml -filter_dfx $out_dir/ref_$block.${corner}_timing_summary_only_dfx.xml.filtered -filter_not_dfx $out_dir/ref_$block.${corner}_timing_summary_no_dfx.xml.filtered 
/nfs/site/disks/ayarokh_wa/tools/reports/vrf_reports.py -report_in $tst_xml -filter_dfx $out_dir/tst_$block.${corner}_timing_summary_only_dfx.xml.filtered -filter_not_dfx $out_dir/tst_$block.${corner}_timing_summary_no_dfx.xml.filtered 

if ($cor_type == "max") then
	foreach model (ref tst)
		set no_dfx_xml = $out_dir/${model}_$block.${corner}_timing_summary_no_dfx.xml.filtered
		echo "No DFX max"
		foreach par ($partitions)
			echo "working on $par"
			cat $no_dfx_xml | egrep 'int_ext="internal.*startpoint=.[a-z0-9/]*'"$par"'/|int_ext="external.*endpoint=.[a-z0-9/]*'"$par"'/' | grep -v 'startpoint="icore1/.*endpoint="icore1/' > $out_dir/$par.${model}_no_dfx.xml
		end
		echo ""
		echo "splitting into bins"
		echo "par,ext<=0%,ext<=-1%,ext<=-2%,ext<=-5%,ext<=-10%,ext_WNS,ext_TNS,par,int<=0%,int<=-1%,int<=-2%,int<=-5%,int<=-10%,int_WNS,int_TNS" > $out_dir/${model}.nor_uc.status.csv
		foreach par ($partitions)
			set par_file = $out_dir/$par.${model}_no_dfx.xml
			set intto10 =  `cat $par_file |grep 'int_ext="internal"' |awk -F '"' -v th=-10 '{if ($2 <= th/100) print $0}' |wc -l`
			set intto5 =  `cat $par_file |grep 'int_ext="internal"' |awk -F '"' -v th=-5 '{if ($2 <= th/100) print $0}' |wc -l`
			set intto2 =  `cat $par_file |grep 'int_ext="internal"' |awk -F '"' -v th=-2 '{if ($2 <= th/100) print $0}' |wc -l`
			set intto1 =  `cat $par_file |grep 'int_ext="internal"' |awk -F '"' -v th=-1 '{if ($2 <= th/100) print $0}' |wc -l`
			set intto0 =  `cat $par_file |grep 'int_ext="internal"' |awk -F '"' -v th=-0 '{if ($2 <= th/100) print $0}' |wc -l`
			set inttns = `cat $par_file | grep 'int_ext="internal"' |grep -v 'startpoint="icore1/.*endpoint="icore1/'|awk -F '"' '{print $4}' | awk '{s+=$1}END{print s}'`
			set intwns = `cat $par_file | grep 'int_ext="internal"' |head -n 1 |awk -F '"' '{print $4}'`

			set extto10 =  `cat $par_file |grep 'int_ext="external"' |awk -F '"' -v th=-10 '{if ($2 <= th/100) print $0}' |wc -l`
			set extto5 =  `cat $par_file |grep 'int_ext="external"' |awk -F '"' -v th=-5 '{if ($2 <= th/100) print $0}' |wc -l`
			set extto2 =  `cat $par_file |grep 'int_ext="external"' |awk -F '"' -v th=-2 '{if ($2 <= th/100) print $0}' |wc -l`
			set extto1 =  `cat $par_file |grep 'int_ext="external"' |awk -F '"' -v th=-1 '{if ($2 <= th/100) print $0}' |wc -l`
			set extto0 =  `cat $par_file |grep 'int_ext="external"' |awk -F '"' -v th=-0 '{if ($2 <= th/100) print $0}' |wc -l`
			set exttns = `cat $par_file | grep 'int_ext="external"' |grep -v 'startpoint="icore1/.*endpoint="icore1/'|awk -F '"' '{print $4}' | awk '{s+=$1}END{print s}'`
			set extwns = `cat $par_file | grep 'int_ext="external"' |head -n 1 |awk -F '"' '{print $4}'`

			echo "$par,$extto0,$extto1,$extto2,$extto5,$extto10,$extwns,$exttns,$par,$intto0,$intto1,$intto2,$intto5,$intto10,$intwns,$inttns" >> $out_dir/${model}.nor_uc.status.csv
		end
		set inttotal10 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$14}END{print s}'`
		set inttotal5 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$13}END{print s}'`
		set inttotal2 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$12}END{print s}'`
		set inttotal1 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$11}END{print s}'`
		set inttotal0 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$10}END{print s}'`
		set inttotalwns = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{print $15}' | sort -n| head -1`
		set inttotaltns = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$16}END{print s}'`

		set exttotal10 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$6}END{print s}'`
		set exttotal5 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$5}END{print s}'`
		set exttotal2 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$4}END{print s}'`
		set exttotal1 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$3}END{print s}'`
		set exttotal0 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$2}END{print s}'`
		set exttotalwns = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{print $7}' | sort -n| head -1`
		set exttotaltns = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$8}END{print s}'`

		echo "Total,$exttotal0,$exttotal1,$exttotal2,$exttotal5,$exttotal10,$exttotalwns,$exttotaltns,Total,$inttotal0,$inttotal1,$inttotal2,$inttotal5,$inttotal10,$inttotalwns,$inttotaltns" >> $out_dir/${model}.nor_uc.status.csv
	end
	
	echo "model,par,ext_to_0%,ext_to_1%,ext_to_2%,ext_to_5%,ext_to_10%,ext_wns,ext_tns,par,int_to_0%,int_to_1%,int_to_2%,int_to_5%,int_to_10%,int_wns,int_tns" > $out_dir/vrf_uc.csv
	foreach par ($partitions)
		echo $TST_NAME,`cat $out_dir/tst.nor_uc.status.csv| grep -w "$par"| head -1` >> $out_dir/vrf_uc.csv
		echo $REF_NAME,`cat $out_dir/ref.nor_uc.status.csv| grep -w "$par"| head -1` >> $out_dir/vrf_uc.csv
	end
	echo $TST_NAME,`cat $out_dir/tst.nor_uc.status.csv| grep -w "^Total"| head -1` >> $out_dir/vrf_uc.csv
	echo $REF_NAME,`cat $out_dir/ref.nor_uc.status.csv| grep -w "^Total"| head -1` >> $out_dir/vrf_uc.csv
else
	foreach model (ref tst)
	set no_dfx_xml = $out_dir/${model}_$block.${corner}_timing_summary_no_dfx.xml.filtered
	echo "No DFX min"
	foreach par ($partitions)
	echo "working on $par"
	cat $no_dfx_xml | egrep 'int_ext="internal.*startpoint=.[a-z0-9/]*'"$par"'/|int_ext="external.*endpoint=.[a-z0-9/]*'"$par"'/' | grep -v 'startpoint="icore1/.*endpoint="icore1/' > $out_dir/$par.${model}_no_dfx.xml
	end
	echo ""
	echo "splitting into bins"
	echo "par,ext<=0ps,ext<=-2ps,ext<=-3ps,ext<=-5ps,ext<=-10ps,ext_WNS,ext_TNS,par,int<=0ps,int<=-2ps,int<=-3ps,int<=-5ps,int<=-10ps,int_WNS,int_TNS" > $out_dir/${model}.nor_uc.status.csv
	foreach par ($partitions)
	set par_file = $out_dir/$par.${model}_no_dfx.xml
	set intto10 =  `cat $par_file |grep 'int_ext="internal"'|awk -F '"' -v th=-10 '{if ($4 <= th) print $0}' |wc -l`
	set intto5 =  `cat $par_file |grep 'int_ext="internal"'|awk -F '"' -v th=-5 '{if ($4 <= th) print $0}' |wc -l`
	set intto3 =  `cat $par_file |grep 'int_ext="internal"'|awk -F '"' -v th=-3 '{if ($4 <= th) print $0}' |wc -l`
	set intto2 =  `cat $par_file |grep 'int_ext="internal"'|awk -F '"' -v th=-2 '{if ($4 <= th) print $0}' |wc -l`
	set intto0 =  `cat $par_file |grep 'int_ext="internal"'|awk -F '"' -v th=-0 '{if ($4 <= th) print $0}' |wc -l`
	set inttns = `cat $par_file |  grep 'int_ext="internal"'|grep -v 'startpoint="icore1/.*endpoint="icore1/'|awk -F '"' '{print $4}' | awk '{s+=$1}END{print s}'`
	set intwns = `cat $par_file |grep 'int_ext="internal"'|head -n 1 |awk -F '"' '{print $4}'`

	set extto10 =  `cat $par_file |grep 'int_ext="external"'|awk -F '"' -v th=-10 '{if ($4 <= th) print $0}' |wc -l`
	set extto5 =  `cat $par_file |grep 'int_ext="external"'|awk -F '"' -v th=-5 '{if ($4 <= th) print $0}' |wc -l`
	set extto3 =  `cat $par_file |grep 'int_ext="external"'|awk -F '"' -v th=-3 '{if ($4 <= th) print $0}' |wc -l`
	set extto2 =  `cat $par_file |grep 'int_ext="external"'|awk -F '"' -v th=-2 '{if ($4 <= th) print $0}' |wc -l`
	set extto0 =  `cat $par_file |grep 'int_ext="external"'|awk -F '"' -v th=-0 '{if ($4 <= th) print $0}' |wc -l`
	set exttns = `cat $par_file |grep 'int_ext="external"'|grep -v 'startpoint="icore1/.*endpoint="icore1/'|awk -F '"' '{print $4}' | awk '{s+=$1}END{print s}'`
	set extwns = `cat $par_file |grep 'int_ext="external"'|head -n 1|awk -F '"' '{print $4}'`

	echo "$par,$extto0,$extto2,$extto3,$extto5,$extto10,$extwns,$exttns,$par,$intto0,$intto2,$intto3,$intto5,$intto10,$intwns,$inttns" >> $out_dir/${model}.nor_uc.status.csv
	end
	set inttotal10 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$14}END{print s}'`
	set inttotal5 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$13}END{print s}'`
	set inttotal3 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$12}END{print s}'`
	set inttotal2 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$11}END{print s}'`
	set inttotal0 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$10}END{print s}'`
	set inttotalwns = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{print $15}' | sort -n| head -1`
	set inttotaltns = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$16}END{print s}'`

	set exttotal10 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$6}END{print s}'`
	set exttotal5 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$5}END{print s}'`
	set exttotal3 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$4}END{print s}'`
	set exttotal2 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$3}END{print s}'`
	set exttotal0 = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$2}END{print s}'`
	set exttotalwns = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{print $7}' | sort -n| head -1`
	set exttotaltns = `cat $out_dir/${model}.nor_uc.status.csv |grep "^par_" |awk -F "," '{s+=$8}END{print s}'`

	echo "Total,$exttotal0,$exttotal2,$exttotal3,$exttotal5,$exttotal10,$exttotalwns,$exttotaltns,Total,$inttotal0,$inttotal2,$inttotal3,$inttotal5,$inttotal10,$inttotalwns,$inttotaltns" >> $out_dir/${model}.nor_uc.status.csv
	end
	
	echo "model,par,ext_to_0,ext_to_-2ps,ext_to_-3ps,ext_to_-5ps,ext_to_-10ps,ext_wns,ext_tns,par,int_to_0,int_to_-2ps,int_to_-3ps,int_to_-5ps,int_to_-10ps,int_wns,int_tns" > $out_dir/vrf_uc.csv
	foreach par ($partitions)
	echo $TST_NAME,`cat $out_dir/tst.nor_uc.status.csv| grep -w "$par"| head -1` >> $out_dir/vrf_uc.csv
	echo $REF_NAME,`cat $out_dir/ref.nor_uc.status.csv| grep -w "$par"| head -1` >> $out_dir/vrf_uc.csv
	end
	echo $TST_NAME,`cat $out_dir/tst.nor_uc.status.csv| grep -w "^Total"| head -1` >> $out_dir/vrf_uc.csv
	echo $REF_NAME,`cat $out_dir/ref.nor_uc.status.csv| grep -w "^Total"| head -1` >> $out_dir/vrf_uc.csv

endif



#!/bin/tcsh

set par = $1 
set test_tag = $2
set ref_tag = $3

set scenarios = "func.max_nom.T_85.typical func.max_high.T_85.typical"
set main_scenario = "func.max_high.T_85.typical"

set old_pwd = `pwd`

set dir_name = ${par}_`date +%F_%H-%M`
mkdir $dir_name

cd $dir_name 

rm -f running_jobs
    
mkdir tst/
cd tst/
foreach scenario ( $scenarios ) 
    if ( -e $PROJ_ARCHIVE/arc/${par}/sta_primetime/$test_tag/${par}.pt_session.$scenario/ ) then 
        /usr/intel/bin/nbjob run --exec-limit 6d:7d --target "sc8_express" --qslot "/c2dg/BE_BigCore/gfc/fct/sles15_fct" --class "SLES15&&128G&&4C" /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh $PROJ_ARCHIVE/arc/${par}/sta_primetime/$test_tag/${par}.pt_session.$scenario/ -title ${par}_tst_status -file /nfs/site/disks/home_user/baselibr/GFC_script/partition_status_mail/partition_xml.tcl -no_exit 0   | item 7 | tr -d "," >> ../running_jobs  
    else 
        touch done_$scenario 
    endif
end
cd - 

mkdir ref/
cd ref/
foreach scenario ( $scenarios ) 
    if ( -e  $PROJ_ARCHIVE/arc/${par}/sta_primetime/${ref_tag}/${par}.pt_session.$scenario/ ) then 
        /usr/intel/bin/nbjob run --exec-limit 6d:7d --target "sc8_express" --qslot "/c2dg/BE_BigCore/gfc/fct/sles15_fct" --class "SLES15&&128G&&4C" /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh $PROJ_ARCHIVE/arc/${par}/sta_primetime/${ref_tag}/${par}.pt_session.$scenario/ -title ${par}_ref_status -file /nfs/site/disks/home_user/baselibr/GFC_script/partition_status_mail/partition_xml.tcl -no_exit 0  | item 7 | tr -d "," >> ../running_jobs 
    else 
        touch done_$scenario
    endif
end
cd - 

set files = ""
foreach scenario ( $scenarios ) 
    foreach model (tst ref ) 
        set files = "$files $model/done_$scenario"
    end
end

# Loop until all files are created
while (1)
    set all_exist = 1
    foreach file ($files)
        if (! -e $file) then
            set all_exist = 0
            break
        endif
    end
    if ($all_exist) then
        echo "All files are created."
        break
    endif
    sleep 10
end

set bin = "0,-5,-10,-20,-30,-50,-100"
echo "model,scenario,type,tns,wns,$bin" > file.csv
foreach scenario ($scenarios) 
    foreach type (internal input_ports output_ports feedthru )
        foreach model (tst ref ) 
           echo -n "$model,$scenario,$type," >> file.csv 
           set wns = `cat $model/${par}_${scenario}_${type}.xml | grep "<path" | awkvrf '{print $4} END {if (NR==0) {print NR} } ' | sort -n | head -1 `
           set tns = `cat $model/${par}_${scenario}_${type}.xml | grep "<path" | awkvrf '{print $4} END {if (NR==0) {print NR} } ' | awksum`
           echo -n "$tns,$wns," >> file.csv
           cat $model/${par}_${scenario}_${type}.xml | grep "<path" | awkvrf '{print $4}' | awk -v bins="$bin" '{split(bins,a,",") ; for (i=1; i<=length(a);i++) {if ($0<a[i]) { b[i] =b[i] +1 }}} END {if (NR==0) {split(bins,a,",") ;  for (i=1; i<=length(a);i++) {printf "0," } ; print ""} else {for (i=1; i<=length(a);i++) {if (b[i]==0) {printf "0,"} else {printf b[i]","}};print "" } }'  >> file.csv 
        end
    end
end

set unit_list = "\n\
par_exe:     shuf siu miv1c miv0c rsvecprf_arrays sicrypt mimxx87c fpu misttnis miv0std1d rsvecbpd mix87cnsld \n\
par_fe:      bac bpu dsbfe ifu \n\
par_fmav0:    \n\
par_fmav1:    \n\
par_meu:     dcu mob dtlb moglbd repeater tmaxehrd siaxeld1vd agu ieu micrctls migitd mimxintd rsbpd rsintprf_arrays \n\
par_msid:    dsbe id idq il iq ms msid_misc \n\
par_ooo_int: rat_int rs_int alloc_int \n\
par_ooo_vec: rat_vec rob rs_vec \n\
par_pmh:     pmsyns pmsndtagd pmsndctls \n\
par_tmul:    tmu tmul_core tmul_tm \n\
par_mlc:     mlcc mlcctls mldfxd \n\
par_pm:      mlbtrs tadreg \n\
"
set par_unit = `echo $unit_list | grep "$par\:" | awk -F ":" '{print $2}'`
echo "model,scenario,unit,tns,wns,$bin" > unit_file.csv
foreach scenario ($scenarios) 
    foreach unit ($par_unit)
          foreach model (tst ref )
           echo -n "$model,$scenario,$unit," >> unit_file.csv 
           set wns = `cat $model/${par}_${scenario}_*.xml | grep "endpoint.*$unit/.*startpoint_clock" | grep "<path" | awkvrf '{print $4} END {if (NR==0) {print NR} }'  | sort -n | head -1 `
           set tns = `cat $model/${par}_${scenario}_*.xml | grep "endpoint.*$unit/.*startpoint_clock" | grep "<path" | awkvrf '{print $4} END {if (NR==0) {print NR} }'  | awksum`
           echo -n "$tns,$wns," >> unit_file.csv
           cat $model/${par}_${scenario}_*.xml |  grep "endpoint.*$unit/.*startpoint_clock" | grep "<path" | awkvrf '{print $4}' | awk -v bins="$bin" '{split(bins,a,",") ; for (i=1; i<=length(a);i++) {if ($0<a[i]) { b[i] =b[i] +1 }}} END {for (i=1; i<=length(a);i++) {if (b[i]==0) {printf "0,"} else {printf b[i]","}};print "" }'  >> unit_file.csv 
        end
    end
end

echo "Model,Scenario,Clock,CT,network,source" > file_clock.csv
foreach scenario ($scenarios) 
    foreach model (tst ref ) 
        echo -n "$model,$scenario," >> file_clock.csv
        cat $model/${par}_${scenario}_clock.csv | grep "mclk_"  >> file_clock.csv
    end
end

echo "Model,ULVT,ULVTLL,LVT,BFM,CLOCK_CELLS,TOTAL_CELLS,FF,FF2,FF4,FF6,FF8,TOTAL_FF,L,L2,L4,L6,L8,TOTAL_L,%ULVT,%ULVTLL,%LVT,%BFM,%MB,D20,FDRD" > cell.csv
foreach scenario ($main_scenario) 
    foreach model (tst ref ) 
        echo -n "$model," >> cell.csv
        cat $model/${par}_${scenario}_ulvt_usage.csv | grep -v TOTAL >> cell.csv
        #cat $model/${par}_${scenario}_ulvt_usage.csv | grep -v "TOTAL" | awk -F "," '{print $1","$1*100/$4"%,"$2","$2*100/$4"%,"$3","$3*100/$4"%,"$4}' >> cell.csv
    end
end



set ci_par = $par

echo "Subject: $PRODUCT_NAME-$PRODUCT_STEP  - $ci_par comparing Tag $test_tag with $ref_tag"  > mail_to_send
echo "Content-Type: text/html; charset=UTF-8" >> mail_to_send
echo "MIME-Version: 1.0">>mail_to_send
echo "<p style="font-size:30px"> <font color="red"> <u> $PRODUCT_NAME-$PRODUCT_STEP - $ci_par comparing Tag $test_tag with $ref_tag  </u> </font> </p>" >> mail_to_send

echo "<pre> ==================================   Details ========================================" >> mail_to_send

zcat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/$test_tag/*manifest* | grep "From dir" | sed 's/From/TST/g' >> mail_to_send
zcat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/$ref_tag/*manifest* | grep "From dir" | sed 's/From/REF/g' >> mail_to_send

ls -ltr $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/ | grep -w $test_tag | egrep -v "GOLDEN|arc_trans|0LATEST|4POWERROLLUP|PNC_DROP_" |tail -1 |awk '{print $(NF-2)}'      
ls -ltr $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/ | grep -w $ref_tag  | egrep -v "GOLDEN|arc_trans|0LATEST|4POWERROLLUP|PNC_DROP_" |tail -1 |awk '{print $(NF-2)}'

set test_ts = `cat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/$test_tag/sd.reopen | sed -r 's/.*-proj ([^ ]*) -.*/\1/g'`
set ref_ts = `cat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/$ref_tag/sd.reopen | sed -r 's/.*-proj ([^ ]*) -.*/\1/g'`

set test_ts = `grep -m1 toolversion,eou_flow_design_class $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/$test_tag/$ci_par.func.max_high.*.pt.log | awk -F "'" '{print $2}' | head -1 `
set ref_ts = `grep -m1 toolversion,eou_flow_design_class $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/$ref_tag/$ci_par.func.max_high.*.pt.log | awk -F "'" '{print $2}' | head -1 `

set test_tag_version = `zcat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/$test_tag/*man* | grep "Version:" | awk '{print $NF}'`
set ref_tag_version = `zcat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/$ref_tag/*man* | grep "Version:" | awk '{print $NF}'`

set tst_tag = $test_tag 

echo "TST TAG: $tst_tag" >> mail_to_send
echo "REF TAG: $ref_tag" >> mail_to_send
echo "TST TS: $test_ts" >> mail_to_send
echo "REF TS: $ref_ts" >> mail_to_send

echo "\n =======================================   Timing Status    =============================" >> mail_to_send
echo "XML At : `pwd $dir_name `" >> mail_to_send

mv file.csv all_corners.csv
cat all_corners.csv | grep -e "func.max_nom" -e scenario > file.csv
python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py --less_better >> mail_to_send
cat all_corners.csv | grep -e "func.max_high" -e scenario > file.csv
python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py --less_better >> mail_to_send

cat unit_file.csv | grep -e "func.max_nom" -e scenario > file.csv
python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py --less_better >> mail_to_send
cat unit_file.csv | grep -e "func.max_high" -e scenario > file.csv
python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py --less_better >> mail_to_send

cat file_clock.csv | grep -e "func.max_nom" -e Scenario > file.csv
python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py  >> mail_to_send
cat file_clock.csv | grep -e "func.max_high" -e Scenario > file.csv
python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py  >> mail_to_send
cat cell.csv > file.csv

python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py --no_compare  >> mail_to_send
foreach scenario ($scenarios) 
    cat $model/${par}_${scenario}_clock.csv | tail -2  | sed "s/endpoint/endpoint,$scenario/g ; s/bins/bins,corner/g"  > file.csv 
    python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py --no_compare >> mail_to_send
end

foreach scenario ($scenarios) 
    echo "\n =========================$scenario=============================" >> mail_to_send       
    zcat $PROJ_ARCHIVE/arc/${ci_par}/sta_primetime/$test_tag/${ci_par}.$scenario.report_global_timing.rpt.gz | grep -e "Total" -e "WNS" -e "TNS" -e "NUM" | awk '{print "TST "$0}' > test_model
    zcat $PROJ_ARCHIVE/arc/${ci_par}/sta_primetime/$ref_tag/${ci_par}.$scenario.report_global_timing.rpt.gz | grep -e "Total" -e "WNS" -e "TNS" -e "NUM" | awk '{print "REF "$0}' > ref_model
    paste test_model ref_model | sed 's/REF/\nREF/g' | sed 's/TST/--------------------------------------------------------------------------------\nTST/g' | sed '/REF.*Total/d' | sed '/Total/ s/TST/   /g' >> mail_to_send
end


paste tst/${ci_par}_func.max_high.T_85.typical_ebb_clock.csv ref/${ci_par}_func.max_high.T_85.typical_ebb_clock.csv | sed 's/^/tst,,/g ; s/\t/\nref,,/g' |sed 's/\..*//g' | grep -v "ref,,ebb_clk_pin" | sed 's/tst,,ebb_clk_pin,/model,,ebb_clk_pin,/g' | grep -v -e "/mil_c" -e "/mol_c" > file.csv
python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py >> mail_to_send


echo "\n ==================================Archive manifest========================================" >> mail_to_send

zcat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/$test_tag/*manifest* | head -25  >> mail_to_send
echo "</pre>" >> mail_to_send


cat mail_to_send | sendmail $USER

rm file.csv

cd $old_pwd

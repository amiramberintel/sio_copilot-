#!/bin/tcsh
set mailing_list = "\
par_exe     $USER hmuhsen mandrea gilkeren hmuhsen idc.design.pds@intel.com\n\
par_exe_int $USER hmuhsen gilkeren lstambul fnaseral idc.design.pds@intel.com\n\
par_fe      $USER hmuhsen gilkeren lstambul ahaimovi idc.design.pds@intel.com\n\
par_fmav1   $USER hmuhsen gilkeren idc.design.pds@intel.com\n\
par_fmav0   $USER hmuhsen gilkeren idc.design.pds@intel.com\n\
par_meu     $USER hmuhsen gilkeren lstambul fnaseral mburak idc.design.pds@intel.com\n\
par_mlc     $USER hmuhsen gilkeren amenashe lstambul fnaseral idc.design.pds@intel.com\n\
par_msid    $USER hmuhsen gilkeren lstambul amenashe ahaimovi idc.design.pds@intel.com\n\
par_ooo_int $USER hmuhsen gilkeren idc.design.pds@intel.com\n\
par_ooo_vec $USER hmuhsen gilkeren skukade idc.design.pds@intel.com\n\
par_pm      $USER hmuhsen gilkeren fnaseral lstambul idc.design.pds@intel.com\n\
par_pmh     $USER hmuhsen gilkeren mandrea fnaseral idc.design.pds@intel.com\n\
par_tmul_stub    $USER hmuhsen gilkeren\n\
"

set par = $1 
set ref_tag = $2
set test_tag = $3

set old_pwd = `pwd`

set dir_name = ${par}_`date +%F_%H-%M`
mkdir $dir_name

cd $dir_name 

rm -f running_jobs

mkdir tst/
cd tst/
if ( -e $PROJ_ARCHIVE/arc/${par}/sta_primetime/$test_tag/${par}.pt_session.func.max_high.ttttcmaxtttt_100.tttt/ ) then 
    /usr/intel/bin/nbjob run --exec-limit 6d:7d --target "sc8_express" --qslot "/c2dg/BE_BigCore/pnc/fct/sles12_fct" --class "SLES12SP5&&128G&&4C" /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh $PROJ_ARCHIVE/arc/${par}/sta_primetime/$test_tag/${par}.pt_session.func.max_high.ttttcmaxtttt_100.tttt/ -title ${par}_tst_status -file /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/partition_xml.tcl -no_exit 0   | item 7 | tr -d "," >> ../running_jobs  
else 
    touch done_func.max_high.ttttcmaxtttt_100.tttt 
endif

if ( -e $PROJ_ARCHIVE/arc/${par}/sta_primetime/$test_tag/${par}.pt_session.func.max_med.ttttcmaxtttt_100.tttt/ ) then 
    /usr/intel/bin/nbjob run --exec-limit 6d:7d --target "sc8_express" --qslot "/c2dg/BE_BigCore/pnc/fct/sles12_fct" --class "SLES12SP5&&128G&&4C" /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh $PROJ_ARCHIVE/arc/${par}/sta_primetime/$test_tag/${par}.pt_session.func.max_med.ttttcmaxtttt_100.tttt/ -title ${par}_tst_status -file /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/partition_xml.tcl -no_exit 0   | item 7 | tr -d "," >> ../running_jobs  
else 
    touch done_func.max_med.ttttcmaxtttt_100.tttt 
endif

if ( -e $PROJ_ARCHIVE/arc/${par}/sta_primetime/$test_tag/${par}.pt_session.func.max_nom.ttttcmaxtttt_100.tttt/ ) then 
    /usr/intel/bin/nbjob run --exec-limit 6d:7d --target "sc8_express" --qslot "/c2dg/BE_BigCore/pnc/fct/sles12_fct" --class "SLES12SP5&&128G&&4C" /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh $PROJ_ARCHIVE/arc/${par}/sta_primetime/$test_tag/${par}.pt_session.func.max_nom.ttttcmaxtttt_100.tttt/ -title ${par}_tst_status -file /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/partition_xml.tcl -no_exit 0   | item 7 | tr -d "," >> ../running_jobs  
else 
    touch done_func.max_nom.ttttcmaxtttt_100.tttt
endif
cd - 

mkdir ref/
cd ref/
if ( -e  $PROJ_ARCHIVE/arc/${par}/sta_primetime/${ref_tag}/${par}.pt_session.func.max_high.ttttcmaxtttt_100.tttt/ ) then 
    /usr/intel/bin/nbjob run --exec-limit 6d:7d --target "sc8_express" --qslot "/c2dg/BE_BigCore/pnc/fct/sles12_fct" --class "SLES12SP5&&128G&&4C" /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh $PROJ_ARCHIVE/arc/${par}/sta_primetime/${ref_tag}/${par}.pt_session.func.max_high.ttttcmaxtttt_100.tttt/ -title ${par}_ref_status -file /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/partition_xml.tcl -no_exit 0  | item 7 | tr -d "," >> ../running_jobs 
else 
    touch done_func.max_high.ttttcmaxtttt_100.tttt 
endif
if ( -e  $PROJ_ARCHIVE/arc/${par}/sta_primetime/${ref_tag}/${par}.pt_session.func.max_med.ttttcmaxtttt_100.tttt/ ) then 
    /usr/intel/bin/nbjob run --exec-limit 6d:7d --target "sc8_express" --qslot "/c2dg/BE_BigCore/pnc/fct/sles12_fct" --class "SLES12SP5&&128G&&4C" /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh $PROJ_ARCHIVE/arc/${par}/sta_primetime/${ref_tag}/${par}.pt_session.func.max_med.ttttcmaxtttt_100.tttt/ -title ${par}_ref_status -file /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/partition_xml.tcl -no_exit 0  | item 7 | tr -d "," >> ../running_jobs 
else 
    touch done_func.max_med.ttttcmaxtttt_100.tttt 
endif
if ( -e  $PROJ_ARCHIVE/arc/${par}/sta_primetime/${ref_tag}/${par}.pt_session.func.max_nom.ttttcmaxtttt_100.tttt/ ) then 
    /usr/intel/bin/nbjob run --exec-limit 6d:7d --target "sc8_express" --qslot "/c2dg/BE_BigCore/pnc/fct/sles12_fct" --class "SLES12SP5&&128G&&4C" /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh $PROJ_ARCHIVE/arc/${par}/sta_primetime/${ref_tag}/${par}.pt_session.func.max_nom.ttttcmaxtttt_100.tttt/ -title ${par}_ref_status -file /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/partition_xml.tcl -no_exit 0  | item 7 | tr -d "," >> ../running_jobs 
else 
    touch done_func.max_nom.ttttcmaxtttt_100.tttt
endif
cd - 

#while (1)
#    echo "jobs are still running `cat running_jobs`"
#    foreach jobid  ( ` cat running_jobs `)  
#        if ( `/usr/intel/bin/nbstatus jobs --timeout 600 --format noheaders --fields status jobid=$jobid --target "sc8_express" | wc -l`) then 
#            echo still runnning  $jobid 
#        else
#            echo done $jobid  
#            sed -i "/$jobid/d" running_jobs
#
#        endif
#    end
#    if ( `cat running_jobs  | wc -l ` ) then 
#    else 
#        break
#    endif
#    sleep 10
#end

while (! -e tst/done_func.max_nom.ttttcmaxtttt_100.tttt || ! -e tst/done_func.max_high.ttttcmaxtttt_100.tttt || ! -e tst/done_func.max_med.ttttcmaxtttt_100.tttt || ! -e ref/done_func.max_nom.ttttcmaxtttt_100.tttt || ! -e ref/done_func.max_high.ttttcmaxtttt_100.tttt || ! -e ref/done_func.max_med.ttttcmaxtttt_100.tttt)
    sleep 10
end


set bin = "0,-5,-10,-20,-30,-50,-100"
echo "model,scenario,type,tns,wns,$bin" > file.csv
foreach scenario (func.max_nom.ttttcmaxtttt_100.tttt func.max_high.ttttcmaxtttt_100.tttt func.max_med.ttttcmaxtttt_100.tttt ) 
    foreach type (internal input_ports output_ports feedthru )
        foreach model (tst ref ) 
           echo -n "$model,$scenario,$type," >> file.csv 
           set wns = `cat $model/${par}_${scenario}_${type}.xml | grep "<path" | awkvrf '{print $4}' | sort -n | head -1 `
           set tns = `cat $model/${par}_${scenario}_${type}.xml | grep "<path" | awkvrf '{print $4}' | awksum`
           echo -n "$tns,$wns," >> file.csv
           cat $model/${par}_${scenario}_${type}.xml | grep "<path" | awkvrf '{print $4}' | awk -v bins="$bin" '{split(bins,a,",") ; for (i=1; i<=length(a);i++) {if ($0<a[i]) { b[i] =b[i] +1 }}} END {for (i=1; i<=length(a);i++) {if (b[i]==0) {printf "0,"} else {printf b[i]","}};print "" }'  >> file.csv 
        end
    end
end

echo "Model,Scenario,Clock,network,source" > file_clock.csv
foreach scenario (func.max_nom.ttttcmaxtttt_100.tttt func.max_high.ttttcmaxtttt_100.tttt func.max_med.ttttcmaxtttt_100.tttt ) 
    foreach model (tst ref ) 
        echo -n "$model,$scenario," >> file_clock.csv
        cat $model/${par}_${scenario}_clock.csv | grep "mclk_"  >> file_clock.csv
    end
end

echo "Model,ULVTLL,%ULVTLL,ULVT,%ULVT,LVT,%LVT,SVT,%SVT,TOTAL" > cell.csv
foreach scenario (func.max_high.ttttcmaxtttt_100.tttt ) 
    foreach model (tst ref ) 
        echo -n "$model," >> cell.csv
        cat $model/${par}_${scenario}_ulvt_usage.csv | grep -v "TOTAL" | awk -F "," '{print $1","$1*100/$5"%,"$2","$2*100/$5"%,"$3","$3*100/$5"%,"$4","$4*100/$5"%,"$5}' >> cell.csv
    end
end

set ci_par = $par
echo "extraction quality,Percent of completely good nets" >> extraction_qulity.csv
grep "Percent of completely good nets" $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/${PROJECT_STEPPING}LATEST/reports/star_pv/${ci_par}.extract_quality.report | awk '{print "TST,"$(NF-1)"%"}' >> extraction_qulity.csv
grep "Percent of completely good nets" $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/GOLDEN/reports/star_pv/${ci_par}.extract_quality.report | awk '{print "REF,"$(NF-1)"%"}' >> extraction_qulity.csv


echo "Subject: $PRODUCT_NAME-$PRODUCT_STEP - $ci_par did a new sta_primetime CI"  > mail_to_send
echo "Content-Type: text/html; charset=UTF-8" >> mail_to_send
echo "MIME-Version: 1.0">>mail_to_send
echo "<p style="font-size:30px"> <font color="red"> <u> $PRODUCT_NAME-$PRODUCT_STEP - $ci_par did a new sta_primetime CI  </u> </font> </p>" >> mail_to_send
echo "<p style="font-family:Courier New"> Updated at `date`  </p>" >> mail_to_send
echo "<p style="font-family:Courier New" > ${PROJ_ARCHIVE}/arc/${ci_par}/sta_primetime/${PROJECT_STEPPING}LATEST/ </p>" >> mail_to_send

echo "<pre> ==================================   Details ========================================" >> mail_to_send

zcat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/${PROJECT_STEPPING}LATEST/*manifest* | grep "From dir" | sed 's/From/TST/g' >> mail_to_send
zcat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/GOLDEN/*manifest* | grep "From dir" | sed 's/From/REF/g' >> mail_to_send

ls -ltr $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/ | grep -w ${PROJECT_STEPPING}LATEST | egrep -v "GOLDEN|arc_trans|PNC78SERVERB0LATEST|PNC78CLIENTB0LATEST|4POWERROLLUP|PNC_DROP_" |tail -1 |awk '{print $(NF-2)}'      
ls -ltr $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/ | grep -w GOLDEN | egrep -v "GOLDEN|arc_trans|PNC78SERVERB0LATEST|PNC78CLIENTB0LATEST|4POWERROLLUP|PNC_DROP_" |tail -1 |awk '{print $(NF-2)}'

set test_ts = `cat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/${PROJECT_STEPPING}LATEST/sd.reopen | sed -r 's/.*-proj ([^ ]*) -.*/\1/g'`
set ref_ts = `cat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/GOLDEN/sd.reopen | sed -r 's/.*-proj ([^ ]*) -.*/\1/g'`

set test_ts = `grep -m1 toolversion,eou_flow_design_class $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/${PROJECT_STEPPING}LATEST/$ci_par.func.max_high.*.pt.log | awk -F "'" '{print $2}' | head -1 `
set ref_ts = `grep -m1 toolversion,eou_flow_design_class $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/GOLDEN/$ci_par.func.max_high.*.pt.log | awk -F "'" '{print $2}' | head -1 `

set test_tag_version = `zcat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/${PROJECT_STEPPING}LATEST/*man* | grep "Version:" | awk '{print $NF}'`
set ref_tag_version = `zcat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/GOLDEN/*man* | grep "Version:" | awk '{print $NF}'`



set tst_tag = `ls -ltr $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/ | grep -w $test_tag_version | egrep -v "GOLDEN|arc_trans|PNC78SERVERB0LATEST|PNC78CLIENTB0LATEST|4POWERROLLUP|PNC_DROP_" | tail -1 | awk '{print $(NF-2)}'`
if ($tst_tag == "") then
    set tst_tag = $test_tag_version
endif
set ref_tag = `ls -ltr $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/ | grep -w $ref_tag_version | egrep -v "GOLDEN|arc_trans|PNC78SERVERB0LATEST|PNC78CLIENTB0LATEST|4POWERROLLUP|PNC_DROP_" | tail -1 | awk '{print $(NF-2)}'`
 if ($ref_tag == "") then
    set ref_tag = $ref_tag_version
endif
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
cat all_corners.csv | grep -e "func.max_med" -e scenario > file.csv
python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py --less_better >> mail_to_send

cat file_clock.csv | grep -e "func.max_nom" -e Scenario > file.csv
python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py  >> mail_to_send
cat file_clock.csv | grep -e "func.max_high" -e Scenario > file.csv
python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py  >> mail_to_send
cat file_clock.csv | grep -e "func.max_med" -e Scenario > file.csv
python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py  >> mail_to_send
cat cell.csv > file.csv
python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py --no_compare  >> mail_to_send
cat extraction_qulity.csv > file.csv
python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py --no_compare >> mail_to_send

foreach scenario (func.max_nom.ttttcmaxtttt_100.tttt func.max_high.ttttcmaxtttt_100.tttt func.max_med.ttttcmaxtttt_100.tttt ) 
    cat $model/${par}_${scenario}_clock.csv | tail -2  | sed "s/endpoint/endpoint,$scenario/g ; s/bins/bins,corner/g"  > file.csv 
    python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py --no_compare >> mail_to_send
end

echo "\n =========================func.max_nom.ttttcmaxtttt_100.tttt=============================" >> mail_to_send       
zcat $PROJ_ARCHIVE/arc/${ci_par}/sta_primetime/${PROJECT_STEPPING}LATEST/${ci_par}.func.max_nom.ttttcmaxtttt_100.tttt.report_global_timing.rpt.gz | grep -e "Total" -e "WNS" -e "TNS" -e "NUM" | awk '{print "TST "$0}' > test_model
zcat $PROJ_ARCHIVE/arc/${ci_par}/sta_primetime/GOLDEN/${ci_par}.func.max_nom.ttttcmaxtttt_100.tttt.report_global_timing.rpt.gz | grep -e "Total" -e "WNS" -e "TNS" -e "NUM" | awk '{print "REF "$0}' > ref_model
paste test_model ref_model | sed 's/REF/\nREF/g' | sed 's/TST/--------------------------------------------------------------------------------\nTST/g' | sed '/REF.*Total/d' | sed '/Total/ s/TST/   /g' >> mail_to_send
echo "\n =========================func.max_high.ttttcmaxtttt_100.tttt=============================" >> mail_to_send        
zcat $PROJ_ARCHIVE/arc/${ci_par}/sta_primetime/${PROJECT_STEPPING}LATEST/${ci_par}.func.max_high.ttttcmaxtttt_100.tttt.report_global_timing.rpt.gz | grep -e "Total" -e "WNS" -e "TNS" -e "NUM" | awk '{print "TST "$0}' > test_model
zcat $PROJ_ARCHIVE/arc/${ci_par}/sta_primetime/GOLDEN/${ci_par}.func.max_high.ttttcmaxtttt_100.tttt.report_global_timing.rpt.gz | grep -e "Total" -e "WNS" -e "TNS" -e "NUM" | awk '{print "REF "$0}' > ref_model
paste test_model ref_model | sed 's/REF/\nREF/g' | sed 's/TST/--------------------------------------------------------------------------------\nTST/g' | sed '/REF.*Total/d' | sed '/Total/ s/TST/   /g' >> mail_to_send
echo " " >> mail_to_send
echo "\n =========================func.max_med.ttttcmaxtttt_100.tttt=============================" >> mail_to_send        
zcat $PROJ_ARCHIVE/arc/${ci_par}/sta_primetime/${PROJECT_STEPPING}LATEST/${ci_par}.func.max_med.ttttcmaxtttt_100.tttt.report_global_timing.rpt.gz | grep -e "Total" -e "WNS" -e "TNS" -e "NUM" | awk '{print "TST "$0}' > test_model
zcat $PROJ_ARCHIVE/arc/${ci_par}/sta_primetime/GOLDEN/${ci_par}.func.max_med.ttttcmaxtttt_100.tttt.report_global_timing.rpt.gz | grep -e "Total" -e "WNS" -e "TNS" -e "NUM" | awk '{print "REF "$0}' > ref_model
paste test_model ref_model | sed 's/REF/\nREF/g' | sed 's/TST/--------------------------------------------------------------------------------\nTST/g' | sed '/REF.*Total/d' | sed '/Total/ s/TST/   /g' >> mail_to_send
echo " " >> mail_to_send

echo "\n ==================================CLOCK ON EBB ========================================" >> mail_to_send

paste tst/${ci_par}_func.max_high.ttttcmaxtttt_100.tttt_ebb_clock.csv ref/${ci_par}_func.max_high.ttttcmaxtttt_100.tttt_ebb_clock.csv | sed 's/^/tst,,/g ; s/\t/\nref,,/g' |sed 's/\..*//g' | grep -v "ref,,ebb_clk_pin" | sed 's/tst,,ebb_clk_pin,/model,,ebb_clk_pin,/g'| grep -v clk_checkpin_falling > file.csv
python /nfs/site/disks/home_user/baselibr/PNC_script/partition_status_mail/convert_csv_to_html.py >> mail_to_send


echo "\n ==================================Archive manifest========================================" >> mail_to_send

zcat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/${PROJECT_STEPPING}LATEST/*manifest* | head -25  >> mail_to_send
echo "</pre>" >> mail_to_send

if (`echo $mailing_list | grep "$ci_par " | wc -l ` == 1 ) then 
    set users_to_mail = `echo $mailing_list | grep "$ci_par " | sed 's/par[^ ]* //g' | sed 's/  \+/ /g' `
#  set users_to_mail = "baselibr"
    echo "$ci_par did a new CI sending a mail to $users_to_mail" 
else 
    set users_to_mail = " baselibr"
    echo "somthing went wrong sending mail to $users_to_mail" 
endif


cat mail_to_send | sendmail gilkeren

rm file.csv

cd $old_pwd

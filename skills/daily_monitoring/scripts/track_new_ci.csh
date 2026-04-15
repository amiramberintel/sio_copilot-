#!/bin/tcsh
set mailing_list = "\
par_exe     $USER\n\
par_exe_int $USER\n\
par_fe      $USER\n\
par_fmav1   $USER\n\
par_fmav0   $USER\n\
par_meu     $USER\n\
par_mlc     $USER\n\
par_msid    $USER\n\
par_ooo_int $USER\n\
par_ooo_vec $USER\n\
par_pm      $USER\n\
par_pmh     $USER\n\
par_tmul_stub    $USER\n\
"

ls --full-time $PROJ_ARCHIVE/arc/par*/sta_primetime/${PROJECT_STEPPING}LATEST | item 6 7 9 > archive_old_times
while (1)
    sleep 1 
    foreach desktop ( `xdotool search -all --name "par.*tst_status" ` `xdotool search -all --name "par.*ref_status"` )
       xdotool set_desktop_for_window $desktop 0
    end 
    sleep 60   # Wait for 1 min
    ls --full-time $PROJ_ARCHIVE/arc/par*/sta_primetime/${PROJECT_STEPPING}LATEST | item 6 7 9 > archive_new_times
    diff -B archive_new_times archive_old_times > /dev/null
    if ($status == 0) then
    else 
        set ci_par = `diff archive_new_times archive_old_times | grep par | item 4 | sort -u | sed 's|/sta_primetime.*||g; s|.*/arc/||g'`
        source /nfs/site/disks/home_user/baselibr/GFC_script/partition_status_mail/compare_partition_timing.csh $ci_par &
     
        set test_tag_version = `zcat $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/${PROJECT_STEPPING}LATEST/*man* | grep "Version:" | awk '{print $NF}'`
        set tst_tag = `ls -ltr $PROJ_ARCHIVE/arc/$ci_par/sta_primetime/ | grep -w $test_tag_version | egrep -v "GOLDEN|arc_trans|0LATEST|4POWERROLLUP|PNC_DROP_" | tail -1 | awk '{print $(NF-2)}'`
        if ($tst_tag == "") then
            set tst_tag = $test_tag_version
        endif

        echo "Partition $ci_par did a CI on `date ` with tag $tst_tag" >> $ward/ci_history.rpt
        
        mv archive_new_times archive_old_times
    endif
end


endif 


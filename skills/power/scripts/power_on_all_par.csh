#!/usr/bin/csh -f
set script=$1

if ($#argv < 2) then
        set base=/p/pnc/power_central_dir/power/links/pnc_core_rollup/latest_partition_rlp/
else
        set base=$2
endif

set nb='/usr/intel/bin/nbjob run --target sc8_express --qslot /c2dg/BE_BigCore/pnc/sd/sles12_sd --class "SLES12SP5&&257G&&4C"'
#set tech=1278.6
set scenario=max_nom.ttttcmaxtttt_100.tttt
set test = "atom_perlbench"

set critical_tests_list = "\
par_exe atom_hplinpack \n\
par_fe  atom_perlbench \n\
par_fmav0   atom_hplinpack \n\
par_fmav1   atom_hplinpack \n\
par_meu atom_perlbench \n\
par_mlc core_roms \n\
par_msid    core_cassandra \n\
par_ooo_int atom_perlbench \n\
par_ooo_vec atom_lucas \n\
par_pm  core_roms \n\
par_pmh core_xalancbmk \n\
"

set out = power_test_file.csh
echo "#/usr/bin/csh " > $out
foreach partition (`echo $critical_tests_list | awk '{print $1}' ` ) 
    set test = `echo $critical_tests_list | grep "$partition " | awk '{print $2}'` 
    set f=$base/$partition/runs/$partition/$tech/power_extraction/$partition.func.$scenario.$test/session/$partition.pt_save_session.power
    if (-d $f ) then 
        echo $nb --log-file $partition.$test.log /p/hdk/pu_tu/prd/quick_power/latest/toolbox/load_db -db $f -cmd \"source $script\" >> $out
    else 
        echo "Session for test $test of $partition does not exist"
        rm $out 
    endif
end
chmod a+x $out
echo "run file is at : $out"


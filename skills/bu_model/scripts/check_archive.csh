set partitions = `ls -1 runs/ |grep "^par"`
\rm -f $ward/archive_diff


#### checking sio internal exceptions from GOLDEN ####
foreach par ($block $partitions)
foreach file (`ls -1 $PROJ_ARCHIVE/arc/$par/sio_timing_collateral/GOLDEN/*.tcl`)
diff $file runs/$par/$tech/release/latest/sio_timing_collateral/ > /dev/null
if ($status == 0) then
else
tkdiff $file runs/$par/$tech/release/latest/sio_timing_collateral/ &
echo "cp -L $file runs/$par/$tech/release/latest/sio_timing_collateral/" >> archive_diff
endif
end
end

#### checking sio internal exceptions per scenario from GOLDEN ####
foreach par (`ls -1 $PROJ_ARCHIVE/arc/*/sio_timing_collateral/GOLDEN/*/*.tcl | grep -v "$block" | awk -F "/" '{print $7}' |sort -u `)
foreach cor (`ls -1 $PROJ_ARCHIVE/arc/*/sio_timing_collateral/GOLDEN/*/*.tcl | grep -v "$block" | awk -F "/" '{print $10}' | sort -u`)
foreach file (`ls -1 $PROJ_ARCHIVE/arc/$par/sio_timing_collateral/GOLDEN/$cor/*.tcl`)
diff $file runs/$par/$tech/release/latest/sio_timing_collateral/$cor/ > /dev/null
if ($status == 0) then
else
tkdiff $file runs/$par/$tech/release/latest/sio_timing_collateral/$cor/ &
echo "cp -L $file runs/$par/$tech/release/latest/sio_timing_collateral/$cor/" >> archive_diff
endif
end
end
end

#### sio ovrs from GOLDEN ####
if ($block == "icore") then
    set collection = `ls -1 $PROJ_ARCHIVE/arc/*/sio_ovr/GOLDEN/*.tcl | egrep -wv "$block|par_pmhglb|par_fma|par_mlc|par_pm" | awk -F "/" '{print $7}' | sort -u `
else
    set collection = `ls -1 $PROJ_ARCHIVE/arc/*/sio_ovr/GOLDEN/*.tcl | egrep -wv "$block|par_pmhglb|par_fma" | awk -F "/" '{print $7}' | sort -u `
endif
foreach par ($collection)
diff $PROJ_ARCHIVE/arc/$par/sio_ovr/GOLDEN/${par}_sio_ovrs.tcl $ward/runs/$par/$tech/release/latest/sio_ovr/${par}_sio_ovrs.tcl > /dev/null
if ($status == 0) then
else
tkdiff $PROJ_ARCHIVE/arc/$par/sio_ovr/GOLDEN/${par}_sio_ovrs.tcl $ward/runs/$par/$tech/release/latest/sio_ovr/${par}_sio_ovrs.tcl &
echo "cp -L $PROJ_ARCHIVE/arc/$par/sio_ovr/GOLDEN/${par}_sio_ovrs.tcl $ward/runs/$par/$tech/release/latest/sio_ovr/${par}_sio_ovrs.tcl" >> archive_diff
endif
end

#### hip ovrs from GOLDEN ####
if ($block == "icore") then
    set collection = `ls -1 $PROJ_ARCHIVE/arc/*/sio_ovr/GOLDEN/*.xml | egrep -wv "$block|par_pmhglb|par_fma|par_mlc|par_pm" | awk -F "/" '{print $7}' | sort -u `
else
    set collection = `ls -1 $PROJ_ARCHIVE/arc/*/sio_ovr/GOLDEN/*.xml | egrep -wv "$block|par_pmhglb|par_fma" | awk -F "/" '{print $7}' | sort -u `
endif
foreach par ($collection)
diff $PROJ_ARCHIVE/arc/$par/sio_ovr/GOLDEN/${par}.hip_ovrs.xml $ward/runs/$par/$tech/release/latest/hip_ovr/${par}.hip_ovrs.xml > /dev/null
if ($status == 0) then
else
tkdiff $PROJ_ARCHIVE/arc/$par/sio_ovr/GOLDEN/${par}.hip_ovrs.xml $ward/runs/$par/$tech/release/latest/hip_ovr/${par}.hip_ovrs.xml &
echo "cp -L $PROJ_ARCHIVE/arc/$par/sio_ovr/GOLDEN/${par}.hip_ovrs.xml $ward/runs/$par/$tech/release/latest/hip_ovr/${par}.hip_ovrs.xml" >> archive_diff
endif
end

#### mbist/fdr from sio_ovr bundle ####
rm $ward/check_archive.list
rm $ward/cksum.archive
rm $ward/cksum.ward
foreach par ($partitions)
ls -1 $PROJ_ARCHIVE/arc/$par/sio_ovr/GOLDEN/*.tcl $PROJ_ARCHIVE/arc/$par/sio_ovr/GOLDEN/*.sdc | replace "GOLDEN/" "GOLDEN/ "|awk '{print $2}' | grep -v "sio_ovr" > $ward/check_archive.list
foreach file (`cat $ward/check_archive.list`)
set short = `echo $file |awk -F "/" '{print $NF}'`
echo "$par $file" `cksum $PROJ_ARCHIVE/arc/$par/sio_ovr/GOLDEN/$file |awk '{print $1" "$2}'` >> $ward/cksum.archive
echo "$par $file" `cksum $ward/runs/$par/$tech/release/latest/sio_ovr/$file |awk '{print $1" "$2}'` >> $ward/cksum.ward
end
end
cat $ward/cksum.archive | grep -v Exit | grep "^par" > kukuku  ; mv kukuku  $ward/cksum.archive
cat $ward/cksum.ward    | grep -v Exit | grep "^par" > kukuku2 ; mv kukuku2 $ward/cksum.ward
tkdiff $ward/cksum.archive $ward/cksum.ward &

xterm -geometry 200x40 -bg black -fg white -cr white -e most archive_diff &


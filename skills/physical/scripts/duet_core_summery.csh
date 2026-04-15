#!/usr/bin/tcsh -f

set rule = $1

foreach fub ( `cat $FCT_MODEL/latest_${PROJECT}/indicators/details/*/*.bvr_source.ind.details |  replace "|" " " | /nfs/site/proj/mpg/proc/projects/mrm/utils/bin/item 3` )
~gilkeren/scripts/duet_summery.csh $fub ${rule} >> tmp.txt
end

most tmp.txt |sort -nr -k 3 > ${rule}.txt

rm tmp.txt

echo "most ${rule}.txt"

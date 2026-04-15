
logic_count_grep_path $1 $2 | l > Spec_calc_timing_report
xterm -fn fixed -ls -sb -geometry 350x70 -e less -S Spec_calc_timing_report &
cat ~baselibr/gfc/Core_plot/icore/Draw_block.gnuplot_temp  > path.location.gnuplot
logic_count_grep_path $1 $2 | grep -e "(.*.0,.*.0)" | perl -pe 's/.*\((.*.0),(.*.0)\).*/$1,$2/g' | awk -F "," '{print $1/1000 , $2/1000}'  > path.location

echo " '`pwd`/path.location' with linespoints linestyle 3" >> path.location.gnuplot
set start_loc = `cat path.location | head -1 | awk '{print $1+10","$2-20}' ` 
set end_loc = `cat path.location | tail -1 | awk '{print $1+10","$2-20}' `  

echo "set label 'Start' at $start_loc font "'"'",14"'"' >> path.location.gnuplot
echo "set label 'End' at $end_loc font "'"'",14"'"' >> path.location.gnuplot
echo "replot" >> path.location.gnuplot
echo "pause -1"  >> path.location.gnuplot
/usr/intel/bin/gnuplot path.location.gnuplot >> /dev/null 


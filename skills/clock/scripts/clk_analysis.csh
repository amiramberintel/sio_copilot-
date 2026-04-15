alias awkbin_between 'awk -v bins="$bin" '"'"'BEGIN{split(bins,a,",") ; for (i=2; i<=length(a);i++) {printf a[i-1]"-"a[i]","} ; print "" }{split(bins,a,",") ; for (i=2; i<=length(a);i++) {if (a[i-1]<=$0 && $0<a[i]) { b[i] =b[i] +1 }}} END {for (i=2; i<=length(a);i++) {if (b[i]=="") {b[i]=0} ; printf b[i]","};print "" }'"'"'' 
alias awktranspose 'awk '"'"'{for (i=1; i<=NF; i++) a[i,NR]=$i ;max=(max<NF?NF:max)}  END {for (i=1; i<=max; i++) {for (j=1; j<=NR; j++) printf "%s%s", a[i,j], (j==NR?RS:FS)}}'"'"' '

set bin = `seq 50 1 150 | tr "\n" ","`
foreach par ( `ls runs/ | g par` )
#set par = par_ooo_int
set name = `echo $par | sed "s/par_//g"`
echo bin $par> $par.hist ; cat ~baselibr/gfc_links/daily_gfc0a_n2_core_client_bu_postcts/runs/core_client/n2p_htall_conf4/sta_pt/func.max_high.T_85.typical/logs/result_capture_mclk_$name | grep _reg | awk '{print $4}' | awkbin_between | tr "," " " | awktranspose >> $par.hist
end

paste par*.hist | item 1 2 4 6 8 10 12 14 16 18 20 22 24 > data.dat
gnuplot -p ~baselibr/PNC_script/draw_histogram.gnuplot


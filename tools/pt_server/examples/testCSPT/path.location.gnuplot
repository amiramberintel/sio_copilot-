bind "F" "pause mouse button1; sx=MOUSE_X;sy=MOUSE_Y; replot '/nfs/site/disks/home_user/baselibr/lnc/Core_plot/rise_FF.png' binary filetype=png origin=( sx , sy ) with rgbimage ; replot "
bind "f" "pause mouse button1; sx=MOUSE_X;sy=MOUSE_Y; replot '/nfs/site/disks/home_user/baselibr/lnc/Core_plot/fall_FF.png' binary filetype=png origin=( sx , sy ) with rgbimage ; replot "
bind "L" "pause mouse button1; sx=MOUSE_X;sy=MOUSE_Y; replot '/nfs/site/disks/home_user/baselibr/lnc/Core_plot/latches_neg.png' binary filetype=png origin=( sx , sy ) with rgbimage ; replot " 
bind "l" "pause mouse button1; sx=MOUSE_X;sy=MOUSE_Y; replot '/nfs/site/disks/home_user/baselibr/lnc/Core_plot/latches_pos.png' binary filetype=png origin=( sx , sy ) with rgbimage ; replot "
bind a "pause mouse button1; sx_ar=MOUSE_X;sy_ar=MOUSE_Y;pause mouse button1;set arrow from sx_ar,sy_ar to MOUSE_X,MOUSE_Y ls 2;replot"
bind s "pause mouse button1; sx_sq=MOUSE_X;sy_sq=MOUSE_Y;pause mouse button1;set obj rect from sx_sq,sy_sq to MOUSE_X,MOUSE_Y fc lt 10; replot"
bind t 'load "/nfs/site/home/baselibr/lnc/Core_plot/lnc_client/perllabel.gnuplot

set style line 1 linecolor rgb '#0060ad' linetype -1 linewidth 2
set style line 2 linecolor rgb '#ad0000' linetype -1 linewidth 2
set style line 3 linecolor rgb '#ad00ad' linetype 6 linewidth 2
set style line 4 linecolor rgb '#0000ad' linetype 2 linewidth 2

unset ytics
unset xtics
set size ratio -1
set key noautotitle

set label 'par_exe' at 20,1080
set label 'par_fe' at 1310,950
set label 'par_vpmm' at 20,1600
set label 'par_fmav0' at 380,1460
set label 'par_fmav1' at 20,1460
set label 'par_meu' at 720,1530
set label 'par_mlc' at 20,1900
set label 'par_msid' at 720,260
set label 'par_ooo_int' at 720,830
set label 'par_ooo_vec' at 20,520
set label 'par_pm' at 2050,1900
set label 'par_pmh' at 1660,1100

set label 'par_exe' at 20,3900-1080 
set label 'par_fe' at 1310,3900-950
set label 'par_vpmm' at 20,3900-1600
set label 'par_fmav0' at 380,3900-1460
set label 'par_fmav1' at 20,3900-1460
set label 'par_meu' at 720,3900-1530
set label 'par_msid' at 720,3900-260
set label 'par_ooo_int' at 720,3900-830
set label 'par_ooo_vec' at 20,3900-520
set label 'par_pmh' at 1660,3900-1100

set label 'r - Enable ruler ' at 2300,1900 font ",14" 
set label 'a - Draw arrow ' at 2300,1850 font ",14"
set label 's - Draw square' at 2300,1800 font ",14"
set label 't - Add Text'  at 2300,1750 font ",14"

load "/nfs/site/disks/home_user/baselibr/gfc/Core_plot/core_client/Draw_core_client.ebb"

plot '/nfs/site/home/baselibr/gfc/Core_plot/core_client/icore0.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/icore1.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_exe_icore0.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_exe_icore1.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_fe_icore0.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_fe_icore1.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_fmav0_icore0.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_fmav0_icore1.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_fmav1_icore0.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_fmav1_icore1.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_meu_icore0.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_meu_icore1.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_mlc.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_msid_icore0.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_msid_icore1.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_ooo_int_icore0.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_ooo_int_icore1.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_ooo_vec_icore0.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_ooo_vec_icore1.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_pmh_icore0.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_pmh_icore1.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/par_pm.location' with linespoints linestyle 1 ,\
 '/nfs/site/home/baselibr/gfc/Core_plot/core_client/core_client.location' with linespoints linestyle 2 ,\
 '/nfs/site/disks/tsabek_wa01/playground/testCSPT/path.location' with linespoints linestyle 3
pause -1

#!/usr/bin/tcsh -f

set wa = $ward
set corner = $corner
cat $wa/runs/$block/$tech/sta_pt/$corner/reports/paths_to_dop_fall_late.$corner.rpt | grep "<-" | awk '{print $(NF-2)" "$9}' > fall_late.$corner.csv
cat $wa/runs/$block/$tech/sta_pt/$corner/reports/paths_to_dop_rise_late.$corner.rpt | grep "<-" | awk '{print $(NF-2)" "$9}' > rise_late.$corner.csv
cat $wa/runs/$block/$tech/sta_pt/$corner/reports/paths_to_dop_rise_early.$corner.rpt | grep "<-" | awk '{print $(NF-2)" "$9}' > rise_early.$corner.csv
cat $wa/runs/$block/$tech/sta_pt/$corner/reports/paths_to_dop_fall_early.$corner.rpt | grep "<-" | awk '{print $(NF-2)" "$9}' > fall_early.$corner.csv
`
join rise_late.$corner.csv rise_early.$corner.csv > rise.rpt
join fall_late.$corner.csv fall_early.$corner.csv > fall.rpt
join rise.rpt fall.rpt > $corner.rpt
cat $corner.rpt | replace " " "," > clk_pd_mean_${corner}.csv

\rm rise_late.$corner.csv
\rm fall_late.$corner.csv
\rm rise.rpt
\rm fall.rpt
\rm $corner.rpt

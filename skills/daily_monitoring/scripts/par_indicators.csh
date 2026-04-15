#!/usr/bin/tcsh -f

if ($#argv == 0) then
        echo ""
        echo "Error: you must give PAR WA ~gilkeren/scripts/par_indicators <PAR WA>"
        echo ""
               exit 0
endif

set wa = `realpath $1`


cat $wa/runs/*/$tech/apr_fc/p_*_allcritical.log |awk -F "=" '{print $2}' > tmp.tmp

echo "taking statistics from:"
realpath  $1
echo ""
echo "full report: `rp $wa/runs/*/$tech/apr_fc/p_*_allcritical.log`"
echo ""
echo "#####################################################################################"

echo "-200\n-150\n-100\n-50\n-40\n-30\n-20\n-15\n-10\n-5\n-0" > thr.list


foreach thresh (`cat thr.list`) 
echo "paths less than ${thresh} : " `cat tmp.tmp | awk -v thr=${thresh} ' $1 < thr ' | wc -l` 
end
echo ""
echo ""


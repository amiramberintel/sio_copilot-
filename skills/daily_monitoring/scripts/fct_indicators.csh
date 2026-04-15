#!/usr/bin/tcsh -f

mkdir fct_indicators/
rm -rf fct_indicators/*

clear
if ($#argv == 0) then
        echo ""
        echo "Error: you must give FCT WA ~gilkeren/scripts/section_indicators <FCT WA>"
        echo ""
               exit 0
endif

set wa = `realpath $1`
set proj_step = `cat ${wa}/env.log | grep -w "PROJECT" | replace "=" " " | item 2`
set proj = `cat ${wa}/env.log | grep -w "PROJECT_TEMPLATE" | replace "=" " " | item 2`


set max_margin = `zcat ${wa}/tango/spec/analysis/${proj}.allcritical.must.gz | tail -3 | head -1 | awk -F "|" '{print $2}'`

#threshold list
#if (`echo ${max_margin}` > 0) then
echo "Bins\n-0.100\n-0.050\n-0.040\n-0.030\n-0.020\n-0.015\n-0.010\n-0.005\n-0.000\n0.005\n0.010\n0.015\n0.020\n0.025\n0.030" > fct_indicators/thr.list
echo "Bins\n-0.100\n-0.050\n-0.040\n-0.030\n-0.020\n-0.015\n-0.010\n-0.005\n-0.000\n0.005\n0.010\n0.015\n0.020\n0.025\n0.030"
#else
#echo "Bins\n-0.100\n-0.050\n-0.040\n-0.030\n-0.020\n-0.015\n-0.010\n-0.005\n-0.000" > fct_indicators/thr.list
#echo "Bins\n-0.100\n-0.050\n-0.040\n-0.030\n-0.020\n-0.015\n-0.010\n-0.005\n-0.000"
#endif

foreach section (`ls ${wa}/tango/spec/analysis/${proj}.allcritical.*.gz | replace "allcritical." " " | replace ".gz" "" | item 2`)
echo "working on ${section}"
echo ""
	foreach corner (nominal highv lowv)
		echo "$section" > fct_indicators/${section}_${corner}.full.bins
		echo "$section" > fct_indicators/${section}_${corner}.mindel.full.bins
		echo "$section" > fct_indicators/${section}_${corner}.max.collapsed
		echo "$section" > fct_indicators/${section}_${corner}.full.vrf.bins


		zcat ${wa}/cornet/${corner}/tango/spec/analysis/${proj}.allcritical.${section}.gz | grep -vE "vdmcore|odicore|idvcore|fuselink|maclk|mbclk|corepwrgood" | grep BB | grep -v Driver | replace "|" " " | /nfs/site/proj/mpg/proc/projects/mrm/utils/bin/item 2 > fct_indicators/${section}_${corner}.full
		
		zcat ${wa}/cornet/${corner}/tango/analysis/${proj}.allcritical.${section}.gz | grep -vE "vdmcore|odicore|idvcore|fuselink|maclk|mbclk|corepwrgood" | grep BB | grep -v Driver | replace "|" " " | /nfs/site/proj/mpg/proc/projects/mrm/utils/bin/item 2 > fct_indicators/${section}_${corner}.full.vrf

		zcat ${wa}/cornet/${corner}/tango/analysis/${proj}.mindel.${section}.gz | grep -vE "vdmcore|odicore|idvcore|fuselink|maclk|mbclk|corepwrgood" | grep BB | grep -v Driver | replace "|" " " | /nfs/site/proj/mpg/proc/projects/mrm/utils/bin/item 2 > fct_indicators/${section}_${corner}.mindel.full

		cat ${wa}/cornet/${corner}/tango/spec/analysis/${proj}.allcritical.${section}.report.collapsed | grep -vE "vdmcore|odicore|idvcore|fuselink|maclk|mbclk|corepwrgood" | zegrep BB | grep -v Driver | replace "|" " " | /nfs/site/proj/mpg/proc/projects/mrm/utils/bin/item 3 > fct_indicators/${section}_${corner}.collapsed


		foreach thresh (`cat fct_indicators/thr.list |grep -v Bins`) 
			cat fct_indicators/${section}_${corner}.full | awk -v thr=${thresh} ' $1 < thr ' | wc -l >> fct_indicators/${section}_${corner}.full.bins
			cat fct_indicators/${section}_${corner}.mindel.full | awk -v thr=${thresh} ' $1 < thr ' | wc -l >> fct_indicators/${section}_${corner}.mindel.full.bins
			cat fct_indicators/${section}_${corner}.collapsed | awk -v thr=${thresh} ' $1 < thr ' | wc -l >> fct_indicators/${section}_${corner}.max.collapsed
			cat fct_indicators/${section}_${corner}.full.vrf | awk -v thr=${thresh} ' $1 < thr ' | wc -l >> fct_indicators/${section}_${corner}.full.vrf.bins

		end
	end
end

echo "Done"
echo ""
echo "$wa"
echo ""

echo "Nominal" >> fct_indicators/total.full.bins
paste fct_indicators/thr.list fct_indicators/*_nominal.full.bins | column -t >> fct_indicators/total.full.bins
echo "" >> fct_indicators/total.full.bins
echo "HighV" >> fct_indicators/total.full.bins
paste fct_indicators/thr.list fct_indicators/*_highv.full.bins | column -t >> fct_indicators/total.full.bins

echo "Nominal" >> fct_indicators/total.mindel.bins
paste fct_indicators/thr.list fct_indicators/*_nominal.mindel.full.bins | column -t >> fct_indicators/total.mindel.bins
echo "" >> fct_indicators/total.mindel.bins
echo "HighV" >> fct_indicators/total.mindel.bins
paste fct_indicators/thr.list fct_indicators/*_highv.mindel.full.bins | column -t >> fct_indicators/total.mindel.bins

echo "Nominal" >> fct_indicators/total.max.collapsed
paste fct_indicators/thr.list fct_indicators/*_nominal.max.collapsed | column -t >> fct_indicators/total.max.collapsed
echo "" >> fct_indicators/total.max.collapsed
echo "HighV" >> fct_indicators/total.max.collapsed
paste fct_indicators/thr.list fct_indicators/*_highv.max.collapsed | column -t >> fct_indicators/total.max.collapsed

echo "Nominal" >> fct_indicators/total.full.vrf.bins
paste fct_indicators/thr.list fct_indicators/*_nominal.full.vrf.bins | column -t >> fct_indicators/total.full.vrf.bins
echo "" >> fct_indicators/total.full.vrf.bins
echo "HighV" >> fct_indicators/total.full.vrf.bins
paste fct_indicators/thr.list fct_indicators/*_highv.full.vrf.bins | column -t >> fct_indicators/total.full.vrf.bins

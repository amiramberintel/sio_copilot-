set corner = $1
set wa = $ward

foreach vrf (vrf_split_normalized vrf_split_normalized_uc)
foreach type (int ext)
set outfile = $wa/ct_analyis_${vrf}_${type}.csv
echo "CT,"`cat $wa/$vrf/$corner/$type.status.rpt | egrep "par,"` > $outfile
foreach par (`cat $wa/$vrf/$corner/$type.status.rpt | egrep "par_|Total" |awkc '{print $1}'`)
foreach cor (`ls -1 $vrf/ | grep "$corner"`)
if ($cor == "func.max_high.T_85.typical") then
set ct = ct178
else 
set ct = `echo $cor |awk -F "." '{print $NF}'`
endif
set paths = $wa/$vrf/$cor/$type.status.rpt
echo "$ct,"`grep -w $par $paths` >> $outfile
end
end
end
end

#mail gilkeren -a ct_analyis_vrf_split_normalized_int.csv -a ct_analyis_vrf_split_normalized_ext.csv -a ct_analyis_vrf_split_normalized_uc_int.csv -a ct_analyis_vrf_split_normalized_uc_ext.csv -s ct_analysis

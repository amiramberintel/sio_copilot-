#!/usr/bin/tcsh -f

set wa = `realpath $ward`

set partitions = `ls $wa/runs/ |grep "^par_"`

echo "" > $wa/cp_commands

if ($#argv == 0) then
set file = $wa/check_bu_output_latest.log
else
if ($1 == "local") then
set file = $wa/check_bu_output.log
endif
endif

echo "date,netlist_date,user_po,par,sta_tag,par_version,timing_model,io_date,td_model,par_status,vendor,clk,clk_status,par_rtl,par_wa,fdr,mbist,hip" > $file

foreach par ($partitions)

    #echo "working on $par"
if ($#argv == 0) then
	set tag = `ls -ltr $PROJ_ARCHIVE/arc/$par/sta_primetime/ | grep "^l" |awk '{print $9}' | egrep -v "LNCN3_POWER_ROLLUP|LNCN3CLIENTA0|LNCN3A0LATEST|LNLLNCA0_LATEST|LNLLNCA0_IIL|LNLBRLNCA0LATEST|LNLLNCN3A0LATEST|LNLLNCN3A0_IIL_VER" | tail -1`

	else
	if ($1 == "local") then
		set tag = `cat $wa/runs/$block/$tech/$flow/scripts/user_fct_vars.tcl | grep -w "fct_prep,par_tags_ovr,$par" | awk -F '"' '{print $2}'|tail -1`

	else
		echo "error"
	endif
endif


set full_path = $PROJ_ARCHIVE/arc/$par/sta_primetime/$tag/
set manifest_file = $PROJ_ARCHIVE/arc/$par/sta_primetime/$tag/$par.sta_primetime.manifest.gz

if (`ls -ltr $manifest_file |wc -l` == 0) then
echo "no manifest, pls check tag"
continue
endif

set par_wa = `zcat $manifest_file | grep -w "Work Area" | awk '{print $4}'|awk -F "/runs/" '{print $1}'`

if ($par_wa == 0) then
echo "no WA for $par tag: $tag"
set par_version = NA
set par_rtl = NA
set io_model = NA
set io_model_date = NA
set fcl_model = NA
set fdr = NA
set mbist = NA
set hip = NA
else
set par_version = `ls -ltr $par_wa/project/ | grep snps | awk -F "/" '{print $(NF-1)}'`
set par_rtl = `cat $par_wa/runs/$par/$tech/release/latest/fe_collateral/${par}.hier_f.tcl | grep -v "^#" | grep -w "set ::CORE_ROOT" |awk '{print $3}'`
set io_model = `zegrep -w "Configs" $par_wa/runs/$par/$tech/release/latest/timing_collateral/${par}.timing_collateral.manifest* |awk '{print $3}'`
set io_model_date = `cat $par_wa/runs/$par/$tech/release/latest/timing_collateral/func.max_turbo.T_85.typical/${par}_io_constraints.tcl | grep "^#date =" | awk '{print $4" "$5" "$7}'`
set fcl_model = `zegrep -w "Configs" $par_wa/runs/$par/$tech/release/latest/td_collateral/${par}.td_collateral.manifest* |awk '{print $3}'`
set fdr = `realpath $par_wa/runs/$par/$tech/release/latest/fe_collateral/$par.fdr_exceptions.tcl`
set mbist = `realpath $par_wa/runs/$par/$tech/release/latest/timing_collateral/${par}_mbist_exceptions.tcl`
set hip = `realpath $par_wa/runs/$par/$tech/release/latest/fe_collateral/$par.hip_tags.xml`
endif

set date = `zegrep -w "Current Date" $manifest_file | awk '{print $6" "$5" "$8}'`
set user_po = `zegrep -w "User Name" $manifest_file | awk '{print $4}'`
set par_status = `zegrep -w "write_netlist|write_verilog" $full_path/${par}.pt_nonpg.v*| awk -F " " '{print $NF}' | awk -F "/" '{print $(NF-1)}' |head -1`
if (`zcat -f $full_path/${par}.pt_nonpg.v* | grep -w "Cadence" |wc -l` != 0) then
	set vendor = cdns
else
	set vendor = snps
endif
if ($vendor == cdns ) then
	set clk = `zcat -f $full_path/${par}.pt_nonpg.v* |egrep 'CKN.*CTS_.*_inv_.*' | wc -l`
	set netlist_date = `zegrep "#  Generated on" $full_path/${par}.pt_nonpg.v* | awk '{print $6" "$5" "$8}'`
else
	set clk = `zcat -f $full_path/${par}.pt_nonpg.v* |egrep '^CK.*cts' | wc -l`
	set netlist_date = `zegrep "Generated on" $full_path/${par}.pt_nonpg.v* | head -1 |awk '{print $4}'`
endif
if ($clk == 0) then
	set clk_status = without
else
	set clk_status = with
endif

echo "$date,$netlist_date,$user_po,$par,$tag,$par_version,$io_model,$io_model_date,$fcl_model,$par_status,$vendor,$clk,$clk_status,$par_rtl,$par_wa,$fdr,$mbist,$hip" >> $file

echo "cp $fdr runs/$par/$tech/release/latest/fe_collateral" >> $wa/cp_commands
echo "cp $mbist runs/$par/$tech/release/latest/timing_collateral" >> $wa/cp_commands

end

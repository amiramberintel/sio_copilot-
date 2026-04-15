#!/usr/bin/tcsh -f
#
# csv_split_multi.csh - Compare N models (not just TST vs REF).
#
# Usage:
#   csv_split_multi.csh <corner> <model1_path> <model2_path> [model3_path] ...
#
# Each model is labeled by its WW tag from env_vars.rpt.
# First model is treated as the primary (output dir is under its reports/csv/).
#
# Examples:
#   csv_split_multi.csh func.max_high.T_85.typical $ward $ward/dcm
#   csv_split_multi.csh func.max_high.T_85.typical /path/to/WW13B /path/to/WW13A /path/to/WW12G
#
# Requires: $flow, $PROJECT_STEPPING to be set (source cth_psetup first)

if ($#argv < 3) then
    echo "Usage: $0 <corner> <model1_wa> <model2_wa> [model3_wa] ..."
    echo "  At least 2 models required."
    exit 1
endif

set corner = $1
shift

# Build model list
set n_models = $#argv
set model_paths = ($argv)
set model_labels = ()
set model_techs = ()
set model_blocks = ()

echo "Corner: $corner"
echo "Models: $n_models"
echo ""

foreach i (`seq 1 $n_models`)
    set wa = $model_paths[$i]
    set mtech = `grep "^tech=" $wa/env_vars.rpt | head -1 | cut -d= -f2`
    set mblock = `grep "^block=" $wa/env_vars.rpt | head -1 | cut -d= -f2`
    set mww = `grep "^WW=" $wa/env_vars.rpt | head -1 | cut -d= -f2`
    set model_techs = ($model_techs $mtech)
    set model_blocks = ($model_blocks $mblock)
    set model_labels = ($model_labels $mww)
    echo "  Model ${i} - ${mww} ($wa)"
end

# Output under first model
set primary_wa = $model_paths[1]
set primary_tech = $model_techs[1]
set primary_block = $model_blocks[1]
set out_dir = $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/csv2
set partitions = `ls $primary_wa/runs/ | grep "^par_"`
set pt_log = $primary_wa/runs/${primary_block}/${primary_tech}/${flow}/${corner}/logs/${primary_block}.${corner}.pt.log
set cor_type = `grep -w "$corner" $primary_wa/project/$PROJECT_STEPPING/pvt.tcl | grep -w "scenario_delay_type_map" | awk -F '"' '{print $(NF-1)}'`

\mkdir -p $out_dir
\rm -rf $out_dir/*.csv
\rm -rf $out_dir/*.xlsx

echo ""
echo "Output: $out_dir"
echo "Delay type: $cor_type"
echo ""

#--------------------------------------------------------------------
# Helper: for each report type, iterate over all models
# Pattern: grep a key from primary model, then grep same key from all models
#--------------------------------------------------------------------

#--- ext bottleneck ---
echo "Processing: ext_bottleneck"
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/ext_analyssis_to_0_${corner}.csv` > $out_dir/ext_bottleneck.csv
foreach line (`cat $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/ext_analyssis_to_0_${corner}.csv | grep -v "^num_of_paths" | awk -F "," '{print $2","$3}'`)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        echo "$lb,"`grep -F "$line" $wa/runs/$bl/$te/$flow/$corner/reports/ext_analyssis_to_0_${corner}.csv` >> $out_dir/ext_bottleneck.csv
    end
end

#--- ext bottleneck DFX ---
echo "Processing: ext_bottleneck_dfx"
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/ext_analyssis_to_0_${corner}_dfx.csv` > $out_dir/ext_bottleneck_dfx.csv
foreach line (`cat $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/ext_analyssis_to_0_${corner}_dfx.csv | grep -v "^num_of_paths" | awk -F "," '{print $2","$3}'`)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        echo "$lb,"`grep -F "$line" $wa/runs/$bl/$te/$flow/$corner/reports/ext_analyssis_to_0_${corner}_dfx.csv` >> $out_dir/ext_bottleneck_dfx.csv
    end
end

#--- model_info ---
echo "Processing: model_info"
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/$primary_block.$corner.model_info.ind` > $out_dir/model_info.csv
foreach line (`cat $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/$primary_block.$corner.model_info.ind | grep -v "^BUNDLE" | awk -F "," '{print $1}'`)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        echo "$lb,"`grep -wF "$line" $wa/runs/$bl/$te/$flow/$corner/reports/$bl.$corner.model_info.ind` >> $out_dir/model_info.csv
    end
end

#--- DOPs ---
echo "Processing: dops"
echo "model,DOP,rise_late,rise_early,fall_late,fall_early,mean_rise_late,mean_rise_early,mean_fall_late,mean_fall_early" > $out_dir/dops.csv
foreach dop (`cat $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/paths_to_dop_rise_late.${corner}.rpt | egrep "^par|^icore" | sort`)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        set rise_late = `grep -F "$dop" $wa/runs/$bl/$te/$flow/$corner/reports/paths_to_dop_rise_late.${corner}.rpt | grep "<-" | awk '{print $(NF-8)}' | awk -F "." '{print $1}'`
        set rise_early = `grep -F "$dop" $wa/runs/$bl/$te/$flow/$corner/reports/paths_to_dop_rise_early.${corner}.rpt | grep "<-" | awk '{print $(NF-8)}' | awk -F "." '{print $1}'`
        set fall_late = `grep -F "$dop" $wa/runs/$bl/$te/$flow/$corner/reports/paths_to_dop_fall_late.${corner}.rpt | grep "<-" | awk '{print $(NF-8)}' | awk -F "." '{print $1}'`
        set fall_early = `grep -F "$dop" $wa/runs/$bl/$te/$flow/$corner/reports/paths_to_dop_fall_early.${corner}.rpt | grep "<-" | awk '{print $(NF-8)}' | awk -F "." '{print $1}'`
        set mean_rise_late = `grep -F "$dop" $wa/runs/$bl/$te/$flow/$corner/reports/paths_to_dop_rise_late.${corner}.rpt | grep "<-" | awk '{print $9}' | awk -F "." '{print $1}'`
        set mean_rise_early = `grep -F "$dop" $wa/runs/$bl/$te/$flow/$corner/reports/paths_to_dop_rise_early.${corner}.rpt | grep "<-" | awk '{print $9}' | awk -F "." '{print $1}'`
        set mean_fall_late = `grep -F "$dop" $wa/runs/$bl/$te/$flow/$corner/reports/paths_to_dop_fall_late.${corner}.rpt | grep "<-" | awk '{print $9}' | awk -F "." '{print $1}'`
        set mean_fall_early = `grep -F "$dop" $wa/runs/$bl/$te/$flow/$corner/reports/paths_to_dop_fall_early.${corner}.rpt | grep "<-" | awk '{print $9}' | awk -F "." '{print $1}'`
        echo "$lb,$dop,$rise_late,$rise_early,$fall_late,$fall_early,$mean_rise_late,$mean_rise_early,$mean_fall_late,$mean_fall_early" >> $out_dir/dops.csv
    end
end

#--- EBBs ---
echo "Processing: ebb_summary"
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/ebb_indicator.csv` > $out_dir/ebb_summary.csv
foreach ebb (`cat $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/ebb_indicator.csv | grep -v "EBB_DATE" | awk -F "," '{print $3}'`)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        echo "$lb,"`grep -wF "$ebb" $wa/runs/$bl/$te/$flow/$corner/reports/ebb_indicator.csv` >> $out_dir/ebb_summary.csv
    end
end

#--- Quality ---
echo "Processing: quality"
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/$primary_block.$corner.quality.ind` > $out_dir/quality.csv

#--- VRF headers ---
echo "model,par,ext_0ps,ext_5ps,ext_10ps,ext_20ps,ext_30ps,ext_50ps,ext_100ps,ext_200ps,ext_wns,ext_tns,model,par,int_0ps,int_5ps,int_10ps,int_20ps,int_30ps,int_50ps,int_100ps,int_200ps,int_wns,int_tns" > $out_dir/vrf_dfx.csv
echo "model,par,ext_0ps,ext_5ps,ext_10ps,ext_20ps,ext_30ps,ext_50ps,ext_100ps,ext_200ps,ext_wns,ext_tns,model,par,int_0ps,int_5ps,int_10ps,int_20ps,int_30ps,int_50ps,int_100ps,int_200ps,int_wns,int_tns" > $out_dir/vrf_all.csv
echo "model,par,ext_0%,ext_5%,ext_10%,ext_20%,ext_30%,ext_50%,ext_75%,ext_100%,ext_wns,ext_tns,model,par,int_0%,int_5%,int_10%,int_20%,int_30%,int_50%,int_75%,int_100%,int_wns,int_tns" > $out_dir/vrf_normalized.csv
if ($cor_type == "min") then
    echo "model,par,ext_0ps,ext_5ps,ext_10ps,ext_20ps,ext_30ps,ext_50ps,ext_100ps,ext_200ps,ext_wns,ext_tns,model,par,int_0ps,int_5ps,int_10ps,int_20ps,int_30ps,int_50ps,int_100ps,int_200ps,int_wns,int_tns" > $out_dir/vrf_uncompressed.csv
else
    echo "model,par,ext_0%,ext_5%,ext_10%,ext_20%,ext_30%,ext_50%,ext_75%,ext_100%,ext_wns,ext_tns,model,par,int_0%,int_5%,int_10%,int_20%,int_30%,int_50%,int_75%,int_100%,int_wns,int_tns" > $out_dir/vrf_uncompressed.csv
endif
echo "model,par,unit,ext_0%,ext_5%,ext_10%,ext_20%,ext_30%,ext_50%,ext_75%,ext_100%,ext_wns,ext_tns,model,par,unit,int_0%,int_5%,int_10%,int_20%,int_30%,int_50%,int_75%,int_100%,int_wns,int_tns" > $out_dir/unit_vrf_normalized.csv

#--- OVR / tags / logs headers ---
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/${primary_block}.$corner.ovr.ind` > $out_dir/ovrs.csv
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/${primary_block}.$corner.tags.ind` > $out_dir/tags.csv
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/${primary_block}.$corner.logs.ind` > $out_dir/logs.csv

#--- TOP VRF ---
echo "model,par,ext_0%,ext_5%,ext_10%,ext_20%,ext_30%,ext_50%,ext_75%,ext_100%,ext_wns,ext_tns,version" > $out_dir/top_vrf_normalized.csv
foreach i (`seq 1 $n_models`)
    set wa = $model_paths[$i]
    set bl = $model_blocks[$i]
    set lb = $model_labels[$i]
    echo "$lb,"`cat $wa/vrf_split_normalized/$corner/$bl/$bl.status.rpt | grep -w "$bl" | tail -1` >> $out_dir/top_vrf_normalized.csv
end

#--- Per-partition loop ---
echo "Processing: per-partition data"
foreach par ($partitions)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]

        # vrf_uncompressed
        if ($cor_type == "min") then
            echo "$lb,"`cat $wa/vrf_split_no_dfx/$corner/ext.status.rpt | grep -w "$par" | head -1`",$lb,"`cat $wa/vrf_split_no_dfx/$corner/int.status.rpt | grep -w "$par" | head -1` >> $out_dir/vrf_uncompressed.csv
        else
            echo "$lb,"`cat $wa/vrf_split_normalized_uc/$corner/ext.status.rpt | grep -w "$par" | head -1`",$lb,"`cat $wa/vrf_split_normalized_uc/$corner/int.status.rpt | grep -w "$par" | head -1` >> $out_dir/vrf_uncompressed.csv
        endif

        # vrf_dfx
        echo "$lb,"`cat $wa/vrf_split_only_dfx/$corner/ext.status.rpt | grep -w "$par" | tail -1`",$lb,"`cat $wa/vrf_split_only_dfx/$corner/int.status.rpt | grep -w "$par" | tail -1` >> $out_dir/vrf_dfx.csv

        # vrf_all
        echo "$lb,"`cat $wa/vrf_split_all/$corner/ext.status.rpt | grep -w "$par" | tail -1`",$lb,"`cat $wa/vrf_split_all/$corner/int.status.rpt | grep -w "$par" | tail -1` >> $out_dir/vrf_all.csv

        # vrf_normalized
        echo "$lb,"`cat $wa/vrf_split_normalized/$corner/ext.status.rpt | grep -w "$par" | tail -1`",$lb,"`cat $wa/vrf_split_normalized/$corner/int.status.rpt | grep -w "$par" | tail -1` >> $out_dir/vrf_normalized.csv

        # unit_vrf_normalized
        foreach unit (`cat $primary_wa/units/vrf_split_normalized/$corner/external.status.csv | grep -w "$par" | awk -F "," '{print $2}'`)
            echo "$lb,"`cat $wa/units/vrf_split_normalized/$corner/external.status.csv | grep -w "$par,$unit" | tail -1`",$lb,"`cat $wa/units/vrf_split_normalized/$corner/internal.status.csv | grep -w "$par,$unit" | tail -1` >> $out_dir/unit_vrf_normalized.csv
        end

        # ovrs
        echo "$lb,"`cat $wa/runs/$bl/$te/$flow/$corner/reports/$bl.$corner.ovr.ind | grep -w "$par"` >> $out_dir/ovrs.csv

        # tags
        echo "$lb,"`cat $wa/runs/$bl/$te/$flow/$corner/reports/$bl.$corner.tags.ind | grep -w "$par"` >> $out_dir/tags.csv

        # logs
        echo "$lb,"`cat $wa/runs/$bl/$te/$flow/$corner/reports/$bl.$corner.logs.ind | grep -w "$par"` >> $out_dir/logs.csv
    end
end

#--- VRF Totals ---
foreach i (`seq 1 $n_models`)
    set wa = $model_paths[$i]
    set bl = $model_blocks[$i]
    set te = $model_techs[$i]
    set lb = $model_labels[$i]

    if ($cor_type == "min") then
        echo "$lb,"`cat $wa/vrf_split_no_dfx/$corner/ext.status.rpt | grep -w "^Total" | head -1`",$lb,"`cat $wa/vrf_split_no_dfx/$corner/int.status.rpt | grep -w "^Total" | head -1` >> $out_dir/vrf_uncompressed.csv
    else
        echo "$lb,"`cat $wa/vrf_split_normalized_uc/$corner/ext.status.rpt | grep -w "^Total" | head -1`",$lb,"`cat $wa/vrf_split_normalized_uc/$corner/int.status.rpt | grep -w "^Total" | head -1` >> $out_dir/vrf_uncompressed.csv
    endif
    echo "$lb,"`cat $wa/vrf_split_only_dfx/$corner/ext.status.rpt | grep -w "^Total" | tail -1`",$lb,"`cat $wa/vrf_split_only_dfx/$corner/int.status.rpt | grep -w "^Total" | tail -1` >> $out_dir/vrf_dfx.csv
    echo "$lb,"`cat $wa/vrf_split_all/$corner/ext.status.rpt | grep -w "^Total" | tail -1`",$lb,"`cat $wa/vrf_split_all/$corner/int.status.rpt | grep -w "^Total" | tail -1` >> $out_dir/vrf_all.csv
    echo "$lb,"`cat $wa/vrf_split_normalized/$corner/ext.status.rpt | grep -w "^Total" | tail -1`",$lb,"`cat $wa/vrf_split_normalized/$corner/int.status.rpt | grep -w "^Total" | tail -1` >> $out_dir/vrf_normalized.csv
end

echo "," >> $out_dir/vrf_uncompressed.csv
echo "," >> $out_dir/vrf_dfx.csv
echo "," >> $out_dir/vrf_all.csv
echo "," >> $out_dir/vrf_normalized.csv

#--- VRF Block-level ---
foreach i (`seq 1 $n_models`)
    set wa = $model_paths[$i]
    set bl = $model_blocks[$i]
    set te = $model_techs[$i]
    set lb = $model_labels[$i]

    if ($i == 1) then
        if ($cor_type == "min") then
            echo "model,"`cat $wa/vrf_split_no_dfx/$corner/ext.status.rpt | grep -w "^Block" | head -1` >> $out_dir/vrf_uncompressed.csv
        else
            echo "model,"`cat $wa/vrf_split_normalized_uc/$corner/ext.status.rpt | grep -w "^Block" | head -1` >> $out_dir/vrf_uncompressed.csv
        endif
        echo "model,"`cat $wa/vrf_split_only_dfx/$corner/ext.status.rpt | grep -w "^Block" | head -1` >> $out_dir/vrf_dfx.csv
        echo "model,"`cat $wa/vrf_split_all/$corner/ext.status.rpt | grep -w "^Block" | head -1` >> $out_dir/vrf_all.csv
        echo "model,"`cat $wa/vrf_split_normalized/$corner/ext.status.rpt | grep -w "^Block" | head -1` >> $out_dir/vrf_normalized.csv
    endif

    if ($cor_type == "min") then
        echo "$lb,"`cat $wa/vrf_split_no_dfx/$corner/ext.status.rpt | grep -w "^$bl" | head -1` >> $out_dir/vrf_uncompressed.csv
    else
        echo "$lb,"`cat $wa/vrf_split_normalized_uc/$corner/ext.status.rpt | grep -w "^$bl" | head -1` >> $out_dir/vrf_uncompressed.csv
    endif
    echo "$lb,"`cat $wa/vrf_split_only_dfx/$corner/ext.status.rpt | grep -w "^$bl" | head -1` >> $out_dir/vrf_dfx.csv
    echo "$lb,"`cat $wa/vrf_split_all/$corner/ext.status.rpt | grep -w "^$bl" | head -1` >> $out_dir/vrf_all.csv
    echo "$lb,"`cat $wa/vrf_split_normalized/$corner/ext.status.rpt | grep -w "^$bl" | head -1` >> $out_dir/vrf_normalized.csv
end

#--- Quality per partition ---
echo "Processing: quality"
foreach par ($partitions other)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        echo "$lb,"`cat $wa/runs/$bl/$te/$flow/$corner/reports/$bl.$corner.quality.ind | grep -w "$par"` >> $out_dir/quality.csv
    end
end

#--- par_status ---
echo "Processing: par_status"
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/check_bu_output.log` > $out_dir/par_status.csv
foreach line (`cat $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/check_bu_output.log | grep -v "^#" | awk -F "," '{print $4}'`)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        echo "$lb,"`grep -wF "$line" $wa/runs/$bl/$te/$flow/$corner/reports/check_bu_output.log` >> $out_dir/par_status.csv
    end
end

#--- uarch_status ---
echo "Processing: uarch_status"
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/uarch_status.csv` > $out_dir/uarch_status.csv
foreach line (`cat $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/uarch_status.csv | grep -v "^#" | awk -F "," '{print $1","$2","$3","$4}'`)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        echo "$lb,"`grep -wF "$line" $wa/runs/$bl/$te/$flow/$corner/reports/uarch_status.csv` >> $out_dir/uarch_status.csv
    end
end

#--- sdc_cksum ---
echo "Processing: sdc_cksum"
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/sdc_cksum.csv` > $out_dir/sdc_cksum.csv
foreach line (`cat $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/sdc_cksum.csv | grep -v "^#" | awk -F "," '{print $1}'`)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        echo "$lb,"`grep -wF "$line" $wa/runs/$bl/$te/$flow/$corner/reports/sdc_cksum.csv` >> $out_dir/sdc_cksum.csv
    end
end

#--- check_clk_latency ---
echo "Processing: check_clk_latency"
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/check_clk_latency.$corner.rpt` > $out_dir/check_clk_latency.csv
foreach line (`cat $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/check_clk_latency.$corner.rpt | grep -v "^#" | awk -F "," '{print $1}'`)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        echo "$lb,"`grep -wF "$line" $wa/runs/$bl/$te/$flow/$corner/reports/check_clk_latency.$corner.rpt` >> $out_dir/check_clk_latency.csv
    end
end

#--- uarch_sum ---
echo "Processing: uarch_sum"
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/uarch_sum.csv` > $out_dir/uarch_sum.csv
foreach line (`cat $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/uarch_sum.csv | grep -v "^#" | awk -F "," '{print $1}'`)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        echo "$lb,"`grep -wF "$line" $wa/runs/$bl/$te/$flow/$corner/reports/uarch_sum.csv` >> $out_dir/uarch_sum.csv
    end
end

#--- port indicator ---
echo "Processing: ports"
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/${primary_block}.$corner.port_location.ind` > $out_dir/ports.csv
foreach line (`cat $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/${primary_block}.$corner.port_location.ind | grep "par_" | awk -F "," '{print $2","$3}'`)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        echo "$lb,"`grep -wF "$line" $wa/runs/$bl/$te/$flow/$corner/reports/$bl.$corner.port_location.ind` >> $out_dir/ports.csv
    end
end

#--- DOP stamping ---
echo "Processing: dop_stamping"
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/dop_stamping.${corner}.rpt` > $out_dir/dop_stamping.csv
foreach line (`cat $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/dop_stamping.${corner}.rpt | grep -v "^#dop_input_pin" | awk -F "," '{print $1}'`)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        echo "$lb,"`grep -F "$line" $wa/runs/$bl/$te/$flow/$corner/reports/dop_stamping.${corner}.rpt` >> $out_dir/dop_stamping.csv
    end
end

#--- cell stats ---
echo "Processing: cell_stats"
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/cell_stats.csv` > $out_dir/cell_stats.csv
foreach line (`cat $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/cell_stats.csv | grep -v "^par," | awk -F "," '{print $1}'`)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        echo "$lb,"`grep -wF "$line" $wa/runs/$bl/$te/$flow/$corner/reports/cell_stats.csv` >> $out_dir/cell_stats.csv
    end
end

#--- EBB clk latency ---
echo "Processing: ebb_ltncy"
echo "model,"`head -1 $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/${primary_block}.$corner.ebb_clk_ltncy.ind` > $out_dir/ebb_ltncy.csv
foreach line (`cat $primary_wa/runs/$primary_block/$primary_tech/$flow/$corner/reports/${primary_block}.$corner.ebb_clk_ltncy.ind | grep -v "^#ebb_clk_pin" | awk -F "," '{print $1}'`)
    foreach i (`seq 1 $n_models`)
        set wa = $model_paths[$i]
        set bl = $model_blocks[$i]
        set te = $model_techs[$i]
        set lb = $model_labels[$i]
        echo "$lb,"`grep -F "$line" $wa/runs/$bl/$te/$flow/$corner/reports/$bl.$corner.ebb_clk_ltncy.ind` >> $out_dir/ebb_ltncy.csv
    end
end

#--- General Properties ---
set fct_report_timing_summary_pba_mode_default = `cat $pt_log | grep "ivar(fct_report_timing_summary_pba_mode_default)" | tail -1 | awk -F "'" '{print $2}'`
set pt_ver = `cat $pt_log | grep "ivar(toolversion,primetime)" | tail -1 | awk -F "'" '{print $2}'`

echo "BUNDLE,TAG" > $out_dir/model_tags.csv
echo "BLOCK,$primary_block" >> $out_dir/model_tags.csv
echo "RTL,"`grep -w "CORE_ROOT_DIR" $primary_wa/runs/$primary_block/$primary_tech/$flow/scripts/vars.tcl | awk '{print $NF}'` >> $out_dir/model_tags.csv
echo "FE_COLLATERAL,$FE_COLLATERAL_TAG" >> $out_dir/model_tags.csv
echo "SELF_COLLATERAL/TD_COLLATERAL,$TD_COLLATERAL_TAG" >> $out_dir/model_tags.csv
echo "CLOCK_COLLATERAL,$CLOCK_COLLATERAL_TAG" >> $out_dir/model_tags.csv
echo "TIMING_COLLATERAL,$TIMING_COLLATERAL_TAG" >> $out_dir/model_tags.csv
echo "SIO_TIMING_COLLATERAL,$SIO_TIMING_COLLATERAL_TAG" >> $out_dir/model_tags.csv
echo 'Hip List (override),$model'"/runs/$primary_block/$primary_tech/release/latest/fe_collateral/$primary_block.hip_tags.xml" >> $out_dir/model_tags.csv
echo "TS:,"`ls -ltr $primary_wa/project/ | grep -w "$PROJECT_STEPPING" | awk -F "/" '{print $(NF-1)}'` >> $out_dir/model_tags.csv
echo "," >> $out_dir/model_tags.csv
echo "CORNER:,$corner" >> $out_dir/model_tags.csv
echo "USER:,$user" >> $out_dir/model_tags.csv
echo "ivar(fct_report_timing_summary_pba_mode_default):,$fct_report_timing_summary_pba_mode_default" >> $out_dir/model_tags.csv
echo "PT version:,$pt_ver" >> $out_dir/model_tags.csv
echo "," >> $out_dir/model_tags.csv
echo "Models compared:,$n_models" >> $out_dir/model_tags.csv
foreach i (`seq 1 $n_models`)
    set wa = $model_paths[$i]
    set lb = $model_labels[$i]
    echo "Model ${i} (${lb}),"`realpath $wa` >> $out_dir/model_tags.csv
end
echo "," >> $out_dir/model_tags.csv

echo ""
echo "Done. Output in: $out_dir"
echo "Models compared: $n_models"
foreach i (`seq 1 $n_models`)
    set lb = $model_labels[$i]
    set wa = $model_paths[$i]
    echo "  ${lb} - $wa"
end

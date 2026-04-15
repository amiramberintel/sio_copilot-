#!/usr/intel/bin/tcsh -f
#
# run_extraction.csh - Populate partition from archive and run StarRC extraction.
#
# Usage: run_extraction.csh <partition> <tag> [--local]
#
# Steps:
#   1. Populate partition data from archive (eouMGR)
#   2. Clean up unneeded collateral (SPEF, constraints, etc.)
#   3. Symlink netlist/DEF/UPF into finish or finish_cdns (vendor-dependent)
#   4. Create extraction vars.tcl
#   5. Submit IStarXtract via nbjob (or run locally with --local)
#
# Prerequisites: $ward, $tech must be set (source cth_psetup first)
#
# Examples:
#   run_extraction.csh par_fmav0 new_synthesis_polaris_CLKpush_pt_eco_ww12_5
#   run_extraction.csh par_pmh GOLDEN --local

if ($#argv < 2) then
    echo "Usage: $0 <partition> <tag> [--local]"
    echo "  partition: e.g. par_fmav0, par_meu"
    echo "  tag:       archive tag (e.g. GOLDEN, pt_eco_ww12_5)"
    echo "  --local:   run extraction locally instead of via nbjob"
    exit 1
endif

set par = $1
set tag = $2
set run_local = 0
if ($#argv >= 3 && "$3" == "--local") set run_local = 1

# Validate environment
if (! $?ward) then
    echo "ERROR: \$ward not set. Source cth_psetup first."
    exit 1
endif
if (! $?tech) then
    echo "ERROR: \$tech not set. Source cth_psetup first."
    exit 1
endif

set base = $ward/runs/$par/$tech

echo "============================================"
echo "Partition:  $par"
echo "Tag:        $tag"
echo "Ward:       $ward"
echo "Tech:       $tech"
echo "============================================"

# --- Step 1: Populate from archive ---
echo ""
echo ">>> Step 1: Populating from archive..."
\rm -rf $base/release/latest
eouMGR --block $par --bundle sta_primetime --tag $tag --populate --force
eouMGR --block $par --bundle evr_collateral --tag GFC_MOCK1_TOP_EVR_ww12_2_2026 --populate --force

if ($status != 0) then
    echo "ERROR: eouMGR populate failed"
    exit 1
endif
echo "Done populating from archive"

# --- Step 2: Detect vendor ---
set vendor = `/p/hdk/cad/cth_blocksinfo/latest/user_scripts/bi --table --header sd_vendor_type --fval name=^${par}$ | tail -1`
echo "Vendor: $vendor"

# --- Step 3: Clean up unneeded files ---
echo ""
echo ">>> Step 3: Cleaning up unneeded collateral..."
\rm -rf $base/release/latest/sta_primetime/*spef*
\rm -rf $base/release/latest/sta_primetime/$par.pt_session*
\rm -rf $base/release/latest/clock_collateral
\rm -rf $base/release/latest/dft_collateral
\rm -rf $base/release/latest/sio_timing_collateral
\rm -rf $base/release/latest/constraints_mapping
\rm -rf $base/release/latest/star_pv
\rm -rf $base/release/latest/td_collateral
\rm -rf $base/release/latest/fe_collateral
\rm -rf $base/release/latest/timing_collateral
\rm -rf $base/release/latest/power_collateral

# --- Step 4: Symlink into finish/finish_cdns ---
echo ""
set sta = $base/release/latest/sta_primetime
if ("$vendor" == "snps") then
    echo ">>> Step 4: Linking into finish/ (Synopsys)"
    set finish = $base/release/latest/finish
    mkdir -p $finish
    foreach f ($par.def.gz $par.ndm $par.pt_nonpg.v.gz $par.upf $par.v.gz $par.pt.v.gz $par.oas)
        if (-e $sta/$f) ln -sf `realpath $sta/$f` $finish/
    end
else
    echo ">>> Step 4: Linking into finish_cdns/ (Cadence)"
    set finish = $base/release/latest/finish_cdns
    mkdir -p $finish
    foreach f ($par.def.gz $par.db $par.pt_nonpg.v.gz $par.upf $par.v.gz $par.pt.v.gz $par.oas)
        if (-e $sta/$f) ln -sf `realpath $sta/$f` $finish/
    end
endif
# hip_data goes one level up
if (-e $sta/hip_data) ln -sf `realpath $sta/hip_data` $base/

# --- Step 5: Create extraction vars.tcl ---
echo ""
echo ">>> Step 5: Creating extraction vars.tcl..."
mkdir -p $base/extraction/scripts
\rm -f $base/extraction/scripts/vars.tcl
echo "set ivar(design_name) ${par}" >> $base/extraction/scripts/vars.tcl
echo "set ivar(extraction,evr_def) $base/release/latest/evr_collateral/${par}.core_client.${par}.td_top_evr.def.gz" >> $base/extraction/scripts/vars.tcl
echo 'set ivar(extraction_vmf_type) ""' >> $base/extraction/scripts/vars.tcl

# --- Step 6: Run extraction ---
echo ""
if ("$vendor" == "snps") then
    set stage = "finish"
    set xtract_cmd = "$ward/global/eouFW/bin/IStarXtract -B $par -S finish -A"
else
    set stage = "finish_cdns"
    set xtract_cmd = "$ward/global/eouFW/bin/IStarXtract -B $par -S finish_cdns -IF lefdef_invs -A"
endif

if ($run_local) then
    echo ">>> Step 6: Running extraction locally ($stage)..."
    eval $xtract_cmd
    set s = $status
else
    echo ">>> Step 6: Submitting extraction via nbjob ($stage)..."
    nbjob run --target sc8_express --qslot bc15_gfc_fct --class "SLES15&&4C&&256G" $xtract_cmd
    set s = $status
endif

echo ""
if ($s == 0) then
    echo "Extraction submitted/completed successfully for $par"
else
    echo "ERROR: Extraction failed with status $s"
endif

exit $s

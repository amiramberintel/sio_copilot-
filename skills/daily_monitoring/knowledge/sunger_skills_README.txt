================================================================================
  SKILLS FOR SIO COPILOT — Directory Index
  Source: /nfs/site/disks/sunger_wa/fc_data/my_learns
  Created: 2026-03-30
================================================================================

  scripts/              4 files — Core Python tools
    par_status.py               Partition health status (IFC + HSD tracking)
    par_status_diff.py          Compare IFC timing across daily builds
    ifc_per_corner_report.py    Per-corner setup+hold IFC report (daily+PTECO)
    check_daily_vs_po.py        Compare daily vs PO timing

  cookbooks/           26 files — Step-by-step guides (.txt) and demo scripts (.sh)
    par_status_cookbook.*        How to run par_status pipeline
    par_status_diff_cookbook.*   How to diff builds
    cross_partition_debug_*     Cross-partition timing debug flow
    pt_client_cookbook.*         PT client interactive commands
    icc2_eco_fix_cookbook.*      ICC2 ECO fix flow
    master_timing_fix_*         Master timing fix methodology
    hold_ifc_debug_cookbook.txt  Hold IFC debug flow
    daily_update_cookbook.txt    Daily update pipeline
    copilot_daily_work_guideline.txt  Copilot usage patterns
    + more...

  knowledge/           25 files — Reference documentation
    cross_partition_debug_playbook.txt    Debug playbook for IFC timing
    cross_partition_timing_fix_guideline.txt  Fix guidelines
    sta_primetime_GOLDEN_file_reference.txt   PT golden file reference
    pvt_tcl_overview.txt                 PVT/scenario/voltage overview
    contour_tag_summary.txt              Contour tag structure
    eouMGR_command_summary.txt           eouMGR command reference
    SPEF_explanation.txt                 SPEF format explanation
    FC_VCLP_explanation.txt              VCLP explanation
    path_analysis_procedure.txt          Path analysis procedure
    par_exe_*                            PAR EXE analysis reports
    par_msid_*                           PAR MSID analysis reports
    par_meu_*                            PAR MEU analysis reports
    + more...

  aliases/              6 files — Shell aliases and environment setup
    my.aliases                  Main aliases file
    sunger_aliases              Personal aliases
    ahaimovi_aliases            Team member aliases
    hmuhsen_aliases             Team member aliases
    mburak_aliases              Team member aliases (fctxml, etc.)
    baselibr_aliases            Base library aliases

  tcl/                  8 files — Reusable TCL scripts
    balance_byplevel_clk.tcl    Clock balancing
    fix_shifter_datapath.tcl    Shifter datapath fix
    par_exe_eco_fixes.tcl       PAR EXE ECO fixes
    stage0_verify.tcl           Stage0 verification
    extract_all_tp_files.tcl    Extract TP files
    extract_jnc_pins.tcl        Extract JNC pins
    extract_pin_locations.tcl   Extract pin locations
    fc_extract_standalone.tcl   FC extract standalone

  jnc_conversion/      11 files — GFC-to-JNC TIP file conversion
    convert_gfc_to_jnc.py       V1 converter
    convert_gfc_to_jnc_v2.py    V2 converter (real data)
    scale_gfc_to_jnc.py         Scaling converter
    gen_diff_tables.py           Diff table generator
    run_fc_extract.csh           FC extract runner
    run_fc_farm.sh               Farm submission
    gfc_to_jnc_mapping_analysis.txt  Mapping analysis
    gfc_vs_jnc_diff_report.txt  Diff report
    gfc_vs_jnc_per_signal_diff.txt  Per-signal diff

  eco_fixes/           18 files — Signal-specific ECO fix scripts
    RSMOClearVM803H_*            RSMO clear fix scripts
    DsbExitPointMaskM124H_*      DSB exit point fix
    DsbqBypUopsNumDeltaM124H_*   DSB bypass fix
    shuf2vfpp7v0wbm804h_*        Shuffler fix scripts
    brdispnotsigned_*_fixes.tcl  BR dispatch fix (FE + MSID)
    dcl1dataeccissec_*_fixes.tcl DC L1 ECC fix (MEU + PMH)
    analyze_par_msid_external_status*.sh  MSID external analysis

  specs/                4 files — Missing specs fix files
    icore_missing_specs_fix.csv
    par_exe_missing_specs_fix.csv
    par_exe_missing_specs_fix.xml
    par_pm_missing_specs_fix.csv

  io_constraints/      29 files — Fixed IO constraint TCLs (ww13_4)
    <corner>__core_client_io_constraints.tcl  (all PVT corners)

  tip/                 11 files — TIP topology files and analysis
    icore.*.tp                   TIP topology files
    DsbqWrDataBundleValidsM124H_*  DSB analysis
    ILGBPQIdM107H_*              ILGBPQ analysis
    TIP_creation_flow_guide.txt  TIP creation guide
    TIP_tp_creation_cookbook.txt  TIP .tp creation cookbook

  pt_analysis/         48 files — PrimeTime path analysis reports
    RSMOClearVM803H_*            Path analysis demo and fix summaries
    dcu_l1_*                     DCU L1 hold PBA endpoint analysis
    pba_setup_d*.rpt             PBA setup per databank (d00-d31)
    max_high_dcibbankd*.rpt      Max_high per databank
    pteco_*                      PTECO unfixable hold/setup analysis
    core_client.path_margin*     Path margin ECO reports

  dfx/                  6 files — DFX (Design For Testability) knowledge
    dfx_overview.txt             What DFX is, how it differs from functional timing
    dfx_clock_domains.txt        All DFX clock periods and domain names
    dfx_components.txt           BIST, BISR, JTAG, IJTAG, scan chains explained
    dfx_par_meu_status_ww14a.txt par_meu DFX status per corner with domain breakdown
    dfx_report_reading_guide.txt How to read Maha's DFX weekly status report
    dfx_status_ww14a_summary.txt Full DFX status analysis (WW14A TST vs WW13A REF)

  caliber/              3 files — Intel Caliber FC signoff violations
    caliber_overview.txt         What Caliber is, report locations, how to run
    caliber_violation_types.txt  All rule types explained (SlowSlope, MaxCap, etc.)
    caliber_status_ww14a.txt     WW14A status: per-partition, per-rule, par_meu detail

  fev/                  2 files — FEV (Formal Equivalence Verification)
    fev_overview.txt             What FEV is, tool, directory structure, rules
    fev_status_ww14a.txt         WW14A status: per-partition pass/fail, audit review

================================================================================
  All files are COPIES — originals remain in /nfs/site/disks/sunger_wa/fc_data/my_learns/
================================================================================

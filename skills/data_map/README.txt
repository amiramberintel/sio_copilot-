================================================================================
  SKILL: data_map -- Daily Model File Map & Data Location Reference
================================================================================

TRIGGERS: where is, find file, file location, model structure, ward structure,
          daily model, release model, data map, spef location, def location,
          netlist location, constraints location, collateral, sdc, upf,
          manifest, bootstrap, archive, indicators, vrf, check timing

DESCRIPTION
-----------
Complete map of every file and directory in a daily/release FCT model (ward).
Use this when you need to locate ANY data file for timing analysis.

================================================================================
  WARD NAMING CONVENTION
================================================================================

Ward name pattern:
  GFC_CLIENT_<milestone>_<fct_tag>_<suffix>.<model_type>

Example:
  GFC_CLIENT_26ww12b_ww13_1_initial_with_TIP-FCT26WW16B_meu_VER_64-CLK050.bu_postcts

Components:
  26ww12b_ww13_1_initial   = milestone (workweek/iteration)
  TIP-FCT26WW16B           = FCT model tag
  meu_VER_64               = partition + version
  CLK050                   = clock target (050 = 50ps window)
  bu_postcts               = model type (bu = bottom-up, postcts = after CTS)

Model types:
  bu_postcts    -- Bottom-up post-CTS (most common for SIO)
  bu_postroute  -- Bottom-up post-route
  td_*          -- Top-down models

================================================================================
  WARD TOP-LEVEL STRUCTURE
================================================================================

<ward>/
  |
  |-- env_vars.rpt              Environment variables snapshot
  |                             KEY: MODEL_BLOCK, MODEL_TYPE, REF_MODEL,
  |                                  CENTRAL_HIP_LIST_TAG, SIO_TIMING_COLLATERAL_TAG
  |
  |-- runs/                     ALL partition and block data
  |   |-- n2p_htall_conf4.bootstrap_vars.tcl    ivar() definitions for the build
  |   |-- core_client/          Top-level block (contains intel_caliber, etc.)
  |   |-- icore/                icore block
  |   |-- icore0/               icore instance 0
  |   |-- icore1/               icore instance 1
  |   |-- par_exe/              Partition: execution unit
  |   |-- par_fe/               Partition: front end
  |   |-- par_fmav0/            Partition: FMA vector 0
  |   |-- par_fmav1/            Partition: FMA vector 1
  |   |-- par_meu/              Partition: memory execution unit
  |   |-- par_mlc/              Partition: mid-level cache
  |   |-- par_msid/             Partition: micro-op sequencing ID
  |   |-- par_ooo_int/          Partition: out-of-order integer
  |   |-- par_ooo_vec/          Partition: out-of-order vector
  |   |-- par_pm/               Partition: power management
  |   |-- par_pmh/              Partition: power management helper
  |   |-- par_tmul_stub/        Partition: TMUL stub
  |   |-- pivot/                Pivot block
  |   |-- project_global_waivers/   Project-wide DRC waivers
  |   |-- core_client_top_bin/  Top-level binary
  |
  |-- global/                   Global tool configurations
  |   |-- ansys/                ANSYS power/thermal settings
  |   |-- cdns/                 Cadence (Innovus) settings
  |   |-- common/               Shared settings across tools
  |   |-- coverage/             Code coverage configs
  |   |-- eouFW/                EOU framework configs
  |   |-- fishtail/             Fishtail analysis settings
  |   |-- flows/                Flow definitions
  |   |-- fractal/              Fractal tool settings
  |   |-- intel/                Intel-specific configs
  |   |-- mentor/               Mentor (Siemens) tool settings
  |   |-- mlFW/                 ML framework settings
  |   |-- snps/                 Synopsys tool settings
  |
  |-- archive/                  Archived partition data (symlinks to arc storage)
  |   |-- core_client/
  |   |-- core_server/
  |   |-- icore/
  |   |-- msurom00..msurom10/   Memory subunit ROMs
  |
  |-- design_class/             Design classification data
  |   |-- c2dg_be/              C2DG back-end classification
  |
  |-- dcm/                      DCM (Design Closure Manager) job tracking
  |                             Contains per-job logs and clock skew HTML reports
  |
  |-- nworst_vrf_split_all/     N-worst VRF reports (all paths, per corner)
  |-- nworst_vrf_split_no_dfx/  N-worst VRF (excluding DFX paths)
  |-- nworst_vrf_split_normalized/         N-worst normalized
  |-- nworst_vrf_split_normalized_uc/      N-worst normalized (use-case)
  |
  |-- check_timing/             Timing check results per corner
  |
  |-- fct_cth_ovr.cth           FCT CTH override file
  |-- fct_post_setup.csh        Post-setup hook script

================================================================================
  PARTITION STRUCTURE (per partition, e.g. par_meu)
================================================================================

<ward>/runs/<par>/n2p_htall_conf4/
  |
  |-- release/
  |   |-- latest/               MAIN DATA AREA (symlink to latest release)
  |       |-- sta_primetime/    *** PRIMARY SIO DATA -- see detail below ***
  |       |-- timing_collateral/    SDC constraints per corner
  |       |-- timing_closure/       Timing summary XMLs (per corner)
  |       |-- timing_specs/         IO specs (CSV + XML)
  |       |-- clock_collateral/     Clock definitions per corner
  |       |-- constraints_mapping/  Mapped SDC files
  |       |-- sio_ovr/              SIO timing overrides (false paths, etc.)
  |       |-- sio_timing_collateral/  SIO-specific timing constraints
  |       |-- fe_collateral/        Front-end collateral (HIP tags)
  |       |-- fdr_collateral/       FDR attributes
  |       |-- td_collateral/        Top-down collateral
  |       |-- mbist_collateral/     Memory BIST constraints
  |       |-- hip_ovr/              HIP overrides
  |       |-- netlist_mapping_waiver/  Netlist mapping waivers
  |
  |-- intel_caliber/            DRC/Caliber (Duet) results
  |   |-- <scenario>/           Per timing scenario
  |   |   |-- reports/
  |   |       |-- <par>.apr.summary   *** KEY: DRC violation summary ***
  |   |       |-- caliber/           Per-rule DRC reports (.rpt)
  |   |       |-- duet/              Duet-specific reports
  |   |-- scripts/              Caliber run scripts
  |   |-- logs/                 Caliber run logs
  |   |-- cmdlines/             Command lines used
  |
  |-- caliber_waiver/           DRC waivers
  |   |-- collateral/           Project-level auto waivers
  |   |-- <par>_waiver_db/      User waivers
  |   |-- <par>_approval_db/    Approved violations
  |
  |-- hip_data/                 Hard-IP data
  |   |-- hip_attributes.tcl    HIP timing attributes
  |   |-- hip_cycles.tcl        HIP cycle definitions
  |   |-- hip_ivars.tcl         HIP ivar overrides
  |   |-- hip_filter.log        HIP filtering log
  |   |-- <par>.hip_tags.xml    HIP version tags
  |   |-- oc_type_map.tcl       Operating condition type mapping
  |   |-- hardip_*.csv          HIP pattern files
  |   |-- prepare_config        HIP preparation config
  |
  |-- netlist_mapping/          Netlist mapping results
  |   |-- reports/
  |       |-- generate_json_cfg/
  |       |-- netlist_mapping/
  |
  |-- netlist_mapping_incr/     Incremental netlist mapping
  |
  |-- scripts/                  Build scripts
      |-- create_fishtail_json.tcl

================================================================================
  sta_primetime/ -- THE PRIMARY SIO DATA DIRECTORY
================================================================================

<ward>/runs/<par>/n2p_htall_conf4/release/latest/sta_primetime/
  |
  |-- EXTRACTION (SPEF) FILES
  |   <par>.cworst_CCworst_125.spef.gz        Setup: cold worst-case
  |   <par>.cworst_CCworst_M40.spef.gz        Setup: minus-40 worst-case
  |   <par>.cworst_CCworst_T_125.spef.gz      Setup: 125C transistor-level
  |   <par>.cworst_CCworst_T_M40.spef.gz      Setup: M40 transistor-level
  |   <par>.rcworst_CCworst_125.spef.gz       Hold: RC worst 125C
  |   <par>.rcworst_CCworst_M40.spef.gz       Hold: RC worst M40
  |   <par>.rcworst_CCworst_T_125.spef.gz     Hold: RC worst 125C transistor
  |   <par>.typical_85.spef.gz                Typical: 85C nominal
  |   NOTE: All are symlinks to arc storage:
  |     /nfs/site/disks/gfc_n2_client_arc_transaction_0001/<par>/sta_primetime/<tag>/
  |
  |-- NETLIST
  |   <par>.pt.v                  Gate-level Verilog (with PG pins)
  |   <par>.pt_nonpg.v            Gate-level Verilog (no PG pins)
  |
  |-- PHYSICAL
  |   <par>.def.gz                Design Exchange Format (placement+routing)
  |   <par>.lef                   Library Exchange Format (abstract cells)
  |   <par>_rules.lef             Technology rules LEF
  |   <par>.upf                   Unified Power Format (power domains)
  |
  |-- PORT CAPACITANCE
  |   <par>.func.max_high.T_85.typical.port_capacitance
  |   <par>.func.max_nom.T_85.typical.port_capacitance
  |   <par>.func.min_low.T_85.typical.port_capacitance
  |
  |-- TIMING
  |   <par>.saif.namemap           SAIF signal name mapping (for power)
  |   <par>.pt_va_script.tcl       PT voltage-aware script
  |   <par>_fct.manifest           FCT build manifest (stage completion status)
  |
  |-- reports/
  |   |-- star_pv/
  |       |-- <par>.extract_quality.report    *** StarRC extraction quality ***
  |
  |-- timing_collateral/          Per-corner spec attributes
      |-- <scenario>/
          |-- bu_spec_attribute_core_client.tcl
          |-- bu_spec_attribute_icore.tcl

================================================================================
  timing_collateral/ -- SDC CONSTRAINTS PER CORNER
================================================================================

<ward>/runs/<par>/n2p_htall_conf4/release/latest/timing_collateral/
  |
  |-- GLOBAL FILES (not corner-specific)
  |   global_clocks_constraints.tcl         Master clock definitions
  |   global_constraints.tcl                Global timing constraints
  |   global_constraints_postdft.tcl        Post-DFT constraints
  |   global_constraints_unmapped.tcl       Unmapped constraints
  |   global_mbist_constraints.tcl          Memory BIST constraints
  |   global_par_pm_stuckat.tcl             Power management stuck-at
  |   global_post_visa_constraints.tcl      Post-VISA constraints
  |   global_scan_constraints.tcl           Scan mode constraints
  |   global_ssh_constraints.tcl            SSH constraints
  |   global_tap_constraints.tcl            TAP constraints
  |   global_temp_constraints.tcl           Temporary constraints
  |   hip_excluded_rails.tcl                Excluded HIP power rails
  |   <par>_mbist_exceptions*.sdc           MBIST exception SDCs
  |   <par>.fdr_exceptions.tcl              FDR exceptions
  |   ieu_arrays.sdc                        IEU array constraints
  |   mec_arrays_wrapper.sdc                MEC array constraints
  |   dcu_ext_mbist.sdc                     DCU external MBIST
  |   rsintprf_arrays_ext_mbist.sdc         RSIntPrf MBIST
  |
  |-- PER-CORNER DIRS (one dir per timing scenario)
      func.max_low.T_85.typical/
        |-- <par>_io_constraints.tcl        *** IO delay constraints ***
      func.max_high.T_85.typical/
        |-- <par>_io_constraints.tcl
      func.max_med.T_85.typical/
        |-- <par>_io_constraints.tcl
      func.max_nom.T_85.typical/
        |-- <par>_io_constraints.tcl
      ... (one per corner)

  34 CORNERS:
    Setup: func.max_low, func.max_med, func.max_high, func.max_nom,
           func.max_turbo, func.max_fast, func.max_slow_low,
           func.max_slow_mid, func.max_slow_rc_high,
           func.max_slow_low_cold, func.max_hi_hi_lo,
           func.max_hi_lo_hi, func.max_lo_hi_hi,
           + _stressed variants (max_low_stressed, max_med_stressed,
             max_high_stressed, max_nom_stressed, max_turbo_stressed)
    Hold:  func.min_low, func.min_high, func.min_nom, func.min_turbo,
           fresh.min_fast, fresh.min_fast_cold, fresh.min_slow,
           fresh.min_slow_cold, fresh.min_hvqk,
           fresh.min_hi_hi_lo, fresh.min_hi_lo_hi, fresh.min_lo_hi_hi
    Noise: fresh.noise_high, fresh.noise_low
    EM:    func.rv_em_core

================================================================================
  clock_collateral/ -- CLOCK DEFINITIONS PER CORNER
================================================================================

<ward>/runs/<par>/n2p_htall_conf4/release/latest/clock_collateral/
  |
  |-- GLOBAL FILES
  |   global_clock_ideal_nets.tcl       Ideal (unextracted) clock nets
  |   global_cross_clk_exceptions.tcl   Cross-clock-domain exceptions
  |   global_cross_clk_groups.tcl       Clock groupings
  |   global_pin_stamping.tcl           Clock pin stamping definitions
  |
  |-- PER-CORNER DIRS
      <scenario>/
        |-- <par>_clocks.tcl            Clock create commands
        |-- <par>_clock_params.tcl      Clock parameters (freq, etc.)
        |-- clocks_ctx.tcl              Context clock definitions
        |-- clock_uncertainty.tcl       Setup/hold uncertainty values

================================================================================
  constraints_mapping/ -- MAPPED SDC
================================================================================

<ward>/runs/<par>/n2p_htall_conf4/release/latest/constraints_mapping/
  |-- <par>.clocks.sdc                  All clock definitions (mapped)
  |-- <par>.exceptions.sdc              Timing exceptions
  |-- <par>.internal_exceptions.sdc     Internal partition exceptions
  |-- <par>.misc.sdc                    Miscellaneous SDC
  |-- <par>.pt_nonpg.v                  Non-PG netlist (copy)
  |-- <par>.clock_groups.sdc            Clock group definitions
  |-- map_sdc.log                       SDC mapping log
  |-- setup_issues.rpt                  Issues found during setup
  |-- unmapped_constraints.out          Constraints that could not be mapped

================================================================================
  timing_closure/ -- TIMING SUMMARY XMLS
================================================================================

<ward>/runs/<par>/n2p_htall_conf4/release/latest/timing_closure/
  |-- core_client.<scenario>_timing_summary.xml.filtered
  |   Contains: worst slack per endpoint, violation counts
  |   Corners included:
  |     func.max_high, func.max_low, func.max_med, func.max_nom  (setup)
  |     func.min_low                                               (hold)
  |     fresh.min_fast.F_125.rcworst_CCworst                       (hold)
  |-- core_client.par_source.csv
  |   Maps: which partition owns each path

================================================================================
  timing_specs/ -- IO TIMING SPECIFICATIONS
================================================================================

<ward>/runs/<par>/n2p_htall_conf4/release/latest/timing_specs/
  |-- <par>_spec.csv                    IO specs (main file)
  |-- <par>_spec_ft.csv                 IO specs (fishtail format)
  |-- diff_file                         Diff from previous spec version
  |-- reports/
      |-- <par>_timing_specs.xml        XML timing specs
      |-- <par>_ft_timing_specs.xml     Fishtail XML timing specs
      |-- <par>_missing_spec.report     Ports without specs
      |-- <par>_multipule_spec_definition.report  Duplicate spec definitions
      |-- <par>_pin_not_found.report    Spec pins not found in design

================================================================================
  sio_ovr/ -- SIO TIMING OVERRIDES
================================================================================

<ward>/runs/<par>/n2p_htall_conf4/release/latest/sio_ovr/
  |-- <par>_sio_ovrs.tcl
  |   Contains: set_false_path, set_multicycle_path commands
  |   These are SIO-specific timing exceptions for known false/multi-cycle paths

================================================================================
  sio_timing_collateral/ -- SIO-SPECIFIC CONSTRAINTS
================================================================================

<ward>/runs/<par>/n2p_htall_conf4/release/latest/sio_timing_collateral/
  |-- <par>_internal_exceptions.tcl     SIO internal timing exceptions
  |-- diff_file                         Diff from previous version

================================================================================
  VRF REPORTS (ward-level)
================================================================================

<ward>/nworst_vrf_split_all/<scenario>/
  |-- core_client/              Core-client level VRF
  |-- <par>/                    Per-partition VRF
  |-- ext.status.rpt            External interface status
  |-- int.status.rpt            Internal interface status

VRF = Violation Report Format
Shows n-worst failing paths per endpoint.
4 flavors:
  nworst_vrf_split_all          -- All paths
  nworst_vrf_split_no_dfx       -- Excluding DFX paths
  nworst_vrf_split_normalized   -- Normalized to target
  nworst_vrf_split_normalized_uc -- Normalized per use-case

================================================================================
  FCT MANIFEST -- BUILD COMPLETION STATUS
================================================================================

<par>_fct.manifest in sta_primetime/:
  CSI Done: 1
  COMPILE_FINAL_OPTO Done: 1
  CTS Done: 1
  CLOCK_ROUTE Done: 1
  CLOCK_ROUTE_OPT Done: 0
  ROUTE_OPT Done: 1
  APR_ECO Done: 0
  FILL Done: 1
  EXTRACTION Done: 1

Each stage: 1 = completed, 0 = not completed
EXTRACTION Done: 1 means SPEF files are valid.

================================================================================
  ARCHIVE STORAGE
================================================================================

SPEF/netlist archive:
  /nfs/site/disks/gfc_n2_client_arc_transaction_0001/<par>/sta_primetime/<tag>/
  Tag example: GFCN2CLIENTA0_SC8_VER_064

Partition archive (for re-extraction):
  /nfs/site/disks/gfc_n2_client_arc_transaction_0001/<par>/...
  Accessed via: eouMGR populate (see run_extraction.csh)

================================================================================
  KEY ENVIRONMENT VARIABLES (from env_vars.rpt)
================================================================================

  MODEL_BLOCK        = core_client          (block name)
  MODEL_TYPE         = bu_postcts           (model type)
  REF_MODEL          = path to reference model for comparison
  CENTRAL_HIP_LIST_TAG = GFCN2CLIENTA0_SC8_VER_057
  SIO_TIMING_COLLATERAL_TAG = GOLDEN
  NBPOOL             = sc8_express          (job submission pool)

================================================================================
  QUICK REFERENCE: "WHERE IS..." CHEAT SHEET
================================================================================

  NEED                          PATH
  ----------------------------  ------------------------------------------
  SPEF files                    .../sta_primetime/<par>.<corner>.spef.gz
  Gate netlist                  .../sta_primetime/<par>.pt.v
  DEF (placement)               .../sta_primetime/<par>.def.gz
  LEF (cell abstracts)          .../sta_primetime/<par>.lef
  UPF (power format)            .../sta_primetime/<par>.upf
  Port capacitance              .../sta_primetime/<par>.<scenario>.port_capacitance
  Extraction quality            .../sta_primetime/reports/star_pv/<par>.extract_quality.report
  IO constraints (per corner)   .../timing_collateral/<scenario>/<par>_io_constraints.tcl
  Global constraints            .../timing_collateral/global_constraints.tcl
  Clock definitions             .../clock_collateral/<scenario>/<par>_clocks.tcl
  Clock uncertainty             .../clock_collateral/<scenario>/clock_uncertainty.tcl
  Timing summary XML            .../timing_closure/core_client.<scenario>_timing_summary.xml.filtered
  IO specs CSV                  .../timing_specs/<par>_spec.csv
  SIO overrides                 .../sio_ovr/<par>_sio_ovrs.tcl
  SIO internal exceptions       .../sio_timing_collateral/<par>_internal_exceptions.tcl
  Mapped SDC (clocks)           .../constraints_mapping/<par>.clocks.sdc
  Mapped SDC (exceptions)       .../constraints_mapping/<par>.exceptions.sdc
  DRC summary                   .../intel_caliber/<scenario>/reports/<par>.apr.summary
  DRC per-rule reports          .../intel_caliber/<scenario>/reports/caliber/<Rule>.rpt
  HIP tags                      .../hip_data/<par>.hip_tags.xml
  HIP attributes                .../hip_data/hip_attributes.tcl
  Build manifest                .../sta_primetime/<par>_fct.manifest
  Bootstrap vars                <ward>/runs/n2p_htall_conf4.bootstrap_vars.tcl
  Environment vars              <ward>/env_vars.rpt
  VRF reports                   <ward>/nworst_vrf_split_all/<scenario>/<par>/
  DRC waivers                   .../caliber_waiver/<par>_waiver_db/

  NOTE: "..." = <ward>/runs/<par>/n2p_htall_conf4/release/latest

================================================================================
  PARTITIONS IN GFC CLIENT A0
================================================================================

  par_exe       Execution unit
  par_fe        Front end
  par_fmav0     FMA vector 0
  par_fmav1     FMA vector 1
  par_meu       Memory execution unit (largest, most SIO-critical)
  par_mlc       Mid-level cache
  par_msid      Micro-op sequencing ID
  par_ooo_int   Out-of-order integer
  par_ooo_vec   Out-of-order vector
  par_pm        Power management
  par_pmh       Power management helper

SOURCE: Live GFC build (WW16B par_meu, aholtzma ward)
================================================================================

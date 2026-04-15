================================================================================
  SKILL: contour_model -- Contour Archive Structure, Tags & Bundles
================================================================================

TRIGGERS: contour, contour tag, archive, bundle, eouMGR, populate, tag,
          collateral version, arc, VER_, CONTOUR_, GOLDEN, sta_primetime tag,
          timing_collateral tag, clock_collateral tag, td_collateral tag,
          fe_collateral tag, sio_timing_collateral tag, power_collateral tag,
          assembly, sd_layout, arc storage, partition archive

DESCRIPTION
-----------
The contour model is the versioned archive system for all partition collateral.
Each bundle type (timing, clock, SIO, etc.) is independently versioned and
stored in the project archive. A CONTOUR_TAG groups compatible bundle versions
into a single release snapshot.

This skill maps the entire archive structure, tag naming conventions,
bundle contents, and how to populate/query contour data.

================================================================================
  ARCHIVE ROOT
================================================================================

/nfs/site/disks/gfc_n2_client_arc_proj_archive/arc/

Partitions in archive:
  core_client  core_server  icore  infra
  par_exe      par_fe       par_fmav0  par_fmav1
  par_meu      par_mlc      par_msid   par_ooo_int
  par_ooo_vec  par_pm       par_pmh    par_tmul  par_tmul_stub
  par_vpmm     unijet       test
  msurom00..msurom38   (39 memory subunit ROMs)

================================================================================
  CONTOUR TAG NAMING
================================================================================

Pattern:
  GFCN2CLIENTA0<stepping>_CONTOUR_<workweek><day>[_suffix]

Components:
  GFCN2CLIENTA0  = project (GFC N2 Client A0)
  P08 / P10      = stepping (P08 = earlier, P10 = current)
  26WW13E        = 2026 workweek 13 day E (Friday)
  _new_top_io    = variant with updated top-level IO
  _REFRESH       = refresh contour (mid-week update)
  _PILOT         = pilot/experimental contour

Special tags:
  GFCN2CLIENTA0_CONTOUR_LATEST  -- Always points to latest contour
  GOLDEN                         -- Golden/blessed reference

Version tags (per bundle):
  GFCN2CLIENTA0_SC8_VER_NNN     -- Actual versioned directory
  Contour tags are symlinks to these: CONTOUR_26WW13E -> SC8_VER_150

Recent contour history (par_meu timing_collateral):
  P08_CONTOUR_25WW51A                    (oldest)
  P08_CONTOUR_26WW02D
  P08_CONTOUR_26WW05A_REFRESH
  P10_CONTOUR_26WW06E                    (stepped to P10)
  P10_CONTOUR_26WW07E
  P10_CONTOUR_26WW09E
  P10_CONTOUR_26WW10E_REFRESH
  P10_CONTOUR_26WW12E
  P10_CONTOUR_26WW13E                    (latest as of WW16)
  CONTOUR_LATEST -> SC8_VER_150

================================================================================
  BUNDLE TYPES (per partition)
================================================================================

  Bundle                   SIO Relevance   Description
  -----------------------  --------------  -----------------------------------
  timing_collateral        *** CRITICAL    SDC constraints, IO specs, globals
  clock_collateral         *** CRITICAL    Clock defs, uncertainty, params
  sio_timing_collateral    *** CRITICAL    SIO internal exceptions
  sio_ovr                  *** CRITICAL    SIO false paths, multicycle
  timing_specs             *** CRITICAL    IO timing spec CSVs and XMLs
  timing_closure           ** HIGH         Timing summary XMLs per corner
  sta_primetime            ** HIGH         SPEF, netlist, DEF, LEF, UPF
  td_collateral            ** HIGH         Top-down constraints, interface
  fe_collateral            * MEDIUM        RTL, filelists, UPF, HIP tags
  fdr_collateral           * MEDIUM        FDR attributes and exceptions
  dft_collateral           LOW             DFT/scan collateral
  mbist_collateral         LOW             Memory BIST constraints
  power_collateral         LOW             Power intent (control.mtl)
  evr_collateral           LOW             EVR DEF for TD
  assembly                 LOW             Physical assembly (OAS, SP)
  pd_intent                LOW             Power domain intent
  sd_layout_cdns           LOW             Cadence layout data
  fev_rtl2apr_cdns         LOW             Formal equivalence
  fev_rtl2syn_cdns         LOW             Formal equivalence
  fev_convergence_cdns     LOW             Formal convergence
  qc_reports               LOW             Quality check reports
  rvsc_*                   LOW             RVSC power/thermal (6 types)

================================================================================
  BUNDLE CONTENTS -- DETAILED
================================================================================

--- timing_collateral ---
Path: arc/<par>/timing_collateral/<tag>/

Global files:
  global_clocks_constraints.tcl         Master clock definitions
  global_constraints.tcl                Global timing constraints
  global_constraints_postdft.tcl        Post-DFT constraints
  global_constraints_unmapped.tcl       Unmapped constraints
  global_mbist_constraints.tcl          Memory BIST constraints
  global_par_pm_stuckat.tcl             Power management stuck-at
  global_post_visa_constraints.tcl      Post-VISA constraints
  global_scan_constraints.tcl           Scan mode constraints
  global_ssh_constraints.tcl            SSH constraints
  global_tap_constraints.tcl            TAP constraints
  global_temp_constraints.tcl           Temporary constraints
  hip_excluded_rails.tcl                Excluded HIP power rails
  <par>.fdr_attributes.tcl              FDR attributes
  <par>.fdr_exceptions.tcl              FDR exceptions
  <par>_mbist_exceptions.tcl            MBIST exceptions
  <par>_mbist_exceptions_global.sdc     Global MBIST SDC
  dcu_ext_mbist.sdc                     DCU ext MBIST
  ieu_arrays.sdc                        IEU array constraints
  mec_arrays_wrapper.sdc                MEC array constraints
  rsintprf_arrays_ext_mbist.sdc         RSIntPrf MBIST
  <par>.timing_collateral.manifest      Manifest file
  <par>.timing_collateral.manifest.gz   Compressed manifest

Per-corner dirs (IO constraints):
  func.max_low.T_85.typical/
    <par>_io_constraints.tcl
  func.max_med.T_85.typical/
    <par>_io_constraints.tcl
  func.max_high.T_85.typical/
    <par>_io_constraints.tcl
  func.max_nom.T_85.typical/
    <par>_io_constraints.tcl
  + stressed variants (max_low_stressed, max_med_stressed, etc.)

--- clock_collateral ---
Path: arc/<par>/clock_collateral/<tag>/

Global files:
  global_clock_ideal_nets.tcl           Ideal (unextracted) clock nets
  global_cross_clk_exceptions.tcl       Cross-clock-domain exceptions
  global_cross_clk_groups.tcl           Clock groupings
  global_pin_stamping.tcl               Clock pin stamping

Per-corner dirs (34 corners):
  <scenario>/
    <par>_clocks.tcl                    Clock create commands
    <par>_clock_params.tcl              Clock freq, duty cycle params
    clocks_ctx.tcl                      Context clock definitions
    clock_uncertainty.tcl               Setup/hold uncertainty

Corners include: func.max_*, func.min_*, fresh.min_*, fresh.noise_*,
                 func.rv_em_core, func.power_mid_warm_client

--- sio_timing_collateral ---
Path: arc/<par>/sio_timing_collateral/<tag>/

  <par>_internal_exceptions.tcl         SIO internal exceptions
  diff_file                             Diff from previous version
  <par>.sio_timing_collateral.manifest.gz

--- sio_ovr ---
Path: arc/<par>/sio_ovr/<tag>/

  <par>_sio_ovrs.tcl                    SIO timing overrides
  <par>.sio_ovr.manifest.gz             (set_false_path, set_multicycle_path)

--- timing_specs ---
Path: arc/<par>/timing_specs/<tag>/

  <par>_spec.csv                        IO timing specs (main)
  <par>_spec_ft.csv                     Fishtail format specs
  diff_file                             Diff from previous version
  reports/
    <par>_timing_specs.xml              XML timing specs
    <par>_ft_timing_specs.xml           Fishtail XML
    <par>_missing_spec.report           Ports without specs
    <par>_multipule_spec_definition.report   Duplicate specs
    <par>_pin_not_found.report          Spec pins not in design
  <par>.timing_specs.manifest.gz

--- timing_closure ---
Path: arc/<par>/timing_closure/<tag>/

  core_client.<scenario>_timing_summary.xml.filtered   (one per corner)
  core_client.par_source.csv                           (partition source map)
  <par>.timing_closure.manifest.gz

  Also stores historical model references:
    GFC_CLIENT_<milestone>-<fct_tag>.bu_postcts        (symlinks to ward)

  37 corners of timing summary XMLs.

--- sta_primetime ---
Path: arc/<par>/sta_primetime/<tag>/

  Versioned by custom tags (not contour), e.g.:
    ww15, ww15__pad_all_the_way, ww15__pad_until_route,
    ww08_contour9e_newrtl_plus_gal_fixed

  Contains (same as release/latest/sta_primetime in ward):
    <par>.<corner>.spef.gz              8 SPEF files
    <par>.pt.v                          Gate-level netlist (PG)
    <par>.pt_nonpg.v                    Gate-level netlist (no PG)
    <par>.def.gz                        DEF placement/routing
    <par>.lef                           LEF cell abstracts
    <par>_rules.lef                     Technology rules LEF
    <par>.upf                           Power format
    <par>.saif.namemap                  SAIF signal mapping
    <par>.<scenario>.port_capacitance   Port cap per corner
    <par>_fct.manifest                  Build stage completion
    design.library_link_scaling.*.tcl   Library scaling per corner
    bscript/                            Build scripts
    fscript/                            Flow scripts
    clock_collateral/                   (copy for self-contained model)
    constraints_mapping/                (copy)
    dft_collateral/                     (copy)
    fe_collateral/                      (copy)
    fv/                                 Formal verification data
    hip_data/                           HIP data
    logs/                               Build logs
    reports/star_pv/                    Extraction quality report

--- td_collateral ---
Path: arc/<par>/td_collateral/<tag>/

  standard/
    <par>.v                             Verilog netlist
    <par>.pg.v                          PG netlist
    <par>.upf                           Power format
    <par>.loc                           Location constraints
    <par>.power_map                     Power domain mapping
    <par>.clock_types.tcl               Clock type definitions
    <par>.cells_location_update_innovus.tcl
    <par>_td.attribute.xml              TD attributes
    <par>_td.def                        TD DEF
    <par>_td.pg.v                       TD PG netlist
    <par>_td.spef                       TD SPEF
    <par>_td.upf                        TD UPF
    <par>_fc_units.rpt                  FC unit report
    <par>_feedthrough_info.csv          Feedthrough data
    <par>_fev.tcl                       Formal verification
  innovus/
    <par>_clock_connectivity_innovus.tcl
    <par>_td_attributes_innovus.tcl
    <par>_td_connectivity_innovus.tcl
    <par>_td_pd_constraints_innovus.tcl
  icc2/
    <par>.loc
    <par>_td.attribute.xml
    <par>_td_connectivity.tcl
    <par>_td_pd_constraints.tcl
    <par>_td_user_attribute.tcl
    <par>_fev_fm.tcl
    timing_common/

--- fe_collateral ---
Path: arc/<par>/fe_collateral/<tag>/

  <par>.v.gz                            RTL Verilog (compressed)
  <par>.f                               Filelist
  <par>.fixed.f                         Fixed filelist
  <par>.upf                             Power format
  <par>.hip_tags.xml                    HIP version tags
  <par>.hip_tags_signoff.xml            Signoff HIP tags
  <par>.hier_f.tcl                      Hierarchy filelist TCL
  <par>.lp_signal_supply.tcl            Low-power signal supply
  <par>.rtl2fev.tcl                     RTL-to-FEV mapping
  <par>_hier.csv                        Hierarchy CSV
  <par>_rtl_snapshot.fcn                RTL snapshot FCN
  fcn_missing_hips.rpt                  Missing HIP report
  ms_units                              Memory/special units list
  ms_units.stubs                        Stub definitions
  rails.tcl                             Power rail definitions
  soc_hier.partial.csv                  SoC hierarchy

--- fdr_collateral ---
Path: arc/<par>/fdr_collateral/<tag>/

  <par>.fdr_attributes.tcl              FDR timing attributes
  <par>.fdr_exceptions.tcl              FDR timing exceptions

--- dft_collateral ---
Path: arc/<par>/dft_collateral/<tag>/

  dft_data.tcl                          DFT data definitions
  dft_pre_compile_setup.tcl             Pre-compile DFT setup
  bb_buf.v                              Black-box buffer Verilog
  rules.cfg                             DFT rules config
  scan_caliber_data.tcl                 Scan Caliber data
  block_waiver.swl                      Block-level waivers
  gen_spgdft_collaterals.pl             Collateral generator

--- power_collateral ---
Path: arc/<par>/power_collateral/<tag>/

  control.mtl                           Power control material/intent

--- mbist_collateral ---
Path: arc/<par>/mbist_collateral/<tag>/

  dcu_ext_mbist.sdc
  ieu_arrays.sdc
  mec_arrays_wrapper.sdc
  <par>_mbist_exceptions.tcl
  <par>_mbist_exceptions_global.sdc
  rsintprf_arrays_ext_mbist.sdc

--- evr_collateral ---
Path: arc/<par>/evr_collateral/<tag>/

  <par>.td_top_evr.def.gz              EVR DEF for top-down

--- assembly ---
Path: arc/<par>/assembly/<tag>/

  config/                               Assembly configuration
  data/                                 Assembly data
  hip_data/                             HIP data for assembly
  logs/                                 Assembly logs
  outputs/                              Assembly outputs
  reports/                              Assembly reports
  <par>.oas                             OASIS layout file
  <par>.sp                              SPICE netlist

================================================================================
  HOW TO POPULATE FROM ARCHIVE
================================================================================

Command:
  eouMGR --block <par> --bundle <bundle_type> --tag <contour_tag> --populate --force

Example (populate all SIO-relevant bundles):
  set ctag = GFCN2CLIENTA0P10_CONTOUR_26WW13E
  set par  = par_meu

  eouMGR --block $par --bundle timing_collateral       --tag $ctag --populate --force
  eouMGR --block $par --bundle clock_collateral        --tag $ctag --populate --force
  eouMGR --block $par --bundle sio_timing_collateral   --tag $ctag --populate --force
  eouMGR --block $par --bundle td_collateral           --tag $ctag --populate --force
  eouMGR --block $par --bundle fe_collateral           --tag $ctag --populate --force
  eouMGR --block $par --bundle dft_collateral          --tag $ctag --populate --force
  eouMGR --block $par --bundle power_collateral        --tag $ctag --populate --force

================================================================================
  HOW TO QUERY TAGS
================================================================================

Check current contour tag:
  echo $CONTOUR_TAG
  grep CONTOUR_TAG <ward>/env_vars.rpt

Check what version a contour points to:
  ls -la arc/<par>/timing_collateral/<CONTOUR_TAG>
  # Shows: CONTOUR_26WW13E -> GFCN2CLIENTA0_SC8_VER_150

Check latest contour:
  ls -la arc/<par>/timing_collateral/GFCN2CLIENTA0_CONTOUR_LATEST

List all contour tags for a partition:
  ls arc/<par>/timing_collateral/ | grep CONTOUR

Check all bundle versions for a contour:
  for bundle in timing_collateral clock_collateral sio_timing_collateral \
                td_collateral fe_collateral; do
    echo "$bundle: $(readlink arc/<par>/$bundle/<CONTOUR_TAG>)"
  done

Get all tags alias (from baselibr):
  get_tags_FCT <sio_tag> <timing_tag> <dft_tag> <contour_tag>

================================================================================
  CONTOUR vs WARD RELATIONSHIP
================================================================================

The WARD (work area) is populated FROM the contour archive:
  1. FCT build starts with a CONTOUR_TAG
  2. eouMGR populates ward from archive using contour tag
  3. Build runs (CTS, route, extraction, timing)
  4. Results (SPEF, timing XMLs) archived back with new VER tags
  5. Next contour may include updated bundles

Flow:
  Archive (CONTOUR_TAG)  --(populate)-->  Ward  --(build)-->  Results
       ^                                                         |
       +----(archive new version)--------------------------------+

Key env vars in ward:
  CONTOUR_TAG                = which contour was used
  TIMING_TAG                 = timing_collateral version
  TIMING_COLLATERAL_TAG      = same (alias)
  SIO_TIMING_COLLATERAL_TAG  = SIO collateral version
  CENTRAL_HIP_LIST_TAG       = HIP list version

================================================================================
  QUICK REFERENCE: FIND IT IN ARCHIVE
================================================================================

  NEED                          ARCHIVE PATH
  ----------------------------  -----------------------------------------------
  IO constraints (setup)        arc/<par>/timing_collateral/<tag>/<corner>/
  Clock definitions             arc/<par>/clock_collateral/<tag>/<corner>/
  SIO overrides (false paths)   arc/<par>/sio_ovr/<tag>/
  SIO internal exceptions       arc/<par>/sio_timing_collateral/<tag>/
  IO specs CSV                  arc/<par>/timing_specs/<tag>/
  Timing summary XMLs           arc/<par>/timing_closure/<tag>/
  SPEF files                    arc/<par>/sta_primetime/<tag>/
  Netlist (.pt.v)               arc/<par>/sta_primetime/<tag>/
  DEF file                      arc/<par>/sta_primetime/<tag>/
  RTL source                    arc/<par>/fe_collateral/<tag>/
  HIP tags                      arc/<par>/fe_collateral/<tag>/<par>.hip_tags.xml
  TD constraints (Innovus)      arc/<par>/td_collateral/<tag>/innovus/
  TD constraints (ICC2)         arc/<par>/td_collateral/<tag>/icc2/
  FDR attributes                arc/<par>/fdr_collateral/<tag>/
  Power intent                  arc/<par>/power_collateral/<tag>/
  Physical layout (OAS)         arc/<par>/assembly/<tag>/
  DRC waivers                   (not in archive -- in ward caliber_waiver/)

  NOTE: arc = /nfs/site/disks/gfc_n2_client_arc_proj_archive/arc

================================================================================
  GOTCHAS
================================================================================

  - Contour tags are SYMLINKS -- readlink to see actual VER_NNN
  - Each bundle has its OWN version -- clock VER_049 != timing VER_150
  - _new_top_io variants have updated top-level IO constraints
  - _REFRESH contours are mid-week updates (not standard weekly)
  - _PILOT contours are experimental (may not be stable)
  - GOLDEN tag = blessed reference (not always latest)
  - Stepping change (P08 -> P10) means RTL changes, not just collateral
  - sta_primetime uses custom tags (ww15, etc.) not CONTOUR tags
  - get_missing_bottom_up_files_from_contour=1 in env_vars means
    the ward auto-fetches missing files from contour archive
  - Always check manifest.gz to verify what was actually populated

SEE ALSO
--------
  skills/data_map/      -- Ward (daily model) file structure
  skills/specs/         -- IO specification details
  skills/clock/         -- Clock constraint details
  config/paths.cfg      -- All key directory paths
  tools/primetime/      -- PT timing flow using contour data

SOURCE: Live GFC archive (par_meu), contour_tag_summary.txt, env_vars.rpt
================================================================================

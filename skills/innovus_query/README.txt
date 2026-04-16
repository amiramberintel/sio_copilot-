================================================================================
  SKILL: innovus_query -- On-demand Innovus Session for Deep Physical Queries
================================================================================

TRIGGERS: innovus, open innovus, physical design, routing detail, congestion,
          metal usage, via count, wire length per layer, cell utilization,
          placement density, drc debug, routing topology

DESCRIPTION
-----------
On-demand Innovus session with auto-timeout to protect license usage.
Use when PT/SPEF queries are not enough -- typically for:
  - Per-layer wire length and via count breakdown (full routing detail)
  - Congestion analysis (hotspot identification)
  - Cell utilization and placement density
  - DRC root cause debugging on specific metal layers
  - Full routing topology visualization

WHEN TO USE (vs other approaches):
  - PT session:     instant cap/res/wire_length, but NO per-layer routing detail
  - SPEF script:    per-layer node count + approx resistance, 5-15 min
  - Innovus:        FULL routing detail -- exact per-layer wire length, via types,
                    congestion, cell placement, DRC -- but needs 10-30 min to load

================================================================================
  ENVIRONMENT SETUP (REQUIRED BEFORE LAUNCHING)
================================================================================

Innovus is NOT in your default PATH. You need a CTH/W2E environment first.

HOW PAR TEAM SETS IT UP:
  The setup chain is: cth_psetup -> W2E lobby -> Icdns_shell -> innovus

  Step 1: cth_psetup (creates the ward environment)
    /nfs/site/proj/hdk/pu_tu/prd/liteinfra/1.19.p1/commonFlow/bin/cth_psetup \
      -proj gfc_n2_client/GFC_TS2025.15.3 \
      -cfg gfcn2clienta0.cth \
      -ward /nfs/site/disks/mpridvas_wa/PAR \
      -x '$SETUP_R2G -f -w <ward_name> -b <partition>'

  Step 2: This opens a csh shell with Icdns_shell and all Cadence tools in PATH
  Step 3: Icdns_shell wraps 'innovus -stylus' with correct environment

  The setup_info.txt in each archive tag records the exact command used.

QUICK ACCESS OPTIONS:
  1. nbjob submission (RECOMMENDED -- no local setup needed, see below)
  2. Ask PAR engineer (mpridvas) for a pre-configured shell
  3. Use W2E lobby: psetup / load_setup aliases from lobby prompt
  4. Run cth_psetup yourself (need ward access)

REQUIREMENT: Must run on SLES15 machine (enforced by W2E lobby / nbjob class).

NBJOB SUBMISSION (from PAR team / Ameer):
  /usr/intel/bin/nbjob run \
    --target sc8_express \
    --qslot /c2dg/BE_BigCore/gfc/dedemr \
    --class "SLES15SP4&&32C" \
    Icdns_shell -F apr_innovus -stylus -P -I -N -A -R apr_cdns -B "$block"

  Machine class options (adjust --class to your allocation):
    Full PAR run:     "SLES15SP4&&397G&&32C&&EMERALDRAPIDS"  (397GB, 32 cores, EMR)
    Light query:      "SLES15SP4&&32C"                       (any SLES15, 32 cores)
    Minimal:          "SLES15SP4"                             (any SLES15 available)

  NOTE: If you don't have access to the 397G/EMR class, use "SLES15SP4&&32C"
        or just "SLES15SP4". For read-only DB restore + queries, you don't need
        full PAR resources.

================================================================================
  QUICK START
================================================================================

OPTION A: Auto-detect (tries local, falls back to nbjob)

  bash skills/innovus_query/scripts/innovus_session.sh par_meu 60

OPTION B: Force nbjob submission (no local tools needed)

  bash skills/innovus_query/scripts/innovus_session.sh --nbjob par_meu 60

OPTION C: Force local (must have Icdns_shell in PATH)

  bash skills/innovus_query/scripts/innovus_session.sh --local par_meu 60

  All options will:
  1. Find latest archived design DB for par_meu
  2. Launch Innovus in no-GUI mode (saves license overhead)
  3. Restore design (~10-30 min)
  4. Load physical_queries.tcl with ready-to-use procs
  5. Auto-exit after 60 minutes to release the license

  Then in the Innovus prompt:
    inv_net_report "mynet"        # Full per-layer report
    inv_metal_summary             # Partition-wide metal usage
    inv_congestion                # Full-chip congestion
    inv_congestion 100 200 300 400  # Region congestion

OPTION D: One-shot batch query (run query, get result, exit)

  # Create query script
  cat > /tmp/innovus_query.tcl << 'EOF'
  restoreDesign <db_path> par_meu
  source skills/innovus_query/tcl/physical_queries.tcl
  inv_net_report "mynet"
  exit
  EOF
  innovus -nowin -init /tmp/innovus_query.tcl > result.txt 2>&1

================================================================================
  AVAILABLE PROCS (physical_queries.tcl)
================================================================================

  inv_net_report <net>
    Full physical report for a net:
    - Total wire length (um)
    - Per-metal-layer wire length + segment count + percentage
    - Via breakdown by via layer type + total count
    - Driver and receiver pin names

  inv_metal_summary
    Partition-wide routing summary (uses Innovus reportRoute)

  inv_congestion ?x1 y1 x2 y2?
    Congestion overflow report. Optional bounding box for region query.

  inv_utilization
    Cell count, area, placement density stats

  inv_drc_summary
    Run DRC check and report violations

  inv_find_nets <pattern>
    Find nets by wildcard pattern (e.g. "clk*meu*")

  inv_inst_distance <inst1> <inst2>
    Manhattan distance between two cell instances

================================================================================
  DESIGN DATABASE LOCATION
================================================================================

Archive (read-only, always available):
  /nfs/site/disks/gfc_n2_client_arc_proj_archive/arc/<partition>/sd_layout_cdns/

Latest tag:  GFCN2CLIENTA0LATEST -> GFCN2CLIENTA0_SC8_VER_NNN
Design DB:   <tag>/sd_layout_cdns_latest/<partition>.db/
DB contents:
  <par>.route.gz        -- Full routing data (1.1GB for par_meu)
  <par>.place.gz        -- Placement data
  <par>.fp.gz           -- Floorplan
  <par>.route.congmap.gz -- Congestion map
  <par>.marker.gz       -- DRC markers
  <par>.techData.gz     -- Tech data (layer definitions)

Also available in archive:
  <par>.lib_cell_usage.csv  -- Cell inventory (instant, no Innovus needed)
  <par>.lvs.v.gz            -- LVS netlist
  <par>.pt.v.gz             -- PT netlist
  <par>.upf                 -- Power intent

PAR work area (live, may be in use):
  /nfs/site/disks/mpridvas_wa/PAR/par_fe_GFC_ww16_2/

================================================================================
  LICENSE MANAGEMENT
================================================================================

IMPORTANT: Innovus licenses are limited and shared across the GFC team.

Auto-timeout: The launcher script auto-exits after the specified timeout
  (default 120 min). Always set the shortest timeout you need:

  innovus_session.sh par_meu 30    # 30 min for quick query
  innovus_session.sh par_meu 60    # 1 hour for deeper analysis

No-GUI mode: We always launch with -nowin (no GUI) which uses fewer
  license features than the full GUI.

Check license usage:
  # See who has Innovus licenses
  lmstat -a -c <license_server> | grep -i innovus

Best practice:
  1. Try PT or SPEF script first
  2. If you need Innovus, use shortest possible timeout
  3. Exit as soon as your query is done (type 'exit')
  4. Never leave Innovus running overnight

================================================================================
  EXAMPLE: FULL NET PHYSICAL REPORT FROM INNOVUS
================================================================================

  innovus> inv_net_report "rslduopcodm301h_21_[8]"

  ============================================================
  NET PHYSICAL REPORT: rslduopcodm301h_21_[8]
  ============================================================
  Total wire length:  64.170 um
  Total vias:         18

  METAL LAYER USAGE:
    Layer      Length(um)   Segments   % of Total
    --------------------------------------------------
    M1         2.340        2          3.6%
    M7         8.120        2          12.7%
    M8         12.450       4          19.4%
    M9         28.960       9          45.1%
    M10        12.300       4          19.2%

  VIA BREAKDOWN:
    Via Layer       Count
    ------------------------------
    VIA0            1
    VIA2            2
    VIA6            2
    VIA7            3
    VIA8            8
    VIA_upper       2

  Driver:    <driver_pin>
  Receivers: 2 pins
    - exe_int/micrctls/miictls/g499743:A2
    - rslduopcodm301h_21_[8]
  ============================================================

================================================================================
  SEE ALSO
================================================================================

  skills/spef_query/     -- SPEF-based queries (no license needed, 5-15 min)
  skills/physical/       -- Extraction quality, DRC reports (no tool needed)
  skills/data_map/       -- File locations in daily model
  tools/primetime/       -- PT session for instant cap/res queries

SOURCE: GFC par_meu design DB from sd_layout_cdns archive (SC8_VER_001)
================================================================================

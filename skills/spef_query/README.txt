================================================================================
  SKILL: spef_query -- Fast SPEF Data Extraction for Physical/Timing Analysis
================================================================================

TRIGGERS: spef, spef query, net capacitance, net resistance, coupling cap,
          wire length, metal layer, via count, manhattan distance, rc delay,
          net parasitics, spef extract, net physical, routing data,
          bounding box, fanout, pin location, driver receiver

DESCRIPTION
-----------
Get physical data (R, C, metal layers, wire length, pin coords, distance)
for any net. Three approaches by speed:

  RECOMMENDED: PT SESSION (instant -- SPEF already loaded in memory)
  BACKUP:      Python streaming script (5-15 min per query)
  ESCALATION:  Innovus session (ask PAR team for deep physical debug)

SPEF files are HUGE (3.8GB compressed, ~2.76M nets per partition per corner,
8 corners = ~30GB per partition). Don't parse them if PT is available.

================================================================================
  APPROACH 1: PT SESSION -- INSTANT (RECOMMENDED)
================================================================================

If you have a PT session loaded (which you do for daily timing work),
ALL physical data is instantly available. PT already loaded the SPEF.

QUICK START:
  # In PT session:
  source .../skills/spef_query/tcl/physical_net_query.tcl

  # Full physical summary for a net (cap, wire length, driver, receivers)
  sio_net_physical "dcl1hitslm404h_0_[0]"

  # Physical data for all nets on a timing path
  sio_path_physical "startpoint" "endpoint"

  # Find worst-cap nets on failing paths for a clock
  sio_worst_nets "mclk_meu" 20

  # Distance between two pins
  sio_pin_distance "inst1/Z" "inst2/A"

INDIVIDUAL PT COMMANDS:
  get_attribute [get_nets "mynet"] total_capacitance    ;# Net cap
  get_attribute [get_nets "mynet"] wire_length           ;# Wire length
  get_attribute [get_nets "mynet"] fanout                ;# Fanout
  report_net -connections -verbose [get_nets "mynet"]    ;# Full detail
  get_attribute [get_pins "inst/pin"] location           ;# Pin coordinates
  get_attribute [get_cells "inst"] ref_name              ;# Cell type
  get_attribute [get_cells "inst"] location              ;# Cell location

PROCS AVAILABLE (source physical_net_query.tcl):
  sio_net_physical <net>            Full physical summary for a net
  sio_path_physical <from> <to>     RC data for all nets on a timing path
  sio_worst_nets <clk> ?top_n?     Worst-cap nets on failing paths
  sio_pin_distance <pin1> <pin2>   Manhattan distance between two pins

PROCS AVAILABLE (source rc_analysis.tcl + report_nets_rc.tcl):
  report_nets_rc $paths $threshold $outfile
    Extracts per-net RC data for timing paths into CSV

================================================================================
  APPROACH 2: PYTHON STREAMING (when PT not available)
================================================================================

================================================================================
  THE PROBLEM
================================================================================

par_meu SPEF stats (typical_85 corner):
  - Compressed:     3.8 GB
  - Nets:           2,760,510
  - Lines:          ~500M+
  - Full grep:      5-15 minutes per search

8 corners x 11 partitions = 88 SPEF files, ~330 GB total.
You CANNOT load these. You need targeted extraction.

Streams through compressed SPEF in one pass, extracts only matching nets.
Memory-efficient, works on any SPEF size. Use when PT session is not available.

USAGE:

  # Quick: find net names matching a pattern (scans name map only, seconds)
  python3 spef_net_query.py <spef.gz> --name-lookup "dcl1hitsl"

  # Extract full physical data for specific net
  python3 spef_net_query.py <spef.gz> --net "dcl1hitslm404h_0_[0]"

  # Multiple nets from a list file
  python3 spef_net_query.py <spef.gz> --netlist my_nets.txt

  # Pattern match (regex) with CSV output
  python3 spef_net_query.py <spef.gz> --pattern "dcl1hit.*m404h" --csv

  # Find all high-capacitance nets (above 100 fF)
  python3 spef_net_query.py <spef.gz> --cap-above 100.0 --summary

  # One-line summary per net
  python3 spef_net_query.py <spef.gz> --net "mynet" --summary

OUTPUT PER NET:
  - Net name and total capacitance
  - Driver: pin name, cell type, coordinates, metal layer
  - Receivers: pin names, cell types, coordinates, load caps, layers
  - Internal nodes: coordinates and metal layers
  - Resistance segments: count, range, total
  - Capacitance: ground cap, coupling cap, coupling ratio
  - Derived: bounding box, manhattan distance, metal layers used
  - Derived: estimated RC delay (Elmore: 0.5 * R * C)

CSV COLUMNS:
  net, total_cap_fF, total_res_ohm, ground_cap_fF, coupling_cap_fF,
  coupling_ratio_pct, pin_count, res_segments, metal_layers,
  manhattan_dist_um, dx_um, dy_um, rc_delay_ps

PERFORMANCE:
  - Name lookup:     ~1-2 min (scans name map section only)
  - Single net:      ~5-15 min (must scan to find net position)
  - Pattern (10 nets): ~5-15 min (single pass, extracts all matches)
  - Cap threshold:   ~15-30 min (must scan all nets)

  TIP: Name lookup first to verify net names, then extract specific nets.
  TIP: Put multiple nets in --netlist to extract in one pass.
  TIP: If PT is running, use PT instead -- it's instant.

================================================================================
  APPROACH 3: INNOVUS SESSION (escalation to PAR team)
================================================================================

Innovus has the full design DB with routing, placement, metal layers, vias,
congestion, cell utilization -- everything. But it requires:
  - PAR work area access (mpridvas_wa/PAR/)
  - Innovus license (limited)
  - 30-60 min to restore design

When to escalate to Innovus:
  - Deep congestion analysis
  - DRC root cause on specific metal layers
  - Placement optimization queries
  - Full routing topology visualization

PAR contact: Check with P&R team for Innovus session access.

================================================================================
  APPROACH 4: COMMAND-LINE GREP (quick one-off check)
================================================================================

For a one-off quick check when you know the exact net name:

  # Find a net in SPEF (slow but no setup needed)
  zcat <spef.gz> | grep -A 50 "^*D_NET.*mynetname" | head -60

  # Find net in name map (faster - name map is at the top)
  zcat <spef.gz> | grep "mynetname" | head -5

  # Count coupling caps for a net
  zcat <spef.gz> | sed -n '/^*D_NET.*mynet/,/^*END/p' | grep -c " \*"

  # Quick total cap check
  zcat <spef.gz> | grep "^*D_NET.*mynet"

WARNING: These take 5-15 min per query on 3.8GB files.
         Use spef_net_query.py for anything beyond a one-off check.

================================================================================
  APPROACH 5: ADDITIONAL DATA SOURCES (instant, no SPEF parsing)
================================================================================

lib_cell_usage.csv -- Cell inventory (instant, no tool needed):
  Location: sd_layout_cdns archive or PAR area
  Contains: cell names, VT types, cell counts, area
  Use for: VT ratio analysis, cell utilization, area estimates

DEF file -- Placement and pin coordinates (fast, no tool needed):
  Location: <ward>/runs/<par>/n2p_htall_conf4/release/latest/sta_primetime/
  Contains: component placement, pin positions, die area, rows
  Parser: skills/physical/scripts/def_parser.py

Extraction quality report -- DRC and extraction health:
  Location: <ward>/runs/<par>/n2p_htall_conf4/release/latest/sta_primetime/reports/star_pv/
  File: <par>.extract_quality.report
  Contains: total nets, shorts, opens, missing vias

================================================================================
  DECISION TREE: WHICH APPROACH TO USE
================================================================================

  "I need net RC data"
    --> PT running?  YES --> sio_net_physical in PT (instant)
                     NO  --> spef_net_query.py (5-15 min)

  "I need cell placement info"
    --> DEF parser (fast, no tool needed)

  "I need VT ratios / cell counts"
    --> lib_cell_usage.csv (instant, no tool needed)

  "I need extraction DRC status"
    --> extract_quality.report (instant, no tool needed)

  "I need congestion/routing topology"
    --> Innovus (escalation, need PAR team)

================================================================================
  SPEF FILE FORMAT REFERENCE
================================================================================

HEADER:
  *SPEF "IEEE 1481-1999"
  *DESIGN "<partition>"
  *T_UNIT 1.0 NS          <- Time unit
  *C_UNIT 1.0 FF          <- Capacitance unit (femtofarads)
  *R_UNIT 1.0 OHM         <- Resistance unit

NAME MAP:
  *NAME_MAP
  *2760533 ml2dcsnpreqpacketm400h_0__snpreqid[1]
  ...
  Maps compact IDs to full hierarchical net names.

NET SECTION:
  *D_NET *<id> <total_cap>     <- Net ID + total cap in C_UNIT (fF)

  *CONN                         <- Connection section
  *I *<inst_id>:<pin> O *C <x> <y> *D <cell_type> // $lvl=<layer>
                        ^                             ^
                        Driver pin (Output)           Metal layer number

  *I *<inst_id>:<pin> I *C <x> <y> *L <load_cap> *D <cell_type> // $lvl=<layer>
                        ^            ^
                        Receiver     Load capacitance
                        (Input)

  *N *<net_id>:<node> *C <x> <y> // $lvl=<layer>
                                    ^
                                    Internal routing node + metal layer

  *CAP                          <- Capacitance section
  <idx> <node> <value>                  <- Ground cap
  <idx> <node1> <node2> <value>         <- Coupling cap (to neighbor net)

  *RES                          <- Resistance section
  <idx> <node1> <node2> <value>         <- Wire resistance between nodes

  *END                          <- End of net

COORDINATE SYSTEM:
  Coordinates are in microns (um).
  $lvl = metal layer number (1=M0, 2=M1, ... see layer map in script)
  $llx/$lly/$urx/$ury = bounding box of the node/pin

METAL LAYERS (N2P process, 1P20M):
  lvl 1  = M0    (lowest)
  lvl 2  = M1
  lvl 3  = V0    (via between M0-M1)
  lvl 4  = M2
  lvl 5  = V1
  ... alternating metal/via up to:
  lvl 20 = M10   (highest standard metal)
  lvl 51+ = upper redistribution / bump metals

================================================================================
  WHAT DATA CAN YOU GET FROM SPEF
================================================================================

  Data                     How                         Speed
  -----------------------  --------------------------  ----------
  Net total capacitance    D_NET line or PT query      Fast
  Net resistance           Sum RES section             Medium
  Coupling capacitance     Sum coupling CAP entries    Medium
  Metal layers used        $lvl from CONN/N nodes      Medium
  Wire bounding box        Min/max of *C coordinates   Medium
  Manhattan distance       bbox width + height         Medium
  Pin coordinates          *C in CONN section          Medium
  Driver cell type         *D in CONN section          Medium
  Receiver count           Count *I ... I entries      Medium
  Load capacitance         *L in CONN section          Medium
  Estimated RC delay       0.5 * R_total * C_total     Medium
  Via count                Count $lvl that are vias    Medium
  Net-to-net coupling      Coupling CAP entries        Slow
  All nets > cap threshold Scan all D_NET lines        Slow

================================================================================
  TYPICAL SIO USE CASES
================================================================================

1. "Why is this path slow?" -- Check if net has high RC
   python3 spef_net_query.py <spef.gz> --net "<net_from_path>" --summary

2. "Which nets have worst routing?" -- Find high-cap nets
   python3 spef_net_query.py <spef.gz> --cap-above 200 --csv > worst_nets.csv

3. "What layers is this net using?" -- Check metal layer distribution
   python3 spef_net_query.py <spef.gz> --net "<net>" (see metal layers in output)

4. "How far apart are driver and receiver?" -- Manhattan distance
   python3 spef_net_query.py <spef.gz> --net "<net>" --summary

5. "Is there coupling on this net?" -- Coupling ratio
   python3 spef_net_query.py <spef.gz> --net "<net>" (see coupling_ratio)

6. "Compare RC across corners" -- Run on multiple SPEF files
   for corner in cworst_CCworst_125 rcworst_CCworst_125 typical_85; do
     echo "=== $corner ==="
     python3 spef_net_query.py <par>.$corner.spef.gz --net "<net>" --summary
   done

7. "Get all data for nets on a timing path" -- PT + SPEF
   In PT: report_timing -to <endpoint> > path.rpt
   Extract net names from path report
   python3 spef_net_query.py <spef.gz> --netlist path_nets.txt --csv

================================================================================
  SPEF FILE LOCATIONS
================================================================================

In ward (daily model):
  <ward>/runs/<par>/n2p_htall_conf4/release/latest/sta_primetime/<par>.<corner>.spef.gz

In archive:
  /nfs/site/disks/gfc_n2_client_arc_proj_archive/arc/<par>/sta_primetime/<tag>/<par>.<corner>.spef.gz

8 corners:
  cworst_CCworst_125, cworst_CCworst_M40, cworst_CCworst_T_125,
  cworst_CCworst_T_M40, rcworst_CCworst_125, rcworst_CCworst_M40,
  rcworst_CCworst_T_125, typical_85

SEE ALSO
--------
  skills/routing/       -- RC analysis TCL, SPEF explanation
  skills/data_map/      -- SPEF file locations in daily model
  skills/physical/      -- Extraction quality report
  tools/primetime/      -- PT session for interactive SPEF queries

SOURCE: Live SPEF from GFC par_meu typical_85 (WW16B, 2.76M nets, 3.8GB)
================================================================================

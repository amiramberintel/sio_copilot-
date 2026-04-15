================================================================================
  SKILL: routing -- Routing Analysis (Metal, RC, Distance)
================================================================================

TRIGGERS: routing, route, metal, layer, spef, cap, capacitance, resistance,
          rc, net, wire, distance, monster, congestion, layer_promotion

WHAT THIS SKILL DOES:
  - Analyze routing per path: which metals, total wire length, RC
  - Parse SPEF data for net capacitance and resistance
  - Identify monster nets (high fanout, long distance)
  - Check layer promotion opportunities
  - Analyze routing congestion impact on timing

KEY ANALYSIS TYPES:
  1. Net RC Extraction
     - Parse SPEF for cap/res per net segment
     - Compare actual vs estimated RC
     - Flag nets with excessive RC

  2. Layer/Metal Distribution
     - Which metal layers used per path
     - Metal layer vs timing correlation
     - Layer promotion candidates (M3->M4 etc.)

  3. Monster Net Detection
     - Nets with fanout > threshold
     - Nets with wire length > threshold
     - Cross-partition nets

  4. Manhattan Distance
     - sio_manh_dist proc from sio_common.tcl
     - Physical distance between driver/receiver
     - Distance vs timing correlation

TCL PROCS (from sio_common.tcl):
  sio_manh_dist                 Manhattan distance
  sio_mow_tot_dist_from_points  Total distance from path points
  nm_to_um                      Unit conversion helper

PREREQS:
  - SPEF files from extraction
  - PT session for path analysis
  - source sio_common.tcl

SEE ALSO:
  skills/ifc/       -- IFC paths with routing issues
  skills/setup/     -- Setup failures from routing
  tools/primetime/  -- PT routing-aware timing
================================================================================

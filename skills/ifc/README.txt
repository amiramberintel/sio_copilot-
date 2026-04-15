================================================================================
  SKILL: ifc -- Interface Timing (IFC) Analysis and Debug
================================================================================

TRIGGERS: ifc, interface, ifc_family, port, slack, wns, tns, fep, bound,
          failing_endpoints, logic_count, manhattan, tip, mow, buffer_chain

WHAT THIS SKILL DOES:
  - Analyze IFC timing: WNS, TNS, FEP per port/family
  - Debug failing interface paths (logic count, distance, buffering)
  - Check if paths can be bounded (flop-level analysis)
  - Calculate manhattan distance for interface paths
  - Map-of-World (MOW) visualization of timing
  - TIP (Timing Interface Protocol) data extraction
  - Buffer chain analysis along interface paths

TCL LIBRARY: tcl/sio_common.tcl (6058 lines, source in PT shell)
  KEY PROCS:
  -- Path Analysis --
  sio_logic_count_path              Count logic stages in timing path
  sio_logic_count_path_get_max_slack Get max slack for analysis
  sio_manh_dist                     Manhattan distance between 2 points
  sio_mow_tot_dist_from_points      Total dist from path points

  -- Port Analysis --
  get_ports_from_points             Extract ports from path
  sio_mow_get_port_that_drived_by_pin  Port driving a pin
  sio_mow_get_port_that_drive_pin      Port driven by a pin
  get_abutted_port                  Find abutted port pair
  sio_check_abbutted_pins           Validate abutted pins
  check_port_location_outside_bbox  Is port outside bounding box?

  -- Buffer Chain --
  server_buff_chain_server          Analyze buffer chain in PT server
  check_regexs_buffs_invs           Buffer/inverter pattern matching
  sio_inv_buff_delay_to_endpoint_haya  Buffer delay analysis
  sio_mow_get_sio_buffer_data_from_paths  Buffer data from paths

  -- MOW (Map of World) --
  run_sio_mow                       Launch MOW analysis
  sio_mow_get_initial_data          Init MOW data
  sio_mow_report_timing             Report timing in MOW context
  sio_mow_center_of_mass            Center of mass for port cluster

  -- TIP Data --
  sio_mow_tip_data                  Get TIP timing data
  sio_mow_get_tip_data              Extract TIP data
  sio_mow_fix_tip_data              Fix/adjust TIP data

  -- TNS --
  sio_mow_port_tns                  Port-level TNS calculation
  sio_get_tns_for_RFs_pins          TNS for rise/fall pins
  sio_get_tns_for_ebbs_pins         TNS for EBB pins

  -- Bounding Check --
  sio_check_if_can_bound            Can this path be bounded?
  sio_check_if_can_bound_path       Specific path check
  sio_check_if_can_bound_clk_latency  Clock latency bounding

ADDITIONAL TCL: tcl/init-taimor.tcl
  ts_debug_port     Check if flops can be bounded for a port
  ts_check_slack_of_file  Check slack from file list
  ts_get_ex_slack_of_ports  Get external slack of ports

PROC CATALOG: tcl/sio_common_proc_catalog.txt (full organized listing)

PREREQS:
  - PT session loaded with design
  - source tcl/sio_common.tcl in PT shell
  - For MOW: X11 display or file output mode

SEE ALSO:
  skills/clock/         -- Clock paths affecting IFC
  skills/setup/         -- Setup violations on IFC
  skills/hold/          -- Hold violations on IFC
  skills/eco/           -- ECO fixes for IFC violations
  skills/routing/       -- Physical routing affecting IFC timing
  skills/cell_library/  -- Cell legality in IFC paths
  tools/primetime/      -- PT commands for IFC debug
================================================================================

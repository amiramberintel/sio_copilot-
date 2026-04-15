================================================================================
  TOOL: estimate_eco -- Quick What-If ECO Analysis in PT Shell
================================================================================

WHAT:
  PT shell command that estimates slack impact of ECO changes WITHOUT
  actually making the change. READ-ONLY -- safe to run on pt_client server.
  Use this BEFORE assuming ECO gains -- prevents wrong estimates.

CRITICAL RULE:
  estimate_eco reports GBA slack internally, but the DELTA applies to PBA too.
  NEVER use GBA slack values directly -- only use the IMPROVEMENT DELTA.

TYPES OF ESTIMATE:

  1. SIZE_CELL -- Can we upsize or Vt-swap a cell?
     estimate_eco -type size_cell -sort_by slack -nosplit [get_cells <cell>]

  2. INSERT_BUFFER -- Would adding a buffer on a net help?
     estimate_eco -type insert_buffer -sort_by slack -nosplit \
       -lib_cells {<buf_cell_list>} [get_pins <pin>]

  3. VT_SWAP -- Can we swap to a different voltage threshold?
     estimate_eco -sort_by slack -nosplit -rise \
       -lib_cells [get_lib_cells <wildcard_pattern>] [get_cells <cell>]

COMMAND SYNTAX:

  --- SIZE_CELL (upsize candidates) ---
  estimate_eco -type size_cell \
    -sort_by slack \
    -nosplit \
    [get_cells <cell_instance>]

  Via pt_client:
    sg soc -c "pt_client.pl -m <corner> -c 'estimate_eco -type size_cell \
      -sort_by slack -nosplit [get_cells <cell>]'"

  --- INSERT_BUFFER (buffer insertion candidates) ---
  estimate_eco -type insert_buffer \
    -sort_by slack \
    -nosplit \
    -lib_cells {BUFFD4BWP156HNPPN3P48CPDULVT BUFFD8BWP156HNPPN3P48CPDULVT} \
    [get_pins <pin>]

  Via pt_client:
    sg soc -c "pt_client.pl -m <corner> -c 'estimate_eco -type insert_buffer \
      -sort_by slack -nosplit \
      -lib_cells {BUFFD4BWP156HNPPN3P48CPDULVT BUFFD8BWP156HNPPN3P48CPDULVT} \
      [get_pins <pin>]'"

  --- SETUP vs HOLD ---
  For setup corners (func.max_*):  estimate_eco -max ...
  For hold corners (func.min_*):   estimate_eco -min ...

  --- RISE vs FALL ---
  Add -rise or -fall to check specific transitions.
  Check BOTH -- worst may differ between rise and fall.

READING THE OUTPUT:

  Output is a table of alternatives sorted by slack:
    Cell/LibCell            Slack_Before  Slack_After  Delta
    *current*               -103.0        -103.0       0.0     <-- baseline
    BUFFD8BWP...DULVT       -103.0        -99.1        +3.9    <-- improvement
    BUFFD4BWP...DULVT       -103.0        -100.2       +2.8

  KEY: If *current* = BEST (first row), NO ECO helps this cell.
  If alternative is better: delta = real ECO potential.

USEFUL TCL PROCS (from pt_shell_command.log):

  # Estimate all VT swap options for a cell
  proc estimate_vt_swap {cell} {
      global scenario
      if {[regexp min_ $scenario]} {
          estimate_eco -min -nosplit -rise -sort_by slack \
            -lib_cells [get_lib_cells [regsub {/i0m.*([0-9][0-9]x[0-9])} \
              [regsub {_[^_]*vt_} [get_object_name \
                [get_attribute [get_cell $cell] lib_cell]] {_*_}] \
              {/i0m*\1}]] $cell
      } else {
          estimate_eco -max -nosplit -rise -sort_by slack \
            -lib_cells [get_lib_cells [regsub {/i0m.*([0-9][0-9]x[0-9])} \
              [regsub {_[^_]*vt_} [get_object_name \
                [get_attribute [get_cell $cell] lib_cell]] {_*_}] \
              {/i0m*\1}]] $cell
      }
  }

  # Estimate VT swap for ALL cells in a timing path
  proc estimate_vt_swap_of_path {tp} {
      foreach_in_collection cell [append_to_collection {} \
        [get_attribute $tp points.object.cell] -unique] {
          redirect -variable eco_results {estimate_vt_swap $cell}
      }
  }

  # Estimate buffer insertion on a pin
  proc estimate_buffer_insertion {pin} {
      global scenario
      set buff_list {BUFFD4BWP156HNPPN3P48CPDULVT BUFFD8BWP156HNPPN3P48CPDULVT}
      if {[regexp min_ $scenario]} {
          estimate_eco -type insert_buffer -nosplit $pin \
            -lib_cells $buff_list -sort_by slack -min
      } else {
          estimate_eco -type insert_buffer -nosplit $pin \
            -lib_cells $buff_list -sort_by slack -max
      }
  }

WORKFLOW -- VERIFY ECO GAINS BEFORE CLAIMING THEM:

  WRONG: "this cell is LVT, swap to ULVT saves ~8ps" (guessing)
  RIGHT:
    1. Get worst path: report_timing -through ... -max_paths 1
    2. For each cell: estimate_eco -type size_cell [get_cells ...]
    3. If *current* is best: NO ECO helps, move on
    4. If alternative is better: record actual delta
    5. Also try: estimate_eco -type insert_buffer on long nets
    6. Sum verified deltas = real ECO potential

REAL EXAMPLE (dcl1rddatam408h BUS, WW15):
  DISCOVERY: All 18 top SFFs (810/1024 paths) are fully optimized.
  estimate_eco -type size_cell shows *current = BEST for every cell.
  Only insert_buffer on 1 long net gave +3.9ps (marginal).
  Conclusion: data-path ECO = ~0ps gain. Useful skew push REQUIRED.

GOTCHAS:
  - estimate_eco is READ-ONLY -- safe on pt_client server
  - Run on SAME corner as your analysis (func.max_high for setup)
  - For cross-partition paths: only ECO cells in YOUR partition
  - DULVTLL/LVT cells on critical paths may not have room to swap
    (most GFC Client A0 critical paths already at DULVT)
  - Buffer insertion estimates assume ideal placement -- real gain
    may be less due to routing

PREREQS:
  - PT session loaded (via pt_client or local pt_shell)
  - Know the cell/pin to estimate

SEE ALSO:
  skills/eco/           -- Full ECO workflows
  tools/pt_eco/         -- Full PT-ECO flow
  tools/primetime/      -- PT shell commands
  skills/cell_library/  -- Available cells for swap
  skills/reporting/templates/eco_impact.txt -- Report template
================================================================================

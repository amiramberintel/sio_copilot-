================================================================================
  SKILL: cell_library -- Cell Library Analysis and Dont-Use Management
================================================================================

TRIGGERS: cell, dont_use, illegal, library, vt, elvt, lvtll, pnnp, OD_flavor

WHAT THIS SKILL DOES:
  - Identify illegal/dont-use cells per stage (STA, ECO, signoff)
  - Track VT restrictions: ELVT, LVTLL, PNNP OD flavor rules
  - Catalog cells in a design region or path
  - Check if ECO-inserted cells comply with library restrictions

AVAILABLE DATA:
  knowledge/illegal_cells_dont_use.txt
    -- Full dont_use list from Timor Sabek
    -- Format: <lib_pattern> <cell_name> <reason>
    -- Reasons include:
       elvt_svt_cells_are_not_allowed
       lvtll_cells_are_not_allowed
       pnnp_OD_flavor_is_not_allowed
       pnnp_OD_flavor_is_not_allowed_elvt_svt_cells_are_not_allowed
       pnnp_OD_flavor_is_not_allowed_lvtll_cells_are_not_allowed
    -- Library pattern: tcbn02p_*

TCL PROCS (from sio_common.tcl):
  cells_cataloging             Catalog all cells in a path/region
  sio_write_all_cells          Write full cell list
  sio_write_all_cells_clusters Cluster analysis of cells

PREREQS:
  - PT session loaded with design
  - source sio_common.tcl in PT shell

HOW TO CHECK IF A CELL IS ILLEGAL:
  1. grep cell name in knowledge/illegal_cells_dont_use.txt
  2. If found, check reason column
  3. Common fix: swap to allowed VT variant (LVT, ULVT, ULVTLL)

SEE ALSO:
  skills/eco/       -- ECO may insert cells; must check dont_use
  skills/ifc/       -- IFC paths may contain illegal cells
  tools/primetime/  -- Cell checking in PT shell
================================================================================

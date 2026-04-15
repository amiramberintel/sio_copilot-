================================================================================
  SKILL: eco -- Engineering Change Order (ECO) Workflows
================================================================================

TRIGGERS: eco, pt_eco, pc_eco, fix, buffer, size, swap, insert, remove,
          unfixable, override, sio_ovrs

WHAT THIS SKILL DOES:
  - Plan and execute PT-ECO / PC-ECO flows
  - Track ECO impact on timing (WNS/TNS/FEP delta)
  - Manage SIO overrides per partition
  - Identify unfixable violations
  - Validate ECO cell legality against dont_use list

AVAILABLE TCL:
  tcl/par_mlc_sio_ovrs.tcl            -- SIO overrides for par_mlc partition
    (Template for other partitions -- customize per par_*)

  PROCS from sio_common.tcl:
  pteco_check_meu_meu                 -- Check PTECO results for par_meu
  sio_mow_pceco_read_unfixable        -- Read unfixable from PCECO
  sio_pceco_check_location            -- Check PCECO cell locations

ECO FLOW (via flow_manager):
  /nfs/site/disks/ucde/tools/tool_utils/apr_eco/latest/scripts/run_auto_pt_eco.py
    --ref_ward <path>
    --flow <flow_name>
    --tcl <eco_tcl_file>
    --nbc "SLES15&&500G&&16C"
    --nbq "/c2dg/BE_BigCore/gfc/sd"
    --nbp "sc8_express"

ECO VALIDATION CHECKLIST:
  [ ] Check cells in dont_use list (skills/cell_library/)
  [ ] Verify timing improvement (before/after WNS)
  [ ] Check no new hold violations introduced
  [ ] Verify DRC clean (no new routing violations)
  [ ] Check FEV equivalence

PREREQS:
  - PT session loaded
  - ECO permissions on work area
  - source sio_common.tcl for PTECO procs

SEE ALSO:
  skills/flow_manager/  -- Run ECO flows end-to-end
  skills/cell_library/  -- Dont_use cell checking
  skills/ifc/           -- IFC violations targeted by ECO
  tools/pt_eco/         -- PT-ECO tool details
  tools/estimate_eco/   -- Estimate ECO impact before running
================================================================================

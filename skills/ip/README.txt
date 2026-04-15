================================================================================
  SKILL: ip -- IP Block Integration and Timing
================================================================================

TRIGGERS: ip, ip_block, macro, hard_macro, soft_macro, memory, sram, rom,
          analog, pll, io, phy, serdes, interface_ip, ip_timing, liberty,
          .lib, ip_model, etm, ilm

WHAT THIS SKILL DOES:
  - Manage IP timing models (ETM, ILM, liberty .lib)
  - Track IP versions and model updates across builds
  - Debug timing at IP boundaries (IP port timing)
  - Validate IP constraints vs top-level constraints
  - Check IP dont_use / cell restrictions
  - Compare IP model versions between builds
  - Handle hard macro placement impact on timing
  - Track which IPs are in which partitions

IP TYPES:
  Hard Macros:   SRAM, ROM, analog, PLL, PHY, SerDes
  Soft Macros:   Synthesized IP blocks
  Timing Models: ETM (Extracted), ILM (Interface Logic Model)
  Liberty:       .lib files for IP characterization

KEY QUESTIONS THIS SKILL ANSWERS:
  - What IP version is used in this build?
  - Did the IP model change between builds?
  - Is the IP boundary timing clean?
  - Which partitions contain this IP?
  - What are the IP port constraints?
  - Is the liberty model correct for this corner?

PREREQS:
  - IP model paths (from build or archive)
  - Liberty files for corners
  - PT session with IP models loaded

SEE ALSO:
  skills/ifc/             -- IFC paths often cross IP boundaries
  skills/cell_library/    -- IP cells in dont_use checks
  skills/model_comparison/ -- IP model version tracking
  skills/bu_model/        -- Build includes IP models
  config/paths.cfg        -- IP model paths
================================================================================

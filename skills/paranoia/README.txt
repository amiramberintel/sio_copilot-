================================================================================
  SKILL: paranoia -- Paranoia Checks and Sanity Verification
================================================================================

TRIGGERS: paranoia, sanity, check, verify, audit, double_check, crosscheck,
          consistency, golden, baseline, trust, confidence

WHAT THIS SKILL DOES:
  - Run sanity checks on timing data before trusting results
  - Cross-verify between tools (PT vs Tempus, ICC2 vs Innovus)
  - Validate ECO results: did the fix actually land? Did it help?
  - Check for common data corruption / stale session issues
  - Compare report numbers against golden baseline
  - Verify constraint consistency (SDC vs actual clocks)
  - Check for missing corners / incomplete analysis
  - Audit: are all partitions using same build tag?

TYPICAL PARANOIA CHECKS:
  [ ] Is the PT session from today's build or stale?
  [ ] Do WNS numbers match between IFC report and PT query?
  [ ] Are all corners loaded (no missing corner)?
  [ ] Are constraints consistent across corners?
  [ ] Did ECO cells actually get placed (not just scripted)?
  [ ] Are dont_use cells sneaking in after ECO?
  [ ] Is the SPEF from the right extraction run?
  [ ] Do port names match between partitions (no rename)?
  [ ] Is the clock period what we expect?
  [ ] Are derates applied correctly per corner?

PREREQS:
  - Access to current build data
  - PT session or reports to verify

SEE ALSO:
  skills/daily_monitoring/ -- Daily checks overlap with paranoia
  skills/model_comparison/ -- Cross-build verification
  skills/cell_library/     -- Dont_use audit after ECO
  config/corners.cfg       -- Expected corners to verify against
================================================================================

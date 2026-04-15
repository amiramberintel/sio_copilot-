================================================================================
  CROSS-PARTITION DEBUG WITH pt_client — README
  Quick overview of what's inside the full cookbook
================================================================================

  WHAT IS THIS COOKBOOK?
  ─────────────────────
  A step-by-step guide to debug cross-partition timing paths using
  pt_client.pl — a tool that sends PrimeTime commands to a live server
  and returns results in seconds, instead of opening a PT session (20+ min).

  Full cookbook: cross_partition_debug_with_pt_client_cookbook.txt
  View colored: bash cross_partition_debug_with_pt_client_cookbook.sh

  WHAT'S INSIDE (by stage):
  ──────────────────────────
  ★ GOLDEN RULE      Always verify which model is loaded (-debug flag)

  STAGE 0 — PATH ANALYSIS (instant, 10 seconds):
    Step 0.1        Get full path report with physical, cap, transition
    Step 0.2        Identify partitions — look for "unplaced" port crossings
    Step 0.3-0.5    Extract delays, distances, classify path severity
    Step 0.6        Check ULVT upgrade candidates (LVT→ULVT = 3-8ps/cell)
    Step 0.7        Check SP/EP FF locations — does placement make sense?
                    → Red flags: FF >500μm from port, port not between FFs
    Step 0.8        Check spec budget BEFORE moving any FF
                    → Moving FF changes clock latency → shifts budget!
                    → Uses formula: margin = period - uncertainty + skew - specs
                    → See also: spec_status_cookbook.txt

  STAGE 1 — CLOCK BALANCE (10 seconds):
    Step 1.1-1.2    Get clock latency for both SP and EP FFs via pt_client

  STAGE 2 — NEIGHBOR STAGES (20 seconds — biggest win!):
    Step 2.1        Check stage BEFORE source FF → retiming margin?
    Step 2.2        Check stage AFTER endpoint FF → push logic forward?
    Step 2.3        D-pin input path check for multi-bit FFs
                    → D-pin slack LIMITS how far you can move a FF!
                    → MUST check before any TIP placement change

  STAGE 3 — BUS CHECK (10 seconds):
    Step 3.1-3.2    Is it a bus? All bits failing or just some?
    Step 3.3        Source FF fanout → FF duplication candidate?

  STAGE 4 — PORT SPEC / BUDGET (20 seconds):
    Step 4.1-4.2    Check both sides of port (live via pt_client)
                    → If one side has margin → shift spec (Technique 8)

  STAGE 5 — MULTI-CORNER ANALYSIS (1 min — NEW!):
    Step 5.1        Check all setup corners (high, nom, low, med)
    Step 5.2        Check hold corners (min_low, min_nom)
    Step 5.3        Check with crosstalk (CCworst) — SI impact
                    → A fix that helps max_high might hurt max_low!
                    → PREVENTS creating new violations in other corners

  STAGE 6 — MODEL COMPARISON (30 sec — NEW!):
    Step 6.1        Compare latest vs previous build — did TIP/RCO help?
    Step 6.2        Track daily slack trend across work weeks

  FULL WORKFLOW     10-minute step-by-step walkthrough (minute by minute)
  REAL EXAMPLE      RSMOClearVM803H complete debug session
  LIMITATIONS       What pt_client CANNOT do (read-only, no ECO)

  SPEEDUP: Full debug goes from 2-4 HOURS → 5-10 MINUTES (20-50x faster!)

  RELATED COOKBOOKS:
  ──────────────────
  pt_client_cookbook.txt                  Tool reference, setup, aliases
  spec_status_cookbook.txt                Budget balance & clock latency
  cross_partition_debug_playbook.txt     Original playbook (no pt_client)
  TIP_tp_creation_cookbook.txt            Creating TIP files for FF placement

================================================================================

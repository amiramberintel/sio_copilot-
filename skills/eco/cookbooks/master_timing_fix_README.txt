================================================================================
  MASTER TIMING FIX COOKBOOK — README & USAGE GUIDE
================================================================================

  File:     /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/master_timing_fix_cookbook.txt
  Purpose:  One-stop cookbook for ALL timing fix techniques (26 total)
            organized into 8 selectable modes. Interactive workflow.
  Created:  2026-03-16


================================================================================
  WHAT IS THIS?
================================================================================

  The master cookbook unifies ALL timing fix approaches into a single
  interactive tool. Instead of reading 14 separate cookbooks, you say
  "run master" and the copilot walks you through:

    1. Pick which FIX MODE to use (or combine modes)
    2. Point to your work area (WA)
    3. Select which signals to analyze
    4. Pick output directory for reports/scripts
    5. Copilot runs the full analysis autonomously
    6. You get colored reports + ICC2 fix scripts


================================================================================
  THE 8 MODES — WHAT THEY CONTAIN
================================================================================

  Mode │ Name         │ Techniques │ Who does the work?
  ─────┼──────────────┼────────────┼────────────────────────────────
    1  │ ECO          │ C1-C7 (7)  │ PO in ICC2 (you)
    2  │ ECO+CLOCK    │ +E1-E3(10) │ PO in ICC2 (you, clock tree)
    3  │ SIO2PO       │ D1-D7 (7)  │ SIO team via HSD
    4  │ PHYSICAL     │ 1+2+3+G(20)│ PO + SIO (all physical)
    5  │ RTL          │ B1-B4 (4)  │ RTL designer via RTL4BE HSD
    6  │ TIP          │ F1-F3 (3)  │ SIO creates .tp files
    7  │ SPEC         │ A1-A3 (3)  │ Spec owner / you
    8  │ ALL          │ 26 total   │ Everyone

  ❌ Pipeline insertion is NEVER available (adds latency to design)


  ────────────────────────────────────────────────────────────────────
  MODE 7 — SPEC (timing budget, no physical change)
  Who: Spec owner / you
  ────────────────────────────────────────────────────────────────────

  A1 — Spec Rebalance
       What:  Adjust the IO delay budget split between source and dest
              partitions in the timing spec XML. If source uses 164ps of
              143 budget but dest only uses 17ps of 25, move 10ps from
              dest to source (153/15 split).
       Gain:  FREE — no physical change, just budget accounting
       Risk:  NONE (but verify dest still meets after giving away budget)
       When:  Always try first — cheapest fix available
       How:   Edit userSpec in timing spec XML file
       Note:  Only helps if one side is under budget and the other is over

  A2 — Update Timing Specs
       What:  Fix missing, wrong, or stale specs. Some signals may have
              incorrect clock domains, wrong period, or missing specs
              entirely. Fixing the spec can remove false violations.
       Gain:  Varies — can eliminate entire signal family if spec was wrong
       Risk:  LOW (but must verify spec is actually wrong, not the design)
       When:  When par_status shows unexpected clock groups or spec names
       How:   Update spec XML, coordinate with spec owner

  A3 — Synthesis Directives
       What:  Add dont_touch, set_max_delay, group_path, or other
              synthesis constraints to guide the tool. Can prevent
              unwanted optimizations or force specific timing targets.
       Gain:  Guides tool — indirect improvement
       Risk:  NONE (directives don't change physical design)
       When:  When synthesis is producing suboptimal results for a path
       How:   Add constraints to synthesis scripts / SDC files


  ────────────────────────────────────────────────────────────────────
  MODE 5 — RTL (RTL designer via RTL4BE HSD)
  Who: RTL designer — file RTL4BE HSD, they implement
  ────────────────────────────────────────────────────────────────────

  B1 — Retiming
       What:  Move combinational logic across an existing FF boundary.
              If Stage A has too much logic and Stage B has slack,
              move some gates from A to B. The FF stays, logic shifts.
       Gain:  10-40ps
       Risk:  MED (RTL designer must verify functional equivalence)
       When:  When neighbor stage has significant positive slack
       How:   File RTL4BE HSD with timing path + neighbor slack data
       Check: pt_client report_timing -from <endpoint_FF> to see next
              stage slack. Need >20ps positive slack on neighbor.

  B2 — Reduce Logic Depth
       What:  Simplify the combinational cone between two FFs. RTL
              designer restructures logic to use fewer gate levels
              (e.g., flatten a priority encoder, merge conditions).
       Gain:  10-60ps
       Risk:  MED-HIGH (requires RTL design understanding)
       When:  When data delay is very high relative to clock period
       How:   File RTL4BE HSD showing the long combo path
       Note:  Most effective fix but requires RTL team bandwidth

  B3 — Pre-compute
       What:  Shift computation to an earlier clock cycle. If a value
              is known one cycle early, compute it then and register
              the result. Reduces critical path in the current cycle.

              Example — without pre-compute (today):
                Cycle N: Input A → MUX + Adder + Compare → FF
                         ══════════ 200ps (too long!) ══════════

              With pre-compute:
                Cycle N-1: Input A → MUX + Adder → FF_new  (120ps, has slack)
                Cycle N:   FF_new → Compare only → FF      (80ps, fixed!)

              The heavy work moves to cycle N-1 because Input A was
              already available then. Result still arrives in cycle N
              — NO added latency (unlike pipeline insertion ❌).

       Gain:  15-40ps
       Risk:  MED (must verify architectural correctness)
       When:  When inputs to the logic are available earlier than needed.
              VERY RARE — requires RTL designer to confirm the input
              is stable one cycle early. Most paths don't qualify.
       How:   File RTL4BE HSD with timing + architecture analysis
       Note:  This is rare in practice. Unlike retiming (B1) which
              just moves existing logic, pre-compute requires deep
              knowledge of the architecture to confirm early availability.

  B4 — FF Duplication (RTL)
       What:  Duplicate a register in RTL source code to split high
              fanout. Unlike physical FF dup (D6), this creates a
              separate register in RTL that synthesis can place freely.
       Gain:  10-25ps
       Risk:  LOW-MED (simple RTL change, must add to formal equiv)
       When:  When source FF has high fanout (>20 loads)
       How:   File RTL4BE HSD with fanout report



  ────────────────────────────────────────────────────────────────────
  MODE 1 — ECO (PO works in ICC2, data path only)
  Who: PO (you) — direct ICC2 commands
  ────────────────────────────────────────────────────────────────────

  C1 — size_cell (upsize)
       What:  Increase cell drive strength: D2→D4→D8→D12→D16.
              Stronger driver = faster transition = less delay.
       Gain:  2-5ps per cell
       Risk:  LOW
       When:  When a cell in the path has a weak drive (D2, D4) and
              the output transition time is high (>20ps)
       How:   size_cell <inst> <new_ref>
       Check: Verify target cell is not in illegal.txt!
       Note:  Most common ECO fix. Start here.

  C2 — size_cell (downsize)
       What:  Decrease drive strength to fix hold violations or
              reduce power. Opposite of C1.
       Gain:  Varies (hold fix, not setup)
       Risk:  LOW
       When:  When fixing hold violations or reducing power on
              non-critical paths
       How:   size_cell <inst> <smaller_ref>

  C3 — Vt Swap
       What:  Change cell threshold voltage: LVT→ULVT (faster, more
              power) or ULVT→LVT (slower, less power). ULVT cells
              switch faster but leak more current.
       Gain:  2-3ps per cell
       Risk:  LOW (but check power impact)
       When:  When all cells in path are already at max drive but
              still too slow. Vt swap + upsize = maximum speed.
       How:   size_cell <inst> <same_size_different_vt_ref>
       Note:  ULVT is fastest available. Check if cell exists in ULVT.

  C4 — insert_buffer
       What:  Add a buffer (BUFFD8, BUFFD12) on a long wire segment
              (>100μm). The buffer reshapes the signal, reducing RC
              delay on the remaining wire.
       Gain:  5-15ps
       Risk:  LOW-MED (buffer must be placed legally, check DRC)
       When:  When timing report shows a long net with high wire delay
       How:   insert_buffer <net> <buf_ref>
       Check: Verify buffer cell is not in illegal.txt!
       Note:  Apply AFTER port relocation (D4) decisions — buffer
              placement depends on final wire topology

  C5 — remove_buffer
       What:  Remove unnecessary buffers (SR2BFY, small BUFFs) that
              were inserted by synthesis but add delay. If the net
              is short enough, direct connection is faster.
       Gain:  3-8ps
       Risk:  LOW
       When:  When timing report shows a buffer with very short
              input+output nets (both <20μm)
       How:   remove_buffer <inst>

  C6 — move_objects
       What:  Physically move a data cell to a better location.
              Can dramatically reduce wire delay but may cause DRC
              violations or congestion issues.
       Gain:  10-40ps
       Risk:  HIGH (DRC, congestion, may affect other paths)
       When:  When a cell is placed far from its connections
       How:   move_objects <inst> -x <x> -y <y>
       Note:  Run DRC check after move. High risk — use as last resort.

  C7 — route_eco
       What:  Re-route nets after making ECO changes (size_cell,
              insert_buffer, etc.). Required cleanup step.
       Gain:  N/A (cleanup, not a standalone fix)
       Risk:  LOW
       When:  Always run after any ECO change
       How:   route_eco ; check_routes


  ────────────────────────────────────────────────────────────────────
  MODE 3 — SIO2PO (file HSD, SIO/PO team executes)
  Who: SIO team — file SIO2PO HSD, they implement in PO
  ────────────────────────────────────────────────────────────────────

  D1 — Bound Source FF
       What:  Constrain the source FF to be placed closer to the
              output port. SIO adds a placement bound so the FF
              can't drift far from the partition boundary.
       Gain:  10-30ps
       Risk:  LOW-MED (may affect other paths from same FF)
       When:  When source partition budget >> spec (FF is far from port)
       How:   File SIO2PO HSD with instance name + port name

  D2 — Bound Receiver FF
       What:  Constrain the destination FF to be placed closer to
              the input port. Same concept as D1 but on dest side.
       Gain:  15-35ps
       Risk:  MED (endpoint FF may be in MBIT bank — check!)
       When:  When dest partition budget >> spec (FF is far from port)
       How:   File SIO2PO HSD with instance name + port name
       Note:  If FF is in MBIT bank, may need G1 (demerge) first

  D3 — Push Clock
       What:  Adjust clock tree to give earlier clock arrival at
              the endpoint FF. Increases useful skew (clock helps
              the data path by borrowing time).
       Gain:  15-25ps
       Risk:  LOW-MED (SIO/CTS team handles complexity)
       When:  When clock skew is unfavorable or neutral
       How:   File SIO2PO HSD requesting clock push at endpoint
       Note:  Already favorable skew? Push clock gives MORE.

  D4 — Port Relocation
       What:  Move the partition boundary port to a different Y
              (vertical) position. Reduces wire distance between
              source FF and dest FF through the port.
       Gain:  5-15ps
       Risk:  MED (affects all signals through that port)
       When:  When manhattan Y distance is dominant (>70% of total)
       How:   File SIO2PO HSD with current port coords + suggested Y
       Note:  Coordinates: DBU/1000 = μm

  D5 — Port Duplication
       What:  Split a high-fanout port into 2+ copies. Each copy
              serves fewer loads, reducing wire delay and fanout.
       Gain:  20-40ps
       Risk:  MED (adds ports, increases boundary complexity)
       When:  When port has >10 fanout on dest side
       How:   File SIO2PO HSD with fanout report

  D6 — FF Duplication (Physical)
       What:  Clone a FF in the physical design to split fanout.
              Unlike B4 (RTL dup), this is a physical-only change
              in ICC2. The cloned FF gets the same clock/data.
       Gain:  10-25ps
       Risk:  MED (must maintain equivalence, add to formal)
       When:  When source FF drives many loads across partition
       How:   File SIO2PO HSD or do in ICC2 directly

  D7 — Buffer Insert at Port
       What:  SIO adds or removes a repeater buffer at the partition
              boundary port. Different from C4 — this is SIO's buffer
              in the port area, not your buffer inside the partition.
       Gain:  5-15ps
       Risk:  LOW
       When:  When port-to-FF wire is long and SIO manages the port
       How:   File SIO2PO HSD requesting port buffer change


  ────────────────────────────────────────────────────────────────────
  MODE 2 — ECO+CLOCK (Mode 1 + clock tree changes)
  Who: PO (you) — direct ICC2 commands on clock tree
  ────────────────────────────────────────────────────────────────────

  Includes ALL of Mode 1 (C1-C7), PLUS:

  E1 — Useful Skew
       What:  Adjust the local clock delay on a FF to borrow time
              from the next stage. If the next stage has slack, slow
              down its clock (or speed up this FF's clock).
       Gain:  10-25ps
       Risk:  LOW-MED (must verify next stage doesn't violate)
       When:  When neighbor stage has positive slack (>15ps)
       How:   Adjust clock insertion delay in ICC2 CTS
       Check: Verify next stage slack with pt_client before applying

  E2 — CTS Buffer Sizing
       What:  Upsize clock tree buffers (CKND, CKBUF, ZCTSINV) to
              reduce clock latency to the endpoint FF.
       Gain:  4-8ps
       Risk:  LOW-MED (affects all FFs on that clock branch)
       When:  When clock latency is high relative to other FFs
       How:   size_cell on clock tree buffer cells
       Note:  Affects ALL endpoints on that clock branch — check
              that improving one doesn't break others

  E3 — Clock Buffer Insertion
       What:  Add a new buffer in the clock tree to reduce RC delay
              on a long clock wire. Similar to C4 but for clock nets.
       Gain:  5-15ps
       Risk:  MED-HIGH (clock tree is sensitive — affects many FFs)
       When:  When clock wire to endpoint is very long
       How:   insert_buffer on clock net
       Note:  HIGH risk — clock changes affect many endpoints.
              Only do this if E1/E2 are insufficient.


  ────────────────────────────────────────────────────────────────────
  MODE 6 — TIP (SIO creates .tp topology plan files)
  Who: SIO team — creates .tp files, build system integrates
  ────────────────────────────────────────────────────────────────────

  F1 — TIP Buffer Insertion
       What:  SIO creates a .tp file that adds a buffer in the data
              path. The buffer is inserted by the build system during
              synthesis, giving the tool better placement guidance.
       Gain:  10-40ps
       Risk:  LOW (build system validates)
       When:  When the fix needs to survive re-synthesis (not just ECO)
       How:   SIO creates .tp file → goes into TIP/ directory
       Note:  TIP fixes persist across builds. ECO fixes (C4) don't.

  F2 — TIP Cell Insertion
       What:  SIO creates a .tp file that adds a specific RTL cell
              (not just a buffer) at a chosen location. More powerful
              than F1 — can add logic restructuring cells.
       Gain:  20-60ps
       Risk:  MED (must verify functional equivalence)
       When:  When a structural change is needed that persists
       How:   SIO creates .tp file with cell specification

  F3 — TIP Bound (Placement)
       What:  SIO creates a .tp file that constrains placement of
              specific cells. Forces the tool to place cells near
              a target location (port, FF, etc.).
       Gain:  10-30ps
       Risk:  LOW-MED
       When:  When cells keep drifting to bad locations across builds
       How:   SIO creates .tp file with placement constraints
       Note:  Unlike D1/D2 (one-time SIO2PO), TIP bounds persist


  ────────────────────────────────────────────────────────────────────
  MODE 4 — PHYSICAL (Mode 1+2+3 + MBIT/FF structure)
  Who: PO + SIO — combines all physical techniques
  ────────────────────────────────────────────────────────────────────

  Includes ALL of Mode 1 (C1-C7) + Mode 2 (E1-E3) + Mode 3 (D1-D7), PLUS:

  G1 — MBIT Demerge
       What:  Split a multi-bit FF bank (MB4, MB8) into smaller banks
              (MB2) or single FFs. MBIT banks constrain placement —
              all bits must stay together. Demerging frees individual
              bits to be placed optimally.
       Gain:  Enabler — doesn't directly improve timing but enables
              D2 (bound receiver), G3 (FF placement fix)
       Risk:  MED (changes physical structure, may affect other bits)
       When:  When endpoint FF is in a large MBIT bank (MB4+) and
              the bank placement is far from the port
       How:   File SIO2PO HSD requesting demerge of specific bank
       Note:  Must demerge BEFORE applying D2 or G3 on that FF

  G2 — MBIT Regroup
       What:  Regroup FFs into a different MBIT bank configuration.
              Instead of demerging (splitting), regroup moves the
              target bit into a different bank with better placement.
       Gain:  Better placement (indirect timing improvement)
       Risk:  MED
       When:  When demerge is too risky but bank placement is poor
       How:   File SIO2PO HSD requesting regroup

  G3 — FF Placement Fix
       What:  Physically move an FF to a better location (closer to
              port or closer to its data source). Most aggressive
              physical fix — directly reduces wire delay.
       Gain:  15-40ps
       Risk:  MED-HIGH (may cause DRC, congestion, affect neighbors)
       When:  As last resort when other techniques are insufficient
       How:   move_objects or placement constraint
       Check: If FF is in MBIT bank, demerge (G1) first!
       Note:  Check D-pin connectivity after move — don't break
              data connections to other loads


================================================================================
  HOW TO USE — STEP BY STEP
================================================================================

  OPTION A: INTERACTIVE (copilot asks you questions)
  ──────────────────────────────────────────────────

    Just say:  "run master"

    Copilot will:
      → Show you ALL 8 modes with full technique lists
      → Ask which mode (you can combine: "mode 1+3", "mode 4+5")
      → Ask for WA path
      → Ask which signals (all / worst N / partition / specific)
      → Ask output directory
      → Run full analysis
      → Generate reports + TCL scripts


  OPTION B: ONE-LINER (skip the questions)
  ──────────────────────────────────────────────────

    You can give everything in one line:

    "run master mode 1 worst 5"
      → ECO mode, current WA, worst 5 signals, default output dir

    "run master mode 4+5 par_fe brdispnotsignedm107h"
      → PHYSICAL+RTL, current WA, specific signal, default dir

    "run master mode 8 all worse than -60ps"
      → ALL modes, current WA, signals with WNS ≤ -60ps, default dir

    "run master mode 1+3 par_meu dcl1dataeccissecm408h output ww12_2"
      → ECO+SIO2PO, par_meu signal, output to ww12_2/


  OPTION C: WITH CONSTRAINTS (copilot auto-excludes)
  ──────────────────────────────────────────────────

    "run master, no RTL no TIP"
      → Copilot proposes mode 4+7 (everything except RTL/TIP)
      → You confirm or adjust

    "run master, ECO only, no clock changes"
      → Copilot proposes mode 1 (ECO without clock)
      → You confirm or adjust


================================================================================
  WHAT YOU GET — OUTPUT FILES
================================================================================

  For each analyzed signal, copilot generates:

  ┌──────────────────────────────────────┬───────────────────────────────┐
  │ File                                 │ What it is                    │
  ├──────────────────────────────────────┼───────────────────────────────┤
  │ <signal>_eco_report.txt              │ FULL analysis (12 sections,   │
  │                                      │ colored ANSI, all data)       │
  ├──────────────────────────────────────┼───────────────────────────────┤
  │ <signal>_eco_report_short.txt        │ SHORT summary (fix table +    │
  │                                      │ closure verdict, colored)     │
  ├──────────────────────────────────────┼───────────────────────────────┤
  │ <signal>_<src_partition>_fixes.tcl   │ ICC2 TCL for source PO        │
  │                                      │ (only if mode includes ECO)   │
  ├──────────────────────────────────────┼───────────────────────────────┤
  │ <signal>_<dst_partition>_fixes.tcl   │ ICC2 TCL for dest PO          │
  │                                      │ (only if mode includes ECO)   │
  └──────────────────────────────────────┴───────────────────────────────┘

  Color scheme (baked-in ANSI, no yellow → magenta):
    RED     = worst delays, violations, gaps
    MAGENTA = warnings, MSID-side fixes, MED risk
    CYAN    = info headers, FE-side fixes, section titles
    GREEN   = legal checks ✓, LOW risk, improvements
    DIM     = separators, metadata
    WHITE   = section headers, totals


================================================================================
  COMBINING MODES — EXAMPLES
================================================================================

  "mode 1"      → ECO only (doing ICC2 manual fixes)
  "mode 2"      → ECO + Clock (including clock tree changes)
  "mode 3"      → SIO2PO only (filing HSDs for SIO team)
  "mode 4"      → Full PHYSICAL (ECO + Clock + SIO + MBIT/FF)
  "mode 1+5"    → ECO + RTL (ICC2 fixes + ask RTL team)
  "mode 1+3"    → ECO + SIO2PO (ICC2 fixes + file SIO HSDs)
  "mode 3+6"    → SIO2PO + TIP (SIO HSDs + topology plans)
  "mode 4+5"    → Physical + RTL (everything physical + RTL team)
  "mode 7+4"    → Spec + Physical (start with spec, then physical)
  "mode 4+7"    → Physical + Spec (everything except RTL/TIP)
  "mode 8"      → ALL 26 techniques


================================================================================
  WHICH MODE SHOULD I USE?
================================================================================

  If you're doing...                              → Use mode...
  ─────────────────────────────────────────────────────────────
  Quick ICC2 manual fix during build               → Mode 1 (ECO)
  ICC2 fix but also want to move clock             → Mode 2 (ECO+CLOCK)
  Filing SIO HSD for port/FF changes               → Mode 3 (SIO2PO)
  Everything physical (last resort before RTL)     → Mode 4 (PHYSICAL)
  Need RTL team to restructure logic               → Mode 5 (RTL)
  TIP topology plan changes                         → Mode 6 (TIP)
  Spec budget adjustment / synthesis constraints   → Mode 7 (SPEC)
  Explore ALL options, no constraints              → Mode 8 (ALL)

  After last synthesis (no more RTL changes)?      → Mode 4+7
  Before synthesis (can still change RTL)?         → Mode 8
  Just want to understand the problem?             → Mode 7+1 (check spec+ECO)


================================================================================
  PREREQUISITES
================================================================================

  Before running master, make sure you have:

  1. A daily WA path (the sta_pt/func.max_high.T_85.typical directory)
     → This is where pt_client reads timing data from

  2. par_*_status.txt files (optional but recommended)
     → Copilot uses these to find signals and WNS values
     → Without them, you must specify signal names manually

  3. Access to pt_client_server (on the build machine)
     → Copilot calls pt_client to get worst paths, fanout, slack

  4. illegal.txt in the build area
     → For checking if proposed fix cells are legal


================================================================================
  RELATED COOKBOOKS
================================================================================

  The master cookbook references these for deep-dive details:

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/path_analysis_procedure.txt
      → Full path analysis steps (coordinate conversion, illegal cells, fix table)

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/pt_client_cookbook.txt
      → pt_client command reference (report_timing, get_cells, get_nets)

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/cross_partition_debug_with_pt_client_cookbook.txt
      → Cross-partition debug flow (multi-partition path tracing)

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/icc2_eco_fix_cookbook.txt
      → ICC2 ECO fix script generation (size_cell, insert_buffer, reports)

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/TIP_tp_creation_cookbook.txt
      → TIP .tp file creation (topology plans for SIO)

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/sio_risk_assessment_cookbook.txt
      → 7-step risk assessment (IFC, HSD, TIP, illegal, risk category)

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/daily_update_cookbook.txt
      → Daily WA update workflow (par_status, diff, daily report)

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/par_status_cookbook.txt
      → par_status tool (IFC x HSD x TIP cross-reference)

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/par_status_diff_cookbook.txt
      → Diff between builds (regression/improvement tracking)

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/rtl_model_compare_cookbook.txt
      → Compare RTL models between builds

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/spec_status_cookbook.txt
      → Spec status reference (timing budgets, XML specs)

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/cross_partition_debug_playbook.txt
      → Cross-partition debug playbook (step-by-step debug)

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/clean_home_dir_cookbook.txt
      → Clean home directory (disk space management)

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/master_timing_fix_README.txt
      → THIS FILE — usage guide for master cookbook

  /nfs/site/disks/sunger_wa/fc_data/my_learns/cookbooks/cross_partition_debug_with_pt_client_README.txt
      → README for cross-partition pt_client debug cookbook


================================================================================
  CHANGELOG
================================================================================

  2026-03-16  Created README for master_timing_fix_cookbook.txt

================================================================================

================================================================================
  SKILL: pt_reference -- PrimeTime Command Reference & User Guide
================================================================================

TRIGGERS: pt command, pt syntax, report_timing, primetime help, pt manual,
          how to run, pt_shell, get_attribute, timing command, pt options,
          pt error, pt variable, pt invocation, snps tcl

DESCRIPTION
-----------
Complete Synopsys PrimeTime documentation converted to searchable text.
Use this when you need exact command syntax, options, error explanations,
or PT variable settings.

Version: PrimeTime X-2025.06-SP3

================================================================================
  CONTENTS
================================================================================

docs/pt_cmd.txt              137,154 lines  Full command reference (985 commands)
docs/pt_vars.txt              36,273 lines  All PT variables
docs/pt_err.txt              170,609 lines  Error/warning message reference
docs/ptug.txt                 65,878 lines  PT user guide (timing analysis)
docs/PrimeTimeUserGuide.txt   54,050 lines  PT user guide (alternate version)
docs/snps_tcl.txt              5,421 lines  Synopsys TCL extensions
docs/pt_invocation.txt           365 lines  PT startup/invocation options

knowledge/pt_command_index.txt   985 lines  Command name -> page number index
knowledge/sio_pt_quick_reference.txt         SIO-focused quick reference

Total: ~470,000 lines of PT documentation

================================================================================
  HOW TO USE
================================================================================

1. QUICK REFERENCE (most common SIO commands):
   Read: knowledge/sio_pt_quick_reference.txt

2. LOOK UP A SPECIFIC COMMAND (full syntax + options + examples):
   grep -A 80 "^     report_timing$" docs/pt_cmd.txt | head -100

3. FIND COMMAND BY LINE NUMBER (from index):
   grep "report_timing" knowledge/pt_command_index.txt
   -> 1911 report_timing
   sed -n '1911,2000p' docs/pt_cmd.txt    ;# Read the full entry

4. SEARCH FOR A KEYWORD ACROSS ALL DOCS:
   grep -i "pba_mode" docs/pt_cmd.txt | head -20

5. LOOK UP A PT ERROR MESSAGE:
   grep "UITE-.*" docs/pt_err.txt | head -20
   grep "PTE-003" docs/pt_err.txt

6. FIND A PT VARIABLE:
   grep "timing_report" docs/pt_vars.txt | head -10

7. IN PT SESSION (built-in help):
   pt_shell> man report_timing        ;# Full manual page
   pt_shell> apropos timing           ;# Search by keyword
   pt_shell> help report_timing       ;# Quick syntax

================================================================================
  SIO MOST-USED COMMANDS (quick lookup)
================================================================================

  Command                Line in pt_cmd.txt    Purpose
  ---------------------- --------------------   ----------------------------
  report_timing          1911                   Timing path report
  report_clock_timing    1813                   Clock latency/skew
  report_constraints     1838                   Constraint violations
  get_timing_paths       724                    Get path objects
  get_nets               665                    Find nets
  get_cells              578                    Find cells
  get_pins               702                    Find pins
  get_clocks             595                    Find clocks
  get_attribute          549                    Query any attribute
  set_false_path         2177                   False path constraint
  set_multicycle_path    2235                   Multicycle constraint
  size_cell              2338                   ECO cell sizing
  insert_buffer          793                    ECO buffer insertion
  write_changes          2534                   Export ECO changes
  update_timing          2494                   Re-run STA
  report_net             1886                   Net connectivity detail
  all_fanin              53                     Trace logic cone
  all_fanout             57                     Trace fanout cone
  report_analysis_coverage 1757                 Timing coverage check

================================================================================
  EXAMPLE: LOOK UP report_timing FULL SYNTAX
================================================================================

  Command:
    grep -A 100 "report_timing$" docs/pt_cmd.txt | head -120

  Output (abbreviated):
    report_timing
      [-from from_list]
      [-rise_from rise_from_list]
      [-fall_from fall_from_list]
      [-to to_list]
      [-rise_to rise_to_list]
      [-fall_to fall_to_list]
      [-through through_list]
      [-rise_through rise_through_list]
      [-fall_through fall_through_list]
      [-exclude exclude_list]
      [-max_paths max_paths]
      [-nworst nworst_paths_per_endpoint]
      [-delay_type delay_type]
      [-slack_lesser_than slack_value]
      [-slack_greater_than slack_value]
      [-group group_name]
      [-pba_mode pba_mode]
      [-nosplit]
      [-input_pins]
      [-nets]
      [-transition_time]
      [-capacitance]
      [-significant_digits digits]
      [-path_type full|full_clock|full_clock_expanded|short|end|summary]
      ...

================================================================================
  SOURCE
================================================================================

  Copied from: PAR copilot knowledge base
    /nfs/site/disks/mpridvas_wa/PAR/par_fe_GFC_ww16_2/copilot/central/vendors/synopsys/pt/

  Original: Synopsys PrimeTime X-2025.06-SP3 documentation (PDF converted to text)

  SEE ALSO:
    skills/routing/tcl/          -- SIO-specific PT TCL procs
    skills/spef_query/tcl/       -- Physical query procs for PT
    skills/eco/                  -- ECO flow using PT
    skills/ifc/cookbooks/        -- Cross-partition PT client usage
================================================================================

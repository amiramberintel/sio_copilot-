================================================================================
  SKILL: innovus_reference -- Cadence Innovus Command Reference & User Guide
================================================================================

TRIGGERS: innovus command, innovus syntax, innovus help, innovus manual,
          dbGet, reportRoute, reportDesign, placeDesign, routeDesign,
          verify_drc, report_congestion, cadence command, stylus command,
          innovus attribute, innovus error, electromigration, em check

DESCRIPTION
-----------
Complete Cadence Innovus documentation converted to searchable text.
Use this when you need exact command syntax, options, database object
attributes, EM checks, or routing/placement commands.

Versions: Innovus 25.11 (July 2025) + Stylus Common UI 23.16

================================================================================
  CONTENTS
================================================================================

docs/InnovusTCRcom.txt                366,462 lines  Full Text Command Reference v25.11
docs/TCRcom.txt                       268,887 lines  Stylus Common UI TCR v23.16
docs/UGcom.txt                         96,940 lines  Innovus User Guide
docs/DBcom.txt                         59,981 lines  Database Objects Reference
docs/EMRcom.txt                        57,407 lines  Electromigration Reference
docs/innovus_common_ui_user_guide.txt  93,859 lines  Stylus Common UI User Guide
docs/innovus_common_ui_database_objects.txt 48,061 lines  DB Objects (Stylus)

knowledge/innovus_command_index.txt     1,869 lines  Command -> page number index
knowledge/commands.md                     424 lines  Curated command summary
knowledge/attributes.md                   350 lines  Curated attributes summary

Total: ~992,000 lines of Innovus documentation

================================================================================
  HOW TO USE
================================================================================

1. LOOK UP A SPECIFIC COMMAND (full syntax + options + examples):
   grep -A 80 "^  reportRoute$" docs/TCRcom.txt | head -100
   grep -A 80 "reportRoute" docs/InnovusTCRcom.txt | head -100

2. FIND COMMAND IN INDEX:
   grep "report_net" knowledge/innovus_command_index.txt
   -> 374 report_net_wires

3. SEARCH FOR A KEYWORD:
   grep -i "congestion" docs/TCRcom.txt | head -20
   grep -i "dbGet.*net" docs/InnovusTCRcom.txt | head -20

4. LOOK UP DATABASE OBJECT ATTRIBUTES:
   grep -A 10 "net.*wire_length\|net.*total_cap" docs/DBcom.txt | head -20
   grep -i "inst.*location\|cell.*area" docs/DBcom.txt | head -20

5. LOOK UP EM RULES:
   grep -A 20 "check_ac_limit\|check_dc_limit" docs/EMRcom.txt | head -40

6. CURATED QUICK REFERENCE:
   Read: knowledge/commands.md     (most common commands)
   Read: knowledge/attributes.md   (most common attributes)

7. IN INNOVUS SESSION (built-in help):
   innovus> man reportRoute         ;# Full manual page
   innovus> help reportRoute        ;# Quick syntax

================================================================================
  KEY COMMANDS FOR SIO PHYSICAL QUERIES
================================================================================

  Command              Doc File         Purpose
  -------------------  ---------------  ----------------------------------
  dbGet                InnovusTCRcom    Query any database object/attribute
  reportRoute          TCRcom           Routing summary / detail
  reportDesign         TCRcom           Design physical stats
  reportCongestion     TCRcom           Congestion analysis
  verify_drc           TCRcom           DRC violation check
  reportGateCount      TCRcom           Cell utilization
  placeDesign          TCRcom           Placement
  routeDesign          TCRcom           Global/detail routing
  get_nets             TCRcom           Find nets (Stylus)
  get_cells            TCRcom           Find cells (Stylus)
  get_pins             TCRcom           Find pins (Stylus)
  get_property         TCRcom           Get object property
  report_net_wires     TCRcom           Net wire detail
  report_timing        TCRcom           Timing analysis
  check_ac_limit       EMRcom           AC electromigration
  check_dc_limit       EMRcom           DC electromigration

================================================================================
  INNOVUS vs STYLUS COMMANDS
================================================================================

Innovus has two command interfaces:
  1. LEGACY (dbGet/dbSet) -- direct database access, very fast
     dbGet top.nets.name                    ;# All net names
     dbGet [dbGet -p top.nets.name mynet].numWires
     dbGet top.insts.pt                     ;# All instance locations

  2. STYLUS (get_*/set_*/report_*) -- TCL collection-based, same as PT
     get_nets mynet
     get_attribute [get_nets mynet] wire_length
     report_net -connections [get_nets mynet]

Both work in Innovus -stylus mode (which is what GFC PAR uses).
Stylus commands are documented in TCRcom.txt.
Legacy dbGet is in InnovusTCRcom.txt.

================================================================================
  EXAMPLE: LOOK UP dbGet SYNTAX
================================================================================

  grep -A 60 "^dbGet$" docs/InnovusTCRcom.txt | head -70

  dbGet
    dbGet objId [attrName] [-p] [-e] [-v value]
    ...
    -p    : Return full pointer (not just value)
    -e    : Return empty string on error (not error)
    -v    : Filter by value

  Examples:
    dbGet top.nets.name                      ;# All net names
    dbGet [dbGet -p top.nets.name clk].wires ;# Wires of clk net
    dbGet top.insts.cell.name                ;# All cell ref names
    dbGet top.numInsts                       ;# Instance count

================================================================================
  SOURCE
================================================================================

  Copied from: PAR copilot knowledge base
    /nfs/site/disks/mpridvas_wa/PAR/par_fe_GFC_ww16_2/copilot/central/vendors/cadence/innovus/

  Original: Cadence Innovus 25.11 + Stylus Common UI 23.16 documentation

  SEE ALSO:
    skills/innovus_query/        -- On-demand Innovus session launcher
    skills/spef_query/           -- SPEF extraction (alternative to Innovus)
    skills/physical/             -- Physical quality reports
    skills/pt_reference/         -- PrimeTime command reference
================================================================================

# PT Server Query Cookbook

## Overview

Query a running PrimeTime server to run pt_shell commands (report_timing, get_attribute, etc.)
without needing to load a full PT session locally.

## Setup

### PT Client Script
```
/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl
```

### Aliases File
```
/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/aliases_for_pt_client
```

To load aliases in csh/tcsh:
```csh
source /nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/aliases_for_pt_client
```

## Basic Usage

### Direct command (no aliases needed)
```bash
/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl \
  -m <model_name> \
  -c "<pt_shell_command>"
```

### Using aliases (after sourcing)
```bash
gfcn2clienta0bmhigt085_b pwd
gfcn2clienta0bmhigt085_b "report_timing -max_paths 3 -nosplit"
```

## Model Name Convention

Model names follow the pattern:
```
<version>_gfcn2clienta0_<flow>_<corner>
```

| Component | Options | Description |
|-----------|---------|-------------|
| `version` | `modelb`, `modela`, `latest`, `prev` | Which model revision |
| `flow` | `bu_prp`, `fcl` | BU PRP or FCL flow |
| `corner` | e.g., `func.max_high.T_85.typical` | Timing corner |

### Examples
```
modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical
latest_gfcn2clienta0_bu_prp_func.max_nom.T_85.typical
modela_gfcn2clienta0_fcl_func.max_low.T_85.typical
modelb_gfcn2clienta0_bu_prp_fresh.min_fast.F_125.rcworst_CCworst
```

## Alias Name Convention

Alias names follow the pattern:
```
gfcn2clienta0<flow_short><corner_short>_<version>
```

| Component | Example | Meaning |
|-----------|---------|---------|
| `bm` | `gfcn2clienta0bm...` | bu_prp func.max |
| `bn` | `gfcn2clienta0bn...` | bu_prp fresh.min |
| `lm` | `gfcn2clienta0lm...` | fcl func.max |
| `_b` suffix | `..._b` | modelb |
| `_a` suffix | `..._a` | modela |
| `0` suffix | `...0` | prev |
| no suffix | `...` | latest |

### Common Aliases
| Alias | Corner |
|-------|--------|
| `gfcn2clienta0bmhigt085_b` | modelb bu_prp func.max_high.T_85.typical |
| `gfcn2clienta0bmlowt085_b` | modelb bu_prp func.max_low.T_85.typical |
| `gfcn2clienta0bmnomt085_b` | modelb bu_prp func.max_nom.T_85.typical |
| `gfcn2clienta0bmmedt085_b` | modelb bu_prp func.max_med.T_85.typical |
| `gfcn2clienta0bmffff125rct_b` | modelb bu_prp func.max_fast.F_125.rcworst_CCworst_T |
| `gfcn2clienta0bnhvqf125rcw_b` | modelb bu_prp fresh.min_hvqk.F_125.rcworst_CCworst |
| `gfcn2clienta0lmhigt085_b` | modelb fcl func.max_high.T_85.typical |

## Checking Server Status

To see which PT servers are online, open the live status page (updates every 5 min):

**Browser (Windows):**
```
file://sc8-samba.sc.intel.com/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_track_system/report.html
```

**From Linux (raw HTML):**
```bash
cat /nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_track_system/report.html
```

The status page shows:
- **OFFLINE** vs **UP and UPDATED** count
- Per-model table with: die, modelA/modelB, flow type (bu_prp/fcl), model path, last update time, link owner
- Green = online, Red = offline, Yellow = recently updated (be patient)

### Quick check from command line

```bash
# Count online vs offline
grep -oP 'bgcolor="(#66ff33|red)"' /nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_track_system/report.html | sort | uniq -c
```

### Check cron config (are servers enabled?)

All server entries are in the cron config. Lines starting with `#` are disabled:

```bash
grep "gfcn2clienta0" /nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_server_c2dgbcptserver_cron.cfg
```

Format: `<die>,<flow>,<corner>,<model>,<config>,<server>,<port>`

If all lines are commented out (`#`), no servers are online.

## Corner Naming and Delay Type

The corner name determines the analysis delay type (`$::ivar(sta,delay_type)`):

| Corner prefix | Delay type | Analysis | PT command |
|---------------|-----------|----------|------------|
| `func.max_*` | `max` | Setup analysis | `report_timing -delay_type max` |
| `func.min_*` | `min` | Hold analysis | `report_timing -delay_type min` |
| `fresh.min_*` | `min` | Hold analysis | `report_timing -delay_type min` |

**Important:** When querying a `min` corner, use `-delay_type min` to get meaningful hold results. Using `-delay_type max` on a hold corner will show inflated slack due to path margins.

### Examples
```bash
# Setup analysis on max_high corner
pt_client.pl -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_timing -delay_type max -to <endpoint> -nosplit"

# Hold analysis on min_nom corner
pt_client.pl -m modelb_gfcn2clienta0_bu_prp_func.min_nom.T_85.typical \
  -c "report_timing -delay_type min -to <endpoint> -nosplit"
```

## Common PT Commands

### Report Timing (worst paths)
```bash
pt_client.pl -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_timing -max_paths 5 -nosplit"
```

### Report Timing for Specific Endpoint
```bash
pt_client.pl -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_timing -to <endpoint_pin> -nosplit"
```

### Report Timing Through a Pin
```bash
pt_client.pl -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_timing -through <pin_name> -max_paths 3 -nosplit"
```

### Report Timing with Nets and Input Pins
```bash
pt_client.pl -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_timing -through <pin_name> -nosplit -nets -input_pins -significant_digits 4"
```

### Report Delay Calculation (per-net RC and delay)
```bash
pt_client.pl -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_delay_calculation -from <driver_pin> -to <load_pin> -nosplit"
```

Output includes: net delay (rise/fall), total capacitance, total resistance, slew degradation.

### Get Clock Period
```bash
pt_client.pl -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "get_attribute [get_clocks mclk_fe] period"
```

### Check Design Name
```bash
pt_client.pl -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "current_design"
```

### Working Directory
```bash
pt_client.pl -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "pwd"
```

### Report Constraints
```bash
pt_client.pl -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_constraint -all_violators -nosplit -max_paths 10"
```

### Report Clock Tree to Register
```bash
pt_client.pl -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_timing -to [get_pins <register>/CP] -path_type full_clock -nosplit"
```

This shows the full clock network path including ICG cells, CKN/CKB buffers, and
global clock drivers. Useful for identifying clock gating and clock tree depth.

### Check ICG Enable Timing
```bash
pt_client.pl -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_timing -to [get_pins <icg_cell>/E] -nosplit"
```

ICG cells (CKLNQ, CKLHQ) have an enable pin (E) that must arrive before the
clock edge. Tight enable timing pushes the ICG output clock late.

### Check Register Fanout (All Destinations)
```bash
pt_client.pl -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_timing -from [get_cells <register>] -max_paths 5 -nosplit"
```

Shows all destination endpoints from a register. Useful for checking if a register
only feeds partition outputs (relocation candidate) or has local sinks.

## PT Client Gotchas

### Carriage Returns in Output
PT client output includes `\r` (carriage returns). When parsing in bash scripts,
always strip with `tr -d '\r'`:
```bash
result=$("$PT_CLIENT" -m "$MODEL" -c "..." 2>&1 | grep -v "^-I-" | tail -1 | tr -d '\r')
```

### Curly Brace Filters Don't Work
`get_pins -filter {direction==out}` fails via pt_client.pl. Use `filter_collection` instead:
```bash
# BAD:
pt_client.pl -m $MODEL -c "get_pins -filter {direction==out} -of [get_nets $NET]"

# GOOD:
pt_client.pl -m $MODEL -c "get_object_name [filter_collection [get_pins -of [get_nets $NET]] \"direction==out\"]"
```

### Source Command is Forbidden
Cannot use `source <file>` on PT server. All commands must be self-contained.

### Complex Multi-Line TCL
`foreach_in_collection` with `puts` doesn't work reliably via pt_client. Keep commands
to single-line queries or use semicolons for simple chains.

### Unsupported Flags
- `get_timing_paths` does NOT support `-quiet` flag
- `all_fanout` needs `-trace_arcs all` to trace through ILM/partition boundaries

## Tips

- Always use `-nosplit` in report commands for cleaner output
- The server already has the session loaded — no need to `read_verilog` or `link_design`
- Multiple commands can be chained with semicolons: `-c "cmd1; cmd2"`
- Output goes to stdout — pipe/redirect as needed
- Use full hierarchical pin names when querying specific paths
- Use `-nets -input_pins -significant_digits 4` for detailed path tracing
- **MBIT registers** use `D1`/`D2`/`Q1`/`Q2` etc. — NOT `D`/`Q`. The suffix maps to the bit position in the MBIT packing.

## Finding Available Models

List all available model names:
```bash
grep "^alias.*gfcn2clienta0" /nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/aliases_for_pt_client \
  | sed 's/.*-m //' | sed 's/ .*//' | sort -u
```

List all alias names:
```bash
grep "^alias.*gfcn2clienta0" /nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/aliases_for_pt_client \
  | awk '{print $2}'  | sort -u
```

## Debugging Unconstrained Ports

When a port shows as unconstrained, use these commands to investigate:

### Check if pin has timing arcs
```bash
# Check for timing arcs from/to the pin
pt_client.pl -m $MODEL -c "get_timing_arcs -from [get_pins <pin>]"
pt_client.pl -m $MODEL -c "get_timing_arcs -to [get_pins <pin>]"
```

### Check what's connected to the pin
```bash
# All pins on the same net
pt_client.pl -m $MODEL -c "get_object_name [get_pins -of [get_nets -of [get_pins <pin>] -segments]]"

# Fanout from pin
pt_client.pl -m $MODEL -c "all_fanout -from <pin> -flat -endpoints_only -trace_arcs all"
```

### Report timing through the pin
```bash
# Shows path group "(none)" and "Path is unconstrained" if no constraint exists
pt_client.pl -m $MODEL -c "report_timing -through <pin> -nosplit -max_paths 1"
```

### Common root causes for unconstrained ports
1. **No fanout** — Pin connects to partition boundary but has no internal load
   (destination register optimized away during synthesis)
2. **Scan-only clocking** — Startpoint clocked by scan clock, no functional clock
3. **Missing constraints** — No `set_input_delay`/`set_output_delay` on the port

## Understanding Library Setup Time

To see how the library setup time value in `report_timing` is calculated:

```bash
# Note: direction is clock_pin -> data_pin (related_pin -> constrained_pin)
pt_client.pl -m $MODEL \
  -c "report_delay_calculation -from <cell>/CP -to <cell>/D"
```

This shows the liberty lookup table interpolation:
- **X axis**: `related_pin_transition` (clock slew at CP)
- **Y axis**: `constrained_pin_transition` (data slew at D)
- **Z value**: Setup constraint time

For MBIT cells, use the specific data pin (D1, D2, etc.):
```bash
pt_client.pl -m $MODEL \
  -c "report_delay_calculation -from <mbit_cell>/CP -to <mbit_cell>/D1"
```

**Important**: The arc direction is `CP → D` (not `D → CP`). Using `D → CP` returns
"No arcs between those pins".

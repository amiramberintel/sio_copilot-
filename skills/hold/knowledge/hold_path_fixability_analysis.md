# Hold Path Fixability Analysis Cookbook

## Goal

Given a hold-violating endpoint, determine whether the hold violation is fixable
by checking the **setup slack at each point** along the hold path across multiple corners.
If a point already has a setup violation, adding delay there to fix hold will worsen setup.

## Scripts

| Script | Purpose |
|--------|---------|
| `hold_analysis.sh` | Hold/setup slack table across 8 corners |
| `hold_analysis_with_fixes.sh` | Same + delay cell fix recommendation using buffer DB |

Script location: `/nfs/site/disks/gilkeren_wa/copilot/scripts/`

## Quick Run

### Basic analysis (table only)
```bash
$stod/copilot/scripts/hold_analysis.sh <endpoint_pin>
```

### With fix recommendation
```bash
$stod/copilot/scripts/hold_analysis_with_fixes.sh <endpoint_pin> <buffer_db_csv>
```

Example:
```bash
$stod/copilot/scripts/hold_analysis_with_fixes.sh \
  "icore0/par_meu/rsintprf_arrays/.../wbeudatabank0m805l_1_[29]" \
  /nfs/site/disks/gilkeren_wa/copilot/buffer_cell_database_all_corners.csv
```

## Standard Output Format

The script produces a header, slack table, and (with_fixes version) fix recommendation:

```
Startpoint: <full startpoint name> (<clock>, <edge>)
Endpoint:   <full endpoint name> (<clock>, <edge>)
Hold slack (min_nom): -121.5ps
Launch clock latency (max_high): 100.2ps    <- RED if < 80ps
Capture clock latency (max_high): 111.3ps   <- RED if > 90ps

DATA PATH          | MAX HV  | MAX MED | MAX NOM | MAX LOW | MIN LOW  | MIN NOM  | MIN FAST | MIN FAST COLD
-----------------------------------------------------------------------------------------------------------
.../startpoint/Q   | +150.4 MET | +153.5 MET | ... | ... | -123.8 VIOL | -121.5 VIOL | ...
...
.../endpoint/D1    | +94.1 MET  | +93.0 MET  | ... | ... | -123.8 VIOL | -121.5 VIOL | ...
```

### Header Fields
- **Startpoint / Endpoint**: From hold path at min_nom corner
- **Hold slack (min_nom)**: Worst hold slack at the endpoint
- **Launch clock latency (max_high)**: Clock network delay to startpoint (RED if < 80ps — low latency means less hold margin)
- **Capture clock latency (max_high)**: Clock network delay to endpoint (RED if > 90ps)

### Highlighting
- **Bold green**: Best (most positive) slack value per setup column
- Launch clock latency: RED if **< 80ps** (contributes to hold issues)
- Capture clock latency: RED if **> 90ps**

---

## Fix Recommendation (hold_analysis_with_fixes.sh)

### How It Works

1. **Finds worst hold across ALL hold corners** (min_low, min_nom, min_fast, min_fast_cold)
2. **Finds best insertion point** — the data path **input** pin with highest setup margin
   (most room for delay). Output pins (Z, ZN, Q, QN, Y, etc., including MBIT variants
   like Q1-Q8) are excluded since delay cells are inserted at cell inputs, not outputs.
3. **Checks buffer delay vs slack PER CORNER** — both hold and setup:
   - Hold: `buffer_delay[corner] >= |hold_violation[corner]|` for ALL min corners
   - Setup: `buffer_delay[corner] <= setup_slack[corner]` for ALL max corners
4. **Recommends the smallest fix** — cell with lowest positive hold margin (minimal setup impact)
5. Shows **FIXABLE** (green) or **UNFIXABLE** (red) verdict

### Cell Selection Rules
- **LVT only** (no ULVT) — to avoid leakage concerns
- **Delay cells** (DELA through DELG) and **buffer cells** (BUFF, CKB, CKN)
- Buffer cell list filtered to **drive strength 1-4** for display
- Best single cell: lowest positive hold margin that fixes ALL corners (**★** marker, green)
- 2-cell combos: sorted by lowest hold margin first

### Per-Corner Validation (Critical)

The script validates fix viability at **each corner independently**:
- A delay cell has different delay at each PVT corner
- Example: DELE LVT = 157.6ps at min_nom but only 62.2ps at min_fast
- Setup cost also varies: DELE = 101.9ps at max_med but 232.5ps at max_low
- A fix that passes at one corner may fail at another

**Previous bug (fixed):** Checking only min_nom for hold and only max_med for setup
led to recommending cells that broke setup at max_low or failed hold at min_fast.

### Output Sections

```
DELAY CELL FIX RECOMMENDATION (LVT only)
═══════════════════════════════════════
 Worst hold violation: -123.8ps (min_low)      <- worst across ALL hold corners
 Hold slacks at insertion point:                <- per-corner hold at best pin
   min_low: -123.8ps, min_nom: -121.5ps, min_fast: -97.7ps, min_fast_cold: -80.6ps

 Best insertion point (highest setup margin):
   Pin: .../Q7
   Setup margin: +150.4ps (worst across all max corners)

 LVT DELAY CELLS:        <- per-corner delays (hold + setup columns)
 LVT BUFFER CELLS:       <- drive 1-4 only, delay > 5ps

 SINGLE CELL OPTIONS:    <- ★ marks recommended cell (green)
 TWO-CELL COMBINATIONS:  <- sorted by lowest hold margin
 NEAR-MISS COMBOS:       <- shown only when no valid combo exists

 RECOMMENDATION: FIXABLE / UNFIXABLE   <- green/red
   Option A (single cell): 1x DELB...
   Option B (2-cell): 1x BUF... + 1x DEL...
```

### Buffer Cell Database

Location: `/nfs/site/disks/gilkeren_wa/copilot/buffer_cell_database_all_corners.csv`

Generated by: `buffer_cell_database.tcl` (run inside PT per corner)
Merged by: `merge_buffer_database.sh`

Contains: ref_name, func, type, vt_class, drive_strength, instance_count, + avg delay per corner

---

## Setup Path Investigation Workflow

When investigating a setup-violating path through a partition output port:

### Step 1: Report timing through the port
```bash
$PT -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_timing -through [get_pins <partition_output_port>] -nosplit"
```

### Step 2: Check previous stage slack
Query the timing arriving at the startpoint register's data pin:
```bash
# For MBIT registers, use D1/D2/etc (NOT D)
$PT -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_timing -to [get_pins <startpoint_register>/D1] -nosplit"
```

**Important:** MBIT cells use `D1`, `D2`, etc. — NOT `D`.

### Step 3: Check fanout from startpoint register
See if the register only feeds the partition output or has local sinks:
```bash
$PT -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_timing -from [get_cells <startpoint_register>] -max_paths 5 -nosplit"
```

If all fanout goes to the same partition output → register relocation candidate.

### Step 4: Check clock tree and clock gating
Query the clock tree to the startpoint register:
```bash
$PT -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_timing -to [get_pins <startpoint_register>/CP] -path_type full_clock -nosplit"
```

Then check the ICG enable timing:
```bash
$PT -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_timing -to [get_pins <icg_cell>/E] -nosplit"
```

### Step 5: Assess fix options

| Condition | Fix |
|-----------|-----|
| Prev stage has large slack + all fanout crosses partition | **Move register** closer to partition boundary |
| Long buffer chain to partition output | **Promote net to upper metals** to reduce RC and buffers |
| Launch clock much later than capture | **Clock skew** — check ICG enable, clock tree balancing |
| ICG enable path is tight | **Speed up ICG enable** — reduce buffer stages |
| Deep logic in receiving partition | Receiving partition needs logic optimization |

### Register Relocation Criteria
A register is a good candidate for relocation when:
1. **Previous stage has large positive slack** (e.g., +115ps) — budget to absorb extra wire delay
2. **All fanout goes to partition output** — no local sinks that would be hurt by moving
3. **Single fanin to D pin** — simple relocation, no convergence issues
4. **Long buffer chain** between Q and partition boundary — indicates register is far from boundary

---

## Prerequisites

- PT server access via `pt_client.pl`
- Know which corners to check (setup and hold corners)
- Know the endpoint to analyze
- For fix recommendation: buffer_cell_database_all_corners.csv

### PT Client

```bash
PT="/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl"
```

### Corner Naming → Delay Type

- `func.max_*` or `fresh.max_*` → setup analysis → `report_timing -delay_type max`
- `func.min_*` or `fresh.min_*` → hold analysis → `report_timing -delay_type min`

### Model Naming

```
modelb_gfcn2clienta0_bu_prp_<corner_name>
```

Example: `modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical`

---

## Corners Checked

### Hold Corners (for fix validation)
| Tag | Corner | Buffer DB Column |
|-----|--------|------------------|
| min_low | func.min_low.T_85.typical | func.min_low |
| min_nom | func.min_nom.T_85.typical | func.min_nom |
| min_fast | fresh.min_fast.F_125.rcworst_CCworst | fresh.min_fast.F_125 |
| min_fast_cold | fresh.min_fast_cold.F_M40.rcworst_CCworst | fresh.min_fast_cold |

### Setup Corners (for fix validation)
| Tag | Corner | Buffer DB Column |
|-----|--------|------------------|
| max_hv | func.max_high.T_85.typical | func.max_high |
| max_med | func.max_med.T_85.typical | func.max_med |
| max_nom | func.max_nom.T_85.typical | func.max_nom |
| max_low | func.max_low.T_85.typical | func.max_low |

---

## How to Interpret Results

### Fixability Check

For each pin along the hold path:
- **Setup MET + Hold VIOLATED** → Delay can be added here (setup margin is the budget)
- **Setup VIOLATED + Hold VIOLATED** → Cannot add delay here — would worsen setup
- **Large setup margin jump** between adjacent pins (e.g., +11 → +166) means different
  worst setup paths fan out at that point

### Clock Latency Analysis

Compare clock latencies across corners:
- Hold violations are often driven by **endpoint clock latency growth** at hold corners
- The EP-SP skew difference between setup and hold corners shows the adverse skew swing
- **Launch latency < 80ps**: Low launch latency reduces hold margin (data arrives early)
- **ICG enable slack tight**: Late ICG enable pushes launch clock late, hurting setup on cross-partition paths

---

## XML Startpoint Bottleneck Analysis

### Goal

Identify the **top common startpoints** from the official XML timing summary and check
their **prev path slack** — the setup slack arriving at the data input pin. Startpoints
that are already setup-violated on their input become bottlenecks that propagate timing
problems to many downstream endpoints.

### XML File Locations

```
# Official XML (regular, ~190K paths):
runs/core_client/n2p_htall_conf4/sta_pt/<corner>/reports/core_client.<corner>_timing_summary.xml.filtered

# Nworst XML (~3M paths):
runs/core_client/n2p_htall_conf4/sta_pt/<corner>/reports/core_client.<corner>_timing_summary.nworst.xml.filtered
```

### Step 1: Find Top Startpoints

Extract startpoints from the XML, normalize MBIT names, and count occurrences:

```bash
XML="runs/core_client/n2p_htall_conf4/sta_pt/func.max_high.T_85.typical/reports/core_client.func.max_high.T_85.typical_timing_summary.xml.filtered"

# All paths (excluding ifc_external), normalize icore0/icore1:
grep -oP '<path[^>]+' "$XML" | \
  grep -v 'ifc_external' | \
  grep -oP 'startpoint="\K[^"]+' | \
  sed 's|/CP$||; s|^icore[01]/|icore0/|' | \
  sort | uniq -c | sort -rn | head -10
```

### Step 2: Query Prev Path Slack

For each top startpoint, query the worst setup path arriving at its data pin:

```bash
$PT -m modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical \
  -c "report_timing -delay_type max -through <register>/D* -nosplit"
```

**Important:** Use `-through D*` (not `-to D1`). The `-through` finds the actual
worst-case arriving path through any data pin.

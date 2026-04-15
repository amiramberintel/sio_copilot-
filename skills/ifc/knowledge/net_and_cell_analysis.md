# Net & Cell Analysis Cookbook

> **Scripts location:** `/nfs/site/disks/gilkeren_wa/copilot/scripts/`

## Net Analysis Script

### Overview
Analyzes a single net's routing characteristics: metal layers, wire length, RC parasitics, and delay.
Accepts either input or output pins — auto-detects direction.

### Quick Run
```bash
/nfs/site/disks/gilkeren_wa/copilot/scripts/net_analysis.sh <pin_name> [corner]
```

### Examples
```bash
# Output pin (driver):
net_analysis.sh icore0/par_fmav0/simuldisablebugfixm3nnh__FEEDTHRU_1_ft_buf4/Z

# Input pin (load):
net_analysis.sh icore0/par_fmav0/simuldisablebugfixm3nnh__FEEDTHRU_1_ft_buf3/I

# Specify corner:
net_analysis.sh icore0/par_meu/invs_place_FE_OFC2011752_n_8507/ZN func.max_med.T_85.typical
```

Default corner: `func.max_high.T_85.typical`

### Output
```
NET ANALYSIS RESULTS
  Net name   : <net>
  Driver     : <driver_pin>
  Loads      : <N>
  Wire length: <X> um

  METAL LAYER USAGE:
    M11    : 8 segments
    M4     : 5 segments
    ...
  Range: M1 - M13

  DELAY & RC PER LOAD:
  LOAD PIN                              R(ps)    F(ps)  Cap(pF) Res(kΩ)
  <load_pin>                          8.164   7.981   0.015   1.520

  SUMMARY: Net delay=8.2ps(R)/8.0ps(F) | R=1.5kΩ | C=15fF | Wire=83.8um
```

### How It Works
1. Queries PT server for net name, driver/loads via `pt_client.pl`
2. Queries `report_delay_calculation` for each load (RC and delay)
3. Parses DEF file for metal layer usage and wire length (streaming `awk` — handles huge DEF files)
4. Extracts partition name from pin hierarchy to locate the correct DEF file

### Data Sources
- **PT server**: net connectivity, delay, RC parasitics
- **DEF file**: metal layers, routing coordinates for wire length
  - Location: `runs/<partition>/n2p_htall_conf4/release/latest/sta_primetime/<partition>.def.gz`
  - DEF UNITS: 2000 per µm (for this design)

### Key Technical Details
- Streaming DEF parsing with `awk` (not Python `zcat` into memory) — handles 200M+ line DEF files
- Wire length = sum of manhattan distances between routed coordinate pairs
- DEF `*` wildcard in coordinates means "same as previous value"
- Some nets appear twice in DEF (connectivity section + routing section); script prefers the ROUTED block

---

## Buffer Cell Database Script

### Overview
Creates a CSV database of all buffer-like cells with average delays computed from actual
post-route instances across all partitions.

### Quick Run (inside PT session)
```tcl
source /nfs/site/disks/gilkeren_wa/copilot/scripts/buffer_cell_database.tcl
build_buffer_database
```

### Options
```tcl
# Test with single cell type (fast):
build_buffer_database -ref BUFFD4BWP156HPNPN3P48CPDULVT

# Test with a family:
build_buffer_database -ref BUFFD4*

# Custom output path:
build_buffer_database -output /path/to/output.csv

# Override delay type:
build_buffer_database -delay_type min
```

### Cell Families Covered
| Pattern | Type | Description |
|---------|------|-------------|
| `BUFF*` | BUF | Data buffers (BUFFD, BUFFSR2, BUFFSKF, BUFFSKR, BUFFREPM, BUFFBBOX, etc.) |
| `INV*` | INV | Inverters (INVD, INVSKF, INVSKFO, INVSKR, INVSKRO, INVREP, etc.) |
| `CKB*` | CK_BUF | Clock buffers (CKBD, CKBDH, CKBSLOW) |
| `CKN*` | CK_INV | Clock inverters (CKND, CKNDH, CKND2) |
| `DCCK*` | CK_BUF | DC-coupled clock buffers |
| `DEL[A-G]*` | DELAY | Delay cells (DELA through DELG) |

### Output CSV Columns
| Column | Description |
|--------|-------------|
| `ref_name` | Full cell library name |
| `func` | Cell function prefix (e.g., BUFF, INVSKFO, CKBD, DELA) |
| `type` | Category: BUF, INV, CK_BUF, CK_INV, DELAY |
| `vt_class` | Threshold voltage: LVT, ULVT, ULVTLL, SVT, HVT |
| `drive_strength` | Drive strength number (from D<N>BWP pattern) |
| `instance_count` | Number of instances in the design |
| `arc_count` | Number of timing arcs queried |
| `avg_rise_delay_ps` | Average rise delay across all instances (ps) |
| `avg_fall_delay_ps` | Average fall delay across all instances (ps) |
| `min/max_rise/fall_delay_ps` | Min/max delay bounds |

### Defaults
- **Output**: `$::ivar(rpt_dir)/buffer_cell_database.csv`
- **Delay type**: `$::ivar(sta,delay_type)` (auto-detects max/min from corner)

### How It Works
1. Collects all buffer-like cell instances using `get_cells -hier -filter {ref_name=~PATTERN}`
2. Groups by `ref_name` (unique cell type)
3. For each cell type, bulk-queries timing arc delays via `get_attribute $arcs delay_max_rise`
4. Computes mean/min/max statistics
5. Extracts VT class and drive strength from the cell name

### Key Technical Details
- Uses `$::ivar()` (global array with `::` prefix) inside procs — NOT `ivar` command
- Delays are real post-route values (include actual RC loading), not library intrinsic
- For `max` corners: queries `delay_max_rise` / `delay_max_fall`
- For `min` corners: queries `delay_min_rise` / `delay_min_fall`
- Cell name parsing: VT class from suffix, drive strength from `D<N>BWP` pattern

---

## Partition Input Constraint Check Script

### Overview
Checks all input pins of all partitions for timing constraint status: constrained, unconstrained,
clock port, or no sink.

### Quick Run (inside PT session)
```tcl
source /nfs/site/disks/gilkeren_wa/copilot/scripts/check_partition_inputs.tcl
check_partition_inputs
```

### Output
CSV at `$::ivar(rpt_dir)/partition_input_check.csv` with columns:
`partition, pin, status, path_group, delay_type`

Status values: `CONSTRAINED`, `UNCONSTRAINED`, `CLOCK`, `SKIPPED_NO_SINK`

### Key Technical Details
- Auto-detects partitions from PT design hierarchy
- Uses `all_fanout -trace_arcs all` to find sinks (required for ILM boundary tracing)
- Checks `is_clock_pin` on fanout endpoints for CLOCK classification
- Constraint detection: `get_timing_paths -through $pin` then check `path_group`
  - `path_group == ""` or `**async_default**` = unconstrained
- Uses `parallel_foreach_in_collection` for performance
- Thread-safe result collection via temp file

---

## Cell Area Analysis

### Get Area of a Single Cell
```tcl
get_attribute [get_cells <cell_instance>] area
# From liberty (ref cell area):
get_attribute [get_lib_cells <lib>/<ref_name>] area
```

Area unit is typically µm² — verify with:
```tcl
get_attribute [get_libs *] area_unit
```

### Sum Area of a Partition
```tcl
proc get_partition_area {partition} {
    set cells [get_cells ${partition}/* -hierarchical -quiet]
    if {[sizeof_collection $cells] == 0} {
        puts "No cells found under ${partition}/"
        return 0
    }
    set total 0
    set count 0
    foreach_in_collection c $cells {
        set total [expr {$total + [get_attribute $c area]}]
        incr count
    }
    set total [expr {round($total)}]
    puts "Partition: $partition"
    puts "Cells:     $count"
    puts "Area:      $total um^2"
    return $total
}

# Usage:
get_partition_area icore0/par_fmav0
```

**Note:** `sum_collection` is available in FC/ICC2 but NOT in PrimeTime — use `foreach_in_collection` loop instead.

---

## Feedthrough Path Analysis Workflow

### When to Use
When analyzing timing paths that cross partition boundaries through feedthrough chains
(common in par_fmav0, par_fmav1).

### Identifying Bottlenecks
1. Run `report_timing -through <signal> -nosplit -nets -input_pins -significant_digits 4`
2. Look for large **net delays** (>20ps) — these dominate the path
3. Use `net_analysis.sh` on suspect nets to check metal layers and RC

### Common Issues
| Issue | Symptom | Fix |
|-------|---------|-----|
| Low-metal routing | Net on M3-M5, R>4kΩ, high net delay | Promote to upper metals (M11+) |
| Long cross-partition net | 40-50ps net delay, high R and C | Add repeater near boundary, reroute upper metals |
| Too many feedthrough stages | 4+ buffers in chain | Reduce to 2-3 if placement allows |
| Weak drive cells | LVT D1 inverters/buffers | Upsize to ULVT or higher drive strength |

### Example Analysis
```
Signal: simuldisablebugfixm3nnh (par_meu → par_fmav0 → par_fmav1)
Slack: -157ps, 4 feedthrough buffers in par_fmav0
Bottleneck: ft_net2 routed on M3-M5 (R=4.6kΩ, 28ps) vs M11+ for others (R=1.5kΩ, 8ps)
Fix: Promote ft_net2 to upper metals → save ~20ps
```

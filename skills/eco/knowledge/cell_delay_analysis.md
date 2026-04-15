# Cell Delay Analysis — Per-Arc Delay Measurement & Corner Scaling

## Purpose

Measure average cell delay per timing arc (e.g., NAND2 A→Y rise, A→Y fall) in PrimeTime,
then compare across corners to understand PVT scaling factors.

## Scripts

| Script | Location | Language |
|--------|----------|----------|
| `cell_type_delays.tcl` | `$stod/copilot/scripts/cell_type_delays.tcl` | PT TCL |
| `cell_delay_scaling.py` | `$stod/copilot/scripts/cell_delay_scaling.py` | Python 3 |

Where `$stod = /nfs/site/disks/gilkeren_wa`.

---

## Step 1: Collect Delays in PrimeTime

### Source and run in a PT session:

```tcl
source /nfs/site/disks/gilkeren_wa/copilot/scripts/cell_type_delays.tcl

# Full chip (warning: very slow on large designs)
report_cell_type_delays -output cell_delays_max_high.csv

# Scoped to a partition (recommended for large designs)
report_cell_type_delays -output cell_delays_max_high.csv -partition icore0/par_meu

# Custom sample size (default: 20 instances per cell type)
report_cell_type_delays -output cell_delays_max_high.csv -partition icore0/par_meu -sample 50
```

### Arguments

| Flag | Required | Description |
|------|----------|-------------|
| `-output` | Yes | Output CSV file path |
| `-partition` | No | Scope to a partition hierarchy (e.g., `icore0/par_meu`) |
| `-sample` | No | Max instances to sample per cell type (default: 20) |

### How it works

1. Collects all leaf cells (optionally scoped by `-partition` using `get_cells -hierarchical -filter`)
2. Builds a histogram of `ref_name` (cell type) using bulk `get_attribute`
3. For each cell type, samples up to N instances
4. For each instance, iterates over combinational timing arcs (`get_timing_arcs -filter "type==combinational"`)
5. Calls `report_delay_calculation -from <pin> -to <pin> -rise/-fall` per arc
6. Parses "Cell Delay" value from the report output
7. Errors on individual arcs are caught and silently skipped (disabled arcs, no-path arcs, etc.)

### Output CSV format

```
ref_name,count,arc,edge,measured,avg_delay,min_delay,max_delay
NAND2X1,15432,A->Y,rise,20,0.012345,0.010100,0.015600
NAND2X1,15432,A->Y,fall,20,0.011234,0.009800,0.013200
NAND2X1,15432,B->Y,rise,20,0.013456,0.011000,0.016700
...
```

| Column | Description |
|--------|-------------|
| `ref_name` | Cell type (library reference name) |
| `count` | Total instances of this type in design/partition |
| `arc` | Timing arc (e.g., `A->Y`, `B->Y`) |
| `edge` | Output transition: `rise` or `fall` |
| `measured` | Number of instances actually measured (≤ sample) |
| `avg_delay` | Average cell delay across measured instances |
| `min_delay` | Minimum cell delay observed |
| `max_delay` | Maximum cell delay observed |

### Runtime estimates

| Scope | Cells | Approx Runtime |
|-------|-------|---------------|
| Single partition | ~1-3M | ~1-3 hours |
| Full chip (30M) | ~30M | ~12-28 hours (not recommended) |

**Recommendation**: Use `-partition` to scope to a single partition from a full-chip session.
The cells still have full-chip timing context (real slews/loads from neighboring partitions),
so the delay data is accurate.

---

## Step 2: Compare Across Corners

Run the TCL script in each corner's PT session with different output filenames:

```tcl
# Corner 1: max_high
report_cell_type_delays -output $ward/cell_delay_max_high.csv -partition icore0/par_meu

# Corner 2: max_med
report_cell_type_delays -output $ward/cell_delay_max_med.csv -partition icore0/par_meu

# Corner 3: nom
report_cell_type_delays -output $ward/cell_delay_nom.csv -partition icore0/par_meu
```

Then from a regular shell:

```bash
python3 /nfs/site/disks/gilkeren_wa/copilot/scripts/cell_delay_scaling.py \
    $ward/cell_delay_max_high.csv \
    $ward/cell_delay_max_med.csv \
    $ward/cell_delay_nom.csv
```

### Scaling output

The first file is the **reference corner**. For each additional corner, the script shows:
- Per-arc delays and scaling ratios (`other / reference`)
- Summary statistics: average, weighted average (by instance count), and range

```
cell_type                            arc  edge    count      max_high       max_med           nom  max_med/max_high    nom/max_high
--------------------------------------------------------------------------------------------------------------------------------------
NAND2X1                           A->Y  rise    15432      0.012345      0.010100      0.008200          0.8182          0.6640
NAND2X1                           A->Y  fall    15432      0.011234      0.009200      0.007500          0.8189          0.6676
...
--------------------------------------------------------------------------------------------------------------------------------------
Scaling max_med vs max_high:
  Average:  0.8200  (unweighted, 2450 arcs)
  Weighted: 0.8150  (by instance count)
  Range:    0.7500 .. 0.9100
```

### Single-corner mode

With a single CSV file, it simply prints all delays sorted by cell type:

```bash
python3 cell_delay_scaling.py $ward/cell_delay_max_high.csv
```

---

## PT Syntax Notes

Key PT command patterns used (important for debugging/customization):

```tcl
# Partition-scoped cell collection (use -hierarchical -filter, NOT glob pattern)
get_cells -hierarchical -filter "full_name=~${partition}/* && is_hierarchical==false" -quiet

# Combinational timing arcs (use -filter, NOT -type flag)
get_timing_arcs -of_objects $cell -filter "type==combinational" -quiet

# In-memory filtering (fast, avoids repeated get_cells)
filter_collection $all_cells "ref_name==$ref"

# Delay calculation with error handling
catch { redirect -variable rpt_str { report_delay_calculation -from $pin1 -to $pin2 -rise } }
```

---

## See Also

- `multi_model_comparison.md` — Multi-model WA comparison pipeline
- `timing_report_compression.md` — Timing report compression utilities

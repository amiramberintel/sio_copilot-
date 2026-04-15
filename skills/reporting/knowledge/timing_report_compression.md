# Timing Report Compression Cookbook

## Overview

Compress large timing report XML files into concise summaries with optional
PBA (Path-Based Analysis) detailed timing from PT server.

**Script:** `/nfs/site/disks/gilkeren_wa/copilot/scripts/compress_timing_rpt.py`

## What It Does

Takes a timing report XML (`.rpt`) with thousands of `<path>` entries and:

1. **Simplifies startpoint/endpoint names:**
   - Strips full hierarchy → keeps register name + n-1 parent hierarchy
   - MBIT same-sequential → base register name (e.g., `data_array_reg`)
   - MBIT different-sequential → keeps all unique names (`MBIT_nameA_reg_MBIT_nameB_reg`)
   - Strips register bit indices (`_reg_119_` → `_reg`)
   - Removes `_clone`/`_clone_N` suffixes
   - Replaces index numbers with `*` (preserves signal name numbers like `M202H`)

2. **Deduplicates** by unique SP/EP pair, keeping worst slack per bucket

3. **Adds TNS** (Total Negative Slack) per SP/EP bucket

4. **Shows port name** for external paths (from `boundary_pins` attribute)

5. **Optionally queries PT server** for detailed PBA timing reports

## Usage

```bash
# Basic compression (summary only)
python3 compress_timing_rpt.py <input.rpt> [output.rpt]

# With PBA detailed timing (auto-detects corner and PT model)
python3 compress_timing_rpt.py <input.rpt> [output.rpt] --pba

# PBA only for paths with slack <= -20
python3 compress_timing_rpt.py <input.rpt> --pba --slack -20

# Explicit PT model and parallelism
python3 compress_timing_rpt.py <input.rpt> --pba --model modelb_gfcn2clienta0_bu_prp_func.max_high.T_85.typical --parallel 30
```

If output is not specified, writes to `<input>.compressed.rpt`.

## Command-Line Options

| Option | Default | Description |
|--------|---------|-------------|
| `input` | (required) | Input timing report XML file |
| `output` | `<input>.compressed.rpt` | Output file path |
| `--pba` | off | Query PT server for detailed PBA timing |
| `--model MODEL` | auto-detect | PT server model name |
| `--parallel N` | 20 | Number of parallel PT queries |
| `--slack SLACK` | all | Slack threshold for PBA (e.g., `-20`) |

## Output Format

### Summary Table

```
id        slack        tns type startpoint                              endpoint                                port
----------------------------------------------------------------------------------------------------------------------
1           -45       -536 int  parent/data_array_reg                   rsbpc/RSMOClearVM802H_reg
2          -101      -3240 ext  momclb/MOWBCheckRobIdM803H_reg          rsschedrepd/ROWBCheckRobIdLdM804H_reg   mowbcheckrobidldm803h_*_[*]
```

| Column | Description |
|--------|-------------|
| `id` | Sequential path ID |
| `slack` | Worst negative slack (WNS) for this SP/EP bucket (ps) |
| `tns` | Total negative slack across all paths in this bucket (ps) |
| `type` | `int` (internal) or `ext` (external) |
| `startpoint` | Simplified startpoint: `n-1_hier/register_name` |
| `endpoint` | Simplified endpoint: `n-1_hier/register_name` |
| `port` | Boundary port name (external paths only) |

### Detailed PBA Reports (with `--pba`)

Appended after the summary, one `report_timing` output per path:
```
=====================================
DETAILED TIMING REPORTS (PBA mode) - N paths
=====================================

--- Path 1 ---
<full PT report_timing output with -pba_mode path -transition_time -input_pins -capacitance -physical>

--- Path 2 ---
...
```

## Name Simplification Rules

### Hierarchy Stripping
```
icore0/par_ooo_int/rs_int/rsbpc/RSMOClearVM802H_reg/D
→ rsbpc/RSMOClearVM802H_reg
```
Keeps n-1 hierarchy (`rsbpc`) + register name. Pin (`/D`) is stripped.

### MBIT Same-Sequential
All constituent registers share the same base name → collapse to base:
```
auto_vector_MBIT_data_array_reg_0__1__fielded_NeedsBit_MBIT_data_array_reg_0__1__fielded_MustPrimaryJump_...
→ data_array_reg
```

### MBIT Different-Sequential
Constituent registers have different base names → keep all unique:
```
auto_vector_MBIT_RSSpecUopOrV2ICancNotReadyM203H_reg_MBIT_RSV2ICanc299MHNoRdyEuWakeInvM204H_reg
→ MBIT_RSSpecUopOrV2ICancNotReadyM203H_reg_MBIT_RSV2ICanc299MHNoRdyEuWakeInvM204H_reg
```

### Register Index Stripping
```
RSLDCamcRdyEuM300H_reg_119_  → RSLDCamcRdyEuM300H_reg
EuDepMatchEuFlipM204H_reg_0__10_ → EuDepMatchEuFlipM204H_reg
```

### Clone Removal
```
ctech_lib_clk_gate_te_dcszo_clone_clone_clone_1 → ctech_lib_clk_gate_te_dcszo
```

### Number Wildcarding
Index-like numbers replaced with `*`, signal name numbers preserved:
```
CG_RC_CG_HIER_INST1012 → CG_RC_CG_HIER_INST*
Eu_wrclk_0__  → Eu_wrclk_*__
rseuwakeupin0m800h[5]  → rseuwakeupin0m800h[*]   (m800h preserved)
```

### Non-Register Endpoints (Ports, ICGs)
Hierarchical ports and ICG cells (no `_reg` in name) keep n-1 hierarchy:
```
icore0/.../rsmeubanktop/euspecwakeup301cancelm203h[2]
→ rsmeubanktop/euspecwakeup301cancelm203h[*]
```

## Examples

### Internal Timing Report
```bash
python3 compress_timing_rpt.py \
  nworst_vrf_split_normalized_uc/func.max_high.T_85.typical/par_ooo_int/par_ooo_int.int.0.rpt

# Result: 69,229 lines (61 MB) → 567 unique pairs (0.1 MB), 99.9% reduction
```

### External Timing Report with PBA
```bash
python3 compress_timing_rpt.py \
  nworst_vrf_split_normalized_uc/func.max_high.T_85.typical/par_ooo_int/par_ooo_int.ext.0.rpt \
  --pba --slack -50

# Result: summary + detailed PBA for paths with slack <= -50
```

### All External Paths
```bash
python3 compress_timing_rpt.py \
  nworst_vrf_split_normalized_uc/func.max_high.T_85.typical/par_ooo_int/par_ooo_int.ext.all.rpt

# Handles both {braced} and space-separated boundary_pins formats
```

## TNS vs WNS Prioritization

The `tns` column helps identify high-impact buckets:

- **High WNS, low TNS** = few paths, likely a specific logic issue
- **Moderate WNS, high TNS** = many failing paths, broader structural issue

Example:
```
id   slack      tns  startpoint                    endpoint
1      -45     -536  data_array_reg                RSMOClearVM802H_reg       ← few paths, deep logic
5      -34   -16744  RSCancRdyEuVM300H_reg         RSEuMtxRdyStdPartOutM300H ← many paths, fanout issue
```

Path 5 has moderate WNS but massive TNS — fixing it improves many more endpoints.

## PT Model Auto-Detection

The script auto-detects the PT model from the input file path by extracting the corner name
(e.g., `func.max_high.T_85.typical`) and constructing:
```
modelb_gfcn2clienta0_bu_prp_<corner>
```

Override with `--model` if using a different flow (e.g., `fcl`) or model version.

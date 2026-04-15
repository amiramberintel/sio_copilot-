# Multi-Model Comparison Pipeline

## Overview

Compare N FCT work areas side-by-side with CSV reports and formatted XLSX output.
Two scripts work together:

1. **csv_split_multi.csh** — generates CSV comparison files from N models
2. **pnc_table_multi.pl** — converts CSVs into a formatted XLSX workbook

## Scripts Location

```
/nfs/site/disks/gilkeren_wa/copilot/scripts/csv_split_multi.csh
/nfs/site/disks/gilkeren_wa/copilot/scripts/pnc_table_multi.pl
```

## Quick Usage

### Step 1: Generate CSVs

```bash
csv_split_multi.csh <corner> <model1_path> <model2_path> [model3_path ...]
```

- **corner**: e.g., `func.max_high.T_85.typical`
- **model1**: current/newest model (gets red/green highlights)
- **model2**: primary reference (Model 1 is compared against this)
- **model3+**: additional older references (optional)

Example — 3-model comparison:
```bash
$stod/copilot/scripts/csv_split_multi.csh func.max_high.T_85.typical \
  $ward \
  $ward/dcm/ \
  /path/to/older_wa/
```

Models are auto-labeled from `env_vars.rpt` WW tags (e.g., WW13B, WW13A).
Output goes to: `<model1>/runs/<block>/<tech>/sta_pt/<corner>/reports/csv/`

### Step 2: Generate XLSX

```bash
pnc_table_multi.pl <csv_directory>
```

Example:
```bash
$stod/copilot/scripts/pnc_table_multi.pl \
  $ward/runs/core_client/n2p_htall_conf4/sta_pt/func.max_high.T_85.typical/reports/csv/
```

Output: `indicator_table_<corner>_<user>.xlsx` in the same directory.

## XLSX Features

### Model Detection
- Auto-detects N from `model_tags.csv` (multi-model format) or data CSV patterns (original TST/REF)
- Prints detected models on startup: `Detected 3 models: WW13B, WW13A, WW12D`

### Color Coding
- Each model gets a distinct background color:
  - Model 1: blue (#cad8ed)
  - Model 2: white (border only)
  - Model 3: light peach (#f5e6cc)
  - Model 4: light sage (#d5e8d4)
  - Model 5+: lavender, cream, sky, pink, mint, apricot
- Label columns (model, par, unit) keep model colors but no red/green

### Conditional Formatting (Red/Green)
- Applied **only to Model 1 rows**
- Compares Model 1 vs Model 2 (always, regardless of how many models)
- Green = Model 1 improved over Model 2
- Red = Model 1 regressed vs Model 2
- Per-tab polarity rules preserved from original script

### Tabs (21 total)
| Tab | CSV | Highlights |
|-----|-----|-----------|
| vrf_norm | vrf_normalized.csv | WNS/TNS normalized violations |
| Unit_vrf | unit_vrf_normalized.csv | Per-unit violations |
| vrf_uncomp | vrf_uncompressed.csv | Raw violation counts |
| vrf_dfx | vrf_dfx.csv | DFX violations |
| Quality | quality.csv | Quality checks + totals |
| Ovrs | ovrs.csv | Override counts + totals |
| Logs | logs.csv | Log checks + totals |
| Tags | tags.csv | Partition tags (string diff) |
| EBB_summary | ebb_summary.csv | EBB summary (string diff) |
| uArch_sum | uarch_sum.csv | uArch summary (% col) |
| uArch_status | uarch_status.csv | uArch status (% col) |
| clk_latency | check_clk_latency.csv | Clock latency |
| DOP_latency | dops.csv | DOP latency |
| dop_stamping | dop_stamping.csv | DOP stamping (string diff) |
| ext_bottleneck | ext_bottleneck.csv | External bottleneck paths |
| par_status | par_status.csv | Partition status (string diff) |
| model_info | model_info.csv | Model metadata (string diff) |
| model_tags | model_tags.csv | Model paths (no formatting) |
| sdc_cksum | sdc_cksum.csv | SDC checksums (string diff) |
| cell_stats | cell_stats.csv | Cell statistics |
| ports location | ports.csv | Port locations |

## Backward Compatibility

Both scripts work with the original 2-model csv_split.csh output (TST/REF format).
When N=2, output is visually equivalent to the original `pnc_table_bu.pl_new`.

## End-to-End Example

```bash
# Compare 3 weekly models on max_high corner
$stod/copilot/scripts/csv_split_multi.csh func.max_high.T_85.typical \
  /path/to/WW13B_wa \
  /path/to/WW13A_wa \
  /path/to/WW12D_wa

# Generate XLSX
$stod/copilot/scripts/pnc_table_multi.pl \
  /path/to/WW13B_wa/runs/core_client/n2p_htall_conf4/sta_pt/func.max_high.T_85.typical/reports/csv/

# Result: indicator_table_func_max_high_T_85_typical_<user>.xlsx
```

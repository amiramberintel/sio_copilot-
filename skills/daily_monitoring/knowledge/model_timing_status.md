# Model Timing Status Summary Cookbook

## Overview

Generate a CSV summary of timing status (WNS/TNS/FEP) across all corners,
partitions, and path types from a PrimeTime work area.

**Script:** `/nfs/site/disks/gilkeren_wa/copilot/scripts/model_timing_status.py`

Optimized Python replacement for the original csh scripts:
- `model_timing_status_v2.csh` — standard mode (func/dfx split)
- `model_timing_status_v2_nworst.csh` — nworst mode (all paths, no voltage columns)

Produces identical output ~50-70× faster by parsing each XML file once instead of
running multiple grep passes per partition.

## Usage

```bash
# Requires environment: tech, flow, ward, PROJECT_STEPPING
# (typically set after sourcing cth_psetup)

# Standard mode (func/dfx):
python3 /nfs/site/disks/gilkeren_wa/copilot/scripts/model_timing_status.py <work_area> [--out output.csv]

# Nworst mode:
python3 /nfs/site/disks/gilkeren_wa/copilot/scripts/model_timing_status.py <work_area> --nworst [--out output.csv]
```

Default output:
- Standard: `$ward/model_timing_status_<WW>.csv`
- Nworst: `$ward/model_timing_status_nworst_<WW>.csv`

## Output Format

### Standard Mode

CSV with columns:

| Column | Description |
|--------|-------------|
| corner | Timing corner (e.g., `func.max_high.T_85.typical`) |
| priorty | Priority from pvt.csv (e.g., `PT1`) |
| min_or_max | Delay type (`min` or `max`) |
| type_xml | `no_dfx` (functional) or `only_dfx` (DFx paths) |
| mclk_ct | mclk_pll period |
| uclk_ct | uclk period |
| sbclk_ct | sbclk period |
| npkclk_ct | npkclk period |
| vcccore/vccring/vccst | Supply voltages |
| par | Partition name (e.g., `par_exe`, `par_meu`) |
| internal_wns/tns/FEP | Internal path worst slack, total negative slack, failing endpoint count |
| external_wns/tns/FEP | External path metrics |
| ifc_external_wns/tns/FEP | IFC external path metrics |
| have_server | Number of available PT servers for this corner |

### Nworst Mode (`--nworst`)

Fewer columns — no uclk/sbclk/npkclk/voltages, adds `type` column:

| Column | Description |
|--------|-------------|
| corner | Timing corner |
| priorty | Priority from pvt.csv |
| min_or_max | Delay type |
| type_xml | Always `nworst` |
| mclk_ct | mclk_pll period (includes mclk_pll_ext) |
| type | Always `all` |
| par | Partition name |
| internal_wns/tns/FEP | Internal path metrics |
| external_wns/tns/FEP | External path metrics |
| ifc_external_wns/tns/FEP | IFC external path metrics |
| have_server | Number of available PT servers |

Key differences from standard mode:
- XML source: `_timing_summary.nworst.xml.filtered` (single file, not split by dfx)
- Excludes `.ct` corners (in addition to noise/rv_em)
- Corners sorted alphabetically (standard mode uses modification time)
- Priority file from `$ward` (standard uses `$wa`)

## How It Works

1. Reads `env_vars.rpt` for block name, tech, flow, workweek
2. Discovers corners by scanning the STA output directory (sorted by file modification time)
3. For each corner, reads clock periods and voltages once
4. **Key optimization**: Parses each XML file in a single pass, extracting WNS/TNS/FEP
   for all partitions simultaneously (original script runs 6 separate greps per partition)
5. For external paths, a line is counted for every partition name that appears anywhere
   in the line (startpoint, endpoint, blocks_impacted, boundary_pins)

## Data Sources

| Data | Source File |
|------|-------------|
| WNS/TNS/FEP | `reports/<block>.<corner>_timing_summary_no_dfx.xml.filtered` |
| Clock periods | `outputs/<block>_clock_params.<corner>.debug.propagate_clock_1.tcl` |
| Voltages | `project/<stepping>/pvt.tcl` (volt_for_supply_rails) |
| Priority | `project/<stepping>/pvt.csv` |
| Delay type | `project/<stepping>/pvt.tcl` (scenario_delay_type_map) |
| Server availability | PT server aliases file |

## Performance Comparison

| Metric | Original (csh) | Optimized (Python) |
|--------|----------------|---------------------|
| XML file scans | 6 greps × partitions × corners × 2 types | 1 pass per XML |
| Server check | 1 grep per corner | 1 pass total |
| Clock/voltage | grep per corner per field | 1 read per file |
| Typical speedup | — | ~50-70× faster |

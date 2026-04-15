# External Path Spec Analysis Cookbook

## Overview

Analyze external timing paths to identify which partitions and ports miss their spec budget.
Data comes from `.ext.0.rpt` files which are XML-like, one `<path>` element per line.

## Input Files

### External Path Reports
```
nworst_vrf_split_normalized_uc/<corner>/<par>/<par>.ext.0.rpt
```
- One file per partition (par_fe, par_meu, par_msid, etc.)
- Each line is a `<path ... />` with attributes

### Clock Period File
```
runs/core_client/<config>/release/latest/clock_collateral/<corner>/core_client_clock_params.tcl
```
- Contains `periodCache(clock_name, ...)` entries with period in ps

## Key Attributes in the Report

| Attribute | Description |
|-----------|-------------|
| `slack` | Path slack in ps |
| `normalized_slack` | Slack normalized to cycle time (fractional) |
| `blocks_impacted` | Partitions on the path with `{partition(data_delay,spec)}` format |
| `boundary_pins` | Port names at partition boundaries |
| `endpoint_clock` | Clock domain of the endpoint (used for cycle time lookup) |
| `path_group` | Clock-based path group |
| `startpoint` | Path startpoint register |
| `endpoint` | Path endpoint register |

## Understanding `blocks_impacted`

Format: `{icore0/par_meu(130.35,21.0) } {icore0/par_fe(151.78,147.0) }`

- First number = **data_delay** (actual delay through that partition)
- Second number = **spec** (budget allocated to that partition)
- **MISS** when `data_delay > spec`
- **Overshoot** = `data_delay - spec`

## Calculating Number of Cycles

The path may cross multiple clock cycles. To determine how many:

1. Derive the effective period: `period = slack / norm_slack`
2. Get clock cycle time from the clock file via `endpoint_clock` attribute
3. Calculate: `raw_cycles = period / cycle_time`
4. Round to nearest **0.5** (values: 0, 0.5, 1, 1.5, 2, ...)

Example:
```
slack = -45ps, norm_slack = -0.12, cycle_time = 186ps
period = -45 / -0.12 = 375ps
raw_cycles = 375 / 186 = 2.02
num_cycles = 2.0
```

## Deduplication

Multiple paths may hit the same port. Keep only the **worst overshoot** per unique port (partition + port_name combined, e.g., `icore0/par_meu/rslvpdatasigncheckm806h[20]`).

## Step-by-Step

### 1. Parse Clock Periods

```python
import re

clk_file = "runs/core_client/<config>/release/latest/clock_collateral/<corner>/core_client_clock_params.tcl"
clk_periods = {}
with open(clk_file) as f:
    for line in f:
        m = re.search(r'periodCache\((\w+),', line)
        p = re.search(r'\)\s+(\d+)"', line)
        if m and p:
            clk_periods[m.group(1)] = float(p.group(1))
```

### 2. Parse All Partition Reports

```python
import glob, os

base = "nworst_vrf_split_normalized_uc/<corner>"
worst = {}  # (partition, port_name) -> row with worst overshoot

for pardir in sorted(glob.glob(os.path.join(base, "par_*"))):
    par = os.path.basename(pardir)
    rptfile = os.path.join(pardir, f"{par}.ext.0.rpt")
    if not os.path.isfile(rptfile):
        continue

    with open(rptfile) as f:
        for line in f:
            line = line.strip()
            if not line.startswith('<path '):
                continue

            # Extract attributes
            slack = float(re.search(r' slack="([^"]+)"', line).group(1))
            norm_slack = float(re.search(r'normalized_slack="([^"]+)"', line).group(1))
            blocks_str = re.search(r'blocks_impacted="([^"]+)"', line).group(1)
            bpins = re.search(r'boundary_pins="([^"]+)"', line).group(1)
            path_id = re.search(r'path_id="([^"]+)"', line).group(1)
            path_group = re.search(r'path_group="([^"]+)"', line).group(1)
            startpoint = re.search(r'startpoint="([^"]+)"', line).group(1)
            endpoint = re.search(r'endpoint="([^"]+)"', line).group(1)
            endpoint_clock = re.search(r'endpoint_clock="([^"]+)"', line).group(1)

            pins = re.findall(r'\{?([^{}\s]+)\}?', bpins)

            # Parse each block in blocks_impacted
            for bm in re.finditer(r'\{(\S+)\(([\d.]+),([\d.]+)\)\s*\}', blocks_str):
                partition = bm.group(1)
                data_delay = float(bm.group(2))
                spec = float(bm.group(3))
                overshoot = round(data_delay - spec, 3)
                status = "MISS" if overshoot > 0 else "MET"

                # Find matching port name from boundary_pins
                part_short = partition.split('/')[-1]
                port_name = ""
                for p in pins:
                    if part_short in p:
                        pm = re.search(re.escape(partition) + r'/(.+)', p)
                        port_name = pm.group(1) if pm else p
                        break

                # Calculate num_cycles
                cycle_time = clk_periods.get(endpoint_clock, None)
                if cycle_time is None and norm_slack != 0:
                    cycle_time = round(slack / norm_slack, 2)
                
                num_cycles = 0
                if norm_slack != 0 and cycle_time and cycle_time != 0:
                    period = slack / norm_slack
                    raw_cycles = period / cycle_time
                    num_cycles = round(raw_cycles * 2) / 2  # nearest 0.5

                # Combine partition and port into single field
                port = partition + '/' + port_name if port_name else partition

                # Keep worst per port
                key = port
                if key not in worst or overshoot > worst[key]['overshoot']:
                    worst[key] = {
                        'source_partition': par,
                        'port': port,
                        'data_delay': data_delay,
                        'spec': spec,
                        'overshoot': overshoot,
                        'status': status,
                        'slack': slack,
                        'norm_slack': norm_slack,
                        'endpoint_clock': endpoint_clock,
                        'cycle_time': cycle_time,
                        'num_cycles': num_cycles,
                        'path_group': path_group,
                        'path_id': path_id,
                        'startpoint': startpoint,
                        'endpoint': endpoint,
                    }
```

### 3. Write CSV Output

```python
import csv

outfile = "/path/to/output/all_partitions_ext_spec_misses.csv"
deduped = sorted(worst.values(), key=lambda r: -r['overshoot'])
fields = ['source_partition', 'port', 'data_delay', 'spec', 'overshoot',
          'status', 'slack', 'norm_slack', 'endpoint_clock', 'cycle_time', 'num_cycles',
          'path_group', 'path_id', 'startpoint', 'endpoint']

with open(outfile, 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=fields)
    w.writeheader()
    w.writerows(deduped)
```

## Output CSV Columns

| Column | Description |
|--------|-------------|
| `source_partition` | Which partition's report file this came from |
| `port` | Full port path: partition + port name (e.g., `icore0/par_meu/rslvpdatasigncheckm806h[20]`) |
| `data_delay` | Actual data delay through the partition (ps) |
| `spec` | Allocated budget for that partition (ps) |
| `overshoot` | `data_delay - spec` (positive = miss) |
| `status` | `MISS` or `MET` |
| `slack` | Path slack (ps) |
| `norm_slack` | Normalized slack (fraction of cycle) |
| `endpoint_clock` | Endpoint clock domain |
| `cycle_time` | Clock period from clock file (ps) |
| `num_cycles` | Number of cycles the path spans (0, 0.5, 1, 1.5, ...) |
| `path_group` | Clock-based path group |
| `path_id` | Unique path identifier |
| `startpoint` | Path startpoint |
| `endpoint` | Path endpoint |

## Quick Summary Query (after generating CSV)

To get a per-partition summary of misses:

```bash
python3 -c "
import csv
from collections import defaultdict
data = defaultdict(lambda: {'miss':0, 'met':0, 'worst':0})
with open('all_partitions_ext_spec_misses.csv') as f:
    for r in csv.DictReader(f):
        # Extract partition from port (e.g., icore0/par_meu from icore0/par_meu/portname)
        parts = r['port'].rsplit('/', 1)
        k = parts[0] if len(parts) > 1 else r['port']
        if r['status']=='MISS':
            data[k]['miss'] += 1
            data[k]['worst'] = max(data[k]['worst'], float(r['overshoot']))
        else:
            data[k]['met'] += 1
for p in sorted(data, key=lambda x: -data[x]['worst']):
    d = data[p]
    print(f'{p:<30} MISS:{d[\"miss\"]:>5}  MET:{d[\"met\"]:>5}  Worst Overshoot:{d[\"worst\"]:>10.3f}ps')
"
```

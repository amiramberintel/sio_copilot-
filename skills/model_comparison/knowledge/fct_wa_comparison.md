# FCT Work Area Comparison Cookbook

## Overview

Compare two FCT work areas (e.g., DCM vs daily, WW-to-WW) to identify what changed
in inputs, partitions, constraints, and timing results.

## Quick Comparison Checklist

### 1. Key Environment Variables

```bash
REF="<ref_wa_path>"
TST="<tst_wa_path>"
for key in block WW PROJECT_STEPPING; do
  rv=$(grep "^${key}=" $REF/env_vars.rpt | head -1 | cut -d= -f2)
  tv=$(grep "^${key}=" $TST/env_vars.rpt | head -1 | cut -d= -f2)
  echo "$key: REF=$rv TST=$tv"
done
```

### 2. DCM Release Source

The DCM release that feeds each WA is recorded in `dcm/.eouMGR_INFO.log`:

```bash
grep "WARD:" $REF/dcm/.eouMGR_INFO.log | head -1
grep "WARD:" $TST/dcm/.eouMGR_INFO.log | head -1
```

### 3. Partition ARC Versions

Each partition's data comes from an ARC transaction. Compare versions:

```bash
for par in par_exe par_fe par_fmav0 par_fmav1 par_meu par_mlc par_msid par_ooo_int par_ooo_vec par_pm par_pmh par_tmul_stub; do
  r=$(ls -l $REF/runs/$par/n2p_htall_conf4/release/latest/sta_primetime/*.def.gz 2>/dev/null | awk '{print $NF}' | grep -oP 'VER_\d+')
  t=$(ls -l $TST/runs/$par/n2p_htall_conf4/release/latest/sta_primetime/*.def.gz 2>/dev/null | awk '{print $NF}' | grep -oP 'VER_\d+')
  if [ "$r" = "$t" ]; then
    echo "SAME  $par: $r"
  else
    echo "DIFF  $par: REF=$r TST=$t"
  fi
done
```

### 4. Partition Tag Overrides

Tag overrides in `user_fct_vars.tcl` identify which ECO/release each partition uses:

```bash
diff <(grep "par_tags_ovr" $REF/runs/core_client/n2p_htall_conf4/sta_pt/scripts/user_fct_vars.tcl | grep -v "^#" | sort) \
     <(grep "par_tags_ovr" $TST/runs/core_client/n2p_htall_conf4/sta_pt/scripts/user_fct_vars.tcl | grep -v "^#" | sort)
```

Tag naming conventions:
- `pt_eco_ww12_5` — PT-ECO iteration 5 from WW12
- `pt_eco_max_med_ww13_2` — PT-ECO targeting max_med corner, iteration 2, WW13
- `noBistSkew` — BIST skew removal ECO
- `CONTOUR_26WW06E` — contour release identifier

### 5. Constraint/Override Files

```bash
# CTH override (usually identical between daily runs)
diff $REF/fct_cth_ovr.cth $TST/fct_cth_ovr.cth

# user_fct_vars.tcl (partition tags, scenarios, NBQ settings)
diff $REF/runs/core_client/n2p_htall_conf4/sta_pt/scripts/user_fct_vars.tcl \
     $TST/runs/core_client/n2p_htall_conf4/sta_pt/scripts/user_fct_vars.tcl

# PVT files (clock periods, voltages, priorities)
diff $REF/project/GFCN2CLIENTA0/pvt.tcl $TST/project/GFCN2CLIENTA0/pvt.tcl
diff $REF/project/GFCN2CLIENTA0/pvt.csv $TST/project/GFCN2CLIENTA0/pvt.csv
```

### 6. Scenario List

```bash
# Extract and compare scenario lists
python3 -c "
import re
def get_scen(p):
    with open(p) as f:
        for l in f:
            if 'FCT_SCENARIOS' in l and not l.strip().startswith('#'):
                m = re.search(r'\"([^\"]+)\"', l)
                if m: return set(m.group(1).split(','))
    return set()
r = get_scen('$REF/runs/core_client/n2p_htall_conf4/sta_pt/scripts/user_fct_vars.tcl')
t = get_scen('$TST/runs/core_client/n2p_htall_conf4/sta_pt/scripts/user_fct_vars.tcl')
print(f'REF: {len(r)} scenarios, TST: {len(t)} scenarios')
for s in sorted(r-t): print(f'  Only in REF: {s}')
for s in sorted(t-r): print(f'  Only in TST: {s}')
"
```

### 7. Timing Comparison (WNS/TNS)

Generate timing summaries and compare:

```bash
cd $REF && python3 /nfs/site/disks/gilkeren_wa/copilot/scripts/model_timing_status.py . --out /tmp/timing_ref.csv
cd $TST && python3 /nfs/site/disks/gilkeren_wa/copilot/scripts/model_timing_status.py . --out /tmp/timing_tst.csv
```

Then compare using the Python script below, or load into Excel.

## DCM vs Daily Comparison

When comparing `$ward/dcm` (DCM release) vs `$ward` (daily run):

### Typical Differences

| Item | DCM | Daily |
|------|-----|-------|
| MODEL_DISK | `idc_gfc_fct_bu_release` | `idc_gfc_fct_bu_daily` |
| WARD_SUFFIX | `_dcm_release` | `_dcm_daily` |
| RUN_MODE | (not set) | `REGRESSION` |
| DAILY | (not set) | `1` |
| NBQSLOT | `bc15_gfc_fct` | `bc15_gfc_sd` |
| caliber_run_from_pv | 1 | 0 |
| Scenarios | Full set (32+) | Reduced (no noise/rv_em/stressed) |

### What Causes Timing Diffs Between DCM and Daily

1. **Partition ARC version changes** — most common. New ECOs bring new ILM/SPEF/DEF
2. **Constraint changes** — pvt.tcl updates (rare between adjacent WW)
3. **Scenario differences** — daily drops non-critical corners (noise, stressed)
4. **Same inputs but different PT version** — unlikely but check env_vars

## Timing Comparison Script

```python
import csv

def load_timing(path):
    data = {}
    with open(path) as f:
        for row in csv.reader(f):
            if row[0].startswith('#') or len(row) < 22:
                continue
            cor, typ, par = row[0], row[3], row[11]
            data[(cor, typ, par)] = {
                'int_wns': int(row[12]) if row[12] else None,
                'int_tns': int(row[13]) if row[13] else None,
                'ext_wns': int(row[15]) if row[15] else None,
                'ext_tns': int(row[16]) if row[16] else None,
                'ifc_wns': int(row[18]) if row[18] else None,
                'ifc_tns': int(row[19]) if row[19] else None,
            }
    return data

ref = load_timing('/tmp/timing_ref.csv')
tst = load_timing('/tmp/timing_tst.csv')

# Aggregate WNS/TNS per corner (no_dfx, skip .ct)
import re
skip = re.compile(r'\.ct|noise|rv_em|stressed')
corners_done = set()
all_keys = set(ref.keys()) | set(tst.keys())

for key in sorted(all_keys):
    cor, typ, par = key
    if skip.search(cor) or typ != 'no_dfx' or cor in corners_done:
        continue
    rwns, twns, rtns, ttns = [], [], 0, 0
    for k in all_keys:
        if k[0] != cor or k[1] != typ:
            continue
        for pf in ['int', 'ext', 'ifc']:
            rv = ref.get(k, {}).get(f'{pf}_wns')
            tv = tst.get(k, {}).get(f'{pf}_wns')
            if rv is not None: rwns.append(rv)
            if tv is not None: twns.append(tv)
            rt = ref.get(k, {}).get(f'{pf}_tns')
            tt = tst.get(k, {}).get(f'{pf}_tns')
            if rt: rtns += rt
            if tt: ttns += tt
    rw = min(rwns) if rwns else None
    tw = min(twns) if twns else None
    dw = (tw - rw) if rw and tw else 0
    dt = ttns - rtns
    mark = " <<<" if abs(dw) >= 5 or abs(dt) > 1000 else ""
    print(f"{cor:<52} {str(rw):>8} {str(tw):>8} {dw:>+6} {rtns:>11} {ttns:>11} {dt:>+10}{mark}")
    corners_done.add(cor)
```

## Key Files Reference

| File | Purpose |
|------|---------|
| `env_vars.rpt` | All environment variables (block, WW, tech, flow, etc.) |
| `dcm/.eouMGR_INFO.log` | DCM release source path and timestamp |
| `fct_cth_ovr.cth` | CTH override configuration |
| `user_env_vars_file.csh` | User environment variable overrides |
| `runs/.../scripts/user_fct_vars.tcl` | Partition tags, scenarios, NBQ settings |
| `project/<stepping>/pvt.tcl` | Clock periods, voltages, delay type map |
| `project/<stepping>/pvt.csv` | Corner priorities |
| `runs/<par>/.../release/latest/sta_primetime/` | Partition ILM, SPEF, DEF data |

## See Also

- [Multi-Model Comparison Pipeline](multi_model_comparison.md) — for N-model CSV/XLSX comparison using `csv_split_multi.csh` and `pnc_table_multi.pl`

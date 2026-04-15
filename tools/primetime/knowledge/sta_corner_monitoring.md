# STA Corner Run Monitoring Cookbook

> **Scripts location:** All helper scripts live in `/nfs/site/disks/gilkeren_wa/copilot/scripts/`.
> Always place new scripts there.

## Quick Run

```bash
/nfs/site/disks/gilkeren_wa/copilot/scripts/sta_corner_monitor.sh [work_area]
```

Pass the BU work area path (e.g., `.../GFC_CLIENT_...bu_postcts`). If omitted, uses the current directory.

## Overview

How to monitor PrimeTime STA corner runs: check completion status, identify current stage for running corners, and get full runtime information.

## Directory Structure

```
runs/core_client/<config>/sta_pt/
├── <corner>/
│   ├── logs/
│   │   ├── core_client.<corner>.pt.log    # Main PT log
│   │   └── proc_time.log                  # Detailed runtime per stage
│   └── reports/csv/
│       └── indicator_table_*.xlsx         # Output XLS report
├── dmsa/
├── inputs/
├── logs/
├── outputs/
├── reports/
└── scripts/
```

## Step 1: List All Corners

List corner directories, excluding infrastructure directories and `.ct*` sub-corners:

```bash
cd runs/core_client/n2p_htall_conf4/sta_pt/
ls -d */ | sed 's/\/$//' \
  | grep -v -E '^(dmsa|inputs|logs|outputs|reports|scripts)$' \
  | grep -v '\.ct[0-9]*$'
```

## Step 2: Check Completion Status

A corner is **done** when its PT log contains the string `"Thank you for using pt_shell!"` near the end:

```bash
tail -50 <corner>/logs/core_client.<corner>.pt.log | grep -q "Thank you for using pt_shell!"
```

### Full status check for all corners:

```bash
cd runs/core_client/n2p_htall_conf4/sta_pt/
corners=$(ls -d */ | sed 's/\/$//' \
  | grep -v -E '^(dmsa|inputs|logs|outputs|reports|scripts)$' \
  | grep -v '\.ct[0-9]*$')

for c in $corners; do
  ptlog="$c/logs/core_client.${c}.pt.log"
  if [ -f "$ptlog" ] && tail -50 "$ptlog" | grep -q "Thank you for using pt_shell!"; then
    echo "DONE    | $c"
  else
    echo "RUNNING | $c"
  fi
done
```

## Step 3: Check Current Stage for Running Corners

For corners still running, check **two sources** — `proc_time.log` only records completed stages,
so the corner may have moved past the last recorded stage into a phase that doesn't emit TimeStamp
entries (notably `output_reports` / `-fct_reports`).

### 3a. Last completed stage (proc_time.log)

```bash
c="<corner>"
grep "^TimeStamp" "$c/logs/proc_time.log" | tail -1
```

This shows the last **completed** stage name, incremental time, total elapsed time, memory usage,
and wall-clock timestamp.

**Important:** If the timestamp is hours old but the corner is still running, it has moved on to a
later phase that doesn't write TimeStamp entries (typically `output_reports`).

### 3b. Actual current activity (PT log tail)

To see what the corner is **actually doing right now**, check the tail of the PT log:

```bash
c="<corner>"
tail -5 "$c/logs/core_client.${c}.pt.log"
```

Look for `INTEL_INFO` lines with timestamps — these show the currently executing script or report
step (e.g., `vrf_reports.py`, `uarch.tcl`, `fct_report_timing_summary_nworst`).

### Combined check for all running corners:

```bash
cd runs/core_client/n2p_htall_conf4/sta_pt/
corners=$(ls -d */ | sed 's/\/$//' \
  | grep -v -E '^(dmsa|inputs|logs|outputs|reports|scripts)$' \
  | grep -v '\.ct[0-9]*$')

for c in $corners; do
  ptlog="$c/logs/core_client.${c}.pt.log"
  if [ -f "$ptlog" ] && tail -50 "$ptlog" | grep -q "Thank you for using pt_shell!"; then
    continue  # skip completed corners
  fi
  echo "=== $c ==="
  # Last completed stage from proc_time.log
  last_ts=$(grep "^TimeStamp" "$c/logs/proc_time.log" 2>/dev/null | tail -1)
  stage=$(echo "$last_ts" | grep -oP 'TimeStamp : \S+' | sed 's/TimeStamp : //')
  ts_time=$(echo "$last_ts" | grep -oP '\w+ \w+ \d+ \d+:\d+:\d+ \d+$')
  echo "  Last completed stage: $stage ($ts_time)"
  # Actual current activity from PT log
  cur=$(tail -3 "$ptlog" 2>/dev/null | grep -oP '\[.*?\]' | tail -1)
  echo "  PT log activity as of: $cur"
  tail -1 "$ptlog" 2>/dev/null | sed 's/^/  /' | cut -c1-120
  echo
done
```

### Example output:
```
TimeStamp : read_constraints - Incr : 01h:09m:28s (06h:23m:28s) Total : 01h:25m:00s (07h:19m:23s) Mem : 62.7GB PeakMem : 68.9GB ...
```

## Step 4: Get Full Runtime

The total runtime is in the last `TimeStamp` line of `proc_time.log`:

```bash
cd runs/core_client/n2p_htall_conf4/sta_pt/
corners=$(ls -d */ | sed 's/\/$//' \
  | grep -v -E '^(dmsa|inputs|logs|outputs|reports|scripts)$' \
  | grep -v '\.ct[0-9]*$')

for c in $corners; do
  proclog="$c/logs/proc_time.log"
  if [ -f "$proclog" ]; then
    total=$(grep "^TimeStamp" "$proclog" | tail -1 | grep -oP 'Total : \S+' | sed 's/Total : //')
    echo "$c | $total"
  else
    echo "$c | no proc_time.log"
  fi
done
```

## Step 5: Check if XLS Report is Ready

For corners not yet done, you may want to know if the xlsx indicator table has already been generated:

```bash
ls <corner>/reports/csv/indicator_table_*.xlsx 2>/dev/null
```

## All-in-One Script

Combines status, runtime, current stage (if running), and XLS readiness:

```bash
cd runs/core_client/n2p_htall_conf4/sta_pt/
corners=$(ls -d */ | sed 's/\/$//' \
  | grep -v -E '^(dmsa|inputs|logs|outputs|reports|scripts)$' \
  | grep -v '\.ct[0-9]*$')

for c in $corners; do
  ptlog="$c/logs/core_client.${c}.pt.log"
  proclog="$c/logs/proc_time.log"

  # Status
  if [ -f "$ptlog" ] && tail -50 "$ptlog" | grep -q "Thank you for using pt_shell!"; then
    status="DONE"
  else
    status="RUNNING"
  fi

  # Runtime & stage from proc_time.log
  if [ -f "$proclog" ]; then
    last_ts=$(grep "^TimeStamp" "$proclog" | tail -1)
    total=$(echo "$last_ts" | grep -oP 'Total : \S+' | sed 's/Total : //')
    stage=$(echo "$last_ts" | grep -oP 'TimeStamp : \S+' | sed 's/TimeStamp : //')
  else
    total="N/A"; stage="N/A"
  fi

  # For running corners: check PT log tail for actual current activity
  # (proc_time.log only shows last completed stage, not current activity)
  actual_activity=""
  xlsx=""
  if [ "$status" = "RUNNING" ]; then
    if [ -f "$ptlog" ]; then
      actual_activity=$(tail -1 "$ptlog" | sed 's/^[[:space:]]*//' | cut -c1-80)
    fi
    if ls "$c/reports/csv/indicator_table_"*.xlsx &>/dev/null; then
      xlsx="XLS_READY"
    else
      xlsx="XLS_NOT_READY"
    fi
  fi

  if [ -n "$actual_activity" ]; then
    echo "$status | $c | Runtime: $total | Last stage: $stage | Now: $actual_activity $xlsx"
  else
    echo "$status | $c | Runtime: $total | Stage: $stage $xlsx"
  fi
done
```

## Key Identifiers

| What | Where to Look |
|------|---------------|
| Corner done? | `"Thank you for using pt_shell!"` in PT log |
| Last completed stage | Last `TimeStamp` line in `proc_time.log` (only records completed stages) |
| Actual current activity | `tail` of PT log — shows live script/report being executed |
| Total runtime | `Total :` field in last `TimeStamp` line of `proc_time.log` |
| XLS ready? | `<corner>/reports/csv/indicator_table_*.xlsx` exists |
| PT log | `<corner>/logs/core_client.<corner>.pt.log` |
| Timing log | `<corner>/logs/proc_time.log` |

---

## Clock Period Relaxation

To calculate relaxed clock periods (e.g. 3% relaxation) for all max corners:

```bash
wa="<work_area>"
block=$(grep -w block $wa/env_vars.rpt | awk -F'=' '{print $2}')
for cor in $(ls -d $wa/runs/$block/$tech/$flow/func.max_* 2>/dev/null | xargs -n1 basename | sort); do
    clk_file="$wa/runs/$block/$tech/$flow/$cor/outputs/${block}_clock_params.$cor.debug.propagate_clock_1.tcl"
    ct=$(grep "periodCache(mclk_pll," "$clk_file" 2>/dev/null | awk '{print $NF}')
    if [ -n "$ct" ]; then
        new_ct=$(python3 -c "import math; print(math.ceil($ct * 1.03 / 2) * 2)")
        echo "$cor | CT=$ct | +3%=$new_ct (rounded to even)"
    fi
done
```

Formula: `new_CT = ceil(CT × 1.03 / 2) × 2` (round up to nearest even number)

### Reference: Max Corner Clock Periods (FCT26WW13A)

| Corner | CT (ps) | +3% even (ps) |
|--------|---------|----------------|
| func.max_fast.F_125.rcworst_CCworst_T | 182 | 188 |
| func.max_hi_hi_lo.T_85.typical | 180 | 186 |
| func.max_hi_lo_hi.T_85.typical | 180 | 186 |
| func.max_high.T_85.typical | 186 | 192 |
| func.max_lo_hi_hi.T_85.typical | 384 | 396 |
| func.max_low.T_85.typical | 384 | 396 |
| func.max_med.T_85.typical | 212 | 218 |
| func.max_nom.T_85.typical | 284 | 292 |
| func.max_slow_low.S_125.cworst_CCworst_T | 450 | 464 |
| func.max_slow_low_cold.S_M40.cworst_CCworst_T | 450 | 464 |
| func.max_slow_mid.S_125.cworst_CCworst_T | 400 | 412 |
| func.max_slow_rc_high.S_125.rcworst_CCworst_T | 206 | 212 |
| func.max_turbo.T_85.typical | 180 | 186 |

---

## Deep Runtime Analysis

### Runtime Breakdown from proc_time.log

`proc_time.log` contains `TimeStamp` lines for each stage with incremental and total times.
Parse all stages and their durations:

```bash
grep "^TimeStamp" <corner>/logs/proc_time.log
```

Each line has:
```
TimeStamp : <stage_name> - Incr : <incr_time> (<wall_incr>) Total : <total_time> (<wall_total>) Mem : <mem> PeakMem : <peak> ...
```

### Typical Stage Breakdown (func.max_low example, 13h:47m total)

| Stage                   | Incr Time  | % of Total | Mem     | Notes                    |
|-------------------------|------------|------------|---------|--------------------------|
| link_design             |   0h:06m   |    0.7%    |  32.1GB |                          |
| read_constraints        |   0h:51m   |    6.2%    |  58.6GB |                          |
| update_timing           |   3h:59m   |   28.8%    | 211.0GB | Core timing engine       |
| save_session            |   0h:16m   |    1.9%    | 201.7GB |                          |
| -fct_reports            |   7h:08m   |   51.5%    | 257.2GB | Dominates runtime        |
| -fct_debit              |   1h:09m   |    8.3%    | 268.5GB |                          |
| -gen_sta_report         |   0h:08m   |    1.0%    | 257.9GB |                          |
| output_reports (total)  |   8h:27m   |   61.0%    | Peak 299.6GB |                    |

**Top 3 consumers: `-fct_reports` (51.5%), `update_timing` (28.8%), `-fct_debit` (8.3%) = ~89% total**

### Deep Dive: gen_sta_report (inside output_reports)

The PT log contains `Start Section` / `End Section` markers with timestamps.
Extract sub-section durations:

```bash
grep "INTEL_INFO.*Start Section\|INTEL_INFO.*End Section" <corner>/logs/core_client.<corner>.pt.log
```

Within `output_reports`, `gen_sta_report` takes ~99% of the time. Its breakdown:

| Sub-task                          | Duration | % of gen_sta | Notes                      |
|-----------------------------------|----------|-------------|----------------------------|
| Report definitions/setup          |   <1min  |     <0.1%   |                            |
| fct_generate_hip_pwr_connectivity |   ~11min |      2.2%   |                            |
| **fct_report_timing_summary**     |   ~43min |      8.6%   | Regular XML (1.5M paths, nworst=1) |
| **fct_report_timing_summary_nworst** | **~5h:54m** | **70.2%** | Nworst XML (5M paths, nworst=100, PBA=path) |
| analyze_parasitics_annotation     |    ~1min |      0.2%   |                            |
| timing_summary_link + fishtail    | ~1h:17m  |     15.3%   | Cross-clocks, indicators, filtering |

**The nworst XML generation dominates** — 5h:54m (70%) of gen_sta_report time.

### Key Report Parameters

| Report             | max_paths | nworst | PBA mode | Typical Duration |
|--------------------|-----------|--------|----------|-----------------|
| Regular XML        | 1,500,000 | 1      | path     | ~43min          |
| Nworst XML         | 5,000,000 | 100    | path     | ~5h:54m         |

### Output File Locations

```
# Regular XML timing summary:
<corner>/reports/core_client.<corner>_timing_summary.xml

# Nworst XML timing summary:
<corner>/reports/core_client.<corner>_timing_summary.nworst.xml

# Filtered versions (with .filtered suffix):
<corner>/reports/core_client.<corner>_timing_summary.xml.filtered
<corner>/reports/core_client.<corner>_timing_summary.nworst.xml.filtered
```

### How to Identify Runtime Bottlenecks

1. **Check proc_time.log** for top-level stage breakdown
2. If `output_reports` / `-fct_reports` dominates, dig into PT log section markers
3. Look for `fct_report_timing_summary_nworst` — usually the biggest consumer
4. The nworst XML runtime scales with path count × nworst value × PBA complexity
5. Memory typically peaks during output_reports (can hit 300GB+)

#!/usr/bin/env python3
"""
Compress timing report XML files by simplifying startpoint/endpoint names,
deduplicating by unique SP/EP pairs (keeping worst slack), and optionally
querying a PT server for detailed PBA timing reports.

Usage:
    python3 compress_timing_rpt.py <input.rpt> [output.rpt] [--pba] [--model MODEL] [--parallel N]

Options:
    --pba          Query PT server for detailed PBA timing of each unique path
    --model MODEL  PT server model name (default: modelb_gfcn2clienta0_bu_prp_<corner>)
                   <corner> is auto-detected from the input file path
    --parallel N   Number of parallel PT queries (default: 20)

If output is not specified, writes to <input>.compressed.rpt

Transformations applied:
  1. Strip hierarchy from startpoint/endpoint - keep only register name
  2. Simplify MBIT names:
     - Same sequential: keep base register name only
     - Different sequentials: keep all unique base names (MBIT_name1_MBIT_name2)
  3. Strip register bit indices (e.g., _reg_119_ -> _reg)
  4. For data_array_reg and non-_reg endpoints/startpoints: keep n-1 hierarchy
  5. Remove _clone/_clone_N suffixes
  6. Replace index numbers with * (preserving signal name numbers like M202H)
  7. Deduplicate: keep only worst slack per unique SP/EP pair
  8. Add summary header (id, slack, startpoint, endpoint)
  9. (Optional) Append detailed PBA timing reports from PT server
"""

import re
import sys
import os
import subprocess
import time
import argparse

PT_CLIENT = "/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/pt_client.pl"
PIN_PATTERN = re.compile(r'^[A-Z][A-Z]?[0-9]?$')


def is_pin(s):
    return bool(PIN_PATTERN.match(s))


def get_base(name):
    """Extract base register name up to and including _reg"""
    m = re.match(r'^(.*?_reg)', name)
    return m.group(1) if m else name


def replace_numbers(name):
    """Replace index-like numbers with * while preserving signal name numbers."""
    name = re.sub(r'\[\d+\]', '[*]', name)
    name = re.sub(r'_(\d+)__', '_*__', name)
    name = re.sub(r'_(\d+)_', '_*_', name)
    name = re.sub(r'_(\d+)_', '_*_', name)  # second pass for overlapping
    name = re.sub(r'_(\d+)$', '_*', name)
    name = re.sub(r'(INST)(\d+)', r'\1*', name)
    return name


def remove_clones(name):
    """Remove _clone and _clone_N suffixes."""
    return re.sub(r'(_clone(_\d+)?)+', '', name)


def simplify_path(full_path):
    """
    Simplify a startpoint or endpoint path:
    - Strip hierarchy, keep register name
    - Simplify MBIT names
    - Strip register indices
    - Add n-1 hierarchy for data_array_reg and non-_reg paths
    - Remove clones
    - Replace index numbers with *
    """
    parts = full_path.split('/')

    # Determine if last component is a cell pin (D, CP, E, etc.)
    if len(parts) >= 2 and is_pin(parts[-1]):
        reg_name = parts[-2]
        parent_idx = -3
    else:
        # Hierarchical port - last component IS the port/endpoint name
        reg_name = parts[-1]
        parent_idx = -2

    # Always keep n-1 hierarchy for all paths
    needs_parent = True

    parent = parts[parent_idx] if len(parts) >= abs(parent_idx) + 1 and needs_parent else None

    # Handle MBIT names
    mbit_parts = reg_name.split('_MBIT_')
    if len(mbit_parts) > 1:
        constituents = mbit_parts[1:]  # skip prefix (e.g., auto_vector)
        seen = set()
        unique_bases = []
        for c in constituents:
            base = get_base(c)
            if base not in seen:
                seen.add(base)
                unique_bases.append(base)
        if len(unique_bases) == 1:
            result = unique_bases[0]
        else:
            # Different sequentials - keep all unique base names
            result = 'MBIT_' + '_MBIT_'.join(unique_bases)
    else:
        result = get_base(reg_name) if '_reg' in reg_name else reg_name

    # Add parent hierarchy where needed
    if parent:
        result = f'{parent}/{result}'

    result = remove_clones(result)
    result = replace_numbers(result)
    return result


def detect_corner(input_file):
    """Auto-detect timing corner from file path."""
    # Look for corner pattern like func.max_high.T_85.typical
    m = re.search(r'(func\.\w+\.\w+\.\w+)', input_file)
    if m:
        return m.group(1)
    m = re.search(r'(fresh\.\w+\.\w+\.\w+)', input_file)
    if m:
        return m.group(1)
    return None


def query_pt_pba(paths, model, parallel=20):
    """
    Query PT server for detailed PBA timing reports.
    paths: list of (index, orig_sp, orig_ep) tuples
    Returns: dict of {index: report_text}
    """
    total = len(paths)
    results = {}
    completed = 0
    failed = 0
    start_time = time.time()

    for batch_start in range(0, total, parallel):
        batch = paths[batch_start:batch_start + parallel]
        procs = []
        for idx, sp, ep in batch:
            cmd = ('report_timing -from [get_pins %s] -to [get_pins %s] '
                   '-pba_mode path -nosplit -significant_digits 2 '
                   '-transition_time -input_pins -capacitance -include_hierarchical_pins -physical') % (sp, ep)
            p = subprocess.Popen(
                [PT_CLIENT, '-m', model, '-c', cmd],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )
            procs.append((idx, p))

        for idx, p in procs:
            stdout, stderr = p.communicate()
            output = stdout.decode() + stderr.decode()
            if 'slack' in output.lower():
                results[idx] = output
                completed += 1
            else:
                failed += 1

        elapsed = time.time() - start_time
        done = batch_start + len(batch)
        rate = done / elapsed if elapsed > 0 else 0
        eta = (total - done) / rate if rate > 0 else 0
        print('  Progress: %d/%d (%d ok, %d fail) ETA: %.1fm'
              % (done, total, completed, failed, eta / 60), flush=True)

    elapsed_total = (time.time() - start_time) / 60
    print('  Completed: %d ok, %d failed, %.1f min' % (completed, failed, elapsed_total))
    return results


def compress_report(input_file, output_file, pba=False, model=None, parallel=20,
                    slack_threshold=None):
    print(f'Reading: {input_file}')
    with open(input_file, 'r') as f:
        lines = f.readlines()

    orig_count = len(lines)
    orig_size = os.path.getsize(input_file)
    print(f'  Lines: {orig_count:,}  Size: {orig_size:,} bytes ({orig_size/1024/1024:.1f} MB)')

    # Parse all original paths (needed for PBA queries)
    orig_paths = {}
    for line in lines:
        pid = re.search(r'path_id="(\d+)"', line)
        sp = re.search(r'startpoint="([^"]+)"', line)
        ep = re.search(r'endpoint="([^"]+)"', line)
        sl = re.search(r' slack="([^"]+)"', line)
        int_ext = re.search(r'int_ext="([^"]+)"', line)
        bpins = re.search(r'boundary_pins="([^"]*)"', line)
        if pid and sp and ep and sl:
            orig_paths[pid.group(1)] = {
                'sp': sp.group(1), 'ep': ep.group(1), 'slack': float(sl.group(1)),
                'ext': int_ext.group(1) == 'external' if int_ext else False,
                'boundary_pins': bpins.group(1) if bpins else ''
            }

    # Deduplicate: for each unique simplified SP/EP pair, keep the path_id with worst slack
    # Also accumulate TNS (total negative slack) per bucket
    best = {}  # (simplified_sp, simplified_ep) -> (slack, path_id, orig_sp, orig_ep, ext, boundary_pins)
    tns = {}   # (simplified_sp, simplified_ep) -> total negative slack
    for pid, info in orig_paths.items():
        simp_sp = simplify_path(info['sp'])
        simp_ep = simplify_path(info['ep'])
        key = (simp_sp, simp_ep)
        if key not in best or info['slack'] < best[key][0]:
            best[key] = (info['slack'], pid, info['sp'], info['ep'],
                         info['ext'], info['boundary_pins'])
        if info['slack'] < 0:
            tns[key] = tns.get(key, 0) + info['slack']

    # Sort by slack (most negative first)
    sorted_pairs = sorted(best.items(), key=lambda x: x[1][0])

    # Write summary header
    with open(output_file, 'w') as f:
        f.write('%-6s %8s %10s %-4s %-80s %-80s %s\n' % ('id', 'slack', 'tns', 'type', 'startpoint', 'endpoint', 'port'))
        f.write('-' * 210 + '\n')
        for i, (key, (slack, pid, orig_sp, orig_ep, ext, bpins)) in enumerate(sorted_pairs, 1):
            simp_sp, simp_ep = key
            path_type = 'ext' if ext else 'int'
            bucket_tns = tns.get(key, 0)
            # Extract port name from boundary_pins: "{port1} {port2}" -> last component
            port = ''
            if ext and bpins:
                # Handle both formats:
                #   With braces: "{port1} {port2}"
                #   Without braces: "port1 port2"
                port_match = re.search(r'\{([^}]+)\}', bpins)
                if port_match:
                    port_full = port_match.group(1)
                else:
                    # Space-separated, take first port
                    port_full = bpins.strip().split()[0] if bpins.strip() else ''
                if port_full:
                    port = port_full.split('/')[-1]
                    port = replace_numbers(port)
            f.write('%-6d %8.0f %10.0f %-4s %-80s %-80s %s\n' % (i, slack, bucket_tns, path_type, simp_sp, simp_ep, port))

    unique_count = len(sorted_pairs)
    new_size = os.path.getsize(output_file)
    print(f'\nSummary written: {unique_count} unique SP/EP pairs')
    print(f'  Size: {orig_size:,} -> {new_size:,} bytes ({new_size/1024/1024:.1f} MB)')
    print(f'  Reduction: {(1 - new_size/orig_size)*100:.1f}%')

    # PBA detailed timing
    if pba:
        if not model:
            corner = detect_corner(input_file)
            if corner:
                model = 'modelb_gfcn2clienta0_bu_prp_' + corner
                print(f'\nAuto-detected PT model: {model}')
            else:
                print('\nError: Could not detect corner. Use --model to specify.')
                return

        pt_paths = []
        for i, (key, (slack, pid, orig_sp, orig_ep, ext, bpins)) in enumerate(sorted_pairs, 1):
            if slack_threshold is not None and slack > slack_threshold:
                continue
            pt_paths.append((i, orig_sp, orig_ep))

        if not pt_paths:
            print(f'\nNo paths meet slack threshold ({slack_threshold}). Skipping PBA queries.')
            return

        print(f'\nQuerying PT server for {len(pt_paths)} PBA paths '
              f'(slack <= {slack_threshold if slack_threshold is not None else "all"}, '
              f'{parallel} parallel)...')

        results = query_pt_pba(pt_paths, model, parallel)

        # Append detailed reports
        with open(output_file, 'a') as f:
            f.write('\n' + '=' * 160 + '\n')
            f.write('DETAILED TIMING REPORTS (PBA mode) - %d paths\n' % len(results))
            f.write('=' * 160 + '\n\n')
            for i in range(1, unique_count + 1):
                if i in results:
                    f.write('--- Path id %d ---\n' % i)
                    f.write(results[i])
                    f.write('\n')

        final_size = os.path.getsize(output_file)
        final_lines = sum(1 for _ in open(output_file))
        print(f'\nFinal output: {output_file}')
        print(f'  {final_lines:,} lines, {final_size/1024/1024:.1f} MB')
        print(f'  {len(results)} detailed PBA reports appended')
    else:
        print(f'\nOutput: {output_file}')


def main():
    parser = argparse.ArgumentParser(
        description='Compress timing report XML and optionally add PBA detailed timing')
    parser.add_argument('input', help='Input timing report file (.rpt)')
    parser.add_argument('output', nargs='?', default=None,
                        help='Output file (default: <input>.compressed.rpt)')
    parser.add_argument('--pba', action='store_true',
                        help='Query PT server for detailed PBA timing')
    parser.add_argument('--model', default=None,
                        help='PT server model name (auto-detected from corner if omitted)')
    parser.add_argument('--parallel', type=int, default=20,
                        help='Number of parallel PT queries (default: 20)')
    parser.add_argument('--slack', type=float, default=None,
                        help='Slack threshold for PBA queries (e.g., -20). '
                             'Only paths with slack <= threshold get detailed reports')
    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f'Error: {args.input} not found')
        sys.exit(1)

    if args.output:
        output_file = args.output
    else:
        base, ext = os.path.splitext(args.input)
        output_file = f'{base}.compressed{ext}'

    compress_report(args.input, output_file, pba=args.pba,
                    model=args.model, parallel=args.parallel,
                    slack_threshold=args.slack)


if __name__ == '__main__':
    main()

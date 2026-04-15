#!/usr/bin/env python3
"""
model_timing_status.py - Fast timing status summary across corners and partitions.

Optimized replacement for model_timing_status_v2.csh and model_timing_status_v2_nworst.csh.
Key speedup: each XML file is parsed once (single pass) instead of
6 greps × N_partitions per file.

Usage:
    python3 model_timing_status.py <work_area> [--out <output.csv>]
    python3 model_timing_status.py <work_area> --nworst [--out <output.csv>]

Environment variables required: tech, flow, ward, PROJECT_STEPPING
"""

import os
import sys
import re
import argparse
import subprocess
from collections import defaultdict
from pathlib import Path


def parse_xml_file(xml_path, partitions):
    """Parse a timing summary XML in one pass, extracting WNS/TNS/FEP per partition and int_ext type.

    Matches original csh behavior: grep 'int_ext="<type>".*<partition>/' counts a line
    for every partition name that appears ANYWHERE in the line (startpoint, endpoint,
    blocks_impacted, boundary_pins). For external paths, the same line contributes
    to multiple partitions.
    """
    results = {}  # (partition, int_ext) -> { 'wns': int, 'tns': int, 'fep': int }

    if not os.path.isfile(xml_path):
        return results

    slack_pat = re.compile(r'(?<![a-z_])slack="([^"]*)"')
    int_ext_pat = re.compile(r'int_ext="([^"]*)"')

    with open(xml_path, 'r') as f:
        for line in f:
            m_ext = int_ext_pat.search(line)
            if not m_ext:
                continue
            int_ext = m_ext.group(1)

            # Extract the 'slack' attribute (not normalized_slack)
            # Original uses: awk -F '"' '{print $4}' which is the 2nd quoted value = slack
            # Find all key="value" pairs to get the right one
            m_slack = slack_pat.search(line)
            if not m_slack:
                continue
            try:
                slack = int(round(float(m_slack.group(1))))
            except ValueError:
                continue

            # Match original: grep 'int_ext="...".*par_xxx/' matches if par_xxx/ appears anywhere
            for par in partitions:
                if par + '/' in line:
                    key = (par, int_ext)
                    if key not in results:
                        results[key] = {'wns': None, 'tns': 0, 'fep': 0}

                    entry = results[key]
                    entry['fep'] += 1
                    entry['tns'] += slack
                    if entry['wns'] is None or slack < entry['wns']:
                        entry['wns'] = slack

    return results


def get_clock_periods(clock_file, nworst=False):
    """Extract clock periods from propagate_clock tcl file.

    v2 uses 'periodCache.*mclk_pll,' (comma = exact match, single value).
    nworst uses 'periodCache.*mclk_pll' (no comma = matches mclk_pll AND mclk_pll_ext).
    csh collects all matches into a space-separated list.
    """
    periods = {'mclk': [], 'uclk': [], 'sbclk': [], 'npkclk': []}
    if not os.path.isfile(clock_file):
        return {k: '' for k in periods}

    # nworst matches 'mclk_pll' (catches mclk_pll and mclk_pll_ext)
    # v2 matches 'mclk_pll,' (only exact mclk_pll)
    mclk_pattern = 'mclk_pll' if nworst else 'mclk_pll,'

    with open(clock_file, 'r') as f:
        for line in f:
            if 'periodCache' not in line:
                continue
            val = line.split()[-1]
            if mclk_pattern in line:
                periods['mclk'].append(val)
            elif 'uclk,' in line:
                periods['uclk'].append(val)
            elif 'sbclk,' in line:
                periods['sbclk'].append(val)
            elif 'npkclk,' in line:
                periods['npkclk'].append(val)
    return {k: ' '.join(v) for k, v in periods.items()}


def get_voltages(pvt_file, pvt_profile):
    """Extract vcccore, vccring, vccst from pvt.tcl."""
    voltages = {'vcccore': '', 'vccring': '', 'vccst': ''}
    if not os.path.isfile(pvt_file) or not pvt_profile:
        return voltages

    # Use word boundary match like original grep -w
    pat = re.compile(r'\bvolt_for_supply_rails\b.*\b' + re.escape(pvt_profile) + r'\b')
    with open(pvt_file, 'r') as f:
        for line in f:
            if pat.search(line):
                parts = line.split('"')
                # Format: "VSS 0" "VCCCORE 0.540" "VCCRING 0.540" "VCCST 0.675" ...
                # Index:    1       3                5                7
                try:
                    voltages['vcccore'] = parts[3].split()[1] if len(parts) > 3 and len(parts[3].split()) > 1 else ''
                    voltages['vccring'] = parts[5].split()[1] if len(parts) > 5 and len(parts[5].split()) > 1 else ''
                    voltages['vccst'] = parts[7].split()[1] if len(parts) > 7 and len(parts[7].split()) > 1 else ''
                except (IndexError, ValueError):
                    pass
                break
    return voltages


def get_priority(priority_file, corner):
    """Get priority from pvt.csv. Uses whole-word match like grep -w."""
    if not os.path.isfile(priority_file):
        return ''
    with open(priority_file, 'r') as f:
        for line in f:
            fields = line.strip().split(',')
            # Match whole word: corner must be an exact field
            if len(fields) >= 3 and corner in fields:
                return fields[2]
    return ''


def get_delay_type(pvt_file, corner):
    """Get min_or_max from pvt.tcl scenario_delay_type_map. Uses whole-word match."""
    if not os.path.isfile(pvt_file):
        return ''
    pat = re.compile(r'\bscenario_delay_type_map\b.*\b' + re.escape(corner) + r'\b')
    with open(pvt_file, 'r') as f:
        for line in f:
            if pat.search(line):
                parts = line.split('"')
                if len(parts) >= 5:
                    return parts[3]
    return ''


def check_server_availability(corner):
    """Check if PT server is available for this corner."""
    aliases_file = '/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/aliases_for_pt_client'
    if not os.path.isfile(aliases_file):
        return '0'
    count = 0
    with open(aliases_file, 'r') as f:
        for line in f:
            if 'gfcn2clienta0b' in line and 'modelb' in line and corner in line:
                count += 1
    return str(count)


def main():
    parser = argparse.ArgumentParser(description='Fast timing status summary')
    parser.add_argument('work_area', help='Path to work area')
    parser.add_argument('--out', help='Output CSV path (default: $ward/model_timing_status_<WW>.csv)')
    parser.add_argument('--nworst', action='store_true',
                        help='Use nworst XML reports (single type, no voltages, excludes .ct corners)')
    args = parser.parse_args()

    nworst = args.nworst

    wa = os.path.realpath(args.work_area)

    # Read environment variables
    ward = os.environ.get('ward', '')
    project_stepping = os.environ.get('PROJECT_STEPPING', '')

    # Read work area config - parse exact key=value pairs
    env_vars_file = os.path.join(wa, 'env_vars.rpt')
    env_vars = {}
    if os.path.isfile(env_vars_file):
        with open(env_vars_file, 'r') as f:
            for line in f:
                if '=' in line:
                    key, val = line.strip().split('=', 1)
                    env_vars[key.strip()] = val.strip()

    wa_block = env_vars.get('block', '')
    workweek = env_vars.get('WW', '')
    tech = os.environ.get('tech', '') or env_vars.get('tech', '')
    flow = os.environ.get('flow', '') or env_vars.get('flow', '')

    # Get partitions
    runs_dir = os.path.join(wa, 'runs')
    partitions = sorted([d for d in os.listdir(runs_dir) if d.startswith('par_')]) if os.path.isdir(runs_dir) else []
    partitions_set = set(partitions)

    # Get corners - use ls -ltr ordering (by modification time) to match original
    corner_base = os.path.join(wa, 'runs', wa_block, tech, flow)
    corners = []
    if os.path.isdir(corner_base):
        # XML suffix depends on mode
        if nworst:
            xml_suffix = '_timing_summary.nworst.xml.filtered'
            corner_exclude = re.compile(r'noise|rv_em|.ct')
        else:
            xml_suffix = '_timing_summary_no_dfx.xml.filtered'
            corner_exclude = re.compile(r'noise|rv_em')

        corner_dirs = []
        for d in os.listdir(corner_base):
            full = os.path.join(corner_base, d)
            if os.path.isdir(full) and not corner_exclude.search(d):
                xml_check = os.path.join(full, 'reports',
                    f'{wa_block}.{d}{xml_suffix}')
                if os.path.isfile(xml_check):
                    corner_dirs.append((os.path.getmtime(xml_check), d))
        # nworst: alphabetical sort (original pipes through |sort)
        # v2: modification-time sort (original uses ls -ltr without final sort)
        if nworst:
            corners = sorted(d for _, d in corner_dirs)
        else:
            corners = [d for _, d in sorted(corner_dirs)]

    # Setup files
    pvt_file = os.path.join(wa, 'project', project_stepping, 'pvt.tcl')
    # nworst uses $ward for priority file, standard uses $wa
    if nworst:
        priority_file = os.path.join(ward, 'project', project_stepping, 'pvt.csv')
    else:
        priority_file = os.path.join(wa, 'project', project_stepping, 'pvt.csv')

    # Output file
    if nworst:
        out_csv = args.out or os.path.join(ward, f'model_timing_status_nworst_{workweek}.csv')
    else:
        out_csv = args.out or os.path.join(ward, f'model_timing_status_{workweek}.csv')

    print(f"taking data from wa: {wa}")
    if nworst:
        print(f"corners: {len(corners)}, partitions: {len(partitions)}, mode: nworst")
    else:
        print(f"corners: {len(corners)}, partitions: {len(partitions)}, types: 2")

    # Pre-read server availability per corner (one pass over aliases file)
    # Original: grep "gfcn2clienta0b.*modelb.*$cor " | sort -u | wc -l
    aliases_file = '/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/aliases_for_pt_client'
    server_count = defaultdict(int)
    if os.path.isfile(aliases_file):
        seen = set()
        with open(aliases_file, 'r') as f:
            for line in f:
                if 'gfcn2clienta0b' not in line or 'modelb' not in line:
                    continue
                for cor in corners:
                    if f'{cor} ' in line:
                        key = (cor, line.strip())
                        if key not in seen:
                            seen.add(key)
                            server_count[cor] += 1

    # Pre-read priorities and delay types (one pass each)
    priorities = {}
    delay_types = {}
    for cor in corners:
        priorities[cor] = get_priority(priority_file, cor)
        delay_types[cor] = get_delay_type(pvt_file, cor)

    # Write CSV
    with open(out_csv, 'w') as out:
        if nworst:
            out.write('#corner,priorty,min_or_max,type_xml,mclk_ct,type,par,'
                      'internal_wns,internal_tns,int_FEP,'
                      'external_wns,external_tns,ext_FEP,'
                      'ifc_external_wns,ifc_external_tns,ifc_FEP,have_server\n')
        else:
            out.write('#corner,priorty,min_or_max,type_xml,mclk_ct,uclk_ct,sbclk_ct,npkclk_ct,'
                      'vcccore,vccring,vccst,par,internal_wns,internal_tns,int_FEP,'
                      'external_wns,external_tns,ext_FEP,'
                      'ifc_external_wns,ifc_external_tns,ifc_FEP,have_server\n')

        for cor in corners:
            print(f"  {cor}")

            # Clock periods (read once per corner)
            clock_file = os.path.join(corner_base, cor, 'outputs',
                f'{wa_block}_clock_params.{cor}.debug.propagate_clock_1.tcl')
            periods = get_clock_periods(clock_file, nworst=nworst)

            # Voltages (read once per corner, skip for nworst)
            if not nworst:
                pvt_profile = cor.split('.')[1] if '.' in cor else ''
                voltages = get_voltages(pvt_file, pvt_profile)

            # XML types to process
            if nworst:
                xml_types = [('nworst', '_timing_summary.nworst.xml.filtered')]
            else:
                xml_types = [('no_dfx', '_timing_summary_no_dfx.xml.filtered'),
                             ('only_dfx', '_timing_summary_only_dfx.xml.filtered')]

            for type_xml, suffix in xml_types:
                xml_path = os.path.join(corner_base, cor, 'reports',
                    f'{wa_block}.{cor}{suffix}')

                xml_data = parse_xml_file(xml_path, partitions_set)

                for par in partitions:
                    def get_val(int_ext_type):
                        entry = xml_data.get((par, int_ext_type), {})
                        wns = entry.get('wns', None)
                        tns = entry.get('tns', 0)
                        fep = entry.get('fep', 0)
                        if wns is not None:
                            wns_s = str(wns)
                            tns_s = str(tns)
                        else:
                            wns_s = ''
                            tns_s = ''
                        return wns_s, tns_s, str(fep)

                    int_wns, int_tns, int_fep = get_val('internal')
                    ext_wns, ext_tns, ext_fep = get_val('external')
                    ifc_wns, ifc_tns, ifc_fep = get_val('ifc_external')

                    if nworst:
                        row = ','.join([
                            cor, priorities.get(cor, ''), delay_types.get(cor, ''),
                            type_xml, periods['mclk'], 'all',
                            par,
                            int_wns, int_tns, int_fep,
                            ext_wns, ext_tns, ext_fep,
                            ifc_wns, ifc_tns, ifc_fep,
                            str(server_count.get(cor, 0))
                        ])
                    else:
                        row = ','.join([
                            cor, priorities.get(cor, ''), delay_types.get(cor, ''),
                            type_xml,
                            periods['mclk'], periods['uclk'], periods['sbclk'], periods['npkclk'],
                            voltages['vcccore'], voltages['vccring'], voltages['vccst'],
                            par,
                            int_wns, int_tns, int_fep,
                            ext_wns, ext_tns, ext_fep,
                            ifc_wns, ifc_tns, ifc_fep,
                            str(server_count.get(cor, 0))
                        ])
                    out.write(row + '\n')

    print(f"Done. report at: {out_csv}")


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
GFC → JNC TIP .tp File Converter
Converts GFC (TSMC N2P) tp files to JNC (Intel 1278) format.
Uses PNC (same Intel 1278 process) as reference for process-specific items.

What changes:
  - Buffer cell name (NER)
  - Metal layer names (M17→m14, M18→m13, M16→m12, M15→m11, M14→m10)
  - NDR rule names and definitions (GFC→PNC equivalent)
  - Layer cutting distance values
  - Repeater height/width multipliers
  - Header metadata (NLIB, BUILD_DIR, etc.)
  - Shape layer wire widths

What stays:
  - Signal/net names, pin names, partition names (same RTL)
  - Topology node/edge structure
  - bbox_percentage, origin coordinates, repeater offsets (starting point)
  - Buffer spacing values (kept from GFC, needs JNC tuning)
"""

import os
import re
import sys
import shutil

# ═══════════════════════════════════════════════════════════════════
# PROCESS MAPPING TABLES
# ═══════════════════════════════════════════════════════════════════

GFC_BUFFER = "tcbn02p_bwph156nppnl3p48cpd_base_ulvt_c240429/BUFFSR2BFYD18BWP156HNPPN3P48CPDULVT"
JNC_BUFFER = "i0mbfn000ab1n36x5"

# Metal layer mapping: GFC (TSMC N2P, uppercase) → JNC (Intel 1278, lowercase)
LAYER_MAP = {
    "M18": "m13",
    "M17": "m14",
    "M16": "m12",
    "M15": "m11",
    "M14": "m10",
    "M13": "m9",
    "M12": "m8",
    "M11": "m7",
    "M10": "m6",
    "M9":  "m5",
    "M8":  "m4",
    "M7":  "m3",
    "M6":  "m2",
    "M5":  "m1",
    "M4":  "m0",
}

# NDR rule name mapping (GFC → JNC/PNC equivalent)
NDR_MAP = {
    "2w2s":                        "2w2s_m13_m14",
    "2w2s_M18_only":               "2w2s_m13_m14",
    "2p5w2s_M14_M16_1w3s_M15":    "1w7s_m11_1w3s_m12",
    "2p5w2s_M16":                  "1w7s_m11_1w3s_m12",
    "m17_4w3s_m18_4w4s":           "1w7s_m13_1w3s_m14",
}

# PNC routing rule definitions (complete replacement for create_routing_rule lines)
PNC_ROUTING_RULES = {
    "2w2s_m13_m14": '    create_routing_rule "2w2s_m13_m14" -widths {"bph" 4.5000 "bm5" 2.0000 "bm4" 0.5400 "bm3" 0.5400 "bm2" 0.2400 "bm1" 0.1600 "bm0" 0.0800 "m0" 0.0200 "m1" 0.0300 "m2" 0.0200 "m3" 0.0240 "m4" 0.0240 "m5" 0.0400 "m6" 0.0400 "m7" 0.0400 "m8" 0.0400 "m9" 0.0400 "m10" 0.0400 "m11" 0.0600 "m12" 0.0600 "m13" 0.0800 "m14" 0.0800} -spacings {"bph" {4.5000} "bm5" {2.0000} "bm4" {0.5400} "bm3" {0.5400} "bm2" {0.1400} "bm1" {0.1400} "bm0" {0.0800} "m0" {0.0160} "m1" {0.0200} "m2" {0.0160} "m3" {0.0160} "m4" {0.0160} "m5" {0.0400} "m6" {0.0400} "m7" {0.0400} "m8" {0.0400} "m9" {0.0400} "m10" {0.0400} "m11" {0.0600} "m12" {0.0600} "m13" {0.0800} "m14" {0.0800}} -spacing_weight_levels {"bph" {hard} "bm5" {hard} "bm4" {hard} "bm3" {hard} "bm2" {hard} "bm1" {hard} "bm0" {hard} "m0" {hard} "m1" {hard} "m2" {hard} "m3" {hard} "m4" {hard} "m5" {hard} "m6" {hard} "m7" {hard} "m8" {hard} "m9" {hard} "m10" {hard} "m11" {hard} "m12" {hard} "m13" {hard} "m14" {hard}} -multiplier_width 2 -multiplier_spacing 2 -ignore_spacing_to_pg false -ignore_spacing_to_blockage true -ignore_spacing_to_shield false',
    "1w7s_m11_1w3s_m12": '    create_routing_rule "1w7s_m11_1w3s_m12" -widths {"bph" 4.5000 "bm5" 2.0000 "bm4" 0.5400 "bm3" 0.5400 "bm2" 0.2400 "bm1" 0.1600 "bm0" 0.0800 "m0" 0.0200 "m1" 0.0300 "m2" 0.0200 "m3" 0.0240 "m4" 0.0240 "m5" 0.0400 "m6" 0.0400 "m7" 0.0400 "m8" 0.0400 "m9" 0.0400 "m10" 0.0400 "m11" 0.0600 "m12" 0.0600 "m13" 0.0800 "m14" 0.0800} -spacings {"m5" {0.0400} "m6" {0.0400} "m7" {0.0400} "m8" {0.0400} "m9" {0.0400} "m10" {0.0400} "m11" {0.4200} "m12" {0.1800} "m13" {0.0800} "m14" {0.0800}} -spacing_weight_levels {"m5" {hard} "m6" {hard} "m7" {hard} "m8" {hard} "m9" {hard} "m10" {hard} "m11" {hard} "m12" {hard} "m13" {hard} "m14" {hard}} -multiplier_width 1 -multiplier_spacing 1 -ignore_spacing_to_pg false -ignore_spacing_to_blockage true -ignore_spacing_to_shield false',
    "1w7s_m13_1w3s_m14": '    create_routing_rule "1w7s_m13_1w3s_m14" -widths {"bph" 4.5000 "bm5" 2.0000 "bm4" 0.5400 "bm3" 0.5400 "bm2" 0.2400 "bm1" 0.1600 "bm0" 0.0800 "m0" 0.0200 "m1" 0.0300 "m2" 0.0200 "m3" 0.0240 "m4" 0.0240 "m5" 0.0400 "m6" 0.0400 "m7" 0.0400 "m8" 0.0400 "m9" 0.0400 "m10" 0.0400 "m11" 0.0600 "m12" 0.0600 "m13" 0.0800 "m14" 0.0800} -spacings {"m5" {0.0400} "m6" {0.0400} "m7" {0.0400} "m8" {0.0400} "m9" {0.0400} "m10" {0.0400} "m11" {0.0600} "m12" {0.0600} "m13" {0.5600} "m14" {0.2400}} -spacing_weight_levels {"m5" {hard} "m6" {hard} "m7" {hard} "m8" {hard} "m9" {hard} "m10" {hard} "m11" {hard} "m12" {hard} "m13" {hard} "m14" {hard}} -multiplier_width 1 -multiplier_spacing 1 -ignore_spacing_to_pg false -ignore_spacing_to_blockage true -ignore_spacing_to_shield false',
    "1w3s_m13_m14": '    create_routing_rule "1w3s_m13_m14" -widths {"bph" 4.5000 "bm5" 2.0000 "bm4" 0.5400 "bm3" 0.5400 "bm2" 0.2400 "bm1" 0.1600 "bm0" 0.0800 "m0" 0.0200 "m1" 0.0300 "m2" 0.0200 "m3" 0.0240 "m4" 0.0240 "m5" 0.0400 "m6" 0.0400 "m7" 0.0400 "m8" 0.0400 "m9" 0.0400 "m10" 0.0400 "m11" 0.0600 "m12" 0.0600 "m13" 0.0800 "m14" 0.0800} -spacings {"bph" {4.5000} "bm5" {2.0000} "bm4" {0.5400} "bm3" {0.5400} "bm2" {0.1400} "bm1" {0.1400} "bm0" {0.0800} "m0" {0.0160} "m1" {0.0200} "m2" {0.0160} "m3" {0.0160} "m4" {0.0160} "m5" {0.0400} "m6" {0.0400} "m7" {0.0400} "m8" {0.0400} "m9" {0.0400} "m10" {0.0400} "m11" {0.0600} "m12" {0.0600} "m13" {0.0800} "m14" {0.0800}} -spacing_weight_levels {"bph" {hard} "bm5" {hard} "bm4" {hard} "bm3" {hard} "bm2" {hard} "bm1" {hard} "bm0" {hard} "m0" {hard} "m1" {hard} "m2" {hard} "m3" {hard} "m4" {hard} "m5" {hard} "m6" {hard} "m7" {hard} "m8" {hard} "m9" {hard} "m10" {hard} "m11" {hard} "m12" {hard} "m13" {hard} "m14" {hard}} -multiplier_width 1 -multiplier_spacing 3 -ignore_spacing_to_pg false -ignore_spacing_to_blockage true -ignore_spacing_to_shield false',
}

# Layer cutting distance: GFC → JNC
# GFC: {M18 0.5 0.5} {M17 0.5 0.5} / {M16 0.5 0.5} {M15 0.5 0.5}
# JNC: {m13 0.3 0.3} {m14 0.5 0.5} / {m11 0.3 0.3} {m12 0.5 0.5}

JNC_NLIB = "### JNC_NLIB_PATH_TBD ###"
JNC_BUILD_DIR = "### JNC_BUILD_DIR_TBD ###"


def convert_layer_name(match_text):
    """Replace GFC layer name with JNC equivalent in arbitrary text."""
    result = match_text
    # Sort by length descending to avoid M1 matching before M18
    for gfc_layer in sorted(LAYER_MAP.keys(), key=len, reverse=True):
        jnc_layer = LAYER_MAP[gfc_layer]
        # Use word-boundary-aware replacement
        result = re.sub(r'\b' + gfc_layer + r'\b', jnc_layer, result)
    return result


def convert_line(line, in_routing_rule_block, current_ndr_target):
    """Convert a single line from GFC to JNC format."""

    # ── Header comments ──
    if line.startswith('#| NLIB'):
        return f'#| NLIB              : {JNC_NLIB}\n', in_routing_rule_block, current_ndr_target
    if line.startswith('#| BUILD_DIR'):
        return f'#| BUILD_DIR         : {JNC_BUILD_DIR}\n', in_routing_rule_block, current_ndr_target
    if line.startswith('#| CTH_SETUP_CMD'):
        return '#| CTH_SETUP_CMD       : ### JNC_CTH_SETUP_TBD ###\n', in_routing_rule_block, current_ndr_target
    if line.startswith('#| TOOL EXECUTABLE'):
        return '#| TOOL EXECUTABLE   : ### JNC_TOOL_TBD ###\n', in_routing_rule_block, current_ndr_target
    if line.startswith('#| HOST'):
        return '#| HOST              : ### JNC_HOST_TBD ###\n', in_routing_rule_block, current_ndr_target
    if line.startswith('#| PROCEDURE'):
        return '#| PROCEDURE         : ### CONVERTED_FROM_GFC ###\n', in_routing_rule_block, current_ndr_target
    if line.startswith('#| PROC_SOURCE'):
        return '#| PROC_SOURCE       : ### CONVERTED_FROM_GFC ###\n', in_routing_rule_block, current_ndr_target

    # ── Skip comment-only lines (pass through) ──
    if line.startswith('#'):
        return line, in_routing_rule_block, current_ndr_target

    # ── Buffer cell replacement ──
    if GFC_BUFFER in line:
        line = line.replace(GFC_BUFFER, JNC_BUFFER)

    # ── NER layer replacement ──
    if 'parameter "layer"' in line:
        line = convert_layer_name(line)

    # ── NER NDR replacement ──
    if 'parameter "ndr"' in line:
        for gfc_ndr, jnc_ndr in NDR_MAP.items():
            if f'"{gfc_ndr}"' in line:
                line = line.replace(f'"{gfc_ndr}"', f'"{jnc_ndr}"')
                break

    # ── Repeater multipliers ──
    if 'repeater_height_multiplier' in line:
        line = re.sub(r'-value \{[^}]*\}', '-value {2}', line)
    if 'repeater_width_multiplier' in line:
        line = re.sub(r'-value \{[^}]*\}', '-value {1.2}', line)

    # ── Layer cutting distance ──
    if 'layer_cutting_distance' in line:
        line = convert_layer_name(line)
        # Update cutting values: horizontal layer gets 0.3, vertical gets 0.5
        # m13 (was M18, horizontal) → 0.3 0.3
        # m14 (was M17, vertical) → 0.5 0.5
        # m12 (was M16) → 0.3 0.3
        # m11 (was M15) → 0.5 0.5
        line = re.sub(r'\{m13 [0-9.]+ [0-9.]+\}', '{m13 0.3 0.3}', line)
        line = re.sub(r'\{m14 [0-9.]+ [0-9.]+\}', '{m14 0.5 0.5}', line)
        line = re.sub(r'\{m12 [0-9.]+ [0-9.]+\}', '{m12 0.3 0.3}', line)
        line = re.sub(r'\{m11 [0-9.]+ [0-9.]+\}', '{m11 0.5 0.5}', line)

    # ── Shape layers in edges ──
    if 'shape_layers' in line:
        line = convert_layer_name(line)

    # ── Routing rule block: replace entire create_routing_rule ──
    if 'create_routing_rule' in line:
        # Extract the rule name
        m = re.search(r'create_routing_rule "([^"]*)"', line)
        if m:
            gfc_rule = m.group(1)
            jnc_rule = NDR_MAP.get(gfc_rule, gfc_rule)
            if jnc_rule in PNC_ROUTING_RULES:
                return PNC_ROUTING_RULES[jnc_rule] + '\n', True, jnc_rule
            else:
                # Unknown rule — do layer name conversion
                line = convert_layer_name(line)

    # ── Routing rule references (get_routing_rules -quiet, set_routing_rule) ──
    if 'get_routing_rules -quiet' in line or 'set_routing_rule -rule' in line:
        for gfc_ndr, jnc_ndr in NDR_MAP.items():
            if f'"{gfc_ndr}"' in line:
                line = line.replace(f'"{gfc_ndr}"', f'"{jnc_ndr}"')
                break
    if 'NDR does not exist' in line:
        for gfc_ndr, jnc_ndr in NDR_MAP.items():
            if gfc_ndr in line:
                line = line.replace(gfc_ndr, jnc_ndr)
                break

    # ── sRDL / M19 / M20 cleanup (don't exist in Intel 1278) ──
    # These only appear in routing rules which we already replaced entirely

    return line, in_routing_rule_block, current_ndr_target


def convert_file(src_path, dst_path):
    """Convert a single GFC tp file to JNC format."""
    with open(src_path, 'r') as f:
        lines = f.readlines()

    converted = []
    in_routing_rule_block = False
    current_ndr_target = None
    changes = 0

    for line in lines:
        new_line, in_routing_rule_block, current_ndr_target = convert_line(
            line, in_routing_rule_block, current_ndr_target
        )
        if new_line != line:
            changes += 1
        converted.append(new_line)

    with open(dst_path, 'w') as f:
        f.writelines(converted)

    return changes


def main():
    src_dir = "/nfs/site/disks/idc_gfc_fct_td/GFC_TIP_WA/tip_files/GFCA0_26WW13_1"
    dst_dir = "/nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/jnc_converted"

    os.makedirs(dst_dir, exist_ok=True)

    tp_files = sorted([f for f in os.listdir(src_dir) if f.endswith('.tp')])
    print(f"Converting {len(tp_files)} GFC tp files → JNC format")
    print(f"Source: {src_dir}")
    print(f"Output: {dst_dir}")
    print("=" * 70)

    total_changes = 0
    for tp_file in tp_files:
        src = os.path.join(src_dir, tp_file)
        dst = os.path.join(dst_dir, tp_file)
        changes = convert_file(src, dst)
        total_changes += changes
        status = f"{changes} lines changed" if changes > 0 else "NO CHANGES"
        print(f"  {tp_file:<55s} {status}")

    print("=" * 70)
    print(f"Done: {len(tp_files)} files converted, {total_changes} total lines changed")
    print(f"\nOutput: {dst_dir}/")
    print(f"\n⚠️  Items marked ### TBD ### need JNC-specific values from Basel/Kris:")
    print(f"    - JNC_NLIB_PATH_TBD")
    print(f"    - JNC_BUILD_DIR_TBD")
    print(f"    - JNC_CTH_SETUP_TBD")
    print(f"\n⚠️  Items kept from GFC (need JNC tuning):")
    print(f"    - bbox_percentage values (GFC floorplan)")
    print(f"    - origin coordinates")
    print(f"    - repeater offsets/count")
    print(f"    - buffer_spacing values")


if __name__ == '__main__':
    main()

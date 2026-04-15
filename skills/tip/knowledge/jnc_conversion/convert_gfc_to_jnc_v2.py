#!/usr/bin/env python3
"""
GFC (TSMC N2P) → JNC (Intel 1278.6 m16) TP file converter v2
Based on Kris's real JNC tp files from:
  /nfs/site/disks/kknopp_wa/JNC/TIP/runs/core_server/1278.6/rtlfp/

Key mapping (verified from real JNC files):
  GFC M18 (horiz) → JNC m16 (horiz)
  GFC M17 (vert)  → JNC m15 (vert)
  GFC M16         → JNC m14
  GFC M15         → JNC m13
  GFC M14         → JNC m12
  Buffer: i0mbfn000qa1n36x5 (lib: lib786_i0m_180h_50pp_ds1_ulvt)
  NDR: m15_m16_2x_2w
"""
import re, os, sys, glob

# ============================================================
# LAYER MAPPING (GFC TSMC → JNC Intel 1278.6 m16 stack)
# ============================================================
LAYER_MAP = {
    'M18': 'm16', 'M17': 'm15', 'M16': 'm14', 'M15': 'm13', 'M14': 'm12',
    'M13': 'm11', 'M12': 'm10', 'M11': 'm9',  'M10': 'm8',
    'M9': 'm7', 'M8': 'm6', 'M7': 'm5', 'M6': 'm4', 'M5': 'm3',
    'M4': 'm2', 'M3': 'm1', 'M2': 'm0',
    # sRDL (TSMC top) → bsb (Intel top bump)
    'sRDL': 'bsb',
}

# ============================================================
# BUFFER CELL (from Kris's real JNC files)
# ============================================================
GFC_BUFFER_PATTERNS = [
    r'tcbn02p_bwph156nppnl3p48cpd_base_ulvt_c240429/BUFFSR2BFYD18BWP156HNPPN3P48CPDULVT',
    r'tcbn02p_bwph156nppnl3p48cpd_base_ulvt_c240429/BUFFSR2BFYD14BWP156HNPPN3P48CPDULVT',
    r'tcbn02p_bwph156nppnl3p48cpd_base_ulvt_c240429/BUFFSR2D18BWP156HNPPN3P48CPDULVT',
]
JNC_BUFFER = 'lib786_i0m_180h_50pp_ds1_ulvt/i0mbfn000qa1n36x5'

# ============================================================
# NDR RULE MAPPING (from real JNC files — all use m15_m16_2x_2w)
# ============================================================
GFC_NDR_RULES = ['2w2s', '2w2s_M18_only', '2p5w2s_M14_M16_1w3s_M15', 
                 '2p5w2s_M16', 'm17_4w3s_m18_4w4s']
JNC_NDR = 'm15_m16_2x_2w'

# ============================================================
# JNC ROUTING RULE (from Kris's real files)
# ============================================================
JNC_ROUTING_RULE = '''    create_routing_rule "m15_m16_2x_2w" -widths {"bsb" 32.0000 "bm5" 2.0000 "bm4" 0.5400 "bm3" 0.5400 "bm2" 0.2400 "bm1" 0.1600 "bm0" 0.0800 "m0" 0.0200 "m1" 0.0300 "m2" 0.0200 "m3" 0.0240 "m4" 0.0240 "m5" 0.0400 "m6" 0.0400 "m7" 0.0400 "m8" 0.0400 "m9" 0.0400 "m10" 0.0400 "m11" 0.0600 "m12" 0.0600 "m13" 0.0800 "m14" 0.0800 "m15" 0.0800 "m16" 0.0800} -spacings {"bsb" {16.7200} "bm5" {2.0000} "bm4" {0.5400} "bm3" {0.5400} "bm2" {0.1400} "bm1" {0.1400} "bm0" {0.0800} "m0" {0.0160} "m1" {0.0200} "m2" {0.0160} "m3" {0.0160} "m4" {0.0160} "m5" {0.0400} "m6" {0.0400} "m7" {0.0400} "m8" {0.0400} "m9" {0.0400} "m10" {0.0400} "m11" {0.0600} "m12" {0.0600} "m13" {0.0800} "m14" {0.0800} "m15" {0.0800} "m16" {0.0800}} -spacing_weight_levels {"bsb" {hard} "bm5" {hard} "bm4" {hard} "bm3" {hard} "bm2" {hard} "bm1" {hard} "bm0" {hard} "m0" {hard} "m1" {hard} "m2" {hard} "m3" {hard} "m4" {hard} "m5" {hard} "m6" {hard} "m7" {hard} "m8" {hard} "m9" {hard} "m10" {hard} "m11" {hard} "m12" {hard} "m13" {hard} "m14" {hard} "m15" {hard} "m16" {hard}} -multiplier_width 2 -multiplier_spacing 2'''

# ============================================================
# JNC HEADER VALUES (from Kris's ward)
# ============================================================
JNC_NLIB = '/nfs/site/disks/kknopp_wa/JNC/TIP/core_server.nlib'
JNC_BUILD_DIR = '/nfs/site/disks/kknopp_wa/JNC/TIP/runs/core_server/1278.6'
JNC_CTH_SETUP = "/nfs/site/proj/hdk/pu_tu/prd/liteinfra/1.15/commonFlow/bin/cth_psetup -proj jnc_78_server/JNC_TS2025.11.T1 -cfg jnc78servera0.cth -ward /nfs/site/disks/kknopp_wa/JNC -x '\\$SETUP_R2G -w TIP -b core_server -force'"
JNC_TOOL = '/nfs/site/disks/crt_tools_0112/fusioncompiler/V-2023.12-SP5-6-613-T-20250917/linux64/nwtn/bin/dgcom_exec'

def convert_file(src_path, dst_path):
    with open(src_path, 'r') as f:
        content = f.read()
    
    lines = content.split('\n')
    new_lines = []
    in_routing_rule = False
    skip_until_brace = 0
    
    for i, line in enumerate(lines):
        # --- HEADER replacements ---
        if line.startswith('#| NLIB'):
            new_lines.append(f'#| NLIB              : {JNC_NLIB}')
            continue
        if line.startswith('#| BUILD_DIR'):
            new_lines.append(f'#| BUILD_DIR         : {JNC_BUILD_DIR}')
            continue
        if line.startswith('#| CTH_SETUP_CMD'):
            new_lines.append(f'#| CTH_SETUP_CMD       : {JNC_CTH_SETUP}')
            continue
        if line.startswith('#| TOOL EXECUTABLE'):
            new_lines.append(f'#| TOOL EXECUTABLE   : {JNC_TOOL}')
            continue
        if line.startswith('#| PROC_SOURCE'):
            new_lines.append('#| PROC_SOURCE       : ### JNC TIP procs ###')
            continue
            
        # --- BUFFER CELL ---
        modified = line
        for pat in GFC_BUFFER_PATTERNS:
            modified = modified.replace(pat.split('/')[-1], JNC_BUFFER.split('/')[-1])
            modified = modified.replace(pat.split('/')[0], JNC_BUFFER.split('/')[0])
        # Full buffer path replacement
        for pat in GFC_BUFFER_PATTERNS:
            modified = modified.replace(pat, JNC_BUFFER)
        
        # --- NDR RULES ---
        for gfc_ndr in GFC_NDR_RULES:
            # Replace NDR name in quotes and braces
            modified = modified.replace(f'"{gfc_ndr}"', f'"{JNC_NDR}"')
            modified = modified.replace(f' {gfc_ndr} ', f' {JNC_NDR} ')
            modified = modified.replace(f' {gfc_ndr}]', f' {JNC_NDR}]')
        
        # --- LAYER MAPPING (careful: only standalone layer names, not in signal names) ---
        # Replace layers in specific contexts: shape_layers, horizontal_value, vertical_value,
        # layer_cutting_distance, routing_rule widths/spacings
        for gfc_layer, jnc_layer in LAYER_MAP.items():
            # In quotes: "M18" → "m16"
            modified = re.sub(rf'"{gfc_layer}"', f'"{jnc_layer}"', modified)
            # In braces with values: {M18 100% 22.68} → {m16 100% 0.00000}
            modified = re.sub(rf'\{{({gfc_layer})\s+(\d+[%.])', 
                            lambda m: f'{{{jnc_layer} {m.group(2)}', modified)
            # layer_cutting_distance: {M18 0.5 0.5} → skip (JNC doesn't use)
            # Standalone in commands
            modified = re.sub(rf'(?<=["\s])({gfc_layer})(?=["\s\}}])', jnc_layer, modified)
        
        # --- SHAPE LAYER WIDTHS: GFC uses ~22.68um, JNC uses 0.00000 ---
        # Replace wire widths in shape_layers
        modified = re.sub(r'(shape_layers.*?)(\d+\.\d+)\}', 
                         lambda m: m.group(0) if 'bm' in m.group(0) else m.group(0),
                         modified)
        # More targeted: {m16 100% 22.68000} → {m16 100% 0.00000}
        modified = re.sub(r'\{(m\d+)\s+([\d.]+%)\s+\d+\.\d+\}', 
                         r'{\1 \2 0.00000}', modified)
        
        # --- LAYER CUTTING DISTANCE: remove (JNC doesn't use) ---
        if 'layer_cutting_distance' in modified:
            continue
            
        # --- REPEATER HEIGHT/WIDTH MULTIPLIER: remove (JNC doesn't use) ---
        if 'repeater_height_multiplier' in line or 'repeater_width_multiplier' in line:
            continue
        if 'set_attribute' in line and ('height_multiplier' in line or 'width_multiplier' in line):
            continue
        # Also handle set_repeater_group_constraints with height/width
        if 'set_repeater_group_constraints' in line and ('height' in line or 'width' in line):
            if 'height' in line and 'width' not in line:
                continue
            if 'width' in line and 'height' not in line:
                continue
            
        # --- ROUTING RULE: replace entire GFC routing rule block with JNC ---
        if 'create_routing_rule' in modified and any(ndr in modified for ndr in [JNC_NDR]):
            # Check if we already have JNC NDR rule, replace with canonical version
            if 'multiplier_width' not in modified or '-ignore_spacing_to_shield' in modified:
                new_lines.append(JNC_ROUTING_RULE)
                # Skip continuation lines of old rule
                continue
        
        # Remove GFC-specific routing rule options not in JNC
        if '-ignore_spacing_to_shield' in modified:
            modified = re.sub(r'\s*-ignore_spacing_to_shield\s*', ' ', modified)
        
        new_lines.append(modified)
    
    with open(dst_path, 'w') as f:
        f.write('\n'.join(new_lines))

def main():
    src_dir = '/nfs/site/disks/idc_gfc_fct_td/GFC_TIP_WA/tip_files/GFCA0_26WW13_1'
    dst_dir = '/nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/jnc_converted'
    
    # Skip the 12 files we already have from Kris
    jnc_real = {
        'icore.bplsdaborttoidqm155h.tp', 'icore.dsbfespec123bypenm123h.tp',
        'icore.dsbhitm124h.tp', 'icore.dsbqwrdatabrnumm124h.tp',
        'icore.dsbqwrdatabundlevalidsm124h.tp', 'icore.dsbqwrdatauopsnumm124h.tp',
        'icore.idforcejeclrm201h.tp', 'icore.idspecavx512m200h.tp',
        'icore.ifhitextsnoopm105h.tp', 'icore.je2mswrearlym805h_a.tp',
        'icore.jeclearlatetomsidm805h.tp', 'icore.jeforceallonesearlym805h.tp',
    }
    
    src_files = sorted(glob.glob(os.path.join(src_dir, '*.tp')))
    converted = 0
    skipped = 0
    
    for src in src_files:
        fname = os.path.basename(src)
        if fname in jnc_real:
            skipped += 1
            continue
        dst = os.path.join(dst_dir, fname)
        convert_file(src, dst)
        converted += 1
    
    print(f"Converted: {converted} files")
    print(f"Skipped (real JNC): {skipped} files")
    print(f"Total in output: {converted + skipped}")

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Generate per-signal GFC vs JNC diff tables in ASCII format."""

import os, re, glob

gfc_dir = "/nfs/site/disks/idc_gfc_fct_td/GFC_TIP_WA/tip_files/GFCA0_26WW13_1"
jnc_dir = "/nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/jnc_converted_scaled"
outfile = "/nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/gfc_vs_jnc_per_signal_diff.txt"

def extract_tp_info(filepath):
    """Extract key parameters from a tp file."""
    info = {}
    with open(filepath) as f:
        content = f.read()
    
    # Header
    m = re.search(r'set NLIB\s+"([^"]+)"', content)
    info['nlib'] = m.group(1).split('/')[-1] if m else '—'
    
    # NER layers
    h = re.search(r'-horizontal_value\s+"(\w+)"', content)
    v = re.search(r'-vertical_value\s+"(\w+)"', content)
    info['ner_layers'] = f"{h.group(1)}/{v.group(1)}" if h and v else '—'
    
    # NDR
    m = re.search(r'"ndr"\s*-value\s*"([^"]+)"', content)
    info['ndr'] = m.group(1) if m else '(none)'
    
    # Buffer
    m = re.search(r'"buffer"\s*-value\s*"([^"]+)"', content)
    if m:
        buf = m.group(1)
        # Shorten for display
        if 'BUFFSR2' in buf:
            info['buffer'] = 'tcbn02p.../BUFFSR2...'
        elif 'i0mbfn' in buf:
            lib, cell = buf.split('/')
            info['buffer'] = cell
        else:
            info['buffer'] = buf[:30]
    else:
        info['buffer'] = '—'
    
    # Buffer spacing
    m = re.search(r'"buffer_spacing"\s*-value\s*"([\d.]+)"', content)
    info['buf_spacing'] = m.group(1) if m else '—'
    
    # Repeater multipliers
    hm = re.search(r'-multiplier_height\s+([\d.]+)', content)
    wm = re.search(r'-multiplier_width\s+([\d.]+)', content)
    if hm and wm:
        info['rep_mult'] = f"h={hm.group(1)}, w={wm.group(1)}"
    else:
        info['rep_mult'] = '(none)'
    
    # Layer cutting
    cuts = re.findall(r'layer_cutting_distance.*?\{([^}]+)\}', content)
    if cuts:
        info['layer_cut'] = ' '.join(f'{{{c.strip()}}}' for c in cuts[:2])
    else:
        info['layer_cut'] = '(none)'
    
    # Topology nodes: bbox_percentage + partition
    nodes = []
    for m in re.finditer(r'get_cells\s*\{\s*(\w+)\s*\}.*?bbox_percentage\s*\{([-\d.]+)\s+([-\d.]+)\}', content):
        nodes.append((m.group(1), f"{{{m.group(2)} {m.group(3)}}}"))
    info['nodes'] = nodes
    
    # Origin / points_topology_edges
    m = re.search(r'points_topology_edges\s*-value\s*\{(.*?)\}', content, re.DOTALL)
    if m:
        coords = re.findall(r'\{([-\d.]+)\s+([-\d.]+)\}', m.group(1))
        if coords:
            info['origin'] = f"{{{coords[0][0]} {coords[0][1]}}}"
            if len(coords) > 1:
                info['origin'] += f" ... ({len(coords)} pts)"
        else:
            info['origin'] = '—'
    else:
        info['origin'] = '—'
    
    # Shape layers (first edge)
    shapes = re.findall(r'-shape_layers\s*\{([^}]+(?:\{[^}]*\}[^}]*)*)\}', content)
    if shapes:
        first = shapes[0].strip()
        # Compact: just show first segment
        segs = re.findall(r'\{(\w+)\s+([\d.]+%)\s+([\d.]+)\}', first)
        if segs:
            info['shape'] = ' '.join(f'{{{s[0]} {s[1]} {s[2]}}}' for s in segs[:2])
            if len(segs) > 2:
                info['shape'] += f' +{len(segs)-2}more'
        else:
            info['shape'] = first[:50]
    else:
        info['shape'] = '—'
    
    # Repeaters
    reps = re.findall(r'create_topology_repeater.*?-offset\s+([-\d.]+)', content)
    if reps:
        info['repeaters'] = f"{len(reps)} (offsets {reps[0]}-{reps[-1]})"
    else:
        info['repeaters'] = '(none)'
    
    # Routing rule
    rr = re.search(r'create_routing_rule\s+(\S+)\s+-widths\s*\{([^}]+)\}', content)
    if rr:
        layers = re.findall(r'(\w+)\s+[\d.]+', rr.group(2))
        info['routing_rule'] = f"{layers[0]}-{layers[-1]} widths" if layers else rr.group(1)
    else:
        info['routing_rule'] = '(none)'
    
    # Net names (first few)
    m = re.search(r'old_rtl_top_nets_list\s+"([^"]+)"', content)
    if m:
        nets = m.group(1).split()
        if len(nets) > 1:
            info['net_names'] = f"{nets[0]}... ({len(nets)} nets)"
        else:
            info['net_names'] = nets[0]
    else:
        info['net_names'] = '—'
    
    return info

def format_table(sig, gfc, jnc):
    """Format a nice ASCII comparison table."""
    w1, w2, w3 = 22, 35, 40
    sep  = f"  +{'-'*w1}+{'-'*w2}+{'-'*w3}+"
    hsep = f"  |{'-'*w1}+{'-'*w2}+{'-'*w3}|"
    
    lines = []
    lines.append(f"  === {sig} ===")
    lines.append(sep)
    lines.append(f"  |{'Item':<{w1}}|{'GFC (TSMC N2P)':<{w2}}|{'JNC (Intel 1278.6 scaled)':<{w3}}|")
    lines.append(sep)
    
    rows = [
        ('Header',       gfc.get('nlib','—'),          jnc.get('nlib','—')),
        ('NER layer',    gfc.get('ner_layers','—'),     jnc.get('ner_layers','—')),
        ('NDR rule',     gfc.get('ndr','—'),            jnc.get('ndr','—')),
        ('Buffer cell',  gfc.get('buffer','—'),         jnc.get('buffer','—')),
        ('Buffer spacing', gfc.get('buf_spacing','—'),  jnc.get('buf_spacing','—')),
        ('Repeater mult', gfc.get('rep_mult','—'),      jnc.get('rep_mult','—')),
        ('Layer cutting', gfc.get('layer_cut','—'),     jnc.get('layer_cut','—')),
    ]
    
    # Add bbox rows per node
    max_nodes = max(len(gfc.get('nodes',[])), len(jnc.get('nodes',[])))
    for i in range(max_nodes):
        gn = gfc.get('nodes',[])[i] if i < len(gfc.get('nodes',[])) else ('—','—')
        jn = jnc.get('nodes',[])[i] if i < len(jnc.get('nodes',[])) else ('—','—')
        rows.append((f'bbox {gn[0]}', gn[1], jn[1]))
    
    rows.extend([
        ('Origin',       gfc.get('origin','—'),         jnc.get('origin','—')),
        ('Shape layers', gfc.get('shape','—'),          jnc.get('shape','—')),
        ('Repeaters',    gfc.get('repeaters','—'),      jnc.get('repeaters','—')),
        ('Routing rule', gfc.get('routing_rule','—'),   jnc.get('routing_rule','—')),
        ('Net names',    gfc.get('net_names','—'),      'Same' if gfc.get('net_names') == jnc.get('net_names') else jnc.get('net_names','—')),
    ])
    
    for item, gval, jval in rows:
        # Truncate long values
        gval = str(gval)[:w2-1]
        jval = str(jval)[:w3-1]
        lines.append(f"  |{item:<{w1}}|{gval:<{w2}}|{jval:<{w3}}|")
        lines.append(hsep)
    
    # Replace last hsep with bottom border
    lines[-1] = sep
    lines.append("")
    return '\n'.join(lines)

# Generate report
out = []
out.append("=" * 100)
out.append("  GFC vs JNC — PER-SIGNAL DIFF TABLES (v2 scaled)")
out.append("  GFC source:  /nfs/site/disks/idc_gfc_fct_td/GFC_TIP_WA/tip_files/GFCA0_26WW13_1/")
out.append("  JNC output:  /nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/jnc_converted_scaled/")
out.append("  Generated:   2026-03-26")
out.append("=" * 100)
out.append("")

jnc_only = {'dsbbundlevalidsm123h', 'jeloaduarreqcm805h'}
count = 0

for fname in sorted(os.listdir(jnc_dir)):
    if not fname.endswith('.tp'): continue
    sig = fname.replace('icore.', '').replace('.tp', '')
    
    if sig in jnc_only:
        out.append(f"  === {sig} === (JNC-only, no GFC source)")
        out.append("")
        continue
    
    gfc_path = os.path.join(gfc_dir, fname)
    jnc_path = os.path.join(jnc_dir, fname)
    
    if not os.path.exists(gfc_path):
        out.append(f"  === {sig} === (GFC file not found)")
        out.append("")
        continue
    
    gfc_info = extract_tp_info(gfc_path)
    jnc_info = extract_tp_info(jnc_path)
    
    out.append(format_table(sig, gfc_info, jnc_info))
    count += 1

out.append(f"Total signals compared: {count}")
out.append("End of report.")

with open(outfile, 'w') as f:
    f.write('\n'.join(out))

print(f"Generated {count} diff tables -> {outfile}")
print(f"Total lines: {len(out)}")

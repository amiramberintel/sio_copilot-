#!/usr/bin/env python3
"""
Scale GFC geometry in JNC tp files to JNC partition dimensions.
Reads GFC and JNC partition location files, computes bounding boxes,
then scales bbox_percentage, origin coordinates, repeater offsets,
and points_topology_edges in the 97 GFC-converted tp files.

Creates new files in jnc_converted_scaled/ (does NOT modify jnc_converted/).
"""

import os, re, sys, shutil

# ============================================================
# Partition bounding boxes from location files
# ============================================================
def parse_polygon_bbox(lines):
    """Parse polygon coordinates and return (llx, lly, urx, ury) bounding box."""
    xs, ys = [], []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) >= 2:
            try:
                xs.append(float(parts[0]))
                ys.append(float(parts[1]))
            except ValueError:
                continue
    if not xs:
        return None
    return (min(xs), min(ys), max(xs), max(ys))

def load_partitions(base_dir, suffix=""):
    """Load partition bounding boxes from location files."""
    partitions = {}
    part_names = ['par_exe', 'par_fe', 'par_meu', 'par_msid', 
                  'par_ooo_int', 'par_ooo_vec', 'par_fmav0', 'par_fmav1']
    for p in part_names:
        fname = os.path.join(base_dir, f"{p}{suffix}.location")
        if os.path.exists(fname):
            with open(fname) as f:
                bbox = parse_polygon_bbox(f.readlines())
                if bbox:
                    partitions[p] = bbox
    return partitions

# GFC icore0 partitions
gfc_parts = load_partitions(
    "/nfs/site/disks/home_user/baselibr/gfc/Core_plot/core_client", "_icore0")

# JNC icore partitions  
jnc_parts = load_partitions(
    "/nfs/site/disks/home_user/baselibr/jnc/Core_plot/icore")

print("=== Partition Bounding Boxes ===")
print(f"{'Partition':<15} {'GFC (llx,lly,urx,ury)':<45} {'JNC (llx,lly,urx,ury)':<45} {'W_scale':>8} {'H_scale':>8}")
print("-" * 125)

scale_factors = {}
for p in sorted(set(list(gfc_parts.keys()) + list(jnc_parts.keys()))):
    g = gfc_parts.get(p)
    j = jnc_parts.get(p)
    if g and j:
        gw = g[2] - g[0]
        gh = g[3] - g[1]
        jw = j[2] - j[0]
        jh = j[3] - j[1]
        ws = jw / gw if gw > 0 else 1.0
        hs = jh / gh if gh > 0 else 1.0
        scale_factors[p] = (ws, hs, g, j)
        print(f"{p:<15} ({g[0]:8.2f},{g[1]:8.2f},{g[2]:8.2f},{g[3]:8.2f})   "
              f"({j[0]:8.2f},{j[1]:8.2f},{j[2]:8.2f},{j[3]:8.2f})   "
              f"{ws:8.4f} {hs:8.4f}")
    else:
        print(f"{p:<15} {'MISSING GFC' if not g else str(g):<45} {'MISSING JNC' if not j else str(j):<45}")

# Also compute icore-level scale for origin coordinates
# GFC icore0 bbox
with open("/nfs/site/disks/home_user/baselibr/gfc/Core_plot/core_client/icore0.location") as f:
    gfc_icore = parse_polygon_bbox(f.readlines())
with open("/nfs/site/disks/home_user/baselibr/jnc/Core_plot/icore/icore.location") as f:
    jnc_icore = parse_polygon_bbox(f.readlines())

gfc_icore_w = gfc_icore[2] - gfc_icore[0]
gfc_icore_h = gfc_icore[3] - gfc_icore[1]
jnc_icore_w = jnc_icore[2] - jnc_icore[0]
jnc_icore_h = jnc_icore[3] - jnc_icore[1]
icore_ws = jnc_icore_w / gfc_icore_w
icore_hs = jnc_icore_h / gfc_icore_h

print(f"\nicore level: GFC {gfc_icore_w:.2f} x {gfc_icore_h:.2f}  →  JNC {jnc_icore_w:.2f} x {jnc_icore_h:.2f}")
print(f"icore scale: W={icore_ws:.4f}  H={icore_hs:.4f}")

# ============================================================
# Scale tp files
# ============================================================
src_dir = "/nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/jnc_converted"
dst_dir = "/nfs/site/disks/sunger_wa/fc_data/my_learns/tp_file_to_JNC/jnc_converted_scaled"
os.makedirs(dst_dir, exist_ok=True)

# Kris's 14 real JNC files — copy as-is (already correct)
kris_signals = {
    'bplsdaborttoidqm155h', 'dsbbundlevalidsm123h', 'dsbfespec123bypenm123h',
    'dsbhitm124h', 'dsbqwrdatabrnumm124h', 'dsbqwrdatabundlevalidsm124h',
    'dsbqwrdatauopsnumm124h', 'idforcejeclrm201h', 'idspecavx512m200h',
    'ifhitextsnoopm105h', 'je2mswrearlym805h_a', 'jeclearlatetomsidm805h',
    'jeforceallonesearlym805h', 'jeloaduarreqcm805h'
}

def get_partition_from_node_line(line):
    """Extract partition name from create_topology_node line."""
    m = re.search(r'get_cells\s*\{\s*(\w+)\s*\}', line)
    return m.group(1) if m else None

def scale_bbox_percentage(line, partition):
    """Scale bbox_percentage based on partition scale factors.
    
    bbox_percentage is the pin position as % of partition bbox.
    Since the pin's RELATIVE position within the partition changes
    when the partition shape changes, we need to adjust.
    
    Approach: Convert GFC bbox% to absolute coords, then to JNC bbox%.
    GFC_abs = GFC_bbox_ll + GFC_bbox_size * (pct/100)
    JNC_pct = (GFC_abs_scaled - JNC_bbox_ll) / JNC_bbox_size * 100
    
    But since we don't know where the pin ACTUALLY is in JNC, we use
    a simpler proportional scaling: keep the same percentage but adjust
    for the relative position shift of the partition within icore.
    """
    if partition not in scale_factors:
        return line
    
    ws, hs, gfc_bb, jnc_bb = scale_factors[partition]
    
    def replace_bbox(m):
        pct_x = float(m.group(1))
        pct_y = float(m.group(2))
        
        # Convert GFC bbox% to absolute position within GFC icore
        gfc_w = gfc_bb[2] - gfc_bb[0]
        gfc_h = gfc_bb[3] - gfc_bb[1]
        abs_x = gfc_bb[0] + gfc_w * pct_x / 100.0
        abs_y = gfc_bb[1] + gfc_h * pct_y / 100.0
        
        # Scale absolute position from GFC icore to JNC icore
        jnc_abs_x = abs_x * icore_ws
        jnc_abs_y = abs_y * icore_hs
        
        # Convert to JNC bbox%
        jnc_w = jnc_bb[2] - jnc_bb[0]
        jnc_h = jnc_bb[3] - jnc_bb[1]
        if jnc_w > 0 and jnc_h > 0:
            new_pct_x = (jnc_abs_x - jnc_bb[0]) / jnc_w * 100.0
            new_pct_y = (jnc_abs_y - jnc_bb[1]) / jnc_h * 100.0
        else:
            new_pct_x, new_pct_y = pct_x, pct_y
        
        return f"bbox_percentage {{{new_pct_x:.3f} {new_pct_y:.3f}}}"
    
    return re.sub(r'bbox_percentage\s*\{([-\d.]+)\s+([-\d.]+)\}', replace_bbox, line)

def scale_origin_coords(line):
    """Scale origin coordinates (absolute die coords) from GFC to JNC."""
    def replace_coord_pair(m):
        x = float(m.group(1))
        y = float(m.group(2))
        new_x = x * icore_ws
        new_y = y * icore_hs
        return f"{{{new_x:.5f} {new_y:.5f}}}"
    
    # points_topology_edges has format: {{{x1 y1} {x2 y2} ...}}
    if 'points_topology_edges' in line:
        return re.sub(r'\{([-\d.]+)\s+([-\d.]+)\}', replace_coord_pair, line)
    return line

def scale_repeater_offset(line, edge_scale):
    """Scale repeater offset by edge length ratio."""
    def replace_offset(m):
        offset = float(m.group(1))
        new_offset = offset * edge_scale
        return f"-offset {new_offset:.3f}"
    return re.sub(r'-offset\s+([-\d.]+)', replace_offset, line)

def scale_buffer_spacing(line):
    """Scale buffer_spacing by average of icore W and H scale."""
    avg_scale = (icore_ws + icore_hs) / 2.0
    def replace_spacing(m):
        val = float(m.group(1))
        new_val = val * avg_scale
        return f'"buffer_spacing" -value "{new_val:.3f}"'
    return re.sub(r'"buffer_spacing"\s*-value\s*"([\d.]+)"', replace_spacing, line)

def scale_edge_start_end(line):
    """Scale edge start/end values (position along partition edge in microns)."""
    # -start and -end are positions along a partition edge
    avg_scale = (icore_ws + icore_hs) / 2.0
    def replace_val(m):
        prefix = m.group(1)
        val = float(m.group(2))
        new_val = val * avg_scale
        return f"{prefix} {new_val:.3f}"
    line = re.sub(r'(-start)\s+([-\d.]+)', replace_val, line)
    line = re.sub(r'(-end)\s+([-\d.]+)', replace_val, line)
    return line

# Process each file
copied = 0
scaled = 0
for fname in sorted(os.listdir(src_dir)):
    if not fname.endswith('.tp'):
        continue
    
    sig = fname.replace('icore.', '').replace('.tp', '')
    src_path = os.path.join(src_dir, fname)
    dst_path = os.path.join(dst_dir, fname)
    
    # Kris's files — copy as-is
    if sig in kris_signals:
        shutil.copy2(src_path, dst_path)
        copied += 1
        continue
    
    # Read file and identify partitions per node
    with open(src_path) as f:
        lines = f.readlines()
    
    # First pass: find partition for each topology node
    node_partitions = {}
    current_partition = None
    edge_nodes = {}  # edge_name -> (node0_partition, node1_partition)
    
    for line in lines:
        if 'create_topology_node' in line:
            part = get_partition_from_node_line(line)
            nm = re.search(r'-name\s+(\S+)', line)
            if nm and part:
                node_partitions[nm.group(1)] = part
                current_partition = part
        
        if 'create_topology_edge' in line:
            em = re.search(r'-name\s+(\S+)', line)
            nodes_m = re.search(r'-nodes\s*\{([^}]+)\}', line)
            if em and nodes_m:
                node_refs = nodes_m.group(1).split()
                parts_in_edge = []
                for nr in node_refs:
                    nn = nr.split('/')[-1]
                    if nn in node_partitions:
                        parts_in_edge.append(node_partitions[nn])
                edge_nodes[em.group(1)] = parts_in_edge
    
    # Compute edge-level scale: average of both endpoint partition scales
    edge_scales = {}
    for ename, parts in edge_nodes.items():
        scales = []
        for p in parts:
            if p in scale_factors:
                ws, hs, _, _ = scale_factors[p]
                scales.append((ws + hs) / 2.0)
        edge_scales[ename] = sum(scales) / len(scales) if scales else (icore_ws + icore_hs) / 2.0
    
    # Second pass: apply scaling
    new_lines = []
    current_edge = None
    for line in lines:
        # Track current edge for repeater scaling
        if 'create_topology_edge' in line:
            em = re.search(r'-name\s+(\S+)', line)
            if em:
                current_edge = em.group(1)
        
        # Scale bbox_percentage
        if 'bbox_percentage' in line and 'create_topology_node' in line:
            part = get_partition_from_node_line(line)
            if part:
                line = scale_bbox_percentage(line, part)
        elif 'bbox_percentage' in line and 'set_attribute' in line:
            # standalone set_attribute for bbox — use last known partition
            if current_partition:
                line = scale_bbox_percentage(line, current_partition)
        
        # Scale origin/points_topology_edges coordinates
        if 'points_topology_edges' in line:
            line = scale_origin_coords(line)
        
        # Scale repeater offsets
        if 'create_topology_repeater' in line:
            es = edge_scales.get(current_edge, (icore_ws + icore_hs) / 2.0)
            line = scale_repeater_offset(line, es)
        
        # Scale buffer_spacing
        if 'buffer_spacing' in line:
            line = scale_buffer_spacing(line)
        
        # Scale edge start/end
        if '-start' in line or '-end' in line:
            if 'create_topology_node' in line:
                line = scale_edge_start_end(line)
        
        new_lines.append(line)
    
    with open(dst_path, 'w') as f:
        f.writelines(new_lines)
    scaled += 1

print(f"\n=== RESULTS ===")
print(f"Kris originals copied: {copied}")
print(f"GFC→JNC scaled:       {scaled}")
print(f"Total files:           {copied + scaled}")
print(f"Output: {dst_dir}/")

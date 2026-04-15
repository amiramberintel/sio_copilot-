#!/usr/bin/env python3
"""
spef_net_query.py -- Fast SPEF net data extractor

Extracts physical data for specific nets from huge SPEF files without
loading the entire file into memory. Streams through compressed SPEF
and pulls only the nets you need.

Usage:
  # Single net
  python3 spef_net_query.py <spef.gz> --net "net_name"

  # Multiple nets from file (one per line)
  python3 spef_net_query.py <spef.gz> --netlist nets.txt

  # Search by pattern (regex)
  python3 spef_net_query.py <spef.gz> --pattern "dcl1hit.*m404h"

  # Output CSV summary
  python3 spef_net_query.py <spef.gz> --net "net_name" --csv

  # Extract all nets with total_cap > threshold (in fF)
  python3 spef_net_query.py <spef.gz> --cap-above 100.0

  # Quick name map lookup (no parasitic data, very fast)
  python3 spef_net_query.py <spef.gz> --name-lookup "dcl1hitslm404h"

Output per net:
  - Net name, total capacitance
  - Driver pin, cell type, coordinates
  - All receiver pins, cell types, coordinates
  - All internal nodes with coordinates and metal layer ($lvl)
  - RES section: node-to-node resistance values
  - CAP section: grounded + coupling capacitances
  - Derived: total R, total C, coupling C ratio, estimated RC delay
  - Derived: bounding box, manhattan distance, metal layers used
"""

import gzip
import sys
import re
import os
import argparse
from collections import defaultdict


# Metal layer mapping for N2P process (lvl number -> layer name)
# lvl=1 is M0, lvl=2 is M1, etc. Higher numbers are vias.
METAL_LAYERS = {
    1: "M0", 2: "M1", 3: "V0", 4: "M2", 5: "V1",
    6: "M3", 7: "V2", 8: "M4", 9: "V3", 10: "M5",
    11: "V4", 12: "M6", 13: "V5", 14: "M7", 15: "V6",
    16: "M8", 17: "V7", 18: "M9", 19: "V8", 20: "M10",
    # Upper metals / redistribution
    51: "M1_alt", 52: "M_upper1", 53: "VIA_upper1", 54: "VIA_upper2",
}


def get_layer_name(lvl):
    """Convert SPEF $lvl number to metal layer name."""
    return METAL_LAYERS.get(lvl, "L%d" % lvl)


class SpefNetData:
    """Parsed data for a single SPEF net."""
    def __init__(self, name, total_cap):
        self.name = name
        self.total_cap = total_cap      # fF
        self.driver = None              # (pin, cell_type, x, y, lvl)
        self.receivers = []             # [(pin, cell_type, x, y, cap, lvl)]
        self.internal_nodes = []        # [(node, x, y, lvl)]
        self.resistors = []             # [(node1, node2, value_ohm)]
        self.capacitors = []            # [(node1, node2_or_gnd, value_fF)]
        self.conn_lines = []            # raw CONN lines for debug

    @property
    def total_res(self):
        return sum(r[2] for r in self.resistors)

    @property
    def total_ground_cap(self):
        return sum(c[2] for c in self.capacitors if c[1] is None)

    @property
    def total_coupling_cap(self):
        return sum(c[2] for c in self.capacitors if c[1] is not None)

    @property
    def coupling_ratio(self):
        if self.total_cap > 0:
            return self.total_coupling_cap / self.total_cap
        return 0.0

    @property
    def metal_layers(self):
        layers = set()
        if self.driver and self.driver[4]:
            layers.add(self.driver[4])
        for r in self.receivers:
            if r[5]:
                layers.add(r[5])
        for n in self.internal_nodes:
            if n[3]:
                layers.add(n[3])
        return sorted(layers)

    @property
    def metal_layer_names(self):
        return [get_layer_name(l) for l in self.metal_layers]

    @property
    def via_count(self):
        """Count via layers in internal nodes (odd lvl >= 3 are vias in N2P)."""
        count = 0
        for n in self.internal_nodes:
            if n[3] and n[3] in METAL_LAYERS and METAL_LAYERS[n[3]].startswith("V"):
                count += 1
        return count

    @property
    def metal_only_layers(self):
        """Return only metal layers (not vias)."""
        return [l for l in self.metal_layers
                if l in METAL_LAYERS and not METAL_LAYERS[l].startswith("V")]

    @property
    def per_layer_node_count(self):
        """Count of internal routing nodes per layer."""
        counts = defaultdict(int)
        for n in self.internal_nodes:
            if n[3]:
                counts[n[3]] += 1
        return dict(counts)

    @property
    def per_layer_res(self):
        """Sum resistance by layer of the first node in each RES segment.
        Approximation: assigns segment R to the layer of node1."""
        layer_res = defaultdict(float)
        node_layer = {}
        # Build node->layer map from internal nodes + conn
        for n in self.internal_nodes:
            if n[3]:
                node_layer[n[0]] = n[3]
        if self.driver:
            node_layer[self.driver[0]] = self.driver[4]
        for r in self.receivers:
            node_layer[r[0]] = r[5]
        # Sum resistance per layer
        for r in self.resistors:
            lvl = node_layer.get(r[0]) or node_layer.get(r[1])
            if lvl:
                layer_res[lvl] += r[2]
        return dict(layer_res)

    @property
    def bounding_box(self):
        coords = []
        if self.driver:
            coords.append((self.driver[2], self.driver[3]))
        for r in self.receivers:
            coords.append((r[2], r[3]))
        for n in self.internal_nodes:
            coords.append((n[1], n[2]))
        if not coords:
            return None
        xs = [c[0] for c in coords if c[0] is not None]
        ys = [c[1] for c in coords if c[1] is not None]
        if not xs or not ys:
            return None
        return (min(xs), min(ys), max(xs), max(ys))

    @property
    def manhattan_distance(self):
        bb = self.bounding_box
        if bb is None:
            return 0.0
        return (bb[2] - bb[0]) + (bb[3] - bb[1])

    @property
    def num_pins(self):
        return (1 if self.driver else 0) + len(self.receivers)

    @property
    def estimated_rc_delay_ps(self):
        """Elmore delay estimate: 0.5 * R_total * C_total (in ps)."""
        # R in ohms, C in fF -> RC in fs -> /1000 for ps
        return 0.5 * self.total_res * self.total_cap / 1000.0

    def summary_line(self):
        bb = self.bounding_box
        bb_str = ""
        if bb:
            bb_str = "(%.1f,%.1f)-(%.1f,%.1f)" % bb
        return "%s | cap=%.2ffF | res=%.1fohm | pins=%d | layers=%s | vias=%d | dist=%.1fum | bbox=%s | cc_ratio=%.1f%% | rc_est=%.1fps" % (
            self.name, self.total_cap, self.total_res, self.num_pins,
            "+".join(self.metal_layer_names), self.via_count,
            self.manhattan_distance,
            bb_str, self.coupling_ratio * 100, self.estimated_rc_delay_ps
        )

    def detail_report(self):
        lines = []
        lines.append("=" * 78)
        lines.append("NET: %s" % self.name)
        lines.append("=" * 78)
        lines.append("Total Capacitance:  %.4f fF" % self.total_cap)
        lines.append("Total Resistance:   %.4f Ohm" % self.total_res)
        lines.append("Ground Cap:         %.4f fF" % self.total_ground_cap)
        lines.append("Coupling Cap:       %.4f fF (%.1f%%)" % (
            self.total_coupling_cap, self.coupling_ratio * 100))
        lines.append("Estimated RC delay: %.2f ps" % self.estimated_rc_delay_ps)
        lines.append("Pin count:          %d (1 driver + %d receivers)" % (
            self.num_pins, len(self.receivers)))
        lines.append("Metal layers:       %s" % ", ".join(self.metal_layer_names))
        lines.append("Via count:          %d" % self.via_count)
        lines.append("Manhattan distance: %.2f um" % self.manhattan_distance)
        bb = self.bounding_box
        if bb:
            lines.append("Bounding box:       (%.3f, %.3f) - (%.3f, %.3f)" % bb)
        lines.append("")

        if self.driver:
            lines.append("DRIVER:")
            lines.append("  Pin:  %s" % self.driver[0])
            lines.append("  Cell: %s" % self.driver[1])
            lines.append("  Loc:  (%.4f, %.4f)  Layer: %s" % (
                self.driver[2], self.driver[3],
                get_layer_name(self.driver[4]) if self.driver[4] else "?"))
        lines.append("")
        lines.append("RECEIVERS: (%d)" % len(self.receivers))
        for i, r in enumerate(self.receivers):
            cap_str = " load=%.4ffF" % r[4] if r[4] else ""
            lines.append("  [%d] Pin: %s  Cell: %s  Loc: (%.4f,%.4f)  Layer: %s%s" % (
                i+1, r[0], r[1], r[2], r[3],
                get_layer_name(r[5]) if r[5] else "?", cap_str))
        lines.append("")

        # Enhanced metal layer breakdown
        lines.append("METAL LAYER BREAKDOWN:")
        lines.append("-" * 60)
        lines.append("  %-10s %-8s %-12s %-12s %s" % (
            "Layer", "Type", "Nodes", "Res(Ohm)", "% of Total R"))
        lines.append("  " + "-" * 56)
        node_counts = self.per_layer_node_count
        layer_r = self.per_layer_res
        total_r = self.total_res if self.total_res > 0 else 1.0
        metals = 0
        vias = 0
        for lvl in sorted(set(list(node_counts.keys()) + list(layer_r.keys()))):
            lname = get_layer_name(lvl)
            is_via = lname.startswith("V")
            ltype = "via" if is_via else "metal"
            nc = node_counts.get(lvl, 0)
            lr = layer_r.get(lvl, 0.0)
            pct = (lr / total_r) * 100 if total_r > 0 else 0.0
            lines.append("  %-10s %-8s %-12d %-12.3f %.1f%%" % (
                lname, ltype, nc, lr, pct))
            if is_via:
                vias += nc
            else:
                metals += nc
        lines.append("  " + "-" * 56)
        lines.append("  Total metal nodes: %d  |  Total via nodes: %d" % (metals, vias))
        lines.append("")

        lines.append("RES SEGMENTS: %d  (range: %.3f - %.3f Ohm)" % (
            len(self.resistors),
            min(r[2] for r in self.resistors) if self.resistors else 0,
            max(r[2] for r in self.resistors) if self.resistors else 0))
        lines.append("CAP ENTRIES:  %d" % len(self.capacitors))
        lines.append("=" * 78)
        return "\n".join(lines)

    def csv_line(self):
        bb = self.bounding_box
        return "%s,%.4f,%.4f,%.4f,%.4f,%.1f,%d,%d,%d,%s,%.2f,%.2f,%.2f,%.2f" % (
            self.name, self.total_cap, self.total_res,
            self.total_ground_cap, self.total_coupling_cap,
            self.coupling_ratio * 100,
            self.num_pins, len(self.resistors), self.via_count,
            "+".join(self.metal_layer_names),
            self.manhattan_distance,
            bb[2] - bb[0] if bb else 0, bb[3] - bb[1] if bb else 0,
            self.estimated_rc_delay_ps)


def parse_coord_comment(comment):
    """Parse coordinate from SPEF comment: *C x y or $llx=... $lvl=N"""
    x, y, lvl = None, None, None
    # Look for *C x y
    m = re.search(r'\*C\s+([\d.]+)\s+([\d.]+)', comment)
    if m:
        x, y = float(m.group(1)), float(m.group(2))
    # Look for $lvl=N
    m = re.search(r'\$lvl=(\d+)', comment)
    if m:
        lvl = int(m.group(1))
    return x, y, lvl


def parse_cell_type(comment):
    """Extract cell reference name from *D field."""
    m = re.search(r'\*D\s+(\S+)', comment)
    return m.group(1) if m else ""


def parse_load_cap(comment):
    """Extract load capacitance from *L field."""
    m = re.search(r'\*L\s+([\d.eE+-]+)', comment)
    return float(m.group(1)) if m else None


def stream_spef(spef_path, target_nets=None, pattern=None, cap_threshold=None,
                name_lookup=None, max_nets=1000):
    """
    Stream through SPEF file and extract matching nets.
    Only reads one pass, extracts only matching nets.
    """
    results = []
    name_map = {}   # id -> name
    rev_map = {}    # name -> id

    opener = gzip.open if spef_path.endswith('.gz') else open
    mode = 'rt' if spef_path.endswith('.gz') else 'r'

    # Convert target nets to a set for fast lookup
    target_ids = set()
    if target_nets:
        target_nets_set = set(target_nets)
    else:
        target_nets_set = None

    compiled_pattern = re.compile(pattern) if pattern else None

    in_name_map = False
    in_dnet = False
    current_net = None
    section = None  # 'conn', 'cap', 'res'
    found_count = 0

    sys.stderr.write("Streaming %s ...\n" % spef_path)

    with opener(spef_path, mode) as f:
        for line_num, line in enumerate(f):
            line = line.rstrip()

            # Name map section
            if line == "*NAME_MAP":
                in_name_map = True
                continue
            if in_name_map:
                if line.startswith("*D_NET") or line.startswith("*PORTS"):
                    in_name_map = False
                elif line.startswith("*"):
                    parts = line.split(None, 1)
                    if len(parts) == 2:
                        nid = parts[0]
                        nname = parts[1]
                        name_map[nid] = nname
                        rev_map[nname] = nid

                        # Name lookup mode: just find matching names
                        if name_lookup:
                            if name_lookup.lower() in nname.lower():
                                results.append(nname)
                                if len(results) >= max_nets:
                                    return results if name_lookup else results

                        # Build target IDs from names
                        if target_nets_set and nname in target_nets_set:
                            target_ids.add(nid)
                    continue

            if name_lookup:
                continue  # In name lookup mode, skip everything after name map

            # D_NET start
            if line.startswith("*D_NET"):
                parts = line.split()
                net_id = parts[1]
                total_cap = float(parts[2]) if len(parts) > 2 else 0.0
                net_name = name_map.get(net_id, net_id)

                # Check if we want this net
                want = False
                if target_nets_set:
                    want = (net_id in target_ids) or (net_name in target_nets_set)
                if compiled_pattern and not want:
                    want = bool(compiled_pattern.search(net_name))
                if cap_threshold is not None and not want:
                    want = (total_cap >= cap_threshold)
                if not target_nets_set and not compiled_pattern and cap_threshold is None:
                    want = True  # dump all (dangerous for big SPEF!)

                if want:
                    current_net = SpefNetData(net_name, total_cap)
                    in_dnet = True
                    section = None
                else:
                    current_net = None
                    in_dnet = False
                continue

            if not in_dnet or current_net is None:
                continue

            # Section markers
            if line == "*CONN":
                section = "conn"
                continue
            elif line == "*CAP":
                section = "cap"
                continue
            elif line == "*RES":
                section = "res"
                continue
            elif line == "*END":
                results.append(current_net)
                found_count += 1
                if found_count % 100 == 0:
                    sys.stderr.write("  Found %d nets...\n" % found_count)
                if found_count >= max_nets:
                    break
                in_dnet = False
                current_net = None
                section = None
                continue

            # Parse CONN section
            if section == "conn":
                x, y, lvl = parse_coord_comment(line)
                cell_type = parse_cell_type(line)
                load_cap = parse_load_cap(line)
                parts = line.split()
                if len(parts) >= 3:
                    pin = name_map.get(parts[1], parts[1])
                    # Resolve : references
                    if ":" in pin and pin.startswith("*"):
                        base = pin.split(":")[0]
                        pin = name_map.get(base, base) + ":" + pin.split(":", 1)[1]
                    direction = parts[2]
                    if direction == "O":
                        current_net.driver = (pin, cell_type, x, y, lvl)
                    elif direction == "I":
                        current_net.receivers.append(
                            (pin, cell_type, x, y, load_cap, lvl))
                if line.startswith("*N"):
                    # Internal node
                    current_net.internal_nodes.append(
                        (parts[1] if parts else "", x, y, lvl))

            # Parse CAP section
            elif section == "cap":
                parts = line.split()
                if len(parts) >= 3:
                    node1 = parts[1]
                    if len(parts) == 3:
                        # Grounded cap
                        val = float(parts[2])
                        current_net.capacitors.append((node1, None, val))
                    elif len(parts) >= 4:
                        # Coupling cap
                        node2 = parts[2]
                        val = float(parts[3])
                        current_net.capacitors.append((node1, node2, val))

            # Parse RES section
            elif section == "res":
                parts = line.split()
                if len(parts) >= 4:
                    node1 = parts[1]
                    node2 = parts[2]
                    val = float(parts[3])
                    current_net.resistors.append((node1, node2, val))

            # Progress indicator
            if line_num % 10000000 == 0 and line_num > 0:
                sys.stderr.write("  Processed %dM lines...\n" % (line_num // 1000000))

    return results


def main():
    parser = argparse.ArgumentParser(
        description="Fast SPEF net data extractor for SIO timing analysis")
    parser.add_argument("spef", help="SPEF file path (.spef or .spef.gz)")
    parser.add_argument("--net", help="Single net name to extract")
    parser.add_argument("--netlist", help="File with net names (one per line)")
    parser.add_argument("--pattern", help="Regex pattern to match net names")
    parser.add_argument("--cap-above", type=float,
                        help="Extract nets with total_cap above threshold (fF)")
    parser.add_argument("--name-lookup", help="Quick name map search (no parasitic data)")
    parser.add_argument("--csv", action="store_true", help="Output CSV format")
    parser.add_argument("--summary", action="store_true", help="One-line summary per net")
    parser.add_argument("--max-nets", type=int, default=1000,
                        help="Max nets to extract (default 1000)")
    args = parser.parse_args()

    if not os.path.exists(args.spef):
        sys.stderr.write("ERROR: SPEF file not found: %s\n" % args.spef)
        sys.exit(1)

    target_nets = None
    if args.net:
        target_nets = [args.net]
    elif args.netlist:
        with open(args.netlist) as f:
            target_nets = [line.strip() for line in f if line.strip()]

    results = stream_spef(
        args.spef,
        target_nets=target_nets,
        pattern=args.pattern,
        cap_threshold=args.cap_above,
        name_lookup=args.name_lookup,
        max_nets=args.max_nets
    )

    if args.name_lookup:
        sys.stderr.write("Found %d matching names\n" % len(results))
        for name in results:
            print(name)
        return

    if args.csv:
        print("net,total_cap_fF,total_res_ohm,ground_cap_fF,coupling_cap_fF,"
              "coupling_ratio_pct,pin_count,res_segments,via_count,metal_layers,"
              "manhattan_dist_um,dx_um,dy_um,rc_delay_ps")
        for net in results:
            print(net.csv_line())
    elif args.summary:
        for net in results:
            print(net.summary_line())
    else:
        for net in results:
            print(net.detail_report())
            print()

    sys.stderr.write("Total nets extracted: %d\n" % len(results))


if __name__ == "__main__":
    main()

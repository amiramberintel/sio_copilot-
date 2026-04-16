# Innovus Attribute Reference

Complete reference for Innovus object attributes and query patterns.

> **📚 Official Documentation**: Store complete attribute references in `../docs/api_docs/`  
> This file contains curated, practical knowledge extracted from official docs.

---

## Critical Rule: Empty Attribute Checking

⚠️ **ALWAYS use `== ""` for empty attribute checks in Innovus**

```tcl
# ✅ CORRECT - Works for all attribute types
get_db ports -if {.physical_pins == ""}
get_db insts -if {.location == ""}
get_db nets -if {.wires == ""}

# ❌ WRONG - Returns 0 results
get_db ports -if {.physical_pins == {}}
```

**Why**: In Innovus `get_db -if` filters, all empty attribute values should be checked with empty string `""`, not empty list `{}`.

---

## Attribute Types

### Boolean Attributes
Attributes prefixed with `is_`, `has_`, etc.

```tcl
# Method 1: Negation operator
get_db insts -if {!.is_sequential}
get_db insts -if {!.is_latch}

# Method 2: Explicit comparison
get_db insts -if {.is_sequential == false}
get_db insts -if {.is_sequential == true}

# Method 3: Direct use (implicit true)
get_db insts -if {.is_sequential}
```

**Common Boolean Attributes**:
- `.is_sequential` - Instance is sequential (FF/latch)
- `.is_latch` - Instance is a latch
- `.is_buffer` - Base cell is buffer
- `.is_inverter` - Base cell is inverter
- `.is_placed` - Instance is placed
- `.is_fixed` - Instance is fixed

---

### String Attributes

```tcl
# Equality comparison
get_db ports -if {.direction == "in"}
get_db nets -if {.net_type == "signal"}

# Pattern matching (use outside -if with string match)
foreach inst [get_db insts] {
    set name [get_db $inst .name]
    if {[string match "*_reg*" $name]} {
        # Process register instances
    }
}

# Multiple pattern checks
set lc_name [get_db $inst .lib_cell.name]
if {[string match "*lvt*" $lc_name] || [string match "*LVT*" $lc_name]} {
    # LVT cell
}
```

**Common String Attributes**:
- `.name` - Object name
- `.direction` - Port direction: "in", "out", "inout"
- `.net_type` - Net type: "signal", "power", "ground", "clock"
- `.location` - Placement location: "x y" format
- `.base_cell.name` - Base cell name
- `.lib_cell.name` - Library cell name

---

### Collection/List Attributes

⚠️ **Important**: These return string representations, not true TCL lists

```tcl
# Count items (llength works on string representation)
set num_pins [llength [get_db $port .physical_pins]]
set num_wires [llength [get_db $net .wires]]

# Check empty - USE EMPTY STRING
get_db ports -if {.physical_pins == ""}
get_db nets -if {.wires == ""}

# Iterate when not empty
foreach pin [get_db $port .physical_pins] {
    # Process each pin
}
```

**Common Collection Attributes**:
- `.physical_pins` - Port's physical terminals
- `.wires` - Net's wire segments
- `.terms` - Net terminals
- `.insts` - Design instances (at design level)

---

## Attribute Query Patterns

### Port Attributes

```tcl
# Basic port info
get_db ports .name                    # Port names (all ports)
get_db ports -if {.direction == "in"} # Input ports only

# Port terminals
.physical_pins           # Collection of physical pin objects
.physical_pins == ""     # Ports without terminals (empty string check)
llength [get_db $port .physical_pins]  # Terminal count

# Port connections
.net                     # Connected net object
```

**Example - Port Terminal Analysis**:
```tcl
# Count ports without terminals
set ports_no_terms [llength [get_db ports -if {.physical_pins == ""}]]

# Multi-terminal analysis
foreach port [get_db ports] {
    set num_terms [llength [get_db $port .physical_pins]]
    if {$num_terms > 1} {
        puts "[get_db $port .name] has $num_terms terminals"
    }
}
```

---

### Instance Attributes

```tcl
# Basic instance info
.name                    # Instance name
.base_cell.name          # Base cell name (for pattern matching)
.lib_cell.name           # Library cell name (includes PVT info)

# Instance type
.is_sequential           # Boolean - FF or latch
.is_latch               # Boolean - Is latch
.base_cell.is_buffer    # Boolean - Is buffer
.base_cell.is_inverter  # Boolean - Is inverter

# Placement
.location               # String - "x y" coordinates
.location == ""         # Not placed (use empty string)
.is_placed              # Boolean - Has valid placement
.is_fixed               # Boolean - Fixed placement

# Hierarchy
.is_hierarchical        # Boolean - Is hierarchical instance
```

**Example - Sequential Cell Breakdown**:
```tcl
# Get all sequential cells
set seq_cells [get_db insts -if {.is_sequential}]

# Separate FFs and latches
set latches [get_db insts -if {.is_sequential && .is_latch}]
set flipflops [get_db insts -if {.is_sequential && !.is_latch}]
```

**Example - VT Breakdown**:
```tcl
# Analyze by lib_cell name pattern
foreach inst [get_db insts] {
    set lc_name [get_db $inst .lib_cell.name]
    if {[string match "*ulvtll*" $lc_name]} {
        # ULVTLL cell
    } elseif {[string match "*lvt*" $lc_name]} {
        # LVT cell
    } elseif {[string match "*svt*" $lc_name]} {
        # SVT cell
    }
}
```

**Example - Multi-Bit FF Detection**:
```tcl
# Based on base_cell naming: *200* or *020* = dual, *400* or *040* = quad
foreach inst [get_db insts -if {.is_sequential && !.is_latch}] {
    set bc_name [get_db $inst .base_cell.name]
    if {[string match "*200*" $bc_name] || [string match "*020*" $bc_name]} {
        # Dual-bit FF
    } elseif {[string match "*400*" $bc_name] || [string match "*040*" $bc_name]} {
        # Quad-bit FF
    } elseif {[string match "*800*" $bc_name] || [string match "*080*" $bc_name]} {
        # Octa-bit FF
    }
}
```

---

### Net Attributes

```tcl
# Basic net info
.name                    # Net name
.net_type               # String - "signal", "power", "ground", "clock"

# Net connectivity
.wires                  # Collection of wire segments
.wires == ""            # Unrouted net (use empty string)
.terms                  # Collection of connected terminals

# Net properties
.is_clock               # Boolean - Is clock net
.is_power               # Boolean - Is power net
.is_ground              # Boolean - Is ground net
```

**Example - Net Type Breakdown**:
```tcl
set signal_nets [llength [get_db nets -if {.net_type == "signal"}]]
set power_nets  [llength [get_db nets -if {.net_type == "power"}]]
set ground_nets [llength [get_db nets -if {.net_type == "ground"}]]
set clock_nets  [llength [get_db nets -if {.net_type == "clock"}]]
```

---

### Clock Attributes

```tcl
# Clock info
.name                    # Clock name
.period                 # Clock period (ns)
.sources                # Clock source pins
```

**Example - Clock Analysis**:
```tcl
foreach clk [get_db clocks] {
    set clk_name [get_db $clk .name]
    set period [get_db $clk .period]
    set freq_mhz [expr {1000.0 / $period}]
    puts "$clk_name: ${period}ns (${freq_mhz} MHz)"
}
```

---

### Design Attributes

```tcl
# Design info
get_db designs .name               # Design name
get_db designs .insts              # All instances
get_db designs .nets               # All nets
get_db designs .ports              # All ports
```

---

## Testing Attribute Types

When working with unknown attributes, always test first:

```tcl
# Get sample object
set obj [lindex [get_db ports] 0]

# Test attribute value
set val [get_db $obj .attr_name]
puts "Value: $val"
puts "Type: [string is boolean $val]"
puts "Empty check: [expr {$val == ""}]"

# Test filter
set count [llength [get_db ports -if {.attr_name == ""}]]
puts "Empty count: $count"
```

---

## Common Mistakes

### ❌ Using `== {}` for empty checks
```tcl
# WRONG - Returns 0 results
get_db ports -if {.physical_pins == {}}
```

### ❌ Using `!` on non-boolean attributes
```tcl
# WRONG - ! only works for boolean attributes
get_db ports -if {!.physical_pins}

# CORRECT
get_db ports -if {.physical_pins == ""}
```

### ❌ String matching inside -if
```tcl
# WRONG - string match doesn't work in -if
get_db insts -if {[string match "*reg*" .name]}

# CORRECT - use foreach outside
foreach inst [get_db insts] {
    if {[string match "*reg*" [get_db $inst .name]]} { ... }
}
```

---

## Best Practices

1. **Empty checks**: Always use `== ""`
2. **Boolean attributes**: Prefer `!.is_xxx` for negation
3. **Pattern matching**: Use `string match` outside `-if` clause
4. **Test first**: Query sample objects before bulk operations
5. **Namespace safety**: Use `$::env(...)` and `$::ivar(...)` for global variables

---

## See Also

- **Official Docs**: `../docs/api_docs/` - Complete attribute specifications
- **Commands**: `commands.md` - get_db/set_db syntax
- **Cookbook**: `../cookbook.md` - Practical examples
- **Variables**: `variables.md` - Environment and flow variables

---

**📝 To add official documentation**:
```bash
# Store complete attribute reference PDFs/HTMLs
cp innovus_api_reference.pdf ../docs/api_docs/
```

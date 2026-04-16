# Innovus Command Reference

Curated command syntax and examples for Cadence Innovus.

> **📚 Official Documentation**: Store complete command references in `../docs/command_references/`  
> This file contains curated, practical knowledge extracted from official docs.

---

## Cadence Stylus Commands (Innovus-Specific)

⚠️ **These commands are part of Cadence Stylus Common UI and NOT compatible with Synopsys tools**

### Stylus-Only Commands
- **`get_db`** - Query database with attribute chains (Cadence ONLY)
- **`set_db`** - Modify database attributes (Cadence ONLY)

**Not available in**: Synopsys FC, Synopsys PT, or other vendor tools

See: `../../../common/cross_vendor_compatibility.md` for cross-vendor command comparison

---

## get_db - Query Database Objects

### Syntax
```tcl
get_db [<objects>] [-if <condition>] [.attribute] [-u | -unique]
```

### Common Flags
- **`-if <condition>`** - Filter objects by condition
- **`-u` | `-unique`** - Return unique values only (removes duplicate entries from list)
  - If attribute is a list, returns unique set of lists
  - Does NOT uniquify elements within each list (use `lsort -unique` for that)

### Advanced Flags
- **`-expr <expression>`** - Full TCL expression evaluation (supports proc calls, complex substitution)
- **`-foreach <tcl_body>`** - Process each object without creating full list (efficient for large datasets)
- **`-index {object | obj_type name}`** - Query specific index of array attributes (timing, multi-view)
- **`-computed`** - Force computation of timing values when browsing with patterns
- **`-dbu`** - Return coordinate values in database units (int) instead of microns (double)
- **`-depth {[min] max}`** - Expand hierarchy from min to max depth
- **`-category <category>`** - Query all root attributes in a category

### Basic Usage

```tcl
# Get all instances
get_db insts

# Get all ports
get_db ports

# Get design name
get_db designs .name

# Get all instance names
get_db insts .name
```

### Filtering with -if

```tcl
# Sequential cells only
get_db insts -if {.is_sequential}

# Input ports only
get_db ports -if {.direction == "in"}

# Ports without terminals
get_db ports -if {.physical_pins == ""}

# Combined conditions
get_db insts -if {.is_sequential && !.is_latch}
```

### Unique Values with -u | -unique

⚠️ **Important**: Use `-u` (or `-unique`) flag to remove duplicate entries from return list

```tcl
# Get unique library cell names (removes duplicate entries)
get_db insts .lib_cell.name -u
get_db insts .lib_cell.name -unique  # same as -u

# Get unique base cell names
get_db insts .base_cell.name -u

# Get unique net types
get_db nets .net_type -u

# Without -u: may return many duplicate values
# With -u: returns only unique values
```

**Behavior Note**: 
- Removes duplicate entries from the return list
- If the attribute is a list, returns unique set of lists
- Does NOT uniquify elements within each list - use `lsort -unique` for that

**Example - Counting Unique vs Total**:
```tcl
# Total instances using a cell (may have duplicates)
set total_count [llength [get_db insts .lib_cell.name]]

# Unique cells used (duplicates removed)
set unique_cells [llength [get_db insts .lib_cell.name -u]]

puts "Total instances: $total_count"
puts "Unique cells: $unique_cells"
```

### Attribute Access

```tcl
# Direct attribute (single value)
get_db designs .name

# Attribute from collection (multiple values)
get_db insts .name                    # All instance names
get_db ports .direction               # All port directions
get_db insts .lib_cell.name -u        # Unique lib cells (no duplicates)
```

### Nested Attributes

```tcl
# Access nested object attributes
get_db insts .base_cell.name
get_db insts .lib_cell.name
get_db ports .net.name
```

### Common Patterns

#### Get Object Counts
```tcl
set total_insts [llength [get_db insts]]
set total_ports [llength [get_db ports]]
set seq_cells [llength [get_db insts -if {.is_sequential}]]
```

#### Iterate Over Objects
```tcl
foreach inst [get_db insts] {
    set name [get_db $inst .name]
    set cell [get_db $inst .base_cell.name]
    puts "$name: $cell"
}
```

#### Get Unique Values
```tcl
# All unique VT types used in design
set vt_types [get_db insts .lib_cell.name -u]

# All unique net types
set net_types [get_db nets .net_type -u]
```

---

## set_db - Modify Database Objects

### Syntax
```tcl
set_db <objects> .attribute <value>
```

### Examples

```tcl
# Set instance property
set_db $inst .is_fixed true

# Set don't touch
set_db $inst .dont_touch true

# Set design property
set_db designs .route_design_with_si_driven true
```

---

## Common get_db Patterns

### Port Queries
```tcl
# All ports
get_db ports

# Input ports
get_db ports -if {.direction == "in"}

# Ports without terminals
get_db ports -if {.physical_pins == ""}

# Port names
get_db ports .name

# Unique port directions
get_db ports .direction -u
```

### Instance Queries
```tcl
# All instances
get_db insts

# Sequential cells
get_db insts -if {.is_sequential}

# Flip-flops (not latches)
get_db insts -if {.is_sequential && !.is_latch}

# Buffers
get_db insts -if {.base_cell.is_buffer}

# Unique cells used
get_db insts .base_cell.name -u
get_db insts .lib_cell.name -u
```

### Net Queries
```tcl
# All nets
get_db nets

# Signal nets
get_db nets -if {.net_type == "signal"}

# Clock nets
get_db nets -if {.net_type == "clock"}

# Unique net types
get_db nets .net_type -u
```

### Design Queries
```tcl
# Design name
get_db designs .name

# All instances in design
get_db designs .insts

# All ports in design
get_db designs .ports
```

---

## Advanced get_db Features

### -expr: Full TCL Expression Support

Use `-expr` for complex TCL expressions with proc calls, variable substitution, and escaping.

```tcl
# Filter with full TCL expression
get_db insts -expr {$obj(.base_cell.name) eq "AND2"}

# Complex expression with proc calls
get_db insts -expr {[string match "reg_*" $obj(.name)] && $obj(.is_sequential)}

# Access object itself
get_db insts -expr {$obj(.) ne ""}

# With chain and pattern
get_db $my_insts .pins i1/* -expr {$obj(.base_name) eq "A"}
```

**Note**: Cannot use `-expr` and `-if` together. Use `-expr` when you need full TCL semantics.

### -foreach: Process Without Creating Lists

Use `-foreach` to avoid memory overhead of creating long object lists.

```tcl
# Print names of all AND2 instances
get_db insts -if {.base_cell.name == AND2} -foreach {puts $obj(.name)}

# Count with foreach (returns count)
set count [get_db insts abc* -foreach {incr n}]

# Access attributes via $obj() array
get_db insts -foreach {
    puts "$obj(.name): $obj(.base_cell.name)"
}
```

**Benefits**: No list creation overhead, `break` and `continue` work as expected.

### -index: Array Attribute Queries

Use `-index` for attributes that vary by view, clock, or other dimensions.

```tcl
# Timing attributes by analysis view
get_db $my_pins .slack_max_rise -index "view func_wc_cworst"

# By view and clock
get_db $my_pins .slack_max_rise -index "view func_wc_cworst clock clk1"

# Using clock object (contains both view and clock)
set my_clk [get_db clocks -if {.view_name == func_wc_worst && .base_name == clk1}]
get_db $my_pins .slack_max_rise -index $my_clk

# Delay by view
get_db pins .delay_max_rise -index "view v1"
```

### -computed: Force Timing Calculation

Forces computation of timing-related attributes when browsing with patterns.

```tcl
# Without -computed: may show NC (not computed)
get_db $my_pins .slack_max*

# With -computed: computes timing graph if needed
get_db $my_pins .slack_max* -computed
```

**Note**: Single attribute names always compute. Only needed with patterns (`*` or `?`).

### -dbu: Database Units

Return coordinate/area values as integers in database units instead of doubles in microns.

```tcl
# Default: returns double in microns
get_db $my_inst .location
# {1.0 1.0}

# With -dbu: returns int in database units
get_db -dbu $my_inst .location
# {1000 1000}
```

### -depth: Hierarchy Traversal

Expand design or hinst hierarchy from min to max depth.

```tcl
# Get hinst and first level below it (depth 0 to 1)
get_db hinst:top/h1 -depth {0 1}

# Get all hinsts up to depth 3
get_db hinsts -depth 3
```

### -category: Query by Category

Get all root attributes associated with an application category.

```tcl
# All place-related attributes
get_db -category place

# All timing attributes
get_db -category timing

# List all categories
get_db categories
```

---

## Best Practices

1. **Use `-u` or `-unique` for unique values** when querying attributes that may repeat
   ```tcl
   # Good - removes duplicates
   get_db insts .lib_cell.name -u
   
   # Without -u - may return thousands of duplicates
   get_db insts .lib_cell.name
   ```

2. **Empty checks use `== ""`** not `== {}`
   ```tcl
   get_db ports -if {.physical_pins == ""}
   ```

3. **Pattern matching in -if** - must use `.name` for objects
   ```tcl
   # WRONG - won't match
   get_db insts -if {.base_cell == buf*}
   
   # CORRECT - match .name attribute
   get_db insts -if {.base_cell.name == buf*}
   ```

4. **Use `-foreach` for large datasets** to avoid memory overhead
   ```tcl
   # Memory efficient
   get_db insts -foreach {puts $obj(.name)}
   ```

5. **Use `-expr` for complex logic** when `-if` is insufficient
   ```tcl
   get_db insts -expr {[string match "*reg*" $obj(.name)] && $obj(.is_sequential)}
   ```

6. **Count with llength**
   ```tcl
   set count [llength [get_db insts -if {.is_sequential}]]
   ```

7. **Store objects for reuse**
   ```tcl
   set seq_cells [get_db insts -if {.is_sequential}]
   foreach cell $seq_cells { ... }
   ```

---

## See Also

- **Attributes**: `attributes.md` - Complete attribute reference
- **Cookbook**: `../cookbook.md` - Practical examples
- **Official TCR**: `../docs/command_references/InnovusTCRcom.txt` - Complete command documentation (line 50800+)

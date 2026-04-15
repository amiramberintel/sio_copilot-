################################################################################
#  ICC2 ECO FIX — brdispnotsignedm107h  (par_msid side)
#  Signal: par_msid → par_fe  |  WNS: -66ps (bit [40])
#  Model:  FCT26WW12A CLK045  |  Date: 2026-03-16
#
#  ┌──────┬──────────────────────────────────────────┬──────────┬──────┐
#  │ Fix  │ Description                              │ Gain(ps) │ Risk │
#  ├──────┼──────────────────────────────────────────┼──────────┼──────┤
#  │ M1   │ ND2SKFD2→D4 (ilgenstrvd)                │  1-2     │ LOW  │
#  │ M2   │ BUFFSKRD4→D12 (iqsteerd repeater)       │  3-5     │ LOW  │
#  │ M3   │ AO22D2→D4 (iqsteerd logic)              │  3-4     │ LOW  │
#  │ M4   │ Insert buffer on 67μm wire to sideload  │  3-5     │ MED  │
#  ├──────┼──────────────────────────────────────────┼──────────┼──────┤
#  │ TOTAL│                                          │ 10-16    │      │
#  └──────┴──────────────────────────────────────────┴──────────┴──────┘
#
#  All target cells verified LEGAL (not in illegal.txt)
#  PO: run STEP 0 first (verify), then apply one fix at a time
################################################################################


################################################################################
#  STEP 0 — VERIFY (non-destructive) — run this first!
################################################################################

puts "=========================================="
puts "  VERIFY: brdispnotsignedm107h par_msid fixes"
puts "=========================================="

set verify_errors 0

# M1: ND2SKFD2 in ilgenstrvd (suffix *444937*)
set c [get_cells -hier *444937* -quiet]
if {[sizeof_collection $c] > 0} {
    puts "M1 FOUND: [get_attribute $c full_name] ref=[get_attribute $c ref_name]"
} else {
    puts "M1 MISS: *444937* not found"
    incr verify_errors
}

# M2: BUFFSKRD4 repeater in iqsteerd (suffix *2052866*)
set c [get_cells -hier *2052866* -quiet]
if {[sizeof_collection $c] > 0} {
    puts "M2 FOUND: [get_attribute $c full_name] ref=[get_attribute $c ref_name]"
} else {
    puts "M2 MISS: *2052866* not found"
    incr verify_errors
}

# M3: AO22D2 logic gate in iqsteerd (suffix *1344918*)
set c [get_cells -hier *1344918* -quiet]
if {[sizeof_collection $c] > 0} {
    puts "M3 FOUND: [get_attribute $c full_name] ref=[get_attribute $c ref_name]"
} else {
    puts "M3 MISS: *1344918* not found"
    incr verify_errors
}

# M4: BUFFSR2D12 → check the driver for wire we'll buffer (suffix *983705*)
set c [get_cells -hier *983705* -quiet]
if {[sizeof_collection $c] > 0} {
    puts "M4 FOUND: [get_attribute $c full_name] ref=[get_attribute $c ref_name]"
} else {
    puts "M4 MISS: *983705* not found"
    incr verify_errors
}

# Also verify the sideload inverter (suffix *sideload_inv_2)
set c [get_cells -hier *brdispnotsignedm107h_0_x40x_sideload_inv_2 -quiet]
if {[sizeof_collection $c] > 0} {
    puts "M4-sink FOUND: [get_attribute $c full_name] ref=[get_attribute $c ref_name]"
} else {
    puts "M4-sink MISS: *sideload_inv_2 not found"
    incr verify_errors
}

puts "=========================================="
if {$verify_errors > 0} {
    puts "⚠ $verify_errors MISS(es) — DO NOT proceed until resolved"
} else {
    puts "✓ All cells found — safe to proceed with fixes"
}
puts "=========================================="


################################################################################
#  FIX M1: Size up ND2SKFD2 → ND2SKFD4 (ilgenstrvd, D2→D4)
#  Current: ND2SKFD2BWP156HPNPN3P48CPDULVT, delay=4.3ps
#  Target:  ND2SKFD4BWP156HPNPN3P48CPDULVT
#  Expected gain: 1-2ps  |  Risk: LOW (same footprint)
################################################################################

# Uncomment to apply:
# size_cell [get_cells -hier *444937*] ND2SKFD4BWP156HPNPN3P48CPDULVT
# update_timing
# report_timing -through [get_pins [get_cells -hier *444937*]/ZN] -max_paths 1

# Revert if needed:
# size_cell [get_cells -hier *444937*] ND2SKFD2BWP156HPNPN3P48CPDULVT


################################################################################
#  FIX M2: Size up BUFFSKRD4 → BUFFSKRD12 (iqsteerd repeater, D4→D12)
#  Current: BUFFSKRD4BWP156HNPPN3P48CPDULVT, delay=10.4ps!
#  Target:  BUFFSKRD12BWP156HNPPN3P48CPDULVT
#  Expected gain: 3-5ps  |  Risk: LOW (same footprint)
#  Note: High input trans (20.2ps) from upstream — sizing helps drive faster
################################################################################

# Uncomment to apply:
# size_cell [get_cells -hier *2052866*] BUFFSKRD12BWP156HNPPN3P48CPDULVT
# update_timing
# report_timing -through [get_pins [get_cells -hier *2052866*]/Z] -max_paths 1

# Revert if needed:
# size_cell [get_cells -hier *2052866*] BUFFSKRD4BWP156HNPPN3P48CPDULVT


################################################################################
#  FIX M3: Size up AO22D2 → AO22D4 (iqsteerd logic gate, D2→D4)
#  Current: AO22D2BWP156HNPPN3P48CPDULVT, delay=8.8ps!
#  Target:  AO22D4BWP156HNPPN3P48CPDULVT
#  Expected gain: 3-4ps  |  Risk: LOW (same footprint)
################################################################################

# Uncomment to apply:
# size_cell [get_cells -hier *1344918*] AO22D4BWP156HNPPN3P48CPDULVT
# update_timing
# report_timing -through [get_pins [get_cells -hier *1344918*]/Z] -max_paths 1

# Revert if needed:
# size_cell [get_cells -hier *1344918*] AO22D2BWP156HNPPN3P48CPDULVT


################################################################################
#  FIX M4: Insert buffer on 67μm wire (BUFFSR2D12 output → INVD16 sideload)
#  Wire: from (1481.5, 131.8)μm to (1486.7, 193.7)μm = 67μm Manhattan
#  Wire delay: 7.2ps + 11.2ps upstream = 18.4ps total
#  Buffer: BUFFD12BWP156HNPPN3P48CPDULVT at midpoint (1484136, 162775)
#  Expected gain: 3-5ps  |  Risk: MEDIUM (insert + move + route_eco)
################################################################################

# Uncomment to apply:
# set buf [insert_buffer \
#     [get_pins [get_cells -hier *brdispnotsignedm107h_0_x40x_sideload_inv_2]/I] \
#     BUFFD12BWP156HNPPN3P48CPDULVT]
# move_objects $buf -to {1484136 162775}
# route_eco
# update_timing
# report_timing -through [get_pins [get_cells -hier *brdispnotsignedm107h_0_x40x_sideload_inv_2]/ZN] -max_paths 1

# Revert if needed:
# remove_buffer $buf


################################################################################
#  POST-FIX VERIFICATION — run after all fixes
################################################################################

# Setup check (max):
# report_timing -through *brdispnotsignedm107h_0_*40* -max_paths 3
#
# Hold check (min) — MUST stay positive:
# report_timing -through *brdispnotsignedm107h_0_*40* -delay_type min -max_paths 3
#
# Check all bits:
# report_timing -through *brdispnotsignedm107h_0_* -max_paths 10
#
# Final:
# check_legality
# save_block

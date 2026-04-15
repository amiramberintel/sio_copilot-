################################################################################
#  ICC2 ECO FIX — brdispnotsignedm107h  (par_fe side)
#  Signal: par_msid → par_fe  |  WNS: -66ps (bit [40])
#  Model:  FCT26WW12A CLK045  |  Date: 2026-03-16
#
#  ┌──────┬──────────────────────────────────────────┬──────────┬──────┐
#  │ Fix  │ Description                              │ Gain(ps) │ Risk │
#  ├──────┼──────────────────────────────────────────┼──────────┼──────┤
#  │ F1   │ INVD4→D12 (ifbacs weak inverter)         │  3-4     │ LOW  │
#  │ F2   │ Insert repeater on 100μm wire to MBIT    │  5-8     │ MED  │
#  ├──────┼──────────────────────────────────────────┼──────────┼──────┤
#  │ TOTAL│                                          │  8-12    │      │
#  └──────┴──────────────────────────────────────────┴──────────┴──────┘
#
#  All target cells verified LEGAL (not in illegal.txt)
#  NOTE: Endpoint FF is MBIT bank (MB8, 8 bits) — DO NOT move it!
#  PO: run STEP 0 first (verify), then apply one fix at a time
################################################################################


################################################################################
#  STEP 0 — VERIFY (non-destructive) — run this first!
################################################################################

puts "=========================================="
puts "  VERIFY: brdispnotsignedm107h par_fe fixes"
puts "=========================================="

set verify_errors 0

# F1: INVD4 weak inverter in ifbacs (suffix *15630*)
set c [get_cells -hier *15630*brdispnotsignedm107h* -quiet]
if {[sizeof_collection $c] > 0} {
    puts "F1 FOUND: [get_attribute $c full_name] ref=[get_attribute $c ref_name]"
} else {
    # Try broader search
    set c [get_cells -hier *OFC15630* -quiet]
    if {[sizeof_collection $c] > 0} {
        puts "F1 FOUND (broad): [get_attribute $c full_name] ref=[get_attribute $c ref_name]"
    } else {
        puts "F1 MISS: *15630*brdispnotsignedm107h* not found"
        incr verify_errors
    }
}

# F2: INVSKRLPOD12 → check the driver before the long wire (suffix *788267*)
set c [get_cells -hier *788267*brdispnotsignedm107h* -quiet]
if {[sizeof_collection $c] > 0} {
    puts "F2 FOUND: [get_attribute $c full_name] ref=[get_attribute $c ref_name]"
} else {
    set c [get_cells -hier *OFC788267* -quiet]
    if {[sizeof_collection $c] > 0} {
        puts "F2 FOUND (broad): [get_attribute $c full_name] ref=[get_attribute $c ref_name]"
    } else {
        puts "F2 MISS: *788267*brdispnotsignedm107h* not found"
        incr verify_errors
    }
}

# Endpoint MBIT FF (verify it exists and is MBIT)
set c [get_cells -hier *MBIT_BrDispNotSignedM108H_reg_0__40_* -quiet]
if {[sizeof_collection $c] > 0} {
    puts "EP FOUND: [get_attribute $c full_name] ref=[get_attribute $c ref_name]"
} else {
    puts "EP MISS: endpoint MBIT FF not found"
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
#  FIX F1: Size up INVD4 → INVD12 (ifbacs, D4→D12)
#  Current: INVD4BWP156HNPPN3P48CPDULVT, delay=6.4ps, input trans=24.4ps!
#  Target:  INVD12BWP156HNPPN3P48CPDULVT
#  Expected gain: 3-4ps  |  Risk: LOW (same footprint)
#  Note: Very high input trans (24.4ps) from 18.1ps wire — D4 is too weak
#        D12 will handle the 18.8fF output load much better
################################################################################

# Uncomment to apply:
# size_cell [get_cells -hier *OFC15630*brdispnotsignedm107h*] \
#     INVD12BWP156HNPPN3P48CPDULVT
# update_timing
# report_timing -through [get_pins [get_cells -hier *OFC15630*brdispnotsignedm107h*]/ZN] \
#     -max_paths 1

# Revert if needed:
# size_cell [get_cells -hier *OFC15630*brdispnotsignedm107h*] \
#     INVD4BWP156HNPPN3P48CPDULVT


################################################################################
#  FIX F2: Insert repeater on 100μm vertical wire to MBIT endpoint
#  Wire: from INVSKRLPOD12 at (1523.2, 263.4)μm to MBIT at (1525.4, 363.1)μm
#  Distance: 2.2μm X + 99.7μm Y = ~102μm Manhattan
#  Wire delay: 15.3ps with 18.5fF load — THIS IS THE BIGGEST SINGLE DELAY
#  Buffer: BUFFD12BWP156HNPPN3P48CPDULVT at midpoint (1524264, 313285)
#  Expected gain: 5-8ps  |  Risk: MEDIUM (insert + move + route_eco)
#  ⚠ DO NOT move the endpoint MBIT FF — it's a fixed MB8 bank!
################################################################################

# Uncomment to apply:
# set buf [insert_buffer \
#     [get_pins [get_cells -hier *MBIT_BrDispNotSignedM108H_reg_0__38_*]/D2] \
#     BUFFD12BWP156HNPPN3P48CPDULVT]
# move_objects $buf -to {1524264 313285}
# route_eco
# update_timing
# report_timing -to [get_pins [get_cells -hier *MBIT_BrDispNotSignedM108H_reg_0__38_*]/D2] \
#     -max_paths 1

# Revert if needed:
# remove_buffer $buf


################################################################################
#  POST-FIX VERIFICATION — run after all fixes
################################################################################

# Setup check (max):
# report_timing -to *MBIT_BrDispNotSignedM108H_reg_0__40_*/D2 -max_paths 3
#
# Hold check (min) — MUST stay positive:
# report_timing -to *MBIT_BrDispNotSignedM108H_reg_0__40_*/D2 -delay_type min -max_paths 3
#
# Check ALL 8 bits in the MBIT bank (38,40,41,42,45,47,49,52):
# report_timing -to *MBIT_BrDispNotSignedM108H_reg_0__38_*/D* -max_paths 8
#
# Final:
# check_legality
# save_block

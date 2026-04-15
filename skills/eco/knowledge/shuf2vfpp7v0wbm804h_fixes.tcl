###############################################################################
#  shuf2vfpp7v0wbm804h_data[*] — Timing Fix ECO Script (par_exe)
#  Signal: par_exe → par_fmav0  |  WNS: -49ps  |  73,337 paths
#  Model:  FCT26WW11C  |  Generated: 2026-03-12
#
#  INSTRUCTIONS:
#    1. Open par_exe block in ICC2
#    2. Run STEP 0 first — verify all cells/nets exist
#    3. Apply fixes section by section, check timing after each
#    4. Comment out any fix you don't want
#
#  FIXES INCLUDED:
#    DATA PATH  (~27-33ps gain):
#      Fix 1a: INR2D1 → D4            ~3ps    LOW risk
#      Fix 1b: MUXAO4D1 → D2          ~3ps    LOW risk
#      Fix 1c: INVD4 → D8             ~1.5ps  LOW risk
#      Fix 2:  Buffer HFSNET_507       ~8-11ps LOW risk
#      Fix 3:  Size port driver D8→D16 ~3-5ps  MED risk
#      Fix B1: Buffer HFSNET_131       ~4-5ps  LOW risk
#      Fix B2: Buffer tropt_net        ~4-5ps  LOW risk
#    CLOCK TREE (~4-8ps gain):
#      CLK 1a: CKND9 → CKND12         ~1-2ps  LOW risk
#      CLK 1b: CKND12 → CKND16        ~1-2ps  LOW risk
#
#  EXPECTED: WNS -49ps → ~-8 to -18ps
###############################################################################

puts "================================================================"
puts "  STEP 0: VERIFY — Check all cells and nets exist"
puts "================================================================"

set errors 0

# --- Data path cells ---
set dp_cells {
    "Fix1a INR2D1"   {exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_ctmTdsLR_1_4757944}
    "Fix1b MUXAO4D1" {exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_ctmTdsLR_1_4647004}
    "Fix1c INVD4"    {route_auto_tropt_d_inst_6774874}
    "Fix2  BUFFD12"  {exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_HFSBUF_158_2996657}
    "Fix2  IAOI21D4" {exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_ctmTdsLR_1_3924589}
    "Fix3  BUFFSRD8" {route_opt_ropt_mt_inst_6944842}
    "FixB1 NR2D16"   {exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_ctmTdsLR_4_4080370}
    "FixB1 ND2D4"    {exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_ctmTdsLR_2_4293068}
    "FixB2 INVD8"    {route_auto_tropt_d_inst_6774875}
}

# --- Clock cells ---
set clk_cells {
    "CLK1a CKND9"  {exe_vec/shuf/shufp7v0c/ZCTSINV_721}
    "CLK1b CKND12" {exe_vec/shuf/shufp7v0c/ZCTSINV_539}
}

# --- Nets ---
set fix_nets {
    "HFSNET_507"      {exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_HFSNET_507}
    "HFSNET_131"      {exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_HFSNET_131}
    "tropt_4327106"   {tropt_net_4327106}
}

puts "\n  Data path cells:"
foreach {tag cell} $dp_cells {
    set c [get_cells -quiet $cell]
    if {[sizeof_collection $c] == 0} {
        puts "  ✗ $tag  NOT FOUND: $cell"
        incr errors
    } else {
        set ref [get_attribute $c ref_name]
        puts "  ✓ $tag  = $ref"
    }
}

puts "\n  Clock cells:"
foreach {tag cell} $clk_cells {
    set c [get_cells -quiet $cell]
    if {[sizeof_collection $c] == 0} {
        puts "  ✗ $tag  NOT FOUND: $cell"
        puts "    → Try: get_cells *ZCTSINV_721  (hierarchy may differ)"
        incr errors
    } else {
        set ref [get_attribute $c ref_name]
        puts "  ✓ $tag  = $ref"
    }
}

puts "\n  Nets:"
foreach {tag net} $fix_nets {
    set n [get_nets -quiet $net]
    if {[sizeof_collection $n] == 0} {
        puts "  ✗ $tag  NOT FOUND: $net"
        incr errors
    } else {
        puts "  ✓ $tag  found"
    }
}

if {$errors > 0} {
    puts "\n  *** $errors items not found — fix paths above before continuing ***"
    puts "  *** Script will continue but failing commands will error ***"
}

puts "\n  Pre-fix timing:"
report_timing -through [get_pins exe_vec/shuf/shufp7v0c/sishufld/shufS3dataM305H_reg_18_/Q] \
    -max_paths 1 -nosplit


###############################################################################
#  DATA PATH FIXES
###############################################################################

puts "\n================================================================"
puts "  FIX 1a: INR2D1 → INR2D4  (cell sizing, ~3ps gain)"
puts "  Cell: compile_initial_opto_ctmTdsLR_1_4757944"
puts "  Current delay: 6.0ps → expected ~3ps"
puts "================================================================"

size_cell \
    exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_ctmTdsLR_1_4757944 \
    INR2D4BWP156HPNPN3P48CPDULVT


puts "\n================================================================"
puts "  FIX 1b: MUXAO4D1 → MUXAO4D2  (cell sizing, ~3ps gain)"
puts "  Cell: compile_initial_opto_ctmTdsLR_1_4647004"
puts "  Current delay: 10.3ps → expected ~7ps"
puts "================================================================"

size_cell \
    exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_ctmTdsLR_1_4647004 \
    MUXAO4NBFITLICMD2BWP156HPNPN3P48CPDULVT


puts "\n================================================================"
puts "  FIX 1c: INVD4 → INVD8  (cell sizing, ~1.5ps gain)"
puts "  Cell: route_auto_tropt_d_inst_6774874"
puts "  Current delay: 4.0ps → expected ~2.5ps"
puts "  Note: receives 22.7ps input tran from long wire"
puts "================================================================"

size_cell \
    route_auto_tropt_d_inst_6774874 \
    INVD8BWP156HPNPN3P48CPDULVT


puts "\n================================================================"
puts "  FIX 2: BUFFER HFSNET_507  (wire buffering, ~8-11ps gain)"
puts "  Wire: 72.5um, 16.7ps, fanout 4"
puts "  From: BUFFD12 (445464,1171593)"
puts "  To:   IAOI21D4 (517848,1171467)"
puts "  Insert buffer at midpoint (480000, 1171500)"
puts "================================================================"
# insert_buffer on the sink pin — splits the net at that point
# The original net stays on the driver side, new net on buffer→sink side

set buf2 [insert_buffer \
    [get_pins exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_ctmTdsLR_1_3924589/A1] \
    BUFFD12BWP156HNPPN3P48CPDULVT]

if {[sizeof_collection $buf2] > 0} {
    set buf2_name [get_attribute $buf2 name]
    # Place at midpoint of the 72.5um wire
    move_objects $buf2 -to {480000 1171500}
    puts "  ✓ Buffer inserted: $buf2_name"
    puts "  ✓ Placed at (480000, 1171500)"
} else {
    puts "  ✗ insert_buffer FAILED — check pin path"
}


puts "\n================================================================"
puts "  FIX 3: SIZE PORT DRIVER D8 → D16  (sizing, ~3-5ps gain)"
puts "  Cell: route_opt_ropt_mt_inst_6944842"
puts "  Net fanout: 11 — sizing driver helps all sinks"
puts "  RISK: MEDIUM — 10 other sinks share this net"
puts "         Check slack on other sinks after this change!"
puts "================================================================"

size_cell \
    route_opt_ropt_mt_inst_6944842 \
    BUFFSR2BFYDHD16BWP156HPNPN3P48CPDULVTLL


puts "\n================================================================"
puts "  FIX B1: BUFFER HFSNET_131  (wire buffering, ~4-5ps gain)"
puts "  Wire: 45um, 12.4ps, fanout 1"
puts "  From: NR2SKRLPOD16 (520584,1169721)"
puts "  To:   ND2D4 (479448,1165858)"
puts "  Insert buffer at midpoint (500000, 1167500)"
puts "================================================================"

set bufB1 [insert_buffer \
    [get_pins exe_vec/shuf/shufp7v0c/sishufld/compile_initial_opto_ctmTdsLR_2_4293068/A2] \
    BUFFD8BWP156HNPPN3P48CPDULVT]

if {[sizeof_collection $bufB1] > 0} {
    set bufB1_name [get_attribute $bufB1 name]
    move_objects $bufB1 -to {500000 1167500}
    puts "  ✓ Buffer inserted: $bufB1_name"
    puts "  ✓ Placed at (500000, 1167500)"
} else {
    puts "  ✗ insert_buffer FAILED — check pin path"
}


puts "\n================================================================"
puts "  FIX B2: BUFFER tropt_net_4327106  (wire buffering, ~4-5ps gain)"
puts "  Wire: 65um, 12.5ps, fanout 1"
puts "  From: INVD8 (449976,1168191)"
puts "  To:   INVD4 (438648,1222338)"
puts "  Insert buffer at midpoint (444000, 1195000)"
puts "================================================================"

set bufB2 [insert_buffer \
    [get_pins route_auto_tropt_d_inst_6774874/I] \
    BUFFD8BWP156HPNPN3P48CPDULVT]

if {[sizeof_collection $bufB2] > 0} {
    set bufB2_name [get_attribute $bufB2 name]
    move_objects $bufB2 -to {444000 1195000}
    puts "  ✓ Buffer inserted: $bufB2_name"
    puts "  ✓ Placed at (444000, 1195000)"
} else {
    puts "  ✗ insert_buffer FAILED — check pin path"
}


###############################################################################
#  CLOCK TREE FIXES
###############################################################################

puts "\n================================================================"
puts "  CLK FIX 1a: CKND9 → CKND12  (sizing, ~1-2ps gain)"
puts "  Cell: ZCTSINV_721 (CTS inverter in launch clock)"
puts "  Risk: LOW — just sizing, same topology"
puts "================================================================"
# NOTE: verify the lib cell suffix matches your library
#       run: get_attribute [get_cells exe_vec/shuf/shufp7v0c/ZCTSINV_721] ref_name
#       to see the current lib cell, then change only the drive strength

size_cell \
    exe_vec/shuf/shufp7v0c/ZCTSINV_721 \
    CKND12BWP156HPNPN3P48CPDULVT


puts "\n================================================================"
puts "  CLK FIX 1b: CKND12 → CKND16  (sizing, ~1-2ps gain)"
puts "  Cell: ZCTSINV_539 (CTS inverter in launch clock)"
puts "  This INV feeds 6 ICGs + 171 FFs downstream"
puts "  Risk: LOW — sizing only, but verify hold after"
puts "================================================================"

size_cell \
    exe_vec/shuf/shufp7v0c/ZCTSINV_539 \
    CKND16BWP156HPNPN3P48CPDULVT


###############################################################################
#  POST-FIX VERIFICATION
###############################################################################

puts "\n================================================================"
puts "  POST-FIX: TIMING CHECK"
puts "================================================================"

puts "\n--- SETUP (max) check on fixed path ---"
report_timing -through [get_pins exe_vec/shuf/shufp7v0c/sishufld/shufS3dataM305H_reg_18_/Q] \
    -max_paths 1 -nosplit -path_type full -delay_type max \
    -nets -input_pins -transition_time

puts "\n--- HOLD (min) check — must stay positive! ---"
report_timing -through [get_pins exe_vec/shuf/shufp7v0c/sishufld/shufS3dataM305H_reg_18_/Q] \
    -max_paths 1 -nosplit -path_type full -delay_type min

puts "\n--- Check worst slack across ALL bits ---"
report_timing -through [get_pins exe_vec/shuf/shufp7v0c/sishufld/shufS3dataM305H_reg_*/Q] \
    -max_paths 5 -nosplit -delay_type max

puts "\n--- Check the 10 other sinks on the port net (Fix 3 impact) ---"
report_timing -through [get_pins route_opt_ropt_mt_inst_6944842/Z] \
    -max_paths 5 -nosplit -delay_type max

puts "\n================================================================"
puts "  ALL FIXES APPLIED"
puts "  Expected: WNS -49ps → ~-8 to -18ps"
puts ""
puts "  NEXT STEPS:"
puts "    1. Review timing numbers above"
puts "    2. Check DRC: check_legality"
puts "    3. Route new buffers: route_eco"
puts "    4. Full timing: report_timing -max_paths 10"
puts "    5. If hold violated → revert clock sizing"
puts "================================================================"

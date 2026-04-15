SKILL: specs
PRIORITY: HIGH
STATUS: HAVE
TRIGGERS: spec, io delay, input delay, output delay, set_input_delay, set_output_delay,
          constraint, relax, stress, scale spec, spec file, io_constraint, spec_csv2xml

DESCRIPTION
-----------
IO spec/constraint management for GFC SIO timing.
Create, modify, scale, stress-test IO delay constraints.
Convert between CSV and XML spec formats.

AVAILABLE SCRIPTS (IO MANIPULATION)
------------------------------------
scripts/Add_IO_delay                        -- Add IO delay constraint to pin
scripts/Add_max_delay                       -- Add max_delay constraint
scripts/Change_IO_delay_in_IO_constraint    -- Modify existing IO delay value
scripts/Relax_IO_delay                      -- Relax IO delay by specified amount
scripts/Remove_IO_delay_in_IO_constraint    -- Remove IO delay constraint
scripts/Stress_IO_delay                     -- Stress-test IO delay
scripts/Stress_all_mclk_output_delay        -- Stress all mclk output delays
scripts/scale_spec_file.py                  -- Scale entire spec CSV by factor
scripts/spec_csv2xml.py                     -- Convert spec CSV to XML format
scripts/sio_spec_ci.py                      -- Spec CI integration

IO_MANIP USAGE
--------------
All IO_manip scripts use similar syntax:
  Add_IO_delay    -pin <pin> -clock <clk> -value <ps> -direction <in|out>
  Relax_IO_delay  -pin <pin> -clock <clk> -relax_by <ps>
  Change_IO_delay_in_IO_constraint -pin <pin> -clock <clk> -value <new_ps>
  Remove_IO_delay_in_IO_constraint -pin <pin> -clock <clk>

Scale spec file:
  python3 scale_spec_file.py <factor> <input.csv> <output.csv>
  Example: python3 scale_spec_file.py 0.95 spec_WW15.csv spec_WW15_scaled.csv

SOURCE: /nfs/site/disks/home_user/baselibr/GFC_script/IO_manip/
        /nfs/site/disks/sunger_wa/skills_for_sio_copilot/

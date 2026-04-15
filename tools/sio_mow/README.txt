TOOL: sio_mow (Map of World)
STATUS: HAVE
TRIGGERS: mow, map of world, carpet, visualization, port map, partition carpet

DESCRIPTION
-----------
SIO Map of World -- web-based visualization of partition port timing.
Shows partition-level carpet view with slack per port, path exploration,
and PT server integration. Built on Dash/Plotly framework.

COMPONENTS
----------
scripts/sio_mow.py               -- Main MOW web application (Dash)
scripts/carpet_path_explorer.py   -- Path explorer visualization
scripts/make_path_worst_analysis.py -- Worst path analysis generator
tcl/sio_common.tcl                -- TCL procs for MOW data extraction
tcl/carpet.tcl                    -- Carpet data generation in PT
modules/sio_mow_common.py         -- Shared MOW utilities
modules/sio_mow_db.py             -- Database layer
modules/sio_mow_ports_table.py    -- Port table rendering
modules/pt_session.py             -- PT server session management
modules/sio_mow_hsdes.py          -- HSDES integration
modules/sio_basel_scripts.py      -- Basel's script integration

USAGE
-----
In PT shell:
  source tcl/carpet.tcl
  load_carpet {par_meu par_exe}
  -- Opens web carpet at http://<host>:8050

Standalone:
  python3 sio_mow.py -out_file <csv> -new <port_tns.csv> -pt_server_address localhost

SOURCE: /nfs/site/disks/ayarokh_wa/tools/sio_mow/
AUTHOR: ayarokh (Amir Yarokh)

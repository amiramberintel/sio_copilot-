TOOL: PrimeTime (PT Shell)
Synopsys STA engine -- the source of truth for timing.

ACCESS:
  Remote: via pt_server/ (pt_client.pl) -- fast, pre-loaded
  Local:  pt_shell (needs design load, 2-4 hours)

KEY CONCEPTS:
  GBA = Graph-Based Analysis (default, conservative)
  PBA = Path-Based Analysis (more accurate, removes pessimism)
    -pba_mode path: single paths, typical 5-15ps improvement
    -pba_mode exhaustive: full analysis, slow but most accurate

TIMING PATH ANATOMY:
  Data arrival = launch_clock + data_path_delay
  Data required = capture_clock + uncertainty - setup_time
  Slack = required - arrival (positive = OK, negative = FAIL)

SEE ALSO: tools/pt_server/ (remote access), tools/pt_eco/ (ECO mode)

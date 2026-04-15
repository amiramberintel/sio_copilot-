SKILL: Clock Timing (Push/Pull/Rebalance/Reconnect)
TRIGGERS: clock push, clock pull, push clock, pull clock, FF reconnect, clock latency, rebalance, skew, CTS, clock tree, clock eco
PRIORITY: P2
STATUS: PARTIAL

WHAT:
  Clock manipulation for timing fix: push/pull clock latency,
  reconnect FF to different clock, rebalance clock tree, analyze skew.
  "What if I push clock +5ps on max_high?"

KEY CONCEPTS:
  - Push clock = increase clock latency at endpoint (helps setup, hurts hold)
  - Pull clock = decrease clock latency (helps hold, hurts setup)
  - Rebalance = adjust skew between source/destination clocks
  - Reconnect FF = move FF from one clock to another

IMPACT ANALYSIS:
  +Xps clock push -> setup improves by +Xps on ALL setup corners
                  -> hold degrades by -Xps on ALL hold corners
  Must check ALL corners (config/corners.cfg) before deciding.

PREREQS:
  - Partition constraints (partitions/<par>/constraints/)
  - PT access for current timing
  - Know which FF and which clock endpoint

SEE ALSO:
  skills/eco/, tools/pt_eco/, tools/primetime/, skills/reporting/templates/what_if.txt

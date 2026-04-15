#!/bin/bash
#==============================================================================
#  cleanup_x11.sh — Kill stale xterm processes to fix X11 client overflow
#  
#  Usage:
#    ./cleanup_x11.sh              # Dry run — show status only
#    ./cleanup_x11.sh --kill-old   # Kill xterms older than 7 days
#    ./cleanup_x11.sh --kill-all   # Kill ALL xterms except PT sessions
#
#  Protected (never killed):
#    - PT sessions (core_client_BU, pt_shell)
#    - Netbatch ION session (nbjobleader)
#==============================================================================

MODE="${1:---status}"
USER=$(whoami)
AGE_LIMIT_DAYS=7

echo "============================================================"
echo "  X11 Client Cleanup"
echo "  User: $USER"
echo "  Mode: $MODE"
echo "============================================================"
echo ""

# Count all xterms
TOTAL=$(ps -u $USER -o pid,etime,cmd 2>/dev/null | grep -i xterm | grep -v grep | wc -l)
echo "Total xterm processes: $TOTAL"
echo ""

if [ "$TOTAL" -eq 0 ]; then
    echo "No xterms running. X11 issue may be something else."
    echo "Try: echo \$DISPLAY  (should not be empty)"
    exit 0
fi

# Categorize
echo "--- PT sessions (PROTECTED) ---"
ps -u $USER -o pid,etime,cmd 2>/dev/null | grep -i xterm | grep -v grep | grep -iE "core_client_BU|pt_shell|primetime" || echo "  (none)"
echo ""

echo "--- Workspace xterms (msurom/rowbank/rfip etc.) ---"
ps -u $USER -o pid,etime,cmd 2>/dev/null | grep -i xterm | grep -v grep | grep -iE "msurom|rowbank|rfip|workspace" | wc -l
echo ""

echo "--- Standalone xterms ---"
ps -u $USER -o pid,etime,cmd 2>/dev/null | grep "xterm -ls" | grep -v grep | wc -l
echo ""

echo "--- By age ---"
while IFS= read -r line; do
    pid=$(echo "$line" | awk '{print $1}')
    etime=$(echo "$line" | awk '{print $2}')
    
    # Parse elapsed time (dd-HH:MM:SS or HH:MM:SS or MM:SS)
    if echo "$etime" | grep -q '-'; then
        days=$(echo "$etime" | cut -d'-' -f1)
    else
        days=0
    fi
    
    if [ "$days" -ge 30 ]; then
        old_30=$((${old_30:-0} + 1))
    elif [ "$days" -ge 7 ]; then
        old_7=$((${old_7:-0} + 1))
    elif [ "$days" -ge 1 ]; then
        old_1=$((${old_1:-0} + 1))
    else
        fresh=$((${fresh:-0} + 1))
    fi
done < <(ps -u $USER -o pid,etime,cmd 2>/dev/null | grep -i xterm | grep -v grep)

echo "  > 30 days old: ${old_30:-0}"
echo "  7-30 days old: ${old_7:-0}"
echo "  1-7 days old:  ${old_1:-0}"
echo "  < 1 day old:   ${fresh:-0}"
echo ""

# Status only mode
if [ "$MODE" = "--status" ]; then
    echo "Dry run. Use --kill-old or --kill-all to clean up."
    exit 0
fi

# Build kill list
KILL_PIDS=""
KILL_COUNT=0
SKIP_COUNT=0

while IFS= read -r line; do
    pid=$(echo "$line" | awk '{print $1}')
    etime=$(echo "$line" | awk '{print $2}')
    cmd=$(echo "$line" | awk '{$1=""; $2=""; print $0}')
    
    # PROTECT: PT sessions
    if echo "$cmd" | grep -qiE "core_client_BU|pt_shell|primetime"; then
        echo "  SKIP (PT session): PID $pid"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi
    
    # PROTECT: Netbatch
    if echo "$cmd" | grep -qiE "nbjobleader|netbatch"; then
        echo "  SKIP (netbatch): PID $pid"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi
    
    # Parse days
    if echo "$etime" | grep -q '-'; then
        days=$(echo "$etime" | cut -d'-' -f1)
    else
        days=0
    fi
    
    if [ "$MODE" = "--kill-old" ] && [ "$days" -lt "$AGE_LIMIT_DAYS" ]; then
        echo "  SKIP (< ${AGE_LIMIT_DAYS}d): PID $pid ($etime)"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi
    
    KILL_PIDS="$KILL_PIDS $pid"
    KILL_COUNT=$((KILL_COUNT + 1))
    
done < <(ps -u $USER -o pid,etime,cmd 2>/dev/null | grep -i xterm | grep -v grep)

echo ""
echo "Will kill: $KILL_COUNT xterms"
echo "Protected: $SKIP_COUNT xterms"
echo ""

if [ "$KILL_COUNT" -eq 0 ]; then
    echo "Nothing to kill."
    exit 0
fi

# Kill
for pid in $KILL_PIDS; do
    kill $pid 2>/dev/null && echo "  Killed PID $pid"
done

echo ""
echo "Done. Remaining xterms:"
ps -u $USER -o pid,cmd 2>/dev/null | grep -i xterm | grep -v grep | wc -l
echo ""

# Verify clipboard
echo "Testing clipboard..."
if echo "clipboard_test" | xclip -selection clipboard 2>/dev/null; then
    echo "  Clipboard is working!"
else
    echo "  Clipboard still broken. May need to kill more or reconnect SSH."
fi

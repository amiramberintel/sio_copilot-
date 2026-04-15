#!/bin/bash
#==============================================================================
#  open_pt_session.sh — Open a local PT session from daily saved database
#  Usage:  ./open_pt_session.sh <daily_path> <corner> [tech]
#  
#  Examples:
#    ./open_pt_session.sh /nfs/site/disks/idc_gfc_fct_bu_daily/work_area/GFC_CLIENT_26ww12b_ww13_1_initial_with_TIP-FCT26WW15G_dcm_daily-CLK050.bu_postcts func.max_high
#    ./open_pt_session.sh <daily_path> func.min_low
#    ./open_pt_session.sh <daily_path> fresh.min_fast n2p_htall_conf4
#
#  This opens PT interactively — bypasses pt_client server (works on weekends!)
#==============================================================================

DAILY="$1"
CORNER="$2"
TECH="${3:-n2p_htall_conf4}"

if [ -z "$DAILY" ] || [ -z "$CORNER" ]; then
    echo "Usage: $0 <daily_path> <corner> [tech]"
    echo ""
    echo "Available corners (typical):"
    echo "  SETUP:  func.max_high  func.max_low  func.max_med  func.max_nom"
    echo "  HOLD:   func.min_low   func.min_nom"
    echo "  FRESH:  fresh.min_fast  fresh.min_fast_cold  fresh.min_slow"
    echo "          fresh.min_hi_hi_lo  fresh.min_hi_lo_hi  fresh.min_lo_hi_hi"
    echo "          fresh.min_hvqk"
    echo ""
    echo "Default tech: n2p_htall_conf4"
    exit 1
fi

# Map short corner names to full directory names
case "$CORNER" in
    func.max_high|max_high|high)
        CORNER_DIR="func.max_high.T_85.typical" ;;
    func.max_low|max_low|low)
        CORNER_DIR="func.max_low.T_85.typical" ;;
    func.max_med|max_med|med)
        CORNER_DIR="func.max_med.T_85.typical" ;;
    func.max_nom|max_nom|nom)
        CORNER_DIR="func.max_nom.T_85.typical" ;;
    func.min_low|min_low)
        CORNER_DIR="func.min_low.T_85.typical" ;;
    func.min_nom|min_nom)
        CORNER_DIR="func.min_nom.T_85.typical" ;;
    fresh.min_fast|min_fast|fast)
        CORNER_DIR="fresh.min_fast.F_125.rcworst_CCworst" ;;
    fresh.min_fast_cold|min_fast_cold|fast_cold)
        CORNER_DIR="fresh.min_fast_cold.F_M40.rcworst_CCworst" ;;
    fresh.min_slow|min_slow|slow)
        CORNER_DIR="fresh.min_slow.S_125.cworst_CCworst" ;;
    fresh.min_slow_cold|min_slow_cold|slow_cold)
        CORNER_DIR="fresh.min_slow_cold.S_M40.cworst_CCworst" ;;
    fresh.min_hvqk|min_hvqk|hvqk)
        CORNER_DIR="fresh.min_hvqk.F_125.rcworst_CCworst" ;;
    fresh.min_hi_hi_lo|hi_hi_lo)
        CORNER_DIR="fresh.min_hi_hi_lo.T_85.typical" ;;
    fresh.min_hi_lo_hi|hi_lo_hi)
        CORNER_DIR="fresh.min_hi_lo_hi.T_85.typical" ;;
    fresh.min_lo_hi_hi|lo_hi_hi)
        CORNER_DIR="fresh.min_lo_hi_hi.T_85.typical" ;;
    *)
        # Try as-is (user gave full directory name)
        CORNER_DIR="$CORNER" ;;
esac

SESSION_PATH="$DAILY/runs/core_client/$TECH/sta_pt/$CORNER_DIR/outputs/core_client.pt_session.$CORNER_DIR"
LOADER="/p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh"

# Validate paths
if [ ! -d "$DAILY" ]; then
    echo "-E- Daily path not found: $DAILY"
    exit 1
fi

if [ ! -d "$SESSION_PATH" ]; then
    echo "-E- PT session not found: $SESSION_PATH"
    echo ""
    echo "Available corners in this daily:"
    ls "$DAILY/runs/core_client/$TECH/sta_pt/" 2>/dev/null | grep -v dmsa
    exit 1
fi

if [ ! -f "$LOADER" ]; then
    echo "-E- load_session_cth.csh not found at: $LOADER"
    exit 1
fi

TITLE="core_client_BU_$(echo $CORNER | sed 's/.*\.//')"

echo "============================================================"
echo "  Opening PT session"
echo "  Daily:   $(basename $DAILY)"
echo "  Corner:  $CORNER_DIR"
echo "  Tech:    $TECH"
echo "  Title:   $TITLE"
echo "  Session: $SESSION_PATH"
echo "============================================================"
echo ""
echo "Loading... (this may take 15-30 minutes for full chip)"
echo ""

sg soc -c "$LOADER $SESSION_PATH -title $TITLE"

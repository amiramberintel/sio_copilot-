#!/bin/bash
# Open interactive PT shell on NB machine for any model + corner
#
# Usage:  source open_pt.sh [model] [corner]
#
# Models (short names):
#   daily      -> latest daily build (WW16C/CLK056)        [DEFAULT]
#   release    -> latest release (WW16A/CLK050)
#   prev       -> previous release (WW15A/CLK050)
#   noise      -> noise daily
#   /full/path -> any custom work area path
#
# Corners (short names):
#   max_high   -> func.max_high.T_85.typical               [DEFAULT]
#   max_med    -> func.max_med.T_85.typical
#   max_low    -> func.max_low.T_85.typical
#   max_nom    -> func.max_nom.T_85.typical
#   min_low    -> func.min_low.T_85.typical
#   min_high   -> func.min_high.T_85.typical
#   min_fast   -> fresh.min_fast.F_125.rcworst_CCworst
#
# Examples:
#   source open_pt.sh                        # daily max_high
#   source open_pt.sh daily max_med          # daily max_med
#   source open_pt.sh release max_high       # release max_high
#   source open_pt.sh prev min_low           # previous release hold
#   source open_pt.sh /my/custom/ward max_high  # custom WA

GFC_LINKS="/nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/GFC/links"

# --- Model selection ---
MODEL_INPUT="${1:-daily}"
case "$MODEL_INPUT" in
  daily)    WARD=$(readlink -f "$GFC_LINKS/daily_gfc0a_n2_core_client_bu_postcts") ;;
  release)  WARD=$(readlink -f "$GFC_LINKS/latest_gfc0a_n2_core_client_bu_postcts") ;;
  prev)     WARD=$(readlink -f "$GFC_LINKS/prev_gfc0a_n2_core_client_bu_postcts") ;;
  noise)    WARD=$(readlink -f "$GFC_LINKS/noise_daily_gfc0a_n2_core_client_bu_postcts") ;;
  /*)       WARD="$MODEL_INPUT" ;;
  *)        echo "ERROR: Unknown model '$MODEL_INPUT'. Use: daily, release, prev, noise, or /full/path"; return 1 ;;
esac

# --- Corner selection ---
CORNER_INPUT="${2:-max_high}"
case "$CORNER_INPUT" in
  max_high)  CORNER="func.max_high.T_85.typical" ;;
  max_med)   CORNER="func.max_med.T_85.typical" ;;
  max_low)   CORNER="func.max_low.T_85.typical" ;;
  max_nom)   CORNER="func.max_nom.T_85.typical" ;;
  min_low)   CORNER="func.min_low.T_85.typical" ;;
  min_high)  CORNER="func.min_high.T_85.typical" ;;
  min_fast)  CORNER="fresh.min_fast.F_125.rcworst_CCworst" ;;
  *)         CORNER="$CORNER_INPUT" ;;
esac

SESSION="$WARD/runs/core_client/n2p_htall_conf4/sta_pt/$CORNER/outputs/core_client.pt_session.$CORNER"

# --- Validate session exists ---
if [ ! -d "$SESSION" ] && [ ! -f "$SESSION" ]; then
  echo "ERROR: Session not found: $SESSION"
  echo "Check that model '$MODEL_INPUT' has corner '$CORNER_INPUT'"
  return 1
fi

# Extract tag from ward path for display
TAG=$(basename "$WARD" | grep -oP 'FCT\K[^_-]+' | head -1)

echo "==========================================="
echo "  Open PT Interactive on NB"
echo "  Model:   $MODEL_INPUT ($TAG)"
echo "  Corner:  $CORNER_INPUT -> $CORNER"
echo "  Ward:    $WARD"
echo "  Class:   SLES15&&500G&&16C"
echo "==========================================="

nbjob run --target sc8_express \
  --qslot /c2dg/BE_BigCore/gfc/sd \
  --class "SLES15&&500G&&16C" \
  --mode interactive \
  /nfs/site/proj/hdk/pu_tu/prd/liteinfra/1.19.p1/commonFlow/bin/cth_psetup \
    -proj gfc_n2_client/GFC_TS2025.17.0 \
    -nowash \
    -cfg gfcn2clienta0.cth \
    -ward $WARD \
    -x "\$SETUP_R2G ; /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh $SESSION -title core_client_${MODEL_INPUT}_${CORNER_INPUT}"

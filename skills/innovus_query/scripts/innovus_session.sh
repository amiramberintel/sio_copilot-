#!/bin/bash
#===============================================================================
# innovus_session.sh -- Launch Innovus with GFC design, auto-timeout
#===============================================================================
# Usage:
#   innovus_session.sh [--local|--nbjob] [partition] [timeout_minutes]
#
# Launch modes:
#   --local     Run on current machine (must have Icdns_shell in PATH)
#   --nbjob     Submit via nbjob to SC8 cluster (default if tools not in PATH)
#
# Examples:
#   innovus_session.sh par_meu 60             # Auto-detect: local or nbjob
#   innovus_session.sh --local par_meu 60     # Force local launch
#   innovus_session.sh --nbjob par_meu 60     # Force nbjob submission
#   innovus_session.sh                        # par_meu, 120 min, auto-detect
#
# NBJOB SUBMISSION (from Ameer/PAR team):
#   /usr/intel/bin/nbjob run \
#     --target sc8_express \
#     --qslot /c2dg/BE_BigCore/gfc/dedemr \
#     --class "SLES15SP4&&32C" \
#     Icdns_shell -F apr_innovus -stylus -P -I -N -A -R apr_cdns -B <block>
#
#   Machine class options (adjust to your allocation):
#     Full PAR:   "SLES15SP4&&397G&&32C&&EMERALDRAPIDS"  (397GB, 32 cores)
#     Light query: "SLES15SP4&&32C"                       (any SLES15, 32 cores)
#     Minimal:     "SLES15SP4"                             (any available)
#
# LOCAL PREREQUISITES:
#   Must be run from a CTH/W2E environment (csh shell with cth_psetup loaded).
#   The environment provides Icdns_shell wrapper which resolves the Innovus binary.
#
#   Setup chain (how PAR team does it):
#     1. cth_psetup -proj gfc_n2_client/GFC_TS2025.15.3 -cfg gfcn2clienta0.cth \
#                   -ward /nfs/site/disks/mpridvas_wa/PAR \
#                   -x '$SETUP_R2G -f -w <ward_name> -b <partition>'
#     2. This sets PATH to include Icdns_shell and all Cadence tools
#     3. Icdns_shell internally resolves to 'innovus -stylus'
#
# The script:
#   1. Finds the latest archived Innovus design DB
#   2. Launches Innovus in batch mode (no GUI, saves license)
#   3. Sources physical_queries.tcl for ready-to-use procs
#   4. Auto-exits after timeout to release the license
#===============================================================================

set -e

#--- Parse launch mode flag ---
LAUNCH_MODE="auto"
if [[ "$1" == "--local" ]]; then
    LAUNCH_MODE="local"; shift
elif [[ "$1" == "--nbjob" ]]; then
    LAUNCH_MODE="nbjob"; shift
fi

PARTITION="${1:-par_meu}"
TIMEOUT_MIN="${2:-120}"
ARCHIVE_ROOT="/nfs/site/disks/gfc_n2_client_arc_proj_archive/arc"
WORK_DIR="/tmp/innovus_session_${USER}_${PARTITION}_$$"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

#--- nbjob configuration (adjust class to your allocation) ---
NBJOB_BIN="/usr/intel/bin/nbjob"
NBJOB_TARGET="sc8_express"
NBJOB_QSLOT="/c2dg/BE_BigCore/gfc/dedemr"
# Light class for queries -- no need for 397G/EMR unless running full PAR
NBJOB_CLASS="SLES15SP4&&32C"

echo "============================================================"
echo "  Innovus Session Launcher"
echo "============================================================"
echo "  Partition:   $PARTITION"
echo "  Timeout:     $TIMEOUT_MIN minutes"
echo "  Launch mode: $LAUNCH_MODE"
echo "  Work dir:    $WORK_DIR"
echo "============================================================"

#--- Auto-detect: if tools not in PATH, try nbjob ---
if [[ "$LAUNCH_MODE" == "auto" ]]; then
    if command -v Icdns_shell &>/dev/null || command -v innovus &>/dev/null; then
        LAUNCH_MODE="local"
        echo "  -> Tools found in PATH, using local mode"
    elif [[ -x "$NBJOB_BIN" ]]; then
        LAUNCH_MODE="nbjob"
        echo "  -> Tools not in PATH, submitting via nbjob"
    else
        LAUNCH_MODE="local"  # will fail with helpful error below
    fi
fi

#--- nbjob submission path ---
if [[ "$LAUNCH_MODE" == "nbjob" ]]; then
    if [[ ! -x "$NBJOB_BIN" ]]; then
        echo "ERROR: nbjob not found at $NBJOB_BIN"
        exit 1
    fi
    echo ""
    echo "Submitting Innovus job to $NBJOB_TARGET cluster..."
    echo "  Class:  $NBJOB_CLASS"
    echo "  QSlot:  $NBJOB_QSLOT"
    echo ""
    echo "NOTE: Once the job starts, Icdns_shell will be in PATH on the"
    echo "      remote machine. This script will re-run in --local mode there."
    echo ""
    # Submit: run THIS script again in --local mode on the remote machine
    exec "$NBJOB_BIN" run \
        --target "$NBJOB_TARGET" \
        --qslot "$NBJOB_QSLOT" \
        --class "$NBJOB_CLASS" \
        Icdns_shell -F apr_innovus -stylus -nowin \
        -init "${SCRIPT_DIR}/restore_and_query_wrapper.tcl"
    # Note: for interactive query sessions, you may prefer:
    #   exec "$NBJOB_BIN" run ... bash -c "$SCRIPT_DIR/innovus_session.sh --local $PARTITION $TIMEOUT_MIN"
    exit 0
fi

#--- Local launch: check tools ---
if ! command -v innovus &>/dev/null && ! command -v Icdns_shell &>/dev/null; then
    echo ""
    echo "ERROR: Neither 'innovus' nor 'Icdns_shell' found in PATH."
    echo ""
    echo "You need a CTH/W2E environment or use --nbjob mode. Options:"
    echo ""
    echo "  OPTION 1: Submit via nbjob (no local setup needed)"
    echo "    $0 --nbjob $PARTITION $TIMEOUT_MIN"
    echo ""
    echo "  OPTION 2: Use cth_psetup (full CTH environment, then run --local)"
    echo "    /nfs/site/proj/hdk/pu_tu/prd/liteinfra/1.19.p1/commonFlow/bin/cth_psetup \\"
    echo "      -proj gfc_n2_client/GFC_TS2025.15.3 \\"
    echo "      -cfg gfcn2clienta0.cth \\"
    echo "      -ward /nfs/site/disks/mpridvas_wa/PAR \\"
    echo "      -x '\$SETUP_R2G -f -w <ward_name> -b $PARTITION'"
    echo ""
    echo "  OPTION 3: Ask PAR team for access"
    echo "    Contact mpridvas (PAR engineer) for a pre-configured shell."
    echo ""
    exit 1
fi

# Find latest design DB in archive
DB_DIR="${ARCHIVE_ROOT}/${PARTITION}/sd_layout_cdns/GFCN2CLIENTA0LATEST/sd_layout_cdns_latest/${PARTITION}.db"
if [ ! -d "$DB_DIR" ]; then
    echo "ERROR: Design DB not found at $DB_DIR"
    echo "Checking available tags..."
    ls "${ARCHIVE_ROOT}/${PARTITION}/sd_layout_cdns/" 2>/dev/null
    exit 1
fi

echo "Design DB:     $DB_DIR"
DB_SIZE=$(du -sh "$DB_DIR" 2>/dev/null | cut -f1)
echo "DB size:       $DB_SIZE"
echo ""

# Create temp work directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Create the restore + auto-timeout TCL script
cat > restore_and_query.tcl << TCLEOF
#--- Auto-generated Innovus restore script ---
puts "============================================================"
puts "  Restoring design: $PARTITION"
puts "  DB: $DB_DIR"
puts "  Auto-exit after: $TIMEOUT_MIN minutes"
puts "============================================================"

# Restore the design
restoreDesign $DB_DIR $PARTITION

puts "Design restored successfully."
puts ""

# Source the physical query procs
if {[file exists "${SCRIPT_DIR}/../tcl/physical_queries.tcl"]} {
    source "${SCRIPT_DIR}/../tcl/physical_queries.tcl"
    puts "Physical query procs loaded."
} else {
    puts "WARNING: physical_queries.tcl not found"
}

# Set up auto-timeout
set timeout_seconds [expr {$TIMEOUT_MIN * 60}]
after [expr {\$timeout_seconds * 1000}] {
    puts ""
    puts "============================================================"
    puts "  TIMEOUT: $TIMEOUT_MIN minutes reached. Exiting to release license."
    puts "============================================================"
    exit 0
}

puts ""
puts "============================================================"
puts "  Session ready. Type queries or 'exit' to quit."
puts "  License will auto-release after $TIMEOUT_MIN minutes."
puts "============================================================"
puts ""
TCLEOF

echo "Launching Innovus (no GUI, batch interactive mode)..."
echo "This will take 10-30 minutes to restore the design."
echo ""

# Prefer Icdns_shell (Intel wrapper with correct env) over bare innovus
if command -v Icdns_shell &>/dev/null; then
    Icdns_shell -stylus -nowin -init restore_and_query.tcl
else
    innovus -stylus -nowin -abort_on_error -init restore_and_query.tcl
fi

# Cleanup on exit
echo "Session ended. Cleaning up $WORK_DIR"
cd /
rm -rf "$WORK_DIR"

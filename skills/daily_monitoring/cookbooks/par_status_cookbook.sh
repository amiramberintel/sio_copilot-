#!/bin/bash
# =============================================================================
# par_status_cookbook.sh — Colorizer for par_status.py output
# =============================================================================
# Usage (live):
#   sg gfcn2_pcore_ex -c "python3 par_status.py -p par_ooo_int" | bash par_status_cookbook.sh
# Usage (from saved file):
#   cat par_ooo_int_status.txt | bash par_status_cookbook.sh
# =============================================================================

# --- ANSI Color Codes ---
RED=$'\033[1;31m'
GRN=$'\033[1;32m'
YEL=$'\033[1;33m'
MAG=$'\033[1;35m'
CYN=$'\033[1;36m'
WHT=$'\033[1;37m'
DIM=$'\033[2m'
RST=$'\033[0m'

while IFS= read -r line; do

    # === / ─── separator lines
    if [[ "$line" =~ ^[[:space:]]*={10,} ]]; then
        printf '%s%s%s\n' "$WHT" "$line" "$RST"

    # ─── unicode separator lines
    elif [[ "$line" == *"──────"* ]]; then
        printf '%s%s%s\n' "$DIM" "$line" "$RST"

    # --- dashed separator lines
    elif [[ "$line" =~ ^[[:space:]]*-{10,} ]]; then
        printf '%s%s%s\n' "$DIM" "$line" "$RST"

    # Title: PAR_STATUS
    elif [[ "$line" == *"PAR_STATUS"* ]]; then
        printf '%s%s%s\n' "$WHT" "$line" "$RST"

    # Subtitle: Cross-referencing
    elif [[ "$line" == *"Cross-referencing"* ]]; then
        printf '%s%s%s\n' "$DIM" "$line" "$RST"

    # LEGEND and column header keywords
    elif [[ "$line" == *"LEGEND:"* ]] || [[ "$line" == *"Columns:"* ]] || [[ "$line" == *"HSD types:"* ]]; then
        printf '%s%s%s\n' "$WHT" "$line" "$RST"

    # QUICK ACTION SUMMARY header
    elif [[ "$line" == *"QUICK ACTION SUMMARY"* ]]; then
        printf '%s%s%s\n' "$WHT" "$line" "$RST"

    # Stats line: Total families
    elif [[ "$line" == *"Total families:"* ]]; then
        printf '%s%s%s\n' "$WHT" "$line" "$RST"

    # Section/summary: UNTRACKED
    elif [[ "$line" == *"UNTRACKED"* ]] || [[ "$line" == *"NEED HSD NOW"* ]]; then
        printf '%s%s%s\n' "$RED" "$line" "$RST"

    # Section/summary: FIX LANDED
    elif [[ "$line" == *"FIX LANDED"* ]] || [[ "$line" == *"NEED FOLLOW-UP"* ]]; then
        printf '%s%s%s\n' "$MAG" "$line" "$RST"

    # Section/summary: FIX PENDING
    elif [[ "$line" == *"FIX PENDING"* ]]; then
        printf '%s%s%s\n' "$YEL" "$line" "$RST"

    # Section/summary: CLEAN / FIXED
    elif [[ "$line" == *"CLEAN"* ]] || [[ "$line" == *"FIXED"* ]]; then
        printf '%s%s%s\n' "$GRN" "$line" "$RST"

    # Section/summary: REJECTED
    elif [[ "$line" == *"REJECTED"* ]]; then
        printf '%s%s%s\n' "$DIM" "$line" "$RST"

    # Column headers (#  Signal ...)
    elif [[ "$line" =~ ^[[:space:]]+\#[[:space:]]+Signal ]]; then
        printf '%s%s%s\n' "$WHT" "$line" "$RST"

    # HSD detail: RTL4BE lines
    elif [[ "$line" == *"RTL4BE"* ]]; then
        # Color the status word
        colored="$line"
        if [[ "$line" == *"complete"* ]]; then
            colored="${line/complete/${GRN}complete${RST}${CYN}}"
        elif [[ "$line" == *"repo_modified"* ]]; then
            colored="${line/repo_modified/${GRN}repo_modified${RST}${CYN}}"
        elif [[ "$line" == *"not_done"* ]]; then
            colored="${line/not_done/${YEL}not_done${RST}${CYN}}"
        elif [[ "$line" == *"open"* ]]; then
            colored="${line/open/${YEL}open${RST}${CYN}}"
        fi
        printf '%s%s%s\n' "$CYN" "$colored" "$RST"

    # HSD detail: SIO2PO lines
    elif [[ "$line" == *"SIO2PO"* ]]; then
        colored="$line"
        if [[ "$line" == *"complete"* ]]; then
            colored="${line/complete/${GRN}complete${RST}${MAG}}"
        elif [[ "$line" == *"sign_off"* ]]; then
            colored="${line/sign_off/${GRN}sign_off${RST}${MAG}}"
        elif [[ "$line" == *"not_done"* ]]; then
            colored="${line/not_done/${YEL}not_done${RST}${MAG}}"
        elif [[ "$line" == *"open"* ]]; then
            colored="${line/open/${YEL}open${RST}${MAG}}"
        fi
        printf '%s%s%s\n' "$MAG" "$colored" "$RST"

    # Data rows with TIP indicator
    elif [[ "$line" =~ TIP\([0-9]+\)ok ]]; then
        printf '%s\n' "${line/TIP(/${GRN}TIP(}" | sed "s/)ok/)ok${RST}/g"

    elif [[ "$line" =~ TIP\([0-9]+\) ]]; then
        printf '%s\n' "${line/TIP(/${CYN}TIP(}" | sed "s/)/)${RST}/g"

    # Legend description lines (indented explanations)
    elif [[ "$line" =~ ^[[:space:]]+(Crossing|WNS|Norm|TNS|Paths|TIP|Signal)[[:space:]]+= ]]; then
        printf '%s%s%s\n' "$DIM" "$line" "$RST"

    # Default: pass through
    else
        printf '%s\n' "$line"
    fi
done

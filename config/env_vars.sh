# ==============================================================================
# SIO Copilot Environment Variables and Aliases
# ==============================================================================

# --- Directory shortcuts ---
# setenv MYSTOD `realpath /nfs/site/disks/sunger_wa/`
# setenv GFC_LINKS `realpath /nfs/site/disks/pnc_fct_bu/work_area/fct_scripts/GFC/links/`

# --- Useful aliases ---
# alias ll "ls -ltr"
# alias rp "realpath"

# --- NB aliases for PT session loading ---
# alias load_pt_session_in_nb_express \
#   'nbjob run --target sc8_express \
#    --qslot /c2dg/BE_BigCore/pnc/sd/sles12_sd \
#    --class "SLES12&&4C&&128G" \
#    /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh'
#
# alias load_pt_session_in_nb_express_256G \
#   'nbjob run --target sc8_express \
#    --qslot /c2dg/BE_BigCore/pnc/sd/sles12_sd \
#    --class "SLES12&&4C&&256G" \
#    /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh'
#
# alias load_pt_session_in_nb_express_512G \
#   'nbjob run --target sc8_express \
#    --qslot /c2dg/BE_BigCore/pnc/sd/sles12_sd \
#    --class "SLES12&&4C&&512G" \
#    /p/hdk/pu_tu/prd/fct_alias/latest/utils/load_session_cth.csh'

# --- Copilot proxy (Intel internal) ---
# setenv http_proxy http://proxy-dmz.intel.com:912
# setenv https_proxy http://proxy-dmz.intel.com:912
# setenv no_proxy intel.com,.intel.com,localhost,127.0.0.0/8,10.0.0.0/8

# --- FCT tools ---
# alias FCT_RECIPE 'xterm -title "FCT_recipe" -e "l /nfs/site/home/gilkeren/rep_fct_recipe_gfc.csh"&'
# alias item '/nfs/site/home/baselibr/bin/item'
# alias cmprs 'python /nfs/site/disks/home_user/baselibr/PNC_script/compress_ports.py'

# --- Port compression (baselibr) ---
# source ~baselibr/.aliases

# ==============================================================================
# NOTE: All aliases are commented out. Uncomment what you need.
#       NB aliases use SLES12 -- update to SLES15 if needed.
#       GFC_LINKS path is team-standard, verify it resolves correctly.
# ==============================================================================

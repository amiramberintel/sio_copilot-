set uarch_paths_arr(SRCDATA,exe,mimxvecc_srcs_to_FMA) { -through [get_pins par_exe/miv*c/mimxv*c/mimxv*d/miSrcDataM304H*] -through [get_pins par_fma/fma*_wrap/fma*/fma128*/fmadp*s/fma_bp_rcv/*]}
set uarch_paths_arr(DCLD_FP,exe,DCLDtoSHUF) { -from [get_pins par_fma/par_fma_top/*/clk] -to [get_pins par_exe/shuf/shufp*v*c/*/*/d*]}
set uarch_paths_arr(DCLD_FP,exe,DCLDtoMIU) { -from [get_pins par_fma/par_fma_top/*/clk] -to [get_pins par_exe/miv*c/mimxv*c/mimxv*/*/d*]}
set uarch_paths_arr(DCLD_FP,exe,DCLDtoSIMD) { -from [get_pins par_fma/par_fma_top/*/clk] -to [get_pins par_exe/siu/sishiftalup*v*/si*/*/d*]}
#set uarch_paths_arr(DCLD_FP,exe,DCLDtoSHUF_TF) { -from [get_pins par_meu/siaxeld1vd/*/clk] -through [get_pins par_exe/shuf/*]}
set uarch_paths_arr(DCLD_FP,exe,DCLDtoMIU_TF) { -from [get_pins par_meu/siaxeld1vd/*/clk] -to [get_pins par_exe/miv*c/mimxv*c/mimxv*/*/d*]}
set uarch_paths_arr(FPAdd,exe,fastadderWb) { -from [get_pins par_exe/shuf/shufp*v*c/sifpadd*s/*/clk] -to [get_pins par_exe/shuf/shufp*v*c/sifpadd*s/*/d*]}
set uarch_paths_arr(fp_WB,exe,FMAwb_to_mimxvecc) { -through [get_pins par_fma/fma*_wrap/fma*/fma128*/fmadp*s/fma_p_wb_drv/WbDataM804H*] -through [get_pins par_exe/miv*c/mimxv*c/mimxv*d/*]}
set uarch_paths_arr(fp_WB,exe,FMAWBtoShuf) { -through [get_pins par_fma/fma*_wrap/fma*/fma128*/fmadp*s/fma_p_wb_drv/WbDataM804H*] -to [get_pins par_exe/shuf/shuf*v*/sishuf*d/*data*/d]}
set uarch_paths_arr(fp_WB_flag,exe,FMAflagstoMIU) { -thr par_exe/fpvwb*fl* -thr [get_pins par_exe/mi*c/*]}
set uarch_paths_arr(fp_WB_flag,exe,FMAflagstoShuf) { -from [get_pins par_fma/fma*_wrap/fma*/fma128v*/fmadpv***s/parallel_fma_*_fmapseq34s/*/clk] -to [get_pins par_exe/shuf/shufp*v*c/sishufctls/*/d*]}
set uarch_paths_arr(I2VData,exe,mi2vdata) { -from [get_pins par_exe_int/micrctls/miictls/*miI2VData*/clk] -to [get_pins par_exe/miv0c/mimxv**c/mimxv*d/*I2VData*/d*]}
set uarch_paths_arr(V2IData,exe,miV2IdatatoIntd) { -from [get_pins par_exe/miv*c/mimxv**c/mimxv*d/*V2IData*/clk] -to [get_pins par_exe_int/mimxintd/*miV2IDataM80*/d*]}
set uarch_paths_arr(V2IData,exe,miV2IdatatoMicreg) { -from [get_pins par_exe/miv*c/mimxv**c/mimxv*d/*V2IData*/clk] -to [get_pins par_exe_int/micrctls/micregs/*GITMnnn*/d*]}
set uarch_paths_arr(wbdatavld,exe,mimowb) { -from [get_pins par_meu/mols/molprts/molp*s/MOWBDataVLdEX*/clk] -to [get_pins  par_exe/miv*c/miv*ctls/mi*/d]}
set uarch_paths_arr(misrcmask,exe,misrcmask) { -from [get_pins par_exe/mimxx87c/mimxx87d/*/clk] -to [get_pins par_fma/par_fma_top/*SrcMaskM3*/d*]}
set uarch_paths_arr(misrcmask,exe,misrcmask_to_shuffle) { -from [get_pins par_exe/mimxx87c/mimxx87d/*/clk] -to [get_pins par_exe/shuf/shufp*v*c/sishuf*d/miSrcMaskM30*H_reg_*/d]}
set uarch_paths_arr(WBDATA,exe,Miwbdata-mimxvecc_to_rsvecprfc) { -through [get_pins par_exe/miv*c/mimxv*c/mimxv*d/miWbDataM8*] -through [get_pins par_exe/rsvecprf_arrays/dfx_wrapper_vec/rsvec*prf*c_rsvecprfctop/miwb*]}
set uarch_paths_arr(SRCDATA,exe,Rsdatam303h_rsvecprfc_to_mimxvecc) { -through [get_pins par_exe/miv*c/mimxv*c/mimxv*d/*RSDataM303H*]}
set uarch_paths_arr(301H_vec,exe,psrcFromRsvecbpc,SMT) { -through [get_pins  par_exe/rspsrcm301h_4*]}
#set uarch_paths_arr(301H_vec,exe,RSDISPdata301Htox87RSDATA304H,SMT) { -through [get_pins par_ooo_vec/rs_vec/rsvecbpc/rsvecbpcm/rsvecbpcmtop/*rs*dispdataoutm301h*] -to [get_pins par_exe/mimxx87c/mimxx87d/*RSDataM304H*/d*]}
#set uarch_paths_arr(301H_vec,exe,RSDISPdata301HtoVECRSDATA304H,SMT) { -through [get_pins par_ooo_vec/rs_vec/rsvecbpc/rsvecbpcm/rsvecbpcmtop/*rs*dispdataoutm301h*] -to [get_pins par_exe/miv*c/mimx*c/mimxv*d/*RSDataM304H*/d*]}
set uarch_paths_arr(301H_vec,exe,psrcFromVecldcamc,SMT) { -through [get_pins  par_exe/rspsrcm301h*] -exclude [get_pins par_exe/rspsrcm301h_4*]}
set uarch_paths_arr(301H_vec,exe,psrcprftype,SMT) { -from [get_pins par_ooo_vec/rs_vec/rsvecldcamc/EuBpFSMSrc_*_EuBpFSMBank_*_rs_ldcamc_src_module_vec_eu/*PSrcPrf*/*] -to [get_pins par_exe/rsvecbpd/*/d]}
set uarch_paths_arr(301H_vec,exe,psrcldportsel,SMT) { -from [get_pins par_ooo_vec/rs_vec/rsvecldcamc/EuBpFSMSrc_*_EuBpFSMBank_*_rs_ldcamc_src_module_vec_eu/*PsrcCamP*/*] -to [get_pins par_exe/rsvecbpd/*/d]}
set uarch_paths_arr(301H_vec,exe,psrcfsmstate,SMT) { -from [get_pins par_ooo_vec/rs_vec/rsvecldcamc/EuBpFSMSrc_*_EuBpFSMBank_*_rs_ldcamc_src_module_vec_eu/*PsrcFsmState*/clk] -to [get_pins par_exe/rsvecbpd/*/d]}
set uarch_paths_arr(301H_vec,exe,rsfcwmxcsradd,SMT) { -to [get_pins par_exe/miv0c/miv0ctls/RSFcwMxcsrAddrM302H_reg*/d]}
#set uarch_paths_arr(301H_vec,exe,rsimmctl_to_mimx87cnsld,SMT) { -from [get_pins par_ooo_vec/rs_vec/rsvecbpc/*/clk] -to [get_pins par_exe/mix87cnsld/*RSVImmCtl*/d*]}
set uarch_paths_arr(301H_vec,exe,rsimmctl_to_fma,SMT) { -from [get_pins par_exe/miv*c/miv*ctls/RSImmDataCM30*/clk] -to [get_pins par_fma/fma*_wrap/fma*/fma128v*/fmadpv***s/auto_vector_MBIT_ImmM304H_reg_*_MBIT_ImmM304H_reg_*/d*]}
set uarch_paths_arr(301H_vec,exe,rspdst,SMT) {-to [get_pins par_exe/rsvecbpd/*RSPDstM*/*]}
set uarch_paths_arr(301H_vec,exe,rspdstprftype,SMT) { -through [get_pins par_exe/rspdstprftype*]}
set uarch_paths_arr(REALDsip,exe,rsrealdisp,SMT) { -through [get_pins par_exe/rsreal*]}
set uarch_paths_arr(301H_vec,exe,rsstkctl,SMT) {-thr [get_pins par_exe/rsstackctl*]}
set uarch_paths_arr(301H_vec,exe,rsthreadid,SMT) { -through [get_pins par_exe/rsthread*]}
set uarch_paths_arr(301H_vec,exe,Rsuopcod302h,SMT) { -through [get_pins par_exe/rsuopcod*]}
set uarch_paths_arr(301H_vec,exe,rsuoplatency,SMT) {-through [get_pins par_exe/rsuoplat*]}
set uarch_paths_arr(VECLDPRFWRCANCEL,exe,rsvecldprfwrancel,SMT) { -through [get_pins par_exe/rsvecld*] -to mclk_exe}
set uarch_paths_arr(Shuf_WB,exe,ShufDataWBtoFMA) { -from [get_pins par_exe/shuf/shufp*v*c/sishuf*d/*shufS*dataM30*_reg_Bit*/clk] -to [get_pins par_fma/fma*_wrap/fma*/fma128v*/fmadpv***s/fma_bp_rcv/*/d]}
set uarch_paths_arr(301H_vec,exe,zeroctl,SMT) { -through [get_pins par_exe/*zeroctl*]}
set uarch_paths_arr(Shuf_WB,exe,ShufCtlWBtoFMA) { -from [get_pins par_exe/shuf/shufp*v*c/sishufctls/*/clk] -to [get_pins par_fma/fma*_wrap/fma*/fma128v*/fmadpv***s/fma_bp_rcv/*/d]}
set uarch_paths_arr(Shuf_WB,exe,ShufWBtoSIMDWb) { -through [get_pins par_exe/shuf/shufp*c/sishuf*d/sishuf*wb*data*] -through [get_pins par_exe/siu/sishiftalu*/siwb*]}
set uarch_paths_arr(SIMD_WB,exe,shiftWB_to_shufWB) { -through [get_pins par_exe/siu/sishiftalup*/siwbdata*] -through [get_pins par_exe/shuf/shufp*c/sishuf*d/*siwbP*data*]}

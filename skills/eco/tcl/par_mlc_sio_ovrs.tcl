if {($ivar(fct_prep,par_tags_ovr,par_mlc) == "mlc-gfc-a0-master-25ww52b_25WW51A_fixes2")} {
 
#flop will move from meu to pmh
annotet_port par_mlc/meu_mlc_pm_cr_access_endmnnnh* [expr ${factor}*-30]
 
#bound flops
annotet_port par_mlc/dc2mlpicintrm000h* [expr ${factor}*-20]
annotet_port par_mlc/roeeccorepausemnn3h* [expr ${factor}*-15]
annotet_port par_mlc/dc2mlsnpcreditreturnmnnnh* [expr ${factor}*-20]
annotet_port par_mlc/ml2dcfbvcntzeromnnnh* [expr ${factor}*-20]
annotet_port par_mlc/pm2mlcpmbusymnn1h* [expr ${factor}*-20]

 
 
 
#bad routing- need to to improveto meet spec
annotet_port par_mlc/mlpicpvpinfoallmnn1h_*__pvp_info_pvp1024thold* [expr ${factor}*-20]

#need to fix big delay
annotet_port par_mlc/ifsnpidm126h* [expr ${factor}*-150]
annotet_port par_mlc/dc2mlsnpdatardymnnnh_*__*__snpreqid_id* [expr ${factor}*-100]
annotet_port par_mlc/mlisnpidm502h* [expr ${factor}*-50]
 
 
# RTL4BE https://hsdes.intel.com/appstore/article/#/13014364097
annotet_port par_mlc/xbarpwrupoutcoremnn2h* [expr ${factor}*-35]
 
 
#need to fix big delay - contour mismatch - CI 2C
annotet_port par_mlc/ml2dcsnpreqmnn1h_*__*__snpreqid_id* [expr ${factor}*-50]
annotet_port par_mlc/fecsmimnn1h* [expr ${factor}*-30]
annotet_port par_mlc/mluncmemrspm505h* [expr ${factor}*-50]

# bound flop in C2 CI
annotet_port par_mlc/ml2dcsnpreqvalidmnnnh* [expr ${factor}*-30]

}

# if {($ivar(fct_prep,par_tags_ovr,par_mlc) == "mlc-gfc-a0-master-25ww52a_25WW51A")} {
# 
# #flop will move from meu to pmh
# annotet_port par_mlc/meu_mlc_pm_cr_access_endmnnnh* [expr ${factor}*-30]
# 
# #bound flops
# annotet_port par_mlc/mlearlyalertl2linem505h* [expr ${factor}*-20]
# annotet_port par_mlc/dc2mlpicintrm000h* [expr ${factor}*-20]
# annotet_port par_mlc/roeeccorepausemnn3h* [expr ${factor}*-15]
# annotet_port par_mlc/mlearlyalertl3missm506h* [expr ${factor}*-30]
# annotet_port par_mlc/dc2mlsnpcreditreturnmnnnh* [expr ${factor}*-20]
# annotet_port par_mlc/ml2dcfbvcntzeromnnnh* [expr ${factor}*-20]
# annotet_port par_mlc/mlcr8wrackmnnnh* [expr ${factor}*-30]
# annotet_port par_mlc/pm2mlcpmbusymnn1h* [expr ${factor}*-20]
# 
# 
# #bad routing- need to to improveto meet spec
# annotet_port par_mlc/mlpicpvpinfoallmnn1h_*__pvp_info_pvp1024thold* [expr ${factor}*-30]
# 
# 
# # HSDs by tsabek WW52E 
# annotet_port par_mlc/anyfbldpendingm406h* [expr ${factor}*-15]
# annotet_port par_mlc/mlisnpadrm502* [expr ${factor}*-25]
# 
# #bad clock
# annotet_port par_mlc/telemetry_busmnnnh_telemetry_valid [expr ${factor}*-15]
# }



# if {($ivar(fct_prep,par_tags_ovr,par_mlc) == "mlc_xq40mbist_ww49_25WW46A")} {
# 
# #bound flops - with HSD
# annotet_port par_mlc/meu_mlc_pm_cr_access_endmnnnh* [expr ${factor}*-30]
# annotet_port par_mlc/meu_mlc_pm_cr_access_error_codemnnnh* [expr ${factor}*-30]
# annotet_port par_mlc/iccpgntclkenqualwpwrdovrdmnn1h* [expr ${factor}*-20]
# annotet_port par_mlc/mlcsdcthmnn1h* [expr ${factor}*-40]
# annotet_port par_mlc/cr_ringmlc2_dummy2_pwrupmh* [expr ${factor}*-30]
# annotet_port par_mlc/mltacdtstoprecicmnn2h* [expr ${factor}*-20]
# annotet_port par_mlc/mlearlyalertl2linem505h* [expr ${factor}*-20]
# annotet_port par_mlc/meutelemetryinfomnnnh_*__memory_stalls_l2* [expr ${factor}*-20]
# annotet_port par_mlc/meutelemetryinfomnnnh_*__memory_stalls_l1* [expr ${factor}*-20]
# annotet_port par_mlc/mlpicpvpinfoallmnn1h_*__pvp_info_pvp1024thold* [expr ${factor}*-20]
# 
# 
# # HSDs by tsabek WW52E 
# annotet_port par_mlc/anyfbldpendingm406h* [expr ${factor}*-15]
# annotet_port par_mlc/mlisnpadrm502* [expr ${factor}*-20]
# 
# 
# 
# 
# #bound flop in mlc and fix roundtrip in pmh
# annotet_port par_mlc/mlisnpinvm502h* [expr ${factor}*-30]
# 
# #fix roundtrip in mlc + clk skew
# annotet_port par_mlc/dc2mlpicintrm000h* [expr ${factor}*-40]
# annotet_port par_mlc/ml2dcdraindonemnnnh* [expr ${factor}*-60]
# 
# #RTL4BE - need to move 1 ff from pmh to mlc
# annotet_port par_mlc/femsmimnn2h* [expr ${factor}*-60]
# annotet_port par_mlc/femcerrorm206h* [expr ${factor}*-60]
# annotet_port par_mlc/fecsmimnn2h* [expr ${factor}*-60]
# annotet_port par_mlc/fecmcintrmnn3h* [expr ${factor}*-60]
# 
# #mlc need to fix port location
# annotet_port par_mlc/mltapirreadyt_m737h* [expr ${factor}*-30]
# annotet_port par_mlc/mlnotmulpgfusemnn2h* [expr ${factor}*-20]
# annotet_port par_mlc/mlisnpclkenm501h* [expr ${factor}*-120]
# 
# 
# }


# if {($ivar(fct_prep,par_tags_ovr,par_mlc) == "25ww46a_25WW46A_AVO")} {
# 
# #bound flops - with HSD
# annotet_port par_mlc/roeeccorepausemnn3h* [expr ${factor}*-15]
# annotet_port par_mlc/meu_mlc_pm_cr_access_endmnnnh* [expr ${factor}*-30]
# annotet_port par_mlc/dcreqtypm404h* [expr ${factor}*-15]
# annotet_port par_mlc/meu_mlc_pm_cr_access_error_codemnnnh* [expr ${factor}*-30]
# annotet_port par_mlc/pdpviolationmnn2h* [expr ${factor}*-25]
# annotet_port par_mlc/archthrottletriggermnn1h* [expr ${factor}*-25]
# annotet_port par_mlc/iccpgntclkenqualwpwrdovrdmnn1h* [expr ${factor}*-20]
# annotet_port par_mlc/mlcsdcthmnn1h* [expr ${factor}*-40]
# annotet_port par_mlc/mltadregsdasfuseshiftdatamnnnh* [expr ${factor}*-30]
# annotet_port par_mlc/mltacrbuscntlm734h_*__umbpsel* [expr ${factor}*-20]
# annotet_port par_mlc/cr_ringmlc2_dummy2_pwrupmh* [expr ${factor}*-15]
# 
# 
# #bound flop in mlc and fix roundtrip in pmh
# annotet_port par_mlc/mlisnpinvm502h* [expr ${factor}*-30]
# 
# 
# #fix roundtrip in mlc + clk skew
# annotet_port par_mlc/dc2mlpicintrm000h* [expr ${factor}*-40]
# annotet_port par_mlc/rotfbitm909h* [expr ${factor}*-30]
# annotet_port par_mlc/roifbitm909h* [expr ${factor}*-30]
# 
# #mlc need to meet spec in next CI
# annotet_port par_mlc/msid_msrom_post_busy* [expr ${factor}*-100]
# annotet_port par_mlc/msid_dsbe_post_busy* [expr ${factor}*-100]
# 
# 
# #Amnon will fix the clk of the glbdrv
# annotet_port par_mlc/core_clk_core_common_clk_glbdrvff_mnsclkenmlcicore0m011h_o* [expr ${factor}*-140]
# annotet_port par_mlc/core_clk_core_common_clk_glbdrvff_mclkenmlcicore0m011h_o* [expr ${factor}*-140]
# 
# 
# #SIO2PO for pmh - bound ff to IFC
# annotet_port par_mlc/ifsnphitm126h* [expr ${factor}*-50]
# annotet_port par_mlc/ifsnpvalm126h* [expr ${factor}*-50]
# annotet_port par_mlc/ifsnpidm126h* [expr ${factor}*-50]
# 
# #RTL4BE - need to move 1 ff from pmh to mlc
# annotet_port par_mlc/femsmimnn2h* [expr ${factor}*-60]
# annotet_port par_mlc/femcerrorm206h* [expr ${factor}*-60]
# annotet_port par_mlc/fecsmimnn2h* [expr ${factor}*-60]
# annotet_port par_mlc/fecmcintrmnn3h* [expr ${factor}*-60]
# 
# #roundtrip in meu
# annotet_port par_mlc/dc2mlsnpdatardymnnnh_*_valid [expr ${factor}*-300]
# annotet_port par_mlc/dc2mlsnpdatardymnnnh_*__snpreqid_snpagent* [expr ${factor}*-300]
# annotet_port par_mlc/dc2mlsnpdatardymnnnh_*__snpreqid_id* [expr ${factor}*-300]
# annotet_port par_mlc/dc2mlsnpdatardymnnnh_*_snpreqid_mlcslicemsb* [expr ${factor}*-300]
# 
# 
# }







# if {($ivar(fct_prep,par_tags_ovr,par_mlc) == "25ww45b_25WW43E_HIGH")} {
# 
# 
# annotet_port par_mlc/msid_msrom_post_busy* [expr ${factor}*-100]
# annotet_port par_mlc/meu_mlc_pm_cr_access_endmnnnh* [expr ${factor}*-30]
# annotet_port par_mlc/dcreqattrm404h* [expr ${factor}*-30]
# annotet_port par_mlc/msid_dsbe_post_busy* [expr ${factor}*-100]
# annotet_port par_mlc/telemetry_bus_ooomnnnh_*__telemetry_data* [expr ${factor}*-30]
# 
# 
# 
# }





#if {($ivar(fct_prep,par_tags_ovr,par_mlc) == "25ww41B_25WW41B_fixes3")} {

# 
# annotet_port par_mlc/ml2dcdraindonemnnnh* [expr ${factor}*-30]
# }



# if {($ivar(fct_prep,par_tags_ovr,par_mlc) == "25ww41B_25WW41B")} {
# 
# #split between the partitions
# annotet_port par_mlc/mluncllcmissm503h* [expr ${factor}*-80]
# 
# #RTL4BE
# annotet_port par_mlc/ml2dcsnpreqvalidmnnnh* [expr ${factor}*-50]
# 
# 
# #bound ff:
# annotet_port par_mlc/meu_mlc_pm_cr_access_error_codemnnnh* [expr ${factor}*-30]
# annotet_port par_mlc/roifbitm909h* [expr ${factor}*-20]
# annotet_port par_mlc/archthrottletriggermnn1h* [expr ${factor}*-50]
# annotet_port par_mlc/dc2mlsnpdatardymnnnh_*__*__valid* [expr ${factor}*-20]
# annotet_port par_mlc/roeeccorepausemnn3h* [expr ${factor}*-30]
# annotet_port par_mlc/dc2mlfencedrainmnnnh* [expr ${factor}*-35]
# annotet_port par_mlc/cr_mlc_c1_in_pwrupmh* [expr ${factor}*-15]
# annotet_port par_mlc/mldcevrdbyteenm498h* [expr ${factor}*-30]
# annotet_port par_mlc/cr_mlc_c0_out_crdatamh_* [expr ${factor}*-30]
# annotet_port par_mlc/cr_mlc_c1_in_crdatamh** [expr ${factor}*-30]
# annotet_port par_mlc/ml2mecresetmx003h* [expr ${factor}*-30]
# annotet_port par_mlc/mlglobobsfbidm505h* [expr ${factor}*-50]
# annotet_port par_mlc/perfmonpmimnn2h* [expr ${factor}*-15]
# annotet_port par_mlc/mldcevrdchunkm498h* [expr ${factor}*-30]
# annotet_port par_mlc/mlearlyalertfbidm505h* [expr ${factor}*-25]
# annotet_port par_mlc/mlearlyalertl3missm506h* [expr ${factor}*-30]
# annotet_port par_mlc/mlglobobsstatem505h* [expr ${factor}*-30]
# annotet_port par_mlc/altmulpgturnonmnn2h* [expr ${factor}*-20]
# annotet_port par_mlc/mltmulpgfsmackmnn2h* [expr ${factor}*-30]
# annotet_port par_mlc/idmacromatchcm109h* [expr ${factor}*-30]
# }
# 
# 
# if {($ivar(fct_prep,par_tags_ovr,par_mlc) == "25ww37C_25WW38A")} {
# 
# #RTL4BE HSD: https://hsdes.intel.com/appstore/article-one/#/article/13013675922
# # annotet_port par_mlc/switch2susrailnnnnh* [expr ${factor}*-500]
# # annotet_port par_mlc/dup_switch2susrailnnnnh* [expr ${factor}*-400]
# 
# #RTL4BE HSD: https://hsdes.intel.com/appstore/article-one/#/article/13013697903
# # annotet_port par_mlc/ml2dcsnpreqvalidmnnnh* [expr ${factor}*-50]
# # annotet_port par_mlc/mluncllcmissm503h* [expr ${factor}*-80]
# 
# 
# #bad RC delay:
# # annotet_port par_mlc/dc2mlsnpcreditreturnmnnnh* [expr ${factor}*-260]
# 
# #bound ff:
# annotet_port par_mlc/meu_mlc_pm_cr_access_rdatamnnnh* [expr ${factor}*-35]
# annotet_port par_mlc/meu_mlc_pm_cr_access_error_codemnnnh* [expr ${factor}*-30]
# annotet_port par_mlc/roifbitm909h* [expr ${factor}*-20]
# annotet_port par_mlc/archthrottletriggermnn1h* [expr ${factor}*-50]
# annotet_port par_mlc/dc2mlsnpdatardymnnnh_*__*__valid* [expr ${factor}*-20]
# annotet_port par_mlc/dc2mlsnprspmnnnh_*__*__causedtsxabort* [expr ${factor}*-20]
# annotet_port par_mlc/dc2mlpicintrm000h* [expr ${factor}*-40]
# annotet_port par_mlc/mltatapresumeclkunnnh* [expr ${factor}*-40]
# annotet_port par_mlc/ronukeallm909h* [expr ${factor}*-30]
# annotet_port par_mlc/dcreqbyteenparm402h* [expr ${factor}*-30]
# annotet_port par_mlc/dc2mlsnprspmnnnh_*__*__hitm* [expr ${factor}*-100]
# annotet_port par_mlc/dc2mlsnprspmnnnh_*__*__nack* [expr ${factor}*-100]
# annotet_port par_mlc/dc2mlsnprspmnnnh_*__*__rsps* [expr ${factor}*-100]
# annotet_port par_mlc/cr_ringmlc2_dummy2_pwrupmh* [expr ${factor}*-50]
# annotet_port par_mlc/roeeccorepausemnn3h* [expr ${factor}*-30]
# annotet_port par_mlc/dc2mlfencedrainmnnnh* [expr ${factor}*-35]
# annotet_port par_mlc/cr_mlc_c1_in_pwrupmh* [expr ${factor}*-15]
# annotet_port par_mlc/mldcevrdbyteenm498h* [expr ${factor}*-30]
# annotet_port par_mlc/cr_mlc_c0_out_crdatamh_* [expr ${factor}*-30]
# annotet_port par_mlc/cr_mlc_c1_in_crdatamh** [expr ${factor}*-30]
# annotet_port par_mlc/ml2mecresetmx003h* [expr ${factor}*-30]
# annotet_port par_mlc/mlglobobsfbidm505h* [expr ${factor}*-50]
# annotet_port par_mlc/perfmonpmimnn2h* [expr ${factor}*-15]
# annotet_port par_mlc/mldcevrdchunkm498h* [expr ${factor}*-30]
# annotet_port par_mlc/mlearlyalertfbidm505h* [expr ${factor}*-25]
# annotet_port par_mlc/mlearlyalertl3missm506h* [expr ${factor}*-30]
# annotet_port par_mlc/mlglobobsstatem505h* [expr ${factor}*-30]
# annotet_port par_mlc/altmulpgturnonmnn2h* [expr ${factor}*-20]
# annotet_port par_mlc/mltmulpgfsmackmnn2h* [expr ${factor}*-30]
# annotet_port par_mlc/idmacromatchcm109h* [expr ${factor}*-30]
# }
# 
# #################################################################################################################################
# #
# if {($ivar(fct_prep,par_tags_ovr,par_mlc) == "GFCN2SERVERA0_SC8_VER_009")} {
# 
# #RTL4BE HSD: https://hsdes.intel.com/appstore/article-one/#/article/13013675922
# annotet_port par_mlc/switch2susrailnnnnh* [expr ${factor}*-500]
# annotet_port par_mlc/dup_switch2susrailnnnnh* [expr ${factor}*-300]
# 
# #RTL4BE HSD: https://hsdes.intel.com/appstore/article-one/#/article/13013697903
# annotet_port par_mlc/ml2dcsnpreqvalidmnnnh* [expr ${factor}*-50]
# annotet_port par_mlc/mluncllcmissm503h* [expr ${factor}*-80]
# 
# 
# #bad RC delay:
# annotet_port par_mlc/mll2missm505h* [expr ${factor}*-300]
# annotet_port par_mlc/mldcevrdsnpm498h* [expr ${factor}*-260]
# annotet_port par_mlc/dc2mlsnpcreditreturnmnnnh* [expr ${factor}*-260]
# 
# #bound ff:
# annotet_port par_mlc/idft_mclkenm311h_postmux* [expr ${factor}*-30]
# annotet_port par_mlc/mlc02activemnnnh* [expr ${factor}*-40]
# annotet_port par_mlc/mltasigntrrstm8n1h* [expr ${factor}*-50]
# annotet_port par_mlc/rotfbitm909h* [expr ${factor}*-40]
# annotet_port par_mlc/roifbitm909h* [expr ${factor}*-40]
# annotet_port par_mlc/mldcevrdenm498h* [expr ${factor}*-25]
# annotet_port par_mlc/meu_mlc_pm_cr_access_rdatamnnnh* [expr ${factor}*-35]
# annotet_port par_mlc/archthrottletriggermnn1h* [expr ${factor}*-50]
# annotet_port par_mlc/dc2mlsnpdatardymnnnh_*__*__valid* [expr ${factor}*-100]
# annotet_port par_mlc/dc2mlsnprspmnnnh_*__*__causedtsxabort* [expr ${factor}*-100]
# annotet_port par_mlc/roinc0emnn2h* [expr ${factor}*-20]
# annotet_port par_mlc/dc2mlpicintrm000h* [expr ${factor}*-40]
# annotet_port par_mlc/mltatapresumeclkunnnh* [expr ${factor}*-40]
# annotet_port par_mlc/ronukeallm909h* [expr ${factor}*-30]
# annotet_port par_mlc/dcreqbyteenparm402h* [expr ${factor}*-30]
# annotet_port par_mlc/dc2mlsnprspmnnnh_*__*__hitm* [expr ${factor}*-100]
# annotet_port par_mlc/dc2mlsnprspmnnnh_*__*__nack* [expr ${factor}*-100]
# annotet_port par_mlc/dc2mlsnprspmnnnh_*__*__rsps* [expr ${factor}*-100]
# 
# 
# 
# #wrong port location in pm
# annotet_port par_mlc/ubptrigllborcrdcount* [expr ${factor}*-250]
# }
# 
# 
# 
# if {($ivar(fct_prep,par_tags_ovr,par_mlc) == "25ww31b_25WW29A")} {
# 
# #bad RC delay in mlc
# annotet_port par_mlc/mlidatatrigllcreqm510h* [expr ${factor}*-400]
# annotet_port par_mlc/mll2missm505h* [expr ${factor}*-300]
# annotet_port par_mlc/mldcevrdsnpm498h* [expr ${factor}*-260]
# annotet_port par_mlc/dc2mlsnpcreditreturnmnnnh* [expr ${factor}*-260]
# 
# 
# #bound ff to interface
# annotet_port par_mlc/xbarpwrupoutcoremnn2h* [expr ${factor}*-65]
# annotet_port par_mlc/mlrddatapoisonm511h* [expr ${factor}*-30]
# annotet_port par_mlc/dtdatabrkptm405h* [expr ${factor}*-30]
# annotet_port par_mlc/dcreqbyteenm402h* [expr ${factor}*-30]
# annotet_port par_mlc/hvm_x_cleanmnn2h* [expr ${factor}*-40]
# annotet_port par_mlc/crysclkpulsemnnnh* [expr ${factor}*-60]
# annotet_port par_mlc/mluncorepmim5nnh* [expr ${factor}*-50]
# annotet_port par_mlc/idft_mclkenm311h_postmux* [expr ${factor}*-30]
# annotet_port par_mlc/mlc02activemnnnh* [expr ${factor}*-40]
# annotet_port par_mlc/mltasigntrrstm8n1h* [expr ${factor}*-50]
# annotet_port par_mlc/rotfbitm909h* [expr ${factor}*-40]
# annotet_port par_mlc/roifbitm909h* [expr ${factor}*-40]
# annotet_port par_mlc/mldcevrdenm498h* [expr ${factor}*-25]
# annotet_port par_mlc/meu_mlc_pm_cr_access_rdatamnnnh* [expr ${factor}*-35]
# annotet_port par_mlc/archthrottletriggermnn1h* [expr ${factor}*-50]
# annotet_port par_mlc/dc2mlsnpdatardymnnnh_*__*__valid* [expr ${factor}*-100]
# annotet_port par_mlc/dc2mlsnprspmnnnh_*__*__causedtsxabort* [expr ${factor}*-100]
# 
# #add one more cycle time (new ff in mlc interface)
# #https://hsdes.intel.com/appstore/article-one/#/article/13013608222
# set_multicycle_path 2 -setup -through [get_pins  -hierarchical -quiet -filter full_name=~*par_mlc/dc2mlpicintrm000h*]
# 
# #wrong port location in pm
# annotet_port par_mlc/ubptrigllborcrdcount* [expr ${factor}*-250]
# 
# #unconstraints
# set_multicycle_path 6 -setup -through [get_pins  -hierarchical -quiet -filter full_name=~*par_mlc/dup_switch2susrailnnnnh*]
# set_multicycle_path 6 -setup -through [get_pins  -hierarchical -quiet -filter full_name=~*par_mlc/switch2susrailnnnnh*]
# }
# 
# 
# 
# 
# 
# 
# 
# if {($ivar(fct_prep,par_tags_ovr,par_mlc) == "ww28_25WW29A_invs_route_opt_Amir")} {
# 
# #bad RC delay dou to mlc CI
# annotet_port par_mlc/mlidatatrigllcreqm510h[0] [expr ${factor}*-100]
# annotet_port par_mlc/mlidatatrigllcreqm510h[1] [expr ${factor}*-180]
# 
# #bound ff to interface
# annotet_port par_mlc/xbarpwrupoutcoremnn2h* [expr ${factor}*-70]
# annotet_port par_mlc/mlrddatapoisonm511h* [expr ${factor}*-40]
# annotet_port par_mlc/dtdatabrkptm405h* [expr ${factor}*-60]
# annotet_port par_mlc/dcreqbyteenm402h* [expr ${factor}*-40]
# annotet_port par_mlc/altmulendthrottlemnn2h* [expr ${factor}*-50]
# annotet_port par_mlc/dcreqbyteenparm402h* [expr ${factor}*-60]
# annotet_port par_mlc/cdtenfusemnn1h* [expr ${factor}*-60]
# annotet_port par_mlc/mlrddatam511h* [expr ${factor}*-60]
# annotet_port par_mlc/dcsnpcausedtsxabortm404h* [expr ${factor}*-30]
# annotet_port par_mlc/mldcevrdidm498h* [expr ${factor}*-30]
# annotet_port par_mlc/mlc2meupmonbus_mnn4h_*__ctr*_*__inc* [expr ${factor}*-30]
# annotet_port par_mlc/hvm_x_cleanmnn2h* [expr ${factor}*-40]
# annotet_port par_mlc/dcsnpcausedtsxabortm404h* [expr ${factor}*-40]
# 
# #add one more cycle time (new ff in mlc interface)
# #https://hsdes.intel.com/appstore/article-one/#/article/13013608222
# set_multicycle_path 2 -setup -through [get_pins  -hierarchical -quiet -filter full_name=~*par_mlc/dc2mlpicintrm000h*]
# }
# 
# 
# if {($ivar(fct_prep,par_tags_ovr,par_mlc) == "gfc_client_golden")} {
# #port in wrong location in mlc CI
# annotet_port par_mlc/perfubrktrigprfcnt*m738h  [expr ${factor}*-700]
# annotet_port par_mlc/femsmimnn2h*  [expr ${factor}*-800]
# annotet_port par_mlc/femcerrorm206h*  [expr ${factor}*-700]
# annotet_port par_mlc/fecsmimnn2h*  [expr ${factor}*-700]
# annotet_port par_mlc/fecmcintrmnn3h*  [expr ${factor}*-700]
# annotet_port par_mlc/ropanicm993h*  [expr ${factor}*-480]
# annotet_port par_mlc/telemetry_startmnn1h*  [expr ${factor}*-500]
# annotet_port par_mlc/ifubrktrigbufferipm736h*  [expr ${factor}*-450]
# annotet_port par_mlc/mlglobobsm505h*  [expr ${factor}*-370]
# annotet_port par_mlc/mlglobobsstatem505h*  [expr ${factor}*-400]
# annotet_port par_mlc/mlglobobsfbidm505h*  [expr ${factor}*-200]
# annotet_port par_mlc/msid_msrom_post_busy*  [expr ${factor}*-400]
# annotet_port par_mlc/hgs_enable_telemetrymnn1h*  [expr ${factor}*-460]
# annotet_port par_mlc/perflitstframst1mnn3h*  [expr ${factor}*-400]
# annotet_port par_mlc/oob_enable_telemetrymnn1h*  [expr ${factor}*-330]
# annotet_port par_mlc/mlrddataifuselm511h*  [expr ${factor}*-220]
# 
# #bad RC delay dou to mlc CI
# annotet_port par_mlc/dcreqa*  [expr ${factor}*-500]
# annotet_port par_mlc/dcreqlenm404h*  [expr ${factor}*-500]
# annotet_port par_mlc/dcreqtypm404h*  [expr ${factor}*-350]
# annotet_port par_mlc/dcreqidm404h*  [expr ${factor}*-400]
# annotet_port par_mlc/dcreqvm404h*  [expr ${factor}*-270]
# annotet_port par_mlc/dcreqbyteenm402h*  [expr ${factor}*-280]
# annotet_port par_mlc/dcreqbyteenparm402h*  [expr ${factor}*-80]
# 
# annotet_port par_mlc/dcsnphitm404h*  [expr ${factor}*-500]
# annotet_port par_mlc/dcsnphittxrm404h*  [expr ${factor}*-450]
# annotet_port par_mlc/dcsnphitmm404h*  [expr ${factor}*-420]
# annotet_port par_mlc/dcsnphitsm404h*  [expr ${factor}*-170]
# 
# annotet_port par_mlc/dcsnpstallm404h*  [expr ${factor}*-250]
# annotet_port par_mlc/dcsnpdataidm404h*  [expr ${factor}*-420]
# annotet_port par_mlc/dcsnpdatardym405h*  [expr ${factor}*-350]
# annotet_port par_mlc/dcsnpcausedtsxabortm404h*  [expr ${factor}*-350]
# annotet_port par_mlc/dcsnpnackm404h*  [expr ${factor}*-250]
# 
# annotet_port par_mlc/dc2mlmccsmim000h*  [expr ${factor}*-380]
# annotet_port par_mlc/dc2mlmcmsmim000h*  [expr ${factor}*-350]
# annotet_port par_mlc/dc2mlpicintrm000h*  [expr ${factor}*-220]
# annotet_port par_mlc/dc2mlspeci2menmnnnh*  [expr ${factor}*-340]
# annotet_port par_mlc/dc2mlbuslockdrainmnnnh*  [expr ${factor}*-200]
# annotet_port par_mlc/dc2mlwrdatam402h* [expr ${factor}*-240]
# annotet_port par_mlc/dc2mlfencedrainmnnn*  [expr ${factor}*-220]
# annotet_port par_mlc/dc2mlmcharderrm000h*  [expr ${factor}*-230]
# annotet_port par_mlc/dc2mlwrdatapoisonm402h*  [expr ${factor}*-170]
# 
# annotet_port par_mlc/cr_ringmlc2_dummy2_crdatamh*  [expr ${factor}*-400]
# annotet_port par_mlc/cr_mlc_c1_in_crdatamh*  [expr ${factor}*-350]
# annotet_port par_mlc/cr_mlc_c1_in_pwrupm*  [expr ${factor}*-240]
# annotet_port par_mlc/cr_ringmlc2_dummy2_pwrupmh*  [expr ${factor}*-180]
# 
# annotet_port par_mlc/ifsnphitsbm129h*  [expr ${factor}*-300]
# annotet_port par_mlc/ifsnp*124h*  [expr ${factor}*-200]
# annotet_port par_mlc/switch2susrailnnnnh*  [expr ${factor}*-460]
# annotet_port par_mlc/dcspecreqvm403h*  [expr ${factor}*-300]
# annotet_port par_mlc/perflitdatast1mnn3h*  [expr ${factor}*-410]
# annotet_port par_mlc/meu_mlc_pm_cr_access_error_codemnnnh*  [expr ${factor}*-300]
# annotet_port par_mlc/meu_mlc_pm_cr_access_rdatamnnnh*  [expr ${factor}*-520]
# annotet_port par_mlc/mi2mlnoexecuteonallportsm308h*  [expr ${factor}*-350]
# annotet_port par_mlc/roeeccorepausemnn3h*  [expr ${factor}*-250]
# annotet_port par_mlc/roifbitm909h*  [expr ${factor}*-260]
# annotet_port par_mlc/altmulendthrottlemnn2h*  [expr ${factor}*-260]
# annotet_port par_mlc/altmulpgturnonmnn2h*  [expr ${factor}*-150]
# annotet_port par_mlc/pm2ml*  [expr ${factor}*-330]
# annotet_port par_mlc/perfmonpmimnn2h*  [expr ${factor}*-260]
# annotet_port par_mlc/rotfbitm909h*  [expr ${factor}*-250]
# annotet_port par_mlc/ronukeallm909h*  [expr ${factor}*-250]
# annotet_port par_mlc/meu_mlc_pm_cr_access_endmnnnh*  [expr ${factor}*-270]
# 
# annotet_port par_mlc/meutelemetryinfomnnnh_*__memory_stalls_l3*  [expr ${factor}*-270]
# annotet_port par_mlc/meutelemetryinfomnnnh_*__memory_stalls_mem*  [expr ${factor}*-270]
# annotet_port par_mlc/meutelemetryinfomnnnh_*__memory_stalls_l1*  [expr ${factor}*-200]
# annotet_port par_mlc/meutelemetryinfomnnnh_*__memory_stalls_l2*  [expr ${factor}*-150]
# 
# annotet_port par_mlc/dtdatabrkptm405h*  [expr ${factor}*-210]
# annotet_port par_mlc/dtmcaerrcsmim404h*  [expr ${factor}*-210]
# annotet_port par_mlc/dcstopallsnpm396h*  [expr ${factor}*-220]
# annotet_port par_mlc/anyfbldpendingm406h*  [expr ${factor}*-220]
# annotet_port par_mlc/fe_bpu_post_busy*  [expr ${factor}*-400]
# annotet_port par_mlc/molivelockdetl2m4nnh*  [expr ${factor}*-220]
# annotet_port par_mlc/fe_ifu_post_busy_out[0] [expr ${factor}*-250]
# annotet_port par_mlc/exe_ieu_post_busy_out[0] [expr ${factor}*-280]
# annotet_port par_mlc/telemetry_bus_ooomnnnh_*__telemetry_data* [expr ${factor}*-200]
# annotet_port par_mlc/telemetry_bus_ooomnnnh_*__telemetry_valid* [expr ${factor}*-100]
# annotet_port par_mlc/roactivem910h* [expr ${factor}*-190]
# annotet_port par_mlc/dtmcaerrorm404h* [expr ${factor}*-120]
# annotet_port par_mlc/dtmcaerrcmcim404h[1] [expr ${factor}*-170]
# annotet_port par_mlc/dtmcaerrcmcim404h[0] [expr ${factor}*-80]
# annotet_port par_mlc/dtmcaerrmsmim404h* [expr ${factor}*-90]
# annotet_port par_mlc/aliccplevelreqmnn0h* [expr ${factor}*-175]
# annotet_port par_mlc/mlidatapoisonm512h* [expr ${factor}*-90]
# annotet_port par_mlc/rocr8datamnn2h* [expr ${factor}*-175]
# annotet_port par_mlc/msid_dsbe_post_busy* [expr ${factor}*-200]
# annotet_port par_mlc/rowrcr8mnn2h* [expr ${factor}*-160]
# annotet_port par_mlc/morartptrvm905h* [expr ${factor}*-60]
# }

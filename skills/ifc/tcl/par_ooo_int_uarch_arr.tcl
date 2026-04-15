#############################################################
# OOO Uarch paths - compiled by NSA and KKR
#############################################################

########################
## RSEU
########################

set uarch_paths_arr(301H,ooo_int,301H_int_rsbpceu,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/rs_int/rsbpc/rsbpcmemstdm/rsbpcmemstdmtop/* -to par_exe_int/rs*301h* -to \[get_clocks mclk_*]"
set uarch_paths_arr(301H,ooo_int,301H_int_rsbpcmemstd,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/rs_int/rsbpc/rsbpcmemstdm/rsbpcmemstdmtop/* -to par_exe_int/*rs*301h* -to \[get_clocks mclk_*]"
set uarch_paths_arr(301H,ooo_int,301H_int_rsldcamc,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/rs_int/rsldcamc/* -to par_exe_int/*rs*301h* -to \[get_clocks mclk_*]"
set uarch_paths_arr(301H,ooo_int,301H_int_rseuldcamc,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/rs_int/rseuldcamc/* -to par_exe_int/*rs*301h* -to \[get_clocks mclk_*]"
set uarch_paths_arr(301H,ooo_int,301H_int_rseupc,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/rs_int/rseupc/* -to par_exe_int/*rs*301h* -to \[get_clocks mclk_*]"

########################
## JE_804
########################

set uarch_paths_arr(JE_804,ooo_int,804HL_JE_rseupc) "-from \[get_clocks mclk_*] -through par_ooo_int/rs_int/rseupc/* -to par_exe_int/*rs*301h* -to \[get_clocks mclk_*]"

#EDIT THIS
#set uarch_paths_arr(JE_jeo2idataearlym804h_par_exe_int_par_ooo_int) "-from \[get_clocks mclk_*] -through par_exe_int/*jeo2idataearlym804h* -through par_ooo_int/*jeo2idataearlym804h* -to \[get_clocks mclk_*]" 
#set uarch_paths_arr(JE_jeloaduarreqcearlym804l_par_exe_int_par_ooo_int) "-from \[get_clocks mclk_*] -through par_exe_int/*jeloaduarreqcearlym804l* -through par_ooo_int/*jeloaduarreqcearlym804l* -to \[get_clocks mclk_*]" 
#set uarch_paths_arr(JE_jeo2idatam805h_par_ooo_int_par_msid) "-from \[get_clocks mclk_*] -through par_ooo_int/*jeo2idatam805h* -through par_msid/*jeo2idatam805h* -to \[get_clocks mclk_*]" 

########################
## JECLEAR
########################

set uarch_paths_arr(JEClear,ooo_int,jeclearlatetoooom805h,ST) "-from \[get_clocks mclk_*] -through par_exe_int/*jeclearlatetoooom805h* -to par_ooo_int/*jeclearm805h* -to \[get_clocks mclk_*]" 
set uarch_paths_arr(JEClear,ooo_int,jeclearm805h,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/*jeclear*m805* -to par_ooo_vec/*jeclear*m805* -to \[get_clocks mclk_*]" 

########################
## ID*200H*
########################

set uarch_paths_arr(200H,ooo_int,200H_ID,ST) "-from \[get_clocks mclk_*] -through par_msid/*id*200h* -to par_ooo_int/*id*200h* -to \[get_clocks mclk_*]"

########################
## 202H
########################

set uarch_paths_arr(202H,ooo_int,202h_lent,SMT) "-from \[get_clocks mclk_*] -through par_ooo_int/*ra*201*lent*202h* -to par_ooo_vec/*ra*lent*m202h* -to \[get_clocks mclk_*]" 
set uarch_paths_arr(202H,ooo_int,raftosm202h,SMT) "-from \[get_clocks mclk_*] -through par_ooo_int/*raftosm202h* -to par_ooo_vec/*raftosm202h* -to \[get_clocks mclk_*]" 
set uarch_paths_arr(202H,ooo_int,rafptagwordm202h,SMT) "-from \[get_clocks mclk_*] -through par_ooo_int/*rafptagwordm202h* -to par_ooo_vec/*rafptagwordm202h* -to \[get_clocks mclk_*]" 
set uarch_paths_arr(202H,ooo_int,raretireslot0m202h,SMT) "-from \[get_clocks mclk_*] -through par_ooo_int/*raretireslot0m202h* -to par_ooo_vec/*raretireslot0m202h* -to \[get_clocks mclk_*]" 
set uarch_paths_arr(202H,ooo_int,rauopvm202h,SMT) "-from \[get_clocks mclk_*] -through par_ooo_int/*rauopvm202h* -to par_ooo_vec/*rauopvm202h* -to \[get_clocks mclk_*]" 
set uarch_paths_arr(202H,ooo_int,rareadary_m202h,SMT) "-from \[get_clocks mclk_*] -through par_ooo_int/*rareadary_m202h* -to par_ooo_vec/*rareadary_m202h* -to \[get_clocks mclk_*]" 
set uarch_paths_arr(202H,ooo_int,raseltrobm201h,SMT) "-from \[get_clocks mclk_*] -through par_ooo_int/*raseltrobm201h* -to par_ooo_vec/*raseltrobm201h* -to \[get_clocks mclk_*]" 
set uarch_paths_arr(202H,ooo_int,raiduopvm202h,SMT) "-from \[get_clocks mclk_*] -through par_ooo_int/*raiduopvm202h* -to par_ooo_vec/*raiduopvm202h* -to \[get_clocks mclk_*]" 
set uarch_paths_arr(202H,ooo_int,alrobidm202h,SMT) "-from \[get_clocks mclk_*] -through par_ooo_int/*alrobidm202h* -to par_ooo_vec/*alrobidm202h* -to \[get_clocks mclk_*]" 
set uarch_paths_arr(202H,ooo_int,raenhstall2fet_m202l,SMT) "-from \[get_clocks mclk_*] -through par_ooo_int/*raenhstall2fet_m202l* -to par_msid/*raenhstallt_m202l* -to \[get_clocks mclk_*]" 
set uarch_paths_arr(202H,ooo_int,alisstore_m202h,SMT) "-from \[get_clocks mclk_*] -through par_ooo_int/*alisstore_m202h* -to par_ooo_vec/*alisstore_m202h* -to \[get_clocks mclk_*]" 
set uarch_paths_arr(202H,ooo_int,rauopisfusedm203h,SMT) "-from \[get_clocks mclk_*] -through par_ooo_int/*rauopisfusedm202h* -to par_ooo_vec/*rauopisfusedm202h* -to \[get_clocks mclk_*]" 

########################
## RAVECQ
########################

set uarch_paths_arr(RAVECQ,ooo_int,RAVECQ_TID_M251H,SMT) "-from \[get_clocks mclk_*] -through par_ooo_int/*ravecq_tid_m251h* -to par_ooo_vec/*ravecq_tid_m251h* -to \[get_clocks mclk_*]"
set uarch_paths_arr(RAVECQ,ooo_int,RAVECQ_M252H,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/*ravecq*252h* -to par_ooo_vec/* -to \[get_clocks mclk_*]"

########################
## MOWBPDST
########################

set uarch_paths_arr(MOWBPDST,ooo_int,MOWBPDST,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/*mowbpdst* -to par_ooo_vec/*RSWBPdst* -to \[get_clocks mclk_*]"
set uarch_paths_arr(MOWBPDST,ooo_int,MOWBPDST_PRFTYPE,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/*mo*pdst*prftype* -to par_ooo_vec/*RSPDstPRFType* -to \[get_clocks mclk_*]"
#report mopdst/mowbpdst internal to ooo_int
set uarch_paths_arr(MOWBPDST,ooo_int,MOWBPDST_internal,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/*mowbpdst* -to par_ooo_int/*RSWBPdstLd*800L* -to \[get_clocks mclk_*]"
set uarch_paths_arr(MOWBPDST,ooo_int,MOWBPDST_internal,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/*mowbpdst* -to par_ooo_int/*WBPdstLd*800L* -to \[get_clocks mclk_*]"

########################
## MOWBVLD
########################

set uarch_paths_arr(MOWBVLD,ooo_int,MOWBVLD_800H,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/*mowbvldm800h* -to par_ooo_vec/*RSWBPdstVLd*800* -to \[get_clocks mclk_*]"
set uarch_paths_arr(MOWBVLD,ooo_int,MOWBDATAVLDSRSDUPM805H,ST) "-from \[get_clocks mclk_*] -through par_meu/*mowbdatavldrsdupm805h* -to par_ooo_int/*mowbdatavldooodupm805h* -to mclk*" 
#report mowbvld internal paths
set uarch_paths_arr(MOWBVLD,ooo_int,MOWBVLD_800H_internal,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/*mowbvldm800h* -to par_ooo_int/*RSWBPdstVLd*800* -to \[get_clocks mclk_*]"
set uarch_paths_arr(MOWBVLD,ooo_int,MOWBVLD_800H_internal,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/*mowbvldm800h* -to par_ooo_int/*WBPdstVLd*800* -to \[get_clocks mclk_*]"

########################
## RAPDST
########################

set uarch_paths_arr(RAPDST,ooo_int,RAPDST,ST) "-from \[get_clocks mclk_*] -through par_ooo_int/*ra*pdst* -to par_ooo_vec/*ra*pdst* -to mclk*"

########################
## STALLS
########################

set uarch_paths_arr(OOO_STALLS,ooo_int,RASTALL) "-from \[get_clocks mclk_*] -through par_ooo_int/*rastall2fet_m202l* -to \[get_clocks mclk_*]"
set uarch_paths_arr(OOO_STALLS,ooo_int,ALSPECSTALL) "-from \[get_clocks mclk_*] -through par_ooo_int/*alspecstallm201l* -to \[get_clocks mclk_*]"
set uarch_paths_arr(OOO_STALLS,ooo_int,ALDELAYEDSTALL) "-from \[get_clocks mclk_*] -through par_ooo_int/*aldelayedstallm201h* -to \[get_clocks mclk_*]"

#i 'll add endpoints only in ooo_int


########################
## RS_LOOP
########################
set uarch_paths_arr(RSLOOP,ooo_int,RSLOOP) "-from par_ooo_int/rs_int/rseumtx/mclk* -th par_ooo_int/rs_int/rseumtx/*nordy* -th par_ooo_int/rs_int/rssched/rseuschedoutm300h* -to par_ooo_int/rs_int/rseumtx/*sched*"

#add this
#ranewpdstovr- rapsrc -  rspsrc 


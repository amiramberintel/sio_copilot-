set uarch_paths_arr(dc2pm,meu,dc2pm) {-through [get_pins par_meu/"dc2pm*m40*"]}
set uarch_paths_arr(snoop_address,meu,dtmeadr) {\
    -through [get_pins par_meu/dtmeadr*0*]\
    }
    set uarch_paths_arr(dtmiss,meu,dtmiss) {\
    -through [get_pins par_meu/dtmissaddrm404h*]\
    }
    set uarch_paths_arr(snoop_address,meu,dtstphy) {\
    -through [get_pins par_meu/dtstphysadrvm404h*]\
    }

    # Critical interface paths
    
    set uarch_paths_arr(dcreq,meu,dcreq) {\
    -through [get_pins "par_meu/dc*req*0*"]\
    }
    set uarch_paths_arr(lbsnpadr,meu,lbsnpadr) {\
    -through [get_pins "par_meu/lbsnpadr*"]\
    }
    set uarch_paths_arr(pmphyadr,meu,pmphy) {\
    -through [get_pins "par_meu/pmphyadrm402h*"]\
    }
    set uarch_paths_arr(pmpipe,meu,pmpipereq) {\
    -through [get_pins "par_meu/pmpipereqldm398h*"]\
    }
    set uarch_paths_arr(804,meu,meu_to_exe_int) {\
    -through [get_pins par_meu/dcsdbexponesldm804h*]\
   }
set uarch_paths_arr(ld_loop,meu,siaxe_to_dcldport) {\
     -through [get_pins par_meu/siaxeld1vd/dcLdDataM805H*] \
     -through [get_pins par_meu/dclddatam805h*]\
     }

     set uarch_paths_arr(ld_loop,meu,dcsdbint) {\
     -through [get_pins par_meu/dcsdbintldwbdatam804h*]\
     }





    ####dt####
	set uarch_paths_arr(dtlbhit,meu,dtsmlhit) {\
        -through [get_pins par_meu/dtlb/dttagaryd/DTSmlHitVecLdM402H*] \
        -through [get_pins par_meu/dtlb/dtdataryd/*]\
    }
set uarch_paths_arr(ld_loop,meu,agu_aglinadr_start) {\
    -through [get_pins par_meu/aglinadrstart304orm305h*]\
    }
    set uarch_paths_arr(ld_loop,meu,agu_aglinadr_ld) {\
    -through [get_pins par_meu/aglinadrld304orm305h*]\
    }
    set uarch_paths_arr(ld_loop,meu,agu_aglinadr_st) {\
    -through [get_pins par_meu/aglinadrst304orm305h*]\
    }
    set uarch_paths_arr(ld_loop,meu,agu_aglnsplit) {\
    -through [get_pins par_meu/*agealnsplitm304h*]\
    }

  set uarch_paths_arr(ld_loop,meu,fbhit) {\
    -to [get_pins -hier -filter "full_name =~ par_meu/*FBHIT*" -nocase]\
    }

  set uarch_paths_arr(ld_loop,meu,ldreadright) {\
    -to [get_pins -hier -filter "full_name =~ par_meu/*LdReadRight*" -nocase]\
    }



set uarch_paths_arr(ROB-MOB,meu,rort) {\
    -through [get_pins "par_meu/rort*"]\
    }

    ###ml2dc######
   set uarch_paths_arr(ml2dcsnp,meu,ml2dc) {\
    -through [get_pins "par_meu/ml2dc*0*"]\
    }

    ###dc2ml######
   set uarch_paths_arr(dc2ml,meu,dc2ml) {\
    -through [get_pins "par_meu/dc2ml*0*"]\
    }

    ###mlrd######
    set uarch_paths_arr(mlrd,meu,mlrd) {\
    -through [get_pins "par_meu/mlrd*"]\
    }

set uarch_paths_arr(dc2pm,meu,dc2pm) {\
    -through [get_pins "par_meu/dc2pm*m40*"]\
    }

    ###jeclr ######
    set uarch_paths_arr(JE,meu,jeclr) {\
    -through [get_pins "par_meu/je*0*"]\
    }

    ###mowb ######
	
    set uarch_paths_arr(wbdatavld,meu,mowb) {\
    -through [get_pins "par_meu/mowb*m80*"]\
    }
    set uarch_paths_arr(800h,meu,mowb_pdst) {\
    -through [get_pins "par_meu/mopdst*"]\
    }
    set uarch_paths_arr(803,meu,mowb_mono) {\
    -through [get_pins "par_meu/mono*ld* moearly*"]\
    }
    set uarch_paths_arr(803,meu,mowb_moearly) {\
    -through [get_pins "par_meu/moearly*"]\
    }

 set uarch_paths_arr(BLOCKID,meu,mob_blockid) {\
    -from [get_cells par_meu/mosaryd/moslnccd/MO*BlockId*M403H*reg*]\
    }

 set uarch_paths_arr(ld_loop,meu,agu_to_lintag) {\
    -from    [get_pins ag*] \
    -to  [get_cells par_meu/dcu/mec_arrays_wrapper/dcl0lintagd*/*dcl0lintagrfip*] \
    }
set uarch_paths_arr(ld_loop,meu,agu_to_lintag_aglinadrstart) {\
    -from    [get_pins par_meu/aglinadrstart* ] \
    -to       [get_cells par_meu/dcu/mec_arrays_wrapper/dcl0lintagd*/*dcl0lintagrfip*]\
    }



set uarch_paths_arr(ld_loop,meu,agu__lintag__cwaysel) {\
-from [get_pins par_meu/*] -through [get_cells -hierarchical *dcl0lintagrfip*] -to [get_cells par_meu/dcu/dcbdatan/*C*WaySelLdM403H_reg*]}

set uarch_paths_arr(ld_loop,meu,LoadData_to_exe_int) {\
    -from    [get_cells par_meu/dcu/dcl0dbankd/dcl0*/*Load*DataM403L*reg*] \
    -to      [get_pins par_meu/dcsdbintldwbdatam804h*]\
    }



set uarch_paths_arr(ld_loop,meu,lintag_to_cwaysel) {\
    -to      [get_cells par_meu/dcu/dcbdatan/C*WaySelLdM403H_reg*]\
    }



set uarch_paths_arr(ld_loop,meu,LoadData_to_exe_vec) {\
    -from    [get_cells par_meu/dcu/dcl0dbankd/dcl0*/*Load*DataM403L*reg*] \
    -to      [get_cells par_meu/siaxeld1vd/*dcLdDataM805H_reg*]\
    }


 set uarch_paths_arr(ld_loop,meu,cwaysel_to_LoadData) {\
    -from    [get_cells par_meu/dcu/dcbdatan/*C*WaySelLdM403H_reg*] \
    -to      [get_cells par_meu/dcu/dcl0dbankd/dcl0*/*Load*DataM403L*reg*]\
    }



set uarch_paths_arr(ld_loop,meu,l0bank_to_dcrotated) {\
     -from [get_cells par_meu/dcu/dcl0dbankd/dcl0*/*Load*DataM403L*reg*] \
     -to [get_pins par_meu/dcu/dcrotated/ChunkRotOutVecM404H*/d]\
    }


set uarch_paths_arr(ld_loop,meu,l0bank_to_siaxe) {\
    -from [get_cells par_meu/dcu/dcl0dbankd/dcl0*/*Load*DataM403L*reg*]\
    }

#set uarch_paths_arr(dttag_to_dtdata) {\
#    -from [get_cells par_meu/dtlb/dttagaryd/*reg*] \
#    -to   [get_cells par_meu/dtlb/dtdataryd/*reg*]\
#    }


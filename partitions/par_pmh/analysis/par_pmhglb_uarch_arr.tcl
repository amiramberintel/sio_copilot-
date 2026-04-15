   set uarch_paths_arr(dtmiss,pmhglb,dtmiss) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/dtmissaddrm404h*]}
   set uarch_paths_arr(pmphyadrm,pmhglb,pmphyadrm) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/pmphyadrm402h*]}
   set uarch_paths_arr(pmipreq,pmhglb,pmipreq) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/pmpipereqldm398h*]}
   #####IF --> PMH################
   set uarch_paths_arr(itrequest,pmhglb,itrequest) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/itrequestm104h]}
   set uarch_paths_arr(itthread,pmhglb,itthread) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/itthreadidm104h]}
   set uarch_paths_arr(itrequestadrm,pmhglb,itrequestadrm) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/itrequestadrm106h*]}
   ####### meu <--> PMH ######
   set uarch_paths_arr(snpadrlm,pmhglb,snpadrlm) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/lbsnpadrlm402h*]}
   set uarch_paths_arr(snpadrhm,pmhglb,snpadrhm) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/lbsnpadrhm401h*]}
   ###### pmh <---> ooo_int######
   set uarch_paths_arr(earlysnoop,pmhglb,earlysnoop) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/earlymosnoophitthrm900h*]}
   set uarch_paths_arr(tailchange,pmhglb,tailchange) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/molbtailchgmnnnh*]}
   ################# JE --> PMH ################
   set uarch_paths_arr(JE,pmhglb,mojeclear) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/jeclearm805h*]}
   #set uarch_paths_arr(JE,pmhglb,pmjeclear) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/jeclearm805h*]}
   #set uarch_paths_arr(JE,pmhglb,clrwakeup) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/jeclearm805h*]}
   set uarch_paths_arr(JE,pmhglb,jeclrmskld) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/jeclrmskldm306h*]}
   set uarch_paths_arr(JE,pmhglb,jerobidm) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/jerobidm305h*]}
   set uarch_paths_arr(JE,pmhglb,jeclrnuken) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/jeclrnukeenldm306h]}
   set uarch_paths_arr(JE,pmhglb,jeclrpwrovr) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/jeclrpwrovrdmnnnh]}
   ############## OOO_VEC --> OOO_INT --> PMH ########### 
   set uarch_paths_arr(JE,pmhglb,rortldinc) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/rortldincm903h*]}	
   set uarch_paths_arr(JE,pmhglb,rortmempwr) {-from [get_clocks *mclk*] -through [get_pins par_pmhglb/rortmempwrenm903h*]}

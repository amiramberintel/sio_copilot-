#!/usr/intel/bin/perl

##Local packages:
use FindBin qw($RealBin);

##For debug purpose:
use Data::Dumper;

##Actual content:
print "alias fcts_bc_cth2  \"/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/aliases_for_pt_client\"\n";
print "\n\n\n";

my %modela_modelb          = ("modela_" => "_a", "modelb_" => "_b");
my %modela_modelb_end_user = ("modela_" => "", "modelb_" => "0");
my %projects               = ("cgc78clienta0" => "cgc78clienta0", "cgc78clientb0" => "cgc78clientb0", "lnc78a0" => "lnc78a0", "lnc78b0" => "lnc78b0", "pnc78icorea0" => "pnc78icorea0" , "pnc78servera0" => "pnc78servera0", "pnc78serverb0" => "pnc78serverb0", "pnc78clienta0" => "pnc78clienta0", "pnc78clientb0" => "pnc78clientb0", "pnc78serverb0" => "pnc78serverb0", "lncn3clienta0" => "lncn3clienta0", "lncn3clientb0" => "lncn3clientb0", "lncn3lnlcliena0" => "lncn3lnlcliena0", "lncn3lnlclienb0" => "lncn3lnlclienb0");
my %projects               = ("pnc78clientb0" => "pnc78clientb0");

my %projects               = ("gfcn2clienta0" => "gfcn2clienta0");

#my %projects               = ("pnc78servera0" => "pnc78servera0", "pnc78serverb0" => "pnc78serverb0");
my %model_types            = ("_fcl" => "l", "_bu_prects" => "p", "_bu_prp" => "b", "_bu" => "i", "_fcn" => "n");
my %modes                  = ("_func" => "", "_spec" => "s", "_fresh" => "r");
my %min_max_types          = ("min_" => "n" , "max_" => "m", "noise_" => "nnn", "rv_" => "rvv");
my %voltages               = ("dvfs"      => "dvf", "hi_hi_lo" => "hhl", "hi_lo_hi" => "hlh", "hi_lo_lo" => "hll", "high"       => "hig", "high_cold" => "hco", "lo_hi_hi"  => "lhh",
                              "lo_hi_lo"  => "lhl", "lo_lo_hi" => "llh", "low"      => "low", "low_client" => "loc", "nom_client" => "noc", "med" => "med", "noise_high" => "nhi", "noise_low" => "nlo", "nom" => "nom", "turbo" => "tur",
                              "high_cold" => "hco", "low_cold" => "lco", "slow_low" => "sll"  ,"slow" => "slo", "slow_cold" => "slc", "pcss_high" => "phi", "pcss_low_cold" => "plc", "pcss_low" => "pcl", "fast_cold" => "fcd", "fast" => "fff", "hvqk" => "hvq");
my %temps                  = ("F_125" => "f125", "S_M40" => "sm40", "S_125" => "s125" , "T_85" => "t085", "S_0" => "s000", "F_M40" => "fm40", "F_105" => "f105", "TT_100" => "t100", "TM_100" => "tm1",
                              "rcffcminpcff_125" => "rcffcminpcff125","rcffcminpcff_m40" => "rcffcminpcffm40","rcsscmaxpcss_125" => "rcsscmaxpcss125",
			      "rcsscmaxpcss_m40" => "rcsscmaxpcssm40","rfffcmintttt_110" => "rfffcmintttt110","ttttcmaxtttt_100" => "ttttcmaxtttt100",
			      "ttttcmaxtttt_m40" => "ttttcmaxttttm40","ttttcmintttt_100" => "ttttcmintttt100","ttttctyptttt_105" => "ttttctyptttt105"
                             );

my %skew                   = ("typical" => "", "cbest_CCbest" => "ccb", "rcworst_CCworst" => "rcw", "cworst_CCworst" => "ccw", "rcworst_CCworst_T" => "rct", "cworst_CCworst_T" => "cct", "typical_CCworst" => "tcc", "tttt" => "ttt", "pcss" => "pcc", "prcs" => "prc");              


#Read cfg file and update the avail corners:
my $config_file = "$RealBin/pt_server_c2dgbcptserver_cron.cfg";

#Read the cfg file each line by line, save data under %planned_cfg_servers{$server_name}
open (my $FH, "<", $config_file);
while (my $line = <$FH>) {
   chomp($line);
   if ($line =~ /^\s*#/ && $line !~ /^\s*##/ && $line !~ /set pt_server/) {
      $line =~ s/#//g;
      my ($model,$type,$corner,$modelb_or_modela,$process,$machine,$socket) = split(/,/, $line);
      my $server_name;
      $server_name =  $model . "_" . $type . "_" . $corner;
      $planned_cfg_servers{$server_name} = 1;
   }   
}

#Iterate line by line and filter only relevant aliases:
foreach my $proj (keys %projects) {
   print "\n\n### ". uc($proj) . "\n\n";
   foreach my $modela_or_modelb (keys %modela_modelb) {
      print "\n# ${modela_or_modelb}servers\n\n" if ($modela_or_modelb ne "modela_");
      foreach my $model_type (keys %model_types) {  
         foreach my $mode (keys %modes) {
            foreach my $min_max (keys %min_max_types) {
               foreach my $volt (keys %voltages) {
                  foreach my $temp (keys %temps) {
                      foreach my $skew (keys %skew) {  
   		          next if ($mode eq "_all" && ($min_max ne "max_" || $temp ne "" || ($volt ne "" && $volt ne "_lowvcc")));
                          next if (($model_type eq "_fcl" || $model_type eq "_fcn") && ($temp eq "_cold" || $volt =~ /2|hvqk/ || $min_max ne "max_" || $mode eq "_scan"));
                          next if ($temp eq "_cold" && $min_max ne "min_");
                          #next if ($mode eq "_spec" && $model_type ne "_fcl");
                          next if ($min_max ne "min_" && $volt eq "_hvqk");
                          my $server_name_prefix_end_user;
                          if ($modela_or_modelb eq 'modela_') {
		              $server_name_prefix_end_user = 'latest_';
                          } else {
		              $server_name_prefix_end_user = 'prev_';
		          }
		          my $server_name = "${modela_or_modelb}${proj}${model_type}${mode}\.${min_max}${volt}\.${temp}\.${skew}";
                          my $server_name_end_user = "$server_name_prefix_end_user"."${proj}${model_type}${mode}\.${min_max}${volt}\.${temp}\.${skew}";
	                  my $alias = $projects{$proj}; 
                          $alias .= $model_types{$model_type};
                          $alias .= $modes{$mode} if ($model_type eq "_fcl" || $mode eq "_scan" || $model_type eq "_fcn" || $mode eq "_all");
                          $alias .= $min_max_types{$min_max}; #unless ($model_type eq "_fcl" || $model_type eq "_fcn");
                          $alias .= $voltages{$volt};
                          $alias .= $temps{$temp};
                          $alias .= $skew{$skew};
		          my $alias_end_user = $alias;
                          $alias .= $modela_modelb{$modela_or_modelb};
                          #print "$server_name => $alias\n";
		          #Iterate each acail server and try to add it as well:
			  foreach $key (sort keys %planned_cfg_servers) {
			      if ($server_name =~ /$key/) {			  
			          #print "Found :: '$server_name' which includes:: '$key'\n";
				  print "alias  $alias   \'fcts_bc_cth2 -m $server_name    -c \"\\!*\"\'\n";
                                  $alias_end_user .= $modela_modelb_end_user{$modela_or_modelb};
                                  print "alias  $alias_end_user   \'fcts_bc_cth2 -m $server_name_end_user    -c \"\\!*\"\'\n";
			      } else {
			          #print "the alias $server_name_end_user is not cfg, will skip it for now..\n";
			      }
                          }
                      }
                  }
               }
            }
         }
      }
   }
}

#
#4	2	1
#low	low	low 
#low	low	high
#low	high	low 
#low	high	high
#high	low	low 
#high	low	high
#high	high	low 
#high	high	high

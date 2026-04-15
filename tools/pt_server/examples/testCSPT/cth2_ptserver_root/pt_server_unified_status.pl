#!/usr/intel/bin/perl

###########################################################################################
#   Created by  <Givol Ohad>  at  <Feb 2020>
#   Current owner : <ogivol>
#   Purpose of the script : Clear status of PT SERVER allocation
#   Input of the script: arg0: mail_status ;
#   Input of the script: arg1: root_area where all logs are placed (pid, cfg, aliases) ;
#   Input of the script: arg2: root_area where all logs are placed (pid, cfg, aliases) ;
#   Input of the script: arg3: to_list ;
#   Output of the script: serever status summary
###########################################################################################
use File::stat;
use Time::localtime;
#https://perldoc.perl.org/Time/localtime.html
#https://www.cs.ait.ac.th/~on/O/oreilly/perl/learn32/ch10_07.htm
#https://alvinalexander.com/blog/post/perl/how-determine-access-read-modification-update-time-file

#site definition:
my $site = 'sc';

use Data::Dumper;
use Spreadsheet::WriteExcel;    # using package for writing to excel file
my $no_mail    = $ARGV[0];      # skiping mail to user
my $root       = $ARGV[1];      # cron logs area
my $root_log   = $ARGV[2];      # current script output log area
my $to_list    = $ARGV[3];      # bypass for to_list_definition

#location of client script
my $pt_client = "$root/pt_client.pl";

#Isamba report location
my $isamba_report_location     = '//sc8-samba.sc.intel.com/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/cth2_ptserver_track_system/report.html';
my $isamba_report_location_xls = '//sc8-samba.sc.intel.com/nfs/site/proj/lnc/c2dgbcptserver_sc8_fct/cth2_ptserver/cth2_ptserver_root/cth2_ptserver_track_system/report.xls';

#finding running jobs
my $pt_server_cfg_file = "${root}/pt_server_c2dgbcptserver_cron.cfg";

#define the conrtol hash which will hold all existing jobs
my %control_hash;
my %machine_hash;

#define the status per host machine
my %control_hash_per_host;

#opening cfg file for reading:
open(my $fh_cfg, "<", "$pt_server_cfg_file");

#reading each line
print "-I- Reading cfg file...\n";
my $pt_server_end_user_links = "";
while( my $line_cfg = <$fh_cfg>)  {   
    chomp($line_cfg);
  
    #For html later on, get where user shall place links of each session:
    if ($line_cfg =~ /set\s+pt_server_end_user_links\s+(\S+)/) {
        $pt_server_end_user_links = $1;
    }
    
    #Cfg foreach session per model/corner/model_name/process/machine/pid_cfg:
    unless ($line_cfg =~ /scff|scc8|scfb|scc/ && $line_cfg =~ /^#/) {next};        
    my ($die,$model,$corner,$modela_modelb,$process,$machine,$pid_cfg)  = split(',',$line_cfg);    
    
    $die =~ s/#//;
    $control_hash{$die}{$modela_modelb}{$model}{$corner}{machine} = $machine;
    $control_hash{$die}{$modela_modelb}{$model}{$corner}{pid_cfg} = $pid_cfg;
    
    my $current_corner_on_server = "${modela_modelb}_${die}_${model}_${corner}";
    $control_hash{$die}{$modela_modelb}{$model}{$corner}{current_corner_on_server} = $current_corner_on_server;
    #print "current_corner_on_server => $current_corner_on_server\n";
    #print "-I- Adding now: die => $die,model => $model,corner => $corner,modela_modelb => $modela_modelb, machine => $machine, pid_cfg => $pid_cfg\n"; 
    
    #adding status per host name:
    $machine_host_log = "$root/pt_server_model_status_per_server/pt_server_${machine}.log";
    $model_status_per_model_type = "$root/pt_server_model_status_per_model_type/${current_corner_on_server}_pt.log";
    $model_status_per_model_type_loading_file = "$root/pt_server_model_status_per_model_type/${current_corner_on_server}.loading";
   
    if (-e $machine_host_log) {
        $machine_hash{$machine}{status_per_machine} = `cat $machine_host_log | grep Total` ;
    }
    
    if (-e $machine_host_log) {
        $machine_hash{$machine}{time_stamp_per_log} = ctime(stat($machine_host_log)->mtime);
    } else {
        $machine_hash{$machine}{time_stamp_per_log} = "Not Available (Should be created soon)";
    }
    
    $control_hash{$die}{$modela_modelb}{$model}{$corner}{machine_host_log} = $machine_host_log;
    $control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type} = $model_status_per_model_type;
    
    
    #Add loading file in case exists:
    if (-e $model_status_per_model_type_loading_file) {
        #print "${current_corner_on_server} => ohad yes\n";
        $control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type_loading_file} = $model_status_per_model_type_loading_file;        
	$control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type_loading_file_time} = stat($model_status_per_model_type_loading_file)->mtime;   
    } else {
        #print "${current_corner_on_server} => ohad no\n";
        $control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type_loading_file} = "NA";        
	$control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type_loading_file_time} = "NA";       
    }
    
    chomp($machine_hash{$machine}{status_per_machine});
    
    #back annoate server status based on cron log:
    open(my $fh_machine, "<", "$machine_host_log");
    while( my $line_machine = <$fh_machine>)  {   
        chomp($line_machine);    
	my $corner_string = "${modela_modelb}_${die}_${model}_${corner}";
        #if ($line_machine =~ /checking server:\s+($current_corner_on_server)\s+\-\s+.*\s+server\s+\S+\s+is\s+(.*)/) {
        if ($line_machine =~ /checking server:\s+(.*)\s+-.*server\s(.*)\sis\s(.*)/) {
              my $current_corner = $2;
              unless ($current_corner eq $corner_string) {
	            #print "$current_corner ne $corner_string\n";
		        next;
	      } else {
	            #print "$current_corner eq $corner_string\n";
              }
	        # print "momo ==> $2\n";
	        # print "status ==> $3\n";
	        # print "machine ==> $machine\n";
	      
	      my $status = $3;
	      #my $corner_string = "$1";
              #my $modela_modelb = "modela";
              #if ($corner_string =~ /modelb/) {$modela_modelb = 'modelb' ; $corner_string =~ s/modelb_//};
              #$corner_string =~ /(\S+?)_(.*)/g;
              #print "corner_string = $corner_string\n";
	      
	      #$die = $1;
	      #print "die = $die\n";
              #$model_and_corner = $2;
	      #print "model_and_corner = $model_and_corner\n";
              #$model_and_corner =~ /(.*)_([func|scan].*)/;
              #$model = $1;
              #$corner = $2;            
	      $control_hash{$die}{$modela_modelb}{$model}{$corner}{status} = $status;
	      $control_hash{$die}{$modela_modelb}{$model}{$corner}{status_time_from_machine_host_log} = ctime(stat($machine_host_log)->mtime);
	      #print "line_machine = '$line_machine' =>\n";
	      #print ("$line_machine\n");
	      #print "line_machine parsing result: die = $die modela_modelb = $modela_modelb model = $model corner = $corner status = $status\n";
	}
    }
    close($fh_machine);    
}
close($fh_cfg);

if ($ENV{DEBUG_MODE}) {
    print "-I- printing control hash - check1 - now - begin:\n";
    print Dumper (\%control_hash);
    print "-I- printing control hash - check1 - now - end:\n";
    
    print "-I- printing machine_hash - check1.2 - now - begin:\n";
    print Dumper (\%machine_hash);
    print "-I- printing machine_hash - check1.2 - now - end:\n";
    
    
}    
    
#Creation of brief status summary hash here:
my %briefHashSummary;
foreach my $die (sort keys %control_hash) {
    foreach my $modela_modelb (sort keys %{$control_hash{$die}}) {
        foreach my $model  (sort keys %{$control_hash{$die}{$modela_modelb}}) {
	    foreach my $corner (sort keys %{$control_hash{$die}{$modela_modelb}{$model}}) {		
		my $status = "NO STATUS";
                if (exists $control_hash{$die}{$modela_modelb}{$model}{$corner}{status}) {
		    $status = $control_hash{$die}{$modela_modelb}{$model}{$corner}{status};
                }
		if (exists $briefHashSummary{$status}) {
		    $briefHashSummary{$status}++;
		} else {
		    $briefHashSummary{$status} = 1;
		}
            }
	}
    }
}

if ($ENV{DEBUG_MODE}) {
    print "-I- printing briefHashSummary hash - check1.5 - now - begin:\n";
    print Dumper (\%briefHashSummary);
    print "-I- printing briefHashSummary  hash - check1.5 - now - end:\n";
}    

#mapping each sessions based on cron logs status:
my $aliases_file = "$root/aliases_for_pt_client";

#Aliases and missing under cfg file:
my %InAliasMissingCFG;

#opening cfg file for reading:
open(my $fh_aliases, "<", "$aliases_file");

#reading each line
print "-I- Reading aliases file...\n";
while( my $line_alias = <$fh_aliases>)  {   
    chomp($line_alias);
    
    unless ($line_alias =~ /alias\s+(\S+)\s+\'fcts_bc_cth2\s+\-m\s+(\S+)\s+\-c/) {next};
    my $command_example = $line_alias;
    #$command_example =~ s/(.*)(\/\/*.*)/$1/;
    my $modela_modelb = "modela";
    my $alias = $1;
    #print "aliase = $alias\n";
    my $die_corner = $2;
    my $die_corner_full = $die_corner;
    #print "die_corner = $die_corner\n";   
    #Skip current line if not hold _a or _b as this is an end user alias):
    #if (($alias =~ /_a/) || ($alias =~ /_b/)) {
    #    #Take line as is this is not an end user alias
    #} else {
    #    #Skip current line as it is an end user alias
    #	next;
    #}
    if ($die_corner =~ /modelb/) {
        $modela_modelb = 'modelb' ; $die_corner =~ s/modelb_//;
    } elsif ($die_corner =~ /modela/) {
        $modela_modelb = 'modela' ; $die_corner =~ s/modela_//;
    } else {
        next;
    }
    #print "die_corner = $die_corner\n";
    #print "die_corner = $die_corner\n";
    $die_corner =~ /(.*)_(base|fcn|fcl|bu_prp|bu_mc_prp|bu_prp_x2r3|bu)_(.*)/g;
    $die = $1;
    $model = $2;
    $corner = $3;
    #print "adding under aliases: modela_modelb = $modela_modelb | corner = $corner | model = $model | die = $die | die_corner = $die_corner | die_corner_full = $die_corner_full \n";
    
    if ((exists $control_hash{$die}) && (exists $control_hash{$die}{$modela_modelb}) && (exists $control_hash{$die}{$modela_modelb}{$model}) && (exists $control_hash{$die}{$modela_modelb}{$model}{$corner})) {
        #print "found => adding now alias: $alias with $command_example\n";    
	$control_hash{$die}{$modela_modelb}{$model}{$corner}{alias} = $alias;
	my $end_user_alias = $alias;
	$end_user_alias =~ s/_a//; $end_user_alias =~ s/_b//;
	$end_user_alias = "$end_user_alias | ${end_user_alias}0";
	#print "$end_user_alias nnnnn\n";
	$control_hash{$die}{$modela_modelb}{$model}{$corner}{end_user_alias} = $end_user_alias;
	$control_hash{$die}{$modela_modelb}{$model}{$corner}{command_example} = $command_example;
    } else {   
        #print "missing =>\n"; 
	$InAliasMissingCFG{$alias}{command_example} = "$command_example";
	$InAliasMissingCFG{$alias}{die} = "$die";
	$InAliasMissingCFG{$alias}{model} = "$model";
        $InAliasMissingCFG{$alias}{corner} = "$corner";
	$InAliasMissingCFG{$alias}{modela_modelb} = "$modela_modelb";
    }
    
}
close ($fh_aliases);

#Creation of connected models summary hash here:
my %connectedModelsHashSummary;
foreach my $die (sort keys %control_hash) {
    foreach my $modela_modelb (sort keys %{$control_hash{$die}}) {
        foreach my $model  (sort keys %{$control_hash{$die}{$modela_modelb}}) {
	    foreach my $corner (sort keys %{$control_hash{$die}{$modela_modelb}{$model}}) {		
                if (exists $control_hash{$die}{$modela_modelb}{$model}{$corner}{status}) {
                    my $links_location = "$root/pt_server_model_link/";
                    my $model_location_path = "$links_location/${modela_modelb}_${die}_${model}";
                    #print "$model_location_path\n";
		    if (-e $model_location_path) {
                        $connectedModelsHashSummary{$die}{$modela_modelb}{$model} = $model_location_path;         
		    } else {
		        $connectedModelsHashSummary{$die}{$modela_modelb}{$model} = "$model_location_path"." [NA]";
		    }
                }
            }
	}
    }
}


if ($ENV{DEBUG_MODE}) {
    print "-I- printing control hash - check2 - now - begin:\n";
    print Dumper (\%control_hash);
    print "-I- printing control hash - check2 - now - end:\n";
    print "-I- printing InAliasMissingCFG hash - check3 - now - begin:\n";
    print Dumper (\%InAliasMissingCFG);
    print "-I- printing InAliasMissingCFG hash - check3 - now - end:\n";
    print "-I- printing connectedModelsHashSummary hash - check4 - now - begin:\n";
    print Dumper (\%connectedModelsHashSummary);
    print "-I- printing connectedModelsHashSummary hash - check4- now - end:\n";

}  

#Get List of avail machines this qslot:
my %ionCapacityStatusForPtShellHash;
my $cmd = "/usr/intel/bin/ion-capacity -P sc8_interactive -r -b \"resourcegroups=~'suel12_special.ptshell.bc_tool'\" | /bin/grep -v HOST";
print "-I- running now: $cmd\n" if ($ENV{DEBUG_MODE});
foreach my $line (`$cmd`) {
    $line =~ /(\S+)\s+(\S+)\s+.*\s+(sue.*)/;
    my $host = $1;
    my $status = $2;
    my $resourceGroups = $3;
    $ionCapacityStatusForPtShellHash{$host}{status} = $status;
    $ionCapacityStatusForPtShellHash{$host}{resourceGroups} = $resourceGroups;
}
if ($ENV{DEBUG_MODE}) {
    print "-I- printing ionCapacityStatusForPtShellHash hash - check5 - now - begin:\n";
    print Dumper (\%ionCapacityStatusForPtShellHash);
    print "-I- printing ionCapacityStatusForPtShellHash hash - check5- now - end:\n";
}

if ($ENV{DEBUG_MODE}) {
    print "-I- printing machine_hash - check6 - now - begin:\n";
    print Dumper (\%machine_hash);
    print "-I- printing machine_hash - check6 - now - end:\n";
}

#create xls file:
my $xls_file = "$root_log/report.xls";
my $workbook = Spreadsheet::WriteExcel -> new ($xls_file);
my $worksheet = $workbook -> add_worksheet ('ServerStatusPerCFG');

#set coulmn width:
$worksheet->set_column( 0 , 0 , 16 );
$worksheet->set_column( 1 , 1 , 16 );
$worksheet->set_column( 2 , 2 , 15 );
$worksheet->set_column( 3 , 3 , 25 );
$worksheet->set_column( 4 , 4 , 10 );
$worksheet->set_column( 5 , 5 , 14 );
$worksheet->set_column( 6 , 6 , 40 );
$worksheet->set_column( 7 , 7 , 10 );
$worksheet->set_column( 8 , 8 , 70 );
$worksheet->set_column( 9 , 9 , 70 );
$worksheet->set_column( 10 , 10 , 70 );

our $format_title    = $workbook->add_format(bg_color=>'22',border=>'1',bold=>1);  #silver bold
our $format_def      = $workbook->add_format(border=>'1');
our $format_magenta  = $workbook->add_format(bg_color=>'14',border=>'1');
our $format_red      = $workbook->add_format(bg_color=>'10',border=>'1');
our $format_yellow   = $workbook->add_format(bg_color=>'13',border=>'1');
our $format_lime     = $workbook->add_format(bg_color=>'11',border=>'1');
our $format_cyan     = $workbook->add_format(bg_color=>'15',border=>'1');
our $format_gray     = $workbook->add_format(bg_color=>'22',border=>'1');      #silver without bold
our $format_purple   = $workbook->add_format(bg_color=>'20',border=>'1');
our $format_orange   = $workbook->add_format(bg_color=>'53',border=>'1');


####################
####  Headers ######
####################
my $row = 0;
my $col = 0;
my $cur_format = $format_title;
$worksheet -> write ($row , $col++, "Die", $cur_format);
$worksheet -> write ($row , $col++, "ModelB/ModelA", $cur_format);
$worksheet -> write ($row , $col++, "Model", $cur_format);
$worksheet -> write ($row , $col++, "Corner", $cur_format);
$worksheet -> write ($row , $col++, "DA Direct Alias", $cur_format);
$worksheet -> write ($row , $col++, "User Otional Alias", $cur_format);
$worksheet -> write ($row , $col++, "Status", $cur_format);
$worksheet -> write ($row , $col++, "Host", $cur_format);
$worksheet -> write ($row , $col++, "CommandExample", $cur_format);
$worksheet -> write ($row , $col++, "LogDebug", $cur_format);
$worksheet -> write ($row , $col++, "LogDebugForCurrentHost", $cur_format);

my %missing_servers_per_host;
$row++;
$col = 0;
$cur_format = $format_def;
foreach my $die (sort keys %control_hash) {
    foreach my $modela_modelb (sort keys %{$control_hash{$die}}) {
        foreach my $model  (sort keys %{$control_hash{$die}{$modela_modelb}}) {
	    foreach my $corner (sort keys %{$control_hash{$die}{$modela_modelb}{$model}}) {		
		$worksheet -> write ($row , $col++, $die, $cur_format);
		$worksheet -> write ($row , $col++, $modela_modelb, $cur_format);
		$worksheet -> write ($row , $col++, $model, $cur_format);
		$worksheet -> write ($row , $col++, $corner, $cur_format);
		$worksheet -> write ($row , $col++, $control_hash{$die}{$modela_modelb}{$model}{$corner}{alias}, $cur_format);
		$worksheet -> write ($row , $col++, $control_hash{$die}{$modela_modelb}{$model}{$corner}{end_user_alias}, $cur_format);
		$status = "$control_hash{$die}{$modela_modelb}{$model}{$corner}{status}";
		my $status_format = $format_red;
		if ($status =~ /UP and UPDATED/) {
		    $status_format = $format_lime;
		} elsif ($status =~ /LOADING/) {
		    $status_format = $format_yellow;
		} else {
		   $status_format = $format_red;
                   my $host = $control_hash{$die}{$modela_modelb}{$model}{$corner}{machine};
                   $missing_servers_per_host{$host} .= ($missing_servers_per_host{$host} eq "") ? "${modela_modelb}_${die}_${model}_${corner}" : ",${modela_modelb}_${die}_${model}_${corner}";
		}
		
		$worksheet -> write ($row , $col++, $status, $status_format);
		$worksheet -> write ($row , $col++, $control_hash{$die}{$modela_modelb}{$model}{$corner}{machine}, $cur_format);
		$worksheet -> write ($row , $col++, $control_hash{$die}{$modela_modelb}{$model}{$corner}{command_example}, $cur_format);
		$worksheet -> write ($row , $col++, $control_hash{$die}{$modela_modelb}{$model}{$corner}{machine_host_log}, $cur_format);
		$worksheet -> write ($row , $col++, $control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type}, $cur_format);
	        $row++; $col = 0; 
	    }  
        }
    }
}

my $worksheet = $workbook -> add_worksheet ('RedundentAliases');

#set coulmn width:
$worksheet->set_column( 0 , 0 , 16 );
$worksheet->set_column( 1 , 1 , 16 );
$worksheet->set_column( 2 , 2 , 15 );
$worksheet->set_column( 3 , 3 , 25 );
$worksheet->set_column( 4 , 4 , 70 );
$worksheet->set_column( 5 , 5 , 10 );


####################
####  Headers ######
####################
my $row = 0;
my $col = 0;
my $cur_format = $format_title;

$worksheet -> write ($row , $col++, "DA Direct Alias", $cur_format);
$worksheet -> write ($row , $col++, "Die", $cur_format);
$worksheet -> write ($row , $col++, "ModelAModelB", $cur_format);
$worksheet -> write ($row , $col++, "Corner", $cur_format);
$worksheet -> write ($row , $col++, "Command", $cur_format);

$row++;
$col = 0;
$cur_format = $format_def;
foreach my $alias (sort keys %InAliasMissingCFG) {
    my $command_example = $InAliasMissingCFG{$alias}{command_example};
    my $die = $InAliasMissingCFG{$alias}{die};
    my $corner = $InAliasMissingCFG{$alias}{corner};
    my $modela_modelb = $InAliasMissingCFG{$alias}{modela_modelb};

    $worksheet -> write ($row , $col++, $alias, $cur_format);
    $worksheet -> write ($row , $col++, $die, $cur_format);
    $worksheet -> write ($row , $col++, $modela_modelb, $cur_format);
    $worksheet -> write ($row , $col++, $corner, $cur_format);
    $worksheet -> write ($row , $col++, $command_example, $cur_format);
    $row++; $col = 0; 
}  

$workbook ->close();

print "-I- Create xls_file here : $xls_file\n";

#create release notes:
$ReleaseNotesHTML = "$root_log/report.html";
open (my $fh , ">", $ReleaseNotesHTML) || die "Cannot open  for writing: $!";
 
 
    #https://www.w3schools.com/charsets/tryit.asp?deci=129409 
    #https://www.w3schools.com/charsets/ref_emoji.asp
    print $fh "<html>\n";
    print $fh "<p><center><font size=\"6\" color=\"#1347B0\" face=\"Tahoma\"><b>The Future by C<sup>2</sup>DG | Core && Client Development Team | Intel<sup>&#174;</sup></font></center></b>\n";
    print $fh "<p><center><font size=\"3\" color=\"#1347B0\" face=\"Tahoma\"><b>C<sup>2</sup>DG BE Integration DA IDC, CTH2 PrimeTime C2DG Server Status, by \@$ENV{USER} LNL CTH2 system -  host sccf06125510</font></center></b>\n";
    
    my $cmd = 'date +"%Y"';
    my $year = `$cmd`;
    chomp($year);
    my $cmd = 'date +"%V"';
    my $workweek = `$cmd`;
    chomp($workweek);
    my $cmd = `date`;
    my $date = $cmd;
    chomp($date);
    print $fh "<p><center><font size=\"3\" color=\"#1347B0\" face=\"Tahoma\"><b> root = $root | root_log = $root_log</font></center></b>\n";
    print $fh "<p><center><font size=\"3\" color=\"#1347B0\" face=\"Tahoma\"><b>$date</b></font></center><br>\n";
    print $fh "<p><center><font size=\"3\" color=\"#9400D3\" face=\"Tahoma\"> &#129409; <b>Data below is being updated every 5 min...</b> &#129409; </font></center><br>\n";

    #print $fh "<p><center><font size=\"6\" color=\"#FF7326\" face=\"Comic sans MS\"><u><b>\"${year} - WW${workweek} - $date\"</font></center></b></u><br><br>\n";

    print $fh "<p><font size=\"2\" color=\"blue\" face=\"Tahoma\"><b>Hi All,</font></b><br><br>\n";

    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b>      This is PT Server status and allocation based on current linked models:</font><br><br>\n";
    
    #Print #66ff33 how to - short list:
    print $fh "<font size=\"2\" color=\"green\" face=\"Tahoma\"><b><u>End User How To: </b></u></font><br>\n";
    print $fh "<font size=\"3\" color=\"red\" face=\"Tahoma\"><b><ul><li>Aliases: User should source ${root}/aliases_for_pt_client</li>\n";
    print $fh "<font size=\"3\" color=\"red\" face=\"Tahoma\"><b><li>Model Owners: Links shall be updated Here: $pt_server_end_user_links</b></li>\n";   
    print $fh "<font size=\"2\" color=\"green\" face=\"Tahoma\"><b><li>Online 24x7 Status Live from CTH2 Light Infra R2G PT Server: Visit Us Here (windows): <a href='$isamba_report_location'>Visit our online Status</a></li>\n";
    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b><li>How To run command: <alias> <relevant_command> :: example: afl report_timing => it will report user based on modela_adla0_base_func_max_lowvcc </li>\n";
    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b><li>Current Models Status Brief: See Table:</li>\n";
    
    #Print status per host:
    print $fh "<table border=\"1\">\n";
    print $fh "<tr>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Status</th>\n";
    foreach my $status_header (sort keys %briefHashSummary) {
        print $fh " <th bgcolor=\"#D3D3D3\" font size=\"1\">$status_header</th>\n";
    }
    print $fh "</tr>\n";
    print $fh "</tr>\n";   
    print $fh " <th bgcolor=\"#D3D3D3\">Count</th>\n";
    foreach my $status_header (sort keys %briefHashSummary) {
        my $status_value = $briefHashSummary{$status_header};
        my $color = 'red';
	if ($status_header =~ /UP and UPDATED/) {
	    $color = '#66ff33';
	} elsif ($status_header =~ /LOADING/) {
	    $color = 'yellow';
	} elsif ($status_header =~ /OVERLOADED/) {
	    $color = 'blue';
	}
	print $fh " <th bgcolor=\"$color\" font size=\"1\">$status_value</th>\n";
    }
    print $fh "</tr>\n";
    print $fh "</table>\n";
        
    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b><li>Current Models Linked and connected: See Table:</li>\n";
    
    #Print status per model in case such model linked:
    print $fh "<table border=\"1\">\n";
    print $fh "<tr>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Die</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">ModelB/ModelA</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">ModelType</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">ModelPath</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">ModelPathLastUpdated</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">AFreshModel - (during last 3 hours)?</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">ModelLinkOwner</th>\n";
    print $fh "</tr>\n";   

    foreach my $die (sort keys %connectedModelsHashSummary) {
        foreach my $modela_modelb (sort keys %{$connectedModelsHashSummary{$die}}) {
	    foreach my $model (sort keys %{$connectedModelsHashSummary{$die}{$modela_modelb}}) {
	        my $model_location_path = "$connectedModelsHashSummary{$die}{$modela_modelb}{$model}";
		my $color = "white";
		print $fh "<tr>\n";
		print $fh " <th bgcolor=\"$color\" font size=\"1\">$die</th>\n";
		if ($modela_modelb =~ /modela/) {
		    $color = "#66ff33";
		} else {
		    $color = "blue";
		}
		print $fh " <th bgcolor=\"$color\" font size=\"1\">$modela_modelb</th>\n";
		
		$color = 'white';
		for ($model) {
                    /bu/ && do { $color = '#66ff33' };
                    /fcl/ && do { $color = 'cyan' };
                    /fcn/ && do { $color = 'yellow' };
		    /bas/ && do { $color = 'orange' };
                }

		print $fh " <th bgcolor=\"$color\" font size=\"1\">$model</th>\n";		
		if ($model_location_path =~ /NA/) {
		    $color = "red";
		} else {
		    $color = "#66ff33";
		}
		
		print $fh " <th bgcolor=\"$color\" font size=\"1\">$model_location_path</th>\n";
		$color = 'red';
	        $model_location_path_last_updated = "Model Not Avail";
		if (-e $model_location_path) {
		    $model_location_path_last_updated =ctime(stat($model_location_path)->mtime);
		    $color = '#66ff33';
		}
		print $fh " <th bgcolor=\"$color\" font size=\"1\">$model_location_path_last_updated</th>\n";
		
		
		#ModelTimeDiff:
		my $model_under_refresh_status = 'NA';
		my $model_under_refresh_color = 'white';
		my $now_in_seconds = time();
		my $model_creation_time_in_seconds = '';
		
		my $diff_time_period = 10800;
		
		if (-e $model_location_path) {
		    $model_creation_time_in_seconds =stat($model_location_path)->mtime;
		    #print "date now = $now_in_seconds\n";
		    #print "date model_creation_time_in_seconds = $model_creation_time_in_seconds\n";
		    my $diff = $now_in_seconds - $model_creation_time_in_seconds;
		    #print "date diff = $diff\n";
		    if (($diff < $diff_time_period) && (0 < $diff)) {
		        $model_under_refresh_color = 'yellow';
			$model_under_refresh_status = 'Model Updated in last 3 hours, please be patient!'		   
		    
		    } else {
		        $model_under_refresh_color = '#66ff33';
			$model_under_refresh_status = 'Model Update time bigger than 3 hours!'		   
		    }		    	    		    
		} else {
		    $model_under_refresh_status = 'Model Is NA';
		    $model_under_refresh_color = 'red';
		}
		print $fh " <th bgcolor=\"$model_under_refresh_color\" font size=\"1\">$model_under_refresh_status</th>\n";

		#ModelLinkOwner:		
		my $model_link_owner = 'NA';
		my $model_link_owner_color = 'red';
                if (-e $model_location_path) {
		    $model_link_owner =stat($model_location_path)->uid;    
		    #print "owner is $model_link_owner\n";
		    my $uid2owner_cmd = "/usr/bin/ypcat passwd | /bin/grep $model_link_owner | /usr/bin/tail -1";
		    @array_of_owner = split(/:/, `$uid2owner_cmd`);
		    #print (@array_of_owner);
		    $model_link_owner = $array_of_owner[0];
		    $model_link_owner_color = '#66ff33';
                }
		
		#print "=>$model_location_path owner is: $model_link_owner\n";
		print $fh " <th bgcolor=\"$model_link_owner_color\" font size=\"1\">$model_link_owner</th>\n";
		print $fh "</tr>\n";   		
	    }
	}
    }
        
    print $fh "</table><br>\n";  
    
    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b><li>In case You dont get results, you can check status by attach xls: <a href='$isamba_report_location_xls'>XlsPath</a> (use link in case not attach)</li>\n";
    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b><ol><li>Sheet1 - You have full log path and status, you can see if sesion is alive.</li>\n";
    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b><li>Sheet2 - Any redundent alias without a pre-defined session will listed there.</li></ol><br>\n";


    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b><li>Attach Up to date Status per Active/Loading/Used (Non Redundent Aliases) ; in case you see a #bar here, it means corner is disabled by FCT DA:</li><br>\n";

    #Print status per avail aliases (not redundent):
    #print $fh "<table border=\"1\">\n";
    #print $fh "<tr>\n";
    #print $fh " <th bgcolor=\"#D3D3D3\">Die</th>\n";
    #print $fh " <th bgcolor=\"#D3D3D3\">modelb/modela</th>\n";
    #print $fh " <th bgcolor=\"#D3D3D3\">Model</th>\n";
    #print $fh " <th bgcolor=\"#D3D3D3\">Corner</th>\n";
    #print $fh " <th bgcolor=\"#D3D3D3\">AllExpanded</th>\n";
    #print $fh " <th bgcolor=\"#D3D3D3\">Alias</th>\n";    
    #print $fh " <th bgcolor=\"#D3D3D3\">Host</th>\n";
    #print $fh " <th bgcolor=\"#D3D3D3\">HostSummaryStatus</th>\n";
    #print $fh " <th bgcolor=\"#D3D3D3\">HostSummaryStatusDate</th>\n";
    #print $fh " <th bgcolor=\"#D3D3D3\">LastSessionLogUpdateTime</th>\n";
    #print $fh "</tr>\n";      
    foreach my $die (sort keys %control_hash) {
        
	my $DIE = uc($die);
        print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b>${DIE}:</b></font><br>\n";
	
        print $fh "<table border=\"1\">\n";
        print $fh "<tr>\n";
        print $fh " <th bgcolor=\"#D3D3D3\">Die</th>\n";
        print $fh " <th bgcolor=\"#D3D3D3\">ModelB/ModelA</th>\n";
        print $fh " <th bgcolor=\"#D3D3D3\">Model</th>\n";
        print $fh " <th bgcolor=\"#D3D3D3\">Corner</th>\n";
        print $fh " <th bgcolor=\"#D3D3D3\">AllExpanded</th>\n";
        print $fh " <th bgcolor=\"#D3D3D3\">DA Direct Alias</th>\n"; 
	print $fh " <th bgcolor=\"#D3D3D3\">User Optional Alias</th>\n"; 
        print $fh " <th bgcolor=\"#D3D3D3\">Host</th>\n";
        print $fh " <th bgcolor=\"#D3D3D3\">HostSummaryStatus</th>\n";
        print $fh " <th bgcolor=\"#D3D3D3\">HostSummaryStatusDate</th>\n";
        print $fh " <th bgcolor=\"#D3D3D3\">LastSessionLogUpdateTime</th>\n";
        print $fh "</tr>\n";      
	
	foreach my $modela_modelb (sort keys %{$control_hash{$die}}) {
            foreach my $model  (sort keys %{$control_hash{$die}{$modela_modelb}}) {
	        foreach my $corner (sort keys %{$control_hash{$die}{$modela_modelb}{$model}}) {		
                    print $fh "<tr>\n";
		    my $color = 'white';
		    print $fh " <th bgcolor=\"$color\" font size=\"1\">$die</th>\n";
		    print $fh " <th bgcolor=\"$color\" font size=\"1\">$modela_modelb</th>\n";
		    print $fh " <th bgcolor=\"$color\" font size=\"1\">$model</th>\n";
		    print $fh " <th bgcolor=\"$color\" font size=\"1\">$corner</th>\n";
		    print $fh " <th bgcolor=\"$color\" font size=\"1\">$control_hash{$die}{$modela_modelb}{$model}{$corner}{current_corner_on_server}</th>\n";
		    if (exists $control_hash{$die}{$modela_modelb}{$model}{$corner}{alias}) {
                        $color = '#6699ff';
		        print $fh " <th bgcolor=\"$color\" font size=\"1\">$control_hash{$die}{$modela_modelb}{$model}{$corner}{alias}</th>\n";
		        print $fh " <th bgcolor=\"#dac292\" font size=\"1\">$control_hash{$die}{$modela_modelb}{$model}{$corner}{end_user_alias}</th>\n";
		    } else {
                        $color = 'red';
		        print $fh " <th bgcolor=\"$color\" font size=\"1\">NA</th>\n";		    
		        print $fh " <th bgcolor=\"$color\" font size=\"1\">NA</th>\n";	
		    }
		    $color = 'white';
		    print $fh " <th bgcolor=\"$color\" font size=\"1\">$control_hash{$die}{$modela_modelb}{$model}{$corner}{machine}</th>\n";
		    
		    #status from control hash:
		    my $status = "$control_hash{$die}{$modela_modelb}{$model}{$corner}{status}";
		    my $status_time_from_machine_host_log = "$control_hash{$die}{$modela_modelb}{$model}{$corner}{status_time_from_machine_host_log}";
		    
		    #status per corner:
		    #my $test_command_per_session_cmd = "$pt_client -m $corner_full_name -c 'get_dbs'";
		    #my $model_status_per_model_type_last_time_updated = "State File Not Available $control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type}";
		    my $model_status_per_model_type_last_time_updated = "Status File Not Available"; 
		    if (-e $control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type}) {		    
		        $model_status_per_model_type_last_time_updated = ctime(stat($control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type})->mtime);
		    }
		    my $status_format = $format_red;
		    if ($status =~ /UP and UPDATED/) {
		        $color = '#66ff33';
		    } elsif ($status =~ /LOADING/) {
		        $color = 'yellow';
		    } else {
		        $color = 'red';
                    }
 		    print $fh " <th bgcolor=\"$color\" font size=\"1\">$status</th>\n";
		    
		    
		    $color = 'white';
		    print $fh " <th bgcolor=\"$color\" font size=\"1\">$status_time_from_machine_host_log</th>\n";
		    if ($model_status_per_model_type_last_time_updated =~ /Status File Not Available/) {
		        $color = 'red';
		    } else { 
		        $color = '#66ff33';
		    }
		    
		    if (-e $control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type}) {    
                        my $unix_path = "$control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type}";
			my $isamba_prefix = '//sc8-samba.sc.intel.com';
			$unix_path_to_windows = "$isamba_prefix" . "$unix_path";
			#print "check1 unix_path_to_windows = $unix_path_to_windows\n";
			$unix_path_to_windows =~ s/\//\\/g;
			$unix_path_to_windows =~ s/\\\\/\\/g;	
			$unix_path_to_windows =~ s/^\\/\\\\/g;			
			#print "check2 unix_path_to_windows = $unix_path_to_windows\n";
			
			print $fh " <th bgcolor=\"$color\" font size=\"1\"><a href='$unix_path_to_windows'>$model_status_per_model_type_last_time_updated</a></th>\n";		    
		    } else {
		        print $fh " <th bgcolor=\"$color\" font size=\"1\">$model_status_per_model_type_last_time_updated</th>\n";
		    }
		    
		    print $fh "</tr>\n";
		    
		    #Add current data under control_hash_per_host:
		    my $host = "$control_hash{$die}{$modela_modelb}{$model}{$corner}{machine}";
		    my $full_name = "$control_hash{$die}{$modela_modelb}{$model}{$corner}{current_corner_on_server}";
		    $control_hash_per_host{$host}{$full_name}{status} = $status;
		    $control_hash_per_host{$host}{$full_name}{status_time_from_machine_host_log} = $status_time_from_machine_host_log;
		    $control_hash_per_host{$host}{$full_name}{die} = $die;
		    $control_hash_per_host{$host}{$full_name}{modela_modelb} = $modela_modelb;
		    $control_hash_per_host{$host}{$full_name}{corner} = $corner;
		    $control_hash_per_host{$host}{$full_name}{model} = $model; 
		    if (exists $control_hash{$die}{$modela_modelb}{$model}{$corner}{alias}) {
		        $control_hash_per_host{$host}{$full_name}{alias} = $control_hash{$die}{$modela_modelb}{$model}{$corner}{alias};
                    } else {
		        $control_hash_per_host{$host}{$full_name}{alias} = 'NA';
		    }
		    if (exists $control_hash{$die}{$modela_modelb}{$model}{$corner}{end_user_alias}) {
		        $control_hash_per_host{$host}{$full_name}{end_user_alias} = $control_hash{$die}{$modela_modelb}{$model}{$corner}{end_user_alias};
                    } else {
		        $control_hash_per_host{$host}{$full_name}{end_user_alias} = 'NA';
		    }	    
		    if (-e $control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type}) {
                        $control_hash_per_host{$host}{$full_name}{model_status_per_model_type_log_time_stamp} = ctime(stat($control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type})->mtime);
		    } else {
		        $control_hash_per_host{$host}{$full_name}{model_status_per_model_type_log_time_stamp} = "Status File Not Available";
		    }
		    
		    
	        }
            }
	}
        print $fh "</table><br>\n"
    }
    
    
    #Print Load time delay status foreach server:	
    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b><li>For Models in <u>Loading Status</u> - Attach Up to date Load Time:</li>\n";       
    print $fh "<table border=\"1\">\n";
    print $fh "<tr>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Die</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">ModelB/ModelA</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Model</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Corner</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">AllExpanded</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Alias</th>\n";    
    print $fh " <th bgcolor=\"#D3D3D3\">Host</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">CurrentTimeAt</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">LoadFileStartedAt</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">TimeInLoadPhase</th>\n";
    print $fh "</tr>\n";      
    foreach my $die (sort keys %control_hash) {
	foreach my $modela_modelb (sort keys %{$control_hash{$die}}) {
            foreach my $model  (sort keys %{$control_hash{$die}{$modela_modelb}}) {
	        foreach my $corner (sort keys %{$control_hash{$die}{$modela_modelb}{$model}}) {
		    if ($control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type_loading_file} eq 'NA') {
		        next;
		    } else {    		    
                        print $fh "<tr>\n";
                        my $color = 'white';
                        print $fh " <th bgcolor=\"$color\" font size=\"1\">$die</th>\n";
                        print $fh " <th bgcolor=\"$color\" font size=\"1\">$modela_modelb</th>\n";
                        print $fh " <th bgcolor=\"$color\" font size=\"1\">$model</th>\n";
                        print $fh " <th bgcolor=\"$color\" font size=\"1\">$corner</th>\n";
                        print $fh " <th bgcolor=\"$color\" font size=\"1\">$control_hash{$die}{$modela_modelb}{$model}{$corner}{current_corner_on_server}</th>\n";
                        if (exists $control_hash{$die}{$modela_modelb}{$model}{$corner}{alias}) {
                            $color = '#6699ff';
		            print $fh " <th bgcolor=\"$color\" font size=\"1\">$control_hash{$die}{$modela_modelb}{$model}{$corner}{alias}</th>\n";
		        } else {
                            $color = 'red';
		            print $fh " <th bgcolor=\"$color\" font size=\"1\">NA</th>\n";		    
		        }
			$color = 'white';
			print $fh " <th bgcolor=\"$color\" font size=\"1\">$control_hash{$die}{$modela_modelb}{$model}{$corner}{machine}</th>\n";
			my $loading_file_time = $control_hash{$die}{$modela_modelb}{$model}{$corner}{model_status_per_model_type_loading_file_time};
			my $loading_file_time_ctime = ctime($loading_file_time); 			
			my $current_time = time();
			my $current_time_cmtime = ctime($current_time);
			my $current_time_minus_loading_file_time = sprintf '%.2f', ($current_time - $loading_file_time) / 60;			
			print $fh " <th bgcolor=\"$color\" font size=\"1\">$current_time_cmtime</th>\n";
		        print $fh " <th bgcolor=\"$color\" font size=\"1\">$loading_file_time_ctime</th>\n";			
		        print $fh " <th bgcolor=\"yellow\" font size=\"1\">$current_time_minus_loading_file_time minutes</th>\n";
                        print $fh "<tr>\n";
		    }
	        }
            }
	}			
    }
    
    print $fh "</li></ul><br>\n"; 
    print $fh "</table></li></ul><br>\n";  


    if ($ENV{DEBUG_MODE}) {
        print "-I- printing control_hash_per_host - check7 - now - begin:\n";
        print Dumper (\%control_hash_per_host);
        print "-I- printing control_hash_per_host - check7 - now - end:\n";
    }


    #Print status per host:
    print $fh "<font size=\"2\" color=\"green\" face=\"Tahoma\"><b><u>DA - Short How To (ALERT: LNL HARDCODING! **0** MACHINES AVAIL!!!): </b></u></font><br><br>\n";

    #Print status per host based on ion priority:
    my $ionCapacityHashSize = keys %ionCapacityStatusForPtShellHash;
    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b>1. Status per host: How To?</b></font><br><br>  Which Machines do we have in pt server pool?: <br> <ul><li>In total we have <font font size=\"2\" color=\"green\">$ionCapacityHashSize</font> machines here!</li><li>Search for Red items for NA machine:\n"; 
    
    #Print status per model in case such model linked:
    print $fh "<table border=\"1\">\n";
    print $fh "<tr>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Host</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Status</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Resource Group</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Last Updated At?</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Do We Use It?</th>\n";
    print $fh "</tr>\n";   
    
    #CTH2 List of Host:
    foreach my $host (sort keys %ionCapacityStatusForPtShellHash) {
        #unless (exists $listOfHosts{$host} && $listOfHosts{$host} == 1) {next} ;
	print "host = $host\n";
        my $status = $ionCapacityStatusForPtShellHash{$host}{status};
	my $resourceGroups = $ionCapacityStatusForPtShellHash{$host}{resourceGroups};
        my $color = "white";
        print $fh "<tr>\n";
        print $fh " <th bgcolor=\"$color\" font size=\"1\">$host</th>\n";
        if ($status =~ /(Accepting|Running)/) {
            $color = "#66ff33"; 
        } else {
            $color = "red";
        }
        print $fh " <th bgcolor=\"$color\" font size=\"1\">$status</th>\n";	
        $color = 'white';
        if ($resourceGroups eq 'suel12_special.bc.ptshell_tool') {
	    $color = "blue"; 
        } elsif ($resourceGroups eq 'suel11_special.ptshell_tool') {
            $color = "#00cc99"; 
        } else {
	    $color = "red"; 
	}
        print $fh " <th bgcolor=\"$color\" font size=\"1\">$resourceGroups</th>\n";		
        
	
	if ((exists $machine_hash{$host}) && (exists $machine_hash{$host}{time_stamp_per_log})) {
	    $color = "white";
	    print $fh " <th bgcolor=\"$color\" font size=\"1\">$machine_hash{$host}{time_stamp_per_log}</th>\n";	
	} else {
	    $color = "white";
	    print $fh " <th bgcolor=\"$color\" font size=\"1\">Not Available (host not used)</th>\n";
	}
	
	
	$color = "white";
        if (exists $machine_hash{$host}) {
	    print $fh " <th bgcolor=\"#6699ff\" font size=\"1\">$machine_hash{$host}{status_per_machine}</th>\n";
	} else {
	    print $fh " <th bgcolor=\"#00ff00\" font size=\"1\">Not Used by $ENV{USER} - Host is Empty</th>\n";
	}
	print $fh "</tr>\n";   
    }
    print $fh "</table></li></ul><br>\n";  


    #Print status per host per model by name:

    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b>2. Attach Up to date Status per Host Per Active/Loading/Used:<br>\n";
    
    #Print status per avail aliases (not redundent):
    print $fh "<table border=\"1\">\n";
    print $fh "<tr>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Host</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">AllExpanded</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Die</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">ModelB/ModelA</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Model</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Corner</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">DA Direct Alias</th>\n"; 
    print $fh " <th bgcolor=\"#D3D3D3\">User Optional Alias</th>\n"; 
    print $fh " <th bgcolor=\"#D3D3D3\">HostSummaryStatus</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">HostSummaryStatusDate</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">LastSessionLogUpdateTime</th>\n";
    print $fh "</tr>\n";      

    foreach my $host (sort keys %control_hash_per_host) {   
        foreach my $full_name (sort keys %{$control_hash_per_host{$host}}) {
            my $status                            = $control_hash_per_host{$host}{$full_name}{status};
            my $status_time_from_machine_host_log = $control_hash_per_host{$host}{$full_name}{status_time_from_machine_host_log};
	    my $die	                          = $control_hash_per_host{$host}{$full_name}{die};
	    my $modela_modelb                     = $control_hash_per_host{$host}{$full_name}{modela_modelb};
	    my $corner                            = $control_hash_per_host{$host}{$full_name}{corner};
	    my $model                             = $control_hash_per_host{$host}{$full_name}{model};
            my $alias                             = $control_hash_per_host{$host}{$full_name}{alias};
            my $end_user_alias                    = $control_hash_per_host{$host}{$full_name}{end_user_alias};
	    my $model_status_per_model_type_log_time_stamp = $control_hash_per_host{$host}{$full_name}{model_status_per_model_type_log_time_stamp}; 
 
            my $color = "white";
            print $fh "<tr>\n";	    
	    
	    if ($status =~ /UP and UPDATED/) {
	        $color = '#66ff33';
	    } elsif ($status =~ /LOADING/) {
		$color = 'yellow';
	    } else {
	        $color = 'red';
            }	  
            print $fh " <th bgcolor=\"$color\" font size=\"1\">$host</th>\n";
	    $color = 'white';
            print $fh " <th bgcolor=\"$color\" font size=\"1\">$full_name</th>\n";
            print $fh " <th bgcolor=\"$color\" font size=\"1\">$die</th>\n";
            print $fh " <th bgcolor=\"$color\" font size=\"1\">$modela_modelb</th>\n";	
            print $fh " <th bgcolor=\"$color\" font size=\"1\">$model</th>\n";
            print $fh " <th bgcolor=\"$color\" font size=\"1\">$corner</th>\n";

            if ($alias ne 'NA') {
                $color = '#6699ff';
            } else {
                $color = 'red';
	    }
	    print $fh " <th bgcolor=\"$color\" font size=\"1\">$alias</th>\n";
	    print $fh " <th bgcolor=\"#dac292\" font size=\"1\">$end_user_alias</th>\n";
	    
	    
	    if ($status =~ /UP and UPDATED/) {
	        $color = '#66ff33';
	    } elsif ($status =~ /LOADING/) {
		$color = 'yellow';
	    } else {
	        $color = 'red';	    
            }	  	    
	    print $fh " <th bgcolor=\"$color\" font size=\"1\">$status</th>\n";
	    $color = 'white';
	    print $fh " <th bgcolor=\"$color\" font size=\"1\">$status_time_from_machine_host_log</th>\n";	
            if ($model_status_per_model_type_log_time_stamp =~ /Status File Not Available/) {
	        $color = 'red';
            } else { 
                $color = '#66ff33';
            }
	    print $fh " <th bgcolor=\"$color\" font size=\"1\">$model_status_per_model_type_log_time_stamp</th>\n";
	    print $fh "</tr>\n";
	
        }
    
    
    
    }
    print $fh "</table><br>\n";


    #Print status per host:
    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b>3. Machine status: <br> <ul><li>Search for Red items == when we have a corner that is down</li></ul>\n"; 
    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b></font>  Real Memory Status - First Priority (512G/16C Machines): <br> <ul><li><font color=\"red\">Red:</font> Low Physical Memory</li><li><font color=\"yellow\">Yellow</font>: Close to Memory Margin, may need to evacuate 1 corner here</li><li><font color=\"#66ff33\">Green</font>: Enough Margin in Physical Memory, you may add one more corner</li></ul>\n";
    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b></font>  Targets - Second Priority: <br> <ul><li>Having FreeRealMem above 65G</li><li>Having FreeReal[%] over 20% </li><li>No Utilization over FreeVirtual Memory</li></ul><br>\n";
    
    #Print status per host:

    print $fh "<table border=\"1\">\n";
    print $fh "<tr>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Host</th>\n";
    print $fh " <th bgcolor=\"#D3D3D3\">Utilization</th>\n";
    print $fh " <td bgcolor=\"#D3D3D3\">MachineStat</td>\n";
    print $fh " <td bgcolor=\"#D3D3D3\">FreeRealMem</td>\n";
    print $fh " <td bgcolor=\"#D3D3D3\">TotalRealMem</td>\n";
    print $fh " <td bgcolor=\"#D3D3D3\">FreeReal[%]</td>\n";
    
    print $fh " <td bgcolor=\"#D3D3D3\">FreeVirtualMem</td>\n";
    print $fh " <td bgcolor=\"#D3D3D3\">TotalVirtualMem</td>\n";  
    print $fh " <td bgcolor=\"#D3D3D3\">FreeVirtual[%]</td>\n";
    
    print $fh " <td bgcolor=\"#D3D3D3\">CPUs</td>\n";
    print $fh " <td bgcolor=\"#D3D3D3\">MHz</td>\n";
    print $fh " <td bgcolor=\"#D3D3D3\">MissingServers</td>\n";
    print $fh "</tr>\n";

    my $count = 0;
    foreach my $machine (sort keys %machine_hash) {   
        $count++;  
	$msg = '.' x $count;
        print "-I- checking $machine for load status from EC ([$count] machine in total)$msg\n";

	my ($Status,$fRM,$fVM,$tRM,$tVM,$CPUCount,$CPUMhz)  = &ParseIONStatusNew($machine);
	my ($fRM_div,$fVM_div,$tRM_div,$tVM_div) = ($fRM /= 1000,$fVM /= 1000,$tRM /= 1000,$tVM /= 1000);
        print $fh "<tr>\n";
        print $fh " <td bgcolor=\"#D3D3D3\">$machine</td>\n";
        
	my $total_status = "$machine_hash{$machine}{status_per_machine}";
	$total_status =~ m/Total = (.*)\/(.*) servers are UP/;
	if ($1 ne $2) {
	    print $fh " <td bgcolor=\"#FF0000\">$total_status</td>\n";
	} else {
            print $fh " <td bgcolor=\"#00FF7F\">$total_status</td>\n";
	}
	
	if ($Status =~ /Accepting/ || $Status =~ /Running/) {
	    print $fh " <td bgcolor=\"#33cc33\">$Status</td>\n";
	} else {
	    print $fh " <td bgcolor=\"#cc6699\">$Status</td>\n";
	}
	
	
        my $color = &DecideColorFreeMemory($fRM_div);
	print $fh " <td bgcolor=\"$color\">$fRM_div</td>\n";
		
        my $color = &DecideColorDefault($tRM_div);
	print $fh " <td bgcolor=\"$color\">$tRM_div</td>\n";
		
	my $color = &DecideFreePrecentage($fRM,$tRM);
        my $FreePrecentage = 0;
        if ($tRM != 0) {
           $FreePrecentage = ($fRM / $tRM) * 100;
        }
	
        $var = sprintf '%.2f', $FreePrecentage;
	print $fh " <td bgcolor=\"$color\">${var}%</td>\n";

        my $color = &DecideColorDefault($fVM_div);
	print $fh " <td bgcolor=\"$color\">$fVM_div</td>\n";

        my $color = &DecideColorDefault($tVM_div);
	print $fh " <td bgcolor=\"$color\">$tVM_div</td>\n";
	
	my $color = &DecideFreePrecentage($fVM,$tVM);
        my $FreePrecentage = 0;
        if ($tVM != 0) {
	   $FreePrecentage = ($fVM / $tVM) *100;
        }
        $var = sprintf '%.2f', $FreePrecentage;
	$var = sprintf '%.2f', $FreePrecentage;
	print $fh " <td bgcolor=\"$color\">${var}%</td>\n";
	
	
	
	
	print $fh " <td>$CPUCount</td>\n";
	print $fh " <td>$CPUMhz</td>\n";
	print $fh " <td>$missing_servers_per_host{$machine}</td>\n";
        print $fh "</tr>\n";
    }   
    print $fh "</table><br><br>\n";
    
    #print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b>3. Contacts: pragermo,ogivol,yifrach.</b></font><br><br>\n";

    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b> Have great time while budgeting!</b></font><br><br>\n";

    print $fh "<font size=\"2\" color=\"black\" face=\"Tahoma\"><b>Thank You, Have a great day!</b></font><br><br>\n";

    print $fh "<font size=\"2\" color=\"blue\" face=\"Tahoma\"><b>Thanks,<br>\n";
    print $fh "<font size=\"2\" color=\"blue\" face=\"Tahoma\"><b>Ohad Givol | CDG BE Integration DA | &#9743 Phone: 972-73-3374-024 | &#9743 iNET 8-3374-024 | ohad.givol\@intel.com</b></font><br>\n";
    print $fh "&#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409 &#129409<br>\n";

    print $fh "</html>\n";
  
close ($fh);

#opening aliases file for reading:PT_Server_Status_Time
if ($no_mail) {
    print "-I- Main: Mail status: no_mail = $no_mail, flow will skip mail to relevant list...\n";
} else {
    print "-I- Main: Mail status: no_mail = $no_mail, flow will create mail to relevant list...\n";
    SendReleaseMail("$root_log/report.xls");
}


print "-I- Your results are here: $isamba_report_location\n";


print "-I- ByeBye!\n";



sub SendReleaseMail {
    my ($FinalReportXLS) = @_;
    my $HtmlMailScript = "${root}/HtmlReleaseMail.py";

    #my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    #$year += 1900;
    
    #my @abbr = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    #my $month = "$abbr[$mon]";
    #my $date = "@ ${year}_${month}_${mday} at ${hour}_${min}_${sec}";
    my $date = `date`;
    chomp($date);
    my $HtmlHeader = "$root_log/report.html";
          
    ###my $to_list = 'pragermo,ogivol,adahary,nadavcoh,zzoulty,yifrach,bnevo,napelste,nbennoon,skashi,yanivkat,mpollack,roneny';
    my $to_list = 'ogivol';
	
    my $MailSubject = "'CDG BE Integration DA | PT Server | ${date} | Central Status Update'";
    my $cmd = "$HtmlMailScript $to_list $ENV{USER} $MailSubject $HtmlHeader $FinalReportXLS";
    if ($ENV{DEBUG_MODE}) {
        print "-I- HtmlSendReleaseMail: Mail cmd = '$cmd'\n";
    }
    print "-I- Sending now mail to $ENV{USER}, Please be patient, it will arrive, depends on servers.\n";
    print "-I- All of your main reports are here:\n";
    print "-I- 1) xls summary: $FinalReportXLS\n";

    system($cmd);
}   

sub ParseIONStatusNew {
    my ($host) = @_;
    my $cmd = "/usr/intel/bin/nbstatus work --target sc8_interactive --fi Status,fRM,fVM,tRM,tVM,CPUCount,CPUMhz --fo script \"server=='${host}'\" ";
    my $results = `$cmd`; 
    chomp($results);
    #print "results = '$results'   \n";
    
    ($Status,$fRM,$fVM,$tRM,$tVM,$CPUCount,$CPUMhz) = split(',',$results); 
    
    return ($Status,$fRM,$fVM,$tRM,$tVM,$CPUCount,$CPUMhz);
} 


#Appendix:

    # red :   #FF0000
    # green:  #99cc00 #33cc33 
    # blue:   #66ccff
    # brown:  #cc6699
    # yellow: #ffff00

sub DecideColorFreeMemory {
    my ($MemUsed) = @_;
    #Coloring:   0<mem<40: red       - risk to outage
    #Coloring:   40<mem<100: gold    - no issue
    #Coloring:   100<mem: green blue - may have some space
    #Coloring:   500<mem: light blue - total memory
    if ((0 < $MemUsed) && ($MemUsed < 65)) {
        return '#FF0000';
    } elsif ((65 < $MemUsed) && ($MemUsed < 100)) {
       return '#ffff00';
    } elsif (100 < $MemUsed) {
       return '#33cc33';
    } else {
      return '#cc6699';
    }
}

sub DecideColor {
    my ($MemUsed) = @_;
    #Coloring:   0<mem<40: red       - risk to outage
    #Coloring:   40<mem<100: gold    - no issue
    #Coloring:   100<mem: green blue - may have some space
    #Coloring:   500<mem: light blue - total memory
    if ((0 < $MemUsed) && ($MemUsed < 40)) {
        return '#FF0000';
    } elsif ((100 < $MemUsed) && ($MemUsed < 300)) {
       return '#99cc00';
    } elsif (300 < $MemUsed) {
       return '#66ccff';
    } else {
      return '#cc6699';
    }
}

sub DecideFreePrecentage {
    my ($MemUsed,$MemTotal) = @_;
    #Coloring:   0<mem<15: red      - severe risk to outage
    #Coloring:   15<mem<30: gold    - getting closer to an issue with memory
    #Coloring:   30<mem: green      - have some space
    #Coloring:   100<mem: brown     - total memory; escapee
    my $div = 0;
    if ($MemTotal != 0) {
       $div = ($MemUsed / $MemTotal) * 100;
    }
    if ((0 < $div) && ($div < 15)) {
        return '#FF0000';
    } elsif ((15 < $div) && ($div < 20)) {
       return '#ffff00';
    } elsif ((20 < $div) && ($div < 100)) {
       return '#33cc33';
    } else {
      return '#cc6699';
    }
}

sub DecideColorDefault {
    my ($Mem) = @_;
    #Coloring:   0<mem<15: red       - risk to outage
    #Coloring:   15<mem<30: gold     - no issue
    #Coloring:   30<mem: green blue  - may have some space
    #Coloring:   500<mem: light blue - total memory
    return '#FFFFFF';
}

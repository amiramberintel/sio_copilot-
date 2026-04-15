#!/usr/intel/bin/perl

use Data::Dumper;
use strict;
use Getopt::Long;
use Cwd qw(abs_path);

my $scriptInfo = "
   pt_server_supervisor.pl

   Arguments to the script:

      -config <config_file>   :  pt servers file
      [-debug]                :  Print debugging messages (Default: FALSE). 
      [-log]                  :  Log file    #usually we not provide it to avoid massive prints here
      [-help]                 :  Print help and exit.
";


my ($ref, $run, $out, $corner, $log_file, $help, $config_file, $log_file);
our $DEBUG; # Default: no debug messages displayed.
our ($run_corner, $ref_corner);
GetOptions(
    "debug"     => \$DEBUG,
    "config=s"  => \$config_file,
    "log=s"     => \$log_file,
    "h|help"    => \$help
) || die("-E- Wrong Command Line Argument\n");

my $required = ($config_file); # TRUE if the required items are entered
if (($help) || (! $required))  { # User wants script info printed, or did not enter mandatory items
   if (! $help) {
      print ("\n-I- Usage Error. Please read the manual carefully:");
   }
   print("-I- $scriptInfo");
   exit;
}


our %servers_DB;
our $pt_server_dir;
our $pt_server_model_status_per_server;
our $pt_server_model_link;
our $pt_server_model_status_per_model_type;
#our $pt_server_tmp_disk;

my %machine_load;
my %wrong_syntax_server;

open (my $FH, "<", $config_file);
while (my $line = <$FH>) {
   chomp($line);
   if ($line =~ /^\s*#/ && $line !~ /^\s*##/ && $line !~ /set pt_server/) {
      $line =~ s/#//g;
      my ($model,$type,$corner,$modelb_or_modela,$process,$machine,$socket) = split(/,/, $line);
      #$servers_DB{$model}{$type}{$corner}{$modelb_or_modela} = $machine;
      $servers_DB{$model}{$type}{$corner}{$modelb_or_modela}{process} = $process;
      $servers_DB{$model}{$type}{$corner}{$modelb_or_modela}{machine} = $machine;
      my $server_name;
      $server_name = $modelb_or_modela . "_" . $model . "_" . $type . "_" . $corner;
      if ($machine eq "") {
         $wrong_syntax_server{$server_name}{'machine'} = 1;
      }
      if ($socket eq "") {
         $wrong_syntax_server{$server_name}{'socket'} = 1;
      }
      $machine_load{$machine}{$server_name} = 0;
   }
   if ($line =~ /set\s+pt_server_dir\s+(\S+)/) {
      $pt_server_dir = $1;
   }
   
   if ($line =~ /set\s+pt_server_model_status_per_server\s+(\S+)/) {
      $pt_server_model_status_per_server = $1;
   }
   
   if ($line =~ /set\s+pt_server_model_link\s+(\S+)/) {
      $pt_server_model_link = $1;
   }
   if ($line =~ /set\s+pt_server_model_status_per_model_type\s+(\S+)/) {
      $pt_server_model_status_per_model_type = $1;
   }   
   
   #if ($line =~ /set\s+pt_server_tmp_disk\s+(\S+)/) {
   #   $pt_server_tmp_disk = $1;
   #}  
    
}

print "-I- Your values are:\n";
print "-I- Your values: pt_server_dir => $pt_server_dir\n";
print "-I- Your values: pt_server_model_status_per_server => $pt_server_model_status_per_server\n";
print "-I- Your values: pt_server_model_link => $pt_server_model_link\n";
print "-I- Your values: pt_server_model_status_per_model_type => $pt_server_model_status_per_model_type\n";
#print "-I- Your values: pt_server_tmp_disk => $pt_server_tmp_disk\n";

print Dumper(\%servers_DB);

my $my_machine = $ENV{HOST};
$log_file = $pt_server_model_status_per_server . "/" . "pt_server_${my_machine}.log" unless ($log_file);
print "-I- Your log file for current session is: $log_file\n" if ($ENV{DEBUG_MODE});
open (our $LOG_FH , ">" , $log_file);

foreach my $server_name (keys %wrong_syntax_server) {
   foreach my $missing_field (keys %{$wrong_syntax_server{$server_name}}) {
      print $LOG_FH "Wrong syntax found in config file : $missing_field is missing for server $server_name\n";
   }
}

print Dumper(\%wrong_syntax_server);

my $groups = `groups`;
print $LOG_FH "groups = $groups\n";

# Removing old temp files on this machine 
print $LOG_FH "Cleaning /tmp directory\n";
`/bin/rm -rf /tmp/*$ENV{USER}*`;
`/bin/rm -rf /tmp/.SCI*`;
#`rm -rf /tmp/libraryHash.cache.*`;
#print $LOG_FH "removing old temp files (more than 3 days ago)\n";
#my $tmp_dir_format = "/tmp/.SCI*";
#foreach my $tmp_dir (`/bin/ls -d $tmp_dir_format 2>/dev/null`) {
#   chomp($tmp_dir);
#   my $tmp_dir_timestamp = `date -r $tmp_dir '+%s'`;
#   my $now_timestamp =`date '+%s'`;
#   my $duration = ($now_timestamp - $tmp_dir_timestamp) / (60*60*24);
#   $duration = sprintf('%.2f', $duration);
#   my $days_to_keep_dir = 1.5;
#   if ($duration > $days_to_keep_dir) {
#      print $LOG_FH "remove temp directory $tmp_dir (before $duration days)\n";
#      `rm -rf $tmp_dir`;
#   }
#}
# 

print "-I- Here\n";
foreach my $model (keys %servers_DB) {
   foreach my $type (keys %{$servers_DB{$model}}) {
       foreach my $corner (keys %{$servers_DB{$model}{$type}}) {
	  foreach my $modelb_or_modela (keys %{$servers_DB{$model}{$type}{$corner}}) {
	      #my $machine = $servers_DB{$model}{$type}{$corner}{$modelb_or_modela};
	      my $machine = $servers_DB{$model}{$type}{$corner}{$modelb_or_modela}{machine};
	      my $process = $servers_DB{$model}{$type}{$corner}{$modelb_or_modela}{process};
	      next unless ($machine eq $my_machine);
              my $stop_server_processes = 0;
              my $setup_server_flag = 0;
              my $refresh_server_flag = 0;
              my $terminate_server_flag = 0;
              my $model_link = $pt_server_model_link . "/" . $modelb_or_modela . "_" . $model . "_" . $type;
	      print "-I- Your model link is : $model_link\n";
	      my $block = get_block_name($model_link);
	      #my $block = "soc";
	      print "-I- Test area: Your block is $block\n";
	      my $session_link = $model_link . "/runs/${block}/${process}/sta_pt/" . $corner . "/outputs/" . $block . ".pt_session." . $corner . "/";
              print "-I- checking existance of $session_link\n";
	      if (-e $session_link) { 
	          print "-I- AAA: session_link = $session_link\n";		  
	      } else {
                  #FallBack to hdk convention:
	          $block = "soc";
		  $session_link = $model_link . "/primetime/" . $corner . "/dbs/" . $block . "." . $corner . ".analyze_design/";
		  print "-I- BBB: session_link = $session_link\n";
              }
	      my $model_dir = abs_path($model_link);
              my $session_dir = abs_path($session_link);
              my $model_type = $modelb_or_modela . "_" . $model . "_" . $type;	      
              my $server_name = $model_type . "_" . $corner;
	      print $LOG_FH "\nchecking server: $server_name - ";             
	      my @server_processes_numbers = get_server_processes($server_name);
	      print "-I- For server_name : $server_name found attach process: @server_processes_numbers\n";
	      if (scalar(@server_processes_numbers) > 1) {
              # more than one process for this server -> overload -> kill processes
                 print $LOG_FH "server $server_name is OVERLOADED !!\n";
                 $stop_server_processes = 1;
                 $setup_server_flag = 1;
              } else { # no process overload found
                  
		  print $LOG_FH "(process: $server_processes_numbers[0]) - "; 
                  my $output = `$pt_server_dir/pt_client.pl -m $server_name -c "current_design"`;
                  if ($output =~ /OFFLINE/) {
                      print $LOG_FH "server $server_name is OFFLINE !!\n";
                      $setup_server_flag = 1;
                  } elsif ($output =~ /does not exist/) {
                      print $LOG_FH "server $server_name is not included inside: $pt_server_dir/pt_server_cron.cfg  !!\n";
                  } elsif ($output =~ /LOADING/) {
                      my $loading_file = "$pt_server_model_status_per_model_type/${server_name}.loading";
                      my $loading_file_timestamp = `date -r $loading_file '+%s'`;
                      my $now_timestamp =`date '+%s'`;
                      my $loading_duration = ($now_timestamp - $loading_file_timestamp) / 60; # duration in minutes
                      $loading_duration = sprintf('%.2f', $loading_duration);
		      #if load time takes too much time we will re-load again:
		      if (scalar(@server_processes_numbers) == 0) {
                         `rm -f $loading_file`;
                         print $LOG_FH "server $server_name is OFFLINE !! (although loading file exists, no server process found)\n";
                         $setup_server_flag = 1;
		      } elsif ($loading_duration > 150) {
                         `rm -f $loading_file`;
                         print $LOG_FH "server $server_name is OFFLINE !! (loading takes too long : $loading_duration minutes)\n";
                         $setup_server_flag = 1;
                      } else {
                         print $LOG_FH "server $server_name is LOADING !!\n";           
		      }
                  } elsif ($output =~ /DES-071/) { 
                      print $LOG_FH "server $server_name is NOT LINKED\n";
                      $terminate_server_flag = 1;
                      $setup_server_flag = 1;
                  } else { #server is up and linked
		      
		      $output = `$pt_server_dir/pt_client.pl -m $server_name -c "get_dbs"`; 
                      #server_session_dir will hold the actual server which is live and running under pt_client.pl:
		      my $server_session_dir;
                      foreach my $line (split(/\n/, $output)) {
                         if ($line =~ /-I- dbs_real is: \'(.+)\'/) {
                            $server_session_dir = $1;
                         }
                      }
		      #session_dir will hold expected path / link for the model:
                      if ($server_session_dir ne $session_dir) { # The link was refreshed
			 if (-d $session_dir) {
			    print $LOG_FH "server $server_name is NOT UPDATED: link of server was updated, will try reloading !!\n";
                            print $LOG_FH "old = $server_session_dir\n";
                            print $LOG_FH "new = $session_dir\n";
                            #Kill current pid and setup_server from scracth
			    $refresh_server_flag = 1; 
		         } else {
			    print $LOG_FH "server $server_name is NOT UPDATED: session path NA. Cant refresh !!\n";		 
                            print $LOG_FH "remove old job pid's (old sessions) for model_type = $server_name:\n";
                            remove_redundant_specific_server($server_name);
			 }
                      } else {
                         #if we reach here, the server is alive and all is fine:
			 print $LOG_FH "server $server_name is UP and UPDATED !!\n";
                         $machine_load{$machine}{$server_name} = 1;
                         # *_pt.log files tend to become very big so we empty them, but remain them exist
                         my $log_per_server = "$pt_server_model_status_per_model_type/${server_name}_pt.log";
                         #`cp /dev/null $log_per_server`;
                      
		      }
                  }
              }
              if ($stop_server_processes) {   
                 print $LOG_FH "stop server processes\n";
                 foreach my $process_number (@server_processes_numbers) {
                    print "kill -9 $process_number\n";
                    `kill -9 $process_number`;
                 }
              }
              if ($terminate_server_flag) {
                  `$pt_server_dir/pt_client.pl -m $server_name -c "terminate"`;         
              }
              if ($setup_server_flag) {
                 print $LOG_FH "setup server $server_name... \n";
                 #Assure no duplicated servers are avail (for example - change of socket id), here we will remove first old socket and then will creat it:
		 remove_redundant_specific_server($server_name);
		 #Trigger server setup based on below function in case server is NA:
		 setup_server($server_name, $model_type ,$corner, $pt_server_dir, $model_dir, $session_link, $log_file);  
              } else {
	         #print "setup server $server_name... xxxxxxxxxxxx is N/A\n";
	      }
	      
              if ($refresh_server_flag) {
                 my $missing_session_sign = "${pt_server_model_status_per_model_type}/session_of_${server_name}_is_missing";
                 #In case the server_name session_dir (new directory) is not available, missing will be added here, else flow will kill current pid for this server and re-load it:
		 if (! -d $session_dir) {
                     print $LOG_FH "New session does not exist in : $session_dir\n";
                     print $LOG_FH "Server will not be refreshed\n";
                     if (! -f $missing_session_sign) { 
                         `/bin/touch $missing_session_sign`;
                         # send mail with missing session notification
                         my $send_to_user = $ENV{USER};
                         print $LOG_FH "send mail with missing session notification to: $send_to_user\n";
                         #`echo "Server: $server_name \nSession is missing : $session_dir" | mail $send_to_user -s "PT server - Session is missing"`;
                     }
                     next;
                 }
                 print $LOG_FH "refresh server $server_name...";
		 my $log_per_server = "${pt_server_model_status_per_model_type}/${server_name}_pt.log";
		 print "clear old data and keep writing to: $log_per_server\n";
		 #`cp /dev/null  $log_per_server`;
		 #print "running now command: $pt_server_dir/pt_client.pl -m $server_name -c force_refresh\n";
                 #`$pt_server_dir/pt_client.pl -m $server_name -c "force_refresh"`;
		 
		 #kill current pid:
		 print "-I- remove old job pid's (old sessions) for model_type = $server_name:\n";
		 remove_redundant_specific_server($server_name);
		 #setup_server from scracth:
		 print "-I- setup new server (based on setup_server) command for new session:";
                 setup_server($server_name, $model_type ,$corner, $pt_server_dir, $model_dir, $session_link, $log_file);

              }      
          }
       }
   }
}

if ($ENV{DEBUG_MODE}) {
    print "-I- Machine Load Hash Printing : machine_load : Begin\n";
    print Dumper (\%machine_load);
    print "-I- Machine Load Hash Printing : machine_load : End\n";
}

#Remove old servers:
remove_redundant_servers(\%machine_load);

#Pring footer/summary for current machine host:
print_machine_status(\%machine_load);

#Close log file for printing:
close $LOG_FH;

print "-I- You have reached end of pt_server_supervisor...\n";

exit 0;

#################################################################################################################################
############################################Functions############################################################################
#################################################################################################################################
#This function will be printing summary of amount of servers running under current server_name for finalize report per host (server_name):
sub print_machine_status {
   my ($machine_load) = @_;
   my $num_of_servers_on_machine = scalar(keys %{$machine_load->{$ENV{HOST}}});
   my $num_of_up_servers = 0;
   foreach my $server_name (keys %{$machine_load->{$ENV{HOST}}}) {
      $num_of_up_servers += $machine_load->{$ENV{HOST}}->{$server_name};
   }
   #Printing summary of amount of servers running under current server_name:
   print $LOG_FH "\n=> Total = $num_of_up_servers/$num_of_servers_on_machine servers are UP\n";
}

#################################################################################################################################
#This function will iterate each server_name process id and will kill any process id which match given server_name:
sub remove_redundant_specific_server {
   my ($server_name_to_kill) = @_;
   #my $output = `/bin/ps -aux | /usr/bin/grep pt_shell_exec | /usr/bin/grep -vw pt_shell |/usr/bin/grep $ENV{USER} | /usr/bin/grep -w set | perl -pe 's/^\\s*(\\S+)\\s*(\\d+).*pt_corner\\s+(\\S+)\\s+.*set\\s+model_type\\s+(\\S+)\\s+.*/ \${4}_\${3} \${1} \${2}/; s/;//g'`;
   my $output = `/bin/ps -aux | /usr/bin/grep pt_shell_exec | /usr/bin/grep -vw pt_shell | /usr/bin/grep -w set | perl -pe 's/^\\s*(\\S+)\\s*(\\d+).*pt_corner\\s+(\\S+)\\s+.*set\\s+model_type\\s+(\\S+)\\s+.*/ \${4}_\${3} \${1} \${2}/; s/;//g'`;

   my @processes_lines = split(/\n/, $output);
   foreach my $process_line (@processes_lines) {
      my $process_number = (split(/\s+/,$process_line))[3];
      my $user_id = (split(/\s+/,$process_line))[2];
      my $server_name_corner_name = (split(/\s+/,$process_line))[1];
      
      #For some reason the ps -aux command will return this, so we skip it manualy:
      #next if ($server_name =~ /(\S+).*\/_(\S+).*/);
      #Check if current server_name being iterated is the one to be killed?
      if ($server_name_corner_name eq $server_name_to_kill) {
          print $LOG_FH "\nremove redundant server due to refresh (exist in config file): $server_name_corner_name (process: $process_number | user: $user_id)";	 
          `kill -9 $process_number`;
	  print $LOG_FH "\nremoved older process of: $server_name_corner_name (process: $process_number | user: $user_id)\n";
	  
      }
   } 
}
#################################################################################################################################
#This function will iterate each server_name process id and will kill any process id which not avail under cfg file:
#Example:
# /bin/ps -aux | /usr/bin/grep pt_shell_exec | /usr/bin/grep -w set | perl -pe 's/^\s*\S+\s*(\S+).*setenv corner (\S+).*set model_type (\S+).*/ $3_$2 $1/; s/;//g'
# modelb_adla0_base_func_max_lowvcc 40920
# modela_adla0_fcn_func_max_lowvcc 41010
# modela_adla0_fcn_func_max_highvcc 41055
# modelb_adla0_fcn_func_max_highvcc 41102
# modela_adla0_base_func_max_lowvcc 102382
# modela_adla0_base_func_max_highvcc 102462
sub remove_redundant_servers {
   my ($machine_load) = @_;
   #my $output = `/bin/ps -aux | /usr/bin/grep pt_shell_exec | /usr/bin/grep -w set | perl -pe 's/^\\s*\\S+\\s*(\\S+).*setenv corner (\\S+).*set model_type (\\S+).*/ \${3}_\$2 \${1}/; s/;//g'`;
   my $output = `/bin/ps -aux | /usr/bin/grep pt_shell_exec | /usr/bin/grep -vw pt_shell | /usr/bin/grep -w set | perl -pe 's/^\\s*(\\S+)\\s*(\\d+).*pt_corner\\s+(\\S+)\\s+.*set\\s+model_type\\s+(\\S+)\\s+.*/ \${4}_\${3} \${1} \${2}/; s/;//g'`;
   my @processes_lines = split(/\n/, $output);
   foreach my $process_line (@processes_lines) {
      print "process_line = '$process_line' \n";
      #my $server_name = (split(/\s+/,$process_line))[1];
      #my $process_number = (split(/\s+/,$process_line))[2];
      
      my $process_number = (split(/\s+/,$process_line))[3];
      my $user_id = (split(/\s+/,$process_line))[2];
      my $server_name_corner_name = (split(/\s+/,$process_line))[1];
      
      #For some reason the ps -aux command will return this, so we skip it manualy:
      #next if ($server_name =~ /(\S+).*\/_(\S+).*/);
      #Check if current server_name being iterated is the one to be killed as redundent under the host:
      if (! exists $machine_load->{$ENV{HOST}}->{$server_name_corner_name}) {
         print $LOG_FH "\nremove redundant server (not exist in config file): $server_name_corner_name (process: $process_number)\n";
         `kill -9 $process_number`;
      }
   } 
}


#################################################################################################################################
#This function will get setup for relevant links per server
sub setup_server {
   my ($server_name, $model_type, $corner, $pt_server_dir, $model_dir, $session_link, $log_file) = @_;
   
   #print "\n\n\nserver_name = $server_name\n";
   #print "model_type = $model_type\n";
   #print "corner = $corner\n";
   #print "pt_server_dir = $pt_server_dir\n";
   #print "model_dir = model_dir\n";
   #print "session_link = $session_link\n";
   #print "log_file = $log_file\n";
   
   my $missing_session_sign = "${pt_server_model_status_per_model_type}/session_of_${server_name}_is_missing";
   if (! -d $session_link) {
      print $LOG_FH "session dir does not exist in : $session_link\n"; 
      if (! -f $missing_session_sign) { 
         `/bin/touch $missing_session_sign`;
	  # send mail with missing session notification
	  #my $send_to_user = $ENV{USER};
	  #print $LOG_FH "send mail with missing session notification to: $send_to_user\n";
          #`echo "Server: $server_name \nSession is missing : $session_link" | mail $send_to_user -s "PT server - Session is missing"`;
      }
      print $LOG_FH "skip this server...\n";
      return;
   }
   `/bin/rm -f $missing_session_sign`;
   my $log_per_server = "$pt_server_model_status_per_model_type/${server_name}_pt.log";
   print "-I- Wrinting to log file: $log_per_server \n";
   print $LOG_FH "run pt_shell - ";
   my $cmd = "/usr/bin/grep \-A1 \'PrimeTime Version\' $session_link\/README \| /usr/bin/grep -v \'PrimeTime Version\' \| /usr/intel/bin/awk \'{print \$1}\'";
   #print "cmd = $cmd\n";
   my $pt_version = `$cmd`;
   chomp($pt_version);
   print "-I- PT version: $pt_version\n";
   print $LOG_FH "pt_version $pt_version\n";

   #ByPass for corners load conflicts:   
   my $pt_server_tmp_disk_host = "/tmp/${corner}/";
   my $cmd = "/bin/mkdir -p $pt_server_tmp_disk_host";
   system($cmd);
   
   #my $cmd = "\/p\/hdk\/cad\/primetime\/$pt_version\/suse64\/syn\/bin\/pt_shell -x \'setenv corner $corner; set dbs $session_link; set model_type $model_type; set pt_server_dir $pt_server_dir; ";
   #my $cmd = "\/p\/hdk\/cad\/primetime\/$pt_version\/bin\/pt_shell -x \'setenv corner $corner; set dbs $session_link; set model_type $model_type; set pt_server_dir $pt_server_dir; ";   
   #my $cmd = "\/p\/hdk\/cad\/primetime\/$pt_version\/suse64\/syn\/bin\/pt_shell -x \'setenv corner $corner; set_program_options -disable_high_capacity ; set pt_tmp_dir $pt_server_tmp_disk_host  ; set dbs $session_link; set model_type $model_type; set pt_server_dir $pt_server_dir; ";
   my $cmd = "\/p\/hdk\/cad\/primetime\/$pt_version\/bin\/pt_shell -x \'set pt_corner $corner; set_program_options -disable_high_capacity ; set pt_tmp_dir $pt_server_tmp_disk_host  ; set dbs $session_link; set model_type $model_type; set pt_server_dir $pt_server_dir; ";
   
   $cmd .= "source $pt_server_dir\/pt_server.tcl; \' > $log_per_server &";
   print $LOG_FH "cmd = $cmd\n\n";
   print "-I- Running: $cmd\n";
   system($cmd);
}
 
#################################################################################################################################
#List of all server process per server_name
sub get_server_processes {
   my ($server_name) = @_;
   my @server_processes_numbers;
   print "-I- For server $server_name\n";
   #my $output = `/bin/ps -aux | /usr/bin/grep pt_shell_exec | /usr/bin/grep -w set | perl -pe 's/^\\s*\\S+\\s*(\\S+).*setenv corner (\\S+).*set model_type (\\S+).*/ \${3}_\$2 \${1}/; s/;//g' | /usr/bin/grep \" $server_name "`;
   #my $output = `/bin/ps -aux | /usr/bin/grep pt_shell_exec | /usr/bin/grep -vw pt_shell |/usr/bin/grep $ENV{USER} | /usr/bin/grep -w set | perl -pe 's/^\\s*(\\S+)\\s*(\\d+).*pt_corner\\s+(\\S+)\\s+.*set\\s+model_type\\s+(\\S+)\\s+.*/ \${4}_\${3} \${1} \${2}/; s/;//g' | /usr/bin/grep \" $server_name "`;
   my $output = `/bin/ps -aux | /usr/bin/grep pt_shell_exec | /usr/bin/grep -vw pt_shell | /usr/bin/grep -w set | perl -pe 's/^\\s*(\\S+)\\s*(\\d+).*pt_corner\\s+(\\S+)\\s+.*set\\s+model_type\\s+(\\S+)\\s+.*/ \${4}_\${3} \${1} \${2}/; s/;//g' | /usr/bin/grep \" $server_name "`;
   
   my @processes_lines = split(/\n/, $output);
   foreach my $process_line (@processes_lines) {
         print "-I- Parsing process_line: $process_line\n";
         my $process_number = (split(/\s+/,$process_line))[3]; 
         push(@server_processes_numbers, $process_number);
   }
   return @server_processes_numbers;
}

#################################################################################################################################
#Get setup and related block name
sub get_block_name {
   my ($model_link) = @_;
   #Query env_vars - assuming $block appear there, if missing, fallbacl to soc as default.
   my $default_block = "soc";
   print "-I- Checking existance of: $model_link/env_vars.rpt\n";
   if (-e "$model_link/env_vars.rpt") {
       $default_block = `/usr/bin/grep '^block=' $model_link/env_vars.rpt`;
       chomp($default_block);
       $default_block =~ s/block\=(.*)/$1/;
   } else {
       print "file is N/A here: $model_link/env_vars.rpt\n";
   }
   
   if ($default_block ne "") {
       print "-I1- Your block name is $default_block\n";
       return "$default_block";
   } else {
       print "-I2- Your block name is soc  - default one coming from default mechanism env\n";
       return "soc";
   }
}

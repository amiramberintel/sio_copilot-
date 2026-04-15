#!/usr/intel/bin/perl
use File::stat;
use Time::localtime;
use User::pwent;
use Time::localtime;
use Data::Dumper;
use strict;
use Getopt::Long;
use Cwd qw(abs_path);
use Term::ANSIColor;

my $scriptInfo = "
   pt_server_model_link_status.pl

   Arguments to the script:

      -config <config_file>   :  pt servers file
      [-debug]                :  Print debugging messages (Default: FALSE).
      [-stepping]             :  stepping
      [-model_type]           :  model_type
      [-report]               :  report
      [-update_latest_link]   :  update_latest_link
      [-ward_from_user]       :  ward_from_user
      [-help]                 :  Print help and exit.
";


my ($ref, $run, $out, $corner, $log_file, $help, $config_file, $stepping, $model_type, $report, $update_latest_link, $ward_from_user, $ovr_latest_model_link);
our $DEBUG; # Default: no debug messages displayed.


#Function for getting arguments from user:
GetOptions(
    "debug"                => \$DEBUG,
    "config=s"             => \$config_file,
    "stepping=s"           => \$stepping,
    "model_type=s"         => \$model_type,
    "report"               => \$report,
    "update_latest_link"   => \$update_latest_link,
    "ward_from_user=s"     => \$ward_from_user,
    "ovr_latest_model_link" => \$ovr_latest_model_link,
    "h|help"               => \$help
) || die("-E- Wrong Command Line Argument\n");


#Check inputs for current script, in case not meat, script will abort and print user error:
my $required = ($config_file); # TRUE if the required items are entered
if (($help) || (! $required))  { # User wants script info printed, or did not enter mandatory items
   if (! $help) {
      print ("\n-I- Usage Error. Please read the manual carefully:");
   }
   print("-I- $scriptInfo");
   exit;
}

#Clear current screen:
system("clear");
  
#This hash will store all avail model (based on cfg file) and their type:
our %servers_DB;

#This variables will hold our pt server properties:
our $pt_server_dir;
our $pt_server_model_status_per_server;
our $pt_server_model_link;
our $pt_server_model_status_per_model_type;
#our $pt_server_tmp_disk;

#Define names of available models by name:
my %models_hash = (
    modela  => 1,
    modelb => 1,
);

#This hash will store how many sessions/which are per host:
my %machine_load;

#This hash will store any server with bad cfg:
my %wrong_syntax_server;

#Parse config_file:
open (my $FH, "<", $config_file);
while (my $line = <$FH>) {
   chomp($line);
   if ($line =~ /^\s*#/ && $line !~ /^\s*##/ && $line !~ /set pt_server/) {
      $line =~ s/#//g;
      my ($model,$type,$corner,$modelb_or_modela,$machine,$socket) = split(/,/, $line);
      $servers_DB{$model}{$type}{$corner}{$modelb_or_modela} = $machine;
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

#Debug mode all inputs:
if ($ENV{DEBUG_MODE}) {
    print "-DEBUG- Printing all servers hash: servers_DB\n";
    print Dumper (\%servers_DB);
    print "-DEBUG- Printing wrong syntax server hash: wrong_syntax_server\n";
    print Dumper (\%wrong_syntax_server);
    print "-DEBUG- Printing machine_load hash: machine_load\n";
    print Dumper (\%machine_load);

    print "-DEBUG- Printing more pt_server cfg values:\n";
    print "-DEBUG- variable: pt_server_dir value: $pt_server_dir\n";
    print "-DEBUG- variable: pt_server_model_status_per_server value: $pt_server_model_status_per_server\n";
    print "-DEBUG- variable: pt_server_model_link value: $pt_server_model_link\n";
    print "-DEBUG- variable: pt_server_model_status_per_model_type value: $pt_server_model_status_per_model_type\n";
    
    print "-DEBUG- Printing more pt_server cfg values:\n";
    print "-DEBUG- variable: config_file value: $config_file\n";
    print "-DEBUG- variable: stepping value: $stepping\n";
    print "-DEBUG- variable: report value: $report\n";
    print "-DEBUG- variable: update_latest_link value: $update_latest_link\n";
    print "-DEBUG- variable: ward_from_user value: $ward_from_user\n";
    print "-DEBUG- variable: ovr_latest_model_link value: $ovr_latest_model_link\n";    
}

#This hash will store all properties for active models so user can decide which link to update each time:
my %model_links_hash;

#Build the data inside current hash:
foreach my $model (keys %servers_DB) {
    foreach my $type (keys %{$servers_DB{$model}}) {
        foreach my $modelb_or_modela (keys %models_hash) {
	    my $current_path = "$pt_server_model_link/${modelb_or_modela}_${model}_${type}";
	    #print "-I- Current Path is: $current_path\n";
	    
	    if (-e $current_path) {
	        $model_links_hash{$model}{$type}{$modelb_or_modela}{current_path} = $current_path;
	        #my $mtime = (stat $current_path)[9];
		my $time =ctime(stat($current_path)->mtime);
		$model_links_hash{$model}{$type}{$modelb_or_modela}{date} = $time;
		#https://stackoverflow.com/questions/509576/how-do-i-get-a-files-last-modified-time-in-perl
		my $date_array_ref = (stat($current_path));
		#print "date_integer = $date_array_ref\n";
		#print Dumper($date_array_ref);
		#my $date_integer = $date_array[9];
		$model_links_hash{$model}{$type}{$modelb_or_modela}{date_integer} = ${$date_array_ref}[9];
		#my $uid = (stat $current_path)[4];
                #$model_links_hash{$current_path}{user} = $uid;	    
	        my ($gid) = getgrgid(stat($current_path)->gid);
                $model_links_hash{$model}{$type}{$modelb_or_modela}{gid} = $gid;	                  
		my $uid = getpwuid(stat($current_path)->uid);
                $model_links_hash{$model}{$type}{$modelb_or_modela}{uid} = $$uid[0];
		$model_links_hash{$model}{$type}{$modelb_or_modela}{latest_prev} = 0; 	   
	    } else {
	        #print "-I- Path is NA for now...\n";
	    }
	    #} else {   
            #    $model_links_hash{$model}{$type}{$modelb_or_modela}{date_integer} = 0;
	    #	$model_links_hash{$model}{$type}{$modelb_or_modela}{date} = 0;
	    #	$model_links_hash{$model}{$type}{$modelb_or_modela}{uid} = 0;
	    #	$model_links_hash{$model}{$type}{$modelb_or_modela}{gid} = 0;
	    #	$model_links_hash{$model}{$type}{$modelb_or_modela}{latest_prev} = 0;
	    #}
	
	}
    }
}

#Debug mode all inputs:
if ($ENV{DEBUG_MODE}) {
    print "-DEBUG- Printing model_links_hash hash: Begin\n";
    print Dumper (\%model_links_hash);
    print "-DEBUG- Printing model_links_hash hash: End\n";

}

#Iterate each model and decide latest/prev model based on date_integer time:
foreach my $model (keys %servers_DB) {
    foreach my $type (keys %{$servers_DB{$model}}) {
        foreach my $modelb_or_modela (keys %models_hash) {
            if ((exists $model_links_hash{$model}{$type}{modela}) && (exists $model_links_hash{$model}{$type}{modelb})) {
                my $modela_date_integer = $model_links_hash{$model}{$type}{modela}{date_integer};
	        my $modelb_date_integer = $model_links_hash{$model}{$type}{modelb}{date_integer};
	        #print "model = $model  and type = $type and modelb_or_modela = $modelb_or_modela\n";
	        #print "modela_date_integer = $modela_date_integer | modelb_date_integer = $modelb_date_integer\n";
	    
	        if ($modela_date_integer > $modelb_date_integer) {
	            $model_links_hash{$model}{$type}{modela}{latest_prev} = 'latest';
	            $model_links_hash{$model}{$type}{modelb}{latest_prev} = 'prev <= regular_refresh';
	        } else {    
	            $model_links_hash{$model}{$type}{modela}{latest_prev} = 'prev <= regular_refresh';
	            $model_links_hash{$model}{$type}{modelb}{latest_prev} = 'latest';
	        }
		
		#add if else then...
			    
            } elsif ((exists $model_links_hash{$model}{$type}{modela}) && (!(exists $model_links_hash{$model}{$type}{modelb}))) {
	        $model_links_hash{$model}{$type}{modela}{latest_prev} = 'latest';
	    } elsif (!(exists $model_links_hash{$model}{$type}{modela}) && (exists $model_links_hash{$model}{$type}{modelb})) {
	        $model_links_hash{$model}{$type}{modelb}{latest_prev} = 'latest';
	    }
	}
    }    
}

#Debug mode all outputs:
if ($ENV{DEBUG_MODE}) {
    print "-DEBUG- Printing all servers hash: model_links_hash : Begin\n";
    print Dumper (\%model_links_hash);
    print "-DEBUG- Printing all servers hash: model_links_hash : End\n";
}

my $current_date = `date`;

print "\n\nHi $ENV{USER}, This is C2DG CTH2 PT Server Resources @ $current_date\n\n";
print colored ("Current Available Links and models Status: (in case both prev/latest avail, search for <= which indicates where to refresh next link here...",'bold green'),"\n";
print colored ("****************************************** \$LINK_AREA = $pt_server_model_link", 'bold green'),"\n\n";
my $split_sign = '+' x 182; 
my $line = sprintf '%-182s', "$split_sign";
print "$line\n";
my $line = sprintf '%-1s %-10s %-1s %-13s %-1s %-63s %-1s %-25s %-1s %-25s %-1s %-15s %-1s %-9s %-1s', "|", "model", "|", "modelb/modela", "|" , "current_path", "|", "date", "|", "Latest/Prev", "|", "uid", "|", "gid", "|" ;
print "$line\n";
my $line = sprintf '%-182s', "$split_sign";
print "$line\n";

#Printing data to user per model path:
foreach my $model (sort keys %model_links_hash) {
    foreach my $type (sort keys %{$model_links_hash{$model}}) {
        foreach my $modelb_or_modela (sort keys %{$model_links_hash{$model}{$type}}) {
	        my $current_path = $model_links_hash{$model}{$type}{$modelb_or_modela}{current_path};
		$current_path =~ s/${pt_server_model_link}\//\$LINK_AREA\//;
		my $date = $model_links_hash{$model}{$type}{$modelb_or_modela}{date};
                my $uid = $model_links_hash{$model}{$type}{$modelb_or_modela}{uid};
                my $gid = $model_links_hash{$model}{$type}{$modelb_or_modela}{gid};	        
                my $latest_prev = $model_links_hash{$model}{$type}{$modelb_or_modela}{latest_prev};	
		my $line = sprintf '%-1s %-10s %-1s %-13s %-1s %-63s %-1s %-25s %-1s %-25s %-1s %-15s %-1s %-9s %-1s', "|", "$model", "|", "$modelb_or_modela", "|" , "$current_path", "|", "$date", "|", "$latest_prev", "|", "$uid", "|", "$gid", "|" ;
                print "$line\n";
        }
    }
}
my $line = sprintf '%-172s', "$split_sign";
print "$line\n";

print colored ("\n\nCurrent Bad Cfg Models by DA:",'bold yellow'),"\n";
print colored ("*****************************",'bold yellow'),"\n\n";
my $split_sign = '+' x 120; 


my $line = sprintf '%-120s', "$split_sign";
print "$line\n";
my $line = sprintf '%-1s %-80s %-1s %-15s %-1s %-15s %-1s', "|", "model", "|", "machine", "|" , "socket", "|" ;
print "$line\n";
my $line = sprintf '%-120s', "$split_sign";
print "$line\n";

#Printing data to user per model path:
foreach my $server_name (sort keys %wrong_syntax_server) {
    my $machine = $wrong_syntax_server{$server_name}{machine};
    my $socket = $wrong_syntax_server{$server_name}{socket};
    my $line = sprintf '%-1s %-80s %-1s %-15s %-1s %-15s %-1s', "|", "$server_name", "|", "$machine", "|" , "$socket", "|" ;
    print "$line\n";
}
my $line = sprintf '%-118s', "$split_sign";
print "$line\n";



#List of all links under link directory:
my @list_of_linked_models = glob("$pt_server_model_link/*");
my %hash_of_linked_models = map {$_ => 1} @list_of_linked_models;
my %unused_model_links_hash;


#Iterate each linked model and check if we use it, if not alert to user:
foreach my $link (keys %hash_of_linked_models) {
    $link =~ /($pt_server_model_link)\/(.*)/;
    my $link_suffix = $2;
    $link_suffix =~ m/(\S+)_(\S+)_(base|fcn|fcl|bu_prp|bu_mc_prp|bu_prp_x2r3|bu)/;
    #$link_suffix =~ m/(\S+)_(\S+)_(.*)/;
    my $modela_modelb = $1;
    my $model = $2;
    my $type = $3;
    #print "modela_modelb = $modela_modelb | model = $model | type = $type\n";
    if ((exists $model_links_hash{$model}) && (exists $model_links_hash{$model}{$type}) && (exists $model_links_hash{$model}{$type}{$modela_modelb})) {
        #do nothing, all is fine
    } else {
        #add this link under unused_model_links_hash
	$unused_model_links_hash{$link} = $link;
    }
}

#Debug mode all outputs:
if ($ENV{DEBUG_MODE}) {
    print "-DEBUG- Printing all hash_of_linked_models hash: hash_of_linked_models\n";
    print Dumper (\%hash_of_linked_models);
    
    print "-DEBUG- Printing all unused_model_links_hash hash: unused_model_links_hash\n";
    print Dumper (\%unused_model_links_hash);
}

print colored ("\n\nIn Model Link Area but not in Active Servers:",'bold blue'),"\n";
print colored ("*********************************************",'bold blue'),"\n\n";

my $split_sign = '+' x 164; 
my $line = sprintf '%-164s', "$split_sign";
print "$line\n";
my $line = sprintf '%-1s %-160s %-1s', "|", "link", "|" ;
print "$line\n";
my $line = sprintf '%-164s', "$split_sign";
print "$line\n";


#Printing data to user per model path:
foreach my $link (sort keys %unused_model_links_hash) {
    my $line = sprintf '%-1s %-160s %-1s', "|", "$link", "|" ;
    print "$line\n";
}
my $line = sprintf '%-194s', "$split_sign";
print "$line\n";

###Adding linking/report stage:
if ($report) {
    #We check first if env_vars are avail under source, if yes than we are ok, else the link is unreal, first link for model must be for real area!
    my $modela_location = "$pt_server_model_link/modela_${stepping}_${model_type}/env_vars.rpt";
    my $modelb_location = "$pt_server_model_link/modelb_${stepping}_${model_type}/env_vars.rpt";
    print colored ("\n\nLinkage Report Status and Connectivity Status:",'bold red'),"\n";
    print colored ("**********************************************",'bold red'),"\n\n";
    print "-I- Report Mode For User: stepping == '$stepping' && model_type == '$model_type' && ovr_latest_model_link = '$ovr_latest_model_link'\n";

    my $modela_location = "$pt_server_model_link/modela_${stepping}_${model_type}/env_vars.rpt";
    my $modelb_location = "$pt_server_model_link/modelb_${stepping}_${model_type}/env_vars.rpt";
    
    #Both locations are avail:
    if ((-e $modela_location) && (-e $modelb_location)) {     
        my $link_to_update;
	foreach my $modelb_or_modela (keys %{$model_links_hash{$stepping}{$model_type}}) {
	    my $current_latest_prev = $model_links_hash{$stepping}{$model_type}{$modelb_or_modela}{latest_prev};
	    if ($ovr_latest_model_link) {
	        if ($current_latest_prev =~ /latest/) {
	            $link_to_update = $model_links_hash{$stepping}{$model_type}{$modelb_or_modela}{current_path};
	        }
	    } else {    
	        if ($current_latest_prev =~ /prev/) {
	            $link_to_update = $model_links_hash{$stepping}{$model_type}{$modelb_or_modela}{current_path};
	        }	    
	    }
	}
	
	print "-I- Based on 2 models avail status, model shall be updated on this pointer: $link_to_update\n";
	my $cmd = "/bin/ln -f -s $ward_from_user $link_to_update";
	print "-I- Command For manual update: $cmd\n\n";
        if ($update_latest_link) {
	    if (($link_to_update ne '') and (-e $ward_from_user)) { 
	        print "-I- Latest Link Update: Based on status, model shall be updated on this pointer: $link_to_update\n";
	        print "-I- Latest Link Update: User Auto Update: Running: $cmd\n\n";
	    } else {    
	        print "-I- Latest Link Update: Based on status, model shall be updated on this pointer: $link_to_update\n";
	        print "-I- Latest Link Update: User Auto Update: Can't Running: $cmd as one of parameters are NA...\n\n";
	    }
	}       
    } elsif (-e $modela_location) {
        #Only single location:
	my $link_to_update = $model_links_hash{$stepping}{$model_type}{modela}{current_path};
	print "-I- Based on single model and link avail status, model shall be updated on this pointer: $link_to_update\n";
	my $cmd = "/bin/ln -f -s $ward_from_user $link_to_update";
	print "-I- Command For manual update: $cmd\n\n";
        if ($update_latest_link) {
	    if (($link_to_update ne '') and (-e $ward_from_user)) { 
	        print "-I- Latest Link Update: Based on status, model shall be updated on this pointer: $link_to_update\n";
	        print "-I- Latest Link Update: User Auto Update: Running: $cmd\n\n";
	    } else {    
	        print "-I- Latest Link Update: Based on status, model shall be updated on this pointer: $link_to_update\n";
	        print "-I- Latest Link Update: User Auto Update: Can't Running: $cmd as one of parameters are NA...\n\n";
	    }
	}
    
    } elsif (-e $modelb_location) {
        #Only single location:
	my $link_to_update = $model_links_hash{$stepping}{$model_type}{modelb}{current_path};
	print "-I- Based on single model and link avail status, model shall be updated on this pointer: $link_to_update\n";
	my $cmd = "/bin/ln -f -s $ward_from_user $link_to_update";
	print "-I- Command For manual update: $cmd\n\n";
        if ($update_latest_link) {
	    if (($link_to_update ne '') and (-e $ward_from_user)) { 
	        print "-I- Latest Link Update: Based on status, model shall be updated on this pointer: $link_to_update\n";
	        print "-I- Latest Link Update: User Auto Update: Running: $cmd\n\n";
	    } else {    
	        print "-I- Latest Link Update: Based on status, model shall be updated on this pointer: $link_to_update\n";
	        print "-I- Latest Link Update: User Auto Update: Can't Running: $cmd as one of parameters are NA...\n\n";
	    }
	}
    } else {
        #No Location is avail here, we shall request from DA to setup links first here:    
        print "-I- This is first time you link stepping = $stepping' && model_type = '$model_type', pls contact CDG BE Integration DA for first link creation\n";
    }
}



print "Bye Bye...\n";

#!/usr/intel/bin/perl

#-----------------------------------------------------------------------------------
# (C) Copyright Intel Corporation, 2016
# Licensed material -- Program property of Intel Corporation
# All Rights Reserved
#
# This program is the property of Intel Corporation and is furnished
# pursuant to a written license agreement. It may not be used, reproduced,
# or disclosed to others except in accordance with the terms and conditions
# of that agreement.
#-----------------------------------------------------------------------------------
# Author      : Ooi, Thean Wui
# Date        : Mar 1 2016
# Project     : GSD
# Revision    : 1.2
# Description : PT live server session (script wrapper for client side)
#------------------------------------------------------------------------------------

use Getopt::Long;
use Term::ANSIColor;
use Data::Dumper;
use Time::Piece;
use Cwd qw(abs_path);

# split script path based on $0 location get current folder and script name
my $path = abs_path($0);
my @tq = split(/\//,$path);
pop(@tq);
$script_path = join("/",@tq);

$username = `whoami`;
chomp($username);

my $debug;
# server cfg file
$cfg = "$script_path/pt_server_c2dgbcptserver_cron.cfg";
if (!-e $cfg) {
    die("-E- Missing host configuration file in $script_path. Please contact FCT team for detail\n");
}

#Reading cfg file with all servers and corner names:
&read_cfg;

#Script options:
&GetOptions(
    "m=s"         => \$corner,
    "c=s"         => \$command,
    "o=s"	  => \$outputfile,
    "debug"       => \$debug,
    "help"	  => \$help,
    "h"		  => \$help
) || die("-E- Wrong command line argument\n");

sub help 
{
  print "
	USAGE : $script_name	
	-m < mode e.g func_max,func_min,etc [default func_max] >CNLS

	[ available mode: $available_corner]
	-c '< PrimeTime command >'
	-o < print to output file [OPTIONAL] >
	[ -help|h ]
";
	exit(0);
}	

$required = $command;

if($help || !$required) {
	&help();
}	

## set default mode
if(!$corner) {
    $corner = "func_max";
}
	
# support multiple corners query simultaneously
if ($corner =~ /,/) {
    @corner = split(/,/,$corner);
} else {
    @corner = $corner;
}

# active socket/host:
my %hash_;
# active corners:
my $tag;

# printing hash data per socket/host/corner:
if ($ENV{DEBUG_MODE}) {
    print "-I- Full Hash details of avail hosts/socket:\n";
    print Dumper (\%hash_);
    print "-I- Full Hash details of avail corners:\n";
    print Dumper (\%tag);
}

# precheck server status 
foreach $c (@corner) {
    #next unless corner_is_valid($c);
    #print "corner is $c\n";
    my $current_date_string = localtime();
    print "-I- CDG BE Integration DA - PT Server Services - For Debug :: corner from user: $c at @ $current_date_string\n" if ($debug);
    # take each corner (call from user, and map it to relevant model. if user provide modela/modelb prefix - take as is, is user provides prev/latest prefix, map it based on user's request (get first timestamp and than map to prev/latest accordingly based on timestamp) 
    my $prev_latest_prefix = $c;
    $prev_latest_prefix =~ m/(.*?)_(.*)/;
    $prev_latest_prefix = $1;
    #print "prev_latest_prefix = $prev_latest_prefix\n";
    $model_suffix = $2;
    #print "model_suffix = $model_suffix\n";
    #print "prev_latest_prefix = $prev_latest_prefix\n";

    my $modela_corner = "modela_"."${model_suffix}";
    my $modelb_corner = "modelb_"."${model_suffix}";
    #print "modela_corner = $modela_corner\n";
    #print "modelb_corner = $modelb_corner\n";
    

    #Define our corner mapper:
    my $current_corner;

    #Case where corner being callsed is directly modela_* or modelb_*  
    if (($c =~ /modela/) || ($c =~ /modelb/)) {
        if ($c =~ /modela/) {
	    print "-I- CDG BE Integration DA - PT Server Services - For Debug :: Case #1\n" if ($debug);
	    print "-I- CDG BE Integration DA - PT Server Services - For Debug :: Date : Direct Corner\n" if ($debug);
	    #Case where the pt_server_supervisor.pl checks if corner is online
	    $current_corner = $c;
        } elsif ($c =~ /modelb/) {
	    print "-I- CDG BE Integration DA - PT Server Services - For Debug :: Case #2\n" if ($debug);
	    print "-I- CDG BE Integration DA - PT Server Services - For Debug :: Date : Direct Corner\n" if ($debug);
	    #Case where the pt_server_supervisor.pl checks if corner is online
	    $current_corner = $c;
        }   
    } elsif ($prev_latest_prefix eq 'latest') {
        #latest model support:
	print "-I- CDG BE Integration DA - PT Server Services - For Debug :: Case #3\n" if ($debug);
        
	#get modela date:
	my $modela_date = `echo get_current_scenario_time_cth2 | netcat -w 5 $hash_{host}{$modela_corner} $hash_{socket}{$modela_corner} && echo "Online" || echo "Offline"`;       
	$modela_date =~ s/\n//g;
	$modela_date =~ s/(.*Current time of ward is:) (\S+)(\. Thanks!.*)/$2/;
        my $modela_date_string = localtime ($modela_date);
	#print "modela_date = '$modela_date'\n";
        
        #get modelb date
        my $modelb_date = `echo get_current_scenario_time_cth2 | netcat -w 5 $hash_{host}{$modelb_corner} $hash_{socket}{$modelb_corner} && echo "Online" || echo "Offline"`;        
	$modelb_date =~ s/\n//g;
	$modelb_date =~ s/(.*Current time of ward is:) (\S+)(\. Thanks!.*)/$2/;
	my $modelb_date_string = localtime ($modelb_date_string);
	#print "modelb_date = '$modelb_date'\n";
	print "-I- CDG BE Integration DA - PT Server Services - For Debug :: Date modela : '$modela_date' at @ $modela_date_string\n" if ($debug);
	print "-I- CDG BE Integration DA - PT Server Services - For Debug :: Date modelb : '$modelb_date' at @ $modelb_date_string\n" if ($debug);
		
	if (($modela_date eq 'Offline') && ($modelb_date eq 'Offline')) {
	    #Case of both models are offline:
	    print colored ("-E- ${model_suffix} server is OFFLINE (both latest/prev). Please contact FCT team",'bold red'),"\n";
	} elsif (($modela_date eq 'Offline') && ($modelb_date ne 'Offline')) {
	    #Case of one models is offline and only modelb is online:
	    $current_corner = $modelb_corner;
	} elsif (($modelb_date eq 'Offline') && ($modela_date ne 'Offline')) {
	    #Case of one models is offline and only modela is online:
	    $current_corner = $modela_corner;
	} elsif ($modela_date > $modelb_date) {
	    #Case both models are not offline, we will take latest one:
	    $current_corner = $modela_corner;
	} elsif ($modela_date < $modelb_date) {
	    #Case both models are not offline, we will take prev one:
	    $current_corner = $modelb_corner;
	} elsif ($modela_date eq $modelb_date) {
	    #Case both models are not offline, we will take prev one:
	    $current_corner = $modela_corner;
	}	
    } elsif ($prev_latest_prefix eq 'prev') {
        print "-I- CDG BE Integration DA - PT Server Services - For Debug :: Case #4\n" if ($debug);
    
        #prev model support:

        #get modela date:
        my $modela_date = `echo get_current_scenario_time_cth2 | netcat -w 5 $hash_{host}{$modela_corner} $hash_{socket}{$modela_corner} && echo "Online" || echo "Offline"`;
	$modela_date =~ s/\n//g;
	$modela_date =~ s/(.*Current time of ward is:) (\S+)(\. Thanks!.*)/$2/;
	my $modela_date_string = localtime ($modela_date);
        #print "modela_date = '$modela_date'\n";

	#get modelb date
        my $modelb_date = `echo get_current_scenario_time_cth2 | netcat -w 5 $hash_{host}{$modelb_corner} $hash_{socket}{$modelb_corner} && echo "Online" || echo "Offline"`;	
	$modelb_date =~ s/\n//g;
	$modelb_date =~ s/(.*Current time of ward is:) (\S+)(\. Thanks!.*)/$2/;
	my $modelb_date_string = localtime ($modelb_date_string);
 	#print "modelb_date = '$modelb_date'\n";
	print "-I- CDG BE Integration DA - PT Server Services - For Debug :: Date modela : '$modela_date' at @ $modela_date_string\n" if ($debug);
	print "-I- CDG BE Integration DA - PT Server Services - For Debug :: Date modelb : '$modelb_date' at @ $modelb_date_string\n" if ($debug);

	if (($modela_date eq 'Offline') && ($modelb_date eq 'Offline')) {
	    #Case of both models are offline:
	    print colored ("-E- ${model_suffix} server is OFFLINE (both latest/prev). Please contact FCT team",'bold red'),"\n";
	} elsif (($modela_date eq 'Offline') && ($modelb_date ne 'Offline')) {
	    #Case of one models is offline and only modelb is online:
	    $current_corner = $modelb_corner;
	} elsif (($modelb_date eq 'Offline') && ($modela_date ne 'Offline')) {
	    #Case of one models is offline and only modela is online:
	    $current_corner = $modela_corner;
	} elsif ($modela_date > $modelb_date) {
	    #Case both models are not offline, we will take prev one:
	    $current_corner = $modelb_corner;
	} elsif ($modela_date < $modelb_date) {
	    #Case both models are not offline, we will take latest one:
	    $current_corner = $modela_corner;
	} elsif ($modela_date eq $modelb_date) {
	    #Case both models are not offline, we will take latest one:
	    $current_corner = $modela_corner;
	}
    } else {
        print colored ("-I- $c server is Not Avail, Server must start with prev_ or latest_. Please 
	check your call...",'bold red'),"\n";
	next;
    }	

    #Since we made few mapps earlier, we shall update our mapper below for real user information:
    print "-I- Based on server calculation: current_corner mapped to: $current_corner\n" if ($debug);    
    print "-I- Based on server calculation: host: $hash_{host}{$current_corner}\n" if ($debug);
    print "-I- Based on server calculation: socket : $hash_{socket}{$current_corner}\n" if ($debug);

    #Doing now relevant query over the server:
    $paging = `echo ping | netcat -w 5 $hash_{host}{$current_corner} $hash_{socket}{$current_corner} && echo "Online" || echo "Offline"`;
    $tmp_user = `echo 'set pt_user $username' | netcat -w 5 $hash_{host}{$current_corner} $hash_{socket}{$current_corner}`;
    $server_loading_file = "$script_path/pt_server_model_status_per_model_type/${current_corner}.loading";
    if ($paging eq "" || $paging =~ /Offline/) {
        if (-f $server_loading_file) {
            #Open file for read, get first line which shows dbs pointer:
            open(my $current_fh, $server_loading_file) or die "-E- Could not open file $! for reading";
	    my $current_dbs_path = "Unknown...";
            #Iterate each line and look for Current dbs path here:
            while (my $row = <$current_fh>) {
                chomp $row;
                if ($row =~ /Your Current dbs path is: (.*)/) {
	            $current_dbs_path = $1;
	        }
	    }	
	    close($current_fh);
	    print colored ("-I- $current_corner server is LOADING. Please wait... (dbs_path = $current_dbs_path)",'bold blue'),"\n";
        } else {
            print colored ("-E- $current_corner server is OFFLINE. Please contact FCT team!",'bold red'),"\n";
        }
    } else {
        $output = `echo $command | netcat -w 20 $hash_{host}{$current_corner} $hash_{socket}{$current_corner}`;
        if (!$outputfile) {
            print "$output\n";
        } else {
            open(OUT, ">$outputfile");
            print OUT "$output\n";
            close(OUT);
        }
    }	
}

# origianlly used to assure that relevant corner is avail under cfg, if not avail, flow immediatelly say corner is not available.
sub corner_is_valid {
    my ($corner) = @_;
    if ( ! exists $hash_{host}{$corner}) {
        print("-E- corner '$corner' does not exist!\n");
        return 0;
    } else {
        return 1;
    }
}

# read host and socket config
sub read_cfg {
    open (CFG, "$cfg") || die "Can't open host configuration file $cfg. Please contact FCT team\n";
    my $site;
    while (my $line = <CFG>) {
        chomp($line);
        if ($line =~ /set\s+site\s+(\S+)/) {
            $site = $1;
        } elsif ($line =~ /^\s*#/ && $line !~ /set pt_server/) {
           $line =~ s/#//g;
           my ($model,$type,$corner,$modela_or_modelb,$process,$machine,$socket) = split(/,/, $line);
           next if ($machine eq "");
           my $model_type;
           $model_type .= $modela_or_modelb . "_" . $model . "_" . $type;
           my $server_name = $model_type . "_" . $corner;
           $hash_{socket}{$server_name} = $socket;
           $site = $ENV{"EC_SITE"} if ($site eq ""); 
           $hash_{host}{$server_name} = $machine . ".${site}.intel.com";      
           $available_corner .= "$server_name" if (!$tag{$server_name});
           $tag{$server_name} = 1;
        }
    }
    close(CFG);
}

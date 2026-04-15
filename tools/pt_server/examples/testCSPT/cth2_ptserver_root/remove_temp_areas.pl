#!/usr/intel/bin/perl

use File::Basename;

#Block Definition:
#my $block = "soc";

#Temp folders definition:
#print "-I- Begin: /tmp Removal Section\n\n";
#my @files = glob('/tmp/*');
#foreach my $file (@files){
#    if ($file =~ m/tmp\/\d+/) {
#        my $owner = getpwuid((stat($file))[4]);
#	if ($owner eq cdgptserver) {
#	    print "-I- Flow will remove for now $file with $owner\n"; 
#	    my $cmd = "/bin/rm -rf $file";
#	    system($cmd);
#	}
#    }
#}
#print "-I- End: /tmp Removal Section\n\n";

#Clean ward area with all iterations from last run:
my $ptserver_ward = "/nfs/site/disks/ogivol_wa/ogivol_pt_server_repo/cth2_ptserver_ward/$ENV{HOST}/";
my $cmd = "/bin/rm -rf $ptserver_ward";
print "-I- Pre temp ward cleanup : Begin\n";
print "-I- Flow will remove ward area runs from last 24 hours: $cmd\n";
system($cmd);
print "-I- Post temp ward cleanup : End\n";

#Temp folders definition:
print "-I- Begin: /tmp/corner/.SC* Removal Section\n\n";
my @files = glob("/tmp/*/.SC*");
print "-I- file = @files\n";
foreach my $file (@files){
    if ($file =~ m/(\/tmp\/\S+\/)\.SC\w+/) {
        my $owner = getpwuid((stat($file))[4]);
        my $folder = $1;
	if ($owner eq c2dgbcptserver) {	
	    print "-I- Flow will remove for now due to: $file all folder: $folder with $owner Begin\n"; 
	    my $cmd = "/bin/rm -rf $folder";
	    print "-I- ==> Running $cmd ...wait..\n";
	    system($cmd);
	    print "-I- Flow will remove for now due to: $file all folder: $folder with $owner End\n"; 
	}
    }
}
print "-I- End: /tmp/corner/.SC* Removal Section\n\n";

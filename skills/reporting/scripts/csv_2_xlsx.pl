#!/usr/intel/bin/perl5.14.1 -w
# Script to convert FCT csv to xmlx 
use strict;
use warnings;
use Spreadsheet::WriteExcel;
use lib q{/usr/intel/pkgs/perl/5.14.1/lib64/module/r2};
use Intel::WorkWeek qw(:all);
use Excel::Writer::XLSX;
use Excel::Writer::XLSX::Utility;


my $input_dir = "$ARGV[0]";
my $delmiter = ",";

my $output_name = "$ARGV[0]/bins_multi_corner.xlsx" ;
my $workbook  = Excel::Writer::XLSX->new( "$output_name" );

my $RedFontFormat = $workbook->add_format();
$RedFontFormat->set_bg_color(q/#f79999/);
$RedFontFormat->set_bold();
$RedFontFormat->set_border(1);

my $GreenFontFormat = $workbook->add_format();
$GreenFontFormat->set_bg_color(q/#8feb9b/);
$GreenFontFormat->set_bold();
$GreenFontFormat->set_border(1);

my $NuetralFontFormat = $workbook->add_format();
$NuetralFontFormat->set_bold();
$NuetralFontFormat->set_border(1);

my $CurrModelFormat = $workbook->add_format();
$CurrModelFormat->set_bg_color(q/#cad8ed/);
$CurrModelFormat->set_border(1);

my $RefModelFormat = $workbook->add_format();
#$RefModelFormat->set_bg_color(q/#f79999/);
$RefModelFormat->set_border(1);


my $HeaderFormat = $workbook->add_format();
$HeaderFormat->set_bold();
$HeaderFormat->set_size(8);
$HeaderFormat->set_border(1);
$HeaderFormat->set_align('vcenter');
$HeaderFormat->set_align('center');
$HeaderFormat->set_color(q/navy/);
$HeaderFormat->set_bg_color(q/yellow/);
$HeaderFormat->set_text_wrap();

my $DataF2 = $workbook->add_format();
$DataF2->set_text_wrap();
$DataF2->set_align('vcenter');
$DataF2->set_align('center');
$DataF2->set_size(14);
$DataF2->set_text_wrap();
$DataF2->set_font(qq#Courier New#);
$DataF2->set_bg_color(qq#gray#);
$DataF2->set_bold();
$DataF2->set_border(1);

my $DataF = $workbook->add_format();
$DataF->set_text_wrap();
$DataF->set_align('vcenter');
$DataF->set_align('center');
$DataF->set_size(8);
$DataF->set_text_wrap();
$DataF->set_font(qq#Courier New#);
$DataF->set_border(1);


my $listing = `ls -tr ${input_dir}/csv_kobi/*/vrf_uc.csv `;
my @list_file = split /\n/,$listing;

foreach my $file (@list_file){
	open(FH,$file) or die "Cannot open file: $!\n";
	my $sheet_name =  $file  ;
	$sheet_name =~ s/.*csv_kobi\/([^.]*)\.([^.]*)\..*\/vrf_uc.csv/$1.$2\n/;
	my $worksheet = $workbook->add_worksheet(`echo $sheet_name`);
	$worksheet->add_write_handler(qr[\w], \&store_string_widths);
	my ($x,$y) = (0,0);
	while (<FH>){
		chomp;
	 	my $str = $_ ;
		my $ref_count = 1;
		my $counter = 0;
		if (index($str, $delmiter) != -1) {
 			my @list = split /$delmiter/,$str;
 			foreach my $c (@list){
	    			if ($x==0 || $x==27 || $x==28){
		       			$counter++;
					    $worksheet->write( $x, $y++, $c, $HeaderFormat );
     				}else{
     					if($x % ($ref_count+1)==1){
		       				$counter++;
		 				    $worksheet->write($x, $y++, $c, $CurrModelFormat);
					    }else{
		 				    $counter++;
		    				$worksheet->write($x, $y++, $c, $RefModelFormat );
                            if ( $y<2 ) {
                            } else {
					            if ( $y>2 && $y<8 || $y>10 && $y<16 ){
							        $worksheet->conditional_formatting($x-1, $y-1,{type=> 'cell',criteria => '<',value=> $list[$counter-1],format=> $GreenFontFormat,});
							        $worksheet->conditional_formatting($x-1, $y-1,{type=> 'cell',criteria => '>',value=> $list[$counter-1],format=> $RedFontFormat,});
						        }else{
		    				        $worksheet->conditional_formatting($x-1, $y-1,{type=> 'cell',criteria => '>',value=> $list[$counter-1],format=> $GreenFontFormat,});
							        $worksheet->conditional_formatting($x-1, $y-1,{type=> 'cell',criteria => '<',value=> $list[$counter-1],format=> $RedFontFormat,});
						        }
					        }
				        }
     			    }
                }
 			$x++;$y=0;$counter=0;
		}
		
#	 	if (index($str, $delmiter) != -1) {
#	 		my @list = split /$delmiter/,$str;
#	 		foreach my $c (@list){
#		    		if ($x==0){
#			       		$counter++;
#					$worksheet->write($x, $y++, $c);
#	     			} else {
#	     				$counter++;
#			 		$worksheet->write($x, $y++, $c);
#				}
#			}   		
#	 	$x++;$y=0;$counter=0;
#	 	}
	}
	close(FH); 
	autofit_columns($worksheet);
#	}
}
$workbook->close();
print "summary Results are at : $output_name \n";


sub autofit_columns {
    my $worksheet = shift;
    my $col       = 0;
    for my $width (@{$worksheet->{__col_widths}}) {
 
        $worksheet->set_column($col, $col, $width) if $width;
        $col++;
    }
} 

sub string_width {
    return 0.9 * length $_[0];
}

sub store_string_widths {
 
    my $worksheet = shift;
    my $col       = $_[1];
    my $token     = $_[2];
 
    # Ignore some tokens that we aren't interested in.
    return if not defined $token;       # Ignore undefs.
    return if $token eq '';             # Ignore blank cells.
    return if ref $token eq 'ARRAY';    # Ignore array refs.
    return if $token =~ /^=/;           # Ignore formula
 
    # Ignore numbers
    return if $token =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/;
 
    # Ignore various internal and external hyperlinks. In a real scenario
    # you may wish to track the length of the optional strings used with
    # urls.
    return if $token =~ m{^[fh]tt?ps?://};
    return if $token =~ m{^mailto:};
    return if $token =~ m{^(?:in|ex)ternal:};
 
 
    # We store the string width as data in the Worksheet object. We use
    # a double underscore key name to avoid conflicts with future names.
    #
    my $old_width    = $worksheet->{__col_widths}->[$col];
    my $string_width = string_width($token);
 
    if (not defined $old_width or $string_width > $old_width) {
        # You may wish to set a minimum column width as follows.
        #return undef if $string_width < 10;
 
        $worksheet->{__col_widths}->[$col] = $string_width;
    }
 
 
    # Return control to write();
    return undef;
}

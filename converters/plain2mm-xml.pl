#!/usr/bin/perl -w

=head1 plain2mm-xml.pl

=head1 SYNOPSIS

This program converts plain text to MetaMap xml formatted text  
with the target words tagged with the <Target> xml tag. 

=head1 USAGE

perl plain2mm-xml.pl SOURCE DESTINATION

=head2 SOURCE
 
=head2 DESTINATION

=head2 Optional Arguments:

=head3 --log DIRECTORY

Directory to contain temporary and log files. DEFAULT: log

=head3 --metamap TWO DIGIT YEAR

Specifies which version of metap to use. The default is 10 which will 
run metamap10.   

=head3 --help

Displays the quick summary of program options.

=head3 --version

Displays the version information.

=head1 OUTPUT

metamap xml format with the target words tagged with the 
<Target> xml tag. 

=head1 PROGRAM REQUIREMENTS

=over

=item * Perl (version 5.8.5 or better) - http://www.perl.org

=back

=head1 AUTHOR

 Bridget T. McInnes, University of Minnesota, Twin Cities

=head1 COPYRIGHT

 Copyright (c) 2011
 Bridget T. McInnes, University of Minnesota, Twin Cities
 bthomson at umn.edu

 Ted Pedersen, University of Minnesota Duluth
 tpederse at d.umn.edu

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to 

 The Free Software Foundation, Inc.,
 59 Temple Place - Suite 330,
 Boston, MA  02111-1307, USA.

=cut

	
###############################################################################

#                               THE CODE STARTS HERE
###############################################################################

#                           ================================
#                            COMMAND LINE OPTIONS AND USAGE
#                           ================================

use Getopt::Long; 
use XML::Twig;
use File::Spec;

eval(GetOptions( "version", "help" , "log=s", "metamap=s"))or die ("Please check the above mentioned option(s).\n");


#  if help is defined, print out help
if( defined $opt_help ) {
    $opt_help = 1;
    &showHelp();
    exit;
}

#  if version is requested, show version
if( defined $opt_version ) {
    $opt_version = 1;
    &showVersion();
    exit;
}

#  set metamap
my $metamap = "metamap10";
if(defined $opt_metamap) {
    $metamap = "metamap" . "$opt_metamap";
}

#  set the log file
my $log = "log";
if(defined $opt_log) { $log = $opt_log; }

#  check if the output file  already exists
if( -e $log ) {
    print "LOG DIRECTORY ($log) already exists! Overwrite (Y/N)?";
    my $reply = <STDIN>;  chomp $reply; $reply = uc($reply);
    exit 0 if ($reply ne "Y"); 
} 
else { 
    system "mkdir log";
}


# At least 2 terms should be given on the command line.
if(scalar(@ARGV) < 2) {
    print STDERR "The input and output files must be given on the command line.\n";
    &minimalUsageNotes();
    exit;
}

my $output_file = shift;
my $input_file  = shift;


#  check that output file has been supplied
if( !($output_file) ) {
    print STDERR "No output file (DESTINATION) was supplied.\n";
    &askHelp();
    exit;
}

#  check if the output file  already exists
if( -e $output_file ) {
    print "DESTINATION ($output_file) already exists! Overwrite (Y/N)?";
    my $reply = <STDIN>;  chomp $reply; $reply = uc($reply);
    exit 0 if ($reply ne "Y"); 
} 

open(SRC, $input_file) || die "Could not open ($input_file) SOURCE\n";
open (my $fh_out, '>', $output_file) or die "Could not open ($output_file) DEST";

while(<SRC>) {

    chomp;

    $_=~s/\'s/s/g;

    $_=~/^(.*?)<head item=\"(.*?)\" instance=\"(.*?)\" sense=\"(.*?)\">(.*?)<\/head>(.*?)$/;
    $before = $1;	    $tw     = $2;
    $id     = $3;	    $sense  = $4;
    $after  = $6;
    
    #if($id ne "19309183.tx.1") { next; }
  
    $before=~s/\s*$//g; #$after=~s/^\s*//g;

    #print STDERR "*$before*\n\n";
    #print STDERR "*$after*\n\n";

    #  check if target word is between ();
    if($before=~/\($/)        { $before=~s/\($//g; }
    if($after=~/^[s\)\;\s+]/) { $after=~s/^\)//g;  }
    
    #  remove (tw) so metamap doesn't expand it on us
    $before=~s/\(\s*$tw\s*\)//g;
    $after=~s/\(\s*$tw\s*\)//g;
    $before=~s/[\[\]]//g;
    $after=~s/[\[\]]//g;
    $before=~s/\([A-Z\s\+]+\)//g;
    $after=~s/\([A-Z\s\+]+\)//g;

    #  set the text.
    my $text = "$before $tw $after";

    $before = &_clean($before);

    #print STDERR "$text\n\n\n";

    #  get the location of the target word
    my @beforearray = split/\s+/, $before;
    my $location = $#beforearray + 2;
    
    #print STDERR "$before\n";
    #print STDERR "$tw : $location\n";

    #  set the input and output files for metamap
    my $infile  = File::Spec->catfile("$log", "$tw.$id.raw");
    my $outfile = File::Spec->catfile("$log", "$tw.$id.xml");
    
    #  put the text without the tags in the 
    open(INFILE, ">$infile") || die "Could not open $infile\n";
    print INFILE "$text\n";
    close INFILE;


    #  process the text using metamap
    my $output = `$ENV{METAMAP_PATH}/$metamap -% format $infile $outfile 2>&1`;
    

    #  load the metamap xml output
    my $t= XML::Twig->new();
    $t->parsefile("$outfile");
    my $root = $t->root;
    
    #  loop through to find the target word and modify the <TOKEN>
    #  tag around it to <TARGET>
    my $method= $root; my $counter = 0; my $flag   = 0; 
    my $aatext = "";   my $aaexp = "";  my $tcount = 0;
    my $tcountflag = 0;
    while( $method=$method->next_elt( $root )) { 
	if($method->local_name eq "AAText") { 
	    $aatext = $method->text;
	}
	if($method->local_name eq "AAExp") { 
	    $aaexp = $method->text;
	}
	if($method->local_name eq "AATokenNum") {
	    
	    #  replace acronym with expansion
	    $before .= " ";
	    $before=~s/\s\($aatext\)[\.\s]/ $aaexp btm /g;
	    $before=~s/\s$aatext\s/ $aaexp /g;

	    #  replace acronym whose periods were removed with expansion
	    my $paatext = $aatext; $paatext=~s/\./ /g; $paatext=~s/\s*$//g;
	    $before=~s/\s\(?$paatext\)?\s/ $aaexp btm /g;
	    
	    #  replace acronym where space was introduced after the period
	    $paatext = $aatext; $paatext=~s/\./\. /g; $paatext=~s/\s*$//g;
	    $before=~s/\s\(?$paatext\)?\s/ $aaexp btm /g;
	    
	    #  replace acronym whose - or/ were removed with expansion
	    my $daatext = $aatext; $daatext=~s/[\-\/]/ /g; $daatext=~s/\s*$//g;
	    $before=~s/\s\(?$daatext[\)\(\.]?\s/ $aaexp btm /g;

	    #  seperate roman numerals eg AngII -> Ang II
	    my $saatext = $aatext; $saatext=~s/([A-Za-z]+)(II)/$1 $2/g;
	    $before=~s/\s\(?$saatext[\)\(\.]?\s/ $aaexp btm /g;

	    #  seperate upper from lower eg CBreceptors -> CB receptors
	    $saatext = $aatext; $saatext=~s/([A-Z]+)([a-z]+)/$1 $2/g;
	    $before=~s/\s\(?$saatext[\)\(\.]?\s/ $aaexp btm /g;

	    #  acronym is the first word
	    $before=~s/^$aatext /$aaexp btm /g;

	    #  remove duplicates
	    my $cleanaaexp = &_clean($aaexp); 
	    $before=~s/ $cleanaaexp \(?$aaexp\)? btm / $cleanaaexp /g;
	    $before=~s/ $aaexp \(?$aaexp\)? btm / $aaexp /g;
	    
	    #  remove btm 
	    $before=~s/btm//g;
	    
	    #  get the new location
	    $before = &_clean($before);
	    my @array = split/\s+/, $before;
	    $location = $#array + 2;
	    
	    #print STDERR "$aatext : $aaexp : $location\n";
	    #print STDERR "$before\n"; 
	}
	if ($method->local_name eq "Tokens") {
	    $tcount = $counter + 1;
	    $counter += $method->att("Count");
	    
	    #print STDERR "$counter : " . $method->att("Count") . " : ";
	    #print STDERR $method->text . "\n";
	    
	}
	if($method->local_name eq "Token") { 
	    if($counter >= $location and $flag == 0) { 
		if($tcount == $location) { 
		    $method->set_tag('Target');
		    $method->set_atts({'id' => $id, 'sense' => $sense});
		    $flag = 1; 
		}
	    }
	    $tcount++; 
	}
    
    }

    #  print the output
    $t->set_pretty_print( 'nice');
    $t->set_pretty_print( 'indented');
    print {$fh_out} $t->sprint();
}

sub _clean {
    
    my $line = shift;
   
    $line=~s/\'s / /g;
    
    # split up based on puncutation
    $line=~s/ \)?\. / /g;
    $line=~s/[\/\-\@\,\>\<\'=\+\:\%\&\[\]\?\;]/ /g;
    $line=~s/([0-9]+)[\(\.]([0-9]+)/$1 $2/g;
    $line=~s/([a-zA-Z]+)\.([A-Za-z]+)/$1 $2/g;
    $line=~s/([a-zA-Z]+)\)([A-Za-z]+)/$1 $2/g;
    $line=~s/([A-Za-z0-9]+)(\([A-Za-z0-9])/$1 $2/g;
    $line=~s/(\))(\.[a-z])/$1 $2/g;
    $line=~s/([0-9]+\))([A-Za-z])/$1 $2/g;
    $line=~s/([a-z]+\.)([0-9])/$1 $2/g;
    
    $line=~s/([a-zA-Z]+[0-9])\.([A-Za-z]+)/$1 $2/g;
    $line=~s/([0-9]+)\.([A-Z][a-z]+) /$1 $2 /g;
    $line=~s/([0-9]+)\.([A-Z]+) /$1 $2 /g;

    $line=~s/\s+[\)\.]+\s+/ /g;
    $line=~s/\)\(/\) \(/g;
    
    $line=~s/([A-Z]\))([0-9])/$1 $2/g;
    $line=~s/(\)\.)([A-Z])/$1 $2/g;
    $line=~s/\s\.$/ /g;
    $line=~s/ï/ /g;
    $line=~s/ç/ /g;
    $line=~s/ ([0-9])\.([0-9]) / $1 $2 /g;
    $line=~s/\ss\s/ /g;
    $line=~s/\*/ /g;

    #  if a ( is on its own remove it
    $line=~s/\s+\(\s+/ /g;
    $line=~s/\s+\)\s+/ /g;

    #  remove the white space
    $line=~s/\s+/ /g;
    $line=~s/^\s*//g; 
    $line=~s/\s*$//g;

    return $line;
}



##############################################################################
#  SUB FUNCTIONS
##############################################################################

#  function to output minimal usage notes
sub minimalUsageNotes {
    
    print STDERR "Usage: plain2mm-xml.pl [OPTIONS] DESTINATION SOURCE\n";
    askHelp();
}

#  function to output help messages for this program
sub showHelp() {

    print "Usage: plain2mm-xml.pl DESTINATION SOURCE\n\n";
    
    print "Takes as input a file in plain text and process it through\n";
    print "the concept mapping system MetaMap converting it to xml format.\n";

    print "OPTIONS:\n\n";

    print "--version                Prints the version number\n\n";

    print "--help                   Prints this help message.\n\n";
}

#  function to output the version number
sub showVersion {
        print '$Id: plain2mm-xml.pl,v 1.2 2011/04/14 12:51:57 btmcinnes Exp $';
        print "\nCopyright (c) 2011, Ted Pedersen & Bridget McInnes\n";
}

#  function to output "ask for help" message when user's goofed
sub askHelp {
    print STDERR "Type plain2mm-xml.pl --help for help.\n";
}
    

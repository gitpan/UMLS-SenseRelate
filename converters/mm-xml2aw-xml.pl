#!/usr/bin/perl -w

=head1 mm-xml2aw-xml.pl

=head1 SYNOPSIS

This program converts MetaMap xml formatted text to the 
all-words xml formatted text.

=head1 USAGE

perl mm-xml2aw-xml.pl SOURCE DESTINATION

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

 Copyright (c) 2007-2008,
 Bridget T. McInnes, University of Minnesota, Twin Cities
 bthomson at cs.umn.edu

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

eval(GetOptions( "version", "help" , "log=s"))or die ("Please check the above mentioned option(s).\n");


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

#  set the log file
my $log = "log";
if(defined $opt_log) { $log = $opt_log; }


# At least 2 terms should be given on the command line.
if(scalar(@ARGV) < 2) {
    print STDERR "The input and output files must be given on the command line.\n";
    &minimalUsageNotes();
    exit;
}

my $outfile = shift;
my $infile  = shift;

#  check that output file has been supplied
if( !($outfile) ) {
    print STDERR "No output file (DESTINATION) was supplied.\n";
    &askHelp();
    exit;
}

#  check if the output file  already exists
if( -e $outfile ) {
    print "DESTINATION ($outfile) already exists! Overwrite (Y/N)?";
    my $reply = <STDIN>;  chomp $reply; $reply = uc($reply);
    exit 0 if ($reply ne "Y"); 
} 

#  open the input and output files
open(INFILE, $infile) || die "Could not open $infile\n";
open(OUTFILE, ">$outfile") || die "Could not open $outfile\n";


my @abstracts = (); my $abstract = "";
while(<INFILE>) { 
    if($_=~/\<?xml version/) { 
	if($abstract ne "") { push @abstracts, $abstract; }
	$abstract = "";
    }
    $abstract .= $_;
}

#  print header information 
print OUTFILE "<?xml version=\"1.0\"?>\n";
print OUTFILE "<!DOCTYPE corpus SYSTEM  \"all-words.dtd\">\n";
print OUTFILE "<corpus lang=\"en\">\n";

my $abstractid = 0;
foreach my $abstract (@abstracts) { 
    
    if($abstract=~/^\s*$/) { next; }
    
    # increment id
    $abstractid++;
    
    #  print document id
    my $aid = sprintf("%03d", $abstractid);
    print OUTFILE "<text id=\"$aid\">\n";

    #  set the xml file for this abstract
    system "rm $infile.processing";    
    open(FILE, ">$infile.processing") || die "Could not open $infile.processing\n";
    print FILE "$abstract";
    close FILE;

    #  load the metamap xml output
    my $t= XML::Twig->new();
    $t->parsefile("$infile.processing");
    my $root = $t->root;


    #  initialize variables
    my @cuis    = (); 
    my @matches = ();
    my @tokens  = ();


    #  loop through tokens
    my $method= $root; my $sentenceid = 0; my $tokenid = 0;
    while( $method=$method->next_elt( $root )) { 
		
	if($method->local_name eq "UttText") { 
	    $sentenceid++; 
	    $tokenid = 0;
	}

	if($method->local_name eq "InputMatch") { 
	    my $token = $method->text; push @tokens, $token;
	}
	
	#  check if in mapping
	if($method->local_name eq "Mapping") { $flag = 1; }

	#  if in mapping, get the cui
	if( ($method->local_name eq "CandidateCUI") && ($flag = 1) ) { 
	    my $cui = $method->text; push @cuis, $cui;
	}

	#  if in mapping, get the cui
	if( ($method->local_name eq "CandidateMatched") && ($flag = 1) ) { 
	    my $match = $method->text; 
	    $match=~s/[\*\?\+\(\)\[\]\/ ]//g; 
	    push @matches, lc($match);
	}
	
	if($method->local_name eq "Phrase") { 

	    my %mappings = ();
	    foreach my $i (0..$#matches) { 
		my $term = $matches[$i]; my $mflag = 0;
		while($mflag == 0) {
		    foreach my $token (@tokens) {
			$token=lc($token);
			print "$token : $term ";
			if($token=~/$term/) {
			    $mappings{$token}{"$cuis[$i]/$matches[$i]"}++;
			    $mflag = 1; print "mapping";
			}
			print "\n";
		    }
		    print "====================================\n";
		    chop $term;
		    if($term=~/^\s*$/) { $mflag = 1; }
		}
	    }
	    foreach my $token (@tokens) { 
		my $tok = lc($token);
		$tokenid++;
		
		my $a = sprintf("%03d", $abstractid);
		my $s = sprintf("%03d", $sentenceid);
		my $t = sprintf("%03d", $tokenid);
		my $id = "d$a.s$s.t$t";
		
		my $senses = "";
		foreach my $m (sort keys %{$mappings{$tok}}) { 
		    $m=~/(C[0-9]+)\//;
		    $senses .= "$1,";
		} chop $senses;

		if($senses=~/^\s*$/) { print OUTFILE "$token\n"; }
		else                 { print OUTFILE "<head id=\"$id\" candidates=\"$senses\">$token<\/head>\n"; }
	    }
	    @tokens  = ();;
	    @cuis    = ();
	    @matches = ();
	}
    }
    print OUTFILE "<\/text>\n";
}

print OUTFILE "<\/corpus>\n";


##############################################################################
#  SUB FUNCTIONS
##############################################################################

#  function to output minimal usage notes
sub minimalUsageNotes {
    
    print STDERR "Usage: mm-xml2aw-xml.pl [OPTIONS] DESTINATION SOURCE\n";
    askHelp();
}

#  function to output help messages for this program
sub showHelp() {

    print "Usage: mm-xml2aw-xml.pl DESTINATION SOURCE\n\n";
    
    print "Takes as input a machine code MetaMap file and converts it\n";
    print "to all-words xml format for umls-allwords-senserelate.pl.\n\n";

    print "OPTIONS:\n\n";

    print "--version                Prints the version number\n\n";

    print "--help                   Prints this help message.\n\n";
}

#  function to output the version number
sub showVersion {
        print '$Id: mm-xml2aw-xml.pl,v 1.2 2011/04/14 12:51:57 btmcinnes Exp $';
        print "\nCopyright (c) 2007, Ted Pedersen & Bridget McInnes\n";
}

#  function to output "ask for help" message when user's goofed
sub askHelp {
    print STDERR "Type mm-xml2aw-xml.pl --help for help.\n";
}

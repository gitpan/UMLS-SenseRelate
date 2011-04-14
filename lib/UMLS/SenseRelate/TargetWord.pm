# UMLS::SenseRelate::TargetWord
# (Last Updated $Id: TargetWord.pm,v 1.14 2011/04/13 15:43:44 btmcinnes Exp $)
#
# Perl module that performs SenseRelate style target word WSD
#
# Copyright (c) 2010-2011,
#
# Bridget T. McInnes, University of Minnesota, Twin Cities
# bthomson at umn.edu
# 
# Serguei Pakhomov, University of Minnesota, Twin Cities
# pakh0002 at umn.edu
#
# Ted Pedersen, University of Minnesota, Duluth
# tpederse at d.umn.edu
#
# Ying Liu, University of Minnesota, Twin Cities
# liux0935 at umn.edu
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to 
#
# The Free Software Foundation, Inc., 
# 59 Temple Place - Suite 330, 
# Boston, MA  02111-1307, USA.

package UMLS::SenseRelate::TargetWord;

use UMLS::SenseRelate;

use Fcntl;
use strict;
use warnings;
use DBI;
use bytes;

use UMLS::Interface;
use UMLS::Similarity;
use UMLS::SenseRelate::ErrorHandler;

#  module handler variables
my $umls         = "";
my $mhandler      = "";
my $errorhandler = "";

#  senserelate options
my $stoplist      = undef;
my $stopregex     = undef;
my $window        = undef;
my $compound      = undef;
my $trace         = undef;
my $measure       = undef;

local(*TRACE);

my %cache = ();

my $pkg = "UMLS::SenseRelate::TargetWord";

use vars qw($VERSION);

my $debug = 0;


# -------------------- Class methods start here --------------------

#  method to create a new UMLS::Similarity object
#  input : $params <- reference to hash containing the parameters 
#  output:
sub new {

    my $self        = {};
    my $className   = shift;
    my $umlshandler = shift;
    my $meashandler = shift;
    my $params    = shift;

    my $function = "new";

    # bless the object.
    bless($self, $className);

    # initialize error handler
    $errorhandler = UMLS::SenseRelate::ErrorHandler->new();
    if(! defined $errorhandler) {
	print STDERR "The error handler did not get passed properly.\n";
	exit;
    }

    #  set the UMLS::Interface handler
    $umls = $umlshandler;
    if(! defined $umls) { 
	my $str = "UMLS::Interface handler not defined.";
	$errorhandler->_error($pkg, $function, $str, 2);	
    }

    #  set the UMLS::Interface handler
    $mhandler = $meashandler;
    if(! defined $mhandler) { 
	my $str = "UMLS::Similarity measure handler not defined.";
	$errorhandler->_error($pkg, $function, $str, 3);	
    }

    #  check options
    $self->_setOptions($params);
    
    return $self;
}

#  method sets the stoplist
#  input : $senses    <- reference to an array containing 
#                        the CUIs of the possible senses
#          $instance  <- string containing the instance
#  output: $cui, $max <- the cui with the highest similarity score
#                        and its associated score 
sub assignSense {
    
    my $self      = shift;
    my $target    = shift;
    my $instance  = shift;
    my $senseref  = shift;

    my $function = "_assignSense";

    #  check self
    if(!defined $self || !ref $self) {
	$errorhandler->_error($pkg, $function, "", 1);
    }
    
    # check that the parameters are passed
    if(!defined $target) { 
	my $str = "Error with input variable \$target.";
	$errorhandler->_error($pkg, $function, $str, 4); 
    }
    if(!defined $instance) { 
	my $str = "Error with input variable \$instance.";
	$errorhandler->_error($pkg, $function, $str, 4); 
    }

    #  get the terms or CUIs in the specified window of the instance
    my $line = $self->_getWindow($instance);    
    my @terms = split/\s+/, $line;

    #  initialize the return hash containing the senses and the scores
    my %sensescores = ();

    #  get the possible senses of the target word
    my @senses = ();
    if(defined $senseref) { 
	foreach my $sense (@{$senseref}) { push @senses, $sense; }
    }
    else {
	if($measure=~/vector|lesk/) { 
	    @senses = $umls->getDefConceptList($target);
	}
	else {
	    @senses = $umls->getConceptList($target);
	}
    }

    #  check to make certain there exists a possible sense other
    #  wise return 
    if($#senses < 0) { return undef; }
    
    if(defined $trace) { 
	print TRACE "TARGET WORD: $target\n";
	print TRACE "POSSIBLE SENSES: @senses\n";
    }
    
    #  foreach sense determine the similarity
    foreach my $sense (@senses) { 
	
	my $sensescore = 0; my $termcounter = 0;

	if(defined $trace) { print TRACE " Processing sense ($sense)\n"; }

	foreach my $term (@terms) { 
	    
	    if($term=~/^\s*$/) { next; }
	 
	    #  get the term's CUI if it not one
	    my @cuis = ();
	    if($term=~/C[0-9][0-9][0-9][0-9][0-9][0-9][0-9]/) { 
		push @cuis, $term; 
	    }
	    else { 
		$term = lc($term);
		$term=~s/[\<\>\.\,\?\/\!\@\#\$\%\^\&\*\(\)\[\]\{\}\'\"\:\;\\]//g;

		#  if the compound option is defined the instance contains 
		#  compounds which are denoted by an underscore
		if(defined $compound) { $term=~s/_/ /g; }

		#  get the terms associated concepts
		if($measure=~/vector|lesk/) { 
		    @cuis = $umls->getDefConceptList($term); 
		}
		else {
		    @cuis = $umls->getConceptList($term); 
		}
	    }

	    if(defined $trace) { 
		if($#cuis >= 0) { print TRACE "  Processing term: '$term' (@cuis)\n"; }
		else            { print TRACE "  Processing term: '$term' (No Mapping)\n"; }
	    }

	    #  get the highest similarity score between the 
	    #  sense and the given cuis
	    my $value = -1;
	    foreach my $cui (@cuis) {
		my $score = "";

		#  check if the similarity score is in the cache
		if(exists $cache{$sense}{$cui}) { $score = $cache{$sense}{$cui}; }

		#  otherwise go get it and then put it there
		else { 
		    $score = $mhandler->getRelatedness($sense, $cui); 
		    $cache{$sense}{$cui} = $score;
		}
	
		if(defined $trace) { print TRACE "    Relatedness($cui, $sense) = $score\n"; }

		#  check if it is the highest and if so save it
		if($score > $value) { $value = $score; }
	    }
	    
	    #  so if their is a similarity between the term/CUI and sense 
	    #  save the highest term-sense score 
	    if($value >= 0) { 
		$sensescore += $value; $termcounter++;
		if(defined $trace) { 
		    print TRACE "    Increment sense's score by $value to total $sensescore\n";
		}
	    }
	    
	}

	#  average the sense score
	if($termcounter > 0) { $sensescore = $sensescore / $termcounter; }
	
	#  store the sense score for that possible sense
	$sensescores{$sense} = $sensescore;
	    
	if(defined $trace) { 
	    print TRACE " Overall similarity for $sense = $sensescore\n"; 
	}

    }

    #  right now we are just returning a single sense and its
    #  associated similarity score - in the future we will have
    #  the possibility of returning more than a single sense
    #  to return more than a single 
    my $max = -1; my $cui = "NONE"; my %returnhash = ();
    foreach my $sense (sort keys %sensescores) {
	if($sensescores{$sense} > $max) { 
	    $cui = $sense;
	    $max = $sensescores{$sense};
	}
    }
    
    $returnhash{$cui} = $max;
    
    if(defined $trace) { 
	print TRACE "Returning Sense $cui with score $max\n";
	print TRACE "================================================\n";
    }

    #return \%sensescores;
    return \%returnhash;
}

#  method obtains the terms in the window from the instance
#  input : $instance <- string containing the full instance
#  output: $line     <- string containing the terms in the window
sub _getWindow {

    my $self = shift;
    my $instance = shift;

    my $function = "_getWindow";
    &_debug($function);

    #  check self
    if(!defined $self || !ref $self) {
	$errorhandler->_error($pkg, $function, "", 1);
    }
    
    # check that the parameters are passed
    if(!defined $instance) { 
	my $str = "Error with input variable \$instance.";
	$errorhandler->_error($pkg, $function, $str, 4); 
    }    
    if(! ($instance=~/<head/)) { 
	my $str = "Instance ($instance) not in proper format.";
	$errorhandler->_error($pkg, $function, $str, 5);
    }
    
    #  get the words or CUIs surrounding the target word
    $instance=~/^(.*?)<head item=\"(.*?)\" instance=\"(.*?)\">(.*?)<\/head>(.*?)$/;
    my $before = $1;
    my $tw     = $2;
    my $id     = $3;
    my $after  = $5;

    my $line = "";

    # if the window size is not defined we just use the entire context
    if(! defined $window) { 
	$instance=~s/<head (.*?)>//g;
	$instance=~s/<\/head>//g;
	
	#  if the compound option is not defined remove the underscores
	if(! (defined $compound) ) { $instance=~s/_/ /g; }
	   
	#  remove extraneous white space
	$instance=~s/\s+/ /g;
	$instance=~s/^\s*//g; 
	$instance=~s/\s*$//g;
	
	#  if stoplist defined remove the stoplist terms
	if(defined $stopregex) { 
	    my @array = split/\s+/, $instance;
	    foreach my $term (@array) { 
		if(! ($term=~/$stopregex/)) {
		    $line .= "$term ";
		}
	    }
	}
	#  otherwise just use the entire instance as is
	else { $line = $instance; }
	
    }
    #  otherwise get the terms from the window
    else {

	#  get the terms before and after the target word
	$before=~s/[<>]//g;
	$after=~s/[<>]//g;

	# if the compund option is not set remove the underscores
	if(!(defined $compound)) { $before=~s/_/ /g; $after=~s/_/ /g; }

	#  remove extraneous white space
	$before=~s/^\s*//g;	    $before=~s/\s*$//g;
	$after=~s/^\s*//g;	    $after=~s/\s*$//g;
	
	#  get the individual words or terms
	my @beforearray = split/\s+/, $before;
	my @afterarray = split/\s+/, $after;
	
	#  add those terms in the window to the return string $line
	my $bi = 1; my $ai = 1;
	while($bi <= $window || $ai <= $window) { 
	    
	    my $beforeterm = "";
	    my $afterterm  = "";

	    if($#beforearray > -1) { $beforeterm = pop @beforearray; }
	    if($#afterarray > -1)  { $afterterm = shift @afterarray; }
	    
	    #  if there is a stoplist only add those non-stopword terms
	    if(defined $stopregex) { 
		if(! ($beforeterm=~/$stopregex/)) {
		    $line .= "$beforeterm "; $bi++;
		}
		if(! ($afterterm=~/$stopregex/)) { 
		    $line .= "$afterterm "; $ai++;
		}
	    }
	    #  other wise just add what is given
	    else {
		$line .= "$beforeterm $afterterm ";
		$ai++; $bi++;
	    }
	}
    }
    
    #  return the string containing the terms (or CUIs) in the window
    return $line;
}

#  method sets the parameters for the UMLS::SenseRelate package
#  input : $params <- reference to hash containing the parameters 
#  output:
sub _setOptions {

    my $self = shift;
    my $params = shift;

    my $function = "_checkOptions";

    #  check self
    if(!defined $self || !ref $self) {
	$errorhandler->_error($pkg, $function, "", 1);
    }
    
    $params = {} if(!defined $params);

    #  get all the parameters
    $stoplist      = $params->{'stoplist'};
    $window        = $params->{'window'};
    $compound      = $params->{'compound'};
    $trace         = $params->{'trace'};
    $measure       = $params->{'measure'};

    #  set the stoplist
    if(defined $stoplist) { 
	$stopregex = $self->_setStopList($stoplist); 
    }

    #  set the trace
    if(defined $trace) { 
	open(TRACE, ">$trace") || die "Could not open trace file ($trace).\n";
    }

    #  set the measure
    if(! (defined $measure)) { 
	$measure = "path";
    }
}

#  method sets the stoplist
#  input : $stoplist <- file containing stoplist
#  output: $regex    <- string containing regex
sub _setStopList {
    my $self     = shift;
    my $stoplist = shift;

    my $function = "_setStoplist";
    &_debug($function);

    if(!defined $self || !ref $self) {
        $errorhandler->_error($pkg, $function, "", 1);
    }

    
    # check that the parameters are passed
    if(!defined $stoplist) { 
	my $str = "Error with input variable \$stoplist.";
	$errorhandler->_error($pkg, $function, $str, 4); 
    }

    open(STOP, $stoplist) || die "Could not open $stoplist\n";
    my $regex = "(";
    while(<STOP>) { 
	chomp;
	$_=~s/^\///g;
	$_=~s/\/$//g;
	$regex .= "$_|";
    }
    chop $regex;
    $regex .= ")";
    
    return $regex;
}

#  returns the version of the UMLS currently being used
#  input :
#  output: $version <- string containing version
sub _version {

    return $VERSION;
}

#  print out the function name to standard error
#  input : $function <- string containing function name
#  output:
sub _debug {
    my $function = shift;
    if($debug) { print STDERR "In UMLS::SenseRelate::$function\n"; }
}

1;

__END__

=head1 NAME

UMLS::SenseRelate::TargetWord - A Perl module that implement the
target word word sense disambiguation using the sense relate wsd 
algorithm based on the  semantic similarity and relatedness options 
from the UMLS::Similarity package.

=head1 DESCRIPTION

This package provides an implementation of the senserelate word sense 
disambiguation algorithm using the semantic similarity and relatedness 
options from the UMLS::Similarity package.

=head1 SYNOPSIS

 use UMLS::Similarity;
 use UMLS::SenseRelate::TargetWord;

 #  initialize option hash and umls
 my %option_hash = ();
 my $umls        = "";
 my $meas        = "";
 my $senserelate = "";
 my $params      = "";

 #  set interface     
 $option_hash{"t"} = 1;
 $option_hash{"realtime"} = 1;
 $umls = UMLS::Interface->new(\%option_hash);

 #  set measure
 use UMLS::Similarity::path;
 $meas = UMLS::Similarity::path->new($umls);

 #  set senserelate
 $params{"measure"} = "path";
 $senserelate = UMLS::SenseRelate::TargetWord->new($umls, $meas, \%params);

#  set the target word
 my $tw = "adjustment";        

 #  provide an instance where the target word is in <head> tags
 my $instance = "Fifty-three percent of the subjects reported below average ";
    $instance .= "marital <head>adjustment</head>.";

 my ($hashref) = $senserelate->assignSense($tw, $instance, undef);

 if(defined $hashref) {
    print "Target word ($tw) was assigned the following sense(s):\n";
    foreach my $sense (sort keys %{$hashref}) {
      print "  $sense\n";
    }
 }
 else {
    print "Target word ($tw) has no senses.\n";
 }

=head1 INSTALL

To install the module, run the following magic commands:

  perl Makefile.PL
  make
  make test
  make install

This will install the module in the standard location. You will, most
probably, require root privileges to install in standard system
directories. To install in a non-standard directory, specify a prefix
during the 'perl Makefile.PL' stage as:

  perl Makefile.PL PREFIX=/home/bridget

It is possible to modify other parameters during installation. The
details of these can be found in the ExtUtils::MakeMaker
documentation. However, it is highly recommended not messing around
with other parameters, unless you know what you're doing.

=head1 DESCRIPTION

=head1 PARAMETERS

=head2 UMLS::SenseRelate parameters

  'window  '     -> This parameter determines the window size of the 
                    context on each side of the target word to be used 
                    for disambiguation

  'stoplist'     -> This parameter disregards stopwords when creating 
                    the window created on the fly (in realtime). 

  'compound'     -> This parameter indicates that compounds exist in 
                    the input instance denoted by an underscore

  'trace'        -> This parameters indicates that the trace information
                    should be printed out to the file 

=head1 SEE ALSO

http://tech.groups.yahoo.com/group/umls-similarity/

http://search.cpan.org/dist/UMLS-Similarity/

=head1 AUTHOR

Bridget T McInnes <bthomson@umn.edu>
Ted Pedersen <tpederse@d.umn.edu>

=head1 COPYRIGHT

 Copyright (c) 2010-2011
 Bridget T. McInnes, University of Minnesota, Twin Cities
 bthomson at umn.edu

 Ted Pedersen, University of Minnesota, Duluth
 tpederse at d.umn.edu

 Serguei Pakhomov, University of Minnesota, Twin Cities
 pakh0002 at umn.edu

 Ying Liu, University of Minnesota, Twin Cities
 liux0935 at umn.edu

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

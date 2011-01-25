#!/usr/local/bin/perl -w

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/lch.t'

#  This scripts tests the functionality of the utils/ programs

use strict;
use warnings;

use Test::More tests => 5;

BEGIN{ use_ok ('File::Spec') }

my $perl     = $^X;
my $util_prg = "";

my $output   = "";

#######################################################################################
#  check the umls-senserelate.pl program
#######################################################################################

$util_prg = File::Spec->catfile('utils', 'umls-senserelate.pl');
ok(-e $util_prg);

#  check no command line inputs
$output = `$perl $util_prg 2>&1`;
like ($output, qr/The input file or directory must be given on the command line.\s*Type umls-senserelate\.pl --help for help\.\s*Usage\: umls-senserelate\.pl \[OPTIONS\] INPUTFILE/);


#######################################################################################
#  check the umls-senserelate.pl program
#######################################################################################

$util_prg = File::Spec->catfile('utils', 'umls-senserelate-evaluation.pl');
ok(-e $util_prg);

#  check no command line inputs
$output = `$perl $util_prg 2>&1`;
like ($output, qr/The umls-senserelate log directory must be given on the command line.\s*Type umls-senserelate-evaluation\.pl --help for help\.\s*Usage\: umls-senserelate-evaluation\.pl \[OPTIONS\] LOG\_DIRECTORY/);


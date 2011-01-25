# This -*- perl -*- script writes the Makefile for UMLS::Similarity
# (Last Updated 08/09/2004 -- Sid)
#
# Generates the Makefile for the UMLS::Similarity Perl modules. 
#
# ----------------------------------------------------------------------

use 5.005;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $author4 = 'Ying Liu <liux0395@umn.edu>';
my $author3 = 'Serguei Pakhomov <pakh0002@umn.edu>';
my $author2 = 'Ted Pedersen <tpederse@d.umn.edu>';
my $author1 = 'Bridget McInnes <bthomson@umn.edu>';

WriteMakefile(
              'NAME'		  => 'UMLS::SenseRelate',
              'VERSION_FROM'	  => 'lib/UMLS/SenseRelate.pm',
              'PREREQ_PM'         => {'UMLS::Interface' => '0.89',
				      'UMLS::Similarity'=> '0.89',
                                      'File::Spec' => '3.31',
                                      'File::Path' => '2.08'},
	      'EXE_FILES'         => [("utils/umls-senserelate.pl",
				       "utils/umls-senserelate-evaluation.pl", 
				       "External/scorer/score.pl")],
              'dist'              => {'COMPRESS' => 'gzip -9f', 'SUFFIX' => 'gz'},
              ($] >= 5.005 ?
               ('ABSTRACT_FROM'   => '', # retrieve abstract from module
                'AUTHOR'          => "$author1, $author2, $author3, $author4") : ()));


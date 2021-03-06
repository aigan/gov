# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

BEGIN { require 5.010 }
use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
	      'NAME'	       => 'GOV',
	      'PMLIBDIRS'      => [],
	      'SKIP'           => ['all','install'],
 	      'VERSION_FROM'   => 'bin/gov', # finds $VERSION
#	      'ABSTRACT_FROM'  => 'bin/gov',
	      'AUTHOR'         => 'Jonas Liljegren <jonas@paranormal.se>',
 	      'PREREQ_PM'      =>
	      {
#	       'Para::Frame'                => 1.22,
#	       'RDF::Base'                  => 6.66,
	       'Authen::CAS::Client'        => 0.05,
	       'Voting::Condorcet::RankedPairs' => 1.01,
#	       'Statistics::Basic::Median' => 1.66,
               'WWW::Curl::Simple'         => 0.10,
	      },
	      'dist'          =>
	      {
		  'COMPRESS' => 'gzip',
		  'SUFFIX'   => 'gz',
	      }
);

package MY; # so that "SUPER" works right
sub test
{
    my $inherited = shift->SUPER::test(@_);
    $inherited =~ s/test_dynamic :: pure_all/test_dynamic ::/;
    return $inherited;
}

sub test_via_harness
{
    my($self, $perl, $tests) = @_;

    return qq{\t$perl "-MExtUtils::Command::MM" }.
           qq{"-e" "test_harness(\$(TEST_VERBOSE), 'lib')" $tests\n};
}


1;

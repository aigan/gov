# -*-cperl-*-
package ActiveDemocracy::Proposition;

use Para::Frame::Reload;

=head1 NAME

Para::Resource

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );
use Para::Frame::Widget qw( jump );
use Para::Frame::L10N qw( loc );

use Rit::Base::Constants qw( $C_proposition_area_sweden );
use Rit::Base::Resource;
use Rit::Base::Utils qw( parse_propargs is_undef );


##############################################################################

sub register_vote
{
    my( $proposition, $u, $vote_in ) = @_;

    $vote_in = lc $vote_in;

    my $vote_parsed = 0;
    $vote_parsed = 1
      if( $vote_in eq 'yay' or
	  $vote_in eq 'yes' or
	  $vote_in eq 1 );
    $vote_parsed = -1
      if( $vote_in eq 'nay' or
	  $vote_in eq 'no' or
	  $vote_in eq -1 );


#    my $vote = $R->
}

##############################################################################


1;

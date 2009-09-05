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

#use Rit::Base::Constants qw( $C_proposition_area_sweden );
use Rit::Base::Resource;
use Rit::Base::Utils qw( parse_propargs is_undef );


##############################################################################

#sub wu_vote
#{
#    throw('incomplete', loc('Internal error: Proposition is without type.'));
#}


##############################################################################

sub wp_jump
{
    my( $proposition ) = @_;

    my $home = $Para::Frame::REQ->site->home_url_path;


    return jump($proposition->name->loc, $home ."/proposition/display.tt",
		{
		 id => $proposition->id,
		});
}

##############################################################################

sub area
{
    my( $proposition ) = @_;

    return $proposition->subsides_in->get_first_nos;
#      || $C_proposition_area_sweden;
}


##############################################################################

#sub register_vote
#{
#    throw('incomplete', loc('Internal error: Proposition is without type.'));
#}


##############################################################################

1;

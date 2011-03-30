# -*-cperl-*-
package GOV::Resolution::Method::Progressive;

=head1 NAME

GOV::Resolution::Method::Progressive

=cut

=head1 DESCTIPTION

Progressive resolution method requires that the proposition type has
get_vote_integral, resolution_progressive_weight

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );

use Rit::Base::Literal::Time qw( now timespan );
use DateTime::Infinite;

##############################################################################

sub should_resolve
{
    my( $method, $prop ) = @_;

    my $integral = abs $prop->get_vote_integral;
    my $weight = $prop->resolution_progressive_weight || 7;
    my $goal     = $weight * 24 * 60 * 60;

    return $integral > $goal;
}

##############################################################################

sub predicted_resolution_date
{
    my( $method, $prop ) = @_;

    if( $prop->{'gov'}{'end_time'} )
    {
	return $prop->{'gov'}{'end_time'};
    }

    my $future = DateTime::Infinite::Future->new();

    my $count        = $prop->get_vote_count;
    return $future
      unless( $count->{sum} );

    my $area         = $prop->subsides_in;
    my $member_count = $area->revlist('has_voting_jurisdiction')->size
      or return $future;

    my $integral = abs $prop->get_vote_integral;
    my $weight = $prop->resolution_progressive_weight || 7;
    my $goal     = $weight * 24 * 60 * 60
      or return $future;
    my $speed    = abs $count->{sum} / $member_count;
    my $duration = ($goal - $integral) / $speed;
    my $now      = now();

    my $prediction = $now->add( seconds => $duration );

    #debug "Integral   : $integral";
    #debug "Goal       : $goal";
    #debug "Left       : " . ($goal - $integral);
    #debug "Duration   : $duration";
    #debug "Now        : " . now();
    #debug "Speed      : $speed";
    #debug "Prediction : $prediction";

    return $prop->{'gov'}{'end_time'} = $prediction;
}



##############################################################################





1;

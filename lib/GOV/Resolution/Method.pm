# -*-cperl-*-
package ActiveDemocracy::Resolution::Method;

use 5.010;
use strict;
use warnings;
use utf8;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );

use Rit::Base::Literal::Time qw( now timespan );

##############################################################################

# these should be in Progressive, but there is no "node_handled_by_perl_module"-pred...
sub should_resolve
{
    my( $method, $proposition ) = @_;

    my $integral = abs $proposition->get_vote_integral;
    my $goal     = $proposition->resolution_progressive_weight * 24 * 60 * 60;

    return $integral > $goal;
}

sub predicted_resolution_date
{
    my( $method, $proposition ) = @_;

    my $count        = $proposition->get_vote_count;
    return undef
      unless( $count->{sum} );

    my $area         = $proposition->subsides_in;
    my $member_count = $area->revlist('has_voting_jurisdiction')->size
      or return undef;

    my $integral = abs $proposition->get_vote_integral;
    my $goal     = $proposition->resolution_progressive_weight * 24 * 60 * 60
      or return undef;
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

    return $prediction;
}


##############################################################################

1;

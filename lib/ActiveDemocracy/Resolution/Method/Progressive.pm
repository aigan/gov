# -*-cperl-*-
package ActiveDemocracy::Resolution::Method::Progressive;

=head1 NAME

ActiveDemocracy::Resolution::Method::Progressive

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


sub should_resolve
{
    my( $method, $proposition ) = @_;

    my $integral = $proposition->get_vote_integral;
    my $goal     = $proposition->resolution_progressive_weight;

    return $integral > $goal;
}

sub predicted_resolution_date
{
    my( $method, $proposition ) = @_;

    my $count        = $proposition->sum_all_votes;
    my $area         = $proposition->subsides_in;
    my $member_count = $area->revlist('has_voting_jurisdiction').size
      or return 0;

    my $integral = $proposition->get_vote_integral;
    my $goal     = $proposition->resolution_progressive_weight;
    my $speed    = abs $count->{sum} / $member_count;
    my $duration = ($goal - $integral) / $speed;
    my $now      = now();

    my $prediction = $now->add( days => $duration );

    debug "Duration   : $duration";
    debug "Now        : $now:";
    debug "Prediction : $prediction:";

    return $prediction;
}

1;

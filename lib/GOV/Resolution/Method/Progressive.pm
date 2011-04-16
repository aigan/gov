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

sub vote_chart_svg
{
    return vote_integral_chart_svg(@_);
}

##############################################################################

=head2 vote_integral_chart_svg

=cut

sub vote_integral_chart_svg
{
    my( $method, $prop ) = @_;

    my $vote_arcs = $prop->get_all_votes()->revarc_list('places_vote')->flatten->sorted({on=>'activated',cmp=>'<=>'});

#    debug( datadump( $vote_arcs, 2 ) );

    $vote_arcs->reset;

    my $resolution_weight = $prop->resolution_progressive_weight || 7;
    my $member_count = $prop->area->revlist('has_voting_jurisdiction')->size
      or return '';

    my @markers;
    my $current_level = 0;
    my $current_y = 0;
    my $last_time = 0;
    my $base_time;

    while( my $vote_arc = $vote_arcs->get_next_nos ) {
        my $vote = $vote_arc->obj;
        next unless( $vote->weight );

        my $time = $vote->revarc('places_vote')->activated->epoch;
        $base_time //= $time;

        my $rel_time = ($time - $base_time) / 24 / 60 / 60;

        # Speed, in votedays per day
        $current_y += ($rel_time - $last_time) * $current_level;

        push @markers, { x => $rel_time, y => $current_y };

        $current_level += $vote->weight;
        $last_time = $rel_time;

#        debug "$rel_time - $current_level";

    }
    my $now = now()->epoch;

    $base_time //= $now;

    my $rel_time = ($now - $base_time) / 24 / 60 / 60;
    $current_y += ($rel_time - $last_time) * $current_level;
#    debug "$rel_time - $current_level";
    push @markers, { x => $rel_time, y => $current_y };

    debug( datadump( \@markers ) );

    my $resolution_goal = $resolution_weight * $member_count;

    debug "Resolution goal: $resolution_goal";

    return Para::Frame::SVG_Chart->
      curve_chart_svg(
                      [
                       {
                        color => 'red',
                        markers => \@markers,
                       }
                      ],
                      min_y => -$resolution_goal * 1.2,
                      max_y => $resolution_goal * 1.2,
                      grid_h => $resolution_goal,
                      line_w => 0.1,
                     );

}

##############################################################################





1;

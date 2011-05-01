# -*-cperl-*-
package GOV::Proposition::Ranked;

#=============================================================================
#
# AUTHOR
#   Fredrik Liljegren   <fredrik@liljegren.org>
#
# COPYRIGHT
#   Copyright (C) 2009-2011 Fredrik Liljegren
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#=============================================================================

=head1 NAME

GOV::Proposition::Ranked

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use Carp qw( confess croak carp );
use Voting::Condorcet::RankedPairs;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );
use Para::Frame::Widget qw( jump hidden submit go );
use Para::Frame::L10N qw( loc );

use Rit::Base::Constants qw( $C_vote);
use Rit::Base::Resource;
use Rit::Base::Utils qw( parse_propargs is_undef query_desig );
use Rit::Base::List;
use Rit::Base::Literal::Time qw( now timespan );
use Rit::Base::Widget qw( locn aloc locnl alocpp );

##############################################################################

sub register_vote
{
    my( $prop, $u, $vote_in ) = @_;
    my( $args, $arclim, $res ) = parse_propargs('active');

    my $vote_parsed = 0;
    my $changed     = 0;
    my $R           = Rit::Base->Resource;


    # Parse the in-data

    my @votes = split ',', $vote_in;
    my( @yay, @nay );

    while( my $vote_str = shift @votes )
    {
	last if $vote_str eq '|';

	$vote_str =~ /^gov_(\d+)$/ or next;
	my $alt = $R->get($1);
	next unless $prop->has_value({'has_alternative' => $alt}, $args);
	unshift @yay, $alt;
    }

    while( my $vote_str = shift @votes )
    {
	$vote_str =~ /^gov_(\d+)$/ or next;
	my $alt = $R->get($1);
	next unless $prop->has_value({'has_alternative' => $alt}, $args);
	push @nay, $alt;
    }

    my $vote = $R->set_one({rev_has_vote => $prop,
			    rev_places_vote => $u,
			    is => $C_vote,
			   }, $args);

    my( %r_old_alts );
    my $old_alts = $vote->arc_list('places_alternative', undef, $args);
    while( my $arc = $old_alts->get_next_nos )
    {
	$r_old_alts{ $arc->obj->id } = $arc;
    }

    for( my $i=0; $i<=$#yay; $i++ )
    {
	my $alt = $yay[$i];
	if( my $old_arc = delete $r_old_alts{ $alt->id } )
	{
	    next if $old_arc->weight == $i+1;
	    $old_arc->set_weight($i+1, $args);
	    next;
	}

	$vote->add({'places_alternative' => $alt}, {%$args, arc_weight => $i+1});
    }

    for( my $i=0; $i<=$#nay; $i++ )
    {
	my $alt = $nay[$i];
	if( my $old_arc = delete $r_old_alts{ $alt->id } )
	{
	    next if $old_arc->weight == -($i+1);
	    $old_arc->set_weight(-($i+1), $args);
	    next;
	}

	$vote->add({'places_alternative' => $alt}, {%$args, arc_weight => -($i+1)});
    }

    foreach my $old_arc ( values %r_old_alts )
    {
	$old_arc->remove($args);
    }


    # Activate changes
    $res->autocommit({ activate => 1 });

    $prop->clear_caches;
}


##############################################################################

=head2 sum_all_votes

Makes a hash summary of the votes.  This should mainly be called from
GOV::Proposition->get_vote_count, that caches the result.

=cut

sub sum_all_votes
{
    my( $prop ) = @_;

    my $votes = $prop->get_all_votes;
    my $blank = 0;
    my $sum   = 0;

    foreach my $vote ( $votes->as_array )
    {
	if( $vote->places_alternative )
	{
	    $sum ++;
	}
	else
	{
	    $blank ++;
	}
    }

    return { blank => $blank, sum => $sum, turnout => $blank+$sum };
}


##############################################################################

=head2 get_alternative_vote_count

=cut

sub get_alternative_vote_count
{
    my( $prop, $alt ) = @_;

    my $voted_all = $prop->get_all_votes(1);
    my $blank = 0;
    my $yay = 0;
    my $nay = 0;
    my $first = 0;
    my $sum   = 0;
    my $direct = 0;

    my $alt_date = $alt->first_arc('is')->created;

#    debug "Get all votes for prop";
    foreach my $voted ( $voted_all->as_array )
    {
	my $vote = $voted->vote or next;
#	debug "  vote ".$vote->desig;
	next if $vote->first_arc('is')->created < $alt_date;

	$direct++ unless $voted->delegate;

	if( my $arc = $vote->first_arc('places_alternative', $alt) )
	{
	    $sum++;
	    $yay++ if $arc->weight > 0;
	    $nay++ if $arc->weight < 0;

	    my $first_alt = $vote->arc_list('places_alternative')->sorted('weight','desc')->get_first_nos->obj;
	    $first++ if $alt->equals($first_alt);
	}
	else
	{
	    $blank ++;
	}
    }

    my $turnout = $blank+$sum;
    my $voters = $prop->area->number_of_voters;

    my $turnout_percent = sprintf('%.1f%%',100*$turnout/$voters);
    my $direct_percent = sprintf('%.1f%%',100*$direct/$voters);
    my $first_percent = sprintf('%.1f%%',100*$first/$voters);
    my $yay_percent = sprintf('%.1f%%',100*$yay/$voters);
    my $nay_percent = sprintf('%.1f%%',100*$nay/$voters);
    my $yay_rel_percent = sprintf('%.1f%%',100*$yay/$sum);
    my $nay_rel_percent = sprintf('%.1f%%',100*$nay/$sum);
    my $blank_percent = sprintf('%.1f%%',100*$blank/$voters);

    return
    {
     blank => $blank,
     sum => $sum,
     yay => $yay,
     nay => $nay,
     direct => $direct,
     first => $first,
     turnout => $turnout,
     voters => $voters,
     turnout_percent => $turnout_percent,
     direct_percent => $direct_percent,
     first_percent => $first_percent,
     yay_percent => $yay_percent,
     yay_rel_percent => $yay_rel_percent,
     nay_percent => $nay_percent,
     nay_rel_percent => $nay_rel_percent,
     blank_percent => $blank_percent,
    };
}


##############################################################################

=head2 winner_list

=cut

sub winner_list
{
    my( $prop ) = @_;

    if( $prop->{'gov'}{'winners'} )
    {
	return $prop->{'gov'}{'winners'};
    }

    my( $args ) = parse_propargs('active');

    debug "Winner list for ".$prop->sysdesig;

    my $rp = Voting::Condorcet::RankedPairs->new();

    my( %handled );
    my $alts = $prop->list('has_alternative', undef, $args);

    if( $alts->size == 1 )
    {
	return $prop->{'gov'}{'winners'} = [$alts];
    }

    foreach my $alt1 ( $alts->as_array )
    {
	$handled{$alt1->id}++;
	foreach my $alt2 ( $alts->as_array )
	{
	    next if $handled{$alt2->id};
	    my $ratio = $prop->rank_pair( $alt1, $alt2, $args );
	    $rp->add($alt1->id, $alt2->id, $ratio);
	}
    }

    my @rank_list;
    foreach my $place ( $rp->strict_rankings )
    {
#	debug "  place ".$place->[0];
	my @oplace;
	foreach my $alt_id ( @$place )
	{
	    push @oplace, Rit::Base::Resource->get($alt_id);
	}
	push @rank_list, Rit::Base::List->new(\@oplace);
    }

    return $prop->{'gov'}{'winners'} = Rit::Base::List->new(\@rank_list);
}


##############################################################################

sub delegates_alt
{
    my( $prop, $alt ) = @_;

    if( $prop->{'gov'}{'delegates_alt'} )
    {
	return $prop->{'gov'}{'delegates_alt'}{$alt->id};
    }

    my %delegates_alt;
    foreach my $vote ( $prop->delegate_votes->as_array )
    {
	my( $palts ) = $vote->{'vote'}->
	  arc_list('places_alternative')->sorted('weight','desc');
	my $alt = $palts->get_first_nos->obj or next;
	$delegates_alt{ $alt->id } ||= [];
	push @{$delegates_alt{ $alt->id }}, $vote->{'delegate'};
    }

    my %delegates_alt_out;
    foreach my $key ( keys %delegates_alt )
    {
	$delegates_alt_out{ $key } =
	  Rit::Base::List->new($delegates_alt{$key});
    }


    $prop->{'gov'}{'delegates_alt'} = \%delegates_alt_out;
    return $prop->{'gov'}{'delegates_alt'}{$alt->id};
}

##############################################################################

=head2 rank_pair

=cut

sub rank_pair
{
    my( $prop, $alt1, $alt2, $args ) = @_;

    my $cnt1 = 0;
    my $cnt2 = 0;

    foreach my $vote ( $prop->get_all_votes->as_array )
    {
	my $a1 = $vote->first_arc('places_alternative',$alt1, $args);
	my $a2 = $vote->first_arc('places_alternative',$alt2, $args);

	my $w1 = $a1 ? $a1->weight : 0 // 0;
	my $w2 = $a2 ? $a2->weight : 0 // 0;

	if( $w1 > $w2 )
	{
	    $cnt1 ++;
	}
	elsif( $w2 > $w1 )
	{
	    $cnt2++;
	}
    }

    my $sum = $cnt1+$cnt2;

    return 0.5 unless $sum;
    return $cnt1 / ($cnt1+$cnt2);
}


##############################################################################

sub get_vote_integral
{
#    carp('get_vote_integral');

    my( $prop ) = @_;
    my( $args ) = parse_propargs('active');

    my $R          = Rit::Base->Resource;
    my $area       = $prop->area;
    my $members    = $area->revlist( 'has_voting_jurisdiction' );

    return 0 if  $members->size == 0;

    my $votes      = $prop->get_all_votes;
    my $now        = now();
    my $total_days = 0;

    my $winner_list = $prop->winner_list;
    return 0 unless $winner_list->[0];
    return 0 if $winner_list->[0]->size > 1;
    my $first = $winner_list->[0]->get_first_nos;
    my $seconds = $winner_list->[1];


    debug "Getting integral from " . $votes->size . " votes.";
    $votes->reset;

    # To sum delegated votes, we loop through all with jurisdiction in area
    while( my $vote = $votes->get_next_nos )
    {
        next unless $vote->first_arc('places_alternative');

        my $time = $vote->revarc('places_vote')->activated;
        my $duration_days = ($now->epoch - $time->epoch);

	unless( $seconds )
	{
	    $total_days += $duration_days;
	    next;
	}


	my $a1 = $vote->first_arc('places_alternative',$first, $args);
	my $w1 = $a1 ? $a1->weight : 0 // 0;

	my $sum = 0;
	foreach my $sec ( $seconds->as_array )
	{
	    my $a2 = $vote->first_arc('places_alternative',$sec, $args);
	    my $w2 = $a2 ? $a2->weight : 0 // 0;

#	    debug sprintf "Vote %d - %d", $w1, $w2;


	    if( $w1 > $w2 )
	    {
		$sum ++;
	    }
	    elsif( $w2 > $w1 )
	    {
		$sum--;
	    }
	}

#	debug "   = $sum";
#	debug sprintf "   adding %d days", $duration_days * ( $sum / $seconds->size );

        $total_days += $duration_days * ( $sum / $seconds->size );
    }

    my $weighted_intergral = $total_days / $members->size;

    return $weighted_intergral;
}


##############################################################################

=head2 vote_integral_chart_svg

=cut

sub vote_integral_chart_svg
{
    my( $prop ) = @_;
    my( $args ) = parse_propargs('active');

    my $vote_arcs = $prop->get_all_votes()->revarc_list('places_vote',undef,$args)->flatten->sorted({on=>'activated',cmp=>'<=>'});

#    debug( datadump( $vote_arcs, 2 ) );

    $vote_arcs->reset;

    my $resolution_weight = $prop->resolution_progressive_weight || 7;
    my $member_count = $prop->area->revlist('has_voting_jurisdiction',undef,$args)->size
      or return '';


    my $winner_list = $prop->winner_list;
    return '' unless $winner_list->[0];
    my $draw = ($winner_list->[0]->size > 1) ? 1 : 0;
    my $first = $winner_list->[0]->get_first_nos;
    my $seconds = $winner_list->[1] or return '';


    my @markers;
    my $current_level = 0;
    my $current_y = 0;
    my $last_time = 0;
    my $base_time;

    while( my $vote_arc = $vote_arcs->get_next_nos ) {
        my $vote = $vote_arc->obj;
        next unless $vote->first_arc('places_alternative',undef,$args);
	next if $draw;


        my $time = $vote->revarc('places_vote',undef,$args)->activated->epoch;
        $base_time //= $time;

        my $rel_time = ($time - $base_time) / 24 / 60 / 60;

        # Speed, in votedays per day
        $current_y += ($rel_time - $last_time) * $current_level;

        push @markers, { x => $rel_time, y => $current_y };


	my $a1 = $vote->first_arc('places_alternative',$first, $args);
	my $w1 = $a1 ? $a1->weight : 0 // 0;

	my $sum = 0;
	foreach my $sec ( $seconds->as_array )
	{
	    my $a2 = $vote->first_arc('places_alternative',$sec, $args);
	    my $w2 = $a2 ? $a2->weight : 0 // 0;

	    debug sprintf "Vote %d - %d", $w1, $w2;


	    if( $w1 > $w2 )
	    {
		$sum ++;
	    }
	    elsif( $w2 > $w1 )
	    {
		$sum--;
	    }
	}

	if( $seconds )
	{
	    $current_level += ( $sum / $seconds->size );
	}
	else
	{
	    $current_level += 1;
	}

        $last_time = $rel_time;

        debug "$rel_time - $current_level";

    }
    my $now = now()->epoch;

    $base_time //= $now;

    my $rel_time = ($now - $base_time) / 24 / 60 / 60;
    $current_y += ($rel_time - $last_time) * $current_level;
    debug "$rel_time - $current_level";
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

=head2 predicted_resolution_vote

=cut

sub predicted_resolution_vote
{
    my $winner_list = $_[0]->winner_list;
#    debug $_[0]->sysdesig." Winner list: ".$winner_list->[0];
    return 'empty' unless $winner_list->[0];
    return( $winner_list->[0]->desig );
}


##############################################################################

=head2 create_resolution_vote

=cut

sub create_resolution_vote
{
    my( $prop, $args ) = @_;
    my $R     = Rit::Base->Resource;

    my $vote = $R->create({
			   is     => $C_vote,
			  }, $args);

    my @winner_list = @{$prop->winner_list};

    my $weight;
    for( my $i=$#winner_list; $i>=0; $i-- )
    {
	$weight++;
	foreach my $alt ( $winner_list[$i]->as_array )
	{
	    $vote->add({'places_alternative' => $alt}, {%$args, arc_weight => $weight});
	}
    }

    return $vote;
}


##############################################################################


1;

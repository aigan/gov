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

use RDF::Base::Constants qw( $C_vote $C_resolution_method_continous );
use RDF::Base::Resource;
use RDF::Base::Utils qw( parse_propargs is_undef query_desig );
use RDF::Base::List;
use RDF::Base::Literal::Time qw( now timespan );
use RDF::Base::Widget qw( locn aloc locnl alocpp );

##############################################################################

sub register_vote
{
    my( $prop, $u, $vote_in ) = @_;
    my( $args, $arclim, $res ) = parse_propargs('active');

    my $vote_parsed = 0;
    my $changed     = 0;
    my $R           = RDF::Base->Resource;


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

    $vote->mark_updated;

    # Activate changes
    $res->autocommit({ activate => 1 });

    $prop->clear_caches;
    $prop->add_alternative_place($vote);

}


##############################################################################

=head2 sum_all_votes

Makes a hash summary of the votes.

=cut

sub sum_all_votes
{
    my( $prop ) = @_;

    my $voted_all = $prop->get_all_votes(1);

    my $blank = 0;
    my $sum   = 0;
    my $direct = 0;

    foreach my $voted ( $voted_all->as_array )
    {
	my $vote = $voted->vote or next;
	$direct++ unless $voted->delegate;

	if( $vote->places_alternative )
	{
	    $sum ++;
	}
	else
	{
	    $blank ++;
	}
    }

    my $turnout = $blank+$sum;
    my $voters = $prop->area->number_of_voters || 1; # Edge case. Use 1 as to avoid division by zero...

    my $turnout_percent = sprintf('%.1f%%',100*$turnout/$voters);
    my $direct_percent = sprintf('%.1f%%',100*$direct/$voters);
    my $blank_percent = sprintf('%.1f%%',100*$blank/$voters);


    return
    {
     blank => $blank,
     sum => $sum,
     direct => $direct,
     turnout => $turnout,
     voters => $voters,
     turnout_percent => $turnout_percent,
     direct_percent => $direct_percent,
     blank_percent => $blank_percent,
    };
}


##############################################################################

=head2 get_alternative_vote_count

=cut

sub get_alternative_vote_count
{
    my( $prop, $alt, $args ) = @_;

    my $voted_all = $prop->get_all_votes(1, $args);
    my $blank = 0;
    my $yay = 0;
    my $nay = 0;
    my $first = 0;
    my $sum   = 0;
    my $direct = 0;

    my $alt_date = $alt->created;
#    debug "Alt created ".$alt_date;

#    debug "Get all votes for prop";
    foreach my $voted ( $voted_all->as_array )
    {
	my $vote = $voted->vote or next;
	my $voted_date = $vote->updated;

#	debug "  vote from ".$voted->member->desig;
#	debug "         on ".$voted_date;
	next if $voted_date < $alt_date;

	$direct++ unless $voted->delegate;

	if( my $arc = $vote->first_arc('places_alternative', $alt, $args) )
	{
#	    debug "    mention";
	    $sum++;
	    $yay++ if( ($arc->weight||0) > 0 );
	    $nay++ if( ($arc->weight||0) < 0 );

	    my $first_alt = $vote->arc_list('places_alternative',undef,$args)->sorted('weight','desc', $args)->get_first_nos->obj;
	    $first++ if $alt->equals($first_alt);
	}
	else
	{
#	    debug "    blank";
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
    my $blank_percent = sprintf('%.1f%%',100*$blank/$voters);

    my $yay_rel_percent = $sum ? sprintf('%.1f%%',100*$yay/$sum) : undef;
    my $nay_rel_percent = $sum ? sprintf('%.1f%%',100*$nay/$sum) : undef;

    my $score = $yay - $nay;

    return
    {
     blank => $blank,
     sum => $sum,
     yay => $yay,
     nay => $nay,
     score => $score,
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

  $prop->winner_list( \%args )

=cut

sub winner_list
{
    my( $prop, $args_in ) = @_;

    my( $args ) = parse_propargs($args_in // 'solid');
    my $look_date = $args->{arc_active_on_date};
    my $key = $look_date ? $look_date->syskey : 'today';

    if( $prop->{'gov'}{'winners'}{$key} )
    {
	return $prop->{'gov'}{'winners'}{$key};
    }

    debug "Winner list for ".$prop->sysdesig;

    my $rp = Voting::Condorcet::RankedPairs->new();

    my( %handled );
    my $alts = $prop->list('has_alternative', undef, $args);

    if( $alts->size == 1 )
    {
	return $prop->{'gov'}{'winners'}{$key} =
	  RDF::Base::List->new([$alts]);
    }

#    debug "== Building ranked pairs";
    foreach my $alt1 ( $alts->as_array )
    {
#	debug " + ".$alt1->sysdesig;
	$handled{$alt1->id}++;
	foreach my $alt2 ( $alts->as_array )
	{
	    next if $handled{$alt2->id};
#	    debug " - ".$alt2->sysdesig;
	    my $ratio = $prop->rank_pair( $alt1, $alt2, $args );
	    $rp->add($alt1->id, $alt2->id, $ratio);
	}
	$Para::Frame::REQ->may_yield; ### TODO: Optimize
    }

    my @rank_list;
    foreach my $place ( $rp->strict_rankings )
    {
	my @oplace;
	foreach my $alt_id ( @$place )
	{
	    push @oplace, RDF::Base::Resource->get($alt_id);
	}
	push @rank_list, RDF::Base::List->new(\@oplace);
    }

    return $prop->{'gov'}{'winners'}{$key} = RDF::Base::List->new(\@rank_list);
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
	  RDF::Base::List->new($delegates_alt{$key});
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

    my $R           = RDF::Base->Resource;
#    debug "Ranking pair";

    foreach my $vote ( $prop->get_all_votes(0,$args)->as_array )
    {
	my $a1 = $vote->first_arc('places_alternative',$alt1, $args);
	my $w1 = $a1->weight || 0;
#	debug "   a1: ".$w1;

	my $a2 = $vote->first_arc('places_alternative',$alt2, $args);
	my $w2 = $a2->weight || 0;
#	debug "   a2: ".$w2;

	if( $w1 > $w2 )
	{
	    $cnt1 ++;
	}
	elsif( $w2 > $w1 )
	{
	    $cnt2++;
	}
    }

 #   debug "  $cnt1 * ".$R->get($alt1)->sysdesig;
 #   debug "  $cnt2 * ".$R->get($alt2)->sysdesig;

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

    my $R          = RDF::Base->Resource;
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
    my $R     = RDF::Base->Resource;

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

=head2 vote_longdesig

=cut

sub vote_longdesig
{
    my( $prop, $vote, $args ) = @_;

    my( $palts ) = $vote->arc_list('places_alternative')->sorted('weight','desc');
    my $res = "";
    while( my $alt = $palts->get_next_nos )
    {
	$res .= sprintf "%d: %s\n", $alt->weight, $alt->obj->sysdesig;
    }
    return $res;
}


##############################################################################

=head2 vote_as_html_long

=cut

sub vote_as_html_long
{
    my( $prop, $vote, $args ) = @_;

    my( $palts ) = $vote->arc_list('places_alternative')->sorted('weight','desc');
    unless( $palts->size )
    {
	return locnl('Blank');
    }

    my $res = '<table class="vote_alternatives">';
    while( my $alt = $palts->get_next_nos )
    {
	$res .= sprintf "<tr><td>%d</td><td>%s</td></tr>\n", $alt->weight, $alt->obj->wu_jump;
    }
    $res .= "</table>\n";
    return $res;
}


##############################################################################

=head2 vote_desig

=cut

sub vote_desig
{
    my( $prop, $vote, $args ) = @_;
    my( $palts ) = $vote->arc_list('places_alternative')->sorted('weight','desc');
    return $palts->get_first_nos->obj->desig;
}


###############################################################################

=head2 vote_sysdesig

=cut

sub vote_sysdesig
{
    my( $prop, $vote, $args ) = @_;
    my $alts = $vote->arc_list('places_alternative')->sorted('weight','desc')->obj;
    my $text;
    if( $alts->size > 3 )
    {
	my $cnt = $alts->size - 1;
	$text = $alts->get_first_nos->desig." and $cnt more";
    }
    else
    {
	$text = $alts->desig;
    }

    return $vote->id .': '.$text;
}


##############################################################################

=head2 get_alternative_place_date

=cut

sub get_alternative_place_data
{
    my( $prop, $alt ) = @_;

    my $all = parse_propargs( {
			       arclim => ['active', 'old'],
			       unique_arcs_prio => undef,
			      });


    my $place_arcs = $alt->arc_list('alternative_place',undef,$all);
    unless($place_arcs)
    {
	debug( $alt->sysdesig." has no place. Populating" );
	$prop->populate_alternative_place();
	$place_arcs = $alt->arc_list('alternative_place',undef,$all);
    }

    my $current = $place_arcs->active->get_first_nos;
    my $place =  $current->value->plain;
    my $current_date = $current->created;
    my $duration;
    if( $current_date )
    {
	$duration = now() - $current->created;
    }
    else
    {
	$duration = DateTime::Duration->new();
    }

    if( my $previous = $current->replaces )
    {
	my $previous_place = $previous->value->plain;

	return
	{
	 place => $place,
	 date => $current->created,
	 duration => $duration,
	 previous => $previous,
	 previous_place => $previous_place,
	 delta => ($previous_place - $place),
	 place_arcs => $place_arcs,
	};
    }
    else
    {
	return
	{
	 place => $place,
	 date => $current->created,
	 duration => $duration,
	 place_arcs => $place_arcs,
	 delta => 0,
	};
    }
}



##############################################################################

=head2 populate_alternative_place

=cut

sub populate_alternative_place
{
    my( $prop ) = @_;

    state $populating;
    return if $populating->{$prop->id};
    $populating->{$prop->id} = 1;

    my $all = parse_propargs( {
			       arclim => ['active', 'old'],
			       unique_arcs_prio => undef,
			      });


    ### Collect voting dates
    #
    my $votes = $prop->list('has_vote',undef,$all);
    my %votings;
    foreach my $vote ( $votes->nodes )
    {
	my $alt_place_arcs = $vote->arc_list('places_alternative',undef,$all);
	foreach my $places_arc ( $alt_place_arcs->nodes )
	{
	    my $date_key = $places_arc->activated->syskey;
	    $votings{$date_key} = $places_arc;
	}
    }

    my( $args, $arclim, $res ) = parse_propargs({ activate_new_arcs=>1 });

    foreach my $date_key ( sort keys %votings )
    {
	debug " * $date_key";

	my $date = $votings{$date_key}->activated;
	my $by  = $votings{$date_key}->created_by;

	my $argsd = parse_propargs({ arc_active_on_date => $date,
				     res => $res });
	my $wl = $prop->winner_list($argsd);
	$wl->reset;

	my $place=0;
	while( my $alts = $wl->get_next_nos )
	{
	    $place++;
	    $alts->reset;
	    while( my $palt = $alts->get_next_nos )
	    {
		# The winner-lists are filtered on those including the
		# specified alternative. We cant store places for
		# other alternatives unless we get a sorted list of
		# winner lists with all the dates.
		#next unless $palt->equals($alt);

		my $place_arc = $palt->first_arc('alternative_place');
		# Should be all or nothing
		if( $place_arc )
		{
		    my $old_place = $place_arc->value->plain;
		    if( $old_place != $place )
		    {
			if( $place_arc->created >= $date )
			{
			    debug "Placing arc conflict detected";
			    debug "OLD: ".$place_arc->sysdesig;
			    debug "OLD date: ".$place_arc->activated;
			    debug "NEW: place $place";
			    debug "NEW date: ".$date;
			}
			else
			{
			    RDF::Base::Arc->create
				({
				  common => $place_arc->common_id,
				  replaces => $place_arc->id,
				  subj => $palt,
				  pred => 'alternative_place',
				  value => $place,
				  created => $date,
				  created_by => $by,
				  active => 1,
				 }, $args );
			}
		    }
		}
		else
		{
		    RDF::Base::Arc->create({
					    subj => $palt,
					    pred => 'alternative_place',
					    value => $place,
					    created => $date,
					    created_by => $by,
					    active => 1,
					   }, $args);
		}

		my $vc = $prop->get_alternative_vote_count($palt,$argsd);
		my $score = $vc->{score};
		my $score_arc = $palt->first_arc('alternative_score');
		# Should be all or nothing
		if( $score_arc )
		{
		    my $old_score = $score_arc->value->plain;
		    if( $old_score != $score )
		    {
			RDF::Base::Arc->create
			    ({
			      common => $score_arc->common_id,
			      replaces => $score_arc->id,
			      subj => $palt,
			      pred => 'alternative_score',
			      value => $score,
			      created => $date,
			      created_by => $by,
			      active => 1,
			     }, $args );
		    }
		}
		else
		{
		    RDF::Base::Arc->create({
					    subj => $palt,
					    pred => 'alternative_score',
					    value => $score,
					    created => $date,
					    created_by => $by,
					    active => 1,
					   }, $args);
		}

		debug "$place ($score). ".$palt->desig;
	    }
	}

    }

    $res->autocommit();

    $populating->{$prop->id} = 0;
}


##############################################################################

=head2 add_alternative_place

=cut

sub add_alternative_place
{
    my( $prop, $vote ) = @_;

    my( $args ) = parse_propargs({ activate_new_arcs=>1 });
    $args->{activate_new_arcs} = 1;


    my $wl = $prop->winner_list;
    $wl->reset;

    my $place=0;
    while( my $alts = $wl->get_next_nos )
    {
	$place++;
	$alts->reset;
	while( my $palt = $alts->get_next_nos )
	{
	    my $place_arc = $palt->first_arc('alternative_place');
	    # Should be all or nothing
	    if( $place_arc )
	    {
		my $old_place = $place_arc->value->plain;
		if( $old_place != $place )
		{
		    $place_arc->set_value( $place, $args );
		}
	    }
	    else
	    {
		$palt->add({alternative_place=>$place},$args);
	    }

	    my $vc = $prop->get_alternative_vote_count($palt);
	    my $score = $vc->{score};
	    my $score_arc = $palt->first_arc('alternative_score');
	    # Should be all or nothing
	    if( $score_arc )
	    {
		my $old_score = $score_arc->value->plain;
		if( $old_score != $score )
		{
		    $score_arc->set_value( $score, $args );
		}
	    }
	    else
	    {
		$palt->add({alternative_score=>$score},$args);
	    }
	}
    }
}


##############################################################################

=head2 voting_dates

=cut

sub voting_dates
{
    my( $prop ) = @_;

    my $all = parse_propargs( {
			       arclim => ['active', 'old'],
			       unique_arcs_prio => undef,
			      });

    ### Collect voting dates
    #
    my $votes = $prop->list('has_vote',undef,$all);
    my %votings;
    foreach my $vote ( $votes->nodes )
    {
	my $alt_place_arcs = $vote->arc_list('places_alternative',undef,$all);
	foreach my $places_arc ( $alt_place_arcs->nodes )
	{
	    my $date = $places_arc->activated;
	    $votings{$date->syskey} = $date;
	}
    }

    my @dates = map $votings{$_}, sort keys %votings;

    return RDF::Base::List->new(\@dates);
}


##############################################################################

=head2 buffered_continous_resolution

=cut


sub buffered_continous_resolution
{
    my( $prop, $args_in ) = @_;

    unless( $prop->has_resolution_method($C_resolution_method_continous) )
    {
	return;
    }

    my( $args, $arclim, $res ) = parse_propargs($args_in);
    my $R     = RDF::Base->Resource;

    my $vote = $prop->first_prop('has_resolution_vote', undef, $args);
    unless( $vote )
    {
	$vote = $R->create({is => $C_vote}, $args);
	$vote->create_rec({time => $prop->created,
			   user => $prop->created_by});
	$prop->add({ has_resolution_vote => $vote }, $args);
	$res->autocommit($args);

	my $dates = $prop->voting_dates;
	foreach my $date ( $dates->as_array )
	{
#	    debug "Update res for ".$date;
	    $vote->update_resolution($date);
	}
    }

#    debug "Update res for NOW";
    $vote->update_resolution();

    $res->autocommit;

    return $vote;
}


##############################################################################

=head2 vacuum_facet

=cut

sub vacuum_facet
{
    my( $prop, $args_in ) = @_;

    my( $args, $arclim, $res ) = parse_propargs($args_in // 'solid');
    my $all = parse_propargs( {
			       arclim => ['active', 'old'],
			       unique_arcs_prio => undef,
			       force_recursive => 1,
			       res => $res,
			      });

    my $alts = $prop->list('has_alternative',undef,$all);
    foreach my $alt ( $alts->nodes )
    {
	my $place_arcs = $alt->arc_list('alternative_place',undef,$all);
	$place_arcs->remove($all);

	my $score_arcs = $alt->arc_list('alternative_score',undef,$all);
	$score_arcs->remove($all);
    }

    $prop->reset_resolution_vote($args);

    return( $prop );
}


##############################################################################

=head2 table_stats

=cut

# TODO: Show stats for comparison between nr 1 and nr 2.
#sub table_stats
#{
#    my( $prop ) = @_;
#
#    my $count = $prop->sum_all_votes;
#    return( '<tr><td>'.aloc('Blank').'</td><td>'.$count->{blank}.
#	    ' ('.$count->{blank_percent}.')</td></tr>'.
#	  );
#}

##############################################################################


1;

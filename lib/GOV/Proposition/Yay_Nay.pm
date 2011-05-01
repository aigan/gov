# -*-cperl-*-
package GOV::Proposition::Yay_Nay;

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

GOV::Proposition::Yay_Nay

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );
use Para::Frame::Widget qw( jump );
use Para::Frame::L10N qw( loc );

use Rit::Base::Constants qw( $C_vote);
use Rit::Base::Resource;
use Rit::Base::Utils qw( parse_propargs is_undef );
use Rit::Base::Widget qw( locn aloc);
use Rit::Base::List;
use Rit::Base::Literal::Time qw( now timespan );

##############################################################################

sub wu_vote
{
    my( $proposition ) = @_;

    my $req = $Para::Frame::REQ;
    my $u = $req->user;
    my $area = $proposition->area;

    my $widget = '';

    # Any member can vote on a proposition.  Only those with
    # jurisdiction will be counted

    my $R = Rit::Base->Resource;

    # Check if there's an earlier vote on this
    my $voted = $u->find_vote( $proposition );
    my $prev_vote = $voted->vote;
    my $delegate = $voted->delegate;

    if( $prev_vote and not $delegate ) {
        $widget .= aloc('You have voted: [_1].', $prev_vote->desig);
        $widget .= '<br/>';
        $widget .= aloc('You can change your vote:');
        $widget .= '<br/>';
    }
    elsif( $prev_vote ) {
        $widget .= aloc('Delegate [_1] has voted: [_2].', $delegate->name,
                       $prev_vote->desig);
        $widget .= '<br/>';
        $widget .= aloc('You can make another vote:');
        $widget .= '<br/>';
    }

    $widget .= jump(locn('Yay'), '', {
                                     id => $proposition->id,
                                     run => 'place_vote',
                                     vote => 'yay',
                                    }). ' | ';
    $widget .= jump(locn('Nay'), '', {
                                     id => $proposition->id,
                                     run => 'place_vote',
                                     vote => 'nay',
                                    }). ' | ';
    $widget .= jump(locn('Blank'), '', {
                                       id => $proposition->id,
                                       run => 'place_vote',
                                       vote => 'blank',
                                      });

    return $widget;
}


##############################################################################

sub delegates_yay
{
    my( $prop ) = @_;

    if( $prop->{'gov'}{'delegates_yay'} )
    {
	return $prop->{'gov'}{'delegates_yay'};
    }

    my @delegates_yay;
    foreach my $vote ( $prop->delegate_votes->as_array )
    {
	if( $vote->{'vote'}->weight > 0 )
	{
	    push @delegates_yay, $vote->{'delegate'};
	}
    }

    return $prop->{'gov'}{'delegates_yay'} =
      Rit::Base::List->new(\@delegates_yay);
}


##############################################################################

sub delegates_nay
{
    my( $prop ) = @_;

    if( $prop->{'gov'}{'delegates_nay'} )
    {
	return $prop->{'gov'}{'delegates_nay'};
    }

    my @delegates_nay;
    foreach my $vote ( $prop->delegate_votes->as_array )
    {
	if( $vote->{'vote'}->weight < 0 )
	{
	    push @delegates_nay, $vote->{'delegate'};
	}
    }

    return $prop->{'gov'}{'delegates_nay'} =
      Rit::Base::List->new(\@delegates_nay);
}


##############################################################################

sub register_vote
{
    my( $proposition, $u, $vote_in ) = @_;
    my( $args, $arclim, $res ) = parse_propargs('relative');

    my $vote_parsed = 0;
    my $changed     = 0;
    my $R           = Rit::Base->Resource;

    # Parse the in-data
    $vote_in = lc $vote_in;
    $vote_parsed = 1
      if( $vote_in eq 'yay' or
	  $vote_in eq 'yes' or
	  $vote_in eq '1' );
    $vote_parsed = -1
      if( $vote_in eq 'nay' or
	  $vote_in eq 'no' or
	  $vote_in eq '-1' );

    # Build the new vote
    my $vote = $R->create({
			   is     => $C_vote,
			   weight => $vote_parsed,
#			   name   => $vote_in,        # relevant?
#			   code   => $vote_parsed,
			  }, $args);

    # Check if there's an earlier vote on this
    my $prev_vote = $R->find({
			      rev_places_vote => $u,
			      rev_has_vote    => $proposition,
			     }, $args);
    if( $prev_vote ) {
	# Remove previous vote
	$prev_vote->remove($args);
	$changed = 1;
    }

    # Connect the user to the vote
    $u->add({ places_vote => $vote }, $args);

    # Connect the proposition to the vote
    $proposition->add({ has_vote => $vote }, $args);

    # Activate changes
    $res->autocommit({ activate => 1 });

    $proposition->clear_caches;
}


##############################################################################

=head2 sum_all_votes

Makes a hash summary of the votes.  This should mainly be called from
GOV::Proposition->get_vote_count, that caches the result.

=cut

sub sum_all_votes
{
    my( $prop ) = @_;

    my $voted_all = $prop->get_all_votes(1);

    my $blank = 0;
    my $yay = 0;
    my $nay = 0;
    my $sum   = 0;
    my $direct = 0;


    $voted_all->reset;
    while( my $voted = $voted_all->get_next_nos )
    {
	my $vote = $voted->vote or next;
	$direct++ unless $voted->delegate;

        if( not $vote->weight )
	{
            $blank++;
        }
        elsif( $vote->weight == 1 )
	{
	    $sum++;
	    $yay++;
        }
        elsif( $vote->weight == -1 )
	{
	    $sum++;
	    $nay++;
        }
    }

    my $turnout = $blank+$sum;
    my $voters = $prop->area->number_of_voters;

    my $turnout_percent = sprintf('%.1f%%',100*$turnout/$voters);
    my $direct_percent = sprintf('%.1f%%',100*$direct/$voters);
    my $yay_percent = sprintf('%.1f%%',100*$yay/$voters);
    my $nay_percent = sprintf('%.1f%%',100*$nay/$voters);
    my $blank_percent = sprintf('%.1f%%',100*$blank/$voters);

    my $yay_rel_percent = $sum ? sprintf('%.1f%%',100*$yay/$sum) : undef;
    my $nay_rel_percent = $sum ? sprintf('%.1f%%',100*$nay/$sum) : undef;

    return
    {
     blank => $blank,
     sum => $sum,
     yay => $yay,
     nay => $nay,
     direct => $direct,
     turnout => $turnout,
     voters => $voters,
     turnout_percent => $turnout_percent,
     direct_percent => $direct_percent,
     yay_percent => $yay_percent,
     yay_rel_percent => $yay_rel_percent,
     nay_percent => $nay_percent,
     nay_rel_percent => $nay_rel_percent,
     blank_percent => $blank_percent,
    };
}


##############################################################################

sub get_vote_integral
{
    my( $proposition ) = @_;

    my $R          = Rit::Base->Resource;
    my $area       = $proposition->area;
    my $members    = $area->revlist( 'has_voting_jurisdiction' );

    return 0 if( $members->size == 0 );

    my $votes      = $proposition->get_all_votes;
    my $now        = now();
    my $total_days = 0;

    debug "Getting integral from " . $votes->size . " votes.";
    $votes->reset;

    # To sum delegated votes, we loop through all with jurisdiction in area
    while( my $vote = $votes->get_next_nos ) {
        next unless( $vote->weight );

        my $time = $vote->revarc('places_vote')->activated;
        my $duration_days = ($now->epoch - $time->epoch);
        $total_days += $duration_days * $vote->weight;
    }

    my $weighted_intergral = $total_days / $members->size;

    return $weighted_intergral;
}


##############################################################################

=head2 predicted_resolution_vote

=cut

sub predicted_resolution_vote
{
    my( $proposition ) = @_;

    my $count = $proposition->get_vote_count;

    return aloc('Yay')
      if( $count->{sum} > 0 );
    return aloc('Nay')
      if( $count->{sum} < 0 );
    return aloc('Draw');
}


##############################################################################

=head2 create_resolution_vote

=cut

sub create_resolution_vote
{
    my( $proposition, $args ) = @_;

    my $R     = Rit::Base->Resource;
    my $count = $proposition->get_vote_count;

    my $weight = 0;

    $weight = 1   if( $count->{sum} > 0 );
    $weight = -1  if( $count->{sum} < 0 );

    my $name = $count->{sum} > 0 ? 'Yay'
             : $count->{sum} < 0 ? 'Nay'
                                 : 'Blank';
    # Build the new vote
    my $vote = $R->create({
			   is     => $C_vote,
			   weight => $weight,
#			   code   => $weight,
#                           name   => $name,
			  }, $args);

    return $vote;
}


##############################################################################


1;

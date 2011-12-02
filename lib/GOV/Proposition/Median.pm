# -*-cperl-*-
package GOV::Proposition::Median;

#=============================================================================
#
# AUTHOR
#   Fredrik Liljegren   <jonas@liljegren.org>
#
# COPYRIGHT
#   Copyright (C) 2011 Fredrik Liljegren
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#=============================================================================

=head1 NAME

GOV::Proposition::Median

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use Scalar::Util qw( looks_like_number );
use Statistics::Basic qw( median variance stddev mean vector );

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );
use Para::Frame::Widget qw( jump input go );
use Para::Frame::L10N qw( loc );

#use RDF::Base::Constants qw( $C_vote);
use RDF::Base::Resource;
use RDF::Base::Utils qw( parse_propargs is_undef );
use RDF::Base::Widget qw( locn aloc locnl );

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

    my $R = RDF::Base->Resource;

    # Check if there's an earlier vote on this
    my $voted = $u->find_vote( $proposition );
    my $prev_vote = $voted->vote;
    my $delegate = $voted->delegate;

    if( $prev_vote and not $delegate ) {
        $widget .= aloc('You have voted: [_1].', $prev_vote->desig);
        $widget .= '<br/>';
        $widget .= aloc('You can change your vote:');
    }
    elsif( $prev_vote ) {
        $widget .= aloc('Delegate [_1] has voted: [_2].', $delegate->name,
                       $prev_vote->desig);
        $widget .= '<br/>';
        $widget .= aloc('You can make another vote:');
    }
    $widget .= ' ';

    $widget .= input('vote', $prev_vote->weight->plain,
		     {
		      id => $proposition->id,
		      size => 5,
		     });
    $widget .= go(locnl('vote'), undef, 'place_vote');

    return $widget;
}


##############################################################################

sub register_vote
{
    my( $proposition, $u, $vote_in ) = @_;
    my( $args, $arclim, $res ) = parse_propargs('relative');

    my $vote_parsed = undef;
    my $changed     = 0;
    my $R           = RDF::Base->Resource;
    my $C = RDF::Base->Constants;

    $vote_in =~ s/[,\.].*//;
    $vote_in =~ s/\s//g;

    if( looks_like_number( $vote_in ) )
    {
	$vote_parsed = int( $vote_in );
    }
    elsif( length $vote_in )
    {
	throw('validation', loc("[_1] is not a number", $vote_in) );
    }

    # Check if there's an earlier vote on this
    my $prev_vote = $R->find({
			      rev_places_vote => $u,
			      rev_has_vote    => $proposition,
			     }, $args);

    if( $prev_vote )
    {
	my $prev_weight = $prev_vote->get_first_nos->first_prop('weight');
	if( $prev_weight->equals($vote_parsed) )
	{
	    debug "Vote not changed";
	    return;
	}


	# Remove previous vote
	$prev_vote->remove($args);
	$changed = 1;
    }




    # Build the new vote
    my $vote = $R->create({
			   is     => $C->get('vote'),
			   weight => $vote_parsed,
			  }, $args);
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

Makes a hash summary of the votes.

=cut

sub sum_all_votes
{
    my( $prop ) = @_;

    my $voted_all = $prop->get_all_votes(1);

    my $blank = 0;
    my $direct = 0;

    my @numbers;


    $voted_all->reset;
    while( my $voted = $voted_all->get_next_nos )
    {
	my $vote = $voted->vote or next;
	$direct++ unless $voted->delegate;

        if( not $vote->weight->defined )
	{
            $blank++;
        }
        else
	{
	    push @numbers, $vote->weight;
        }
    }

    my $sum = int( @numbers );
    my $turnout = $blank+$sum;
    my $voters = $prop->area->number_of_voters;

    my $turnout_percent = sprintf('%.1f%%',100*$turnout/$voters);
    my $direct_percent = sprintf('%.1f%%',100*$direct/$voters);
    my $blank_percent = sprintf('%.1f%%',100*$blank/$voters);

    my $vector = vector( @numbers );
    my $median = median( $vector );
    my $mean   = mean( $vector );
    my $stddev = stddev( $vector );

    return
    {
     blank => $blank,
     sum => $sum,
     median => $median,
     mean => $mean,
     stddev => $stddev,
     direct => $direct,
     turnout => $turnout,
     voters => $voters,
     turnout_percent => $turnout_percent,
     direct_percent => $direct_percent,
     blank_percent => $blank_percent,
    };
}


##############################################################################

=head2 predicted_resolution_vote

=cut

sub predicted_resolution_vote
{
    my( $proposition ) = @_;

    my $count = $proposition->sum_all_votes;

    return $count->{median};
}


##############################################################################

=head2 create_resolution_vote

=cut

sub create_resolution_vote
{
    my( $proposition, $args ) = @_;

    my $R     = RDF::Base->Resource;
    my $C     = RDF::Base->Constants;
    my $count = $proposition->sum_all_votes;

    # Build the new vote
    my $vote = $R->create({
			   is     => $C->get('vote'),
			   weight => sprintf('%d',$count->{median}),
			  }, $args);

    return $vote;
}


##############################################################################

=head2 vote_longdesig

=cut

sub vote_longdesig
{
    my( $prop, $vote, $args ) = @_;

    if( $vote->weight->defined )
    {
	return $vote->weight;
    }

    return loc('Blank');
}


##############################################################################

=head2 vote_as_html_long

=cut

sub vote_as_html_long
{
    return( shift->vote_longdesig(@_) );
}


##############################################################################

=head2 vote_desig

=cut

sub vote_desig
{
    return( shift->vote_longdesig(@_) );
}


###############################################################################

=head2 vote_sysdesig

=cut

sub vote_sysdesig
{
    my( $prop, $vote, $args ) = @_;

    my $out = $vote->id .': ';
    if( $vote->weight->defined )
    {
	return $out . $vote->weight;
    }

    return $out . loc('Blank');
}


##############################################################################

=head2 table_stats

=cut

sub table_stats
{
    my( $prop ) = @_;

    my $count = $prop->sum_all_votes;
    return( '<tr><td>'.aloc('Blank').'</td><td>'.$count->{blank}.
	    ' ('.$count->{blank_percent}.')</td></tr>'.
	    '<tr><td>'.aloc('Median').'</td><td>'.$count->{median}.
	    '</td></tr>'.
	    '<tr><td>'.aloc('Mean').'</td><td>'.$count->{mean}.
	    '</td></tr>'.
	    '<tr><td>'.aloc('Standard deviation').'</td><td>'.
	    $count->{stddev}.'</td></tr>'
	  );
}

##############################################################################


1;

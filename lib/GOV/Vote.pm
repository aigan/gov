# -*-cperl-*-
package GOV::Vote;

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

GOV::Proposition

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );
use Para::Frame::L10N qw( loc );


##############################################################################

sub longdesig
{
    my( $vote ) = shift;
    return $vote->first_revprop('has_vote')->vote_longdesig($vote, @_);
}


##############################################################################

sub as_html
{
    my( $vote, $args ) = @_;
    $args ||= {};

    if( $args->{'long'} )
    {
	return $vote->first_revprop('has_vote')->vote_as_html_long($vote, $args);
    }
    else
    {
	my( $str ) = CGI->escapeHTML($vote->desig($args));
	$str =~ s/\r?\n/<br\/>/g;
	return $str;
    }
}


##############################################################################

sub desig
{
    my( $vote ) = shift;
    return $vote->first_revprop('has_vote')->vote_desig($vote, @_);
}


##############################################################################

sub sysdesig
{
    my( $vote ) = @_;
    return $vote->first_revprop('has_vote')->vote_sysdesig($vote, @_);
}


##############################################################################

sub safedesig
{
    my( $vote ) = @_;
    return $vote->id;
}


##############################################################################

sub yay_alts
{
    return $_[0]->alt_lists->{yay};
}


##############################################################################

sub blank_alts
{
    return $_[0]->alt_lists->{blank};
}


##############################################################################

sub nay_alts
{
    return $_[0]->alt_lists->{nay};
}


##############################################################################

sub alt_lists
{
    unless( $_[0]->{gov}{alt_lists} )
    {
	my( $vote ) = @_;

	my $prop = $vote->first_revprop('has_vote');


	my( @yay, %blank, @nay );

	foreach my $alt ( $prop->has_alternative->as_array )
	{
	    $blank{$alt->id} = $alt;
	}

	# Previous alternatives arcs
	my( $palts ) = $vote->arc_list('places_alternative')->
	  sorted('weight','desc');
	while( my $palt = $palts->get_next_nos )
	{
	    if( $palt->weight > 0 )
	    {
		push @yay, $palt->obj;
	    }
	    else
	    {
		push @nay, $palt->obj;
	    }
	    delete $blank{ $palt->obj->id };
	}

	my $alt_lists = $vote->{gov}{alt_lists} =
	{
	 yay => Rit::Base::List->new(\@yay),
	 nay => Rit::Base::List->new(\@nay),
	 blank => Rit::Base::List->new([values %blank]),
	};
    }
    return $_[0]->{gov}{alt_lists};
}


##############################################################################

sub on_arc_add
{
    $_[0]->clear_caches(@_);
    $_[0]->revlist('has_vote')->clear_caches;
}


##############################################################################

sub on_arc_del
{
    $_[0]->clear_caches(@_);
    $_[0]->revlist('has_vote')->clear_caches;
}


##############################################################################

sub clear_caches
{
    delete  $_[0]->{'gov'};
}


##############################################################################



1;

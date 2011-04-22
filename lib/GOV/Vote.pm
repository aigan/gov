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
    my( $vote ) = @_;

    ## TODO: Generalize... this is just for Yay_Nay and Ranked...

    if( $vote->has_pred('places_alternative') )
    {
	my( $palts ) = $vote->arc_list('places_alternative')->sorted('weight','desc');
	my $res = "";
	while( my $alt = $palts->get_next_nos )
	{
	    $res .= sprintf "%d: %s\n", $alt->weight, $alt->obj->sysdesig;
	}
	return $res;
    }
    else
    {
	my $name = $vote->weight == 1  ? 'Yay'
	         : $vote->weight == -1 ? 'Nay'
	         :                       'Blank';

	return loc($name);
    }
}

##############################################################################

sub as_html
{
    my( $vote, $args ) = @_;
    $args ||= {};

    if( $args->{'long'} )
    {
	## TODO: Generalize... this is just for Yay_Nay and Ranked...

	if( $vote->has_pred('places_alternative') )
	{
	    my( $palts ) = $vote->arc_list('places_alternative')->sorted('weight','desc');
	    my $res = '<table class="vote_alternatives">';
	    while( my $alt = $palts->get_next_nos )
	    {
		$res .= sprintf "<tr><td>%d</td><td>%s</td></tr>\n", $alt->weight, $alt->obj->wu_jump;
	    }
	    $res .= "</table>\n";
	    return $res;
	}
	else
	{
	    my $name = $vote->weight == 1  ? 'Yay'
	             : $vote->weight == -1 ? 'Nay'
		     :                       'Blank';
	    return loc($name);
	}
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
    my( $vote ) = @_;

    ## TODO: Generalize... this is just for Yay_Nay and Ranked...

    if( $vote->has_pred('places_alternative') )
    {
	my( $palts ) = $vote->arc_list('places_alternative')->sorted('weight','desc');
	return $palts->get_first_nos->obj->desig;
    }
    else
    {
	my $name = $vote->weight == 1  ? 'Yay'
	         : $vote->weight == -1 ? 'Nay'
	         :                       'Blank';

	return loc($name);
    }
}

##############################################################################

sub sysdesig
{
    my( $vote ) = @_;

    ## TODO: Generalize... this is just for Yay_Nay and Ranked...

    if( $vote->has_pred('places_alternative') )
    {
        return $vote->id .': '.
	  $vote->arc_list('places_alternative')->sorted('weight','desc')->desig;
    }
    else
    {
	my $name = $vote->weight == 1  ? 'Yay'
	         : $vote->weight == -1 ? 'Nay'
	         :                       'Blank';

	return $vote->id .': '.$name;
    }
}

##############################################################################

sub safedesig
{
    my( $vote ) = @_;
    return $vote->id;
}

##############################################################################

sub on_arc_add
{
    shift->clear_caches(@_);
}

##############################################################################

sub on_arc_del
{
    shift->clear_caches(@_);
}


##############################################################################

sub clear_caches
{
    my( $vote ) = @_;

    $vote->revlist('has_vote')->clear_caches;
}

##############################################################################



1;

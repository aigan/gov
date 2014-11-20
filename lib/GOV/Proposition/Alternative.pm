# -*-cperl-*-
package GOV::Proposition::Alternative;

#=============================================================================
#
# AUTHOR
#   Jonas Liljegren   <jonas@liljegren.org>
#
# COPYRIGHT
#   Copyright (C) 2009-2011 Jonas Liljegren
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#=============================================================================

=head1 NAME

GOV::Proposition::Alternative

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use Carp qw( confess croak carp );

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );

use RDF::Base::Widget qw( aloc );


##############################################################################

=head2 excerpt_input

=cut

sub excerpt_input
{
    my( $alt, $length ) = @_;

    $length ||= 150;
    my $html = $alt->prop('has_body')->loc or return;

    my $text = HTML::FormatText->format_string( $html,
						leftmargin => 0,
						rightmargin => $length+50);
    return substr $text, 0, $length+10;
}


##############################################################################

sub table_stats
{
    my( $alt ) = @_;

    my $prop = $alt->first_revprop('has_alternative');
    my $count = $prop->get_alternative_vote_count($alt);
    my $pd = $prop->get_alternative_place_data($alt);
    my $out = "";

    $out .= "<tr><td><strong>";
    $out .= aloc('Place');
    $out .= "</strong></td><td><strong>";
    $out .= $pd->{place};
    $out .= "</strong> ";
    $out .= aloc('since [_1]', $pd->{date});
    $out .= "</td></tr><tr><td>";
    $out .= aloc('First place');
    $out .= "</td><td>";
    $out .= $count->{first};
    $out .= " (";
    $out .= $count->{first_percent};
    $out .= ")</td></tr><tr><td>";
    $out .= aloc('Promoting');
    $out .= "</td><td>";
    $out .= $count->{yay};
    $out .= " (";
    $out .= $count->{yay_percent};
    $out .= ")</td></tr><tr><td>";
    $out .= aloc('Neutral');
    $out .= "</td><td>";
    $out .= $count->{blank};
    $out .= " (";
    $out .= $count->{blank_percent};
    $out .= ")</td></tr><tr><td>";
    $out .= aloc('Demoting');
    $out .= "</td><td>";
    $out .= $count->{nay};
    $out .= " (";
    $out .= $count->{nay_percent};
    $out .= ")</td></tr>";

    return $out;
}


##############################################################################


1;

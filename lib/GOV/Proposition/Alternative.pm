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


1;

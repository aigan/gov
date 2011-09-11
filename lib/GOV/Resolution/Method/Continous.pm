# -*-cperl-*-
package GOV::Resolution::Method::Continous;

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

GOV::Resolution::Method::Continous

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use DateTime::Infinite;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );


##############################################################################

sub should_resolve
{
    my( $method, $prop ) = @_;

    return 0;
}

##############################################################################

sub predicted_resolution_date
{
    return shift->{'end_time'} ||= DateTime::Infinite::Future->new();
}

##############################################################################

sub resolution_date
{
    return shift->{'end_time'} ||= DateTime::Infinite::Future->new();
}

##############################################################################

1;

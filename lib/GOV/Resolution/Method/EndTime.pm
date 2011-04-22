# -*-cperl-*-
package GOV::Resolution::Method::EndTime;

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

GOV::Resolution::Method::EndTime

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );

use Rit::Base::Literal::Time qw( now );

##############################################################################

sub should_resolve
{
    my( $method, $prop ) = @_;

    return 1 if $method->end_time($prop) <= now;
    return 0;
}

##############################################################################

sub predicted_resolution_date
{
    return shift->end_time(@_);
}

##############################################################################

sub resolution_date
{
    return shift->end_time(@_);
}

##############################################################################

sub end_time
{
    my( $method, $prop ) = @_;

    return $prop->{'gov'}{'end_time'} ||=
      $prop->create_rec->created + DateTime::Duration->new( days => 7 );
}

##############################################################################

1;

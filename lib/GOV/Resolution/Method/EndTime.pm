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

    if( not $prop->{'gov'}{'end_time'} )
    {
	if( my $time = $prop->first_prop('has_voting_endtime') )
	{
	    return $prop->{'gov'}{'end_time'} = $time;
	}

	my $days = $prop->first_prop('has_voting_duration_days')->plain;

	unless( $days )
	{
	    my $area = $prop->first_prop('subsides_in');
	    $days = $area->first_prop('has_voting_duration_days')->plain;
	}

	$days ||= 7;

	my $time = $prop->create_rec->created +
	  DateTime::Duration->new( days => $days );

	$prop->{'gov'}{'end_time'} = $time;
    }

    return $prop->{'gov'}{'end_time'};
}

##############################################################################

1;

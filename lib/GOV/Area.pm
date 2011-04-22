# -*-cperl-*-
package GOV::Area;

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

use 5.010;
use strict;
use warnings;

use Para::Frame::Reload;

##############################################################################

sub number_of_voters
{
    my( $area, $args ) = @_;

    return $area->revcount('has_voting_jurisdiction',$args);
}

##############################################################################

sub admin_controls_membership
{
    my( $area ) = @_;
    if( my $memcrit = $area->first_prop('has_membership_criteria') )
    {
	return $memcrit->admin_controls_membership;
    }

    return 1;
}


##############################################################################

1;

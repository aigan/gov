# -*-cperl-*-
package GOV;

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
use Para::Frame::Utils qw( debug datadump throw validate_utf8 catch create_dir );

use RDF::Base::Utils qw( valclean parse_propargs query_desig );
use RDF::Base::Constants qw( $C_proposition );

use GOV::User;

our $CFG;
our $BGJOB_LAST;
our $BGJOB_FREQUENCY = 60*60;

##############################################################################

=head2 store_cfg

=cut

sub store_cfg
{
    $CFG = $_[1];
}


##############################################################################


##############################################################################

sub run_background_jobs
{
    # Frequency of BGJOBS
    return unless !$BGJOB_LAST or time - $BGJOB_LAST > $BGJOB_FREQUENCY;

    debug "Background job is run.";

    my $props = $C_proposition->revlist('is');
    while( my $prop = $props->get_next_nos )
    {
        next unless $prop->is_open;
        if( $prop->should_be_resolved )
	{
            $prop->resolve;
        }
    }

    RDF::Base::Constants->get('membership_criteria_by_json_attribute')->
	revlist('is')->update_membership();

    $BGJOB_LAST = time;
}


##############################################################################




1;

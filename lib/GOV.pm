# -*-cperl-*-
package GOV;

#=============================================================================
#
# AUTHOR
#   Fredrik Liljegren   <fredrik@liljegren.org>
#   Jonas Liljegren   <jonas@liljegren.org>
#
# COPYRIGHT
#   Copyright (C) 2009-2011 Fredrik Liljegren
#   Copyright (C) 2012-2020 Jonas Liljegren
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
use RDF::Base::Email::Bulk;

use GOV::User;

our $CFG;
our $BGJOB_LAST;
our $BGJOB_FREQUENCY = 30;

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
#	debug 1, "run_background_jobs " . $BGJOB_FREQUENCY;
	if( !$BGJOB_LAST )
	{
		$BGJOB_LAST = time;
	}

	# Frequency of BGJOBS
	return unless time - $BGJOB_LAST > $BGJOB_FREQUENCY;

  my $req = $Para::Frame::REQ || Para::Frame::Request->new_bgrequest();
	debug "Background job is run.";

	$req->add_background_job('Process bulkmail', sub{ RDF::Base::Email::Bulk->continue_any});


	my $props = $C_proposition->revlist('is');
	while( my $prop = $props->get_next_nos )
	{
		next unless $prop->is_open;
		if( $prop->should_be_resolved )
		{
	    eval
	    {
				$prop->resolve;
	    }; # Just in case of race condition
		}
	}

	RDF::Base::Constants->get('membership_criteria_by_json_attribute')->
			revlist('is')->update_membership();

	$BGJOB_LAST = time;
}


##############################################################################




1;

# -*-cperl-*-
package GOV::Area::Membership::JSON;

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
use Para::Frame::Utils qw( debug );

use Rit::Base::Utils qw( parse_propargs );

use GOV::User;


##############################################################################

sub update_membership
{
    my( $mc ) = @_;
    my( $args, $arclim, $res ) = parse_propargs();

    my $attr_true = $mc->first_prop('using_json_attribute_true');
    unless( $attr_true )
    {
	debug "criteria missing for ".$mc->sysdesig;
	return;
    }

    my $data = GOV::User->from_wp('users_by_meta',{true=>$attr_true});
    return unless $data;
    my $udata_list = $data->{'users'} or return;
    debug "Got ".$data->{'count'}." members";

    my %members;
    foreach my $udata ( @$udata_list )
    {
	my $cas_id = $udata->{'ID'};
	my $member = GOV::User->get_by_cas_id( $cas_id );

	# Similar to GOV::User->update_from_wp()
	$member->update({
			 'has_email'  => $udata->{'user_email'},
			 'name'       => $udata->{'display_name'},
			 'name_short' => $udata->{'user_login'},
			}, $args );
	$members{$member->id} = $member;
    }

    foreach my $area ( $mc->revlist('has_membership_criteria')->as_array )
    {
	my %members_missing = %members;
	foreach my $old_membership_arc
	  ( $area->revarc_list('has_voting_jurisdiction')->as_array )
	  {
	      my $old_member = $old_membership_arc->subj;
	      my $mid = $old_member->id;
	      delete $members_missing{$mid};
	      unless( $members{$mid} ) # Still a member?
	      {
		  $old_membership_arc->remove( $args );
	      }
	  }

	# New members
	foreach my $new_member ( values %members_missing )
	{
	    $new_member->add({has_voting_jurisdiction => $area}, $args);
	}
    }

    $res->autocommit({ activate => 1 });

    return;
}


##############################################################################

sub admin_controls_membership
{
    return 0;
}


##############################################################################

1;

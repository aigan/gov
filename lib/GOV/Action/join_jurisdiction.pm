#-*-cperl-*-
package GOV::Action::join_jurisdiction;


#=============================================================================
#
# AUTHOR
#   Fredrik Liljegren   <fredrik@liljegren.org>
#
# COPYRIGHT
#   Copyright (C) 2011 Fredrik Liljegren
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#=============================================================================

use 5.010;
use strict;
use warnings;

use Para::Frame::Reload;
use Para::Frame::Utils qw( throw passwd_crypt debug datadump );

use Rit::Base::Utils qw( string parse_propargs );
use Rit::Base::Widget qw( locnl );
use Rit::Base::Constants qw( $C_free_membership );



sub handler
{
    my( $req ) = @_;

    my $q = $req->q;
    my $u = $req->user;
    my $R = Rit::Base->Resource;

    my $area_id =  $q->param('area')
      or throw('incomplete', locnl('Missing area'));
    my $area = $R->get($area_id)
      or throw('incomplete', locnl('Missing area'));

    unless( $area->has_membership_criteria($C_free_membership) )
    {
	throw('validation', locnl('Proposition area is not free'));
    }

    if( $u->has_voting_jurisdiction($area) )
    {
	return locnl('You are already a member of this area');
    }

    $area->add_member( $u );

    return locnl('Proposition area joined');
}

1;

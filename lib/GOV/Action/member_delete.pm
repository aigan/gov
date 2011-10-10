#-*-cperl-*-
package GOV::Action::member_delete;

#=============================================================================
#
# AUTHOR
#   Jonas Liljegren   <jonas@liljegren.org>
#
# COPYRIGHT
#   Copyright (C) 2011 Jonas Liljegren
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#=============================================================================

use 5.010;
use strict;
use warnings;

use Digest::MD5  qw(md5_hex);

use Para::Frame::Reload;
use Para::Frame::Utils qw( throw passwd_crypt debug datadump );
use Para::Frame::Email::Sending;

use Rit::Base::Utils qw( string parse_propargs );
use Rit::Base::Constants qw( $C_login_account $C_proposition_area );
use Rit::Base::Literal::Time qw( now );
use Rit::Base::Widget qw( locnl );


sub handler
{
    my( $req ) = @_;

    my $q = $req->q;
    my $u = $req->user;
    my $R = Rit::Base->Resource;

    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $id = $q->param('id')
      or throw('incomplete', locnl('Missing ID.'));

    my $m = $R->get($id);
    unless( $m->is($C_login_account) )
    {
	throw('validation', locnl('[_1] is not a login account', $id));
    }

    unless( $u->has_root_access )
    {
	unless( $u->equals($m) )
	{
	    throw('denied', locnl('You can only change your own settings'));
	}
    }

    my $all = parse_propargs( {
			       arclim => [1, 2],
			       unique_arcs_prio => undef,
			       force_recursive => 1,
			       res => $res,
			      });

    $m->arc_list('name',undef, $all)->remove($all);
    $m->arc_list('name_short',undef, $all)->remove($all);
    $m->arc_list('has_email',undef, $all)->remove($all);
    $m->arc_list('wants_notification_on',undef, $all)->remove($all);

    if( $u->equals($m) )
    {
	$u->logout;
    }

    return locnl('Account names and emails deleted');
}

1;

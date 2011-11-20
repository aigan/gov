# -*-cperl-*-
package GOV::Action::make_area_admin;

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

use Para::Frame::Utils qw( throw debug );

use RDF::Base::Literal::Time qw( now );
use RDF::Base::Utils qw( parse_propargs );
use RDF::Base::Constants qw( $C_proposition_area );
use RDF::Base::Widget qw( locnl );

=head1 DESCRIPTION

Run from member/index.tt to make a member area administrator

=cut

sub handler {
    my( $req ) = @_;

    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $q = $req->q;
    my $u = $req->user;
    my $R = RDF::Base->Resource;

    # Area check
    my $area_id = $q->param('area')
      or throw('incomplete', locnl('Area missing'));
    my $area = $R->get($area_id);
    throw('incomplete', locnl('Incorrect area id'))
      unless( $area and $area->is($C_proposition_area) );

    # Member check
    my $member_id = $q->param('member')
      or throw('incomplete', locnl('Member missing'));
    my $member = $R->get($member_id);
    throw('incomplete', locnl('Member missing'))
      unless( $member and $member->is('login_account') );

    # Permission check
    throw('denied', locnl('You don\'t have permission to make a member an area administrator in "[_1]".', $area->name))
      unless( $u->level >= 20 or $u->administrates_area($area) );

    $member->add({ administrates_area => $area }, $args);
    $res->autocommit({ activate => 1 });

    return locnl('Member "[_1]" now has administration permissions in area "[_2]".', $member->name, $area->name);
}


1;

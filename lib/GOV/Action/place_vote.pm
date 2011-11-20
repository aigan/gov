# -*-cperl-*-
package GOV::Action::place_vote;

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
use RDF::Base::Constants qw( $C_proposition );
use RDF::Base::Widget qw( locnl );

=head1 DESCRIPTION

Places a vote on a proposition.  If user already has a vote, that is deactivated.

Any member can vote on a proposition.  Only those with jurisdiction
will be counted.  This is useful e.g. for delegates

=cut

sub handler {
    my( $req ) = @_;

    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $q = $req->q;
    my $R = RDF::Base->Resource;
    my $u = $req->user or throw('denied', "Log in");
    $u->level or throw('denied', "Log in");

    my $prop_id = $q->param('id')
      or throw('incomplete', 'Proposition id missing');
    my $prop = $R->get($prop_id);
    $prop->is($C_proposition) or throw('validation', "Not a prop");
    throw('denied', locnl('Proposition is already resolved'))
      if( $prop->is_resolved );

    my $vote_in = $q->param('vote')
      or throw('incomplete', 'Vote missing');

    my $area = $prop->area;

    my $resp = "";
    if( $area->is_free and not $u->has_voting_jurisdiction($area) )
    {
	$area->add_member( $u );
	$resp .= locnl('Proposition area joined')."\n";
    }

    if( not $u->has_voting_jurisdiction($area) )
    {
	$resp .= locnl('You do not have jurisdiction in "[_1]".', $area->desig)."\n";
	$resp .= locnl('If you are, or later chose to become, a delegate, your vote is still relevant.'."\n");
    }

    my $vote = $prop->register_vote( $u, $vote_in );

    $resp .= locnl('Vote placed');

    return $resp;
}


1;

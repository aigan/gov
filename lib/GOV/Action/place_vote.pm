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

use Rit::Base::Literal::Time qw( now );
use Rit::Base::Utils qw( parse_propargs );
use Rit::Base::Constants qw( $C_proposition );
use Rit::Base::Widget qw( locnl );

=head1 DESCRIPTION

Places a vote on a proposition.  If user already has a vote, that is deactivated.

Any member can vote on a proposition.  Only those with jurisdiction
will be counted.  This is useful e.g. for delegates

=cut

sub handler {
    my( $req ) = @_;

    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $q = $req->q;
    my $R = Rit::Base->Resource;
    my $u = $req->user or throw('denied', "Log in");

    my $prop_id = $q->param('id')
      or throw('incomplete', 'Proposition id missing');
    my $prop = $R->get($prop_id);
    $prop->is($C_proposition) or throw('validation', "Not a prop");
    throw('denied', locnl('Proposition is already resolved'))
      if( $prop->is_resolved );

    my $vote_in = $q->param('vote')
      or throw('incomplete', 'Vote missing');

    my $vote = $prop->register_vote( $u, $vote_in );

    return locnl('Vote placed');
}


1;

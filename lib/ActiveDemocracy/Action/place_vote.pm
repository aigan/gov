# -*-cperl-*-
package ActiveDemocracy::Action::place_vote;

#=============================================================================
#
# AUTHOR
#   Fredrik Liljegren   <fredrik@liljegren.org>
#
# COPYRIGHT
#   Copyright (C) 2005-2009 Avisita AB.  All Rights Reserved.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#=============================================================================

use 5.010;
use strict;
use warnings;

use Para::Frame::L10N qw( loc );
use Para::Frame::Utils qw( throw debug );

use Rit::Base::Literal::Time qw( now );
use Rit::Base::Utils qw( parse_propargs );

=head1 DESCRIPTION



=cut

sub handler {
    my( $req ) = @_;

    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $q = $req->q;
    my $u = $req->user;
    my $R = Rit::Base->Resource;

    my $vote_in = $q->param('vote')
      or throw('incomplete', 'Vote missing');
    my $proposition_id = $q->param('id')
      or throw('incomplete', 'Proposition id missing');
    my $proposition = $R->get($proposition_id)
      or throw('incomplete', 'Proposition missing');
    my $area = $proposition->area;

    if( $u->has_voting_jurisdiction( $area ) )
    {
	my $vote = $proposition->register_vote( $u, $vote_in );

	return 'Vote placed';
    }
    else
    {
	return loc('You don\'t have jurisdiction in _[1]', $area->desig);
    }
}


1;

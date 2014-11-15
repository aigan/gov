# -*-cperl-*-
package GOV::Action::add_vote_alternative;

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
use RDF::Base::Widget qw( locnl );
use RDF::Base::Constants qw( $C_proposition $C_vote_alternative );

=head1 DESCRIPTION



=cut

sub handler {
    my( $req ) = @_;

    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $q = $req->q;
    my $R = RDF::Base->Resource;
    my $u = $req->user or throw('denied', "Log in");
    my $id = $q->param('id') or throw('validation', "id missing");

    my $prop = $R->get($id);
    $prop->is($C_proposition) or throw('validation', "Not a prop");


    my $name = $q->param('name')
      or throw('incomplete', 'Name missing');

    my $url = $q->param('discussion_url') or undef;
    my $text = $q->param('text') or undef;

    my $area = $prop->subsides_in;
    unless( $u->has_voting_jurisdiction( $area ) )
    {
        return locnl('You don\'t have jurisdiction in [_1]', $area);
    }

    my $similar = $R->find({ rev_has_alternative => $prop,
                             is => $C_vote_alternative,
                             name_clean => $name,
                           });

    if ( $similar->size )
    {
        throw('validation', locnl("Name to similar to existing alternative"));
    }


    my $alt
      = $R->create({
                    is          => $C_vote_alternative,
                    name        => $name,
                    has_body    => $text,
                    has_url     => $url,
                   }, $args);

    $prop->add({has_alternative => $alt}, $args);

    $alt->mark_updated;
    $prop->mark_updated;

    $res->autocommit({ activate => 1 });
    $prop->add_alternative_place();

    $q->param('id', $prop->id);
    $q->param('alt', $alt->id);

    # $alt->notify_members();

    return locnl('Vote alternative for proposition created');
}


1;

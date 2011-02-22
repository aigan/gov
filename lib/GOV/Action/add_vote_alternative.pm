# -*-cperl-*-
package GOV::Action::add_vote_alternative;

#=============================================================================
#
# AUTHOR
#   Fredrik Liljegren   <fredrik@liljegren.org>
#
# COPYRIGHT
#   Copyright (C) 2009 Fredrik Liljegren
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

use Rit::Base::Constants qw( $C_proposition $C_vote_alternative );

=head1 DESCRIPTION



=cut

sub handler {
    my( $req ) = @_;

    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $q = $req->q;
    my $R = Rit::Base->Resource;
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
        return loc('You don\'t have jurisdiction in [_1].', $area);
    }

    my $alt
      = $R->create({
                    is          => $C_vote_alternative,
                    name        => $name,
                    has_body    => $text,
                    has_url     => $url,
                   }, $args);

    $prop->add({has_alternative => $alt}, $args);


    $res->autocommit({ activate => 1 });

    $q->param('id', $prop->id);

    # $alt->notify_members();

    return loc('Vote alternative for proposition created.');
}


1;

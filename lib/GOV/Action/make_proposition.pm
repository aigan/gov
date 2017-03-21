# -*-cperl-*-
package GOV::Action::make_proposition;

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
use RDF::Base::Constants qw( $C_resolution_method_progressive );
use RDF::Base::Widget qw( locnl );

=head1 DESCRIPTION



=cut

sub handler {
    my( $req ) = @_;

    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $q = $req->q;
    my $u = $req->user;
    my $R = RDF::Base->Resource;
    my $id = $q->param('id');


    #my $allowed_preds   = {
    #			   is          => $C_proposition,
    #			   name        => '*',
    #			   subsides_in => '*',
    #			   has_body    => '*',
    #			  };
    #
    #my $node = RDF::Base::Resource->get($id);
    #if( 1 ) #$node->check_query_permissions( $allowed_preds ) )
    #{
    #	$node->update_by_query($args);
    #	$res->autocommit( activate => 1 );
    #}

    my $name = $q->param('name')
      or throw('incomplete', 'Name missing');

    my $url = $q->param('discussion_url')
      or throw('incomplete', 'Discussion url missing');

    my $area = $q->param('area')
      or throw('incomplete', 'Subsidiary area missing');

    my $type = $q->param('type')
      or throw('incomplete', 'Type missing');

    my $text = $q->param('text')
      or throw('incomplete', 'Text missing');

    my $method = $q->param('method')
      or throw('incomplete', 'Resolution method missing');

#    my $p_weight = 7;

    return locnl('Proposition creations closed for now')
      unless( $u->administrates_area( $area ) );

    unless( $u->has_voting_jurisdiction( $area ) ) {
        return locnl('You don\'t have jurisdiction in [_1].', $area);
    }

    my $prop
      = $R->create({
                    is          => $type,
                    name        => $name,
                    subsides_in => $area,
                    has_body    => $text,
                    has_url     => $url,
#                    resolution_progressive_weight => $p_weight,
                    has_resolution_method => $method,
                   }, $args);

    $prop->mark_updated;

    $res->autocommit({ activate => 1 });

    $q->param('id', $prop->id);

    $prop->notify_members();

    return locnl('Proposition created.');
}


1;

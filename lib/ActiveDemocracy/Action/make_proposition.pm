# -*-cperl-*-
package ActiveDemocracy::Action::make_proposition;

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

=head1 DESCRIPTION



=cut

sub handler {
    my( $req ) = @_;

    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $q = $req->q;
    my $u = $req->user;
    my $R = Rit::Base->Resource;
    my $id = $q->param('id');

    #my $allowed_preds   = {
    #			   is          => $C_proposition,
    #			   name        => '*',
    #			   subsides_in => '*',
    #			   has_body    => '*',
    #			  };
    #
    #my $node = Rit::Base::Resource->get($id);
    #if( 1 ) #$node->check_query_permissions( $allowed_preds ) )
    #{
    #	$node->update_by_query($args);
    #	$res->autocommit( activate => 1 );
    #}

    my $name = $q->param('name')
      or throw('incomplete', 'Name missing');

    my $area = $q->param('area')
      or throw('incomplete', 'Subsidiary area missing');

    my $type = $q->param('type')
      or throw('incomplete', 'Type missing');

    my $text = $q->param('text')
      or throw('incomplete', 'Text missing');

    unless( $u->has_voting_jurisdiction( $area ) ) {
        return loc('You don\'t have jurisdiction in [_1].', $area);
    }

    $R->create({
		is          => $type,
		name        => $name,
		subsides_in => $area,
		has_body    => $text,
	       }, $args);
    $res->autocommit({ activate => 1 });
}


1;

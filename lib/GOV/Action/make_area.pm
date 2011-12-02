# -*-cperl-*-
package GOV::Action::make_area;

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

Run from area/new.tt

=cut

sub handler {
    my( $req ) = @_;

    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $q = $req->q;
    my $u = $req->user;
    my $R = RDF::Base->Resource;
    my $id = $q->param('id');

    return locnl('You don\'t have permission to create a proposition area.')
      if( $u->level < 20 );


    my $name = $q->param('name')
      or throw('incomplete', 'Name missing');

    my $area = $q->param('progressive_default_weight')
      or throw('incomplete', 'Progressive default weight missing');

    $R->create({
		is          => $C_proposition_area,
		name        => $name,
	       }, $args);
    $res->autocommit({ activate => 1 });

    return locnl('Area "[_1]" created.', $name);
}


1;

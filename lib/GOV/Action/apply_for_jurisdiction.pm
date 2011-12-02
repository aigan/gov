#-*-cperl-*-
package GOV::Action::apply_for_jurisdiction;


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

use Para::Frame::Reload;
use Para::Frame::Utils qw( throw passwd_crypt debug datadump );

use RDF::Base::Utils qw( string parse_propargs );
use RDF::Base::Widget qw( locnl );


sub handler
{
    my( $req ) = @_;

    my $q = $req->q;
    my $R = RDF::Base->Resource;

    my $u = $req->user;

    my $area_id =  $q->param('area')
      or throw('incomplete', locnl('Missing area'));
    my $area = $R->get($area_id)
      or throw('incomplete', locnl('Missing area'));

    unless( $u->can_apply_for_membership_in($area) )
    {
	throw('validation', locnl('Application not availible'));
    }

    $u->apply_for_jurisdiction( $area );

    return locnl('Application sent');
}

1;

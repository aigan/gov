#-*-cperl-*-
package GOV::Action::test;

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

    sleep(7);

    return 'Testing';
}

1;

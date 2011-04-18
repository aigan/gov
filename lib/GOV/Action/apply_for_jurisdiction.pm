#-*-cperl-*-
package GOV::Action::apply_for_jurisdiction;

use strict;

use Para::Frame::Reload;
use Para::Frame::Utils qw( throw passwd_crypt debug datadump );

use Rit::Base::Utils qw( string parse_propargs );
use Rit::Base::Widget qw( locnl );


sub handler
{
    my( $req ) = @_;

    my $q = $req->q;
    my $R = Rit::Base->Resource;

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

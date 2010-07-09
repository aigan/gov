#-*-cperl-*-
package ActiveDemocracy::Action::apply_for_jurisdiction;

use strict;

use Para::Frame::Reload;
use Para::Frame::Utils qw( throw passwd_crypt debug datadump );
use Para::Frame::L10N qw( loc );

use Rit::Base::Utils qw( string parse_propargs );


sub handler
{
    my( $req ) = @_;

    my $q = $req->q;
    my $R = Rit::Base->Resource;

    my $u = $req->user;

    my $area_id =  $q->param('area')
      or throw('incomplete', loc('Missing area.'));
    my $area = $R->get($area_id)
      or throw('incomplete', loc('Missing area.'));

    my( $args, $arclim, $res ) = parse_propargs('relative');
    $u->add({ has_voting_jurisdiction => $area }, $args);
    $res->autocommit({ submit => 1 });

    return loc('Application sent.');
}

1;


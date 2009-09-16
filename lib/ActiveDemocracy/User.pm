# -*-cperl-*-
package ActiveDemocracy::User;

use 5.010;
use strict;
use warnings;
use base qw( Rit::Base::User Rit::Base::Resource );

use Digest::MD5  qw(md5_hex);

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug trim );

use Rit::Base::Utils qw( is_undef parse_propargs );
use Rit::Base::User;
use Rit::Base::Constants qw( $C_login_account $C_guest_access );
use Rit::Base::Literal::Time qw( now );

##############################################################################

sub set_password
{
    my( $u, $passwd, $args ) = @_;

    my $req      = $Para::Frame::REQ;
    my $md5_salt = $Para::Frame::CFG->{'md5_salt'};
    my $dbh      = $Rit::dbix->dbh;

    $passwd      = md5_hex($passwd, $md5_salt);

    $req->user->update({ has_password => $passwd }, $args );

    return;
}


##############################################################################

sub is_owned_by
{
    my( $user, $agent ) = @_;

    debug "Checking if ". $user->desig ." is owned by ". $agent->desig;

    if( $user->equals( $agent ) )
    {
	debug "  - yess!";
	return 1;
    }
    else
    {
	debug "  - no...";
    }

    return Rit::Base::Resource::is_owned_by( $user, $agent );
}


##############################################################################

1;

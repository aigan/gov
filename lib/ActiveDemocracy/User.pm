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

sub find_vote
{
    my( $user, $proposition ) = @_;

    my( $vote, $delegate );

    my $R     = Rit::Base->Resource;

    $delegate = $user;
    $vote = $R->find({
                      rev_places_vote => $user,
                      rev_has_vote    => $proposition,
                     });

    unless( $vote ) { # Check for delegation
        my $delegate_arcs
          = $user->arc_list('delegates_votes_to')->sorted('weight');

        while( my $delegate_arc = $delegate_arcs->get_next_nos ) {
            $delegate = $delegate_arc->obj;

            $vote = $R->find({
                              rev_places_vote => $delegate,
                              rev_has_vote    => $proposition,
                             });
            if( $vote ) {
                last;
            }
        }
    }

    return( $vote, $delegate );
}


##############################################################################




1;

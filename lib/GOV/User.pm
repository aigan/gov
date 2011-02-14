# -*-cperl-*-
package ActiveDemocracy::User;

use 5.010;
use strict;
use warnings;
use base qw( Rit::Base::User Rit::Base::Resource );

use Digest::MD5  qw(md5_hex);

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug trim );
use Para::Frame::L10N qw( loc );

use Rit::Base::Utils qw( is_undef parse_propargs query_desig );
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
#
# sub is_owned_by
# {
#     my( $user, $agent ) = @_;
#
#     debug "Checking if ". $user->desig ." is owned by ". $agent->desig;
#
#     if( $user->equals( $agent ) )
#     {
# 	debug "  - yess!";
# 	return 1;
#     }
#     else
#     {
# 	debug "  - no...";
#     }
#
#     return Rit::Base::Resource::is_owned_by( $user, $agent );
# }
#
#
##############################################################################

sub find_vote
{
    my( $user, $proposition, $args_in ) = @_;
    my( $args, $arclim, $res ) = parse_propargs($args_in);


    debug sprintf "Finding vote on %s from %s",
      $proposition->sysdesig, $user->sysdesig;
#    debug query_desig($args);

    my( $vote, $delegate );

    my $R = Rit::Base->Resource;

    $delegate = $user;

    $vote = $R->find({
                      rev_places_vote => $user,
                      rev_has_vote    => $proposition,
                     }, $args);

    unless( $vote )
    { # Check for delegation
	my $del_args = $args;

	# Check for delegations active on proposition resolution
	if( my $res_date = $proposition->proposition_resolved_date )
	{
	    debug "  resolved on ".$res_date->desig;
	    $del_args = {%$args, arc_active_on_date => $res_date};
	}


        my $delegate_arcs
          = $user->arc_list('delegates_votes_to',undef,$del_args)->
	    sorted('weight');

        while( my $delegate_arc = $delegate_arcs->get_next_nos ) {
            $delegate = $delegate_arc->obj;

            $vote = $R->find({
                              rev_places_vote => $delegate,
                              rev_has_vote    => $proposition,
                             }, $args);
            if( $vote ) {
                last;
            }
        }
    }

    return( $vote, $delegate );
}


##############################################################################

sub desig
{
    my( $user ) = @_;

    return $user->name_short
      if( $user->is_anonymous );

    return $user->name->loc || $user->name_short;
}

##############################################################################

sub apply_for_jurisdiction
{
    my( $user, $area ) = @_;

    if( $user->has_voting_jurisdiction( $area, { arclim => ['active', 'submitted'] } ) ) {
        # $user has already jurisdiction or application (submitted arc)
        return;
    }

    my( $args, $arclim, $res ) = parse_propargs('relative');
    $user->add({ has_voting_jurisdiction => $area }, $args);
    $res->autocommit({ submit => 1 });

    # Notify area administrators
    my $admins = $area->revlist('administrates_area', { has_email_exist => 1 });

    my $host = $Para::Frame::REQ->site->host;
    my $home = $Para::Frame::REQ->site->home_url_path;
    my $subject = loc('User [_1] has applied for jurisdiction in [_2].', $user->desig, $area->desig);
    my $body    = loc('User [_1] has applied for jurisdiction in [_2].', $user->desig, $area->desig);
    $body .= ' ' . loc('Go here to accept application: ') . 'http://' . $host . $home . '/member/list_applications.tt';

    while( my $admin = $admins->get_next_nos ) {
        my $email_address = $admin->has_email;
        my $email = Para::Frame::Email::Sending->new({ date => now });
        $email->set({
                     body    => $body,
                     from    => 'fredrik@liljegren.org',
                     subject => $subject,
                     to      => $email_address,
                    });
        $email->send_by_proxy();
    }
}


1;

# -*-cperl-*-
package GOV::User;

use 5.010;
use strict;
use warnings;
use base qw( Rit::Base::User );

use Digest::MD5  qw(md5_hex);
use Authen::CAS::Client;
use JSON; #from_json

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug trim catch datadump );
use Para::Frame::L10N qw( loc );

use Rit::Base::Utils qw( is_undef parse_propargs query_desig );
use Rit::Base::User;
use Rit::Base::Constants qw( $C_login_account $C_guest_access );
use Rit::Base::Literal::Time qw( now );

##############################################################################

sub get
{
#    debug "Getting GOV user $_[1]";

    if( $Para::Frame::CFG->{'cas_url'} )
    {
	if( not $_[1] eq 'guest' and
	    not $Para::Frame::REQ->session->cas_verified and
	    $Para::Frame::REQ->q->cookie('ticket') )
	{
	    debug "CAS lookup?";
	    # Trigger a new CAS verification
	    $_[1] = 'guest';
	}

#	$Para::Frame::REQ->add_job('run_code','cas_login',\&cas_login);
#	$Para::Frame::REQ->add_job('after_jobs');
#	&cas_login( $Para::Frame::REQ );
    }

    my $u = eval
    {
	$_[0]->Rit::Base::Resource::get($_[1]);
    };
    if( catch(['notfound']) )
    {
	debug "  user not found";
	return undef;
    }

#    debug "Got $u";
    return $u;

}

##############################################################################

sub clear_cookies
{
    shift->SUPER::clear_cookies;

    my $cookies = $Para::Frame::REQ->cookies;
    $cookies->remove('ticket');
}

##############################################################################

sub verify_password
{
    my( $u ) = shift;
    return 1 if $u->session->cas_verified;
    return $u->SUPER::verify_password(@_);
}

##############################################################################

sub get_by_cas_id
{
    my( $this, $cas_id ) = @_;

    my $nodes = Rit::Base::Resource->find({cas_id=>$cas_id});
    if( $nodes->size )
    {
	return $nodes->get_first_nos;
    }
    else
    {
	return Rit::Base::Resource->create({
					    is => $C_login_account,
					    cas_id => $cas_id,
					   }, {activate_new_arcs=>1});
    }
}

##############################################################################

sub update_from_wp
{
    my( $u, $args ) =  @_;

    my $cas_id = $u->first_prop('cas_id')->plain or return;

    my $data = $u->from_wp('get_user',{id=>$cas_id});
    my $udata = $data->{'user'};
    if( $udata )
    {
	$u->update({
		    'has_email'  => $udata->{'user_email'},
		    'name'       => $udata->{'display_name'},
		    'name_short' => $udata->{'user_login'},
		   }, $args );
    }

    return $u;
}

##############################################################################

sub from_wp
{
    my( $this, $code, $params ) =  @_;

    my $json_url = $Para::Frame::CFG->{'wp_json_url'};
    return unless $json_url;

    my $uri = Para::Frame::URI->new("$json_url/$code/");
    $uri->query_form($params);

    debug "JSON call to ".$uri->as_string;
    my $raw =  $uri->retrieve->content;
    unless( $raw )
    {
	debug "No response from WP";
	return;
    }

#    debug "Got ".$raw;

    # May return: status => 'denied'
    my $data;
    eval
    {
	$data = from_json( $raw );
    };
    if( $@ )
    {
	debug "Error reading data from WP: ".$@;
	return;
    }

    if( $data )
    {
	return $data;
    }
    else
    {
	debug "No data returned from WP";
    }

    return;
}

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
    my( $user, $prop, $args_in ) = @_;
    my( $args, $arclim, $res ) = parse_propargs($args_in);


#    debug sprintf "Finding vote on %s from %s",
#      $prop->sysdesig, $user->sysdesig;
#    debug query_desig($args);

    my( $vote, $delegate );

    my $R = Rit::Base->Resource;

    $delegate = is_undef;

    $vote = $R->find({
                      rev_places_vote => $user,
                      rev_has_vote    => $prop,
                     }, $args)->get_first_nos;

    unless( $vote )
    { # Check for delegation
	my $del_args = $args;

	# Check for delegations active on prop resolution
	if( my $res_date = $prop->proposition_resolved_date )
	{
	    debug "  resolved on ".$res_date->desig;
	    $del_args = {%$args, arc_active_on_date => $res_date};
	}


        my $delegate_arcs
          = $user->arc_list('delegates_votes_to',undef,$del_args)->
	    sorted('weight');

        while( my $delegate_arc = $delegate_arcs->get_next_nos )
	{
            $vote = $R->find({
                              rev_places_vote => $delegate_arc->obj,
                              rev_has_vote    => $prop,
                             }, $args)->get_first_nos;
            if( $vote )
	    {
		$delegate = $delegate_arc->obj;
                last;
            }
        }
    }

    return( $vote, $delegate );
}


##############################################################################

#sub desig
#{
#    my( $user ) = shift;
#
#    return $user->name_short if( $user->is_anonymous );
#
#    return $user->Rit::Base::Resource::desig(@_);
#}

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
    if( $Para::Frame::CFG->{'send_email'} )
    {
	my $admins = $area->revlist('administrates_area', { has_email_exist => 1 });

	my $host = $Para::Frame::REQ->site->host;
	my $home = $Para::Frame::REQ->site->home_url_path;
	my $subject = loc('User [_1] has applied for jurisdiction in [_2].',
			  $user->desig, $area->desig);
	my $body    = loc('User [_1] has applied for jurisdiction in [_2].',
			  $user->desig, $area->desig);
	$body .= ' ' . loc('Go here to accept application: ') .
	  'http://' . $host . $home . '/member/list_applications.tt';

	while( my $admin = $admins->get_next_nos )
	{
	    my $email_address = $admin->has_email;
	    my $email = Para::Frame::Email::Sending->new({ date => now });
	    $email->set({
			 body    => $body,
			 from    => $Para::Frame::CFG->{'email'},
			 subject => $subject,
			 to      => $email_address,
			});
	    $email->send_by_proxy();
	}
    }
}

##############################################################################


sub can_apply_for_membership_in
{
    my( $user, $area ) = @_;
    return 0 unless $area->admin_controls_membership;
    return 0 unless $user->level; # Not guests

    # Already applied or member?
    if( $user->has_voting_jurisdiction
	( $area, { arclim => [ 'active', 'submitted' ] }) )
    {
	return 0;
    }

    return 1;
}


##############################################################################

sub on_arc_add
{
    my( $user, $arc, $pred_name, $args ) = @_;

    # TODO: Bad to load props just to undef them!

    if( $pred_name eq 'delegates_votes_to' )
    {
	foreach my $area ( $user->list('has_voting_jurisdiction')->as_array )
	{
	    foreach my $prop ( $area->revlist('subsides_in')->as_array )
	    {
		$prop->clear_caches();
	    }
	}
    }
}

##############################################################################


1;

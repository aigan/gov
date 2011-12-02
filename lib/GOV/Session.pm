package GOV::Session;
#=============================================================================
#
# AUTHOR
#   Jonas Liljegren   <jonas@paranormal.se>
#
# COPYRIGHT
#   Copyright (C) 2011 Jonas Liljegren.  All Rights Reserved.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#=============================================================================

=head1 NAME

GOV::Session

=cut

use 5.010;
use strict;
use warnings;
use base qw( RDF::Base::Session );

use Carp qw( cluck );

use RDF::Base::Utils qw( parse_propargs );
#use RDF::Base::Constants qw( $C_login_account );
use RDF::Base::Widget qw( locn locnl );

use Para::Frame::Reload;
use Para::Frame::Utils qw( throw debug uri );
use Para::Frame::Widget qw( jump );

use GOV::User;


###########################################################################

=head2 init

=cut

sub init
{
#    my( $s ) = @_[0];
    debug "GOV Session init";
#    debug "  for user ".$s->user;
}


##############################################################################

sub cas_login
{
    my( $resp, $force ) = @_;

    my $req = $resp->req;
    my $s = $req->session;
    my $q = $req->q;

    if( $q->param('autologin') ) # Redo cas login?
    {
        delete $s->{'gov_cas_ticket'};
        $q->delete('cas_session');
        $q->delete('run');
    }

    return if $s->{'gov_cas_ticket'} and not $q->param('ticket');
    return if $Para::Frame::U->username ne 'guest' and $q->cookie('password');
    return if $q->param('run'); # Not during other actions (needed by bg-jobs)
    return if $req->browser->robot();
    return if $req->response_if_existing and $req->response->is_error_response;

    debug "in cas_login";
    debug "Browser: ".$ENV{'HTTP_USER_AGENT'};

    my $cas = Authen::CAS::Client->new( $Para::Frame::CFG->{'cas_url'},
					fatal => 0 );

    if( my $ticket = $q->param('ticket') )
    {
	my $srv = $resp->page->url->canonical->as_string;
#	debug "Ticket ".$ticket;
	my $r = $cas->proxy_validate( $srv, $ticket );
	if( $r->is_success )
	{
#	    debug "User authenticated as: ". $r->user;
	    if( my $u = GOV::User->get_by_cas_id($r->user ) )
	    {
		$u->update_from_wp({activate_new_arcs=>1});

		$u->change_current_user( $u );
		$req->cookies->add({'username' => $u->username});
		$req->cookies->add({'ticket' => $ticket});
		$s->{'gov_cas_ticket'} = $ticket;

		if( my $res = $req->result )
		{
		    $res->message(locnl("Welcome back, [_1]", $u->name->loc));
		}
	    }
	}
	elsif( $r->is_failure )
	{
	    debug "Validation failed: ".$r->message;
	    debug $r->doc->toString;
	}
	else
	{
	    debug "Validation error: ".$r->error;
	    if( $r->doc )
	    {
		debug $r->doc->toString;
	    }
	}
    }
    elsif( $q->param('cas_session') )
    {
#	debug "So this is how it is then you are not logged in...";
	$s->{'gov_cas_ticket'} = 'guest';
    }
    else
    {
        my $srv_url = $resp->page->url_with_query;
        $srv_url->query_param_delete('ticket');
        $srv_url->query_param_delete('autologin');
        $srv_url->query_param_delete('run');
        $srv_url->query_param_append('cas_session'=>1);
	my $srv = $srv_url->canonical->as_string;
#	debug "Srv: ".$srv;

#	debug "Redirecting to CAS ".$Para::Frame::CFG->{'cas_url'};

	my $gateway = $force ? 0 : 1;
#	debug $cas->login_url($srv, gateway => $gateway);
        my $extra = "";
        if( $q->param('autologin') )
        {
            $q->delete('autologin');
            $extra = "&autologin=1";
        }
	$resp->redirect($cas->login_url($srv, gateway => $gateway).$extra);

	# access level error handled. No backtrack please
	$req->result->backtrack(0);
    }
}


##############################################################################

sub go_login
{
    return 0 unless $Para::Frame::CFG->{'cas_url'};

    my( $s, $resp ) = shift;
    $resp ||= $Para::Frame::REQ->response;

    # Force request of a new ticket
    $Para::Frame::REQ->q->delete('ticket');
    delete $s->{'gov_cas_ticket'};

    &cas_login( $resp, 1 );
    return 1;
}


##############################################################################

sub cas_verified
{
    return 1 if $_[0]->{'gov_cas_ticket'};
    return 0;
}


##############################################################################

sub after_user_logout
{
    debug "Removing session ticket";
    delete  $_[0]->{'gov_cas_ticket'};
    return $_[0]->SUPER::after_user_logout;
}


##############################################################################

=head2 wj_login

=cut

sub wj_login
{
    my( $s, $attrs ) = @_;

    $attrs ||= {};
    my $label = delete($attrs->{'label'}) || locn('Sign in');
    my $req = $Para::Frame::REQ;

    if( $Para::Frame::CFG->{'pp_sso'} )
    {
        my $dest = $req->site->home_url_path."/pp/login.tt";
        return jump($label, $dest);
    }
    elsif( not $Para::Frame::CFG->{'cas_url'} )
    {
	my $dest = $req->site->home_url_path."/login.tt";
	return jump($label, $dest);
    }

    return jump($label, $s->cas_login_url_string."&autologin=1");
}


##############################################################################

=head2 wj_logout

=cut

sub wj_logout
{
    my( $s, $attrs ) = @_;

    $attrs ||= {};
    my $label = delete($attrs->{'label'}) || locn('Sign out');
    my $req = $Para::Frame::REQ;

    unless( $Para::Frame::CFG->{'cas_url'} )
    {
	my $dest = uri($req->site->logout_page,
		       {run=>'user_logout'});
	return jump($label, $dest);
    }


    my $cas = Authen::CAS::Client->new( $Para::Frame::CFG->{'cas_url'},
					fatal => 0 );
#    my $srv = $resp->page->url->canonical->as_string;

    my $site = $req->site;
    my $dest = sprintf("%s://%s%s",
		       $site->scheme,
		       $site->host,
		       uri($req->site->logout_page,
			   {run=>'user_logout'}));
#    debug "Dest: ".$dest;
    my $url = uri($Para::Frame::CFG->{'cas_url'}.'/logout',
		  {service=>$dest});

#    my $url = $cas->logout_url('url' => $dest);

    return jump($label, $url);
}


###########################################################################

=head2 cas_login_url_string

=cut

sub cas_login_url_string
{
    my $cas = Authen::CAS::Client->new( $Para::Frame::CFG->{'cas_url'},
					fatal => 0 );
    my $resp = $Para::Frame::REQ->response;
    my $srv_url = $resp->page->url_with_query;
    $srv_url->clear_special_params;
    $srv_url->query_param_delete('ticket');
    $srv_url->query_param_delete('cas_session');
    my $srv = $srv_url->canonical->as_string;
    return $cas->login_url($srv);
}



###########################################################################

1;

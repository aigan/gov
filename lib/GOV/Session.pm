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
use base qw( Rit::Base::Session );

use Para::Frame::Reload;
use Para::Frame::Utils qw( throw debug uri );
use Para::Frame::Widget qw( jump );


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
    my( $resp ) = @_;

    my $req = $resp->req;
    my $s = $req->session;
    return if $s->{'gov_cas_ticket'};
    my $q = $req->q;
    return if $Para::Frame::U->username ne 'guest' and $q->cookie('password');
    # We may be about to do a manual login...
    return if $q->param('run'); # Not during other actions

    debug "in cas_login";
    my $cas = Authen::CAS::Client->new( $Para::Frame::CFG->{'cas_url'},
					fatal => 0 );
    my $srv = $resp->page->url->canonical->as_string;
#    debug "Srv: ".$srv;

    if( my $ticket = $q->param('ticket') )
    {
#	debug "Ticket ".$ticket;
	my $r = $cas->proxy_validate( $srv, $ticket );
	if( $r->is_success )
	{
#	    debug "User authenticated as: ". $r->user;
	    if( my $u = $s->get_by_cas_id($r->user) )
	    {
		$u->change_current_user( $u );
		$req->cookies->add({'username' => $u->username});
		$req->cookies->add({'ticket' => $ticket});
		$s->{'gov_cas_ticket'} = $ticket;
	    }
	}
	elsif( $r->is_failure )
	{
	    debug "Validation failed: ".$r->message;
	    debug $r->doc;
	}
	else
	{
	    debug "Validation error: ".$r->error;
	    debug $r->doc;
	}
    }
    else
    {
	debug "Redirecting to CAS ".$Para::Frame::CFG->{'cas_url'};
	$resp->redirect($cas->login_url($srv));
    }
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

sub get_by_cas_id
{
    my( $this, $cas_id ) = @_;

    my $nodes = Rit::Base::Resource->find({cas_id=>$cas_id});
    if( $nodes->size )
    {
	return $nodes->get_first_nos;
    }

    return undef;
}

###########################################################################


=head2 wj_logout

=cut

sub wj_logout
{
    my( $s, $attrs ) = @_;
    $attrs ||= {};
    my $req = $Para::Frame::REQ;

    my $label = delete($attrs->{'label'}) || 'Sign out';

    my $cas = Authen::CAS::Client->new( $Para::Frame::CFG->{'cas_url'},
					fatal => 0 );
#    my $srv = $resp->page->url->canonical->as_string;

    my $site = $req->site;
    my $dest = sprintf("%s://%s%s",
		       $site->scheme,
		       $site->host,
		       uri($req->site->logout_page,
			   {run=>'user_logout'}));
    debug "Dest: ".$dest;
    my $url = uri($Para::Frame::CFG->{'cas_url'}.'/logout',
		  {service=>$dest});

#    my $url = $cas->logout_url('url' => $dest);

    return jump($label, $url);
}


###########################################################################

1;

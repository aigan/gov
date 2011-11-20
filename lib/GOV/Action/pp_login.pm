#-*-cperl-*-
package GOV::Action::pp_login;

#=============================================================================
#
# AUTHOR
#   Jonas Liljegren   <jonas@liljegren.org>
#
# COPYRIGHT
#   Copyright (C) 2011 Jonas Liljegren
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#=============================================================================

use 5.010;
use strict;
use warnings;

use Para::Frame::Reload;
use Para::Frame::Utils qw( throw debug datadump );

use RDF::Base::Utils qw( string parse_propargs );
use RDF::Base::Widget qw( locnl );


sub handler
{
    my( $req ) = @_;

    my $q = $req->q;
    my $R = RDF::Base->Resource;

    my $user_class = $Para::Frame::CFG->{'user_class'};

    $req->run_hook('before_user_login', $user_class);


    my $result = $q->param('result');
    my $ticket = $q->param('ticket')
      or throw('incomplete', locnl("Ticket is missing"));

    if( $result eq 'fail' )
    {
        given( $q->param('reason') )
        {
            when(1) { throw('validation', locnl('Wrong user or password') ) };
            when(2) { throw('incomplete', locnl("Name or password is missing")) };
            when(3) { throw('denied', locnl("Epic fail. Panic now!")) };
            default { throw(locnl("Unknown error")) };
        }
    }

    my $u = $user_class->get_by_pp_ticket($ticket);

    $u or throw('validation', locnl("Can't lookup the given user"));
    $user_class->change_current_user( $u );
    my $username = $u->username;
    my $cas_id = $u->first_prop('cas_id');
    throw "User has no name" unless $username;

    $q->delete('password');
    $q->delete('ticket');

    $req->cookies->add({
                        'username' => $username,
                        'ticket' => $ticket,
                       },{
                          -expires => '+10y',
                         });


    $u->session->{'gov_cas_ticket'} = $ticket;

    $req->run_hook('user_login', $u);

    debug "Login sucessful";
    return "$username loggar in";
}

1;

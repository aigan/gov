#-*-cperl-*-
package GOV::Action::member_lost_password;

#=============================================================================
#
# AUTHOR
#   Fredrik Liljegren   <fredrik@liljegren.org>
#
# COPYRIGHT
#   Copyright (C) 2009-2011 Fredrik Liljegren
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#=============================================================================

use 5.010;
use strict;
use warnings;

use Digest::MD5  qw(md5_hex);

use Para::Frame::Reload;
use Para::Frame::Utils qw( throw passwd_crypt debug datadump make_passwd );

use RDF::Base::Utils qw( string parse_propargs query_desig );
use RDF::Base::Constants qw( $C_login_account $C_proposition_area );
use RDF::Base::Literal::Time qw( now );
use RDF::Base::Widget qw( locnl );


sub handler
{
    my( $req ) = @_;

    my $q = $req->q;
    my $R = RDF::Base->Resource;

    my $username = $q->param('username');
    my $email_address = $q->param('email');
    my $members;

    my( $args, $arclim, $res ) = parse_propargs('relative');

    if( $username )
    {
        $members = $R->find({
                             is => $C_login_account,
                             name_short => $username,
                            });
    }
    elsif( $email_address )
    {
        $members = $R->find({
                             is => $C_login_account,
                             has_email => $email_address,
                            });
    }

    if( $members->has_email )
    {
        my $new_password = make_passwd(8,'hard');
        my $md5_salt = $Para::Frame::CFG->{'md5_salt'};
        my $password_encrypted = md5_hex($new_password, $md5_salt);

        $members->update({ has_password => $password_encrypted }, $args );
        $res->autocommit({ activate => 1 });

        my $email = Para::Frame::Email::Sending->new({ date => now() });
        $email->set({
                     from => $Para::Frame::CFG->{'email'},
                     to   => $members->has_email,
                     subject => locnl('New password on AD'),
                     body => locnl('Your password has been reset.  It is now "[_1]" (without the "").',
                                 $new_password),
                    });
        $email->send_by_proxy() or return locnl("E-mail NOT sent");

        return locnl('E-mail sent');
    }
    else
    {
	if( $members->size )
	{
	    debug "Found members: ".$members->sysdesig;
	    throw 'validation', locnl('Account has no e-mail address set');
	}
	else
	{
	    throw 'validation', locnl('No accounts found');
	}
    }
}

1;

#-*-cperl-*-
package GOV::Action::member_change;

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
use Para::Frame::Utils qw( throw passwd_crypt debug datadump );
use Para::Frame::Email::Sending;

use RDF::Base::Utils qw( string parse_propargs );
use RDF::Base::Constants qw( $C_login_account $C_proposition_area $C_delegate );
use RDF::Base::Literal::Time qw( now );
use RDF::Base::Widget qw( locnl );


sub handler
{
    my( $req ) = @_;

    my $q = $req->q;
    my $u = $req->user;
    my $R = RDF::Base->Resource;


    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $id = $q->param('id')
      or throw('incomplete', locnl('Missing ID.'));

    my $m = $R->get($id);
    unless( $m->is($C_login_account) )
    {
	throw('validation', locnl('[_1] is not a login account', $id));
    }

    unless( $u->has_root_access )
    {
	unless( $u->equals($m) )
	{
	    throw('denied', locnl('You can only change your own settings'));
	}
    }


    # Name
    my $name =  $q->param('name');
    if( $name
        and $name ne $m->name ) {
        $m->update({ name => $name }, $args);
    }

    # Name short
    my $handle =  $q->param('name_short');
    if( $handle
        and $handle ne $m->name_short )
    {
        $m->update({ name_short => $handle }, $args);
	$req->cookies->add({'username' => $handle});
    }

    # E-mail
    my $email =  $q->param('email');
    if( $email
        and $email ne $m->has_email ) {
        $m->update({ has_email => $email }, $args);
    }

    # Anonymous
    my $anonymous = $q->param('anonymous');
    if( defined $anonymous ) {
        if( $anonymous and not $m->is_anonymous ) {
            $m->update({ is_anonymous => 1 }, $args);
        }
        elsif( not $anonymous and $m->is_anonymous ) {
            $m->arc( 'is_anonymous' )->remove( $args );
        }
    }

    # Password
    my $passwd = $q->param('passwd');
    my $passwd2 = $q->param('passwd2');

    throw('incomplete', locnl('Passwords do not match.'))
      if( $passwd and $passwd ne $passwd2 );

    if( $passwd ) {
        # Encrypt password with salt
        my $md5_salt = $Para::Frame::CFG->{'md5_salt'};
        my $md5_passwd = md5_hex($passwd, $md5_salt);

        $m->update({ has_password => $md5_passwd }, $args);

	if( $m->equals($u) )
	{
	    my $password_encrypted = passwd_crypt( $md5_passwd );
	    $req->cookies->add({
				'password' => $password_encrypted,
			       },
			       {
				-expires => '+10y',
			       });
	    $m->change_current_user( $m );
	    $req->run_hook('user_login', $m);
	}
    }

    ### Delegacy settings ###
    if( $q->param('check_is_delegate') ) {
        # We are on delegacy.tt page
        if( $q->param('is_delegate') ) {
            $m->add({ is => $C_delegate }, $args);
        }
        else {
            $m->arc( 'is', $C_delegate )->remove( $args );
        }

        $m->update({ has_short_delegate_description => $q->param('has_short_delegate_description') }, $args);
        $m->update({ has_delegate_description => $q->param('has_delegate_description') }, $args);
    }


    ### Notification settings ###
    if( $q->param('check_notifications') ) {
        check_notification( $m, $q, $args, 'new_proposition' );
        check_notification( $m, $q, $args, 'unvoted_proposition_resolution' );
        check_notification( $m, $q, $args, 'resolved_proposition' );
    }


    $res->autocommit({ activate => 1 });

    return locnl('Account updated');
}


sub check_notification
{
    my( $m, $q, $args, $notification ) = @_;

    if( $q->param($notification) ) {
        $m->add({ wants_notification_on => $notification }, $args);
    }
    elsif( $m->wants_notification_on( $notification )) {
        RDF::Base::Arc->find({ subj => $m, pred => 'wants_notification_on', value => $notification })->remove($args);
        #$m->arc( 'wants_notification_on', $notification )->remove( $args );
    }
}

1;

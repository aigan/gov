#-*-cperl-*-
package GOV::Action::member_register;

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

use RDF::Base::Utils qw( string parse_propargs );
use RDF::Base::Constants qw( $C_login_account $C_proposition_area );
use RDF::Base::Widget qw( locnl );


sub handler
{
    my( $req ) = @_;

    return "" if $GOV::CFG->{'cas_url'};


    my $q = $req->q;
    my $R = RDF::Base->Resource;
    my $u = $req->user;

    my $out = '';

    my $admin_id = $q->param('area_administrator');
    throw('validation', 'Invalid administration request.')
      if( $admin_id and $admin_id ne $u->id );

    my $passwd;

    if( $admin_id ) {
        $passwd = make_passwd(8,'hard');
    }
    else {
        my $captcha = $req->site->captcha;
        throw('validation', locnl('Invalid control string: [_1]', $captcha->{error}))
          if( not $captcha->is_valid );

        $passwd = $q->param('passwd')
          or throw('incomplete', "Saknar lösenord");
        my $passwd2 = $q->param('passwd2')
          or throw('incomplete', "Saknar lösenordsbekräftelse");
        throw('incomplete', locnl('Passwords do not match.'))
          if( $passwd ne $passwd2 );
    }

    my $name =  $q->param('name')
      or throw('incomplete', locnl('Missing name.'));
    my $username = $q->param('username')
      or throw('incomplete', locnl('Missing username.'));
    my $email = $q->param('email') || '';

    throw('validation', "E-postadressen används redan av annan användare.")
      if( $R->find({ is => $C_login_account, has_email => $email }) );

    throw('validation', "Användarnamnet $username är upptaget.")
      if( $R->find({ is => $C_login_account, name_short => $username }) );


    my( $args, $arclim, $res ) = parse_propargs('relative');

    # Encrypt password with salt
    my $md5_salt = $Para::Frame::CFG->{'md5_salt'};
    my $md5_passwd = md5_hex($passwd, $md5_salt);

    # Create user
    my $user = $R->create({
			   is => $C_login_account,
			   name => $name,
			   name_short => $username,
			   has_password => $md5_passwd,
			   has_email => $email,
			  }, $args);

    $res->autocommit({ activate => 1 });

    if( $admin_id ) {
        $out .= locnl('User account created:')               . "\n";
        $out .= locnl('Login:')    . ' ' . $user->name_short . "\n";
        $out .= locnl('Password:') . ' ' . $passwd           . "\n";

        # Add admin comment
        if( my $admin_comment = $q->param('admin_comment') ) {
            $user->add({ admin_comment => $admin_comment }, $args);
        }

        if( my $area_id = $q->param('area') ) {
            my $area = $R->get($area_id);
            throw('validation', locnl('Incorrect area id.'))
              unless( $area->is($C_proposition_area) );
            $user->add({ has_voting_jurisdiction => $area }, $args);
        }

        $res->autocommit({ activate => 1 });

        $q->delete('username');
        $q->delete('passwd');

    }
    else {
        $out .= locnl('User account "[_1]" registered.', $user->name_short);

        # Add jurisdiction arcs
        foreach my $field ($q->param) {
            if( $field =~ /^jurisdiction_(\d+)$/ ) {
                my $jurisdiction = $R->get($1);

                if( $jurisdiction and
                    $jurisdiction->is($C_proposition_area) ) {
                    $user->apply_for_jurisdiction( $jurisdiction );
                }
            }
        }

        # Log in user
        my $password_encrypted = passwd_crypt( $md5_passwd );
        $user->change_current_user( $user );
        $req->cookies->add({
                            'username' => $username,
                            'password' => $password_encrypted,
                           },{
                              -expires => '+10y',
                             });
        $q->delete('username');
        $q->delete('passwd');
        $req->run_hook('user_login', $user);
    }

    return $out;
}

1;


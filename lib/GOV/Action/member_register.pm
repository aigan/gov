#-*-cperl-*-
package GOV::Action::member_register;

use strict;

use Digest::MD5  qw(md5_hex);

use Para::Frame::Reload;
use Para::Frame::Utils qw( throw passwd_crypt debug datadump );
use Para::Frame::L10N qw( loc );

use Rit::Base::Utils qw( string parse_propargs );
use Rit::Base::Constants qw( $C_login_account $C_proposition_area );


sub handler
{
    my( $req ) = @_;

    my $q = $req->q;
    my $R = Rit::Base->Resource;
    my $u = $req->user;

    my $out = '';

    my $admin_id = $q->param('area_administrator');
    throw('validation', 'Invalid administration request.')
      if( $admin_id and $admin_id ne $u->id );

    my $passwd;

    if( $admin_id ) {
        $passwd = generate_password(8);
    }
    else {
        my $captcha = $req->site->captcha;
        throw('validation', loc('Invalid control string: [_1]', $captcha->{error}))
          if( not $captcha->is_valid );

        $passwd = $q->param('passwd')
          or throw('incomplete', "Saknar lösenord");
        my $passwd2 = $q->param('passwd2')
          or throw('incomplete', "Saknar lösenordsbekräftelse");
        throw('incomplete', loc('Passwords do not match.'))
          if( $passwd ne $passwd2 );
    }

    my $name =  $q->param('name')
      or throw('incomplete', loc('Missing name.'));
    my $username = $q->param('username')
      or throw('incomplete', loc('Missing username.'));
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
        $out .= loc('User account created:')               . "\n";
        $out .= loc('Login:')    . ' ' . $user->name_short . "\n";
        $out .= loc('Password:') . ' ' . $passwd           . "\n";

        # Add admin comment
        if( my $admin_comment = $q->param('admin_comment') ) {
            $user->add({ admin_comment => $admin_comment }, $args);
        }

        if( my $area_id = $q->param('area') ) {
            my $area = $R->get($area_id);
            throw('validation', loc('Incorrect area id.'))
              unless( $area->is($C_proposition_area) );
            $user->add({ has_voting_jurisdiction => $area }, $args);
        }

        $res->autocommit({ activate => 1 });

        $q->delete('username');
        $q->delete('passwd');

    }
    else {
        $out .= loc('User account "[_1]" registered.', $user->name_short);

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


sub generate_password
{
    my $length = shift;
    my $possible = 'abcdefghijkmnpqrstuvwxyz23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    my $password = '';
    while (length($password) < $length) {
        $password .= substr($possible, (int(rand(length($possible)))), 1);
    }
    return $password
}

1;


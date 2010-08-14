#-*-cperl-*-
package ActiveDemocracy::Action::member_register;

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

    my $captcha = $req->site->captcha;
    throw('validation', loc('Invalid control string: [_1]', $captcha->{error}))
      if( not $captcha->is_valid );

    my $name =  $q->param('name')
      or throw('incomplete', loc('Missing name.'));
    my $username = $q->param('username')
      or throw('incomplete', loc('Missing username.'));
    my $passwd = $q->param('passwd')
      or throw('incomplete', "Saknar lösenord");
    my $passwd2 = $q->param('passwd2')
      or throw('incomplete', "Saknar lösenordsbekräftelse");
    throw('incomplete', loc('Passwords do not match.'))
      if( $passwd ne $passwd2 );
    my $email = $q->param('email') || '';

    if( my $user = $R->find({ is => $C_login_account,
			      has_email => $email }) )
    {
	throw('validation', "E-postadressen används redan av annan användare.");
    }
    if( my $user = $R->find({ is => $C_login_account,
			      name_short => $username }) )
    {
	throw('validation', "Användarnamnet $username är upptaget.");
    }

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

    # Add jurisdiction arcs
    # In a running system, this would be requests (submitted arcs, not activated)
    foreach my $field ($q->param)
    {
	if( $field =~ /^jurisdiction_(\d+)$/ )
	{
	    my $jurisdiction = $R->get($1);

	    if( $jurisdiction and
		$jurisdiction->is($C_proposition_area) )
	    {
		$user->apply_for_jurisdiction( $jurisdiction );
	    }
	}
    }


    # Log in user

    my $password_encrypted = passwd_crypt( $md5_passwd );

    $user_class->change_current_user( $user );

    $req->cookies->add({
			'username' => $username,
			'password' => $password_encrypted,
		       },{
			  -expires => '+10y',
			 });
    $q->delete('username');
    $q->delete('password');

    $req->run_hook('user_login', $user);

    return "Användaren tillagd.";
}

1;


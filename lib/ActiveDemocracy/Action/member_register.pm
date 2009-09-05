#-*-cperl-*-
package ActiveDemocracy::Action::member_register;

use strict;

use Digest::MD5  qw(md5_hex);

use Para::Frame::Reload;
use Para::Frame::Utils qw( throw passwd_crypt debug datadump );

use Rit::Base::Utils qw( string parse_propargs );
use Rit::Base::Constants qw( $C_login_account $C_proposition_area );


sub handler
{
    my( $req ) = @_;

    my $q = $req->q;
    my $R = Rit::Base->Resource;

    my $name =  $q->param('name')
      or throw('incomplete', "Saknar namn");
    my $username = $q->param('username')
      or throw('incomplete', "Saknar användarnamn");
    my $passwd = $q->param('passwd')
      or throw('incomplete', "Saknar lösenord");
    my $passwd2 = $q->param('passwd2')
      or throw('incomplete', "Saknar lösenordsbekräftelse");
    throw('incomplete', "Lösenordet stämmer inte överens med bekräftelsen")
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
    $passwd = md5_hex($passwd, $md5_salt);

    # Create user
    my $user = $R->create({
			   is => $C_login_account,
			   name => $name,
			   name_short => $username,
			   has_password => $passwd,
			   has_email => $email,
			  }, $args);

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
		# For now, a user can set his own jurisdiction!
		$user->add({ has_voting_jurisdiction => $jurisdiction }, $args);
	    }
	}
    }


    $res->autocommit({ activate => 1 });

    my $user_class = $Para::Frame::CFG->{'user_class'};
    my $u = $user_class->get( $username );
    $u or throw('validation', "Användaren $username existerar inte");
    my $password_encrypted = passwd_crypt( $passwd );

    $user_class->change_current_user( $u );

    $req->cookies->add({
			'username' => $username,
			'password' => $password_encrypted,
		       },{
			  -expires => '+10y',
			 });
    $q->delete('username');
    $q->delete('password');

    $req->run_hook('user_login', $u);

    return "Användaren tillagd.";
}

1;


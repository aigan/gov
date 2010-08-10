#-*-cperl-*-
package ActiveDemocracy::Action::member_change;

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
    my $u = $req->user;
    my $R = Rit::Base->Resource;


    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $id = $q->param('id')
      or throw('incomplete', loc('Missing ID.'));

    throw('denied', loc('You can only change your own settings.'))
      unless( $id = $u->id );

    my $name =  $q->param('name');
    if( $name
        and $name ne $u->name ) {
        $u->update({ name => $name }, $args);
    }

    my $email =  $q->param('email');
    if( $email
        and $email ne $u->has_email ) {
        $u->update({ has_email => $email }, $args);
    }

    my $anonymous = $q->param('anonymous');
    if( $anonymous and not $u->is_anonymous ) {
        $u->update({ is_anonymous => 1 }, $args);
    }
    elsif( not $anonymous and $u->is_anonymous ) {
        $u->arc( 'is_anonymous' )->remove( $args );
    }


    my $passwd = $q->param('passwd');
    my $passwd2 = $q->param('passwd2');

    throw('incomplete', loc('Passwords do not match.'))
      if( $passwd and $passwd ne $passwd2 );

    if( $passwd ) {
        # Encrypt password with salt
        my $md5_salt = $Para::Frame::CFG->{'md5_salt'};
        $passwd = md5_hex($passwd, $md5_salt);

        $u->update({ has_password => $passwd }, $args);
    }

    $res->autocommit({ activate => 1 });

    return loc('Account updated.');
}

1;

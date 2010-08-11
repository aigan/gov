#-*-cperl-*-
package ActiveDemocracy::Action::member_lost_password;


use strict;

use Digest::MD5  qw(md5_hex);

use Para::Frame::Reload;
use Para::Frame::Utils qw( throw passwd_crypt debug datadump );
use Para::Frame::L10N qw( loc );

use Rit::Base::Utils qw( string parse_propargs );
use Rit::Base::Constants qw( $C_login_account $C_proposition_area );
use Rit::Base::Literal::Time qw( now );


sub handler
{
    my( $req ) = @_;

    my $q = $req->q;
    my $R = Rit::Base->Resource;

    my $username = $q->param('username');
    my $email_address = $q->param('email');
    my $members;

    my( $args, $arclim, $res ) = parse_propargs('relative');

    if( $username ) {
        $members = $R->find({
                             is => $C_login_account,
                             name_short => $username,
                            });
    }
    elsif( $email_address ) {
        $members = $R->find({
                             is => $C_login_account,
                             has_email => $email_address,
                            });
    }

    if( $members->has_email ) {
        my $new_password = generate_password(8);
        my $md5_salt = $Para::Frame::CFG->{'md5_salt'};
        my $password_encrypted = md5_hex($new_password, $md5_salt);

        $members->update({ has_password => $password_encrypted }, $args );
        $res->autocommit({ submit => 1 });

        my $email = Para::Frame::Email::Sending->new({ date => now() });
        $email->set({
                     from => 'fredrik@liljegren.org',
                     to   => $members->has_email,
                     subject => loc('New password on AD.'),
                     body => loc('Your password has been reset.  It is now "[_1]" (without the "").',
                                 $new_password),
                    });
        $email->send_by_proxy();

        return loc('E-mail sent.');
    }
    else {
        return loc('Account has no e-mail address set.');
    }
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

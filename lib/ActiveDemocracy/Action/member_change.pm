#-*-cperl-*-
package ActiveDemocracy::Action::member_change;

use strict;

use Digest::MD5  qw(md5_hex);

use Para::Frame::Reload;
use Para::Frame::Utils qw( throw passwd_crypt debug datadump );
use Para::Frame::L10N qw( loc );
use Para::Frame::Email::Sending;

use Rit::Base::Utils qw( string parse_propargs );
use Rit::Base::Constants qw( $C_login_account $C_proposition_area $C_delegate );
use Rit::Base::Literal::Time qw( now );


sub handler
{
    my( $req ) = @_;

    my $q = $req->q;
    my $u = $req->user;
    my $R = Rit::Base->Resource;


    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $id = $q->param('id')
      or throw('incomplete', loc('Missing ID.'));

    debug $q->param('is_delegate');

    throw('denied', loc('You can only change your own settings.'))
      unless( $id = $u->id );

    # Name
    my $name =  $q->param('name');
    if( $name
        and $name ne $u->name ) {
        $u->update({ name => $name }, $args);
    }

    # E-mail
    my $email =  $q->param('email');
    if( $email
        and $email ne $u->has_email ) {
        $u->update({ has_email => $email }, $args);
    }

    # Anonymous
    my $anonymous = $q->param('anonymous');
    if( defined $anonymous ) {
        if( $anonymous and not $u->is_anonymous ) {
            $u->update({ is_anonymous => 1 }, $args);
        }
        elsif( not $anonymous and $u->is_anonymous ) {
            $u->arc( 'is_anonymous' )->remove( $args );
        }
    }

    # Password
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

    ### Delegacy settings ###
    if( $q->param('check_is_delegate') ) {
        # We are on delegacy.tt page
        if( $q->param('is_delegate') ) {
            $u->add({ is => $C_delegate }, $args);
        }
        else {
            $u->arc( 'is', $C_delegate )->remove( $args );
        }

        $u->update({ has_short_delegate_description => $q->param('has_short_delegate_description') }, $args);
        $u->update({ has_delegate_description => $q->param('has_delegate_description') }, $args);
    }


    $res->autocommit({ activate => 1 });

    #$email = Para::Frame::Email::Sending->new({
    #                                           u => $u,
    #                                           date => now,
    #                                          });
    #$email->set({
    #             body => loc('Your account is now.....'),
    #             from => 'ad@ad.alternativ.se',
    #             subject => loc('Your account on AD has been updated.'),
    #             to => $u->has_email,
    #            });
    #$email->send();



    return loc('Account updated.');
}

1;

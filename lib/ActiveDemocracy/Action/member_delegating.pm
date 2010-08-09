#-*-cperl-*-
package ActiveDemocracy::Action::member_delegating;

use strict;

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
    my $A = Rit::Base->Arc;


    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $id = $q->param('id')
      or throw('incomplete', loc('Missing ID.'));

    throw('denied', loc('You can only change your own settings.'))
      unless( $id = $u->id );

    my @delegates;
    foreach my $delegate_id ($q->param('delegates_votes_to')) {
      push @delegates, $delegate_id;
      $u->add({ delegates_votes_to => $delegate_id }, $args);
    }

    debug "Delegates should be @delegates";
    debug "Old delegates was " . join(',', $q->param('delegated_votes_to'));

    # Clean up old delegates
    foreach my $delegate_id ($q->param('delegated_votes_to')) {
      debug "Checking old delegate " . $delegate_id;
      my $arc = $A->find({
			  subj => $u,
			  pred => 'delegates_votes_to',
			  obj  => $delegate_id,
			 }, $args);
      $arc->remove($args)
	unless grep( /^$delegate_id$/, @delegates ) >= 1;
      debug "Keeping."
	if grep( /^$delegate_id$/, @delegates ) >= 1;
      debug grep( /^$delegate_id$/, @delegates );
    }

    $res->autocommit({ activate => 1 });

    return loc('Account updated.');
}

1;

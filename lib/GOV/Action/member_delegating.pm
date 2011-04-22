#-*-cperl-*-
package GOV::Action::member_delegating;

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

use Para::Frame::Reload;
use Para::Frame::Utils qw( throw passwd_crypt debug datadump );

use Rit::Base::Utils qw( string parse_propargs );
use Rit::Base::Constants qw( $C_login_account $C_proposition_area $C_delegate );
use Rit::Base::Widget qw( locnl );


sub handler
{
    my( $req ) = @_;

    my $q = $req->q;
    my $u = $req->user;
    my $R = Rit::Base->Resource;
    my $A = Rit::Base->Arc;


    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $id = $q->param('id')
      or throw('incomplete', locnl('Missing ID.'));

    throw('denied', locnl('You can only change your own settings.'))
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

    foreach my $param ($q->param) {
        if( $param =~ /^weight_(\d+)$/ ) {
            my $delegate_id = $1;
            my $delegate_arc = $R->find({
                                         subj => $u,
                                         pred => 'delegates_votes_to',
                                         obj  => $delegate_id,
                                        }, $args);
            if ($delegate_arc) {
                $delegate_arc->update({ weight => $q->param($param) }, $args);
            }
            else {
                debug "Didn't find delegate $delegate_id";
            }
        }
    }

    $res->autocommit({ activate => 1 });

    return locnl('Account updated.');
}

1;

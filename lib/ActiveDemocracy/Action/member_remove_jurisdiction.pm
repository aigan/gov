# -*-cperl-*-
package ActiveDemocracy::Action::member_remove_jurisdiction;

#=============================================================================
#
# AUTHOR
#   Fredrik Liljegren   <fredrik@liljegren.org>
#
# COPYRIGHT
#   Copyright (C) 2010 Fredrik Liljegren
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#=============================================================================

use 5.010;
use strict;
use warnings;

use Para::Frame::L10N qw( loc );
use Para::Frame::Utils qw( throw debug );

use Rit::Base::Literal::Time qw( now );
use Rit::Base::Utils qw( parse_propargs );
use Rit::Base::Constants qw( $C_proposition_area );

=head1 DESCRIPTION

Run from member/index.tt to give a member jurisdiction in a proposition area

=cut

sub handler {
    my( $req ) = @_;

    my( $args, $arclim, $res ) = parse_propargs('auto');

    my $q = $req->q;
    my $u = $req->user;
    my $R = Rit::Base->Resource;

    # Area check
    my $area_id = $q->param('area')
      or throw('incomplete', loc('Area missing'));
    my $area = $R->get($area_id);
    throw('incomplete', loc('Incorrect area id'))
      unless( $area and $area->is($C_proposition_area) );

    # Member check
    my $member_id = $q->param('member')
      or throw('incomplete', loc('Member missing'));
    my $member = $R->get($member_id);
    throw('incomplete', loc('Member missing'))
      unless( $member and $member->is('login_account') );

    # Permission check
    throw('denied', loc('You don\'t have permission to give a member jurisdiction in "[_1]".', $area->name))
      unless( $u->administrates_area($area) or $u->level >= 20 );

    my $out = '';

    # For e-mail
    my $host = $Para::Frame::REQ->site->host;
    my $home = $Para::Frame::REQ->site->home_url_path;
    my $subject;
    my $body;

    $member->arc('has_voting_jurisdiction', $area)->remove($args);
    $res->autocommit({ activate => 1 });

    # Prepare e-mail
    $subject = loc('Your voting jurisdiction in "[_1]" has been removed.', $area->desig);
    $body    = loc('Your voting jurisdiction in "[_1]" has been removed by [_2].',
                   $area->desig, $u->desig);
    $body   .= ' ' . loc('If that is in fault, you will have to contact the area administrators.');

    $out .= loc('Voting jurisdiction for member "[_1]" in area "[_2]" has now been removed.',
                $member->desig, $area->name);

    # Inform member
    if( $member->has_email ) {
        my $email = Para::Frame::Email::Sending->new({ date => now });
        $email->set({
                     body    => $body,
                     from    => $u->has_email->plain || 'fredrik@liljegren.org',
                     subject => $subject,
                     to      => $member->list('has_email')->get_first_nos(),
                    });
        $email->send_by_proxy();
    }

    return $out;
}


1;

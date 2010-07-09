# -*-cperl-*-
package ActiveDemocracy::Action::give_jurisdiction;

#=============================================================================
#
# AUTHOR
#   Fredrik Liljegren   <fredrik@liljegren.org>
#
# COPYRIGHT
#   Copyright (C) 2009 Fredrik Liljegren
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

    my $has_arc = $q->param('arc');

    if( $has_arc ) {
        my $A   = Rit::Base->Arc;
        my $arc = $A->get($has_arc);

        throw('validation', loc('Data inconsistency'))
          unless( $arc
                  and $arc->pred->label eq 'has_voting_jurisdiction'
                  and $arc->subj->id == $member_id
                  and $arc->obj->id == $area_id );

        if( $q->param('deny') ) {
            $arc->remove( $args );
            return loc('Member "[_1]" now has been denied voting jurisdiction in area "[_2]".', $member->name, $area->name);
        }

        $arc->activate( $args );

        ## TODO: Inform the applicant
    }
    else {
        $member->add({ has_voting_jurisdiction => $area }, $args);
        $res->autocommit({ activate => 1 });
    }


    return loc('Member "[_1]" now has voting jurisdiction in area "[_2]".', $member->name, $area->name);
}


1;

# -*-cperl-*-
package GOV::Proposition;

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

=head1 NAME

GOV::Proposition

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use Carp qw( confess cluck croak );
use HTML::FormatText;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );
use Para::Frame::Widget qw( jump );
use Para::Frame::L10N qw( loc );
use Para::Frame::Email::Sending;
use Para::Frame::SVG_Chart qw( curve_chart_svg );

#use RDF::Base::Constants qw( $C_proposition_area_sweden );
use RDF::Base::Resource;
use RDF::Base::Utils qw( parse_propargs is_undef );
use RDF::Base::Literal::Time qw( now );
use RDF::Base::Constants qw( $C_login_account $C_delegate $C_resolution_state_completed $C_resolution_state_aborted  $C_resolution_method_continous );
use RDF::Base::Widget qw( locnl aloc );

use GOV::Voted;

##############################################################################

# Overloaded...
#sub wu_vote
#{
#    throw('incomplete', loc('Internal error: Proposition is without type.'));
#}


##############################################################################

sub wp_jump
{
    my( $prop ) = @_;

    my $home = $Para::Frame::REQ->site->home_url_path;


    return jump($prop->name->loc, $home ."/proposition/display.tt",
                {
                 id => $prop->id,
                });
}

##############################################################################

sub area
{
    my( $prop ) = @_;

    return $prop->subsides_in->get_first_nos;
#      || $C_proposition_area_sweden;
}


##############################################################################

# Overloaded...
#sub register_vote
#{
#    throw('incomplete', loc('Internal error: Proposition is without type.'));
#}


##############################################################################

=head2 random_public_vote

Returns: A public vote placed on this proposition

Right now, all votes are public...

=cut

sub random_public_vote
{
    my( $prop ) = @_;

    my $R = RDF::Base->Resource;
    my $public_votes = $R->find({
                                 rev_has_vote => $prop,
                                });

    return $public_votes->randomized->get_first_nos();
}


##############################################################################

=head2 example_vote_html

Returns: An example vote text, e.g.: Fredrik has voted 'yay' on this.

=cut

sub example_vote_html
{
    my( $prop ) = @_;

    my $vote = $prop->random_public_vote; # TODO: or raise internal error
    my $user = $vote->rev_places_vote; # TODO: or raise internal error

    return '<em>'. $user->desig .'</em> would vote "'. $vote->desig
      .'" on this proposition.';
}


##############################################################################

=head2 get_all_votes

Returns: Sum of all votes.

=cut

sub get_all_votes
{
    my( $prop, $wants_delegates, $args_in ) = @_;

    my( $args ) = parse_propargs($args_in);
    my $look_date = $args->{arc_active_on_date} //'';
    my $key = "$look_date" || 'today';

    if ( defined $prop->{'gov'}{'votes'}{$key} )
    {
        if ( $wants_delegates )
        {
            return $prop->{'gov'}{'votes_and_delegates'}{$key};
        }

        $prop->{'gov'}{'votes'}{$key}->reset;
        return $prop->{'gov'}{'votes'}{$key};
    }


    my @complete_list;

    debug "calculating all_votes of ".$prop->sysdesig;

    my $R     = RDF::Base->Resource;

    my $mem_args = $args;
    if ( my $res_date = $prop->proposition_resolved_date )
    {
#	debug "  resolved on ".$res_date->desig;
        if ( $look_date )
        {
            $look_date = $res_date if $res_date < $look_date;
            $mem_args = {%$args, arc_active_on_date => $look_date};
        }
        else
        {
            $mem_args = {%$args, arc_active_on_date => $res_date};
        }
    }


    my $area    = $prop->area;
    my $members_unsorted = $area->
      revlist( 'has_voting_jurisdiction',
               undef, $mem_args )->uniq->as_listobj;

    my @membersl;
    $members_unsorted->reset;
    my $propid = $prop->id;
    my $covslot = 'gov_cover_'.$propid;
    while ( my $muns = $members_unsorted->get_next_nos )
    {
        $muns->{$covslot} = $muns->cover_id($propid);
        push @membersl, $muns;
    }
    my $members = RDF::Base::List->new([sort {$a->{$covslot} cmp $b->{$covslot}} @membersl]);

    my @votes;
    # To sum delegated votes, we loop through all with jurisdiction in area
    $members->reset;
    while ( my $member = $members->get_next_nos )
    {
        # May not be a user anymore...
        my( $voted ) = GOV::User::find_vote($member, $prop, $args );

        push @votes, $voted->vote if( $voted->vote );
#	push @complete_list, $voted if( $voted->vote );
        push @complete_list, $voted;
    }

    $prop->{'gov'}{'votes_and_delegates'}{$key} = new RDF::Base::List( \@complete_list );
    $prop->{'gov'}{'votes'}{$key} = new RDF::Base::List( \@votes );

    return $prop->{'gov'}{'votes_and_delegates'}{$key} if $wants_delegates;
    return $prop->{'gov'}{'votes'}{$key};
}


##############################################################################

sub delegate_votes
{
    my( $prop ) = @_;

    if ( $prop->{'gov'}{'delegate_votes'} )
    {
        return $prop->{'gov'}{'delegate_votes'};
    }

    my $R = RDF::Base->Resource;
    my @delegate_votes;

    foreach my $delegate ( $C_delegate->revlist('is')->as_array )
    {
        my $vote = $R->find({ rev_places_vote => $delegate,
                              rev_has_vote => $prop,
                            })->get_first_nos;

        if ( $vote )
        {
            push @delegate_votes,
            {
             vote => $vote,
             delegate => $delegate,
            };
        }
    }

    return $prop->{'gov'}{'delegate_votes'} =
      RDF::Base::List->new(\@delegate_votes);
}


##############################################################################

sub get_vote_count
{
    confess "deprecated";
    return $_[0]->sum_all_votes;
}

##############################################################################

sub is_open
{
    my( $prop ) = @_;

    return $prop->is_resolved ? is_undef : $prop;
}


##############################################################################

sub is_resolved
{
    my( $prop ) = @_;

    return $prop->has_pred('has_resolution_state') ? $prop : is_undef;
}


##############################################################################

sub is_completed
{
    my( $prop ) = @_;
    return $prop->first_prop('has_resolution_state' => 
                             $C_resolution_state_completed )
      ? $prop : is_undef;
}


##############################################################################

sub is_aborted
{
    my( $prop ) = @_;
    return $prop->first_prop('has_resolution_state' => 
                             $C_resolution_state_aborted )
      ? $prop : is_undef;
}

##############################################################################

sub should_be_resolved
{
    my( $prop ) = @_;

    return 0
      if ( $prop->is_resolved );
    my $method = $prop->has_resolution_method
      or return 0;

    return $method->should_resolve( $prop );
}


##############################################################################

sub has_predicted_resolution_date
{
    my( $prop ) = @_;

    return defined $prop->predicted_resolution_date ? $prop : is_undef;
}

sub no_predicted_resolution_date
{
    my( $prop ) = @_;

    return defined $prop->predicted_resolution_date ? is_undef : $prop;
}

sub predicted_resolution_date
{
    my( $prop ) = @_;

    return is_undef if $prop->is_resolved;
    my $method = $prop->has_resolution_method
      or return is_undef;
    return $method->predicted_resolution_date( $prop );
}

sub resolution_date
{
    my( $prop ) = @_;

    return is_undef if $prop->is_resolved;
    my $method = $prop->has_resolution_method
      or return is_undef;
    return $method->resolution_date( $prop );
}

##############################################################################

=head2 resolve

Adds has_resolution_vote and prop_resolved_date to the proposition.

=cut

sub resolve
{
    my( $prop ) = @_;

    return undef
      if ( $prop->is_resolved );

    my( $args, $arclim, $res ) = parse_propargs('relative');

    my $vote = $prop->create_resolution_vote( $args );
    $prop->add({ has_resolution_vote => $vote }, $args);

    $prop->add({ proposition_resolved_date => now() }, $args);
    $prop->add({ has_resolution_state => $C_resolution_state_completed }, $args);

    $res->autocommit({ activate => 1 });


    # Todo: move this, generalize notify_members...
    if ( $Para::Frame::CFG->{'send_email'} )
    {
        my $members = $C_login_account->revlist('is');

        my $home_url = $Para::Frame::REQ->site->home->url;
        my $subject = locnl('Proposition "[_1]" is resolved: [_2].',
                            $prop->desig, $vote->desig);
        my $body = locnl('Proposition "[_1]" is resolved: [_2].',
                         $prop->desig, $vote->desig);
        $body .= ' ' .
          locnl('Go here to read it: ') . $home_url . 'proposition/display.tt?id=' . $prop->id;

        while ( my $member = $members->get_next_nos )
        {
            next unless $member->wants_notification_on( 'resolved_proposition' );

            my $email_address = $member->has_email or next;
            my $email = Para::Frame::Email::Sending->new({ date => now });

            $email->set({
                         body    => $body,
                         from    => $Para::Frame::CFG->{'email'},
                         subject => $subject,
                         to      => $email_address,
                        });
            $email->send_by_proxy();
        }
    }


    return;
}

##############################################################################

=head2 notify_members

=cut

sub notify_members
{
    my( $prop ) = @_;

    return unless $Para::Frame::CFG->{'send_email'};

    my $members = $C_login_account->revlist('is');

    my $home_url = $Para::Frame::REQ->site->home->url;
    my $subject = locnl('A new proposition has been created in [_1].', $prop->area->desig);
    my $body = locnl('A new proposition has been created in [_1].', $prop->area->desig);
    $body .= ' ' .
      locnl('Go here to read and vote: ') . $home_url . 'proposition/display.tt?id=' . $prop->id;

    while ( my $member = $members->get_next_nos )
    {
        next unless( $member->wants_notification_on( 'new_proposition' ));

        my $email_address = $member->has_email or next;
        my $email = Para::Frame::Email::Sending->new({ date => now });

        $email->set({
                     body    => $body,
                     from    => $Para::Frame::CFG->{'email'},
                     subject => $subject,
                     to      => $email_address,
                    });
        $email->send_by_proxy();
    }
}


##############################################################################

sub vote_chart_svg
{
    my( $prop ) = @_;
    $prop->has_resolution_method->vote_chart_svg($prop);
}


##############################################################################

sub on_arc_add
{
    my( $prop, $arc, $pred_name, $args ) = @_;
    $prop->clear_caches();
    $prop->list('has_vote')->clear_caches;
    $prop->reset_resolution_vote
      if $pred_name eq 'has_buffer_days';
}


##############################################################################

sub on_arc_del
{
    my( $prop, $arc, $pred_name, $args ) = @_;
    $prop->clear_caches(@_);
    $prop->list('has_vote')->clear_caches;
    $prop->reset_resolution_vote
      if $pred_name eq 'has_buffer_days';
}


##############################################################################

sub clear_caches
{
    delete  $_[0]->{'gov'};
}


##############################################################################

=head2 table_stats

=cut

sub table_stats
{
    my( $prop ) = @_;

    my $count = $prop->sum_all_votes;
    return '<tr><td>'.aloc('Blank').'</td><td>'.$count->{blank}.
      ' ('.$count->{blank_percent}.')</td></tr>';
}

##############################################################################

=head2 excerpt_input

=cut

sub excerpt_input
{
    my( $prop, $length ) = @_;

    $length ||= 150;
    my $html = $prop->prop('has_body')->loc or return;

    my $text = HTML::FormatText->format_string( $html,
                                                leftmargin => 0,
                                                rightmargin => $length+50);
    return substr $text, 0, $length+10;
}


##############################################################################

=head2 voting_history

=cut

sub voting_history
{
    my( $prop ) = @_;
}


##############################################################################

=head2 voting_dates

=cut

sub voting_dates
{
    my( $prop ) = @_;
}


##############################################################################

sub reset_resolution_vote
{
    my( $prop, $args_in ) = @_;

    my( $args, $arclim, $res ) = parse_propargs($args_in // 'solid');
    my $all = parse_propargs( {
                               arclim => ['active', 'old'],
                               unique_arcs_prio => undef,
                               force_recursive => 1,
                               res => $res,
                              });


    # Remove resolution vote for continous votes. Should be auto-created
    if ( $prop->has_resolution_method($C_resolution_method_continous) )
    {
        my $vote = $prop->first_prop('has_resolution_vote', undef, $args)->
          remove($all);
    }

    return $prop;
}

##############################################################################


1;

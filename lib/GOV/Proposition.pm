# -*-cperl-*-
package GOV::Proposition;

=head1 NAME

GOV::Proposition

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use Carp qw( confess );

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );
use Para::Frame::Widget qw( jump );
use Para::Frame::L10N qw( loc );
use Para::Frame::Email::Sending;
use Para::Frame::SVG_Chart qw( curve_chart_svg );

#use Rit::Base::Constants qw( $C_proposition_area_sweden );
use Rit::Base::Resource;
use Rit::Base::Utils qw( parse_propargs is_undef );
use Rit::Base::Literal::Time qw( now );
use Rit::Base::Constants qw( $C_login_account );

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

    my $R = Rit::Base->Resource;
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

Returns: Sum of yay- and nay-votes.

=cut

sub get_all_votes
{
    my( $prop, $wants_delegates, $args_in ) = @_;
    confess 'wants_delegates' if $wants_delegates;

    if( $prop->{'gov_all_votes'} )
    {
	$prop->{'gov_all_votes'}->reset;
	return $prop->{'gov_all_votes'};
    }

    my( $args ) = parse_propargs($args_in);

    my @complete_list;

    debug "calculating all_votes";

    my $R     = Rit::Base->Resource;

    my $mem_args = $args;
    if( my $res_date = $prop->proposition_resolved_date )
    {
	debug "  resolved on ".$res_date->desig;
	$mem_args = {%$args, arc_active_on_date => $res_date};
    }


    my $area    = $prop->area;
    my $members = $area->revlist( 'has_voting_jurisdiction',
				      undef, $mem_args )->uniq->as_listobj;
    $members->reset;
    my @votes;

    # To sum delegated votes, we loop through all with jurisdiction in area
    while( my $member = $members->get_next_nos )
    {
	# May not be a user anymore...
	my( $vote, $delegate ) = GOV::User::find_vote($member, $prop );

	push @votes, $vote
	  if( $vote );
	push @complete_list, { member => $member, vote => $vote, delegate => $delegate };
    }

    return $prop->{'gov_all_votes'} = new Rit::Base::List( \@votes );
}


##############################################################################

sub get_vote_count
{
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

    return $prop->count('has_resolution_vote') ? $prop : is_undef;
}


##############################################################################

sub should_be_resolved
{
    my( $prop ) = @_;

    return 0
      if( $prop->is_resolved );
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

##############################################################################

=head2 resolve

Adds has_resolution_vote and prop_resolved_date to the proposition.

=cut

sub resolve
{
    my( $prop ) = @_;

    return undef
      if( $prop->is_resolved );

    my( $args, $arclim, $res ) = parse_propargs('relative');

    my $vote = $prop->create_resolution_vote( $args );
    $prop->add({ has_resolution_vote => $vote }, $args);

    $prop->add({ proposition_resolved_date => now() }, $args);

    $res->autocommit({ activate => 1 });


    # Todo: move this, generalize notify_members...
    if( $Para::Frame::CFG->{'send_email'} )
    {
	my $members = $C_login_account->revlist('is');

	my $host = $Para::Frame::REQ->site->host;
	my $home = $Para::Frame::REQ->site->home_url_path;
	my $subject = loc('Proposition "[_1]" is resolved: [_2].',
			  $prop->desig, $vote->desig);
	my $body = loc('Proposition "[_1]" is resolved: [_2].',
		       $prop->desig, $vote->desig);
	$body .= ' ' .
	  loc('Go here to read it: ') . 'http://' . $host .
	    $home . '/proposition/display.tt?id=' . $prop->id;

	while( my $member = $members->get_next_nos )
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

    my $host = $Para::Frame::REQ->site->host;
    my $home = $Para::Frame::REQ->site->home_url_path;
    my $subject = loc('A new proposition has been created in [_1].', $prop->area->desig);
    my $body = loc('A new proposition has been created in [_1].', $prop->area->desig);
    $body .= ' ' .
      loc('Go here to read and vote: ') . 'http://' . $host . $home . '/proposition/display.tt?id=' . $prop->id;

    while( my $member = $members->get_next_nos ) {
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

=head2 vote_integral_chart_svg

=cut

sub vote_integral_chart_svg
{
    my( $prop ) = @_;

    my $vote_arcs = $prop->get_all_votes()->revarc_list('places_vote')->flatten->sorted({on=>'activated',cmp=>'<=>'});

#    debug( datadump( $vote_arcs, 2 ) );

    $vote_arcs->reset;

    my $resolution_weight = $prop->resolution_progressive_weight || 7;
    my $member_count = $prop->area->revlist('has_voting_jurisdiction')->size
      or return '';

    my @markers;
    my $current_level = 0;
    my $current_y = 0;
    my $last_time = 0;
    my $base_time;

    while( my $vote_arc = $vote_arcs->get_next_nos ) {
        my $vote = $vote_arc->obj;
        next unless( $vote->weight );

        my $time = $vote->revarc('places_vote')->activated->epoch;
        $base_time //= $time;

        my $rel_time = ($time - $base_time) / 24 / 60 / 60;

        # Speed, in votedays per day
        $current_y += ($rel_time - $last_time) * $current_level;

        push @markers, { x => $rel_time, y => $current_y };

        $current_level += $vote->weight;
        $last_time = $rel_time;

#        debug "$rel_time - $current_level";

    }
    my $now = now()->epoch;

    $base_time //= $now;

    my $rel_time = ($now - $base_time) / 24 / 60 / 60;
    $current_y += ($rel_time - $last_time) * $current_level;
#    debug "$rel_time - $current_level";
    push @markers, { x => $rel_time, y => $current_y };

#    debug( datadump( \@markers ) );

    my $resolution_goal = $resolution_weight * $member_count;

#    debug "Resolution goal: $resolution_goal";

    return Para::Frame::SVG_Chart->
      curve_chart_svg(
                      [
                       {
                        color => 'red',
                        markers => \@markers,
                       }
                      ],
                      min_y => -$resolution_goal * 1.2,
                      max_y => $resolution_goal * 1.2,
                      grid_h => $resolution_goal,
                      line_w => 0.1,
                     );

}

##############################################################################

sub on_arc_add
{
    shift->clear_caches(@_);
}

##############################################################################

sub on_arc_del
{
    shift->clear_caches(@_);
}

##############################################################################

sub clear_caches
{
    my( $prop ) = @_;
    foreach my $key ( keys %$prop )
    {
        next unless $key =~ /^gov_/;
	delete $prop->{$key};
    }
}

##############################################################################


1;

# -*-cperl-*-
package ActiveDemocracy::Proposition::Yay_Nay;

=head1 NAME

ActiveDemocracy::Proposition::Yay_Nay

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );
use Para::Frame::Widget qw( jump );
use Para::Frame::L10N qw( loc );

use Rit::Base::Constants qw( $C_vote);
use Rit::Base::Resource;
use Rit::Base::Utils qw( parse_propargs is_undef );
use Rit::Base::List;
use Rit::Base::Literal::Time qw( now timespan );

##############################################################################

sub wu_vote
{
    my( $proposition ) = @_;

    my $req = $Para::Frame::REQ;
    my $u = $req->user;
    my $area = $proposition->area;

    my $widget = '';

    # Any member can vote on a proposition.  Only those with
    # jurisdiction will be counted

    my $R = Rit::Base->Resource;

    # Check if there's an earlier vote on this
    my( $prev_vote, $delegate ) = $u->find_vote( $proposition );


    if( $prev_vote and $delegate eq $u ) {
        $widget .= loc('You have voted: [_1].', $prev_vote->desig);
        $widget .= '<br/>';
        $widget .= loc('You can change your vote:');
        $widget .= '<br/>';
    }
    elsif( $prev_vote ) {
        $widget .= loc('Delegate [_1] has voted: [_2].', $delegate->name,
                       loc($prev_vote->name));
        $widget .= '<br/>';
        $widget .= loc('You can make another vote:');
        $widget .= '<br/>';
    }

    $widget .= jump(loc('Yay'), '', {
                                     id => $proposition->id,
                                     run => 'place_vote',
                                     vote => 'yay',
                                    }). ' | ';
    $widget .= jump(loc('Nay'), '', {
                                     id => $proposition->id,
                                     run => 'place_vote',
                                     vote => 'nay',
                                    }). ' | ';
    $widget .= jump(loc('Blank'), '', {
                                       id => $proposition->id,
                                       run => 'place_vote',
                                       vote => 'blank',
                                      });

    return $widget;
}


##############################################################################

sub register_vote
{
    my( $proposition, $u, $vote_in ) = @_;
    my( $args, $arclim, $res ) = parse_propargs('relative');

    my $vote_parsed = 0;
    my $changed     = 0;
    my $R           = Rit::Base->Resource;

    # Parse the in-data
    $vote_in = lc $vote_in;
    $vote_parsed = 1
      if( $vote_in eq 'yay' or
	  $vote_in eq 'yes' or
	  $vote_in eq 1 );
    $vote_parsed = -1
      if( $vote_in eq 'nay' or
	  $vote_in eq 'no' or
	  $vote_in eq -1 );

    # Build the new vote
    my $vote = $R->create({
			   is     => $C_vote,
			   weight => $vote_parsed,
			   name   => $vote_in,        # relevant?
			   code   => $vote_parsed,
			  }, $args);

    # Check if there's an earlier vote on this
    my $prev_vote = $R->find({
			      rev_places_vote => $u,
			      rev_has_vote    => $proposition,
			     }, $args);
    if( $prev_vote ) {
	# Remove previous vote
	$prev_vote->remove($args);
	$changed = 1;
    }

    # Connect the user to the vote
    $u->add({ places_vote => $vote }, $args);

    # Connect the proposition to the vote
    $proposition->add({ has_vote => $vote }, $args);

    # Activate changes
    $res->autocommit({ activate => 1 });


    # Clear vote caches
    delete $ActiveDemocracy::Proposition::VOTE_COUNT{$proposition->id};
    delete $ActiveDemocracy::Proposition::ALL_VOTES{$proposition->id};
    delete $ActiveDemocracy::Proposition::PREDICTED_RESOLUTION_DATE{$proposition->id};
}


##############################################################################

=head2 sum_all_votes

Makes a hash summary of the votes.  This should mainly be called from
ActiveDemocracy::Proposition->get_vote_count, that caches the result.

=cut

sub sum_all_votes
{
    my( $proposition ) = @_;

    my %count = ( yay => 0, nay => 0, blank => 0, sum => 0 );
    my $votes = $proposition->get_all_votes;

    while( my $vote = $votes->get_next_nos ) {
        if( not $vote->weight ) {
            $count{'blank'}++;
        }
        elsif( $vote->weight == 1 ) {
            $count{'sum'} += $vote->weight;
            $count{'yay'}++;
        }
        elsif( $vote->weight == -1 ) {
            $count{'sum'} += $vote->weight;
            $count{'nay'}++;
        }
    }

    return \%count;
}


##############################################################################

sub get_vote_integral
{
    my( $proposition ) = @_;

    my $R          = Rit::Base->Resource;
    my $area       = $proposition->area;
    my $members    = $area->revlist( 'has_voting_jurisdiction' );

    return 0 if( $members->size == 0 );

    my $votes      = $proposition->get_all_votes;
    my $now        = now();
    my $total_days = 0;

    debug "Getting integral from " . $votes->size . " votes.";
    $votes->reset;

    # To sum delegated votes, we loop through all with jurisdiction in area
    while( my $vote = $votes->get_next_nos ) {
        next unless( $vote->weight );

        my $time = $vote->revarc('places_vote')->activated;
        my $duration_days = ($now->epoch - $time->epoch);
        $total_days += $duration_days * $vote->weight;
    }

    my $weighted_intergral = $total_days / $members->size;

    return $weighted_intergral;
}


##############################################################################

=head2 display_votes

=cut

sub display_votes
{
    my( $proposition ) = @_;

    my $count = $proposition->get_vote_count;

    return loc('Yay') .': '. $count->{'yay'} .'<br/>'
      . loc('Nay') .': '. $count->{'nay'} .'<br/>'
        . loc('Blank') . ': '. $count->{'blank'};
}


##############################################################################

=head2 predicted_resolution_vote

=cut

sub predicted_resolution_vote
{
    my( $proposition ) = @_;

    my $count = $proposition->get_vote_count;

    return loc('Yay')
      if( $count->{sum} > 0 );
    return loc('Nay')
      if( $count->{sum} < 0 );
    return loc('Draw');
}


##############################################################################

=head2 create_resolution_vote

=cut

sub create_resolution_vote
{
    my( $proposition, $args ) = @_;

    my $R     = Rit::Base->Resource;
    my $count = $proposition->get_vote_count;

    my $weight = 0;

    $weight = 1   if( $count->{sum} > 0 );
    $weight = -1  if( $count->{sum} < 0 );

    my $name = $count->{sum} > 0 ? 'Yay'
             : $count->{sum} < 0 ? 'Nay'
                                 : 'Blank';
    # Build the new vote
    my $vote = $R->create({
			   is     => $C_vote,
			   weight => $weight,
			   code   => $weight,
                           name   => $name,
			  }, $args);

    return $vote;
}


##############################################################################


1;

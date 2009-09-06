# -*-cperl-*-
package ActiveDemocracy::Proposition::Yay_Nay;

use Para::Frame::Reload;

=head1 NAME

Para::Resource

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


##############################################################################

sub wu_vote
{
    my( $proposition ) = @_;

    my $req = $Para::Frame::REQ;
    my $u = $req->user;
    my $area = $proposition->area;

    my $widget = '';

    if( $u->has_voting_jurisdiction( $area ) )
    {
	my $R = Rit::Base->Resource;

	# Check if there's an earlier vote on this
	my $prev_vote = $R->find({
				  rev_places_vote => $u,
				  rev_has_vote    => $proposition,
				 });
	if( $prev_vote ) {
	    $widget .= loc('You have voted: [_1]', loc($prev_vote->name));
	    $widget .= '<br/>';
	    $widget .= loc('You can change your vote') .':';
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
    }
    else
    {
	$widget .= "You don't have jurisdiction to vote on this proposition.";
    }

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

}

##############################################################################

=head2 get_all_votes

Returns: Sum of yay- and nay-votes.

=cut

sub get_all_votes
{
    my( $proposition ) = @_;

    my $R     = Rit::Base->Resource;
    my %count;

    $count{'yay'} = $R->find({
			      rev_has_vote => $proposition,
			      weight       => 1,
			     })->size;
    debug "Yay: ". $count{'yay'};
    $count{'nay'} = $R->find({
			      rev_has_vote => $proposition,
			      weight       => -1,
			     })->size;

    return \%count;
}


##############################################################################

=head2 display_votes

=cut

sub display_votes
{
    my( $proposition ) = @_;

    my $count = $proposition->get_all_votes;

    return loc('Yay') .': '. $count->{'yay'} .'<br/>'
      .loc('Nay') .': '. $count->{'nay'};
}


##############################################################################


1;

# -*-cperl-*-
package GOV::Proposition::Ranked;

=head1 NAME

GOV::Proposition::Ranked

=cut

use 5.010;
use strict;
use warnings;
use utf8;
use Carp qw( confess );

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );
use Para::Frame::Widget qw( jump hidden submit go );
use Para::Frame::L10N qw( loc );

use Rit::Base::Constants qw( $C_vote);
use Rit::Base::Resource;
use Rit::Base::Utils qw( parse_propargs is_undef );
use Rit::Base::List;
use Rit::Base::Literal::Time qw( now timespan );

##############################################################################

sub wu_vote
{
    my( $prop ) = @_;

    my $req = $Para::Frame::REQ;
    my $u = $req->user;
    my $area = $prop->area;
    my $q = $req->q;

    my $widget = '';

    # Any member can vote on a proposition.  Only those with
    # jurisdiction will be counted

    my $R = Rit::Base->Resource;

    # Check if there's an earlier vote on this
    my( $prev_vote, $delegate ) = $u->find_vote( $prop );
    # Previous alternatives arcs
    my( $palts ) = $prev_vote->arc_list('places_alternative')->sorted('weight','desc');

    if( $prev_vote and $delegate eq $u ) {
        $widget .= loc('You have voted: [_1].', $prev_vote->desig);
        $widget .= '<br/>';
        $widget .= loc('You can change your vote');
        $widget .= '<br/>';
    }
    elsif( $prev_vote ) {
        $widget .= loc('Delegate [_1] has voted: [_2].', $delegate->name,
                       $prev_vote->desig);
        $widget .= '<br/>';
        $widget .= loc('You can make another vote');
        $widget .= '<br/>';
    }


    $widget .= $q->h2('Alternatives');

    $widget .= q'
<script>
$(function()
{
  $( "#sort_blank, #sort_yay, #sort_nay" ).sortable({connectWith: ".gov_sortlist"}).disableSelection();
});
$("#f").submit( saveSortable );
function saveSortable()
{
  document.forms["f"].run.value="place_vote";
  $("#vote").val( $.merge($.merge( $("#sort_yay").sortable("toArray"),["|"]),$("#sort_nay").sortable("toArray") ) );
}
</script>
<style>
.gov_sortlist
{
  list-style-type: none;
  margin: 0 0 0.5em;
  padding: 1em 0;
  width: 60%;
}
.gov_sortlist li
{
  margin: 0 3px 3px 3px;
  padding: 0.4em;
  font-size: 1.4em;
}
</style>
  ';

    $widget .= hidden('vote');

    $widget .= '<p>
Sortera alternativ du vill <strong>främja</strong> upp till <b style="color:green">GRÖNA</b> fältet.<br/>
Sortera alternativ du vill <strong>mota</strong> ned till <b style="color:red">RÖDA</b> fältet.<br/>
Lämna alternativ du inte har någon åsikt om i det <b style="color:blue">BLÅA</b> fältet.</p>';

    my( @yay, %blank, @nay );

    foreach my $alt ( $prop->has_alternative->as_array )
    {
	$blank{$alt->id} = $alt;
    }

    $palts->reset;
    while( my $palt = $palts->get_next_nos )
    {
	if( $palt->weight > 0 )
	{
	    push @yay, $palt->obj;
	}
	else
	{
	    push @nay, $palt->obj;
	}
	delete $blank{ $palt->obj->id };
    }


    ### YAY
    #
    $widget .= '<ul id="sort_yay" class="gov_sortlist" style="background-color:#3B3">';
    foreach my $alt ( @yay )
    {
	$widget .= sprintf '<li id="gov_%d" class="ui-state-default">', $alt->id;
	$widget .= $alt->wu_jump;
	$widget .= '</li>';
    }
    $widget .= '</ul>';

    ### BLANK
    #
    $widget .= '<ul id="sort_blank" class="gov_sortlist" style="background-color:#55B">';
    foreach my $alt ( values %blank )
    {
	$widget .= sprintf '<li id="gov_%d" class="ui-state-default">', $alt->id;
	$widget .= $alt->wu_jump;
	$widget .= '</li>';
    }
    $widget .= '</ul>';

    ### NAY
    #
    $widget .= '<ul id="sort_nay" class="gov_sortlist" style="background-color:#D22">';
    foreach my $alt ( @nay )
    {
	$widget .= sprintf '<li id="gov_%d" class="ui-state-default">', $alt->id;
	$widget .= $alt->wu_jump;
	$widget .= '</li>';
    }
    $widget .= '</ul>';

    $widget .= submit('Vote');


    $widget .= '<p>' . jump(loc('Add vote alternative'),
		    'add_alternative.tt', {
					   id => $prop->id,
					  });

    return $widget;
}


##############################################################################

sub register_vote
{
    my( $prop, $u, $vote_in ) = @_;
    my( $args, $arclim, $res ) = parse_propargs('relative');

    my $vote_parsed = 0;
    my $changed     = 0;
    my $R           = Rit::Base->Resource;


    # Parse the in-data

    my @votes = split ',', $vote_in;
    my( @yay, @nay );

    while( my $vote_str = shift @votes )
    {
	last if $vote_str eq '|';

	$vote_str =~ /^gov_(\d+)$/ or next;
	my $alt = $R->get($1);
	next unless $prop->has_value({'has_alternative' => $alt}, $args);
	unshift @yay, $alt;
    }

    while( my $vote_str = shift @votes )
    {
	$vote_str =~ /^gov_(\d+)$/ or next;
	my $alt = $R->get($1);
	next unless $prop->has_value({'has_alternative' => $alt}, $args);
	push @nay, $alt;
    }

    my $vote = $R->set_one({rev_has_vote => $prop,
			    rev_places_vote => $u,
			    is => $C_vote,
			   }, $args);

    my( %r_old_alts );
    my $old_alts = $vote->arc_list('places_alternative', undef, $args);
    while( my $arc = $old_alts->get_next_nos )
    {
	$r_old_alts{ $arc->obj->id } = $arc;
    }

    for( my $i=0; $i<=$#yay; $i++ )
    {
	my $alt = $yay[$i];
	if( my $old_arc = delete $r_old_alts{ $alt->id } )
	{
	    next if $old_arc->weight == $i+1;
	    $old_arc->set_weight($i+1);
	    next;
	}

	$vote->add({'places_alternative' => $alt}, {%$args, arc_weight => $i+1});
    }

    for( my $i=0; $i<=$#nay; $i++ )
    {
	my $alt = $nay[$i];
	if( my $old_arc = delete $r_old_alts{ $alt->id } )
	{
	    next if $old_arc->weight == -($i+1);
	    $old_arc->set_weight(-($i+1));
	    next;
	}

	$vote->add({'places_alternative' => $alt}, {%$args, arc_weight => -($i+1)});
    }

    foreach my $old_arc ( values %r_old_alts )
    {
	$old_arc->remove($args);
    }


    # Activate changes
    $res->autocommit({ activate => 1 });


    # Clear vote caches
    delete $GOV::Proposition::VOTE_COUNT{$prop->id};
    delete $GOV::Proposition::ALL_VOTES{$prop->id};
    delete $GOV::Proposition::PREDICTED_RESOLUTION_DATE{$prop->id};
}


##############################################################################

=head2 sum_all_votes

Makes a hash summary of the votes.  This should mainly be called from
GOV::Proposition->get_vote_count, that caches the result.

=cut

sub sum_all_votes
{
    my( $proposition ) = @_;

    warn "fixme sum_all_votes";
    return {};

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

    warn "fixme get_vote_integral";
    return 0;

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

    warn "fixme display_votes";
    return loc('Blank') . ': '. 0;


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

    warn "fixme";
    return loc('Draw');

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

    die "fixme";

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
#			   code   => $weight,
#                           name   => $name,
			  }, $args);

    return $vote;
}


##############################################################################


1;

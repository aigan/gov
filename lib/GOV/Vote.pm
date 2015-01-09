# -*-cperl-*-
package GOV::Vote;

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

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );
use Para::Frame::L10N qw( loc );

use RDF::Base::Utils qw( parse_propargs );
use RDF::Base::Literal::Time qw( now timespan );

##############################################################################

sub longdesig
{
    my( $vote ) = shift;
    return $vote->proposition->vote_longdesig($vote, @_);
}


##############################################################################

sub as_html
{
    my( $vote, $args ) = @_;
    $args ||= {};

    if ( $args->{'long'} )
    {
        return $vote->proposition->vote_as_html_long($vote, $args);
    }
    else
    {
        my( $str ) = CGI->escapeHTML($vote->desig($args));
        $str =~ s/\r?\n/<br\/>/g;
        return $str;
    }
}


##############################################################################

sub desig
{
    my( $vote ) = shift;
    return $vote->proposition->vote_desig($vote, @_);
}


##############################################################################

sub sysdesig
{
    my( $vote ) = @_;
    return $vote->proposition->vote_sysdesig($vote, @_);
}


##############################################################################

sub safedesig
{
    my( $vote ) = @_;
    return $vote->id;
}


##############################################################################

sub yay_alts
{
    return $_[0]->alt_lists->{yay};
}


##############################################################################

sub blank_alts
{
    return $_[0]->alt_lists->{blank};
}


##############################################################################

sub nay_alts
{
    return $_[0]->alt_lists->{nay};
}


##############################################################################

sub alt_lists
{
    unless ( $_[0]->{gov}{alt_lists} )
    {
        my( $vote ) = @_;

        my $prop = $vote->proposition;


        my( @yay, %blank, @nay );

        foreach my $alt ( $prop->has_alternative->as_array )
        {
            $blank{$alt->id} = $alt;
        }

        # Previous alternatives arcs
        my( $palts ) = $vote->arc_list('places_alternative')->
          sorted('weight','desc');
        while ( my $palt = $palts->get_next_nos )
        {
            if ( $palt->weight > 0 )
            {
                push @yay, $palt->obj;
            }
            else
            {
                push @nay, $palt->obj;
            }
            delete $blank{ $palt->obj->id };
        }

        my $alt_lists = $vote->{gov}{alt_lists} =
        {
         yay => RDF::Base::List->new(\@yay),
         nay => RDF::Base::List->new(\@nay),
         blank => RDF::Base::List->new([values %blank]),
        };
    }
    return $_[0]->{gov}{alt_lists};
}


##############################################################################

sub proposition
{
    return( $_[0]->first_revprop('has_vote') ||
            $_[0]->first_revprop('has_resolution_vote') );
}


##############################################################################

sub update_resolution
{
    my( $vote, $date ) = @_;

    my $buffer_days = 14;
    my $now = now();

    my $updated = $vote->updated;
    $date ||= $now;
    return unless $updated < $date;
    my $days = $date->delta_days($updated);
    return unless $days->in_units('days') >= 1;
    my $created = $vote->created;
    return unless
      $created->delta_days($date)->in_units('days') >= $buffer_days;

    my( $args, $arclim, $res ) = parse_propargs();

    my $prop = $vote->first_revprop('has_resolution_vote',undef,$args)
      or return;

    my( %placed, @places );
    my @current = $vote->list('places_alternative',undef,$args)->
      sorted('weight','desc')->as_array;

    my $argsd = {arc_active_on_date=>$date};
    my $alts = $prop->list('has_alternative', undef, $argsd)->
      sorted('alternative_place', undef, $argsd);
    foreach my $alt ( $alts->as_array )
    {
        next if $placed{$alt->id};

        my $placed_place = $alt->first_prop('alternative_place',
                                            undef, $argsd)->plain;
        my $placed_date = $alt->first_arc('alternative_place',
                                          undef, $argsd)->activated;
        my $placed_dur = $now->delta_days($placed_date);

#	debug sprintf( "Place %d for %d days: %s\n",
#		       $placed_place,
#		       $placed_dur->in_units('days'),
#		       $alt->desig
#		     );

        if ( $placed_dur->in_units('days') >= $buffer_days )
        {
            my $score = $alt->first_prop('alternative_score',
                                         undef, $argsd)->plain || 0;

#	    debug "  score: $score";
            last unless $score > 0;

            push @places, $alt;
            $placed{$alt->id} = $alt;
            next;
        }
        # else:

        my $oalt = shift @current or next;
        while ( $placed{$oalt->id} )
        {
            my $o2alt = shift @current or last;
            $oalt = $o2alt;
        }

        my $score = $oalt->first_prop('alternative_score',
                                      undef, $argsd)->plain || 0;
        last unless $score > 0;
        push @places, $oalt;
        $placed{$oalt->id} = $oalt;
    }


#    debug "Updated ".$updated;

    my $weight=0;

    my %old;
    foreach my $arc ( $vote->arc_list('places_alternative')->as_array )
    {
        $old{$arc->obj->id} = $arc;
    }

    while ( my $alt = pop @places )
    {
        $weight ++;

#	debug "PLACING ".$alt->desig." at $weight";

        my $placing_arc = $vote->first_arc('places_alternative', $alt, $args);
        if ( $placing_arc )
        {
            $placing_arc->set_weight($weight,$args);
        }
        else
        {
            $vote->add({places_alternative=>$alt},
                       {
                        %$args,arc_weight=>$weight});
        }

        delete $old{$alt->id};
    }

    foreach my $arc ( values %old )
    {
        $arc->remove($args);
    }

    $res->autocommit({updated=>$date});

    return;
}

##############################################################################

sub on_arc_del
{
    $_[0]->clear_caches(@_);
    $_[0]->revlist('has_vote')->clear_caches;
    $_[0]->revlist('has_resolution_vote')->clear_caches;
}


##############################################################################

sub clear_caches
{
    delete  $_[0]->{'gov'};
}


##############################################################################



1;

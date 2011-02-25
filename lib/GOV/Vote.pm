# -*-cperl-*-
package GOV::Vote;

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

sub desig
{
    my( $vote ) = @_;

    ## TODO: Generalize... this is just for Yay_Nay and Ranked...

    my( $palts ) = $vote->arc_list('places_alternative')->sorted('weight','desc');
    if( $palts ){ return $palts->obj->desig }


    my $name = $vote->weight == 1  ? 'Yay'
             : $vote->weight == -1 ? 'Nay'
                                   : 'Blank';

    return loc($name);
}


1;

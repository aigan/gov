# -*-cperl-*-
package GOV::Delegate;

#=============================================================================
#
# AUTHOR
#   Jonas Liljegren  <jonas@liljegren.org>
#
# COPYRIGHT
#   Copyright (C) 2014 Jonas Liljegren
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#=============================================================================

=head1 NAME

GOV::Delegate

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use Carp qw( confess cluck croak );

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );
#use Para::Frame::Widget qw( jump );
#use Para::Frame::L10N qw( loc );

use RDF::Base::Resource;
use RDF::Base::Utils qw( parse_propargs is_undef );
#use RDF::Base::Literal::Time qw( now );
#use RDF::Base::Constants qw( $C_login_account $C_delegate $C_resolution_state_completed $C_resolution_state_aborted  $C_resolution_method_continous );
#use RDF::Base::Widget qw( locnl aloc );

#use GOV::Voted;

##############################################################################

sub has_allowed
{
    my( $d, $m, $a ) = @_;

    debug "in Delegate has_allowed";
    return 0;
}

##############################################################################


1;

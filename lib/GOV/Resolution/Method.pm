# -*-cperl-*-
package GOV::Resolution::Method;

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

use 5.010;
use strict;
use warnings;
use utf8;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );

use RDF::Base::Literal::Time qw( now timespan );
use RDF::Base::Utils qw( is_undef );

##############################################################################

sub predicted_resolution_date
{
    return is_undef;
}

sub resolution_date
{
    return is_undef;
}

sub vote_chart_svg
{
    return;
}

##############################################################################

1;

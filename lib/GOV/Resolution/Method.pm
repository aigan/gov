# -*-cperl-*-
package GOV::Resolution::Method;

use 5.010;
use strict;
use warnings;
use utf8;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );

use Rit::Base::Literal::Time qw( now timespan );
use Rit::Base::Utils qw( is_undef );

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

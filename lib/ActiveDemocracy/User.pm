# -*-cperl-*-
package ActiveDemocracy::User;

use 5.010;
use strict;
use warnings;
use base qw( Rit::Base::User Rit::Base::Resource );

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug trim );

use Rit::Base::Utils qw( is_undef );
use Rit::Base::User;
use Rit::Base::Constants qw( $C_login_account $C_guest_access );
use Rit::Base::Literal::Time qw( now );

##############################################################################

1;

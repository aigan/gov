# -*-cperl-*-
package GOV::Voted;

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



use Para::Frame::Reload;
#use Para::Frame::Utils qw( debug datadump throw );
#use Para::Frame::L10N qw( loc );

use base qw( Rit::Base::Object );

# A vote is cast by a specific person.  That vote can be held by
# several persons if those persons delegate to the person casting the
# vote. We use THIS class for representing the resulting vote for each
# individual person.


##############################################################################

sub desig
{
    return shift->{vote}->desig(@_);
}

##############################################################################

sub sysdesig
{
    if( $_[0]->{delegate} )
    {
	return( sprintf "Member %s via %s voted %s",
		$_[0]->member->sysdesig,
		$_[0]->delegate->sysdesig,
		$_[0]->vote->sysdesig,
	      );
    }
    else
    {
	return( sprintf "Member voted %s",
		$_[0]->member->sysdesig,
		$_[0]->vote->sysdesig,
	      );
    }
}

##############################################################################

sub member
{
    return $_[0]->{member};
}

##############################################################################

sub vote
{
    return $_[0]->{vote};
}

##############################################################################

sub delegate
{
    return $_[0]->{delegate};
}

##############################################################################



1;

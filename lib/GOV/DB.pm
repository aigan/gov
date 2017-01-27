# -*-cperl-*-
package GOV::DB;

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

GOV::DB

=cut

use 5.010;
use strict;
use warnings;
use utf8;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw );

use RDF::Base::Utils qw( parse_propargs );


##############################################################################

sub initialize
{
	# Don't initialize if we're in rb's setup
	return 0 if( $ARGV[0] and $ARGV[0] eq 'setup_db' );

	debug "initialize_db GOV";

	my $dbix = $RDF::dbix;
	my $dbh = $dbix->dbh;
	my $C = RDF::Base->Constants;
	my $R = RDF::Base->Resource;
	my $class = $C->get('class');
	my $chbpm = 'class_handled_by_perl_module';

	my $req = Para::Frame::Request->new_bgrequest();
	debug "Home is: ". $req->site->home->desig;

	my( $args, $arclim, $res ) = parse_propargs('auto');
	$req->user->set_default_propargs({
																		%$args,
																		activate_new_arcs => 1,
																	 });

	$args->{'force_range_card_max'} = 1;


	my $gov_db = $R->find({ label => 'gov_db' });

	unless( $gov_db )
	{
		my $gov_db =
			$R->create({
									label       => 'gov_db',
									has_version => 1,
								 }, $args);

		Para::Frame->flag_restart();
	}

	debug "has_version is: ". $C->get('has_version')->range->sysdesig;

	my $gov_db_version = $gov_db->has_version->literal;

	if ( $gov_db_version < 2 )
	{
		my $user_module =
			$R->find_set({
										code => 'GOV::User',
										is   => 'class_perl_module',
									 }, $args);
		$C->get('login_account')->update({ $chbpm => $user_module });

		my $proposition_module =
			$R->find_set({
										code => 'GOV::Proposition',
										is   => 'class_perl_module',
									 }, $args);
		my $proposition =
			$R->find_set({
										label          => 'proposition',
										is             => $class,
										$chbpm         => $proposition_module,
									 }, $args);

		my $has_body =
			$R->find_set({
										label => 'has_body',
										is    => 'predicate',
										range => 'text_html',
									 }, $args);

		my $proposition_area =
			$R->find_set({
										label => 'proposition_area',
										is    => $class,
									 }, $args);

		my $subsides_in =
			$R->find_set({
										label  => 'subsides_in',
										is     => 'predicate',
										domain => $proposition,
										range  => $proposition_area,
									 }, $args);

		my $has_voting_jurisdiction =
			$R->find_set({
										label  => 'has_voting_jurisdiction',
										is     => 'predicate',
										domain => 'login_account',
										range  => $proposition_area,
									 }, $args);

#        my $sweden =
#          $R->find_set({
#                        label  => 'proposition_area_sweden',
#                        name   => 'Sveriges riksdag',
#                        is     => $proposition_area,
#                       }, $args);

		my $vote =
			$R->find_set({
										label                        => 'vote',
										is                           => $class,
									 }, $args);

		my $places_vote =
			$R->find_set({
										label  => 'places_vote',
										is     => 'predicate',
										domain => 'login_account',
										range  => $vote,
									 }, $args);

		my $has_vote =
			$R->find_set({
										label  => 'has_vote',
										is     => 'predicate',
										domain => $proposition,
										range  => $vote,
									 }, $args);

		my $yay_nay_proposition_module =
			$R->find_set({
										code => 'GOV::Proposition::Yay_Nay',
										is   => 'class_perl_module',
									 }, $args);

		my $yay_nay_proposition =
			$R->find_set({
										name        => 'Yay/nay proposition',
										label       => 'yay_nay_proposition',
										scof        => $proposition,
										description => 'Proposition to be passed or refused',
										$chbpm      => $yay_nay_proposition_module,
									 }, $args);

		my $has_email =
			$R->find_set({
										label  => 'has_email',
										is     => 'predicate',
										domain => 'intelligent_agent',
										range  => 'text',
									 }, $args);

		$gov_db->update({ has_version => 2 }, $args);
		Para::Frame->flag_restart();
	}

	if ( $gov_db_version < 3 )
	{
		my $delegate =
			$R->find_set({
										label => 'delegate',
										scof  => 'intelligent_agent',
									 }, $args);

		my $delegates_votes_to =
			$R->find_set({
										label  => 'delegates_votes_to',
										is     => 'predicate',
										domain => 'login_account',
										range  => 'delegate',
									 }, $args);

		my $has_short_delegate_description =
			$R->find_set({
										label  => 'has_short_delegate_description',
										is     => 'predicate',
										domain => 'delegate',
										range  => 'text',
									 }, $args);

		my $has_delegate_description =
			$R->find_set({
										label  => 'has_delegate_description',
										is     => 'predicate',
										domain => 'delegate',
										range  => 'text_html',
									 }, $args);
		$gov_db->update({ has_version => 3 }, $args);
		Para::Frame->flag_restart();
	}

	if ( $gov_db_version < 4 )
	{
		my $proposition_resolved_date =
			$R->find_set({
										label       => 'proposition_resolved_date',
										is          => 'predicate',
										domain      => 'proposition',
										range       => 'date',
										description => 'A date set when the proposition got resolved.',
									 }, $args);
		my $has_resolution_vote =
			$R->find_set({
										label       => 'has_resolution_vote',
										is          => 'predicate',
										domain      => 'proposition',
										range       => 'vote',
										description => 'The resolution of a resolved proposition.',
									 }, $args);

		my $resolution_method_module =
			$R->find_set({
										code => 'GOV::Resolution::Method',
										is   => 'class_perl_module',
									 }, $args);

		my $resolution_method =
			$R->find_set({
										label  => 'resolution_method',
										is     => $class,
										$chbpm => $resolution_method_module,
									 }, $args);

		my $resolution_method_progressive_module =
			$R->find_set({
										code => 'GOV::Resolution::Method::Progressive',
										is   => 'class_perl_module',
									 }, $args);
		my $resolution_method_progressive =
			$R->find_set({
										label  => 'resolution_method_progressive',
#                        is     => $resolution_method,
#                        $chbpm => $resolution_method_progressive_module,
									 }, $args);
		my $resolution_progressive_weight =
			$R->find_set({
										label       => 'resolution_progressive_weight',
										is          => 'predicate',
										domain      => 'proposition',
										range       => 'float',
										description => 'The progressive weight, in "days", for a proposition with resolution method progressive.',
									 }, $args);

		my $resolution_method_endtime_module =
			$R->find_set({
										code => 'GOV::Resolution::Method::EndTime',
										is   => 'class_perl_module',
									 }, $args);
		my $resolution_method_endtime =
			$R->find_set({
										label  => 'resolution_method_endtime',
#                        is     => $resolution_method,
#                        $chbpm => $resolution_method_endtime_module,
									 }, $args);
		my $resolution_endtime =
			$R->find_set({
										label       => 'resolution_endtime',
										is          => 'predicate',
										domain      => 'proposition',
										range       => 'date',
										description => 'The set endtime of a proposition with resolution method endtime.',
									 }, $args);


		my $has_resolution_method =
			$R->find_set({
										label       => 'has_resolution_method',
										is          => 'predicate',
										domain      => 'proposition',
										range       => $resolution_method,
										description => 'The method that will determine when a proposition is resolved.',
									 }, $args);

		my $administrates_area =
			$R->find_set({
										label       => 'administrates_area',
										is          => 'predicate',
										domain      => 'login_account',
										range       => 'proposition_area',
										description => 'This account has the permissions to administrate this area.',
									 }, $args);


		$gov_db->update({ has_version => 4 }, $args);
		Para::Frame->flag_restart();
	}

	if ( $gov_db_version < 5 )
	{
		# Already obsolete :P
		$gov_db->update({ has_version => 5 }, $args);
	}

	if ( $gov_db_version < 6 )
	{
		my $has_progressive_default_weight =
			$R->find_set({
										label  => 'has_progressive_default_weight',
										is     => 'predicate',
										domain => 'proposition_area',
										range  => 'float',
									 }, $args);

		$gov_db->update({ has_version => 6 }, $args);
		Para::Frame->flag_restart();
	}

	if ( $gov_db_version < 7 )
	{
		my $vote_module =
			$R->find_set({
										code => 'GOV::Vote',
										is   => 'class_perl_module',
									 }, $args);
		my $vote = $R->find({ label => 'vote' }, $args);
		$vote->update({ $chbpm => $vote_module }, $args);

		$gov_db->update({ has_version => 7 }, $args);
	}

	if ( $gov_db_version < 8 )
	{
		my $is_anonymous =
			$R->find_set({
										is          => 'predicate',
										label       => 'is_anonymous',
										domain      => 'login_account',
										range       => 'bool',
										description => 'Prohibits displaying of name to non-admins.',
									 }, $args);

		$gov_db->update({ has_version => 8 }, $args);
		Para::Frame->flag_restart();
	}


	if ( $gov_db_version < 10 )
	{
		my $wants_notification_on =
			$R->find_set({
										is          => 'predicate',
										label       => 'wants_notification_on',
										domain      => 'login_account',
										range       => 'text',
										description => 'Occations to send notifications, strings defined in different modules',
									 }, $args);

		$gov_db->update({ has_version => 10 }, $args);
		Para::Frame->flag_restart();
	}


	if ( $gov_db_version < 11 )
	{
		my $prop = $C->get('proposition');
		my $vote = $C->get('vote');
		my $ranked_module =
			$R->find_set({
										code => 'GOV::Proposition::Ranked',
										is   => 'class_perl_module',
									 }, $args);

		my $ranked =
			$R->find_set({
										name        => 'Ranked proposition',
										label       => 'ranked_proposition',
										scof        => $prop,
										description => 'Proposition with choises to be ranked',
										$chbpm      => $ranked_module,
									 }, $args);

		my $vote_alternative =
			$R->find_set({
										label                        => 'vote_alternative',
										is                           => $class,
									 }, $args);

		my $has_alternative =
			$R->find_set({
										label       => 'has_alternative',
										is          => 'predicate',
										domain      => $prop,
										range       => $vote_alternative,
									 }, $args);

		my $places_alternative =
			$R->find_set({
										label       => 'places_alternative',
										is          => 'predicate',
										domain      => $vote,
										range       => $vote_alternative,
									 }, $args);


		$prop->update({class_form_url=>'proposition/display.tt'}, $args);


		$gov_db->update({ has_version => 11 }, $args);
		Para::Frame->flag_restart();
	}

	if ( $gov_db_version < 12 )
	{
		$C->get('vote_alternative')->update({class_form_url=>'proposition/vote_alternative.tt'}, $args);
		$gov_db->update({ has_version => 12 }, $args);
	}

	if ( $gov_db_version < 13 )
	{
		$R->find_set({
									label       => 'cas_id',
									is          => 'predicate',
									domain      => $C->get('login_account'),
									range       => $C->get('int'),
								 }, $args);
		$gov_db->update({ has_version => 13 }, $args);
	}

	if ( $gov_db_version < 14 )
	{
		my $rmp = $C->get('resolution_method_progressive');
		my $rm = $C->get('resolution_method');
		$rmp->first_arc('is',$rm,$args)->remove($args);

		my $rmpm =
			$R->find_set({
										code => 'GOV::Resolution::Method::Progressive',
										is   => 'class_perl_module',
									 }, $args);

		$rmp->first_arc($chbpm,$rmpm,$args)->
			remove($args);

		my $rmpc =
			$R->find_set({
										label  => 'resolution_method_progressive_class',
										scof   => $rm,
										$chbpm => $rmpm,
									 }, $args);

		$rmp->add({'is'=>$rmpc}, $args);


		$gov_db->update({ has_version => 14 }, $args);
	}

	if ( $gov_db_version < 15 )
	{
		my $area = $C->get('proposition_area');
		my $area_module =
			$R->find_set({
										code => 'GOV::Area',
										is   => 'class_perl_module',
									 }, $args);
		$area->update({$chbpm => $area_module}, $args );

		my $membership_module =
			$R->find_set({
										code => 'GOV::Area::Membership',
										is   => 'class_perl_module',
									 }, $args);
		my $membership =
			$R->find_set({
										label  => 'membership_criteria',
										is     => $class,
										$chbpm => $membership_module,
									 }, $args);

		my $membership_json_module =
			$R->find_set({
										code => 'GOV::Area::Membership::JSON',
										is   => 'class_perl_module',
									 }, $args);
		my $membership_json =
			$R->find_set({
										label  => 'membership_criteria_by_json_attribute',
										scof   => $membership,
										$chbpm => $membership_json_module,
									 }, $args);

		my $membership_admission_module =
			$R->find_set({
										code => 'GOV::Area::Membership::Admission',
										is   => 'class_perl_module',
									 }, $args);
		my $membership_admission =
			$R->find_set({
										label  => 'membership_criteria_by_admission',
										scof   => $membership,
										$chbpm => $membership_admission_module,
									 }, $args);

#	$R->find_set({
#		      label       => 'using_json_attribute_exist',
#		      is          => 'predicate',
#		      domain      => $membership_json,
#		      range       => $C->get('term'),
#                     }, $args);

		$R->find_set({
									label       => 'using_json_attribute_true',
									is          => 'predicate',
									domain      => $membership_json,
									range       => $C->get('term'),
								 }, $args);

		$R->find_set({
									label       => 'has_membership_criteria',
									is          => 'predicate',
									domain      => $area,
									range       => $membership,
								 }, $args);



		Para::Frame->flag_restart();
		$gov_db->update({ has_version => 15 }, $args);
	}

	if ( $gov_db_version < 16 )
	{
		my $rme = $C->get('resolution_method_endtime');
		my $rm = $C->get('resolution_method');
		$rme->first_arc('is',$rm,$args)->remove($args);

		my $rmem =
			$R->find_set({
										code => 'GOV::Resolution::Method::EndTime',
										is   => 'class_perl_module',
									 }, $args);

		$rme->first_arc($chbpm,$rmem,$args)->
			remove($args);

		my $rmec =
			$R->find_set({
										label  => 'resolution_method_endtime_class',
										scof   => $rm,
										$chbpm => $rmem,
									 }, $args);

		$rme->add({'is'=>$rmec}, $args);

		Para::Frame->flag_restart();
		$gov_db->update({ has_version => 16 }, $args);
	}

	if ( $gov_db_version < 17 )
	{
		my $resolution_state =
			$R->find_set({
										label          => 'resolution_state',
										is             => $class,
									 }, $args);

		$R->find_set({
									label       => 'has_resolution_state',
									is          => 'predicate',
									domain      => 'proposition',
									range       => $resolution_state,
								 }, $args);

		$R->find_set({
									label          => 'resolution_state_completed',
									is             => $resolution_state,
								 }, $args);

		$R->find_set({
									label          => 'resolution_state_aborted',
									is             => $resolution_state,
								 }, $args);

		$R->find({has_resolution_vote_exist=>1})->
			update({has_resolution_state=>'resolution_state_completed'},$args);

		Para::Frame->flag_restart();
		$gov_db->update({ has_version => 17 }, $args);
	}

	if ( $gov_db_version < 18 )
	{
		my $prios = $C->get('ranked_proposition')->revlist('is');
		$prios->has_vote->create_rec;
		$prios->has_alternative->create_rec;
		$C->get('proposition')->revlist('is')->create_rec;

		$R->find_set({
									label  => 'free_membership',
									is   => $C->get('membership_criteria'),
								 }, $args);

		$R->find_set({
									label  => 'admission_membership',
									is   => $C->get('membership_criteria'),
								 }, $args);

		$R->find_set({
									label => 'membership_message',
									is    => 'predicate',
									range => 'text_html',
								 }, $args);

		Para::Frame->flag_restart();
		$gov_db->update({ has_version => 18 }, $args);
	}

	if ( $gov_db_version < 19 )
	{
		$R->find_set({
									label => 'has_voting_duration_days',
									is    => 'predicate',
									range => $C->get('int'),
								 }, $args);

		$R->find_set({
									label => 'has_voting_endtime',
									is    => 'predicate',
									domain => $C->get('proposition'),
									range => $C->get('date'),
								 }, $args);

		Para::Frame->flag_restart();
		$gov_db->update({ has_version => 19 }, $args);
	}

	if ( $gov_db_version < 20 )
	{
		my $rm = $C->get('resolution_method');

		my $rmcm =
			$R->find_set({
										code => 'GOV::Resolution::Method::Continous',
										is   => 'class_perl_module',
									 }, $args);

		my $rmcc =
			$R->find_set({
										label  => 'resolution_method_continous_class',
										scof   => $rm,
										$chbpm => $rmcm,
									 }, $args);

		my $rmc =
			$R->find_set({
										label  => 'resolution_method_continous',
										is     => $rmcc,
									 }, $args);

		$gov_db->update({ has_version => 20 }, $args);
	}

	if ( $gov_db_version < 21 )
	{
		my $proposition = $C->get('proposition');

		my $median_proposition_module =
			$R->find_set({
										code => 'GOV::Proposition::Median',
										is   => 'class_perl_module',
									 }, $args);

		my $median_proposition =
			$R->find_set({
										name        => 'Median proposition',
										label       => 'median_proposition',
										scof        => $proposition,
										$chbpm      => $median_proposition_module,
									 }, $args);

		$gov_db->update({ has_version => 21 }, $args);
	}

	if ( $gov_db_version < 22 )
	{
		$R->find_set({
									label => 'has_secret',
									is    => 'predicate',
									range => $C->get('password'),
								 }, $args);
		$gov_db->update({ has_version => 22 }, $args);
	}

	if ( $gov_db_version < 23 )
	{
		my $bool = $C->get('bool');
		my $pred = $C->get('predicate');

		my $individual
			= $R->find_set({
											label => 'individual',
											admin_comment => "Individual is the collection of all individuals: things that are not sets or collections. Individuals might be concrete or abstract, and include (among other things) physical objects, events, numbers, relations, and groups.",
											is => $class,
											has_cyc_id => 'Individual',
										 }, $args);

		my $temporal_stuff_type
			= $R->find_set({
											label => 'temporal_stuff_type',
											admin_comment => "Temporal Thing class",
											has_cyc_id => 'TemporalStuffType',
											is => $class,
										 }, $args);

		my $information_store
			= $R->find_set({
											label => 'information_store',
											admin_comment => "Each instance of InformationStore is a tangible or intangible, concrete or abstract repository of information. The information stored in an information store is stored there as a consequence of the actions of one or more agents.",
											has_cyc_id => 'InformationStore',
											is => $temporal_stuff_type,
											scof => $individual,
										 }, $args);

		my $ais
			= $R->find_set({
											label => 'ais',
											admin_comment => "AspatialInformationStore is the collection of all information stores that have no spatial location. Specializations of AspatialInformationStore include ConceptualWork, Microtheory, AbstractInformationStructure, and FieldOfStudy.",
											has_cyc_id => 'AspatialInformationStore',
											scof => $information_store,
										 }, $args);

		$R->find_set({
									label => 'cia',
									is => $pred,
									domain => $ais,
									range => $C->get('resource'),
									has_cyc_id => 'containsInformationAbout',
									admin_comment => "Contains information about. Old TS. This predicate relates sources of information to their topics.",
								 }, $args);

		my $prop_context
			= $R->find_set({
											label => 'proposition_context',
											scof => $ais,
											is => $class,
										 }, $args);

		$C->get('proposition_area')->
			update({
							class_form_url => 'area/display.tt',
							scof => $prop_context,
						 }, $args);

		$C->get('proposition')->
			update({
							scof => $prop_context,
						 }, $args);

		$gov_db->
			update({
							scof => $prop_context,
						 }, $args);

		$R->find_set({
									label => 'has_public_members',
									is    => $pred,
									domain => $prop_context,
									range => $bool,
									range_card_max => 1,
								 }, $args);

		$R->find_set({
									label => 'has_public_votes',
									is    => $pred,
									domain => $prop_context,
									range => $bool,
									range_card_max => 1,
								 }, $args);

		$R->find_set({
									label => 'broader',
									is    => $pred,
									range => $R->get('resource'),
									has_cyc_id => 'generalizations',
									admin_comment => "relates things of various kinds to things of the same kind that are correlatively at least as general or inclusive as they are.",
								 }, $args);


		$gov_db->update({ has_version => 23 }, $args);
	}

	if ( $gov_db_version < 24 )
	{
		$C->get('login_account')->
			update({
							class_form_url => 'member/edit.tt',
						 }, $args);

		$gov_db->update({ has_version => 24 }, $args);
	}

	if ( $gov_db_version < 25 )
	{
		my $pred = $C->get('predicate');

		$R->find_set({
									label => 'alternative_place',
									is    => $pred,
									domain => $C->get('vote_alternative'),
									range => $C->get('int'),
									range_card_max => 1,
								 }, $args);

		my $config
			= $R->find_set({
											label => 'config',
											scof => $C->get('ais'),
										 }, $args);

		$R->find_set({
									label => 'has_config',
									is    => $pred,
									domain => $C->get('intelligent_agent'),
									range => $config,
								 }, $args);

  	$R->find_set({
									label => 'config_for',
									is    => $pred,
									domain => $config,
									range => $C->get('resource'),
								 }, $args);

		$gov_db->update({ has_version => 25 }, $args);
	}

	if ( $gov_db_version < 26 )
	{
		my $alt_score =
			$R->find_set({
										label => 'alternative_score',
										is    => $C->get('predicate'),
										domain => $C->get('vote_alternative'),
										range => $C->get('int'),
										range_card_max => 1,
									 }, $args);

		foreach my $alt ( $R->find({is=>$C->get('vote_alternative')})->nodes )
		{
	    my $prop = $alt->first_revprop('has_alternative');
	    my $vc = $prop->get_alternative_vote_count($alt);
	    my $score = $vc->{score};
	    $alt->add({alternative_score=>$score}, $args);
		}


		$gov_db->update({ has_version => 26 }, $args);
	}

	if ( $gov_db_version < 27 )
	{
		my $alt_module =
			$R->find_set({
										code => 'GOV::Proposition::Alternative',
										is   => 'class_perl_module',
									 }, $args);
		$C->get('vote_alternative')->update({ $chbpm => $alt_module });

		$gov_db->update({ has_version => 27 }, $args);
	}

	if ( $gov_db_version < 28 )
	{

		$R->find_set({
									label => 'has_buffer_days',
									is    => $C->get('predicate'),
									domain => $C->get('proposition_context'),
									range => $C->get('int'),
									range_card_max => 1,
								 }, $args);

		$R->find_set({
									label => 'has_activation_delay_days',
									is    => $C->get('predicate'),
									domain => $C->get('proposition_context'),
									range => $C->get('int'),
									range_card_max => 1,
								 }, $args);

		$C->get('has_resolution_method')->
			update({
							range_card_max => 1,
						 }, $args);

		$gov_db->update({ has_version => 28 }, $args);
	}


	if ( $gov_db_version < 29 )
	{

		$C->get('has_resolution_vote')->
			update({
							range_card_max => 1,
						 }, $args);

		$C->get('proposition_resolved_date')->
			update({
							range_card_max => 1,
						 }, $args);

		$C->get('has_resolution_state')->
			update({
							range_card_max => 1,
						 }, $args);

		$gov_db->update({ has_version => 29 }, $args);
	}



###################################


	# Check if root password is to be set
	$req->user->set_password($1, $args)
		if ( $ARGV[0] and $ARGV[0] =~ /^set_root_password=(.*)$/ );

	$res->autocommit;
	$dbh->commit;
	$Para::Frame::REQ->done;
	$req->user->set_default_propargs(undef);

	return 1;
}


##############################################################################

1;

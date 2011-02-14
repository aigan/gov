# -*-cperl-*-
package GOV;

use 5.010;
use strict;
use warnings;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw validate_utf8 catch create_dir );

use Rit::Base::Utils qw( valclean parse_propargs query_desig );
use Rit::Base::Constants qw( $C_proposition );

our $CFG;

##############################################################################

=head2 store_cfg

=cut

sub store_cfg
{
    $CFG = $_[1];
}


##############################################################################

sub initialize_db
{
    # Don't initialize if we're in rb's setup
    return if( $ARGV[0] and $ARGV[0] eq 'setup_db' );

    debug "initialize_db GOV";

    my $dbix = $Rit::dbix;
    my $dbh = $dbix->dbh;
    my $C = Rit::Base->Constants;
    my $R = Rit::Base->Resource;

    my $req = Para::Frame::Request->new_bgrequest();
    debug "Home is: ". $req->site->home->desig;

    my $root = $R->get_by_label('root');
    my( $args, $arclim, $res ) = parse_propargs('auto');
    $req->user->set_default_propargs({
				      %$args,
				      activate_new_arcs => 1,
				     });

    my $gov_db = $R->find({ label => 'gov_db' });

    unless( $gov_db )
    {
        my $has_version =
          $R->create({
                      label       => 'has_version',
                      is          => 'predicate',
                      range       => $C->get('int'),
                     }, $args);

	#$res->autocommit;
	#$dbh->commit;
	#$Para::Frame::REQ->done;

        my $gov_db =
          $R->create({
                      label       => 'gov_db',
                      has_version => 1,
                     }, $args);

        $Para::Frame::TERMINATE = 'RESTART';
    }

    debug "has_version is: ". $C->get('has_version')->range->sysdesig;

    my $gov_db_version = $gov_db->has_version->literal;

    if( $gov_db_version < 2 )
    {
	my $user_module =
	  $R->find_set({
			code => 'GOV::User',
			is   => 'class_perl_module',
		       }, $args);
	$C->get('login_account')->update({ class_handled_by_perl_module => $user_module });

        my $proposition_module =
          $R->find_set({
                        code => 'GOV::Proposition',
                        is   => 'class_perl_module',
                       }, $args);
        my $proposition =
          $R->find_set({
                        label                        => 'proposition',
                        is                           => 'class',
                        class_handled_by_perl_module => $proposition_module,
                        class_form_url               => '/proposition/new.tt',
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
                        is    => 'class',
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

        my $sweden =
          $R->find_set({
                        label  => 'proposition_area_sweden',
                        name   => 'Sveriges riksdag',
                        is     => $proposition_area,
                       }, $args);

        my $vote =
          $R->find_set({
                        label                        => 'vote',
                        is                           => 'class',
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
			name                         => 'Yay/nay proposition',
                        label                        => 'yay_nay_proposition',
                        scof                         => $proposition,
			description                  => 'Proposition to be passed or refused',
                        class_handled_by_perl_module => $yay_nay_proposition_module,
                       }, $args);

	my $has_email =
	  $R->find_set({
			label  => 'has_email',
			is     => 'predicate',
			domain => 'intelligent_agent',
			range  => 'text',
		       }, $args);

        $gov_db->update({ has_version => 2 }, $args);
        $Para::Frame::TERMINATE = 'RESTART';
    }
    if( $gov_db_version < 3 )
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
        $Para::Frame::TERMINATE = 'RESTART';
    }

    if( $gov_db_version < 4 )
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
                        label                        => 'resolution_method',
                        is                           => 'class',
                        class_handled_by_perl_module => $resolution_method_module,
                       }, $args);

        my $resolution_method_progressive_module =
          $R->find_set({
                        code => 'GOV::Resolution::Method::Progressive',
                        is   => 'class_perl_module',
                       }, $args);
        my $resolution_method_progressive =
          $R->find_set({
                        label                        => 'resolution_method_progressive',
                        is                           => $resolution_method,
                        class_handled_by_perl_module => $resolution_method_progressive_module,
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
                        label                        => 'resolution_method_endtime',
                        is                           => $resolution_method,
                        class_handled_by_perl_module => $resolution_method_endtime_module,
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
        $Para::Frame::TERMINATE = 'RESTART';
    }

    if( $gov_db_version < 5 )
    {
        # Already obsolete :P
        $gov_db->update({ has_version => 5 }, $args);
    }

    if( $gov_db_version < 6 )
    {
        my $has_progressive_default_weight =
          $R->find_set({
                        label  => 'has_progressive_default_weight',
                        is     => 'predicate',
                        domain => 'proposition_area',
                        range  => 'float',
                       }, $args);

        $gov_db->update({ has_version => 6 }, $args);
        $Para::Frame::TERMINATE = 'RESTART';
    }

    if( $gov_db_version < 7 )
    {
        my $vote_module =
          $R->find_set({
                        code => 'GOV::Vote',
                        is   => 'class_perl_module',
                       }, $args);
        my $vote = $R->find({ label => 'vote' }, $args);
        $vote->update({ class_handled_by_perl_module => $vote_module }, $args);

        $gov_db->update({ has_version => 7 }, $args);
    }

    if( $gov_db_version < 8 )
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
        $Para::Frame::TERMINATE = 'RESTART';
    }


    if( $gov_db_version < 10 )
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
        $Para::Frame::TERMINATE = 'RESTART';
    }


    # Check if root password is to be set
    $req->user->set_password($1, $args)
      if( $ARGV[0] and $ARGV[0] =~ /^set_root_password=(.*)$/ );

    $res->autocommit;
    $dbh->commit;
    $Para::Frame::REQ->done;
    $req->user->set_default_propargs(undef);
}



##############################################################################

sub run_background_jobs
{
    debug "Background job is run.";

    my $propositions = $C_proposition->revlist('is');
    while( my $proposition = $propositions->get_next_nos ) {
        next unless $proposition->is_open;
        if( $proposition->should_be_resolved ) {
            $proposition->resolve;
        }
    }
}


1;

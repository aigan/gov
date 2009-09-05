# -*-cperl-*-
package ActiveDemocracy;

use 5.010;
use strict;
use warnings;

use Para::Frame::Reload;
use Para::Frame::Utils qw( debug datadump throw validate_utf8 catch create_dir );

use Rit::Base::Utils qw( valclean parse_propargs query_desig );

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

    debug "initialize_db ActiveDemocracy";

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

    my $ad_db = $R->find({ label => 'ad_db' });

    unless( $ad_db )
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

        my $ad_db =
          $R->create({
                      label       => 'ad_db',
                      has_version => 1,
                     }, $args);
    }

    debug "has_version is: ". $C->get('has_version')->range->sysdesig;

    my $ad_db_version = $ad_db->has_version->literal;

    if( $ad_db_version < 2 )
    {
	my $user_module =
	  $R->find_set({
			code => 'ActiveDemocracy::User',
			is   => 'class_perl_module',
		       }, $args);
	$C->get('login_account')->update({ class_handled_by_perl_module => $user_module });

        my $proposition_module =
          $R->find_set({
                        code => 'ActiveDemocracy::Proposition',
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
                        label  => 'vote',
                        is     => 'class',
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
                        code => 'ActiveDemocracy::Proposition::Yay_Nay',
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

        $ad_db->update({ has_version => 2 }, $args);
    }
    if( $ad_db_version < 3 )
    {
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


1;

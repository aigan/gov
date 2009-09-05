# -*-cperl-*-
package ActiveDemocracy;

use 5.010;
use strict;
use warnings;

use Digest::MD5  qw(md5_hex);

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
    debug "initialize_db ActiveDemocracy";

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

    # Check if root password is to be set
    if( $ARGV[0] and $ARGV[0] =~ /^set_root_password=(.*)$/ )
    {
	my $dbix = $Rit::dbix;
	my $dbh = $dbix->dbh;
	my $passwd   = $1;
	my $md5_salt = $Para::Frame::CFG->{'md5_salt'};
	$passwd      = md5_hex($passwd, $md5_salt);

	debug "Setting new root password.";
	debug "Server salt is $md5_salt";
	debug "Passwd is $passwd";

	$req->user->update({ has_password => $passwd }, $args );
	$res->autocommit;
	$dbh->commit;
    }

    my $ad_db = $R->find({ label => 'ad_db' });

    unless( $ad_db )
    {
        my $has_version =
          $R->create({
                      label       => 'has_version',
                      is          => 'predicate',
                      range       => $C->get('text'),
                     });
        my $ad_db =
          $R->create({
                      label       => 'ad_db',
                      has_version => 1,
                     });
    }

    debug "has_version is: ". $R->find({ label => 'has_version' })->range->sysdesig;

    my $ad_db_version = $ad_db->has_version->literal;

    if( $ad_db_version < 2 )
    {
        my $proposition_module =
          $R->find_set({
                        code => 'ActiveDemocracy::Proposition',
                        is   => 'class_perl_module',
                       });
        my $proposition =
          $R->find_set({
                        label => 'proposition',
                        is    => 'class',
                        class_handled_by_perl_module => $proposition_module,
                        class_form_url => '/proposition/new.tt',
                       });

        my $has_body =
          $R->find_set({
                        label => 'has_body',
                        is    => 'predicate',
                        range => 'text_html',
                       });

        my $proposition_area =
          $R->find_set({
                        label => 'proposition_area',
                        is    => 'class',
                       });

        my $subsides_in =
          $R->find_set({
                        label  => 'subsides_in',
                        is     => 'predicate',
                        domain => $proposition,
                        range  => $proposition_area,
                       });

        my $has_voting_jurisdiction =
          $R->find_set({
                        label  => 'has_voting_jurisdiction',
                        is     => 'predicate',
                        domain => 'login_account',
                        range  => $proposition_area,
                       });

        my $sweden =
          $R->find_set({
                        label  => 'proposition_area_sweden',
                        name   => 'Sveriges riksdag',
                        is     => $proposition_area,
                       });

        my $vote_type =
          $R->find_set({
                        label  => 'vote_type',
                        is     => 'class',
                       });

        my $vote =
          $R->find_set({
                        label  => 'vote',
                        is     => 'class',
                        subclasses_are => $vote_type,
                       });

        my $places_vote =
          $R->find_set({
                        label  => 'places_vote',
                        is     => 'predicate',
                        domain => 'login_account',
                        range  => $vote,
                       });

        my $trinary_vote_module =
          $R->find_set({
                        code => 'ActiveDemocracy::Vote::Trinary',
                        is   => 'class_perl_module',
                       });


        my $trinary_vote =
          $R->find_set({
                        label  => 'trinary_vote',
                        name   => 'Yes / No / Blank',
                        scof   => $vote,
                        class_handled_by_perl_module => $trinary_vote_module,
                        description => 'A vote of yay, nay or blank',
                       });

        my $uses_vote_type =
          $R->find_set({
                        label  => 'uses_vote_type',
                        is     => 'predicate',
                        domain => $proposition,
                        range  => $vote_type,
                       });

	my $has_vote =
	  $R->find_set({
			label  => 'has_vote',
			is     => 'predicate',
			domain => $proposition,
			range  => $vote,
		       });


	my $has_email =
	  $R->find_set({
			label  => 'has_email',
			is     => 'predicate',
			domain => 'intelligent_agent',
			range  => 'text',
		       });

        $ad_db->update({ has_version => 2 });
    }
    if( $ad_db_version < 3 )
    {
    }

    $Para::Frame::REQ->done;
    $req->user->set_default_propargs(undef);
}



##############################################################################


1;

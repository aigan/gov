package GOV::Action::mail_send_bulk;

use strict;
use warnings;
use utf8;


use Storable qw(store retrieve);

use Para::Frame::Utils qw( debug datadump throw create_dir );

use RDF::Base::Constants qw( $C_email $C_login_account );
use RDF::Base::Utils qw( parse_propargs query_desig );
use RDF::Base::Arc;

sub handler
{
	my( $req ) = @_;
	$req->note("Testing stuff");

	my $members = $C_login_account->revlist('is')->find({id=>9886});
#	my $members = $C_login_account->revlist('is');
	my $esp_in =
	{
	 u => $req->session->user->id,
	 site => $req->site->code,
	 lang => $req->language->preferred,

	 from =>  $Para::Frame::CFG->{'email'},
#	 on_set_tt_params => 'Rit::Guides::Email',
	 subject => "Test subject",
	 email_body => "Test body\n",
	};

	debug "members " . datadump($members,2);
#	debug( datadump($esp_in) );

	my $bulkid = scalar(time).'-'.$req->id.'-'. (++ $req->{'bulkmailid'});
	my $dirname = $Para::Frame::CFG->{'dir_var'}.'/bulkmail/'.$bulkid;
	create_dir($dirname);
	store($esp_in, $dirname.'/params');

	my $fh = new IO::File $dirname.'/receivers', '>';

	my $to_obj_list = $members;
	$to_obj_list->reset;
	my( $to_obj, $to_obj_err ) = $to_obj_list->get_first;
	while ( !$to_obj_err )
	{
		unless( $to_obj_list->count % 20 )
		{
	    $req->note("Queued up at email ".$to_obj_list->count);
	    die "cancelled" if $req->cancelled;
		}

		$fh->say( $to_obj->id );

		( $to_obj, $to_obj_err ) = $to_obj_list->get_next;
	}
	$fh->close;

	store({
				 at         => 0,
				 cnt_proc   => 0,
				 cnt_sent   => 0,
				 cnt_failed => 0,
				 cnt_total  => $to_obj_list->size,
				}, $dirname.'/state');

	return( "Bulkmail $dirname" );
}

1;

#!/usr/bin/perl
#
# Install the following perl dependencies in ArchLinux:
# yaourt -S perl-lwp-protocol-https perl-xml-libxml
#

use strict;
use warnings;
no warnings 'experimental::smartmatch';

use LWP::UserAgent;
use XML::LibXML;
use Getopt::Long;

my $verbose;

sub usage {
    print "ERROR: Unknown parameter \"@_\".\n" if (@_);
    print "                                  \n"
      . "usage: generate-mailinglists.pl     \n"
      . "--user|-u <username>                \n"
      . "--pass|-p <password>                \n"
      . "--host|-h <hostname>                \n"
      . "[--catch-all <email>]               \n"
      . "[--private <private-list-id>]       \n"
      . "[--verbose|-v]                      \n"
      . "[--help|-?]                         \n\n"
      . "Example:                            \n"
      . "./generate-mailinglists.pl -u admin -p secret -h owncloud.domain.com --private intern --private workgroup\n\n";
    exit;
}

sub http_get {
    ( my $uri, my $user, my $pass ) = @_;

    # define user agent
    my $ua = LWP::UserAgent->new();
    $ua->agent("USER/AGENT/IDENTIFICATION");

    # make request
    my $request = HTTP::Request->new( GET => $uri );

    # authenticate
    $request->authorization_basic( $user, $pass );

    # request data
    my $response = $ua->request($request);
    die "Error " . $response->status_line unless $response->is_success;

    # get content of response
    return $response->content();

}

sub check_status_ok {
    ( my $dom ) = @_;
    die "Error reading data from owncloud"
      unless ( ( $dom->findnodes('/ocs/meta/status') ) eq "ok" );
}

sub get_list_from_api {
    ( my $apicall, my $user, my $pass, my $xpath ) = @_;
    my $xml = http_get( $apicall, $user, $pass );
    my $dom = XML::LibXML->load_xml( string => $xml );
    check_status_ok($dom);
    return $dom->findnodes($xpath);
}

#
# Main
#

# config parameters
my ( $help, $user, $pass, $server, @private, $catchall );

$user     = "";
$pass     = "";
$server   = "";
@private  = ();
$catchall = "";

# parse commandline parameters
usage()
  if (
    !GetOptions(
        'help|?'      => \$help,
        'verbose|v'   => \$verbose,
        'user|u=s'    => \$user,
        'pass|p=s'    => \$pass,
        'host|h=s'    => \$server,
        'private:s'   => \@private,
        'catch-all:s' => \$catchall,
    )
    or defined $help
  );

print "Requesting data from owncloud...\n" if defined $verbose;
my $api    = "https://$server/ocs/v1.php/cloud";
my $result = "# Exim filter <<-- Do not edit or remove this line\n#\n\n";
my @list   = get_list_from_api( "$api/groups", $user, $pass,
    '/ocs/data/groups/element/text()' );

foreach (@list) {
    print "Processing group $_\n" if defined $verbose;
    my @list = get_list_from_api( "$api/groups/$_", $user, $pass,
        '/ocs/data/users/element/text()' );
    my $deliver;
    my $fromcheck;
    my $n = $#list;

    foreach (@list) {
        my @list = get_list_from_api( "$api/users/$_", $user, $pass,
            '/ocs/data/email/text()' );
        my $email = $list[0];
        $deliver .= "  if \$header_from does not contain \"" . $email . "\" then deliver $email endif" . ( !$n ? "" : "\n" );
        $fromcheck .= "    \$header_from does contain \"$email\" "
          . ( !$n-- ? "" : "or\n" );
    }

    $result .=
        "if\n  \$header_to contains \"$_\""
      . ( $_ ~~ @private ? " and \n  (\n$fromcheck\n  )" : "" )
      . "\nthen\n"
      . "$deliver\nendif\n\n";
}

if ( $catchall ne "" ) {
    $result .=
      "# Catch all\nif not delivered then\n" . "  deliver $catchall\nendif";
}

print "Writing new .forward file\n" if defined $verbose;

open( my $fh, ">$ENV{'HOME'}/.forward" )
  or die "Could not open .forward file: $!";
print $fh $result;
close $fh;

print "All done!\n" if defined $verbose;

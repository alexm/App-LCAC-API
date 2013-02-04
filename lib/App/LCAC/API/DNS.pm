use strict;
use warnings;
package App::LCAC::API::DNS;
# ABSTRACT: Query LCAC databases via DNS

=head1 SYNOPSIS

    use App::LCAC::API::DNS;
    App::LCAC::API::DNS->new( db => { name => $db } )->run;

=head1 DESCRIPTION

This module lets you have a DNS server that can be used to query
several LCAC databases in only one instance.

Any DNS resolver can be used as a client to this server, but be
warned that query syntax is not compatible with standard DNS layout.
Only authoritative TXT queries are supported so far.

=head2 Example with dig:

    dig @localhost -p 1234 +short dbname:file:key txt

=cut

use Net::DNS::Nameserver ();
use Text::CSV::LCAC      ();

sub __reply_handler {
    my ( $self, $qname, $qclass, $qtype, $peerhost, $query, $conn ) = @_;
    my ( $rcode, @ans, @auth, @add );
 
    my $dbname = (split Text::CSV::LCAC->separator(), $qname)[0];
 
    if ( $dbname ne "" && $qtype eq "TXT" && exists $self->{db}{$dbname} ) {
	my $qreply = $self->{db}{$dbname}->query($qname);

	if ( defined $qreply ) {
            my ( $ttl, $rdata ) = ( 1, $qreply );
            my $rr = Net::DNS::RR->new("$qname $ttl $qclass $qtype $rdata");
            push @ans, $rr;
            $rcode = "NOERROR";
        }
	else {
            $rcode = "NXDOMAIN";
	}
    }
    else {
        $rcode = "NXDOMAIN";
    }

    print localtime . " received $qtype query $qname from $peerhost with $rcode\n";
 
    # mark the answer as authoritive by setting the 'aa' flag
    return( $rcode, \@ans, \@auth, \@add, { aa => 1 } );
}

=method new( %params )

Returns a new object built with parameters:

=over 4

=item host

Hostname to bind the DNS server, defaults to localhost.

=item port

Port to bind the DNS server, defaults to 5353.

=item db

Hash reference of database names and C<Text::CSV::LCAC> objects.

=back

=cut

sub new {
    my ( $class, %params ) = @_;

    my $object = bless {}, $class;
    my $ns     = Net::DNS::Nameserver->new(
        LocalAddr    => $params{host} || '127.0.0.1',
        LocalPort    => $params{port} || '5353',
        ReplyHandler => sub { __reply_handler( $object, @_ ) },
        Verbose      => 0,
    ) or die "could not create nameserver object\n";
 
    $object->{ns} = $ns;
    $object->{db} = $params{db};

    return $object;
}

=method run( )

Starts the server.

=cut

sub run {
    my $self = shift;

    $self->{ns}->main_loop;
}

=method query( $resolver, $text )

Queries the resolver for text.

=cut

sub query {
    my ( $class, $resolver, $text ) = @_;

    my $reply = "";
    my $query = $resolver->query( $text, "TXT" );
    if ($query) {
        for my $rr ( $query->answer ) {
            next unless $rr->type eq "TXT";

            $reply .= $rr->txtdata;
        }
    }
    else {
        $reply = "query failed: " . $resolver->errorstring;
    }

    return $reply;
}

1;

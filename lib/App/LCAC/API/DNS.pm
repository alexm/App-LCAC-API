use strict;
use warnings;
package App::LCAC::API::DNS;
# ABSTRACT: Query LCAC databases via DNS

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
    else{
        $rcode = "NXDOMAIN";
    }

    print localtime . " received $qtype query $qname from $peerhost with $rcode\n";
 
    # mark the answer as authoritive by setting the 'aa' flag
    return( $rcode, \@ans, \@auth, \@add, { aa => 1 } );
}

sub new {
    my ( $class, %params ) = @_;

    my $object = bless {}, $class;
    my $ns     = Net::DNS::Nameserver->new(
	LocalAddr    => $params{host} || 'localhost',
        LocalPort    => $params{port} || '5353',
        ReplyHandler => sub { __reply_handler( $object, @_ ) },
        Verbose      => 0,
    ) or die "could not create nameserver object\n";
 
    $object->{ns} = $ns;
    $object->{db} = $params{db};

    return $object;
}

sub run {
    my $self = shift;

    $self->{ns}->main_loop;
}

1;

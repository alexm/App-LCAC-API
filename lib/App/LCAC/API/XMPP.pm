use strict;
use warnings;
package App::LCAC::API::XMPP;
# ABSTRACT: Query LCAC databases via DNS

use AnyEvent                      qw();
use AnyEvent::XMPP::Client        qw();
use AnyEvent::XMPP::Ext::Disco    qw();
use AnyEvent::XMPP::Ext::Version  qw();
use AnyEvent::XMPP::Util          qw( bare_jid );
use AnyEvent::XMPP::Namespaces    qw( xmpp_ns );
use YAML::Any                     qw( LoadFile );
use Net::DNS::Resolver            qw();
use App::LCAC::API::DNS           qw();

use feature 'switch';

my %whitelist;
my $condvar;
my $dns;

sub setup_xmpp {
    my ($config) = @_;

    my %params = %{ $config->{'xmpp'} };

    my $disco   = AnyEvent::XMPP::Ext::Disco->new();
    my $version = AnyEvent::XMPP::Ext::Version->new();
    my $client  = AnyEvent::XMPP::Client->new(
        debug => $params{debug},
    );

    $client->add_extension($disco);
    $client->add_extension($version);
    $client->set_presence( undef, $params{presence}, 1 );
    $client->add_account(
        $params{jabber_id},
        $params{password},
        $params{server},
        $params{port},
        { old_style_ssl => $params{old_style_ssl} },
    );

    warn "connecting to $params{jabber_id}...\n";

    return $client;
}

sub setup_dns {
    my ($config) = @_;

    my %params = %{ $config->{dns} };

    my $resolver = Net::DNS::Resolver->new(
        nameservers => $params{nameservers},
        port        => $params{port},
        tcp_timeout => $params{timeout},
        udp_timeout => $params{timeout},
    );

    return $resolver;
}

sub handle_session_ready {
    my ( $client, $account ) = @_;
    warn "connected to ", $account->jid, "\n";
}

sub handle_contact_request_subscribe {
    my ( $client, $account, $roster, $contact ) = @_;

    $contact->send_subscribed;
    warn "subscribed to ", $contact->jid, "\n";
}

sub handle_error {
    my ( $client, $account, $error ) = @_;

    warn "error found: ", $error->string, "\n";
    $condvar->broadcast;
}

sub handle_disconnect {
    warn "got disconnected: [@_]\n";
    $condvar->broadcast;
}

sub send_reply {
    my ( $msg, $body ) = @_;

    my $reply = $msg->make_reply;
    $reply->add_body($body);
    $reply->send;
}

sub get_help {
    return <<HELP;
help  - display this help
hello - be polite
query - query a database
HELP
}

sub dispatch_body {
    my ( $msg, $body ) = @_;

    given($body) {
        when('help') {
            send_reply( $msg, get_help() );
        }
        when( /^hello\s+(?<name>.*)\s*$/i ) {
            send_reply( $msg, "nice to meet you, $+{'name'}!" );
	}
        when( /^query\s+(?<query>.*)\s*$/i ) {
            my $result = App::LCAC::API::DNS->query( $dns, $+{'query'} );
            send_reply( $msg, $result );
        }
        default {
            send_reply( $msg, "do not understand; try help" );
        }
    }
}

sub handle_message {
    my ( $client, $account, $msg ) = @_;

    my $body = $msg->body;
    return unless $body;

    my $from = bare_jid( $msg->from );
    warn "got message from $from\n";

    if ( !exists $whitelist{$from} ) {
        send_reply($msg, "do not know you!");
        return;
    }

    dispatch_body( $msg, $body );
}

sub run {
    shift;
    die "usage: $0 config.yaml\n" unless @_;

    my ($yaml) = @_;
    my $config = LoadFile($yaml);
    %whitelist = map { $_ => 1 } @{ $config->{'whitelist'} };

    my $client = setup_xmpp($config);
    $dns       = setup_dns($config);
    $condvar   = AnyEvent->condvar;

    $client->reg_cb(
        session_ready             => \&handle_session_ready,
        contact_request_subscribe => \&handle_contact_request_subscribe,
        error                     => \&handle_error,
        disconnect                => \&handle_disconnect,
        message                   => \&handle_message,
    );

    $client->start;
    $condvar->wait;
}

1;

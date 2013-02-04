use strict;
use warnings;
package App::LCAC::API::DBI;
# ABSTRACT: Query LCAC databases via DBI

=head1 SYNOPSIS

    use App::LCAC::API::DBI;
    my $dbh = App::LCAC::API::DBI->categorizer($db_dir);
    $dbh->prepare('SELECT * FROM site.categ');
    $dbh->execute();

=head1 DESCRIPTION

This module connects to LCAC databases through DBI so you can
perform SQL queries on them.

=cut

use DBI;
use File::Spec::Functions qw( catfile );

sub __connect {
    my %params = @_;

    my $dbh = DBI->connect('dbi:CSV:')
        or die "Cannot connect: $DBI::errstr\n";

    die "Hash ref tables is required as a param"
        unless ref $params{tables} eq 'HASH';

    $dbh->{csv_sep_char}           = $params{sep_char}           || ':';
    $dbh->{csv_allow_whitespace}   = $params{allow_whitespace}   || 1;
    $dbh->{csv_allow_loose_quotes} = $params{allow_loose_quotes} || 1;

    # DBI csv_tables is an interface that looks like a hash
    # but it does not work always as a hash, i.e. key values
    # must be copied one by one in order to work as expected.
    while ( (my $key, my $value) = each %{ $params{tables} } ) {
        $dbh->{csv_tables}{$key} = $value;
    }

    return $dbh;
}

=method categorizer( $db_dir )

Returns a new DBI handler to LCAC Categorizer database.

=cut

sub categorizer {
    my ( $class, $db_dir ) = @_;

    my %tables = (
        'site.categ' => {
            file      => catfile( $db_dir, 'site.categ' ),
            col_names => [qw( category members )],
        },
    );

    return __connect( tables => \%tables );
}

=method netdb( $db_dir )

Returns a new DBI handler to LCAC NetDB database.

=cut

sub netdb {
    my ( $class, $db_dir ) = @_;

    my %tables = (
        'Equipment'            => { col_names => [qw(
            Name
            Type
            Brand
            Model
            Monitor
            KeyboardType
            SerialNumber
            Description
            Comments
        )]},
        'Equipment.Admin'      => { col_names => [qw(
            Name
            EquipmentGroup
            Owner
            Admin
            UPCInventario
            BuyDate
            FechaFinGarantia
            FechaAlta
            NumeroPedido
        )]},
        'EquipmentGroup'       => { col_names => [qw(
            Name
            IPPool
        )]},
        'IPAddress'            => { col_names => [qw(
            IP
            Name
        )]},
        'IPName.Service'       => { col_names => [qw(
            Name
            Services
        )]},
        'IPPool'               => { col_names => [qw(
            Name
            IPList
        )]},
        'MAC-IP'               => { col_names => [qw(
            MAC
            IPorIPPool
        )]},
        'NAP'                  => { col_names => [qw(
            Building
            Name
            Room
            Workspace
            State
            Map
            MapLocation
            Tags
            Comments
        )]},
        'NAP-NIP'              => { col_names => [qw(
            Building
            Name
            EquipmentName
            EthName
        )]},
        'NIP'                  => { col_names => [qw(
            EquipmentName
            EthName
            SpeedMbps
            MAC
        )]},
        'VLAN'                 => { col_names => [qw(
            Number
            Name
            IPPool
        )]},
    );

    while ( (my $key, my $value) = each %tables ) {
        $tables{$key}{file} = catfile( $db_dir, $key );
    }

    return __connect( tables => \%tables );
}

1;

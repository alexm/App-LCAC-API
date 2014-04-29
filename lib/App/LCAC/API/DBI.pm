use strict;
use warnings;
package App::LCAC::API::DBI;
# ABSTRACT: Query LCAC databases via DBI

=head1 SYNOPSIS

    use YAML 'LoadFile';
    my $config = LoadFile('db.yml');
    use App::LCAC::API::DBI;
    my $dbh = App::LCAC::API::DBI->connect( db => $config->{dbname1} );
    my $query = $dbh->prepare('SELECT * FROM tablename1');
    $query->execute();

=head1 DESCRIPTION

This module connects to LCAC databases through DBI so you can
perform SQL queries on them.

=cut

use DBI;
use File::Spec::Functions qw( catfile );

=method connect( %params )

Returns a new DBI handler to a CSV database.

=head2 Params:

=over 4

=item * path

Path where the CSV tables should be found, defaults to current directory.

=item * db

Hash ref with CSV schema and configuration values for L<DBD::CSV>.

Examples of schemas in YAML:

    'dbname1':
      csv_sep_char: ':'
      csv_allow_whitespace: 1
      csv_allow_loose_quotes: 1
      csv_tables:
        'tablename1':
          col_names:
            - 'colname1'
            - 'colname2'
    'db2':
      csv_sep_char: ';'
      csv_tables:
        't1':
          col_names:
            - 'c1'
            - 'c2'

=cut

sub connect {
    my $class = shift;
    my %params = @_;
    $params{path} ||= '.';

    my $dbh = DBI->connect('dbi:CSV:')
        or die "Cannot connect: $DBI::errstr\n";

    die "Hash ref db is required as a param"
        unless ref $params{db} eq 'HASH';

    for my $p (keys %{ $params{db} }) {
        if ($p eq 'csv_tables') {
            # DBI csv_tables is an interface that looks like a hash
            # but it does not work always as a hash, i.e. key values
            # must be copied one by one in order to work as expected.
            while ( (my $key, my $value) = each %{ $params{db}{csv_tables} } ) {
                $dbh->{csv_tables}{$key} = $value;
                $dbh->{csv_tables}{$key}{file} = catfile( $params{path}, $key );
            }
        }
        else {
            $dbh->{$p} = $params{db}{$p};
        }
    }

    return $dbh;
}

1;

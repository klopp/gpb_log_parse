#!/usr/bin/perl

# ------------------------------------------------------------------------------
use Modern::Perl;

use Const::Fast;
use DBI;
use Email::Valid;
use Text::ParseWords;

const my $INTERNAL_ID_PLACEMENT => 0;
const my $FLAG_PLACEMENT        => 1;
const my $MESSAGE_FLAG          => q{<=};
const my $RX_DATE_TIME          => qr{^(\d{4}[-]\d\d[-]\d\d \d\d:\d\d:\d\d)};
const my $RX_INTERNAL_ID        => qr{^(\w{6}[-]\w{6}[-]\w\w)$};
const my $LOG_FILE              => q{out.log};

const my $DB_NAME     => 'test_base';
const my $DB_USER     => 'test_user';
const my $DB_PASSWORD => 'test_password';
const my $DB_HOST     => 'localhost';
const my $DB_PORT     => '3306';

my ( @table_message, @table_log );

# поля в таблицах:
const my @FIELDS_MESSAGE => ( 'address', 'created', 'id', 'int_id', 'str' );
const my @FIELDS_LOG => ( 'address', 'created', 'int_id', 'str' );

# сколько записей вставлять за один INSERT:
const my $INSERT_RECORDS => 256;

# ------------------------------------------------------------------------------
my $dbh = DBI->connect(
    'dbi:mysql:database=' . $DB_NAME . ';host=' . $DB_HOST . ';port=' . $DB_PORT,
    $DB_USER,
    $DB_PASSWORD,
    {   AutoCommit => 0,
        RaiseError => 1,
        PrintError => 1,
    }
);

open my $file, '<:raw', $LOG_FILE;
while (<$file>) {
    chomp;

    my $line = $_;
    next unless $line =~ /$RX_DATE_TIME/;
    my $created = $1;
    $line =~ s/$RX_DATE_TIME//;
    $line =~ s/^\s+|\s+$//g;

# чтобы не изобретать велосипед, и не спотыкаться на поисках id тупыми регекспами
# в подстроках вида C="250 OK id=1RwtK9-0004TB-Ub":
    my @parts = shellwords($line);
    next unless @parts;

    # формат internal ID не описан, но пусть будет так:
    next unless $parts[$INTERNAL_ID_PLACEMENT] =~ $RX_INTERNAL_ID;
    my $internal_id = $1;

    my ( $id, $address, $flag )
        = ( q{}, q{}, $parts[$FLAG_PLACEMENT] eq $MESSAGE_FLAG ? 1 : 0 );

    for my $part ( 2 .. $#{parts} ) {

        next unless $parts[$part];

# критерий определения адреса не описан, берём первый подходящий:
        if ( !$address ) {
                # из того, что встретилось, адрес может быть:
                # <address>
                # address:
            my $tmp = $parts[$part];
            $tmp =~ s/^<|[:>]$//g;
            if ( Email::Valid->address($tmp) ) {
                $address = $tmp;
                next;
            }
        }
        $id = $1 if $parts[$part] =~ /^id=(\S+)/;
    }

    if ($flag) {
        if ($id) {
            push @table_message, $address, $created, $id, $internal_id, $line;
        }
    }
    else {
        push @table_log, $address, $created, $internal_id, $line;
    }
}
write_table( 'message', \@table_message, \@FIELDS_MESSAGE );
write_table( 'log',     \@table_log,     \@FIELDS_LOG );

close $file;
$dbh->commit;
$dbh->disconnect;

# ------------------------------------------------------------------------------
sub write_table
{
    my ( $table, $data, $fields ) = @_;

    # а был бы DBD::Pg - можно было бы использовать pg_putcopydata...
    my $sql_base = "INSERT IGNORE INTO `$table` (`" . join( '`, `', @{$fields} ) . '`) VALUES(';

    while ( my @portion = splice @{$data}, 0, $INSERT_RECORDS * scalar @{$fields} ) {
        my $sql = $sql_base;
        for ( 1 .. ( scalar @portion / scalar @{$fields} ) ) {
            $sql .= join( ',', ('?') x scalar @{$fields} ) . '),(';
        }
        chop $sql;
        chop $sql;

        my $stmt = $dbh->prepare_cached($sql);
        $stmt->execute(@portion);
        $stmt->finish;
    }
}

# ------------------------------------------------------------------------------

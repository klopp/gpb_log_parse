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
my $message_stmt
                   # раз уж "CONSTRAINT message_id_pk PRIMARY KEY(id)", то нужно IGNORE:
    = $dbh->prepare(
    'INSERT IGNORE INTO `message` (`address`, `created`, `id`, `int_id`, `str`) VALUES (?, ?, ?, ?, ?)'
    );
my $log_stmt
    = $dbh->prepare(
    'INSERT INTO `log` (`address`, `created`, `int_id`, `str`) VALUES (?, ?, ?, ?)');

open my $file, '<:raw', $LOG_FILE;
while (<$file>) {
    chomp;

    my $line = $_;
    next unless $line =~ /^$RX_DATE_TIME/;
    my $created = $1;
    $line =~ s/^$RX_DATE_TIME//;
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
            $message_stmt->execute( $address, $created, $id, $internal_id, $line );
        }
    }
    else {
        $log_stmt->execute( $address, $created, $internal_id, $line );
    }
}
close $file;
undef $message_stmt;
undef $log_stmt;
$dbh->commit;
$dbh->disconnect;

# ------------------------------------------------------------------------------

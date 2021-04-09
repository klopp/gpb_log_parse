#!/usr/bin/perl

# ------------------------------------------------------------------------------
use Modern::Perl;

use CGI;
use CGI::Carp qw/fatalsToBrowser/;
use Const::Fast;
use DBI;

const my $DB_NAME       => 'test_base';
const my $DB_USER       => 'test_user';
const my $DB_PASSWORD   => 'test_password';
const my $DB_HOST       => 'localhost';
const my $DB_PORT       => '3306';
const my $RECORDS_LIMIT => 100;

const my $SELECT => q{
    (
        SELECT `int_id`, `created`, `str` FROM `log` WHERE `address` = ?
    )
            UNION
    (    
        SELECT `int_id`, `created`, `str` FROM `message` WHERE `address` = ?
    )
        ORDER BY `int_id`, `created`
};

# ------------------------------------------------------------------------------
my $cgi     = CGI->new;
my $address = $cgi->param('address') || '';
my $warning = "Only the first $RECORDS_LIMIT entries are shown!";
my $data    = [];
my $dbh     = DBI->connect(
    'dbi:mysql:database=' . $DB_NAME . ';host=' . $DB_HOST . ';port=' . $DB_PORT,
    $DB_USER,
    $DB_PASSWORD,
    {   AutoCommit => 0,
        RaiseError => 1,
        PrintError => 1,
    }
);

my $html = <<'HTML';
Content-Type: text/html

    <html>
        <head>
            <title>Log search</title>
        </head>
        <body>
            <form action="/cgi-bin/log_search.pl" method="get">
                <input name="address" type="text" value="__ADDRESS__"></input>
                <input type="submit" value="Go"></input>
            </form>
            __WARNING__
            <pre>
HTML

if ($address) {

# Лайфхак. Выбираем на одну запись больше чем $RECORDS_LIMIT.
# Если выбрано меньше - уложились в лимит, не выводим предупреждение.
    $data = $dbh->selectall_arrayref(
        $SELECT . ' LIMIT ' . ( $RECORDS_LIMIT + 1 ),
        { Slice => {} },
        $address, $address,
    );
}

$warning = '' if scalar @{$data} <= $RECORDS_LIMIT;
$html =~ s/__ADDRESS__/$address/sm;
$html =~ s/__WARNING__/$warning/sm;
say $html;

for ( 0 .. $RECORDS_LIMIT - 1 ) {
    next unless $data->[$_];
    say $data->[$_]->{created} . q { } . $data->[$_]->{str};
}

say '</pre></body></html>';

$dbh->disconnect;

# ------------------------------------------------------------------------------

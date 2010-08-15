# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3);

our $http_config = <<'_EOC_';
    upstream database {
        postgres_server     127.0.0.1:5432 dbname=ngx_test
                            user=ngx_test password=ngx_test;
    }
_EOC_

worker_connections(128);
run_tests();

no_diff();

__DATA__

=== TEST 1: sanity
--- http_config eval: $::http_config
--- config
    location /postgres {
        postgres_pass       database;
        set_form_input      $sql 'sql';
        set_unescape_uri    $sql;
        postgres_query      $sql;
    }
--- more_headers
Content-Type: application/x-www-form-urlencoded
--- request
POST /postgres
sql=select%20*%20from%20cats;
--- error_code: 200
--- response_headers
Content-Type: application/x-resty-dbd-stream
--- response_body eval
"\x{00}".        # endian
"\x{03}\x{00}\x{00}\x{00}".  # format version 0.0.3
"\x{00}".        # result type
"\x{00}\x{00}".  # std errcode
"\x{02}\x{00}".  # driver errcode
"\x{00}\x{00}".  # driver errstr len
"".              # driver errstr data
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}".  # rows affected
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}".  # insert id
"\x{02}\x{00}".  # col count
"\x{09}\x{00}".  # std col type (integer/int)
"\x{17}\x{00}".  # driver col type
"\x{02}\x{00}".  # col name len
"id".            # col name data
"\x{06}\x{80}".  # std col type (varchar/str)
"\x{19}\x{00}".  # driver col type
"\x{04}\x{00}".  # col name len
"name".          # col name data
"\x{01}".        # valid row flag
"\x{01}\x{00}\x{00}\x{00}".  # field len
"2".             # field data
"\x{ff}\x{ff}\x{ff}\x{ff}".  # field len
"".              # field data
"\x{01}".        # valid row flag
"\x{01}\x{00}\x{00}\x{00}".  # field len
"3".             # field data
"\x{03}\x{00}\x{00}\x{00}".  # field len
"bob".           # field data
"\x{00}"         # row list terminator
--- timeout: 10

# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3 - 4 * 2);

$ENV{TEST_NGINX_POSTGRESQL_PORT} ||= 5432;

our $http_config = <<'_EOC_';
    upstream database {
        postgres_server  127.0.0.1:$TEST_NGINX_POSTGRESQL_PORT
                         dbname=ngx_test user=ngx_test password=ngx_test;
    }
_EOC_

run_tests();

__DATA__

=== TEST 1: none - sanity
--- http_config eval: $::http_config
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "select 'test' as echo";
        postgres_output     none;
    }
--- request
GET /postgres
--- error_code: 200
--- response_headers
! Content-Type
--- response_body eval
""
--- timeout: 10



=== TEST 2: value - sanity
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select 'test', 'test' as echo";
        postgres_output     value 0 0;
    }
--- request
GET /postgres
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body chomp
test
--- timeout: 10



=== TEST 3: value - sanity (with different default_type)
--- http_config eval: $::http_config
--- config
    default_type  text/html;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select 'test', 'test' as echo";
        postgres_output     value 0 1;
    }
--- request
GET /postgres
--- error_code: 200
--- response_headers
Content-Type: text/html
--- response_body chomp
test
--- timeout: 10



=== TEST 4: value - value outside of the result-set
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select 'test' as echo";
        postgres_output     value 2 2;
    }
--- request
GET /postgres
--- error_code: 500
--- timeout: 10



=== TEST 5: value - NULL value
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select NULL as echo";
        postgres_output     value 0 0;
    }
--- request
GET /postgres
--- error_code: 500
--- timeout: 10



=== TEST 6: value - empty value
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select '' as echo";
        postgres_output     value 0 0;
    }
--- request
GET /postgres
--- error_code: 500
--- timeout: 10



=== TEST 7: row - sanity
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select 'a', 'b', 'c', 'd'";
        postgres_output     row 0;
    }
--- request
GET /postgres
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body eval
"a".
"\x{0a}".  # new line - delimiter
"b".
"\x{0a}".  # new line - delimiter
"c".
"\x{0a}".  # new line - delimiter
"d"
--- timeout: 10



=== TEST 8: rds - sanity (configured)
--- http_config eval: $::http_config
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "select 'default' as echo";
        postgres_output     rds;
    }
--- request
GET /postgres
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
"\x{01}\x{00}".  # col count
"\x{00}\x{80}".  # std col type (unknown/str)
"\x{c1}\x{02}".  # driver col type
"\x{04}\x{00}".  # col name len
"echo".          # col name data
"\x{01}".        # valid row flag
"\x{07}\x{00}\x{00}\x{00}".  # field len
"default".       # field data
"\x{00}"         # row list terminator
--- timeout: 10



=== TEST 9: rds - sanity (default)
--- http_config eval: $::http_config
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "select 'default' as echo";
    }
--- request
GET /postgres
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
"\x{01}\x{00}".  # col count
"\x{00}\x{80}".  # std col type (unknown/str)
"\x{c1}\x{02}".  # driver col type
"\x{04}\x{00}".  # col name len
"echo".          # col name data
"\x{01}".        # valid row flag
"\x{07}\x{00}\x{00}\x{00}".  # field len
"default".       # field data
"\x{00}"         # row list terminator
--- timeout: 10



=== TEST 10: inheritance
--- http_config eval: $::http_config
--- config
    default_type     text/plain;
    postgres_output  value 0 3;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select 'a', 'b', 'c', 'test' as echo";
    }
--- request
GET /postgres
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body chomp
test
--- timeout: 10



=== TEST 11: inheritance (mixed, don't inherit)
--- http_config eval: $::http_config
--- config
    postgres_output  row 0;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select 'test' as echo";
        postgres_output     none;
    }
--- request
GET /postgres
--- error_code: 200
--- response_headers
! Content-Type
--- response_body eval
""
--- timeout: 10



=== TEST 12: value - column by name (existing)
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select 'test' as echo";
        postgres_output     value 0 "echo";
    }
--- request
GET /postgres
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body chomp
test
--- timeout: 10



=== TEST 13: value - column by name (not existing)
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select 'test' as echo";
        postgres_output     value 0 "test";
    }
--- request
GET /postgres
--- error_code: 500
--- timeout: 10



=== TEST 14: value - sanity (request with known extension)
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select 'test', 'test' as echo";
        postgres_output     value 0 0;
    }
--- request
GET /postgres.jpg
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body chomp
test
--- timeout: 10



=== TEST 15: value - bytea returned in text format
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select E'\\001'::bytea as res";
        postgres_output     value 0 0;
    }
--- request
GET /postgres
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body chomp
\001
--- timeout: 10



=== TEST 16: binary value - bytea returned in binary format
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select E'\\001'::bytea as res";
        postgres_output     binary_value 0 0;
    }
--- request
GET /postgres
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body eval
"\1"
--- timeout: 10



=== TEST 17: binary value - int2 returned in binary format
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select 3::int2 as res";
        postgres_output     binary_value 0 0;
    }
--- request
GET /postgres
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body eval
"\0\3"
--- timeout: 10



=== TEST 18: value - "if" pseudo-location
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        if ($arg_foo) {
            postgres_pass       database;
            postgres_query      "select * from cats order by id";
            postgres_output     value 0 0;
            break;
        }

        return 404;
    }
--- request
GET /postgres?foo=1
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body chomp
2
--- timeout: 10

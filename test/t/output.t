# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3 - 3 * 2);

worker_connections(128);
run_tests();

no_diff();

__DATA__

=== TEST 1: none - sanity
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
--- response_body eval
"test"
--- timeout: 10



=== TEST 3: value - sanity (with different default_type)
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
--- response_body eval
"test"
--- timeout: 10



=== TEST 4: value - value outside of the result-set
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
--- response_body eval
"test"
--- timeout: 10



=== TEST 11: inheritance (mixed, don't inherit)
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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

# vi:filetype=

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5);

$ENV{TEST_NGINX_POSTGRESQL_HOST_IPV6} ||= '[::1]';
$ENV{TEST_NGINX_POSTGRESQL_PORT} ||= 5432;

our $http_config = <<'_EOC_';
    upstream database {
        postgres_server  $TEST_NGINX_POSTGRESQL_HOST_IPV6:$TEST_NGINX_POSTGRESQL_PORT
                         dbname=ngx_test user=ngx_test password=ngx_test;
    }
_EOC_

run_tests();

__DATA__

=== TEST 1: no keep-alive
--- http_config
    upstream database {
        postgres_server     $TEST_NGINX_POSTGRESQL_HOST_IPV6:$TEST_NGINX_POSTGRESQL_PORT
                            dbname=ngx_test user=ngx_test password=ngx_test;
        postgres_keepalive  off;
    }
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "select * from cats";
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
--- no_error_log
[alert]
[error]



=== TEST 2: keep-alive (single)
--- http_config
    upstream database {
        postgres_server     $TEST_NGINX_POSTGRESQL_HOST_IPV6:$TEST_NGINX_POSTGRESQL_PORT
                            dbname=ngx_test user=ngx_test password=ngx_test;
        postgres_keepalive max=10 mode=single;
    }
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "select * from cats";
    }

    location /t {
        echo_location /postgres;
        echo_location /postgres;
        echo_location /postgres;
    }
--- request
GET /t
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body eval
my $s="\x{00}".  # endian
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
"\x{00}";         # row list terminator
$s x 3;
--- timeout: 10
--- no_error_log
[alert]
[error]



=== TEST 3: keep-alive (multi)
--- http_config
    upstream database {
        postgres_server     $TEST_NGINX_POSTGRESQL_HOST_IPV6:$TEST_NGINX_POSTGRESQL_PORT
                            dbname=ngx_test user=ngx_test password=ngx_test;
        postgres_keepalive max=10 mode=multi;
    }
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "select * from cats";
    }

    location /t {
        echo_location /postgres;
        echo_location /postgres;
        echo_location /postgres;
    }
--- request
GET /t
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body eval
my $s="\x{00}".  # endian
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
"\x{00}";        # row list terminator
$s x 3;
--- timeout: 10
--- no_error_log
[alert]
[error]


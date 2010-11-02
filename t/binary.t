# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * blocks() * 3;

$ENV{TEST_NGINX_POSTGRESQL_PORT} ||= 5432;

our $http_config = <<'_EOC_';
    upstream database {
        postgres_server  127.0.0.1:$TEST_NGINX_POSTGRESQL_PORT
                         dbname=ngx_test user=ngx_test password=ngx_test;
    }
_EOC_

run_tests();

__DATA__

=== TEST 1: binary mode, default off
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select E'\\001'::bytea as res;";
        #postgres_binary_mode off;
        postgres_output     value 0 0;
    }
--- request
GET /postgres.jpg
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body chomp
\001
--- timeout: 10



=== TEST 2: binary mode, explicit off
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select E'\\001'::bytea as res;";
        postgres_binary_mode off;
        postgres_output     value 0 0;
    }
--- request
GET /postgres.jpg
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body chomp
\001
--- timeout: 10



=== TEST 3: binary mode, on
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select E'\\001'::bytea as res;";
        postgres_binary_mode on;
        postgres_output     value 0 0;
    }
--- request
GET /postgres.jpg
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body eval
"\1"
--- timeout: 10



=== TEST 4: binary mode, on
--- http_config eval: $::http_config
--- config
    default_type  text/plain;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select 3::int2 as res;";
        postgres_binary_mode on;
        postgres_output     value 0 0;
    }
--- request
GET /postgres.jpg
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body eval
"\0\3"
--- timeout: 10


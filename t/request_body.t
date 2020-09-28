# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

plan tests => repeat_each() * (2 + 2 + 1);

$ENV{TEST_NGINX_POSTGRESQL_HOST} ||= '127.0.0.1';
$ENV{TEST_NGINX_POSTGRESQL_PORT} ||= 5432;

our $http_config = <<'_EOC_';
    upstream database {
        postgres_server  $TEST_NGINX_POSTGRESQL_HOST:$TEST_NGINX_POSTGRESQL_PORT
                         dbname=ngx_test user=ngx_test password=ngx_test;
    }
_EOC_

no_shuffle();
run_tests();

__DATA__

=== TEST 1: capture request body
--- http_config eval: $::http_config
--- config
    location /test {
        postgres_pass                database;
        postgres_query               POST "SELECT '$request_body'";
        postgres_output              value;
    }
--- request eval
"POST /test
{ test: \"My simple request\" }"
--- error_code: 200
--- response_body eval
"{ test: \"My simple request\" }"
--- timeout: 10



=== TEST 2: escape request body
--- http_config eval: $::http_config
--- config
    location /test {
        postgres_pass                database;
        postgres_query               POST "SELECT '$request_body'";
        postgres_output              value;
    }
--- request eval
"POST /test
'; SQL injection attempt;"
--- error_code: 200
--- response_body eval
"'; SQL injection attempt;"
--- timeout: 10



=== TEST 3: escape request body disabled
--- http_config eval: $::http_config
--- config
    location /test {
        postgres_escape_request_body off;
        postgres_pass                database;
        postgres_query               POST "SELECT '$request_body'";
        postgres_output              value;
    }
--- request eval
"POST /test
'; SQL injection attempt;--"
--- error_code: 500
--- timeout: 10


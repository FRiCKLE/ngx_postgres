# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 2);

$ENV{TEST_NGINX_POSTGRESQL_PORT} ||= 5432;

our $http_config = <<'_EOC_';
    upstream database {
        postgres_server  127.0.0.1:$TEST_NGINX_POSTGRESQL_PORT
                         dbname=ngx_test user=ngx_test password=ngx_test;
    }
_EOC_

run_tests();

__DATA__

=== TEST 1: no changes (SELECT)
--- http_config eval: $::http_config
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "select * from cats";
        postgres_rewrite    no_changes 500;
        postgres_rewrite    changes 500;
    }
--- request
GET /postgres
--- error_code: 200
--- response_headers
Content-Type: application/x-resty-dbd-stream
--- timeout: 10



=== TEST 2: no changes (UPDATE)
--- http_config eval: $::http_config
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "update cats set id=3 where name='noone'";
        postgres_rewrite    no_changes 206;
        postgres_rewrite    changes 500;
    }
--- request
GET /postgres
--- error_code: 206
--- response_headers
Content-Type: application/x-resty-dbd-stream
--- timeout: 10



=== TEST 3: one change
--- http_config eval: $::http_config
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "update cats set id=3 where name='bob'";
        postgres_rewrite    no_changes 500;
        postgres_rewrite    changes 206;
    }
--- request
GET /postgres
--- error_code: 206
--- response_headers
Content-Type: application/x-resty-dbd-stream
--- timeout: 10



=== TEST 4: rows
--- http_config eval: $::http_config
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "select * from cats";
        postgres_rewrite    no_changes 500;
        postgres_rewrite    changes 500;
        postgres_rewrite    no_rows 410;
        postgres_rewrite    rows 206;
    }
--- request
GET /postgres
--- error_code: 206
--- response_headers
Content-Type: application/x-resty-dbd-stream
--- timeout: 10



=== TEST 5: no rows
--- http_config eval: $::http_config
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "select * from cats where name='noone'";
        postgres_rewrite    no_changes 500;
        postgres_rewrite    changes 500;
        postgres_rewrite    no_rows 410;
        postgres_rewrite    rows 206;
    }
--- request
GET /postgres
--- error_code: 410
--- response_headers
Content-Type: text/html
--- timeout: 10



=== TEST 6: inheritance
--- http_config eval: $::http_config
--- config
    postgres_rewrite  no_changes 500;
    postgres_rewrite  changes 500;
    postgres_rewrite  no_rows 410;
    postgres_rewrite  rows 206;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select * from cats";
    }
--- request
GET /postgres
--- error_code: 206
--- response_headers
Content-Type: application/x-resty-dbd-stream
--- timeout: 10



=== TEST 7: inheritance (mixed, don't inherit)
--- http_config eval: $::http_config
--- config
    postgres_rewrite  no_changes 500;
    postgres_rewrite  changes 500;
    postgres_rewrite  no_rows 410;
    postgres_rewrite  rows 206;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select * from cats";
        postgres_rewrite    rows 206;
    }
--- request
GET /postgres
--- error_code: 206
--- response_headers
Content-Type: application/x-resty-dbd-stream
--- timeout: 10



=== TEST 8: rows (method-specific)
--- http_config eval: $::http_config
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "select * from cats";
        postgres_rewrite    no_changes 500;
        postgres_rewrite    changes 500;
        postgres_rewrite    no_rows 410;
        postgres_rewrite    POST PUT rows 201;
        postgres_rewrite    HEAD GET rows 206;
        postgres_rewrite    rows 206;
    }
--- request
GET /postgres
--- error_code: 206
--- response_headers
Content-Type: application/x-resty-dbd-stream
--- timeout: 10



=== TEST 9: rows (default)
--- http_config eval: $::http_config
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "select * from cats";
        postgres_rewrite    no_changes 500;
        postgres_rewrite    changes 500;
        postgres_rewrite    no_rows 410;
        postgres_rewrite    POST PUT rows 201;
        postgres_rewrite    rows 206;
    }
--- request
GET /postgres
--- error_code: 206
--- response_headers
Content-Type: application/x-resty-dbd-stream
--- timeout: 10



=== TEST 10: rows (none)
--- http_config eval: $::http_config
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "select * from cats";
        postgres_rewrite    no_changes 500;
        postgres_rewrite    changes 500;
        postgres_rewrite    no_rows 410;
        postgres_rewrite    POST PUT rows 201;
    }
--- request
GET /postgres
--- error_code: 200
--- response_headers
Content-Type: application/x-resty-dbd-stream
--- timeout: 10



=== TEST 11: no changes (UPDATE) with 202 response
--- http_config eval: $::http_config
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "update cats set id=3 where name='noone'";
        postgres_rewrite    no_changes 202;
        postgres_rewrite    changes 500;
    }
--- request
GET /postgres
--- error_code: 202
--- response_headers
Content-Type: application/x-resty-dbd-stream
--- timeout: 10
--- skip_nginx: 2: < 0.8.41

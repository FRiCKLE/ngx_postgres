# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(1);

plan tests => repeat_each() * (blocks() * 3);

# db init:
# create table numbers (number integer);
# create table users (login text, pass text);
# insert into users (login, pass) values ('monty', 'some_pass');

our $http_config = <<'_EOC_';
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
_EOC_

our $config = <<'_EOC_';
    set $random  123;

    location = /auth {
        internal;

        set_quote_sql_str   $user $remote_user;
        set_quote_sql_str   $pass $remote_passwd;

        postgres_pass       database;
        postgres_query      "SELECT login FROM users WHERE login=$user AND pass=$pass";
        postgres_rewrite    no_rows 403;
        postgres_output     none;
    }

    location = /numbers/ {
        auth_request        /auth;
        postgres_pass       database;
        rds_json            on;

        postgres_query      HEAD GET  "SELECT * FROM numbers";

        postgres_query      POST      "INSERT INTO numbers VALUES('$random') RETURNING *";
        postgres_rewrite    POST      changes 201;

        postgres_query      DELETE    "DELETE FROM numbers";
        postgres_rewrite    DELETE    no_changes 204;
        postgres_rewrite    DELETE    changes 204;
    }

    location ~ /numbers/(?<num>\d+) {
        auth_request        /auth;
        postgres_pass       database;
        rds_json            on;

        postgres_query      HEAD GET  "SELECT * FROM numbers WHERE number='$num'";
        postgres_rewrite    HEAD GET  no_rows 410;

        postgres_query      PUT       "UPDATE numbers SET number='$num' WHERE number='$num' RETURNING *";
        postgres_rewrite    PUT       no_changes 410;

        postgres_query      DELETE    "DELETE FROM numbers WHERE number='$num'";
        postgres_rewrite    DELETE    no_changes 410;
        postgres_rewrite    DELETE    changes 204;
    }
_EOC_

worker_connections(128);
no_shuffle();
run_tests();

no_diff();

__DATA__

=== TEST 1: clean collection
--- http_config eval: $::http_config
--- config eval: $::config
--- more_headers
Authorization: Basic bW9udHk6c29tZV9wYXNz
--- request
DELETE /numbers/
--- error_code: 204
--- response_headers
! Content-Type
--- response_body eval
""
--- timeout: 10



=== TEST 2: list empty collection
--- http_config eval: $::http_config
--- config eval: $::config
--- more_headers
Authorization: Basic bW9udHk6c29tZV9wYXNz
--- request
GET /numbers/
--- error_code: 200
--- response_headers
Content-Type: application/json
--- response_body chop
[]
--- timeout: 10



=== TEST 3: insert resource into collection
--- http_config eval: $::http_config
--- config eval: $::config
--- more_headers
Authorization: Basic bW9udHk6c29tZV9wYXNz
--- request
POST /numbers/
--- error_code: 201
--- response_headers
Content-Type: application/json
--- response_body chop
[{"number":123}]
--- timeout: 10



=== TEST 4: list collection
--- http_config eval: $::http_config
--- config eval: $::config
--- more_headers
Authorization: Basic bW9udHk6c29tZV9wYXNz
--- request
GET /numbers/
--- error_code: 200
--- response_headers
Content-Type: application/json
--- response_body chop
[{"number":123}]
--- timeout: 10



=== TEST 5: get resource
--- http_config eval: $::http_config
--- config eval: $::config
--- more_headers
Authorization: Basic bW9udHk6c29tZV9wYXNz
--- request
GET /numbers/123
--- error_code: 200
--- response_headers
Content-Type: application/json
--- response_body chop
[{"number":123}]
--- timeout: 10



=== TEST 6: update resource
--- http_config eval: $::http_config
--- config eval: $::config
--- more_headers
Authorization: Basic bW9udHk6c29tZV9wYXNz
Content-Length: 0
--- request
PUT /numbers/123
--- error_code: 200
--- response_headers
Content-Type: application/json
--- response_body chop
[{"number":123}]
--- timeout: 10



=== TEST 7: remove resource
--- http_config eval: $::http_config
--- config eval: $::config
--- more_headers
Authorization: Basic bW9udHk6c29tZV9wYXNz
--- request
DELETE /numbers/123
--- error_code: 204
--- response_headers
! Content-Type
--- response_body eval
""
--- timeout: 10



=== TEST 8: update non-existing resource
--- http_config eval: $::http_config
--- config eval: $::config
--- more_headers
Authorization: Basic bW9udHk6c29tZV9wYXNz
Content-Length: 0
--- request
PUT /numbers/123
--- error_code: 410
--- response_headers
Content-Type: text/html
--- response_body_like: 410 Gone
--- timeout: 10



=== TEST 9: get non-existing resource
--- http_config eval: $::http_config
--- config eval: $::config
--- more_headers
Authorization: Basic bW9udHk6c29tZV9wYXNz
--- request
GET /numbers/123
--- error_code: 410
--- response_headers
Content-Type: text/html
--- response_body_like: 410 Gone
--- timeout: 10



=== TEST 10: remove non-existing resource
--- http_config eval: $::http_config
--- config eval: $::config
--- more_headers
Authorization: Basic bW9udHk6c29tZV9wYXNz
--- request
DELETE /numbers/123
--- error_code: 410
--- response_headers
Content-Type: text/html
--- response_body_like: 410 Gone
--- timeout: 10



=== TEST 11: list empty collection (done)
--- http_config eval: $::http_config
--- config eval: $::config
--- more_headers
Authorization: Basic bW9udHk6c29tZV9wYXNz
--- request
GET /numbers/
--- error_code: 200
--- response_headers
Content-Type: application/json
--- response_body chop
[]
--- timeout: 10

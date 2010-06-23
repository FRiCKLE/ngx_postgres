# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3 - 2 * 1);

worker_connections(128);
run_tests();

no_diff();

__DATA__

=== TEST 1: authorized (auth basic)
db init:

create table users (login text, pass text);
insert into users (login, pass) values ('monty', 'some_pass');

--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
--- config
    location = /auth {
        internal;
        set_quote_sql_str   $user $remote_user;
        set_quote_sql_str   $pass $remote_passwd;
        postgres_pass       database;
        postgres_query      "select login from users where login=$user and pass=$pass";
        postgres_rewrite    no_rows 403;
        postgres_set        $login 0 0 required;
        postgres_output     none;
    }

    location /test {
        auth_request        /auth;
        auth_request_set    $auth_user $login;
        echo -n             "hi, $auth_user!";
    }
--- more_headers
Authorization: Basic bW9udHk6c29tZV9wYXNz
--- request
GET /test
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body eval
"hi, monty!"
--- timeout: 10



=== TEST 2: unauthorized (auth basic)
db init:

create table users (login text, pass text);
insert into users (login, pass) values ('monty', 'some_pass');

--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
--- config
    location = /auth {
        internal;
        set_quote_sql_str   $user $remote_user;
        set_quote_sql_str   $pass $remote_passwd;
        postgres_pass       database;
        postgres_query      "select login from users where login=$user and pass=$pass";
        postgres_rewrite    no_rows 403;
        postgres_set        $login 0 0 required;
        postgres_output     none;
    }

    location /test {
        auth_request        /auth;
        auth_request_set    $auth_user $login;
        echo -n             "hi, $auth_user!";
    }
--- more_headers
Authorization: Basic bW9udHk6cGFzcw==
--- request
GET /test
--- error_code: 403
--- response_headers
Content-Type: text/html
--- timeout: 10



=== TEST 3: unauthorized (no authorization header)
db init:

create table users (login text, pass text);
insert into users (login, pass) values ('monty', 'some_pass');

--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
--- config
    location = /auth {
        internal;
        set_quote_sql_str   $user $remote_user;
        set_quote_sql_str   $pass $remote_passwd;
        postgres_pass       database;
        postgres_query      "select login from users where login=$user and pass=$pass";
        postgres_rewrite    no_rows 403;
        postgres_set        $login 0 0 required;
        postgres_output     none;
    }

    location /test {
        auth_request        /auth;
        auth_request_set    $auth_user $login;
        echo -n             "hi, $auth_user!";
    }
--- request
GET /test
--- error_code: 403
--- response_headers
Content-Type: text/html
--- timeout: 10

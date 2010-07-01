# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 2);

worker_connections(128);
run_tests();

no_diff();

__DATA__

=== TEST 1: no changes (SELECT)
db init:

create table cats (id integer, name text);
insert into cats (id) values (2);
insert into cats (id, name) values (3, 'bob');
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
db init:

create table cats (id integer, name text);
insert into cats (id) values (2);
insert into cats (id, name) values (3, 'bob');
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
db init:

create table cats (id integer, name text);
insert into cats (id) values (2);
insert into cats (id, name) values (3, 'bob');
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
db init:

create table cats (id integer, name text);
insert into cats (id) values (2);
insert into cats (id, name) values (3, 'bob');
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
db init:

create table cats (id integer, name text);
insert into cats (id) values (2);
insert into cats (id, name) values (3, 'bob');
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
db init:

create table cats (id integer, name text);
insert into cats (id) values (2);
insert into cats (id, name) values (3, 'bob');
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
db init:

create table cats (id integer, name text);
insert into cats (id) values (2);
insert into cats (id, name) values (3, 'bob');
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
db init:

create table cats (id integer, name text);
insert into cats (id) values (2);
insert into cats (id, name) values (3, 'bob');
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
db init:

create table cats (id integer, name text);
insert into cats (id) values (2);
insert into cats (id, name) values (3, 'bob');
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
db init:

create table cats (id integer, name text);
insert into cats (id) values (2);
insert into cats (id, name) values (3, 'bob');
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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
db init:

create table cats (id integer, name text);
insert into cats (id) values (2);
insert into cats (id, name) values (3, 'bob');
--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
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

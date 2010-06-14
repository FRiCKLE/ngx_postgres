# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3 - 3 * 2);

worker_connections(128);
run_tests();

no_diff();

__DATA__

=== TEST 1: sanity
little-endian systems only

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
        postgres_query      "select * from cats where name='bob'";
        postgres_get_value  0 1;
    }
--- request
GET /postgres
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body eval
"bob"
--- timeout: 10



=== TEST 2: sanity (with different default_type)
little-endian systems only

db init:

create table cats (id integer, name text);
insert into cats (id) values (2);
insert into cats (id, name) values (3, 'bob');

--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
--- config
    default_type  text/html;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select * from cats where name='bob'";
        postgres_get_value  0 1;
    }
--- request
GET /postgres
--- error_code: 200
--- response_headers
Content-Type: text/html
--- response_body eval
"bob"
--- timeout: 10



=== TEST 3: value outside of the result-set
little-endian systems only

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
        postgres_query      "select * from cats where name='bob'";
        postgres_get_value  2 2;
    }
--- request
GET /postgres
--- error_code: 500
--- timeout: 10



=== TEST 4: NULL value
little-endian systems only

db init:

create table cats (id integer, name text);
insert into cats (id) values (2);
insert into cats (id, name) values (3, 'bob');

--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
--- config
    default_type  text/html;

    location /postgres {
        postgres_pass       database;
        postgres_query      "select * from cats where id='2'";
        postgres_get_value  0 1;
    }
--- request
GET /postgres
--- error_code: 500
--- timeout: 10



=== TEST 5: empty value
little-endian systems only

--- http_config
    upstream database {
        postgres_server     127.0.0.1 dbname=test user=monty password=some_pass;
    }
--- config
    location /postgres {
        postgres_pass       database;
        postgres_query      "select '' as echo";
        postgres_get_value  0 0;
    }
--- request
GET /postgres
--- error_code: 500
--- timeout: 10

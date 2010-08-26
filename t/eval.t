# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3);

$ENV{TEST_NGINX_POSTGRESQL_PORT} ||= 5432;

our $http_config = <<'_EOC_';
    upstream database {
        postgres_server  127.0.0.1:$TEST_NGINX_POSTGRESQL_PORT
                         dbname=ngx_test user=ngx_test password=ngx_test;
    }
_EOC_

worker_connections(128);
run_tests();

no_diff();

__DATA__

=== TEST 1: sanity
--- http_config
    upstream database {
        postgres_server     127.0.0.1:$TEST_NGINX_POSTGRESQL_PORT
                            dbname=ngx_test user=ngx_test password=ngx_test;
    }

    server {
        listen  8100;

        location / {
           echo -n  "it works!";
        }
    }
--- config
    location /eval {
        eval_subrequest_in_memory  off;

        eval $backend {
            postgres_pass    database;
            postgres_query   "select 'http://127.0.0.1:8100'";
            postgres_output  value 0 0;
        }

        proxy_pass $backend;
    }
--- request
GET /eval
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body eval
"it works!"
--- timeout: 10
--- skip_nginx2: 3: < 0.8.25 or >= 0.8.42



=== TEST 2: sanity (simple case)
--- http_config eval: $::http_config
--- config
    location /eval {
        eval_subrequest_in_memory  off;

        eval $echo {
            postgres_pass    database;
            postgres_query   "select 'test' as echo";
            postgres_output  value 0 0;
        }

        echo -n  $echo;
    }
--- request
GET /eval
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body eval
"test"
--- timeout: 10
--- skip_nginx: 3: >= 0.8.42

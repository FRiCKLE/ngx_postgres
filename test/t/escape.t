# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3);

worker_connections(128);
run_tests();

no_diff();

__DATA__

=== TEST 1: '
--- http_config eval: $::http_config
--- config
    location /test {
        set                 $test "he'llo";
        postgres_escape     $escaped $test;
        echo                $escaped;
    }
--- request
GET /test
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body
'he''llo'
--- timeout: 10



=== TEST 2: \
--- http_config eval: $::http_config
--- config
    location /test {
        set                 $test "he\\llo";
        postgres_escape     $escaped $test;
        echo                $escaped;
    }
--- request
GET /test
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body
'he\\llo'
--- timeout: 10



=== TEST 3: \'
--- http_config eval: $::http_config
--- config
    location /test {
        set                 $test "he\\'llo";
        postgres_escape     $escaped $test;
        echo                $escaped;
    }
--- request
GET /test
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body
'he\\''llo'
--- timeout: 10



=== TEST 4: NULL
--- http_config eval: $::http_config
--- config
    location /test {
        postgres_escape     $escaped $remote_user;
        echo                $escaped;
    }
--- request
GET /test
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body
NULL
--- timeout: 10

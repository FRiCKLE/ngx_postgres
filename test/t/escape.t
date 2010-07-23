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



=== TEST 5: empty sting
--- config
    location /test {
        set $empty          "";
        postgres_escape     $escaped $empty;
        echo                $escaped;
    }
--- request
GET /test
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body
''
--- timeout: 10



=== TEST 6: UTF-8
--- config
    location /test {
        set $utf8           "你好";
        postgres_escape     $escaped $utf8;
        echo                $escaped;
    }
--- request
GET /test
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body
'你好'
--- timeout: 10

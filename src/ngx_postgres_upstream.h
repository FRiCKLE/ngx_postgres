/*
 * Copyright (c) 2010, FRiCKLE Piotr Sikora <info@frickle.com>
 * Copyright (c) 2009-2010, Xiaozhe Wang <chaoslawful@gmail.com>
 * Copyright (c) 2009-2010, Yichun Zhang <agentzh@gmail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _NGX_HTTP_UPSTREAM_POSTGRES_H_
#define _NGX_HTTP_UPSTREAM_POSTGRES_H_

#include <nginx.h>
#include <ngx_core.h>
#include <ngx_http.h>
#include <libpq-fe.h>


typedef enum {
    state_db_connect,
    state_db_send_query,
    state_db_get_result,
    state_db_get_ack,
    state_db_idle
} ngx_postgres_state_t;

typedef enum {
    postgres_keepalive_overflow_ignore = 0,
    postgres_keepalive_overflow_reject
} ngx_postgres_keepalive_overflow_t;

typedef struct {
    /* simple values */
    ngx_str_t                  query;
    ngx_http_upstream_conf_t   upstream;
    /* complex values */
    ngx_http_complex_value_t  *query_cv;
    ngx_http_complex_value_t  *upstream_cv;
} ngx_postgres_loc_conf_t;

typedef struct {
#if defined(nginx_version) && (nginx_version >= 8022)
    ngx_addr_t       *addrs;
#else
    ngx_peer_addr_t  *addrs;
#endif
    ngx_uint_t        naddrs;
    in_port_t         port;
    ngx_str_t         dbname;
    ngx_str_t         user;
    ngx_str_t         password;
} ngx_postgres_upstream_server_t;

typedef struct {
    struct sockaddr  *sockaddr;
    socklen_t         socklen;
    ngx_str_t         name;
    ngx_str_t         host;
    in_port_t         port;
    ngx_str_t         dbname;
    ngx_str_t         user;
    ngx_str_t         password;
} ngx_postgres_upstream_peer_t;

typedef struct {
    ngx_uint_t                     single;
    ngx_uint_t                     number;
    ngx_str_t                     *name;
    ngx_postgres_upstream_peer_t   peer[1];
} ngx_postgres_upstream_peers_t;

typedef struct {
    ngx_postgres_upstream_peers_t      *peers;
    ngx_uint_t                          current;
    /* of ngx_postgres_upstream_server_t */
    ngx_array_t                        *servers;
    ngx_pool_t                         *pool;
    /* keepalive related fields */
    ngx_flag_t                          single;
    ngx_queue_t                         free;
    ngx_queue_t                         cache;
    ngx_uint_t                          active_conns;
    ngx_uint_t                          max_cached;
    ngx_postgres_keepalive_overflow_t   overflow;
} ngx_postgres_upstream_srv_conf_t;

typedef struct {
    ngx_postgres_upstream_srv_conf_t  *srv_conf;
    ngx_postgres_loc_conf_t           *loc_conf;
    ngx_http_upstream_t               *upstream;
    ngx_http_request_t                *request;
    PGconn                            *pgconn;
    ngx_postgres_state_t               state;
    ngx_str_t                          query;
    ngx_str_t                         *name;
    ngx_flag_t                         failed;
} ngx_postgres_upstream_peer_data_t;


ngx_int_t   ngx_postgres_upstream_init(ngx_conf_t *,
                ngx_http_upstream_srv_conf_t *);
ngx_int_t   ngx_postgres_upstream_init_peer(ngx_http_request_t *,
                ngx_http_upstream_srv_conf_t *);
ngx_int_t   ngx_postgres_upstream_get_peer(ngx_peer_connection_t *, void *);
void        ngx_postgres_upstream_free_peer(ngx_peer_connection_t *, void *,
                ngx_uint_t);
ngx_flag_t  ngx_postgres_upstream_is_my_peer(const ngx_peer_connection_t *);
void        ngx_postgres_upstream_free_connection(ngx_log_t *,
                ngx_connection_t *, PGconn *,
                ngx_postgres_upstream_srv_conf_t *);

#endif /* _NGX_HTTP_UPSTREAM_POSTGRES_H_ */

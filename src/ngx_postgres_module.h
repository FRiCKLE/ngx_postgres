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

#ifndef _NGX_POSTGRES_MODULE_H_
#define _NGX_POSTGRES_MODULE_H_

#include <nginx.h>
#include <ngx_core.h>
#include <ngx_http.h>


extern ngx_module_t  ngx_postgres_module;


typedef enum {
    postgres_keepalive_overflow_ignore = 0,
    postgres_keepalive_overflow_reject
} ngx_postgres_keepalive_overflow_t;

typedef struct {
    ngx_uint_t                          key;
    ngx_str_t                           sv;
    ngx_http_complex_value_t           *cv;
} ngx_postgres_mixed_t;

typedef struct {
    ngx_int_t                           row;
    ngx_int_t                           column;
    ngx_uint_t                          required;
} ngx_postgres_value_t;

typedef struct {
    ngx_uint_t                          idx;
    ngx_http_variable_t                *var;
    ngx_postgres_value_t                value;
} ngx_postgres_variable_t;

typedef struct {
#if defined(nginx_version) && (nginx_version >= 8022)
    ngx_addr_t                         *addrs;
#else
    ngx_peer_addr_t                    *addrs;
#endif
    ngx_uint_t                          naddrs;
    in_port_t                           port;
    ngx_str_t                           dbname;
    ngx_str_t                           user;
    ngx_str_t                           password;
} ngx_postgres_upstream_server_t;

typedef struct {
    struct sockaddr                    *sockaddr;
    socklen_t                           socklen;
    ngx_str_t                           name;
    ngx_str_t                           host;
    in_port_t                           port;
    ngx_str_t                           dbname;
    ngx_str_t                           user;
    ngx_str_t                           password;
} ngx_postgres_upstream_peer_t;

typedef struct {
    ngx_uint_t                          single;
    ngx_uint_t                          number;
    ngx_str_t                          *name;
    ngx_postgres_upstream_peer_t        peer[1];
} ngx_postgres_upstream_peers_t;

typedef struct {
    ngx_postgres_upstream_peers_t      *peers;
    ngx_uint_t                          current;
    ngx_array_t                        *servers;
    ngx_pool_t                         *pool;
    /* keepalive */
    ngx_flag_t                          single;
    ngx_queue_t                         free;
    ngx_queue_t                         cache;
    ngx_uint_t                          active_conns;
    ngx_uint_t                          max_cached;
    ngx_postgres_keepalive_overflow_t   overflow;
} ngx_postgres_upstream_srv_conf_t;

typedef struct {
    /* upstream */
    ngx_http_upstream_conf_t            upstream;
    ngx_http_complex_value_t           *upstream_cv;
    /* queries */
    ngx_postgres_mixed_t               *default_query;
    ngx_uint_t                          methods_set;
    ngx_array_t                        *queries;
    /* get_value */
    ngx_int_t                           get_value[2];
    /* custom variables */
    ngx_array_t                        *variables;
} ngx_postgres_loc_conf_t;

typedef struct {
    u_char                             *name;
    uint32_t                            key;
} ngx_postgres_http_method_t;

typedef struct {
    ngx_chain_t                        *response;
    ngx_int_t                           var_cols;
    ngx_int_t                           var_rows;
    ngx_str_t                           var_value;
    ngx_array_t                        *variables;
} ngx_postgres_ctx_t;


#define NGX_POSTGRES_OUTPUT_NONE   0
#define NGX_POSTGRES_OUTPUT_VALUE  1
#define NGX_POSTGRES_OUTPUT_ROW    2
#define NGX_POSTGRES_OUTPUT_RDS    3

#define NGX_POSTGRES_OPTIONAL      0
#define NGX_POSTGRES_REQUIRED      1


ngx_int_t   ngx_postgres_add_variables(ngx_conf_t *);
void       *ngx_postgres_create_upstream_srv_conf(ngx_conf_t *);
void       *ngx_postgres_create_loc_conf(ngx_conf_t *);
char       *ngx_postgres_merge_loc_conf(ngx_conf_t *, void *, void *);
char       *ngx_postgres_conf_server(ngx_conf_t *, ngx_command_t *, void *);
char       *ngx_postgres_conf_keepalive(ngx_conf_t *, ngx_command_t *, void *);
char       *ngx_postgres_conf_pass(ngx_conf_t *, ngx_command_t *, void *);
char       *ngx_postgres_conf_query(ngx_conf_t *, ngx_command_t *, void *);
char       *ngx_postgres_conf_get_value(ngx_conf_t *, ngx_command_t *, void *);
char       *ngx_postgres_conf_set(ngx_conf_t *, ngx_command_t *, void *);

ngx_http_upstream_srv_conf_t  *ngx_postgres_find_upstream(ngx_http_request_t *,
                                   ngx_url_t *);

#endif /* _NGX_POSTGRES_MODULE_H_ */

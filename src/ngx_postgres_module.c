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

#define DDEBUG 0
#include "ngx_postgres_ddebug.h"
#include "ngx_postgres_handler.h"
#include "ngx_postgres_keepalive.h"
#include "ngx_postgres_module.h"
#include "ngx_postgres_upstream.h"
#include "ngx_postgres_util.h"


static ngx_command_t ngx_postgres_module_commands[] = {

    { ngx_string("postgres_server"),
      NGX_HTTP_UPS_CONF|NGX_CONF_1MORE,
      ngx_postgres_conf_server,
      NGX_HTTP_SRV_CONF_OFFSET,
      0,
      NULL },

    { ngx_string("postgres_keepalive"),
      NGX_HTTP_UPS_CONF|NGX_CONF_1MORE,
      ngx_postgres_conf_keepalive,
      NGX_HTTP_SRV_CONF_OFFSET,
      0,
      NULL },

    { ngx_string("postgres_pass"),
      NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_postgres_conf_pass,
      NGX_HTTP_LOC_CONF_OFFSET,
      0,
      NULL },

    { ngx_string("postgres_query"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_1MORE,
      ngx_postgres_conf_query,
      NGX_HTTP_LOC_CONF_OFFSET,
      0,
      NULL },

    { ngx_string("postgres_get_value"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE2,
      ngx_postgres_conf_get_value,
      NGX_HTTP_LOC_CONF_OFFSET,
      0,
      NULL },

    { ngx_string("postgres_connect_timeout"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_msec_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_postgres_loc_conf_t, upstream.connect_timeout),
      NULL },

    { ngx_string("postgres_result_timeout"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_msec_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_postgres_loc_conf_t, upstream.read_timeout),
      NULL },

      ngx_null_command
};

static ngx_http_module_t ngx_postgres_module_ctx = {
    NULL,                                   /* preconfiguration */
    NULL,                                   /* postconfiguration */

    NULL,                                   /* create main configuration */
    NULL,                                   /* init main configuration */

    ngx_postgres_upstream_create_srv_conf,  /* create server configuration */
    NULL,                                   /* merge server configuration */

    ngx_postgres_create_loc_conf,           /* create location configuration */
    ngx_postgres_merge_loc_conf             /* merge location configuration */
};

ngx_module_t ngx_postgres_module = {
    NGX_MODULE_V1,
    &ngx_postgres_module_ctx,      /* module context */
    ngx_postgres_module_commands,  /* module directives */
    NGX_HTTP_MODULE,               /* module type */
    NULL,                          /* init master */
    NULL,                          /* init module */
    NULL,                          /* init process */
    NULL,                          /* init thread */
    NULL,                          /* exit thread */
    NULL,                          /* exit process */
    NULL,                          /* exit master */
    NGX_MODULE_V1_PADDING
};

ngx_postgres_http_method_t ngx_postgres_http_methods[] = {
   { (u_char *) "GET",       (uint32_t) NGX_HTTP_GET },
   { (u_char *) "HEAD",      (uint32_t) NGX_HTTP_HEAD },
   { (u_char *) "POST",      (uint32_t) NGX_HTTP_POST },
   { (u_char *) "PUT",       (uint32_t) NGX_HTTP_PUT },
   { (u_char *) "DELETE",    (uint32_t) NGX_HTTP_DELETE },
   { (u_char *) "MKCOL",     (uint32_t) NGX_HTTP_MKCOL },
   { (u_char *) "COPY",      (uint32_t) NGX_HTTP_COPY },
   { (u_char *) "MOVE",      (uint32_t) NGX_HTTP_MOVE },
   { (u_char *) "OPTIONS",   (uint32_t) NGX_HTTP_OPTIONS },
   { (u_char *) "PROPFIND" , (uint32_t) NGX_HTTP_PROPFIND },
   { (u_char *) "PROPPATCH", (uint32_t) NGX_HTTP_PROPPATCH },
   { (u_char *) "LOCK",      (uint32_t) NGX_HTTP_LOCK },
   { (u_char *) "UNLOCK",    (uint32_t) NGX_HTTP_UNLOCK },
#if defined(nginx_version) && (nginx_version >= 8041)
   { (u_char *) "PATCH",     (uint32_t) NGX_HTTP_PATCH },
#endif
   { NULL, 0 }
};


void *
ngx_postgres_upstream_create_srv_conf(ngx_conf_t *cf)
{
    ngx_postgres_upstream_srv_conf_t  *conf;
    ngx_pool_cleanup_t                *cln;

    dd("entering");

    conf = ngx_pcalloc(cf->pool, sizeof(ngx_postgres_upstream_srv_conf_t));
    if (conf == NULL) {
        dd("returning NULL");
        return NULL;
    }

    /* set by ngx_pcalloc:
     *     conf->peers = NULL
     *     conf->current = 0
     *     conf->servers = NULL
     *     conf->free = { NULL, NULL }
     *     conf->cache = { NULL, NULL }
     *     conf->active_conns = 0
     *     conf->overflow = 0 (postgres_keepalive_overflow_ignore)
     */

    conf->pool = cf->pool;

    /* enable keepalive (single) by default */
    conf->max_cached = 10;
    conf->single = 1;

    cln = ngx_pool_cleanup_add(cf->pool, 0);
    cln->handler = ngx_postgres_keepalive_cleanup;
    cln->data = conf;

    dd("returning");
    return conf;
}

void *
ngx_postgres_create_loc_conf(ngx_conf_t *cf)
{
    ngx_postgres_loc_conf_t  *conf;

    dd("entering");

    conf = ngx_pcalloc(cf->pool, sizeof(ngx_postgres_loc_conf_t));
    if (conf == NULL) {
        dd("returning NULL");
        return NULL;
    }

    /* set by ngx_pcalloc:
     *     conf->upstream.* = 0 / NULL
     *     conf->upstream_cv = NULL
     *     conf->default_query = NULL
     *     conf->methods_set = 0
     *     conf->queries = NULL
     */

    conf->upstream.connect_timeout = NGX_CONF_UNSET_MSEC;
    conf->upstream.read_timeout = NGX_CONF_UNSET_MSEC;

    conf->get_value[0] = NGX_CONF_UNSET;
    conf->get_value[1] = NGX_CONF_UNSET;

    /* the hardcoded values */
    conf->upstream.cyclic_temp_file = 0;
    conf->upstream.buffering = 1;
    conf->upstream.ignore_client_abort = 1;
    conf->upstream.send_lowat = 0;
    conf->upstream.bufs.num = 0;
    conf->upstream.busy_buffers_size = 0;
    conf->upstream.max_temp_file_size = 0;
    conf->upstream.temp_file_write_size = 0;
    conf->upstream.intercept_errors = 1;
    conf->upstream.intercept_404 = 1;
    conf->upstream.pass_request_headers = 0;
    conf->upstream.pass_request_body = 0;

    dd("returning");
    return conf;
}

char *
ngx_postgres_merge_loc_conf(ngx_conf_t *cf, void *parent, void *child)
{
    ngx_postgres_loc_conf_t  *prev = parent;
    ngx_postgres_loc_conf_t  *conf = child;

    dd("entering");

    ngx_conf_merge_msec_value(conf->upstream.connect_timeout,
                              prev->upstream.connect_timeout, 10000);

    ngx_conf_merge_msec_value(conf->upstream.read_timeout,
                              prev->upstream.read_timeout, 30000);

    if ((conf->upstream.upstream == NULL) && (conf->upstream_cv == NULL)) {
        conf->upstream.upstream = prev->upstream.upstream;
        conf->upstream_cv = prev->upstream_cv;
    }

    if ((conf->default_query == NULL) && (conf->queries == NULL)) {
        conf->default_query = prev->default_query;
        conf->methods_set = prev->methods_set;
        conf->queries = prev->queries;
    }

    if (conf->get_value[0] == NGX_CONF_UNSET) {
        conf->get_value[0] = prev->get_value[0];
    }

    if (conf->get_value[1] == NGX_CONF_UNSET) {
        conf->get_value[1] = prev->get_value[1];
    }

    dd("returning NGX_CONF_OK");
    return NGX_CONF_OK;
}

/*
 * Based on: ngx_http_upstream.c/ngx_http_upstream_server
 * Copyright (C) Igor Sysoev
 */
char *
ngx_postgres_conf_server(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_str_t                         *value = cf->args->elts;
    ngx_postgres_upstream_srv_conf_t  *pgscf = conf;
    ngx_postgres_upstream_server_t    *pgs;
    ngx_http_upstream_srv_conf_t      *uscf;
    ngx_url_t                          u;
    ngx_uint_t                         i;

    dd("entering");

    uscf = ngx_http_conf_get_module_srv_conf(cf, ngx_http_upstream_module);

    if (pgscf->servers == NULL) {
        pgscf->servers = ngx_array_create(cf->pool, 4,
                             sizeof(ngx_postgres_upstream_server_t));
        if (pgscf->servers == NULL) {
            dd("returning NGX_CONF_ERROR");
            return NGX_CONF_ERROR;
        }

        uscf->servers = pgscf->servers;
    }

    pgs = ngx_array_push(pgscf->servers);
    if (pgs == NULL) {
        dd("returning NGX_CONF_ERROR");
        return NGX_CONF_ERROR;
    }

    ngx_memzero(pgs, sizeof(ngx_postgres_upstream_server_t));

    /* parse the first name:port argument */

    ngx_memzero(&u, sizeof(ngx_url_t));

    u.url = value[1];
    u.default_port = 5432; /* PostgreSQL default */

    if (ngx_parse_url(cf->pool, &u) != NGX_OK) {
        if (u.err) {
            ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                               "postgres: %s in upstream \"%V\"",
                               u.err, &u.url);
        }

        dd("returning NGX_CONF_ERROR");
        return NGX_CONF_ERROR;
    }

    pgs->addrs = u.addrs;
    pgs->naddrs = u.naddrs;
    pgs->port = u.port;

    /* parse various options */
    for (i = 2; i < cf->args->nelts; i++) {

        if (ngx_strncmp(value[i].data, "dbname=", sizeof("dbname=") - 1)
                == 0)
        {
            pgs->dbname.len = value[i].len - (sizeof("dbname=") - 1);
            pgs->dbname.data = &value[i].data[sizeof("dbname=") - 1];
            continue;
        }

        if (ngx_strncmp(value[i].data, "user=", sizeof("user=") - 1)
                == 0)
        {
            pgs->user.len = value[i].len - (sizeof("user=") - 1);
            pgs->user.data = &value[i].data[sizeof("user=") - 1];
            continue;
        }

        if (ngx_strncmp(value[i].data, "password=", sizeof("password=") - 1)
                == 0)
        {
            pgs->password.len = value[i].len - (sizeof("password=") - 1);
            pgs->password.data = &value[i].data[sizeof("password=") - 1];
            continue;
        }

        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                           "postgres: invalid parameter \"%V\" in"
                           " \"postgres_server\"", &value[i]);

        dd("returning NGX_CONF_ERROR");
        return NGX_CONF_ERROR;
    }

    uscf->peer.init_upstream = ngx_postgres_upstream_init;

    dd("returning NGX_CONF_OK");
    return NGX_CONF_OK;
}

char *
ngx_postgres_conf_keepalive(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_str_t                         *value = cf->args->elts;
    ngx_postgres_upstream_srv_conf_t  *pgscf = conf;
    ngx_uint_t                         i;
    ngx_int_t                          n;
    u_char                            *data;
    ngx_uint_t                         len;

    dd("entering");

    if (pgscf->max_cached != 10 /* default */) {
        dd("returning");
        return "is duplicate";
    }

    if ((cf->args->nelts == 2) && (ngx_strcmp(value[1].data, "off") == 0)) {
        pgscf->max_cached = 0;

        dd("returning NGX_CONF_OK");
        return NGX_CONF_OK;
    }

    for (i = 1; i < cf->args->nelts; i++) {

        if (ngx_strncmp(value[i].data, "max=", sizeof("max=") - 1)
                == 0)
        {
            len = value[i].len - (sizeof("max=") - 1);
            data = &value[i].data[sizeof("max=") - 1];

            n = ngx_atoi(data, len);

            if (n == NGX_ERROR || n < 0) {
                ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                                   "postgres: invalid \"max\" value \"%V\""
                                   " in \"%V\" directive",
                                   &value[i], &cmd->name);

                dd("returning NGX_CONF_ERROR");
                return NGX_CONF_ERROR;
            }

            pgscf->max_cached = n;

            continue;
        }

        if (ngx_strncmp(value[i].data, "mode=", sizeof("mode=") - 1)
                == 0)
        {
            len = value[i].len - (sizeof("mode=") - 1);
            data = &value[i].data[sizeof("mode=") - 1];

            switch (len) {
            case 6:
                if (ngx_str6cmp(data, 's', 'i', 'n', 'g', 'l', 'e')) {
                    pgscf->single = 1;
                }
                break;

            case 5:
                if (ngx_str5cmp(data, 'm', 'u', 'l', 't', 'i')) {
                    pgscf->single = 0;
                }
                break;

            default:
                ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                                   "postgres: invalid \"mode\" value \"%V\""
                                   " in \"%V\" directive",
                                   &value[i], &cmd->name);

                dd("returning NGX_CONF_ERROR");
                return NGX_CONF_ERROR;
            }

            continue;
        }

        if (ngx_strncmp(value[i].data, "overflow=", sizeof("overflow=") - 1)
                == 0)
        {
            len = value[i].len - (sizeof("overflow=") - 1);
            data = &value[i].data[sizeof("overflow=") - 1];

            switch (len) {
            case 6:
                if (ngx_str6cmp(data, 'r', 'e', 'j', 'e', 'c', 't')) {
                    pgscf->overflow = postgres_keepalive_overflow_reject;
                } else if (ngx_str6cmp(data, 'i', 'g', 'n', 'o', 'r', 'e')) {
                    pgscf->overflow = postgres_keepalive_overflow_ignore;
                }
                break;

            default:
                ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                                   "postgres: invalid \"overflow\" value \"%V\""
                                   " in \"%V\" directive",
                                   &value[i], &cmd->name);

                dd("returning NGX_CONF_ERROR");
                return NGX_CONF_ERROR;
            }

            continue;
        }

        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                           "postgres: invalid parameter \"%V\" in"
                           " \"%V\" directive",
                           &value[i], &cmd->name);

        dd("returning NGX_CONF_ERROR");
        return NGX_CONF_ERROR;
    }

    dd("returning NGX_CONF_OK");
    return NGX_CONF_OK;
}

char *
ngx_postgres_conf_pass(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_str_t                         *value = cf->args->elts;
    ngx_postgres_loc_conf_t           *pglcf = conf;
    ngx_http_core_loc_conf_t          *clcf;
    ngx_http_compile_complex_value_t   ccv;
    ngx_url_t                          url;

    dd("entering");

    if ((pglcf->upstream.upstream != NULL) || (pglcf->upstream_cv != NULL)) {
        dd("returning");
        return "is duplicate";
    }

    if (value[1].len == 0) {
        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                           "postgres: empty value in \"%V\" directive",
                           &cmd->name);

        dd("returning NGX_CONF_ERROR");
        return NGX_CONF_ERROR;
    }

    clcf = ngx_http_conf_get_module_loc_conf(cf, ngx_http_core_module);

    clcf->handler = ngx_postgres_handler;

    if (clcf->name.data[clcf->name.len - 1] == '/') {
        clcf->auto_redirect = 1;
    }

    if (ngx_http_script_variables_count(&value[1])) {
        /* complex value */
        dd("complex value");

        pglcf->upstream_cv = ngx_palloc(cf->pool,
                                        sizeof(ngx_http_complex_value_t));
        if (pglcf->upstream_cv == NULL) {
            dd("returning NGX_CONF_ERROR");
            return NGX_CONF_ERROR;
        }

        ngx_memzero(&ccv, sizeof(ngx_http_compile_complex_value_t));

        ccv.cf = cf;
        ccv.value = &value[1];
        ccv.complex_value = pglcf->upstream_cv;

        if (ngx_http_compile_complex_value(&ccv) != NGX_OK) {
            dd("returning NGX_CONF_ERROR");
            return NGX_CONF_ERROR;
        }

        dd("returning NGX_CONF_OK");
        return NGX_CONF_OK;
    } else {
        /* simple value */
        dd("simple value");

        ngx_memzero(&url, sizeof(ngx_url_t));

        url.url = value[1];
        url.no_resolve = 1;

        pglcf->upstream.upstream = ngx_http_upstream_add(cf, &url, 0);
        if (pglcf->upstream.upstream == NULL) {
            dd("returning NGX_CONF_ERROR");
            return NGX_CONF_ERROR;
        }

        dd("returning NGX_CONF_OK");
        return NGX_CONF_OK;
    }
}

char *
ngx_postgres_conf_query(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_str_t                         *value = cf->args->elts;
    ngx_str_t                          sql = value[cf->args->nelts - 1];
    ngx_postgres_loc_conf_t           *pglcf = conf;
    ngx_http_compile_complex_value_t   ccv;
    ngx_postgres_mixed_t              *query;
    ngx_postgres_http_method_t        *method;
    ngx_uint_t                         methods, i;

    dd("entering");

    if (sql.len == 0) {
        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                           "postgres: empty value in \"%V\" directive",
                           &cmd->name);

        dd("returning NGX_CONF_ERROR");
        return NGX_CONF_ERROR;
    }

    if (cf->args->nelts == 2) {
        /* default query */
        dd("default query");

        if (pglcf->default_query != NULL) {
            dd("returning");
            return "is duplicate";
        }

        pglcf->default_query = ngx_pcalloc(cf->pool,
                                           sizeof(ngx_postgres_mixed_t));
        if (pglcf->default_query == NULL) {
            dd("returning NGX_CONF_ERROR");
            return NGX_CONF_ERROR;
        }

        methods = 0xFFFF;
        query = pglcf->default_query;
    } else {
        /* method-specific query */
        dd("method-specific query");

        methods = 0;

        for (i = 1; i < cf->args->nelts - 1; i++) {
            for (method = ngx_postgres_http_methods; method->name; method++) {
                if (ngx_strcasecmp(value[i].data, method->name) == 0) {
                    /* correct method name */
                    if (pglcf->methods_set & method->key) {
                        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                                           "postgres: \"%V\" directive"
                                           " for method \"%V\" is duplicate",
                                           &cmd->name, &value[i]);

                        dd("returning NGX_CONF_ERROR");
                        return NGX_CONF_ERROR;
                    }

                    methods |= method->key;
                    goto next;
                }
            }

            ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                               "postgres: invalid method \"%V\"", &value[i]);

            dd("returning NGX_CONF_ERROR");
            return NGX_CONF_ERROR;

next:
            continue;
        }

        if (pglcf->queries == NULL) {
            pglcf->queries = ngx_array_create(cf->pool, 4,
                                              sizeof(ngx_postgres_mixed_t));
            if (pglcf->queries == NULL) {
                dd("returning NGX_CONF_ERROR");
                return NGX_CONF_ERROR;
            }
        }

        query = ngx_array_push(pglcf->queries);
        if (query == NULL) {
            dd("returning NGX_CONF_ERROR");
            return NGX_CONF_ERROR;
        }

        pglcf->methods_set |= methods;
    }

    if (ngx_http_script_variables_count(&sql)) {
        /* complex value */
        dd("complex value");

        query->key = methods;

        query->cv = ngx_palloc(cf->pool, sizeof(ngx_http_complex_value_t));
        if (query->cv == NULL) {
            dd("returning NGX_CONF_ERROR");
            return NGX_CONF_ERROR;
        }

        ngx_memzero(&ccv, sizeof(ngx_http_compile_complex_value_t));

        ccv.cf = cf;
        ccv.value = &sql;
        ccv.complex_value = query->cv;

        if (ngx_http_compile_complex_value(&ccv) != NGX_OK) {
            dd("returning NGX_CONF_ERROR");
            return NGX_CONF_ERROR;
        }
    } else {
        /* simple value */
        dd("simple value");

        query->key = methods;
        query->sv = sql;
    }

    dd("returning NGX_CONF_OK");
    return NGX_CONF_OK;
}

char *
ngx_postgres_conf_get_value(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_str_t                         *value = cf->args->elts;
    ngx_postgres_loc_conf_t           *pglcf = conf;

    dd("entering");

    if (pglcf->get_value[0] != NGX_CONF_UNSET) {
        dd("returning");
        return "is duplicate";
    }

    pglcf->get_value[0] = ngx_atoi(value[1].data, value[1].len);
    if (pglcf->get_value[0] < 0) {
        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                           "postgres: invalid row number \"%V\""
                           " in \"postgres_get_value\"", &value[1]);

        dd("returning NGX_CONF_ERROR");
        return NGX_CONF_ERROR;
    }

    pglcf->get_value[1] = ngx_atoi(value[2].data, value[2].len);
    if (pglcf->get_value[1] < 0) {
        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                           "postgres: invalid column number \"%V\""
                           " in \"postgres_get_value\"", &value[2]);

        dd("returning NGX_CONF_ERROR");
        return NGX_CONF_ERROR;
    }

    dd("returning NGX_CONF_OK");
    return NGX_CONF_OK;
}

ngx_http_upstream_srv_conf_t *
ngx_postgres_find_upstream(ngx_http_request_t *r, ngx_url_t *url)
{
    ngx_http_upstream_main_conf_t   *umcf;
    ngx_http_upstream_srv_conf_t   **uscfp;
    ngx_uint_t                       i;

    dd("entering");

    umcf = ngx_http_get_module_main_conf(r, ngx_http_upstream_module);

    uscfp = umcf->upstreams.elts;

    for (i = 0; i < umcf->upstreams.nelts; i++) {

        if ((uscfp[i]->host.len != url->host.len)
            || (ngx_strncasecmp(uscfp[i]->host.data, url->host.data,
                                url->host.len) != 0))
        {
            dd("host doesn't match");
            continue;
        }

        if (uscfp[i]->port != url->port) {
            dd("port doesn't match: %d != %d",
               (int) uscfp[i]->port, (int) url->port);
            continue;
        }

        if (uscfp[i]->default_port && url->default_port
            && (uscfp[i]->default_port != url->default_port))
        {
            dd("default_port doesn't match");
            continue;
        }

        dd("returning");
        return uscfp[i];
    }

    dd("returning NULL");
    return NULL;
}

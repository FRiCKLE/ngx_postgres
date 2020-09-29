/*
 * Copyright (c) 2010, FRiCKLE Piotr Sikora <info@frickle.com>
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

#ifndef DDEBUG
#define DDEBUG 0
#endif

#include "ngx_postgres_ddebug.h"
#include "ngx_postgres_escape.h"
#include "ngx_postgres_module.h"
#include "ngx_postgres_util.h"

#include <libpq-fe.h>

#define SINGLE_QUOTE_CHAR 39 /* ASCII code of Apostrophe = 39 */
uintptr_t ngx_postgres_script_exit_code = (uintptr_t) NULL;


void
ngx_postgres_escape_string(ngx_http_script_engine_t *e)
{
    ngx_postgres_escape_t      *pge;
    ngx_http_variable_value_t  *v;
    u_char                     *p, *s;

    v = e->sp - 1;

    dd("entering: \"%.*s\"", (int) v->len, v->data);

    pge = (ngx_postgres_escape_t *) e->ip;
    e->ip += sizeof(ngx_postgres_escape_t);

    if ((v == NULL) || (v->not_found)) {
        v->data = (u_char *) "NULL";
        v->len = sizeof("NULL") - 1;
        dd("returning (NULL)");
        goto done;
    }

    if (v->len == 0) {
        if (pge->empty) {
            v->data = (u_char *) "''";
            v->len = 2;
            dd("returning (empty/empty)");
            goto done;
        } else {
            v->data = (u_char *) "NULL";
            v->len = sizeof("NULL") - 1;
            dd("returning (empty/NULL)");
            goto done;
        }
    }

    s = p = ngx_pnalloc(e->request->pool, 2 * v->len + 2);
    if (p == NULL) {
        e->ip = (u_char *) &ngx_postgres_script_exit_code;
        e->status = NGX_HTTP_INTERNAL_SERVER_ERROR;
        dd("returning (NGX_HTTP_INTERNAL_SERVER_ERROR)");
        return;
    }

    *p++ = '\'';
    v->len = PQescapeString((char *) p, (const char *) v->data, v->len);
    p[v->len] = '\'';
    v->len += 2;
    v->data = s;

    dd("returning");

done:

    v->valid = 1;
    v->no_cacheable = 0;
    v->not_found = 0;
}


/* Purpose: calculate new length (with doubled quotes) for variable value.
 * This method returns number of the single qoute characters (apostrophes)
 * plus original length of text value */
size_t
ngx_postgres_upstream_var_len_with_quotes(ngx_http_script_engine_t *e)
{
    size_t                        i;
    size_t                        result;
    size_t                        count;
    ngx_http_script_var_code_t   *code;
    ngx_http_variable_value_t    *value;
    ngx_http_core_main_conf_t    *cmcf;
    ngx_http_variable_t          *v;
    ngx_http_request_t           *r;

    dd("entering");
    result = 0;
    count = 0;

    if ((e != NULL) && (e->ip != NULL) && (e->request != NULL)) {
        code = (ngx_http_script_var_code_t *) e->ip;
        e->ip += sizeof(ngx_http_script_var_code_t);

        if (!e->skip) {
            if (e->flushed) {
                value = ngx_http_get_indexed_variable(e->request, code->index);

            } else {
                value = ngx_http_get_flushed_variable(e->request, code->index);
            }

            if ((value != NULL) && (!value->not_found)) {
                r = e->request;
                cmcf = ngx_http_get_module_main_conf(r, ngx_http_core_module);
                v = cmcf->variables.elts;

                if (v[code->index].get_handler ==
                        (ngx_http_get_variable_pt)ngx_postgres_rewrite_var) {
                    /* Quotes already escaped. Do nothing. */
                    return value->len;
                }

                for (i = 0; i < value->len; i++) {
                    if (value->data[i] == SINGLE_QUOTE_CHAR) {
                        count++;
                    }
                }

                result = value->len + count;
                ngx_log_debug1(NGX_LOG_DEBUG_HTTP, e->request->connection->log,
                    0, "http script: postgres: count to replace = %d", count);
            }
        }
    }
    dd("returning");

    return result;
}


/* Purpose: replace quotes in variable values before substitute them in a query
 * This method doubles the single qoute character (example: Can't -> Can''t) */
void
ngx_postgres_upstream_replace_quotes(ngx_http_script_engine_t *e)
{
    int                           i;
    int                           k;
    u_char                       *p;
    u_char                       *data;
    ngx_http_script_var_code_t   *code;
    ngx_http_variable_value_t    *value;
    ngx_http_core_main_conf_t    *cmcf;
    ngx_http_variable_t          *v;
    ngx_http_request_t           *r;

    dd("entering");

    if ((e != NULL) && (e->ip != NULL) && (e->request != NULL)) {
        code = (ngx_http_script_var_code_t *) e->ip;

        e->ip += sizeof(ngx_http_script_var_code_t);

        if (!e->skip) {
            if (e->flushed) {
                value = ngx_http_get_indexed_variable(e->request, code->index);

            } else {
                value = ngx_http_get_flushed_variable(e->request, code->index);
            }

            if ((value != NULL) && (!value->not_found)
                                && (e->buf.data != NULL)) {
                p = e->pos;
                data = value->data;

                r = e->request;
                cmcf = ngx_http_get_module_main_conf(r, ngx_http_core_module);
                v = cmcf->variables.elts;

                if (v[code->index].get_handler ==
                        (ngx_http_get_variable_pt) ngx_postgres_rewrite_var) {
                    /* Quotes already escaped. Do nothing. */
                    return;
                }

                ngx_log_debug2(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                    "http script: postgres: replace quotes in $%V (\"%v\")",
                    &v[code->index].name, value);

                /* copy var value like ngx_http_script_copy_var_code(e) does */
                for (i = 0, k = 0; i < value->len; i++, k++) {
                    /* doubles all the qoute characters,
                     * do not double backslashes */
                    if (data[i] == SINGLE_QUOTE_CHAR) {
                        p[k] = data[i];
                        k++;
                    }

                    p[k] = data[i];
                }

                e->pos += k;
            }
        }
    }

    dd("returning");
}


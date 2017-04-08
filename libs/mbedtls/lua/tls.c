/*
 *  Copyright (C) 2016 Masatoshi Teruya
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a
 *  copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation
 *  the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 *  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 *
 *  src/tls.c
 *  lua-mbedtls
 *  Created by Masatoshi Teruya on 16/05/22.
 */


#include "lmbedtls.h"


static int tls_tostring( lua_State *L )
{
    TOSTRING_MT( L, LMBEDTLS_TLS_MT );
    return 1;
}

static int tls_gc( lua_State *L )
{
    lmbedtls_tls_t *tls = lua_touserdata( L, 1 );

    return 0;
}


static int tls_new( lua_State *L )
{
    size_t len = 0;
    lmbedtls_tls_t *tls = lua_newuserdata( L, sizeof( lmbedtls_tls_t ) );
    int rc = 0;
    lmbedtls_errbuf_t errstr;

    if ( !tls ) {
        lua_pushnil( L );
        lua_pushstring( L, strerror( errno ) );
        return 2;
    }

    if ( rc == 0 ) {
        lauxh_setmetatable( L, LMBEDTLS_TLS_MT );
        return 1;
    }

    // got error
    mbedtls_ctr_drbg_free( &rng->drbg );
    mbedtls_entropy_free( &rng->entropy );
    lmbedtls_strerror( rc, errstr );
    lua_pushnil( L );
    lua_pushstring( L, errstr );

    return 2;
}


LUALIB_API int luaopen_lmbedtls_tls( lua_State *L )
{
    struct luaL_Reg rng_mmethods[] = {
        { "__gc",       tls_gc },
        { "__tostring", tls_tostring },
        { NULL, NULL }
    };

    struct luaL_Reg rng_methods[] = {

        { NULL, NULL }
    };

    // register metatable
    lmbedtls_newmetatable( L, LMBEDTLS_TLS_MT, tls_mmethods, tls_methods );

    // create table
    lua_newtable( L );

    // add new function
    lauxh_pushfn2tbl( L, "new", tls_new );

    //lauxh_pushint2tbl(L, "MAX_SEED_INPUT", MBEDTLS_CTR_DRBG_MAX_SEED_INPUT);


    return 1;
}


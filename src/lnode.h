/*
 *  Copyright 2015 The Luvit Authors. All Rights Reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */
#ifndef _LNODE_H
#define _LNODE_H

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#include "uv.h"
#include "luv.h"

#include <string.h>
#include <stdlib.h>

#ifdef _WIN32
#include <winsock2.h>
#include <windows.h>
#else
#include <unistd.h>
#include <errno.h>
#endif // _WIN32

#define WITH_MINIZ 1
#define WITH_CJSON 1
#define WITH_LUTILS 1

#ifdef WITH_CJSON
LUALIB_API int luaopen_cjson(lua_State * const L);
#endif

#ifdef WITH_LPEG
LUALIB_API int luaopen_lpeg(lua_State* L);
#endif

#ifdef WITH_LUTILS
LUALIB_API int luaopen_lutils(lua_State * const L);
LUALIB_API int luaopen_env(lua_State * const L);
#endif

#ifdef WITH_MINIZ
#include "lminiz.h"
LUALIB_API int luaopen_miniz(lua_State * const L);
#endif

#ifdef WITH_OPENSSL
#include "openssl.h"
#endif

#ifdef WITH_PCRE
#include "pcre.h"
LUALIB_API int luaopen_rex_pcre(lua_State* L);
#endif

#ifdef WITH_WINSVC
#include "winsvc.h"
#include "winsvcaux.h"
#endif

#ifdef WITH_ZLIB
#include "zlib.h"
LUALIB_API int luaopen_zlib(lua_State * const L);
#endif

LUALIB_API int lnode_init(lua_State* L);
LUALIB_API int lnode_load_script(lua_State* L, char* filename, int argc, char* argv[], int offset);
LUALIB_API int lnode_openlibs(lua_State* L);
LUALIB_API int lnode_run_as_deamon();

#endif // _LNODE_H

/*
 *  Copyright 2014 The Luvit Authors. All Rights Reserved.
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

#include "lnode.h"

LUALIB_API int luaopen_lnode(lua_State *L) 
{
#if defined(WITH_OPENSSL) || defined(WITH_PCRE)
  char buffer[1024];
#endif

  lua_newtable(L);
#ifdef LUVI_VERSION
  lua_pushstring(L, ""LUVI_VERSION"");
  lua_setfield(L, -2, "version");
#endif

  lua_newtable(L);
#ifdef WITH_OPENSSL
  snprintf(buffer, sizeof(buffer), "%s, lua-openssl %s",
    SSLeay_version(SSLEAY_VERSION), LOPENSSL_VERSION);
  lua_pushstring(L, buffer);
  lua_setfield(L, -2, "ssl");
#endif

#ifdef WITH_PCRE
  lua_pushstring(L, pcre_version());
  lua_setfield(L, -2, "rex");
#endif

#ifdef WITH_ZLIB
  lua_pushstring(L, zlibVersion());
  lua_setfield(L, -2, "zlib");
#endif

#ifdef WITH_WINSVC
  lua_pushboolean(L, 1);
  lua_setfield(L, -2, "winsvc");
#endif

  lua_pushstring(L, uv_version_string());
  lua_setfield(L, -2, "libuv");
  
  lua_setfield(L, -2, "options");
  return 1;
}

LUALIB_API int lnode_init(lua_State* L) {
  char script[] = "pcall(require, 'init')\n";

  // Load the init.lua script
  if (luaL_loadstring(L, script)) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return -1;
  }

  // Start the main script.
  if (lua_pcall(L, 0, 1, 0)) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return -1;
  }

  return 0;
}

LUALIB_API int lnode_openlibs(lua_State* L) {
  // Get package.preload so we can store builtins in it.
  lua_getglobal(L, "package");
  lua_getfield(L, -1, "preload");
  lua_remove(L, -2); // Remove package

#ifdef WITH_CJSON
  lua_pushcfunction(L, luaopen_cjson);
  lua_setfield(L, -2, "cjson");
#endif

  lua_pushcfunction(L, luaopen_env);
  lua_setfield(L, -2, "env");

  // Store lnode module definition at preload.lnode
  lua_pushcfunction(L, luaopen_lnode);
  lua_setfield(L, -2, "lnode");

#ifdef WITH_LPEG
  lua_pushcfunction(L, luaopen_lpeg);
  lua_setfield(L, -2, "lpeg");
#endif

#ifdef WITH_LUTILS
  lua_pushcfunction(L, luaopen_lutils);
  lua_setfield(L, -2, "lutils");
#endif  

#ifdef WITH_MINIZ
  lua_pushcfunction(L, luaopen_miniz);
  lua_setfield(L, -2, "miniz");
#endif

#ifdef WITH_OPENSSL
  lua_pushcfunction(L, luaopen_openssl);
  lua_setfield(L, -2, "openssl");
#endif

#ifdef WITH_PCRE
  lua_pushcfunction(L, luaopen_rex_pcre);
  lua_setfield(L, -2, "rex");
#endif

#ifdef WITH_PPPP
  lua_pushcfunction(L, luaopen_pppp);
  lua_setfield(L, -2, "pppp");
#endif

  // Store uv module definition at preload.uv
  lua_pushcfunction(L, luaopen_luv);
  lua_setfield(L, -2, "uv");

#ifdef WITH_WINSVC
  lua_pushcfunction(L, luaopen_winsvc);
  lua_setfield(L, -2, "winsvc");
  
  lua_pushcfunction(L, luaopen_winsvcaux);
  lua_setfield(L, -2, "winsvcaux");
#endif

#ifdef WITH_ZLIB
  // Store lnode module definition at preload.zlib
  lua_pushcfunction(L, luaopen_zlib);
  lua_setfield(L, -2, "zlib");
#endif

  return 0;
}

/*
** Push on the stack the contents of table 'arg' from 1 to #arg
*/
static int lnode_pushargs(lua_State *L) {
    int i, n;
    if (lua_getglobal(L, "arg") != LUA_TTABLE) {
      luaL_error(L, "'arg' is not a table");
    }

    n = (int)luaL_len(L, -1);
    luaL_checkstack(L, n + 3, "too many arguments to script");
    for (i = 1; i <= n; i++) {
      lua_rawgeti(L, -i, i);
    }

    lua_remove(L, -i);  /* remove table from the stack */
    return n;
}

/*
** Create the 'arg' table, which stores all arguments from the
** command line ('argv'). It should be aligned so that, at index 0,
** it has 'argv[script]', which is the script name. The arguments
** to the script (everything after 'script') go to positive indices;
** other arguments (before the script name) go to negative indices.
** If there is no script name, assume interpreter's name as base.
*/
static void lnode_create_arg_table (lua_State *L, char **argv, int argc, int script) {
  int i, narg;

  if (script == argc) {
    script = 0;  /* no script name? */
  }

  narg = argc - (script + 1);  /* number of positive indices */
  
  lua_createtable(L, narg, script + 1);
  for (i = 0; i < argc; i++) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i - script);
  }
  lua_setglobal(L, "arg");
}

LUALIB_API int lnode_load_script(lua_State* L, char* filename, int argc, char* argv[], int offset) {
  // Load the init.lua script
  if (luaL_loadfilex(L, filename, NULL)) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return -1;
  }

  // args
  lnode_create_arg_table(L, argv, argc, offset);

  // Start the main script.
  if (lua_pcall(L, 0, 1, 0)) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return -1;
  }

  // Use the return value from the script as process exit code.
  int res = 0;
  if (lua_type(L, -1) == LUA_TNUMBER) {
    res = lua_tointeger(L, -1);
  }

  return res;
}

LUALIB_API int lnode_run_as_deamon() {
#ifndef WIN32
  if (fork() != 0) {
    exit(1);
  }

  if (setsid() < 0) {
    exit(1);
  }

  if (fork() != 0) {
    exit(1);
  }

  umask(022);

  signal(SIGCHLD, SIG_IGN);
#endif

  return 0;
}
